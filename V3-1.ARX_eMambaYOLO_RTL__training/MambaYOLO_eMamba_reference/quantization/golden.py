"""Bit-accurate integer golden model of the original eMamba RTL SSM core.

Source: ~/vivado/eMamba_DAC/eMamba_DAC.srcs/sources_1/new (Jiyong Kim), modules
SSM_Preprocess / SSM_Computation and their submodules. One call = one sequence of
one scan direction; the state is reset to zero at the start of every sequence.

Integer conventions of the RTL:

- a tensor with shift ``n`` holds ``value = int * 2^-n`` (power-of-two scales only)
- ``shifter_right``: arithmetic shift that rounds half up, ``(x >>> s) + x[s-1]``
- ``saturator``: clamp to int8 [-128, 127]
- shifts are compile-time parameters (static scales)

Datapath per token t, channel d, state n (shift names in parentheses):

    dt_low = sat8(rshr(W_dt  @ u, u+w_dt-dt_low))                  x_proj, no bias
    B      = sat8(rshr(W_B   @ u, u+w_B-B))
    C      = sat8(rshr(W_C   @ u, u+w_C-C))
    dt     = sat8(rshr(W_dtp @ dt_low + (bias << dt_low+w_dtp-bias), dt_low+w_dtp-delta))
    delta  = relu(dt)
    dA     = sat8(rshr(pwl(delta*A), 2(delta+A)-dA))               Exp_piecewise
    dB     = sat8(rshr(delta*B, delta+B-dB))                       Dim_expand_delta_B
    Ax     = wrap_{16+dA}(dA * x_k)                                SSM_xkP1_compute
    x_k+1  = Ax + ((dB*u) << dA)                                   24-bit, not stored
    x_k    <- rshr(x_k+1, dA)                                      17-bit state
    y      = sat8(rshr(sum_n C*x_k+1 + ((D*u) << dA+dB+C-D), u+dA+dB+C-y))

``Ax`` is 23 bits wide in the RTL although dA*x_k needs 25, so large states wrap.
``RtlVariant`` switches individual behaviours off for ablations; its default is the RTL.
"""

from __future__ import annotations

import math
from dataclasses import asdict, dataclass

import torch

# Exp_piecewise_compute.sv: the old eMamba custom_exp, domain [-4, 1], 12 segments.
# Segment k (k = 2..12) applies for IF[k-1] < x <= IF[k]; x < IF[0] gives 0; x > IF[11] gives MULT[12].
PWL_IF = (-4.000, -3.513, -3.026, -2.539, -2.052, -1.565, -1.077, -0.590, -0.103, 0.384, 0.871, 1.000)
PWL_MULT = (0, 0.024, 0.038, 0.063, 0.102, 0.166, 0.270, 0.439, 0.714, 1.162, 1.891, 2.550, 2.718)
PWL_ADD = (0, 0.113, 0.165, 0.238, 0.337, 0.468, 0.631, 0.813, 0.976, 1.022, 0.742, 0.16, 0)


def verilog_round(x: float) -> int:
    """Real -> integer conversion of Verilog: nearest, ties away from zero."""
    return int(math.copysign(math.floor(abs(x) + 0.5), x))


@dataclass
class RtlShifts:
    """Fractional bits (value = int * 2^-n) of every fixed-point tensor. Defaults: MAMBA.sv layer 0."""

    u: int = 5
    w_dt: int = 8
    dt_low: int = 6
    w_B: int = 8
    B: int = 6
    w_C: int = 8
    C: int = 5
    w_dtp: int = 8
    bias: int = 8
    delta: int = 4
    A: int = 3
    dA: int = 7
    dB: int = 3
    D: int = 6
    y: int = 3

    def check(self) -> None:
        """Every shift the RTL builds must be non-negative (shifter_left/right take a count)."""
        s = self
        right = {
            "dt_low": s.u + s.w_dt - s.dt_low, "B": s.u + s.w_B - s.B, "C": s.u + s.w_C - s.C,
            "delta": s.dt_low + s.w_dtp - s.delta, "dA": 2 * (s.delta + s.A) - s.dA,
            "dB": s.delta + s.B - s.dB, "y": s.u + s.dA + s.dB + s.C - s.y,
        }
        left = {"bias": s.dt_low + s.w_dtp - s.bias, "Du": s.dA + s.dB + s.C - s.D}
        bad = {k: v for k, v in {**right, **left}.items() if v < 0 or (k in right and v == 0)}
        if bad:
            raise ValueError(f"shift configuration not realisable by the RTL shifters: {bad}")

    def to_dict(self) -> dict[str, int]:
        return asdict(self)


