"""Post-training quantization of Mamba-YOLO layers 0-20 (everything the RTL runs).

Layer 21 (Detect) stays on the CPU in float and receives the dequantized outputs of
layers 14 / 17 / 20. Conventions follow the eMamba RTL: signed integers, power-of-two
static scales (value = int * 2^-n), round half up, saturation.

- BatchNorm is folded into the preceding convolution (no BN unit in hardware).
- Conv2d weights: INT8, power-of-two scale per tensor or per output channel.
  Biases stay unquantized here (INT32 at the accumulator scale in hardware).
- Activations: every tensor the hardware stores is quantized — the input and output of
  every Conv2d / LayerNorm / GELU / SiLU / MaxPool2d / Upsample, both sides of every
  Concat, and the output of every layer 0-20 (the residual stream).
  GELU / SiLU on an 8-bit input equal a 256-entry LUT. LayerNorm is computed exactly on
  the quantized input (a hardware LN unit is assumed; see the LN note in the report).
- The eMamba SSM cores use the bit-accurate RTL golden model (emamba_hw.golden).

    PYTHONPATH=. python -m emamba_hw.full_ptq --weights <ckpt> --weight-granularity channel
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
import torch.nn as nn

import eval_compare_backends as ecb
from ultralytics.nn.modules import Concat, Detect
from ultralytics.nn.modules.hw_ops import LightNorm, SiLUPWL, convert
from ultralytics.nn.modules.mamba_yolo import LSBlock

ROOT = Path(__file__).resolve().parents[1]
ACT_MODULES = (nn.Conv2d, nn.Linear, nn.LayerNorm, LightNorm, nn.GELU, nn.SiLU, SiLUPWL, nn.MaxPool2d, nn.Upsample)
# Activation point categories, for sensitivity runs that quantize one category at a time.
CATEGORIES = ("conv", "norm", "gelu", "silu", "pool", "concat", "layer_out")
MAX_WEIGHT_SHIFT = 15  # 4-bit per-channel weight shift register


def category(module: nn.Module) -> str:
    if isinstance(module, (nn.Conv2d, nn.Linear)):
        return "conv"
    if isinstance(module, (nn.LayerNorm, LightNorm)):
        return "norm"
    if isinstance(module, nn.GELU):
        return "gelu"
    if isinstance(module, (nn.SiLU, SiLUPWL)):
        return "silu"
    if isinstance(module, (nn.MaxPool2d, nn.Upsample)):
        return "pool"
    return "concat"


def pot_fake_quant(x: torch.Tensor, shift: torch.Tensor | int, bits: int) -> torch.Tensor:
    """round-half-up(x * 2^n) saturated to ``bits``, back to float."""
    scale = torch.exp2(torch.as_tensor(shift, dtype=torch.float32, device=x.device))
    q = torch.floor(x.float() * scale + 0.5).clamp(-(2 ** (bits - 1)), 2 ** (bits - 1) - 1)
    return (q / scale).to(x.dtype)


def fit_shift(threshold: torch.Tensor, bits: int) -> torch.Tensor:
    return torch.floor(torch.log2((2 ** (bits - 1) - 1) / threshold.clamp_min(1e-12)))


# ---------------------------------------------------------------- BatchNorm folding
def _fold(conv: nn.Conv2d, bn: nn.BatchNorm2d) -> None:
    std = torch.sqrt(bn.running_var + bn.eps)
    gain = bn.weight / std
    conv.weight.data.mul_(gain.reshape(-1, 1, 1, 1))
    bias = conv.bias.data if conv.bias is not None else torch.zeros_like(bn.running_mean)
    conv.bias = nn.Parameter(bn.bias + (bias - bn.running_mean) * gain)


def fold_batchnorms(model: nn.Module) -> int:
    """Fold every Conv2d -> BatchNorm2d pair in layers 0-20; the BN becomes Identity."""
    folded = 0
    for module in model.modules():
        if isinstance(module, nn.Sequential):
            items = list(module.named_children())
            for (_, a), (bn_name, b) in zip(items, items[1:]):
                if isinstance(a, nn.Conv2d) and isinstance(b, nn.BatchNorm2d):
                    _fold(a, b)
                    setattr(module, bn_name, nn.Identity())
                    folded += 1
        elif hasattr(module, "conv") and isinstance(getattr(module, "bn", None), nn.BatchNorm2d):  # ultralytics Conv
            _fold(module.conv, module.bn)
            delattr(module, "bn")  # same as ultralytics fuse(), so its own fuse() skips this module
            module.forward = module.forward_fuse
            folded += 1
        elif isinstance(module, LSBlock) and isinstance(module.norm, nn.BatchNorm2d):  # fc1 -> norm
            _fold(module.fc1, module.norm)
            module.norm = nn.Identity()
            folded += 1
    remaining = sum(isinstance(m, nn.BatchNorm2d) for m in model.modules())
    if remaining:
        raise RuntimeError(f"{remaining} BatchNorm2d layers were not folded")
    return folded


# ---------------------------------------------------------------- activation quantizers
class ActQuant:
    """Static per-tensor power-of-two quantizer for one stored tensor."""

    def __init__(self, bits: int = 8, percentile: float = 99.999):
        self.bits, self.percentile = bits, percentile
        self.calibrating = False
        self.threshold: torch.Tensor | None = None
        self.fixed_shift: int | None = None  # set when loading an exported spec
        self.record: list | None = None      # set to [] to keep the integer tensor of every call

    def __call__(self, x: torch.Tensor) -> torch.Tensor:
        if getattr(self, "float_record", None) is not None:  # FP32 export: keep the tensor, no quantization
            self.float_record.append(x.detach().float().cpu())
            return x
        if self.fixed_shift is not None or (self.record is not None and not self.calibrating):
            shift = self.shift
            if self.record is not None:
                q = torch.floor(x.detach().double() * 2.0 ** shift + 0.5).clamp(-(2 ** (self.bits - 1)), 2 ** (self.bits - 1) - 1)
                self.record.append(q.long().cpu())
            return pot_fake_quant(x, shift, self.bits)
        if self.calibrating:
            flat = x.detach().abs().flatten().float()
            if flat.numel() > 2_000_000:
                flat = flat[torch.randint(flat.numel(), (2_000_000,), device=flat.device)]
            t = torch.quantile(flat, self.percentile / 100.0)
            self.threshold = t if self.threshold is None else torch.maximum(self.threshold, t)
            return x
        return pot_fake_quant(x, fit_shift(self.threshold, self.bits), self.bits)

    @property
    def shift(self) -> int:
        if self.fixed_shift is not None:
            return self.fixed_shift
        return int(fit_shift(self.threshold, self.bits))


class FullQuant:
    """Attach weight + activation quantization to layers 0-20 of a Mamba-YOLO model."""

    def __init__(self, model: nn.Module, weight_granularity: str = "channel", act_bits: int = 8,
                 residual_bits: int = 8, weight_bits: int = 8, categories: tuple[str, ...] = CATEGORIES,
                 quantize_weights: bool = True):
        self.points: dict[str, ActQuant] = {}
        self.handles = []
        self.weight_shifts: dict[str, torch.Tensor] = {}  # per conv: shift per output channel (or scalar)
        body = model.model[:21] if hasattr(model, "model") else model
        self.weight_report = self._quantize_weights(body, weight_granularity, weight_bits, self.weight_shifts) \
            if quantize_weights else {}
        for index, layer in enumerate(body):
            if isinstance(layer, Detect):
                raise RuntimeError("layer 21 (Detect) must stay in float")
            for name, module in layer.named_modules(prefix=f"model.{index}"):
                if isinstance(module, ACT_MODULES + (Concat,)) and category(module) in categories:
                    self._hook(module, name, act_bits, multi_input=isinstance(module, Concat))
            if "layer_out" in categories:
                self._hook_output(layer, f"model.{index}", residual_bits)

    def _point(self, key: str, bits: int) -> ActQuant:
        return self.points.setdefault(key, ActQuant(bits))

    def _hook(self, module, name, bits, multi_input=False):
        qin, qout = self._point(f"{name}.in", bits), self._point(f"{name}.out", bits)
        if multi_input:
            inputs = [self._point(f"{name}.in{i}", bits) for i in range(8)]
            pre = lambda m, args: ([inputs[i](t) for i, t in enumerate(args[0])],)
        else:
            pre = lambda m, args: (qin(args[0]),) + tuple(args[1:])
        self.handles.append(module.register_forward_pre_hook(pre))
        self.handles.append(module.register_forward_hook(lambda m, args, out: qout(out)))

    def _hook_output(self, layer, name, bits):
        q = self._point(f"{name}.layer_out", bits)
        self.handles.append(layer.register_forward_hook(lambda m, args, out: q(out)))

    @staticmethod
    def _quantize_weights(body, granularity: str, bits: int, shifts_out: dict | None = None) -> dict:
        report = {}
        for name, module in body.named_modules(prefix="model"):
            if isinstance(module, (nn.Conv2d, nn.Linear)):
                w = module.weight.data
                amax = w.abs().amax(dim=tuple(range(1, w.ndim)), keepdim=True) if granularity == "channel" \
                    else w.abs().max()
                # Cap the shift: ~7k channels were decayed to ~1e-7 during training ("dead"); an uncapped
                # shift (up to 46) would push their INT32 bias out of range. They quantize to 0 instead.
                shift = fit_shift(amax, bits).clamp(max=MAX_WEIGHT_SHIFT)
                module.weight.data = pot_fake_quant(w, shift, bits)
                if shifts_out is not None:
                    shifts_out[name] = shift.flatten().to(torch.int64).cpu()
                report[name] = int(shift.min()) if granularity == "tensor" else [int(shift.min()), int(shift.max())]
        return report

    def set_calibrating(self, flag: bool) -> None:
        for q in self.points.values():
            q.calibrating = flag
        if not flag:  # points never reached during calibration (unused Concat slots) are dropped
            self.points = {k: q for k, q in self.points.items()
                           if q.threshold is not None or q.calibrating or q.fixed_shift is not None}

    def shift_table(self) -> dict[str, int]:
        return {k: q.shift for k, q in self.points.items() if q.threshold is not None or q.fixed_shift is not None}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--core", default="emamba_relu:rtl:y16", help="SSM core variant (see eval_compare_backends)")
    parser.add_argument("--weight-granularity", choices=("tensor", "channel"), default="channel")
    parser.add_argument("--act-bits", type=int, default=8)
    parser.add_argument("--residual-bits", type=int, default=8, help="bits of layer outputs (residual stream)")
    parser.add_argument("--no-act", action="store_true", help="weights only (activations stay float)")
    parser.add_argument("--no-weight", action="store_true", help="keep Conv2d weights in float")
    parser.add_argument("--silu-pwl", action="store_true",
                        help="replace every SiLU in layers 0-20 by the eMamba piecewise-linear SiLU (inference form)")
    parser.add_argument("--act-only", nargs="+", choices=CATEGORIES, default=list(CATEGORIES),
                        help="quantize activations of these categories only (sensitivity runs)")
    parser.add_argument("--calib-images", type=int, default=128)
    parser.add_argument("--subset", type=int, default=0)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--device", default="0")
    parser.add_argument("--tag", default=None)
    args = parser.parse_args()

    data = ROOT / "ultralytics/cfg/datasets/coco.yaml"
    load_args = argparse.Namespace(device=args.device, imgsz=640, batch=args.batch, calib_images=args.calib_images)
    model, info = ecb.load_with_backend(args.weights.resolve(), args.core, load_args, data)
    net = model.model.float().eval().to(f"cuda:{args.device}")
    pwl = convert(net, norm=None, gelu_to_silu=False, silu_pwl_eval=True) if args.silu_pwl else {}
    folded = fold_batchnorms(net)
    fq = FullQuant(net, args.weight_granularity, args.act_bits, args.residual_bits, categories=tuple(args.act_only),
                   quantize_weights=not args.no_weight)
    if args.no_act:
        for h in fq.handles:
            h.remove()
        fq.points = {}
    else:
        fq.set_calibrating(True)
        torch.manual_seed(0)
        with torch.no_grad():
            for images in ecb.calibration_batches(data, args.calib_images, 640, args.batch, args.device):
                net(images)
        fq.set_calibrating(False)

    val_data = ecb.subset_data_yaml(data, args.subset, ROOT / "runs/full_ptq") if args.subset else data
    tag = args.tag or f"{args.core.replace(':', '_')}_w{args.weight_granularity}_a{args.act_bits}_r{args.residual_bits}" \
        + ("_noact" if args.no_act else "")
    metrics = model.val(data=str(val_data), imgsz=640, batch=args.batch, device=args.device, workers=4,
                        project=str(ROOT / "runs/full_ptq"), name=tag, exist_ok=True, plots=False, verbose=False)
    result = {"weights": str(args.weights), "core": args.core, "weight_granularity": args.weight_granularity,
              "act_bits": args.act_bits, "residual_bits": args.residual_bits, "no_act": args.no_act,
              "act_categories": args.act_only, "no_weight": args.no_weight, "silu_pwl": pwl,
              "folded_bn": folded, "quant_points": len(fq.points), "subset": args.subset,
              "mAP50-95": metrics.box.map, "mAP50": metrics.box.map50,
              "act_shifts": fq.shift_table(), "weight_shifts": fq.weight_report}
    out = ROOT / "runs/full_ptq" / f"{tag}.json"
    out.write_text(json.dumps(result, indent=2))
    print(f"[{tag}] mAP50-95={metrics.box.map:.4f} mAP50={metrics.box.map50:.4f}  points={len(fq.points)} folded_bn={folded}")


if __name__ == "__main__":
    main()
