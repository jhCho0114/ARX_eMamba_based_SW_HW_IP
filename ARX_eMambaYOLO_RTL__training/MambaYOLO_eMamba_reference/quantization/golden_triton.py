"""Triton version of ``golden.scan_reference`` for long sequences (L up to 25600).

One program per sequence row (batch x direction x channel); the token loop and the
N states live inside the kernel. All arithmetic is int64, so the result is
identical to the PyTorch reference, just without thousands of kernel launches.
"""

from __future__ import annotations

import torch
import triton
import triton.language as tl

from .golden import RtlShifts, RtlVariant, exp_pwl_lut, scan_shifts


@triton.jit
def _rshr(x, s: tl.constexpr):
    return (x + (1 << (s - 1))) >> s


@triton.jit
def _scan_kernel(
    U, DELTA, BM, CM, A, D, LUT, Y, STATS,
    L, ED, rows_per_group,
    LUT_OFFSET: tl.constexpr, N: tl.constexpr,
    SH_DB: tl.constexpr, SH_BU: tl.constexpr, SH_XK: tl.constexpr, LSH_DU: tl.constexpr, RSH_Y: tl.constexpr,
    AX_BITS: tl.constexpr, WRAP_AX: tl.constexpr, DB_MAX: tl.constexpr, Y_MAX: tl.constexpr,
    DA_MAX: tl.constexpr, COLLECT: tl.constexpr,
):
    row = tl.program_id(0)          # (group, channel) with group = batch x direction
    group = row // ED
    param_row = (row % rows_per_group)  # direction x channel index into A / D
    n = tl.arange(0, N)
    a = tl.load(A + param_row * N + n).to(tl.int64)
    dd = tl.load(D + param_row).to(tl.int64)
    xk = tl.zeros([N], dtype=tl.int64)
    m_xk = tl.zeros([N], dtype=tl.int64)     # max |x_k|, |dA*x_k| (before wrap), |x_k+1|
    m_ax = tl.zeros([N], dtype=tl.int64)
    m_xkp1 = tl.zeros([N], dtype=tl.int64)
    m_acc = tl.zeros([1], dtype=tl.int64)    # max |C.x_k+1 + D*u| before the y shift
    n_db = tl.zeros([N], dtype=tl.int64)     # saturation counts
    n_da = tl.zeros([N], dtype=tl.int64)
    n_y = tl.zeros([1], dtype=tl.int64)
    for t in range(0, L):
        u = tl.load(U + row * L + t).to(tl.int64)
        delta = tl.load(DELTA + row * L + t).to(tl.int64)
        b = tl.load(BM + (group * L + t) * N + n).to(tl.int64)
        c = tl.load(CM + (group * L + t) * N + n).to(tl.int64)
        da = tl.load(LUT + delta * a + LUT_OFFSET).to(tl.int64)
        db_raw = _rshr(delta * b, SH_DB)
        db = tl.minimum(tl.maximum(db_raw, -DB_MAX - 1), DB_MAX)
        ax = da * xk
        if COLLECT:
            m_xk = tl.maximum(m_xk, tl.abs(xk))
            m_ax = tl.maximum(m_ax, tl.abs(ax))
            n_db += (db_raw != db).to(tl.int64)
            n_da += (da >= DA_MAX).to(tl.int64)
        if WRAP_AX:
            ax = ((ax + (1 << (AX_BITS - 1))) & ((1 << AX_BITS) - 1)) - (1 << (AX_BITS - 1))
        xkp1 = ax + ((db * u) << SH_BU)
        xk = _rshr(xkp1, SH_XK)
        acc = tl.sum(c * xkp1, axis=0) + ((dd * u) << LSH_DU)
        y_raw = _rshr(acc, RSH_Y)
        y = tl.minimum(tl.maximum(y_raw, -Y_MAX - 1), Y_MAX)
        tl.store(Y + row * L + t, y.to(tl.int32))
        if COLLECT:
            m_xkp1 = tl.maximum(m_xkp1, tl.abs(xkp1))
            m_acc = tl.maximum(m_acc, tl.abs(acc))
            n_y += (y_raw != y).to(tl.int64)
    if COLLECT:
        one = tl.arange(0, 1)
        base = STATS + row * 7
        tl.store(base + 0 + one, tl.max(m_xk, axis=0) + one * 0)
        tl.store(base + 1 + one, tl.max(m_ax, axis=0) + one * 0)
        tl.store(base + 2 + one, tl.max(m_xkp1, axis=0) + one * 0)
        tl.store(base + 3 + one, m_acc)
        tl.store(base + 4 + one, tl.sum(n_db, axis=0) + one * 0)
        tl.store(base + 5 + one, tl.sum(n_da, axis=0) + one * 0)
        tl.store(base + 6 + one, n_y)


def scan_triton(u, delta, B, C, A, D, s: RtlShifts, variant: RtlVariant = RtlVariant(), stats: dict | None = None):
    """Same contract as ``golden.scan_reference`` with a direction axis.

    u, delta: (G, ED, L)  with G = batch x K groups
    B, C:     (G, L, N)
    A:        (K, ED, N)  D: (K, ED)   (group g uses parameter set g % K)
    returns y: (G, ED, L) int32
    """
    G, ED, L = u.shape
    K, _, N = A.shape
    if N & (N - 1):
        raise ValueError("d_state must be a power of two")
    lut, offset = exp_pwl_lut(s, u.device, variant)
    sh = scan_shifts(s, variant)
    y = torch.empty((G, ED, L), dtype=torch.int32, device=u.device)
    out_stats = torch.zeros((G * ED, 7) if stats is not None else (1,), dtype=torch.int64, device=u.device)
    _scan_kernel[(G * ED,)](
        u.int().contiguous(), delta.int().contiguous(), B.int().contiguous(), C.int().contiguous(),
        A.int().contiguous(), D.int().contiguous(), lut, y, out_stats,
        L, ED, K * ED,
        LUT_OFFSET=offset, N=N,
        SH_DB=sh["db"], SH_BU=sh["bu"], SH_XK=sh["xk"], LSH_DU=sh["du"], RSH_Y=sh["y"],
        AX_BITS=sh["ax_bits"] or 0, WRAP_AX=sh["ax_bits"] is not None,
        DB_MAX=(1 << (variant.width("dB") - 1)) - 1, Y_MAX=(1 << (variant.width("y") - 1)) - 1,
        DA_MAX=(1 << (variant.width("dA") - 1)) - 1, COLLECT=stats is not None,
    )
    if stats is not None:
        mx = out_stats.max(0).values.tolist()
        sm = out_stats.sum(0).tolist()
        for i, name in enumerate(("max_xk", "max_ax", "max_xkp1", "max_yacc")):
            stats[name] = max(stats.get(name, 0), mx[i])
        for i, (name, per_token) in enumerate((("sat_dB", N), ("sat_dA", N), ("sat_y", 1)), start=4):
            hit, total = stats.get(name, (0, 0))
            stats[name] = (hit + sm[i], total + G * ED * L * per_token)
    return y