def rshr(x: torch.Tensor, s: int) -> torch.Tensor:
    """RTL shifter_right: floor(x / 2^s) + bit s-1 of x == floor((x + 2^(s-1)) / 2^s)."""
    if s <= 0:
        return x << (-s)
    return (x + (1 << (s - 1))) >> s


def sat8(x: torch.Tensor) -> torch.Tensor:
    return x.clamp(-128, 127)


def sat(x: torch.Tensor, bits: int) -> torch.Tensor:
    return x.clamp(-(1 << (bits - 1)), (1 << (bits - 1)) - 1)


def wrap(x: torch.Tensor, bits: int | None) -> torch.Tensor:
    if bits is None:
        return x
    half = 1 << (bits - 1)
    return ((x + half) & ((1 << bits) - 1)) - half


TENSORS = ("u", "dt_low", "B", "C", "delta", "dA", "dB", "y")


@dataclass(frozen=True)
class RtlVariant:
    """Deviations from the original RTL for ablations. The default IS the original RTL.

    exp:     "rtl" (Exp_piecewise, [-4, 1]), "python" (current eMamba custom_exp,
             [-9.871, 0]) or "exact" (true exp, rounded to the dA format)
    wrap_ax: Ax register of width bits(dB)+bits(u)+dA(+h_frac) wraps, as in the RTL
             (DATA_WIDTH_BU_LSH = 23 for the 8-bit design); False = unbounded
    h_frac:  extra fractional bits kept in the state register (0 in the RTL)
    bits:    widths of individual tensors, e.g. (("dB", 16),); all 8 in the RTL
    """

    exp: str = "rtl"
    wrap_ax: bool = True
    h_frac: int = 0
    bits: tuple = ()

    def width(self, name: str) -> int:
        return dict(self.bits).get(name, 8)

    @property
    def is_rtl(self) -> bool:
        return self == RtlVariant()


def exp_pwl_lut(shifts: RtlShifts, device=None, variant: RtlVariant = RtlVariant()) -> tuple[torch.Tensor, int]:
    """dA for every possible p = delta*A (delta x int8 A), as a LUT indexed by p + offset."""
    s_in = shifts.delta + shifts.A
    offset = (1 << (variant.width("delta") - 1)) * 128
    p = torch.arange(-offset, offset + 1, dtype=torch.int64)
    if variant.exp == "rtl":
        k = 2 ** s_in
        ifs = [verilog_round(k * v) for v in PWL_IF]
        mult = [verilog_round(k * v) for v in PWL_MULT]
        add = [verilog_round(k * k * v) for v in PWL_ADD]
        out = torch.full_like(p, mult[12])                     # x > IF[11]
        for seg in range(11, 0, -1):                           # IF[seg-1] < x <= IF[seg] -> segment seg+1
            out = torch.where(p <= ifs[seg], mult[seg] * p + add[seg], out)
        out = torch.where(p < ifs[0], torch.zeros_like(out), out)
        lut = rshr(out, 2 * s_in - shifts.dA)
    else:
        x = p.double() * 2.0 ** -s_in
        if variant.exp == "python":
            from ultralytics.nn.modules.emamba_ss2d import pwl_exp
            f = pwl_exp(x)
        elif variant.exp == "exact":
            f = torch.exp(x)
        else:
            raise ValueError(f"unknown exp variant {variant.exp!r}")
        lut = torch.floor(f * 2.0 ** shifts.dA + 0.5).long()
    return sat(lut, variant.width("dA")).to(device=device, dtype=torch.int32), offset


@dataclass
class CoreParams:
    """Integer parameters of one core invocation (one direction of one SS2D layer)."""

    w_dt: torch.Tensor    # (R, ED)      x_proj rows for dt
    w_B: torch.Tensor     # (N, ED)
    w_C: torch.Tensor     # (N, ED)
    w_dtp: torch.Tensor   # (ED, R)      dt_proj
    bias: torch.Tensor    # (ED,)
    A: torch.Tensor       # (ED, N)
    D: torch.Tensor       # (ED,)


def record_max(stats: dict | None, name: str, value: torch.Tensor) -> None:
    if stats is not None:
        stats[name] = max(stats.get(name, 0), int(value.abs().max()))


def record_sat(stats: dict | None, name: str, before: torch.Tensor, after: torch.Tensor) -> None:
    if stats is not None:
        hit, total = stats.get(name, (0, 0))
        stats[name] = (hit + int((before != after).sum()), total + before.numel())


