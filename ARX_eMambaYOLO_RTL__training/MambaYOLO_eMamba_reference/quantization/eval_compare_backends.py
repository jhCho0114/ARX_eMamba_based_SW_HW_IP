"""Evaluate one Mamba-YOLO checkpoint under several SS2D backends.

Every variant reloads the same checkpoint and uses the same Ultralytics
validation arguments; only the SS2D scan backend changes. A variant is
``backend[:option...]``:

- ``v2`` / ``v2_relu``: CUDA selective scan with softplus / ReLU delta
- ``emamba_softplus`` / ``emamba_relu``: four-pass eMamba SSM core emulator
- ``:pwl``: emulator with eMamba's piecewise-linear exp (default exact)
- ``:int8s`` / ``:int8d``: INT8 PTQ of the core with static (calibrated on
  COCO train images) / dynamic per-tensor power-of-two scales
- ``emamba_relu:rtl``: bit-accurate golden model of the original eMamba RTL
  (emamba_hw), shifts calibrated per layer and direction. Options after ``rtl``
  deviate from the RTL for ablations: ``exp=python|exact``, ``nowrap``,
  ``hfrac=<bits>``, ``<tensor><bits>`` (e.g. ``dB16``), see emamba_hw.golden.RtlVariant

Example (pretrained softplus model, 500 val images):

    python eval_compare_backends.py \\
        --weights output_dir/coco/mambayolo_t/weights/best.pt \\
        --variants v2 emamba_softplus emamba_softplus:pwl --subset 500

INT8 PTQ of a ReLU checkpoint:

    python eval_compare_backends.py --weights .../mambayolo_t_emamba_relu/weights/last.pt \\
        --variants v2_relu emamba_relu:pwl emamba_relu:pwl:int8s emamba_relu:pwl:int8d
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from time import monotonic
from typing import Any

import cv2
import numpy as np
import torch
import yaml

ROOT = Path(__file__).resolve().parent


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--weights", type=Path, required=True, help="trained Mamba-YOLO .pt checkpoint")
    parser.add_argument("--data", type=Path, default=ROOT / "ultralytics/cfg/datasets/coco.yaml")
    parser.add_argument("--variants", nargs="+", default=["v2", "emamba_softplus"])
    parser.add_argument("--subset", type=int, default=0, help="evaluate the first N val images (0 = all)")
    parser.add_argument("--device", default="0")
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--calib-images", type=int, default=128, help="COCO train images for static INT calibration")
    parser.add_argument("--calib-offset", type=int, default=0, help="skip this many (sorted) train images before calibrating")
    parser.add_argument("--project", type=Path, default=ROOT / "runs/emamba_backend_eval")
    parser.add_argument("--output", type=Path, default=None, help="JSON report (default: <project>/<weights run>.json)")
    return parser.parse_args()


def json_value(value: Any) -> Any:
    if isinstance(value, torch.Tensor):
        return value.detach().cpu().tolist() if value.numel() > 1 else value.item()
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, dict):
        return {str(k): json_value(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_value(v) for v in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)


def subset_data_yaml(data: Path, count: int, project: Path) -> Path:
    """Write a dataset YAML whose val split is the first ``count`` val images."""
    config = yaml.safe_load(data.read_text())
    root = Path(config["path"])
    images = sorted((root / config["val"]).glob("*.jpg"))[:count]
    project.mkdir(parents=True, exist_ok=True)
    listing = project / f"val_first{count}.txt"
    listing.write_text("".join(f"{path}\n" for path in images))
    config["val"] = str(listing)
    subset = project / f"{data.stem}_val_first{count}.yaml"
    subset.write_text(yaml.safe_dump(config, sort_keys=False))
    return subset


def parse_variant(variant: str) -> tuple[str, str, str | None, int, list[str]]:
    """``emamba_relu:pwl:int8s`` -> (backend, exp_mode, quant mode, bits, rtl options)."""
    backend, *options = variant.split(":")
    exp_mode, quant_mode, bits, rtl_options = "exact", None, 8, []
    if "rtl" in options:
        if backend != "emamba_relu":
            raise ValueError("the eMamba RTL only implements a ReLU delta: use emamba_relu:rtl")
        rtl_options = options[options.index("rtl") + 1:]
        options = options[:options.index("rtl")]
        quant_mode = "rtl"
    for option in options:
        if option in ("exact", "pwl"):
            exp_mode = option
        elif option.startswith("int") and option[-1] in "sd" and option[3:-1].isdigit():
            quant_mode, bits = ("static" if option[-1] == "s" else "dynamic"), int(option[3:-1])
        else:
            raise ValueError(f"unknown option {option!r} in variant {variant!r}")
    if quant_mode and not backend.startswith("emamba_"):
        raise ValueError(f"{variant!r}: INT quantization needs an emamba_* backend")
    return backend, exp_mode, quant_mode, bits, rtl_options


def calibration_batches(data: Path, count: int, imgsz: int, batch: int, device: str, offset: int = 0):
    """Letterboxed COCO *train* images, so calibration never sees the val set."""
    from ultralytics.data.augment import LetterBox

    config = yaml.safe_load(data.read_text())
    paths = sorted((Path(config["path"]) / config["train"]).glob("*.jpg"))[offset:offset + count]
    letterbox = LetterBox((imgsz, imgsz), auto=False)
    device = f"cuda:{device}" if device.isdigit() else device
    for start in range(0, len(paths), batch):
        images = [letterbox(image=cv2.imread(str(p)))[..., ::-1].transpose(2, 0, 1) for p in paths[start:start + batch]]
        yield torch.from_numpy(np.ascontiguousarray(np.stack(images))).float().div(255).to(device)


def load_with_backend(weights: Path, variant: str, args: argparse.Namespace, data: Path) -> tuple[Any, dict]:
    from ultralytics import YOLO
    from ultralytics.nn.modules.mamba_yolo import SS2D, set_emamba_quant

    backend, exp_mode, quant_mode, bits, rtl_options = parse_variant(variant)
    model = YOLO(str(weights))
    layers = [m for m in model.model.modules() if isinstance(m, SS2D)]
    if not layers:
        raise RuntimeError("checkpoint contains no Mamba-YOLO SS2D modules")
    for module in layers:
        module.set_backend(backend, exp_mode=exp_mode)
    info: dict[str, Any] = {"ss2d_layers": len(layers)}
    if quant_mode:
        quantizers = set_emamba_quant(model.model, "static" if quant_mode == "rtl" else quant_mode, bits)
        if quant_mode in ("static", "rtl"):
            net = model.model.float().eval().to(f"cuda:{args.device}" if args.device.isdigit() else args.device)
            torch.manual_seed(0)  # percentile sampling in calibration: same scales for every variant
            for q in quantizers:
                q.calibrating = True
            with torch.no_grad():
                for images in calibration_batches(data, args.calib_images, args.imgsz, args.batch, args.device,
                                                  getattr(args, "calib_offset", 0)):
                    net(images)
            for q in quantizers:
                q.calibrating = False
            names = [n for n, m in model.model.named_modules() if isinstance(m, SS2D)]
            info["calib_images"] = args.calib_images
            info["calib_offset"] = getattr(args, "calib_offset", 0)
            if quant_mode == "rtl":
                from emamba_hw.mambayolo import attach_rtl_cores, parse_variant as parse_rtl_options

                rtl_variant = parse_rtl_options(rtl_options)
                info["rtl_variant"] = str(rtl_variant)
                info["rtl_shifts"] = attach_rtl_cores(model.model, quantizers, rtl_variant)
                set_emamba_quant(model.model, None)
            else:
                info["scale_shift_2^-n"] = {n: q.scale_table() for n, q in zip(names, quantizers)}
    return model, info


def main() -> None:
    args = parse_args()
    weights = args.weights.resolve()
    data = args.data.resolve()
    if args.subset:
        data = subset_data_yaml(data, args.subset, args.project)
    run_name = f"{weights.parent.parent.name}_{weights.stem}"
    output = args.output or args.project / f"{run_name}.json"
    report: dict[str, Any] = {"weights": str(weights), "data": str(data), "subset": args.subset, "results": {}}

    for variant in args.variants:
        model, info = load_with_backend(weights, variant, args, args.data.resolve())
        start = monotonic()
        metrics = model.val(
            data=str(data), imgsz=args.imgsz, batch=args.batch, device=args.device, workers=args.workers,
            project=str(args.project), name=f"{run_name}_{variant.replace(':', '_')}", exist_ok=True,
            plots=False, verbose=False,
        )
        report["results"][variant] = {
            "mAP50-95": metrics.box.map,
            "mAP50": metrics.box.map50,
            "elapsed_seconds": round(monotonic() - start, 1),
            "results_dict": json_value(metrics.results_dict),
            **info,
        }
        print(f"[{variant}] mAP50-95={metrics.box.map:.4f} mAP50={metrics.box.map50:.4f}")
        del model
        torch.cuda.empty_cache()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + "\n")  # keep partial results

    print(f"\n{'variant':<26}{'mAP50-95':>10}{'mAP50':>10}{'sec':>8}")
    for variant, r in report["results"].items():
        print(f"{variant:<26}{r['mAP50-95']:>10.4f}{r['mAP50']:>10.4f}{r['elapsed_seconds']:>8.0f}")
    print(f"saved {output}")


if __name__ == "__main__":
    main()
