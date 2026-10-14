"""INT8 post-training quantization model of the eMamba SSM core.

Follows the eMamba INT reference (Mars_eMamba model/eMamba/ssm.py, util.py):
signed 8-bit, per-tensor, power-of-two scales, at the same quantization points
(cross-checked with the eMamba RTL test vectors in /media/solab/hdd/jiyong/eMamba_DAC,
which carry one fixed scale per tensor over the whole test set, i.e. static scales).
The scan state ``h`` is kept in floating point as in that reference; the RTL
accumulator width is not modelled.

Two scale modes:

- ``dynamic``: scale recomputed from every tensor at run time (99.999th
  percentile of |x|), which is what the eMamba Python reference does.
- ``static``: scales fixed once from calibration data, as hardware registers
  would hold them. Activation scales are per SS2D layer and per direction.

Parameters (weights, bias, A, D) always use the max |w| of that direction's slice.
"""

from __future__ import annotations

import math
from typing import Literal

import torch

QuantMode = Literal["dynamic", "static"]

# Activation tensors quantized inside one core call, in dataflow order.
ACT_POINTS = ("u", "dt_low", "B", "C", "dt", "delta", "deltaA", "deltaB", "Bu", "y")
PARAM_POINTS = ("x_proj", "dt_proj", "dt_bias", "A", "D")


def pot_scale(threshold: torch.Tensor, bits: int) -> torch.Tensor:
    """Smallest power-of-two scale such that ``threshold`` fits in signed ``bits``."""
    qmax = 2 ** (bits - 1) - 1
    return torch.exp2(torch.ceil(torch.log2(threshold.clamp_min(1e-12) / qmax)))


def fake_quant(x: torch.Tensor, scale: torch.Tensor, bits: int) -> torch.Tensor:
    qmax = 2 ** (bits - 1) - 1
    return torch.clamp(torch.round(x / scale), -qmax - 1, qmax) * scale


def per_direction_percentile(x: torch.Tensor, percentile: float, max_samples: int = 2_000_000) -> torch.Tensor:
    """|x| percentile for each direction; ``x`` is ``(B,4,...)``. Returns ``(4,)``."""
    flat = x.detach().abs().transpose(0, 1).reshape(4, -1).float()
    if flat.shape[1] > max_samples:  # torch.quantile has an input size limit
        index = torch.randint(flat.shape[1], (max_samples,), device=flat.device)
        flat = flat[:, index]
    return torch.quantile(flat, percentile / 100.0, dim=1)


class CoreQuantizer:
    """Holds the quantization state of one SS2D layer (all four directions)."""

    def __init__(self, bits: int = 8, mode: QuantMode = "static", percentile: float = 99.999):
        if mode not in ("dynamic", "static"):
            raise ValueError(f"unsupported quant mode: {mode}")
        self.bits, self.mode, self.percentile = bits, mode, percentile
        self.calibrating = False
        self.thresholds: dict[str, torch.Tensor] = {}  # running max over calibration batches

    def _broadcast(self, scale: torch.Tensor, x: torch.Tensor, direction_dim: int) -> torch.Tensor:
        shape = [1] * x.ndim
        shape[direction_dim] = 4
        return scale.reshape(shape).to(x.dtype)

    def act(self, name: str, x: torch.Tensor) -> torch.Tensor:
        """Quantize an activation laid out as ``(B,4,...)``."""
        if self.calibrating:
            t = per_direction_percentile(x, self.percentile)
            self.thresholds[name] = t if name not in self.thresholds else torch.maximum(self.thresholds[name], t)
            return x
        if self.mode == "dynamic":
            threshold = per_direction_percentile(x, self.percentile)
        else:
            if name not in self.thresholds:
                raise RuntimeError(f"static quantizer has no calibrated scale for {name!r}; run calibration first")
            threshold = self.thresholds[name]
        return fake_quant(x, self._broadcast(pot_scale(threshold, self.bits), x, 1), self.bits)

    def param(self, name: str, w: torch.Tensor) -> torch.Tensor:
        """Quantize a per-direction parameter laid out as ``(4,...)`` (max |w| per direction)."""
        if self.calibrating:  # thresholds describe the float model
            return w
        threshold = w.detach().abs().reshape(4, -1).amax(1)
        return fake_quant(w, self._broadcast(pot_scale(threshold, self.bits), w, 0), self.bits)

    def scale_table(self) -> dict[str, list[int]]:
        """Calibrated activation scales as the shift n in 2^-n, per direction."""
        return {
            name: [int(-math.log2(s)) for s in pot_scale(t, self.bits).tolist()]
            for name, t in self.thresholds.items()
        }
