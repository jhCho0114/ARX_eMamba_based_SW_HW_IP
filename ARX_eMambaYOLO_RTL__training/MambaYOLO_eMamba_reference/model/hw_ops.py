"""Hardware-friendly Mamba-YOLO: reuse the eMamba RTL units for norms and activations.

- LayerNorm -> LightNorm (eMamba LightNorm.sv / LightNorm_compute.sv):
      y = weight * (x - mean) * 25 / range / 8 + bias = weight * (x - mean) / (0.32 * range) + bias
  range = max - min over the channel dimension; no square root. The parameters keep the
  LayerNorm names (weight / bias), so LayerNorm checkpoints load directly.
- GELU -> SiLU (the eMamba RTL has a SiLU unit, SiLU_piecewise.sv, but no GELU).
- SiLU at inference -> SiLU_piecewise: 18 linear segments on [-7, 7] (approximation.
  piecewise_linear_function). Training uses exact SiLU, as eMamba does.

Only layers 0-20 (the RTL part) are converted; the Detect head is left untouched.
"""

from __future__ import annotations

import torch
import torch.nn as nn

LIGHTNORM_C = 0.32  # 25 / 8 = 1 / 0.32 in LightNorm_compute.sv

# SiLU_piecewise.sv / approximation.piecewise_linear_function: segment k applies for
# BOUND[k-1] <= x < BOUND[k]; x < -7 -> 0, x >= 7 -> x.
SILU_BOUND = (-7.0, -6.417, -5.821, -5.205, -4.560, -3.862, -3.033, -1.547, -0.998, -0.594, -0.294, -0.093,
              -0.004, 0.004, 0.098, 0.327, 1.085, 7.000)
SILU_SLOPE = (-0.007, -0.011, -0.018, -0.029, -0.046, -0.072, -0.089, 0.005, 0.142, 0.287, 0.406, 0.476,
              0.500, 0.526, 0.605, 0.856, 1.045)
SILU_ICEPT = (-0.055, -0.083, -0.123, -0.180, -0.258, -0.358, -0.409, -0.265, -0.127, -0.041, -0.006, 0.0,
              0.0, 0.0, -0.008, -0.117, -0.324)


class LightNorm(nn.Module):
    """eMamba LightNorm over the last dimension; drop-in for nn.LayerNorm."""

    def __init__(self, normalized_shape: int, eps: float = 1e-6):
        super().__init__()
        self.normalized_shape = (normalized_shape,) if isinstance(normalized_shape, int) else tuple(normalized_shape)
        self.eps = eps  # training stability only; the RTL divides by the range directly
        self.weight = nn.Parameter(torch.ones(self.normalized_shape))
        self.bias = nn.Parameter(torch.zeros(self.normalized_shape))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        d = x - x.mean(-1, keepdim=True)
        rng = x.amax(-1, keepdim=True) - x.amin(-1, keepdim=True)
        return d / (LIGHTNORM_C * rng + self.eps) * self.weight + self.bias

    @classmethod
    def from_layernorm(cls, ln: nn.LayerNorm) -> "LightNorm":
        new = cls(ln.normalized_shape[0], ln.eps).to(ln.weight.device)
        with torch.no_grad():
            new.weight.copy_(ln.weight)
            new.bias.copy_(ln.bias)
        return new


def silu_pwl(x: torch.Tensor) -> torch.Tensor:
    bound = x.new_tensor(SILU_BOUND)
    index = torch.bucketize(x, bound, right=True) - 1          # segment below which x lies
    inside = (index >= 0) & (index < len(SILU_SLOPE))
    k = index.clamp(0, len(SILU_SLOPE) - 1)
    y = x.new_tensor(SILU_SLOPE)[k] * x + x.new_tensor(SILU_ICEPT)[k]
    return torch.where(inside, y, torch.where(x >= SILU_BOUND[-1], x, torch.zeros_like(x)))


class HwSiLU(nn.SiLU):
    """SiLU that replaces GELU. Never in-place: ultralytics initialize_weights() sets
    ``inplace=True`` on every nn.SiLU, which breaks on the chunked z view in SS2D."""

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return torch.nn.functional.silu(x)


class SiLUPWL(nn.Module):
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return silu_pwl(x)


@torch.no_grad()
def calibrate_lightnorm(model: nn.Module, batches) -> dict[str, float]:
    """Scale every LightNorm weight by E[0.32*range] / E[std] of its input, measured on
    ``batches``, so each layer starts with the same average output scale as the LayerNorm it
    replaced (the range of C values is several standard deviations, and outlier channels
    widen it further). Returns the factor applied per layer."""
    stats: dict[str, list[float]] = {}
    handles = []
    for name, m in model.named_modules():
        if isinstance(m, LightNorm):
            def hook(mod, args, _name=name):
                x = args[0].float()
                d = x - x.mean(-1, keepdim=True)
                rng = LIGHTNORM_C * (x.amax(-1) - x.amin(-1))
                std = (d.pow(2).mean(-1) + 1e-6).sqrt()
                acc = stats.setdefault(_name, [0.0, 0.0])
                acc[0] += float(rng.mean())
                acc[1] += float(std.mean())
            handles.append(m.register_forward_pre_hook(hook))
    for images in batches:
        model(images)
    for h in handles:
        h.remove()
    factors = {}
    for name, m in model.named_modules():
        if isinstance(m, LightNorm) and name in stats:
            factors[name] = stats[name][0] / stats[name][1]
            m.weight.mul_(factors[name])
    return factors


def _replace(root: nn.Module, predicate, make) -> int:
    count = 0
    for name, module in list(root.named_modules()):
        for child_name, child in list(module.named_children()):
            if predicate(child):
                setattr(module, child_name, make(child))
                count += 1
    return count


def convert(model: nn.Module, norm: str | None = "light", gelu_to_silu: bool = True, silu_pwl_eval: bool = False,
            layers: int = 21) -> dict[str, int]:
    """Convert layers [0, layers) of a Mamba-YOLO DetectionModel in place."""
    body = model.model[:layers] if hasattr(model, "model") else model[:layers]
    done = {}
    if norm == "light":
        done["layernorm->lightnorm"] = _replace(body, lambda m: isinstance(m, nn.LayerNorm), LightNorm.from_layernorm)
    if gelu_to_silu:
        done["gelu->silu"] = _replace(body, lambda m: isinstance(m, nn.GELU), lambda m: HwSiLU())
    if silu_pwl_eval:
        done["silu->pwl"] = _replace(body, lambda m: isinstance(m, nn.SiLU), lambda m: SiLUPWL())
    return done
