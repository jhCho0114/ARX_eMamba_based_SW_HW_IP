"""Run Mamba-YOLO SS2D through the bit-accurate eMamba RTL golden model.

Each SS2D layer = four core calls (row/col x forward/reverse), each with its own
weights and its own fixed-point shifts, as a hardware register set per call would
hold them. Everything outside the core (in_proj, dwconv, GELU, cross-scan, merge,
out_norm, gate, out_proj) stays in floating point, i.e. on the CPU.

Shifts are chosen from calibration thresholds collected by ``CoreQuantizer`` in
calibrating mode (float ReLU emulator): ``n = floor(log2(127 / threshold))`` so the
calibrated range fits int8. Weights, bias, A and D use their max |value|. The
exp(dA) output keeps the RTL's fixed 2^-7.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, replace
from functools import partial

import torch

from ultralytics.nn.modules.emamba_quant import CoreQuantizer
from ultralytics.nn.modules.emamba_ss2d import _merge_and_norm, cross_scan_4d
from ultralytics.nn.modules.mamba_yolo import SS2D

from .golden import TENSORS, CoreParams, RtlShifts, RtlVariant, preprocess, sat
from .golden_triton import scan_triton


def fit_shift(threshold: float, bits: int = 8) -> int:
    """Largest n with threshold <= (2^(bits-1)-1) * 2^-n."""
    return math.floor(math.log2((2 ** (bits - 1) - 1) / max(float(threshold), 1e-12)))


def to_int(x: torch.Tensor, shift: int, bits: int = 8) -> torch.Tensor:
    """Offline / CPU-side quantization: round half up, saturate."""
    return sat(torch.floor(x.double() * 2.0 ** shift + 0.5).long(), bits)


def parse_variant(options: list[str]) -> RtlVariant:
    """["exp=exact", "nowrap", "hfrac=8", "dB16", ...] -> RtlVariant (empty = original RTL)."""
    exp, wrap_ax, h_frac, bits = "rtl", True, 0, {}
    for option in options:
        if option.startswith("exp="):
            exp = option[4:]
        elif option == "nowrap":
            wrap_ax = False
        elif option.startswith("hfrac="):
            h_frac = int(option[6:])
        else:
            name = option.rstrip("0123456789")
            if name not in TENSORS or name == option:
                raise ValueError(f"unknown RTL variant option {option!r}")
            bits[name] = int(option[len(name):])
    return RtlVariant(exp, wrap_ax, h_frac, tuple(sorted(bits.items())))


@dataclass
class DirectionCore:
    shifts: RtlShifts
    params: CoreParams
    stats: dict | None = None  # set to {} to collect accumulator maxima / saturation counts
    record: dict | None = None  # set to {} to keep the integer core inputs/outputs of the last call


def make_realisable(s: RtlShifts) -> RtlShifts:
    """Coarsen output shifts where the RTL shifters would need a negative / zero count."""
    s = replace(s)
    s.dt_low = min(s.dt_low, s.u + s.w_dt - 1)
    s.B = min(s.B, s.u + s.w_B - 1)
    s.C = min(s.C, s.u + s.w_C - 1)
    s.bias = min(s.bias, s.dt_low + s.w_dtp)
    s.delta = min(s.delta, s.dt_low + s.w_dtp - 1)
    s.dB = min(s.dB, s.delta + s.B - 1)
    s.D = min(s.D, s.dA + s.dB + s.C)
    s.y = min(s.y, s.u + s.dA + s.dB + s.C - 1)
    s.check()
    return s


def build_direction_cores(ss2d: SS2D, quant: CoreQuantizer, variant: RtlVariant = RtlVariant()) -> list[DirectionCore]:
    """Integer weights + shifts of the four core calls of one SS2D layer."""
    t, w = quant.thresholds, variant.width
    K, _, R = ss2d.dt_projs_weight.shape
    C, N = ss2d.x_proj_weight.shape[-1], ss2d.A_logs.shape[-1]
    A = -torch.exp(ss2d.A_logs.detach().float()).reshape(K, C, N)
    D = ss2d.Ds.detach().float().reshape(K, C)
    cores = []
    for k in range(K):
        x_proj = ss2d.x_proj_weight.detach()[k].float()
        w_dt, w_B, w_C = x_proj[:R], x_proj[R:R + N], x_proj[R + N:]
        w_dtp, bias = ss2d.dt_projs_weight.detach()[k].float(), ss2d.dt_projs_bias.detach()[k].float()
        s = make_realisable(RtlShifts(
            u=fit_shift(t["u"][k], w("u")), w_dt=fit_shift(w_dt.abs().max()),
            dt_low=fit_shift(t["dt_low"][k], w("dt_low")),
            w_B=fit_shift(w_B.abs().max()), B=fit_shift(t["B"][k], w("B")),
            w_C=fit_shift(w_C.abs().max()), C=fit_shift(t["C"][k], w("C")),
            w_dtp=fit_shift(w_dtp.abs().max()), bias=fit_shift(bias.abs().max()),
            delta=fit_shift(t["delta"][k], w("delta")), A=fit_shift(A[k].abs().max()), dA=w("dA") - 1,
            dB=fit_shift(t["deltaB"][k], w("dB")), D=fit_shift(D[k].abs().max()), y=fit_shift(t["y"][k], w("y")),
        ))
        cores.append(DirectionCore(s, CoreParams(
            w_dt=to_int(w_dt, s.w_dt), w_B=to_int(w_B, s.w_B), w_C=to_int(w_C, s.w_C),
            w_dtp=to_int(w_dtp, s.w_dtp), bias=to_int(bias, s.bias),
            A=to_int(A[k], s.A), D=to_int(D[k], s.D),
        )))
    return cores


def rtl_forward_core(ss2d: SS2D, cores: list[DirectionCore], x: torch.Tensor, channel_first: bool = False,
                     variant: RtlVariant = RtlVariant()) -> torch.Tensor:
    if not channel_first:
        x = x.permute(0, 3, 1, 2).contiguous()
    batch, channels, height, width = x.shape
    xs = cross_scan_4d(x.float())  # (B, 4, C, L): CPU side
    ys = []
    for k, core in enumerate(cores):
        s, p = core.shifts, core.params
        p = CoreParams(**{name: v.to(x.device) for name, v in vars(p).items()})
        u_float = xs[:, k].transpose(1, 2)
        u = to_int(u_float, s.u, variant.width("u"))                        # (B, L, C) int8 -> core
        if core.stats is not None:
            from .golden import record_sat
            core.stats["seq_len"] = u_float.shape[1]
            record_sat(core.stats, "sat_u", torch.floor(u_float.double() * 2.0 ** s.u + 0.5).long(), u)
        delta, B, C = preprocess(u, p, s, variant, stats=core.stats)         # (B, L, C) / (B, L, N)
        y = scan_triton(u.transpose(1, 2), delta.transpose(1, 2), B, C, p.A[None], p.D[None], s, variant,
                        stats=core.stats)
        if core.record is not None:
            core.record.update(u=u.cpu(), delta=delta.cpu(), B=B.cpu(), C=C.cpu(), y=y.transpose(1, 2).cpu())
        ys.append(y.double() * 2.0 ** -s.y)                                  # core -> CPU
    y = torch.stack(ys, dim=1).float()
    out = _merge_and_norm(y, batch, channels, height, width, ss2d.out_norm, getattr(ss2d, "out_norm_shape", "v0"))
    return out.to(x.dtype)


def attach_rtl_cores(model: torch.nn.Module, quantizers: list[CoreQuantizer], variant: RtlVariant = RtlVariant()) -> dict:
    """Replace every SS2D core by the RTL golden model; returns the shift table per layer/direction."""
    layers = [(name, m) for name, m in model.named_modules() if isinstance(m, SS2D)]
    table = {}
    for (name, ss2d), quant in zip(layers, quantizers):
        cores = build_direction_cores(ss2d, quant, variant)
        ss2d.forward_core = partial(rtl_forward_core, ss2d, cores, variant=variant)
        ss2d.emamba_rtl_cores = cores
        table[name] = [core.shifts.to_dict() for core in cores]
    return table
