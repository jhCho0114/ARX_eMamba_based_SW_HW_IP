`timescale 1ns / 1ps
// emy_gather : input address generator of the shared-engine eMambaYOLO (docs/ENGINE_SPEC.md §7.5), used inside emy_gemm
//
// (a) What it does
//   For each requested pixel it names, one word per clock, the buffer words that make up the pixel's input vector, in
//   the GEMM weight column order: taps (dy, dx) in raster order outside; inside a tap the CW0 = ceil(C0 / 8) channel
//   words of source 0, then the CW1 = ceil(C1 / 8) words of source 1 (F_SRC1_EN). Words per pixel = taps x (CW0 + CW1).
//     tap position (y, x) = (ho*S - P + dy, wo*S - P + dx); outside [0, H) x [0, W): w_zero = 1 (the caller does not
//                           read and uses 0, or -128 for MaxPool)
//     source pixel        = y*W + x, or (y >> 1)*(W >> 1) + (x >> 1) with M_UP0 / M_UP1 (that source is W/2 wide)
//     word address        = src.addr + pix * CW + cw,  w_buf = src.buf_id,  w_src = source number,  w_last = last word
//     ([Jae 2026-10-18] src0 pitch: for source 0 the pixel pitch is cmd.shift_aux words when it is non-zero, else CW = ceil(c_in/8);
//      the words read per pixel stay ceil(c_in/8).  DtProj reads the dt part (R channels) of the xp row of pitch XPW.)
//   Kernels (misc[2:0]): KN_1X1 K1 S1 P0, KN_3X3_S1 K3 S1 P1, KN_3X3_S2 K3 S2 P1, KN_2X2_S2 K2 S2 P0, KN_5X5_S1 K5 S1 P2;
//   output width Wo = (W + 2P - K) / S + 1.
//   px_idx:  AM_RASTER (am0)          = absolute output raster pixel ho*Wo + wo (the caller walks its row window)
//            AM_GROUP / AM_PERM (am0) = token t (0..7) of group group_g, mapped per source: am = AM_PERM -> pixel
//                                       p_k(8g + t) of direction dir_k (k0 p = l, k1 p = (l mod H)*W + l div H,
//                                       k2 p = L-1-l, k3 p = p_1(L-1-l), L = H*W), otherwise t (the token's WORK row).
//                                       Token modes are 1x1 only.
// (b) Command fields: src0 / src1 (buf id + word base), c_in = C0, prm2[15:0] = C1 (only with F_SRC1_EN), w / h
//     (logical input size), misc kernel / am0 / am1 / M_UP0 / M_UP1, flags F_SRC1_EN; dir_k, group_g. tile_r0 is not
//     needed (raster px_idx is absolute). All other fields are ignored.
// (c) IMG: none.
// (d) Cycles: init + 2 clk set-up; then taps x (CW0 + CW1) clk per pixel, pixels back to back (the next request is
//     accepted with the last word of the current pixel); 4 clk from the accept to the first word. A request that does
//     not follow the previous one (raster px_idx != previous + 1, the first raster request of a command when it is not
//     pixel 0, and the first token of a k1 / k3 AM_PERM command) costs one 20-step division (px_idx / Wo or l / H): +22 clk.
//     Measured: whole frame = words + 8 clk (e.g. L00 conv0 921,600 words in 921,608 clk), a CrossScan group of 8 tokens
//     = 8 * CW + 8 clk (k0 / k2) or + 30 clk (k1 / k3).
//
// Interface beyond the address stream (for the caller):
//   init  (in)  1-clk pulse per command: cmd / dir_k / group_g are latched; cmd may change afterwards. Clears the stream.
//   busy  (out) set-up, division, a pixel or a word in flight.
//   Limits: c_in, C1 <= 2040 (CW <= 255), token modes 1x1 only ($error in simulation, the caller treats them as no work).
//   px_valid / px_ready / px_idx: request (px_idx held while px_valid and not px_ready).
//   w_valid / w_ready: response, held while w_valid and not w_ready.
module emy_gather import emy_engine_pkg::*; (
    input  logic                  clk,
    input  logic                  nRst,

    input  logic                  init,
    input  cmd_t                  cmd,
    input  logic [15:0]           tile_r0,
    input  logic [1:0]            dir_k,
    input  logic [15:0]           group_g,
    output logic                  busy,

    input  logic                  px_valid,
    output logic                  px_ready,
    input  logic [BUF_ADDR_W-1:0] px_idx,

    output logic                  w_valid,
    input  logic                  w_ready,
    output logic [BUF_ID_W-1:0]   w_buf,
    output logic [BUF_ADDR_W-1:0] w_addr,
    output logic                  w_src,
    output logic                  w_zero,
    output logic                  w_last
);

// ---------- Local Parameters ---------- //
localparam int AW = BUF_ADDR_W;

// ---------- Command and derived sizes ---------- //
cmd_t          c;
logic [1:0]    k_q;
logic [15:0]   g_q;
logic [1:0]    cfg_n;                // set-up step after init (1, 2), 0 = done
logic          cfg_v;
logic [2:0]    km1;                  // K - 1
logic          s2;                   // stride 2
logic [1:0]    pd;                   // pad
logic [7:0]    cw0, cw1;             // channel words per tap of source 0 / 1 (words read per pixel)
logic [7:0]    pw0;                  // pixel pitch of source 0 in words: cmd.shift_aux when non-zero, else cw0 ([Jae 2026-10-18] src0 pitch)
logic          has1, up0, up1, tokm, perm0, perm1;
logic [15:0]   wo_n;                 // output width Wo
logic [AW-1:0] l0, lq, lend;         // first token 8g, L = H*W, L - 1 - 8g

// ---------- Tracker (coordinates of the next expected request) and divider ---------- //
logic          trk_v;
logic [AW-1:0] trk_i;
logic [15:0]   trk_a, trk_b;         // raster (ho, wo); AM_PERM k1 / k3 (l div H, l mod H)
logic          needs_trk, hit;
logic          dv_busy, dv_done;
logic [4:0]    dv_i;
logic [AW-1:0] dv_n, dv_q, dv_idx;
logic [16:0]   dv_r;
logic [15:0]   dv_d;

// ---------- Walker (stage 0) ---------- //
logic          wv;                   // a pixel is being walked
logic [AW-1:0] wt;                   // the request (token index in token modes)
logic [15:0]   wa, wb;               // its coordinates (tracker values at the accept)
logic [2:0]    dy, dx;
logic          sr;                   // source of the current word
logic [7:0]    cw;
logic          en;                   // the stream advances (output register free or taken)

// ---------- Stages 1, 2 ---------- //
logic          s1_v, s1_dir, s1_in, s1_src, s1_last;
logic [AW-1:0] s1_p;
logic [15:0]   s1_y, s1_x, s1_ws;
logic [7:0]    s1_cw;
logic          s2_v, s2_in, s2_src, s2_last;
logic [AW-1:0] s2_p;
// [Jae 2026-10-16] tile-relative sources (M_SRC0_REL / M_SRC1_REL, SPEC §5): pixel - (tile_r0 - HALO_ROWS) * W of that source;
//                  L00 input ring (src0.buf_id == BUF_IN, SPEC §4.4 / §7.5): row y mod IN_RING_ROWS, the words live in WORK.
logic [15:0]   r0_q;
logic          rel0, rel1, ring0;
logic [AW-1:0] off0, off1;            // (tile_r0 - HALO_ROWS) * W (two's complement; negative for tile_r0 = 0)
logic [7:0]    s2_cw;

// ========== ========== ========== Command latch and set-up ========== ========== ==========
function automatic logic [5:0] kdec(input logic [2:0] kn);       // {K-1, stride 2, pad}
    case (kn)
        KN_3X3_S1: kdec = {3'd2, 1'b0, 2'd1};
        KN_3X3_S2: kdec = {3'd2, 1'b1, 2'd1};
        KN_2X2_S2: kdec = {3'd1, 1'b1, 2'd0};
        KN_5X5_S1: kdec = {3'd4, 1'b0, 2'd2};
        default:   kdec = {3'd0, 1'b0, 2'd0};
    endcase
endfunction

always @(posedge clk) begin
    if (init) begin
        c    <= #1 cmd;
        k_q  <= #1 dir_k;
        g_q  <= #1 group_g;
        r0_q <= #1 tile_r0;
    end
end

always @(posedge clk) begin
    if (!nRst) begin
        cfg_n <= #1 2'd0;
        cfg_v <= #1 1'b0;
    end else if (init) begin
        cfg_n <= #1 2'd1;
        cfg_v <= #1 1'b0;
    end else if (cfg_n == 2'd1) begin
        cfg_n <= #1 2'd2;
    end else if (cfg_n == 2'd2) begin
        cfg_n <= #1 2'd0;
        cfg_v <= #1 1'b1;
    end
end

always @(posedge clk) begin
    if (cfg_n == 2'd1) begin
        {km1, s2, pd} <= #1 kdec(c.misc[M_KERNEL_LO +: 3]);
        cw0   <= #1 8'((c.c_in + 16'd7) >> 3);
        pw0   <= #1 (c.shift_aux != 8'sd0) ? 8'(c.shift_aux) : 8'((c.c_in + 16'd7) >> 3);
        cw1   <= #1 c.flags[F_SRC1_EN] ? 8'((c.prm2 + 16'd7) >> 3) : 8'd0;
        has1  <= #1 c.flags[F_SRC1_EN];
        up0   <= #1 c.misc[M_UP0];
        up1   <= #1 c.misc[M_UP1];
        tokm  <= #1 (c.misc[M_AM0_LO +: 2] != AM_RASTER);
        perm0 <= #1 (c.misc[M_AM0_LO +: 2] == AM_PERM);
        perm1 <= #1 (c.misc[M_AM1_LO +: 2] == AM_PERM);
        l0    <= #1 {g_q, 3'b000};
        lq    <= #1 AW'(c.h) * AW'(c.w);
        rel0  <= #1 c.misc[M_SRC0_REL] && (c.misc[M_AM0_LO +: 2] == AM_RASTER);
        rel1  <= #1 c.misc[M_SRC1_REL] && (c.misc[M_AM0_LO +: 2] == AM_RASTER);
        ring0 <= #1 (c.src0.buf_id == BUF_IN);
    end
    if (cfg_n == 2'd2) begin
        automatic logic [16:0] span;
        off0 <= #1 rel0 ? AW'(r0_q * (up0 ? {1'b0, c.w[15:1]} : c.w)) - AW'(HALO_ROWS * (up0 ? {1'b0, c.w[15:1]} : c.w)) : AW'(0);
        off1 <= #1 rel1 ? AW'(r0_q * (up1 ? {1'b0, c.w[15:1]} : c.w)) - AW'(HALO_ROWS * (up1 ? {1'b0, c.w[15:1]} : c.w)) : AW'(0);
        span = {1'b0, c.w} + {14'd0, pd, 1'b0} - {14'd0, km1} - 17'd1;   // W + 2P - K
        wo_n <= #1 (s2 ? span[16:1] : span[15:0]) + 16'd1;           // (W + 2P - K) / S + 1
        lend <= #1 lq - l0 - 1'b1;
    end
end

`ifndef SYNTHESIS
always @(posedge clk)
    if (cfg_n == 2'd1 && (c.c_in > 16'd2040 || (c.flags[F_SRC1_EN] && c.prm2 > 16'd2040) ||
                          (c.misc[M_AM0_LO +: 2] != AM_RASTER && c.misc[M_KERNEL_LO +: 3] != KN_1X1)))
        $error("emy_gather: unsupported command (c_in %0d, C1 %0d > 2040, or a token mode with kernel %0d)",
               c.c_in, c.prm2, c.misc[M_KERNEL_LO +: 3]);