def preprocess(u: torch.Tensor, p: CoreParams, s: RtlShifts, variant: RtlVariant = RtlVariant(),
               lin_acc_bits: int | None = None, stats: dict | None = None):
    """x_proj / dt_proj / ReLU. ``u`` is (..., L, ED) int. Returns delta, B, C as int64.

    ``stats`` (optional) collects max |accumulator| ("acc_*") and saturation counts ("sat_*").
    """
    def matmul(x, w):  # exact: |sum| < 2^53
        return torch.matmul(x.double(), w.double().T).round().long()

    def linear(name, acc, shift, bits):
        record_max(stats, f"acc_{name}", acc)
        shifted = rshr(wrap(acc, lin_acc_bits), shift)
        out = sat(shifted, bits)
        record_sat(stats, f"sat_{name}", shifted, out)
        return out

    w = variant.width
    u = u.long()
    dt_low = linear("dt_low", matmul(u, p.w_dt), s.u + s.w_dt - s.dt_low, w("dt_low"))
    B = linear("B", matmul(u, p.w_B), s.u + s.w_B - s.B, w("B"))
    C = linear("C", matmul(u, p.w_C), s.u + s.w_C - s.C, w("C"))
    acc = matmul(dt_low, p.w_dtp) + (p.bias.long() << (s.dt_low + s.w_dtp - s.bias))
    dt = linear("dt", acc, s.dt_low + s.w_dtp - s.delta, w("delta"))
    return dt.clamp_min(0), B, C


def scan_shifts(s: RtlShifts, variant: RtlVariant, n_state: int = 16) -> dict[str, int]:
    h = variant.h_frac
    # The golden model computes in int64. x_k+1 carries bits(dB)+bits(u)+dA+h plus up to
    # ~8 bits of growth from the recurrence, and y sums bits(C)-bit products over N states.
    need = variant.width("dB") + variant.width("u") + s.dA + h + 8 + variant.width("C") + math.ceil(math.log2(n_state))
    if need > 62:
        raise ValueError(f"variant {variant} needs ~{need}-bit accumulators; the int64 golden model would overflow")
    return {
        "db": s.delta + s.B - s.dB,               # delta*B -> dB
        "bu": s.dA + h,                           # dB*u aligned to dA*x_k
        "xk": s.dA,                               # x_k+1 -> x_k
        "du": s.dA + s.dB + s.C - s.D + h,        # D*u aligned to C*x_k+1
        "y": s.u + s.dA + s.dB + s.C - s.y + h,   # -> y
        "ax_bits": variant.width("dB") + variant.width("u") + s.dA + h if variant.wrap_ax else None,
    }


def scan_reference(u, delta, B, C, A, D, s: RtlShifts, variant: RtlVariant = RtlVariant()):
    """Token loop exactly as SSM_Preprocess (dA, dB) + SSM_Computation.

    u, delta: (..., L, ED)   B, C: (..., L, N)   A: (ED, N)   D: (ED,)   -> y (..., L, ED) int64
    """
    lut, offset = exp_pwl_lut(s, u.device, variant)
    sh = scan_shifts(s, variant)
    u, delta, B, C = u.long(), delta.long(), B.long(), C.long()
    A, D = A.long(), D.long()
    xk = torch.zeros((*u.shape[:-2], u.shape[-1], A.shape[-1]), dtype=torch.int64, device=u.device)
    ys = []
    for t in range(u.shape[-2]):
        d_t, u_t = delta[..., t, :], u[..., t, :]
        dA = lut[(d_t.unsqueeze(-1) * A + offset)].long()                                  # (..., ED, N)
        dB = sat(rshr(d_t.unsqueeze(-1) * B[..., t, :].unsqueeze(-2), sh["db"]), variant.width("dB"))
        xkp1 = wrap(dA * xk, sh["ax_bits"]) + ((dB * u_t.unsqueeze(-1)) << sh["bu"])
        xk = rshr(xkp1, sh["xk"])
        acc = (C[..., t, :].unsqueeze(-2) * xkp1).sum(-1) + ((D * u_t) << sh["du"])
        ys.append(sat(rshr(acc, sh["y"]), variant.width("y")))
    return torch.stack(ys, dim=-2)


def core_reference(u, p: CoreParams, s: RtlShifts, variant: RtlVariant = RtlVariant(),
                   lin_acc_bits: int | None = None):
    """Full SSM module: int8 u (..., L, ED) -> int8 y (..., L, ED)."""
    delta, B, C = preprocess(u, p, s, variant, lin_acc_bits)
    return scan_reference(u, delta, B, C, p.A, p.D, s, variant)
