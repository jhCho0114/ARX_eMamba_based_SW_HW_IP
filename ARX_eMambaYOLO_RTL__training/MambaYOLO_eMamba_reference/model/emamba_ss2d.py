"""Pure PyTorch four-pass SS2D backend for a single-direction eMamba IP.

The implementation intentionally executes the recurrence once per direction.
It is a functional model of four sequential hardware invocations, not a fast
replacement for the CUDA selective-scan kernel shipped with Mamba-YOLO.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Literal

import torch
import torch.nn.functional as F

if TYPE_CHECKING:  # only for annotations; keeps this file importable on its own
    from .emamba_quant import CoreQuantizer


DeltaActivation = Literal["softplus", "relu"]
ExpMode = Literal["exact", "pwl"]
ScanImpl = Literal["loop", "chunked"]

# eMamba ``approximation.custom_exp``: segments (lo, hi] with hi listed below,
# the first segment also includes -9.871, and anything outside [-9.871, 0] is 0.
# The Python reference has four 0.001-wide holes (e.g. -8.410 < x <= -8.409)
# that fall through to 0; they look like typos and are closed here.
_PWL_EXP_LOWER = -9.871
_PWL_EXP_UPPER = (
    -9.384, -8.897, -8.410, -7.922, -7.435, -6.948, -6.461, -5.974, -5.486, -4.999, -4.512,
    -4.025, -3.538, -3.050, -2.563, -2.076, -1.589, -1.102, -0.614, -0.127, 0.000,
)
_PWL_EXP_SLOPE = (
    0.0, 0.0, 0.0, 0.0, 0.0, 0.001, 0.001, 0.002, 0.003, 0.005, 0.009,
    0.014, 0.023, 0.037, 0.061, 0.099, 0.162, 0.263, 0.428, 0.697, 0.939,
)
_PWL_EXP_INTERCEPT = (
    0.001, 0.001, 0.002, 0.003, 0.004, 0.006, 0.010, 0.015, 0.022, 0.033, 0.050,
    0.075, 0.111, 0.162, 0.233, 0.332, 0.461, 0.622, 0.804, 0.969, 1.000,
)


def pwl_exp(x: torch.Tensor) -> torch.Tensor:
    """Piecewise-linear exp of the eMamba SSM core, valid for x <= 0."""
    upper = x.new_tensor(_PWL_EXP_UPPER)
    index = torch.bucketize(x, upper).clamp_max(len(_PWL_EXP_UPPER) - 1)
    y = x.new_tensor(_PWL_EXP_SLOPE)[index] * x + x.new_tensor(_PWL_EXP_INTERCEPT)[index]
    inside = (x >= _PWL_EXP_LOWER) & (x <= 0)
    return torch.where(inside, y, torch.zeros_like(y))


def linear_scan_chunked(a: torch.Tensor, b: torch.Tensor, chunk: int = 256) -> torch.Tensor:
    """Solve ``h[t] = a[t] * h[t-1] + b[t]`` (h[-1] = 0) along the last dim.

    Hillis-Steele scan inside each chunk, carried state between chunks. Same
    recurrence as the loop reference, reassociated only for speed.
    """
    length = a.shape[-1]
    state = torch.zeros_like(b[..., 0])
    outputs = []
    for start in range(0, length, chunk):
        aa, bb = a[..., start:start + chunk], b[..., start:start + chunk]
        step = 1
        while step < aa.shape[-1]:
            bb = torch.cat([bb[..., :step], bb[..., step:] + aa[..., step:] * bb[..., :-step]], dim=-1)
            aa = torch.cat([aa[..., :step], aa[..., step:] * aa[..., :-step]], dim=-1)
            step *= 2
        h = bb + aa * state.unsqueeze(-1)
        state = h[..., -1]
        outputs.append(h)
    return torch.cat(outputs, dim=-1)


def cross_scan_4d(x: torch.Tensor) -> torch.Tensor:
    """Convert BCHW features to row/column forward/reverse sequences.

    Returns a tensor shaped ``(batch, 4, channels, height * width)`` in
    row-forward, column-forward, row-reverse, column-reverse order. This order
    is identical to Mamba-YOLO's ``CrossScan``.
    """
    if x.ndim != 4:
        raise ValueError(f"expected BCHW input, got shape {tuple(x.shape)}")
    batch, channels, height, width = x.shape
    sequences = torch.empty(
        (batch, 4, channels, height * width), device=x.device, dtype=x.dtype
    )
    sequences[:, 0] = x.flatten(2, 3)
    sequences[:, 1] = x.transpose(2, 3).flatten(2, 3)
    sequences[:, 2:4] = sequences[:, 0:2].flip(-1)
    return sequences


def cross_merge_4d(ys: torch.Tensor, height: int, width: int) -> torch.Tensor:
    """Undo directional ordering and sum four directional results.

    ``ys`` may be ``(B, 4, C, L)`` or ``(B, 4, C, H, W)``. The returned
    tensor has shape ``(B, C, H * W)`` and matches Mamba-YOLO CrossMerge.
    """
    if ys.ndim == 5:
        ys = ys.flatten(3, 4)
    if ys.ndim != 4 or ys.shape[1] != 4:
        raise ValueError(f"expected (B,4,C,L) directional outputs, got {tuple(ys.shape)}")
    batch, _, channels, length = ys.shape
    if length != height * width:
        raise ValueError(f"sequence length {length} != height*width {height * width}")

    aligned = ys[:, 0:2] + ys[:, 2:4].flip(-1)
    row = aligned[:, 0]
    column = (
        aligned[:, 1]
        .reshape(batch, channels, width, height)
        .transpose(2, 3)
        .contiguous()
        .reshape(batch, channels, length)
    )
    return row + column


def emamba_scan_1d(
    u: torch.Tensor,
    delta: torch.Tensor,
    A: torch.Tensor,
    B: torch.Tensor,
    C: torch.Tensor,
    D: torch.Tensor | None = None,
    delta_bias: torch.Tensor | None = None,
    delta_activation: DeltaActivation = "softplus",
    exp_mode: ExpMode = "exact",
) -> torch.Tensor:
    """Reference eMamba/S6 recurrence for one scan direction.

    Shapes follow the Mamba-YOLO kernel interface: ``u`` and ``delta`` are
    ``(B,C,L)``, ``A`` is ``(C,N)``, and input-dependent ``B``/``C`` are
    ``(B,N,L)``. Calculations use FP32, like the original reference kernel.
    """
    if u.ndim != 3 or delta.shape != u.shape:
        raise ValueError("u and delta must both have shape (B,C,L)")
    batch, channels, length = u.shape
    if A.ndim != 2 or A.shape[0] != channels:
        raise ValueError("A must have shape (C,N)")
    state_size = A.shape[1]
    expected_bc = (batch, state_size, length)
    if B.shape != expected_bc or C.shape != expected_bc:
        raise ValueError(f"B and C must have shape {expected_bc}")

    input_dtype = u.dtype
    u32, dt32, A32 = u.float(), delta.float(), A.float()
    B32, C32 = B.float(), C.float()
    dt32 = _activate_delta(dt32, delta_bias, delta_activation)
    exp = _exp_fn(exp_mode)

    state = u32.new_zeros((batch, channels, state_size))
    outputs = []
    for index in range(length):
        delta_t = dt32[:, :, index]
        transition = exp(delta_t.unsqueeze(-1) * A32)
        input_term = (
            delta_t.unsqueeze(-1)
            * B32[:, :, index].unsqueeze(1)
            * u32[:, :, index].unsqueeze(-1)
        )
        state = transition * state + input_term
        output = (state * C32[:, :, index].unsqueeze(1)).sum(-1)
        if D is not None:
            output = output + D.float().reshape(1, channels) * u32[:, :, index]
        outputs.append(output)
    return torch.stack(outputs, dim=-1).to(input_dtype)


def _activate_delta(dt: torch.Tensor, bias: torch.Tensor | None, activation: DeltaActivation) -> torch.Tensor:
    if bias is not None:
        dt = dt + bias.float().reshape(-1, 1)
    if activation == "softplus":
        return F.softplus(dt)
    if activation == "relu":
        return F.relu(dt)
    raise ValueError(f"unsupported delta activation: {activation}")


def _exp_fn(exp_mode: ExpMode):
    if exp_mode == "exact":
        return torch.exp
    if exp_mode == "pwl":
        return pwl_exp
    raise ValueError(f"unsupported exp mode: {exp_mode}")


def emamba_scan_chunked(
    u: torch.Tensor,
    delta: torch.Tensor,
    A: torch.Tensor,
    B: torch.Tensor,
    C: torch.Tensor,
    D: torch.Tensor,
    delta_bias: torch.Tensor,
    delta_activation: DeltaActivation = "softplus",
    exp_mode: ExpMode = "exact",
    chunk: int = 256,
) -> torch.Tensor:
    """Fast equivalent of :func:`emamba_scan_1d` for all four directions at once.

    Shapes: ``u``/``delta`` ``(B,K,C,L)``, ``A`` ``(K,C,N)``, ``B``/``C``
    ``(B,K,N,L)``, ``D``/``delta_bias`` ``(K,C)``. Each direction still uses
    only its own parameters; batching them is purely a software speedup.
    """
    u32 = u.float()
    dt = _activate_delta(delta.float().flatten(1, 2), delta_bias.flatten(), delta_activation).view_as(u32)
    exp = _exp_fn(exp_mode)
    transition = exp(dt.unsqueeze(3) * A.float().unsqueeze(0).unsqueeze(-1))  # (B,K,C,N,L)
    input_term = (dt * u32).unsqueeze(3) * B.float().unsqueeze(2)
    states = linear_scan_chunked(transition, input_term, chunk)
    y = (states * C.float().unsqueeze(2)).sum(3)
    return (y + D.float().unsqueeze(0).unsqueeze(-1) * u32).to(u.dtype)


def emamba_core_quantized(
    xs: torch.Tensor,
    x_proj_weight: torch.Tensor,
    dt_projs_weight: torch.Tensor,
    dt_projs_bias: torch.Tensor,
    A: torch.Tensor,
    D: torch.Tensor,
    quant: CoreQuantizer,
    delta_activation: DeltaActivation = "relu",
    exp_mode: ExpMode = "pwl",
    chunk: int = 256,
) -> torch.Tensor:
    """Four core calls with INT8 fake quantization at the eMamba INT reference points.

    ``xs`` is ``(B,4,C,L)``; the core includes x_proj and dt_proj like eMamba's
    SSM module. Returns ``(B,4,C,L)``. The scan state stays in floating point.
    """
    rank = dt_projs_weight.shape[-1]
    state_size = A.shape[-1]
    u = quant.act("u", xs.float())
    x_dbl = torch.einsum("bkdl,kcd->bkcl", u, quant.param("x_proj", x_proj_weight.float()))
    dt_low, B, C = torch.split(x_dbl, [rank, state_size, state_size], dim=2)
    dt_low, B, C = quant.act("dt_low", dt_low), quant.act("B", B), quant.act("C", C)
    dt = torch.einsum("bkrl,kdr->bkdl", dt_low, quant.param("dt_proj", dt_projs_weight.float()))
    dt = quant.act("dt", dt + quant.param("dt_bias", dt_projs_bias.float()).unsqueeze(0).unsqueeze(-1))
    delta = quant.act("delta", _activate_delta(dt, None, delta_activation))
    A_q, D_q = quant.param("A", A.float()), quant.param("D", D.float())

    delta5 = delta.unsqueeze(3)  # (B,4,C,1,L)
    deltaA = quant.act("deltaA", _exp_fn(exp_mode)(delta5 * A_q.unsqueeze(0).unsqueeze(-1)))
    deltaB = quant.act("deltaB", delta5 * B.unsqueeze(2))
    Bu = quant.act("Bu", deltaB * u.unsqueeze(3))  # eMamba_DAC vectors store this as SSM/Bu_quant
    states = linear_scan_chunked(deltaA, Bu, chunk)
    y = (states * C.unsqueeze(2)).sum(3) + D_q.unsqueeze(0).unsqueeze(-1) * u
    return quant.act("y", y)


def cross_selective_scan_emamba(
    x: torch.Tensor,
    x_proj_weight: torch.Tensor,
    x_proj_bias: torch.Tensor | None,
    dt_projs_weight: torch.Tensor,
    dt_projs_bias: torch.Tensor,
    A_logs: torch.Tensor,
    Ds: torch.Tensor,
    out_norm: torch.nn.Module,
    out_norm_shape: str = "v0",
    delta_activation: DeltaActivation = "softplus",
    exp_mode: ExpMode = "exact",
    scan_impl: ScanImpl = "chunked",
    quant: CoreQuantizer | None = None,
    force_fp32: bool = True,
) -> torch.Tensor:
    """Run SS2D as four explicit calls to the single-direction reference IP."""
    batch, channels, height, width = x.shape
    directions, projected_size, projected_channels = x_proj_weight.shape
    if directions != 4 or projected_channels != channels:
        raise ValueError("eMamba SS2D requires four direction-specific projections")
    rank = dt_projs_weight.shape[-1]
    state_size = (projected_size - rank) // 2
    if projected_size != rank + 2 * state_size:
        raise ValueError("invalid x projection dimensions")

    xs = cross_scan_4d(x)
    A = -torch.exp(A_logs.float()).reshape(4, channels, state_size)
    D = Ds.float().reshape(4, channels)
    if quant is not None:
        if x_proj_bias is not None:
            raise ValueError("quantized core does not model an x_proj bias")
        ys = emamba_core_quantized(xs, x_proj_weight, dt_projs_weight, dt_projs_bias, A, D, quant,
                                   delta_activation, exp_mode)
        return _merge_and_norm(ys, batch, channels, height, width, out_norm, out_norm_shape).to(x.dtype)

    x_dbl = torch.einsum("bkdl,kcd->bkcl", xs, x_proj_weight)
    if x_proj_bias is not None:
        x_dbl = x_dbl + x_proj_bias.reshape(1, 4, -1, 1)
    dts, Bs, Cs = torch.split(x_dbl, [rank, state_size, state_size], dim=2)
    dts = torch.einsum("bkrl,kdr->bkdl", dts, dt_projs_weight)

    if scan_impl == "chunked":
        ys = emamba_scan_chunked(xs, dts, A, Bs, Cs, D, dt_projs_bias, delta_activation, exp_mode)
    elif scan_impl == "loop":
        ys = torch.stack(
            [
                emamba_scan_1d(
                    xs[:, direction], dts[:, direction], A[direction], Bs[:, direction], Cs[:, direction],
                    D[direction], dt_projs_bias[direction], delta_activation, exp_mode,
                )
                for direction in range(4)
            ],
            dim=1,
        )
    else:
        raise ValueError(f"unsupported scan implementation: {scan_impl}")
    return _merge_and_norm(ys, batch, channels, height, width, out_norm, out_norm_shape).to(x.dtype)


def _merge_and_norm(ys, batch, channels, height, width, out_norm, out_norm_shape):
    """CPU-side part after the four core calls: CrossMerge then out_norm."""
    y = cross_merge_4d(ys, height, width)
    if out_norm_shape == "v1":
        return out_norm(y.reshape(batch, channels, height, width)).permute(0, 2, 3, 1)
    return out_norm(y.transpose(1, 2).contiguous()).reshape(batch, height, width, channels)