`endif

// ========== ========== ========== Tracker and divider ========== ========== ==========
assign needs_trk = !tokm || (k_q[0] && (perm0 || (has1 && perm1)));
assign hit       = !needs_trk || (trk_v && px_idx == trk_i);

wire dv_start = cfg_v && px_valid && !hit && !dv_busy && !dv_done;
wire [AW-1:0] dv_dividend = !tokm ? px_idx : (k_q[1] ? lend - px_idx : l0 + px_idx);

always @(posedge clk) begin
    if (!nRst || init) begin
        dv_busy <= #1 1'b0;
        dv_done <= #1 1'b0;
    end else begin
        dv_done <= #1 dv_busy && (dv_i == 5'(AW - 1));
        if (dv_start) begin
            dv_busy <= #1 1'b1;
            dv_i    <= #1 '0;
            dv_n    <= #1 dv_dividend;
            dv_q    <= #1 '0;
            dv_r    <= #1 '0;
            dv_d    <= #1 tokm ? c.h : wo_n;
            dv_idx  <= #1 px_idx;
        end else if (dv_busy) begin
            automatic logic [16:0] t;
            t = {dv_r[15:0], dv_n[AW-1]};
            dv_n <= #1 {dv_n[AW-2:0], 1'b0};
            if (t >= {1'b0, dv_d}) begin dv_r <= #1 t - {1'b0, dv_d}; dv_q <= #1 {dv_q[AW-2:0], 1'b1}; end
            else begin dv_r <= #1 t; dv_q <= #1 {dv_q[AW-2:0], 1'b0}; end
            dv_i <= #1 dv_i + 1'b1;
            if (dv_i == 5'(AW - 1)) dv_busy <= #1 1'b0;
        end
    end
end

wire acc_px;
always @(posedge clk) begin
    if (!nRst) begin
        trk_v <= #1 1'b0;
    end else if (init) begin
        trk_v <= #1 1'b0;
    end else if (cfg_n == 2'd1) begin                 // raster commands start at pixel 0 = (0, 0)
        trk_v <= #1 (c.misc[M_AM0_LO +: 2] == AM_RASTER);
        trk_i <= #1 '0;
        trk_a <= #1 '0;
        trk_b <= #1 '0;
    end else if (dv_done) begin
        trk_v <= #1 1'b1;
        trk_i <= #1 dv_idx;
        trk_a <= #1 dv_q[15:0];
        trk_b <= #1 dv_r[15:0];
    end else if (acc_px && needs_trk) begin
        trk_i <= #1 px_idx + 1'b1;
        if (!tokm) begin                               // raster: next column
            if (trk_b == wo_n - 1'b1) begin trk_b <= #1 '0; trk_a <= #1 trk_a + 1'b1; end
            else trk_b <= #1 trk_b + 1'b1;
        end else if (!k_q[1]) begin                    // k1: l + 1
            if (trk_b == c.h - 1'b1) begin trk_b <= #1 '0; trk_a <= #1 trk_a + 1'b1; end
            else trk_b <= #1 trk_b + 1'b1;
        end else begin                                 // k3: (L-1-l) - 1
            if (trk_b == 16'd0) begin trk_b <= #1 c.h - 1'b1; trk_a <= #1 trk_a - 1'b1; end
            else trk_b <= #1 trk_b - 1'b1;
        end
    end
end

// ========== ========== ========== Stage 0: walker ========== ========== ==========
wire [7:0] cwn     = sr ? cw1 : cw0;
wire       cw_end  = (cw == cwn - 1'b1);
wire       src_end = !has1 || sr;
wire       tap_end = (dy == km1) && (dx == km1);
wire       w_end   = cw_end && src_end && tap_end;           // the walker's word is the last of the pixel

assign en       = !w_valid || w_ready;
assign px_ready = cfg_v && en && hit && (!wv || w_end);
assign acc_px   = px_valid && px_ready;

always @(posedge clk) begin
    if (!nRst || init) begin
        wv <= #1 1'b0;
    end else if (en) begin
        if (acc_px) begin
            wv <= #1 1'b1;
            wt <= #1 px_idx;
            wa <= #1 trk_a;
            wb <= #1 trk_b;
            dy <= #1 '0; dx <= #1 '0; sr <= #1 1'b0; cw <= #1 '0;
        end else if (wv) begin
            if (w_end) wv <= #1 1'b0;
            if (!cw_end) cw <= #1 cw + 1'b1;
            else begin
                cw <= #1 '0;
                if (has1 && !sr) sr <= #1 1'b1;
                else begin
                    sr <= #1 1'b0;
                    if (dx != km1) dx <= #1 dx + 1'b1;
                    else begin dx <= #1 '0; dy <= #1 dy + 1'b1; end
                end
            end
        end
    end
end

// ========== ========== ========== Stage 1: tap position / token mapping ========== ========== ==========
wire               s_perm = sr ? perm1 : perm0;
wire               s_up   = sr ? up1 : up0;
wire [16:0]        ya     = s2 ? {wa, 1'b0} : {1'b0, wa};
wire [16:0]        xa     = s2 ? {wb, 1'b0} : {1'b0, wb};
wire signed [18:0] ty     = $signed({2'b00, ya}) + $signed({16'd0, dy}) - $signed({17'd0, pd});
wire signed [18:0] tx     = $signed({2'b00, xa}) + $signed({16'd0, dx}) - $signed({17'd0, pd});

always @(posedge clk) begin
    if (!nRst || init) s1_v <= #1 1'b0;
    else if (en)       s1_v <= #1 wv;
    if (en) begin
        s1_src  <= #1 sr;
        s1_cw   <= #1 cw;
        s1_last <= #1 w_end;
        if (!tokm) begin
            s1_dir <= #1 1'b0;
            s1_in  <= #1 (ty >= 0) && (ty < $signed({3'b000, c.h})) && (tx >= 0) && (tx < $signed({3'b000, c.w}));
            s1_y   <= #1 s_up ? ty[16:1] : ty[15:0];
            s1_x   <= #1 s_up ? tx[16:1] : tx[15:0];
            s1_ws  <= #1 s_up ? {1'b0, c.w[15:1]} : c.w;
        end else begin
            s1_in  <= #1 1'b1;
            s1_dir <= #1 !(s_perm && k_q[0]);                         // k1 / k3: pixel = (l mod H) * W + l div H
            s1_p   <= #1 !s_perm ? wt : (k_q[1] ? lend - wt : l0 + wt);
            s1_y   <= #1 wb;
            s1_x   <= #1 wa;
            s1_ws  <= #1 c.w;
        end
    end
end

// ========== ========== ========== Stage 2: pixel index ========== ========== ==========
always @(posedge clk) begin
    if (!nRst || init) s2_v <= #1 1'b0;
    else if (en)       s2_v <= #1 s1_v;
    if (en) begin
        s2_in   <= #1 s1_in;
        s2_src  <= #1 s1_src;
        s2_cw   <= #1 s1_cw;
        s2_last <= #1 s1_last;
        s2_p    <= #1 s1_dir ? s1_p
                            : AW'((ring0 && !s1_src) ? (s1_y % IN_RING_ROWS) : s1_y) * AW'(s1_ws) + AW'(s1_x) - (s1_src ? off1 : off0);
    end
end

// ========== ========== ========== Stage 3: word address (output register) ========== ========== ==========
always @(posedge clk) begin
    if (!nRst || init) w_valid <= #1 1'b0;
    else if (en)       w_valid <= #1 s2_v;
    if (en) begin
        w_src  <= #1 s2_src;
        w_zero <= #1 !s2_in;
        w_last <= #1 s2_last;
        w_buf  <= #1 s2_src ? c.src1.buf_id : (ring0 ? BUF_WORK : c.src0.buf_id);
        w_addr <= #1 (s2_src ? c.src1.addr : c.src0.addr) + s2_p * AW'(s2_src ? cw1 : pw0) + AW'(s2_cw);   // [Jae 2026-10-18] src0 pitch
    end
end

assign busy = (cfg_n != 2'd0) || dv_busy || dv_done || wv || s1_v || s2_v || w_valid;

endmodule
