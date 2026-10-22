`timescale 1ns / 1ps
// emy_vec : the vector engine of the shared-engine eMambaYOLO (docs/ENGINE_SPEC.md §7.4), 8 lanes = one 64-bit word per cycle
//
//   One command = up to two sources, a per-source requant (shift0 / shift1), one operation, an output requant (shift_out)
//   to int8 (optionally through the SiLU table, optionally ReLU) or to wide (16 bit). The pixels of the row window
//   [tile_r0 + row_lo, tile_r0 + row_hi) ∩ [0, H) (AM_RASTER), the 8 tokens of a group (AM_GROUP: token index, AM_PERM:
//   CrossScan pixel p_k of direction dir_k) are walked word by word (8 channels, NCH = ceil(c_in / 8) words per pixel).
//
//   op            per lane                                                        sources   flags / shifts
//   VEC_RQ        out = rq(x0, shift_out) after x0 = rq(in0, shift0)              in0       OUT_WIDE keeps 16 bit
//   VEC_SILU      out = tab[rq8(rq(in0, shift0), shift_out)]                      in0       prm = IMG line of the 256-B table
//   VEC_ADD       out = rq(rq(in0, shift0) + rq(in1, shift1), shift_out) [SiLU]   in0, in1  ACC_INIT: in1 taken as 0 (CrossMerge first direction)
//   VEC_MUL       out = rq(rq(in0, shift0) * rq(in1, shift1), shift_out)          in0, in1
//   VEC_LN        LightNormInt over the channels of each pixel (two passes)        in0       prm = w, b, INV table; shift_aux = LSH, shift_out = RSH
//   VEC_MAXPOOL   out = rq(max of the 5x5 taps (outside = -128) of rq(in0,...))   in0       raster only
//   rq(x, s) = emy_requant: sat(rshr(x, s)) to 16 bit (lanes), rq8 = to int8. Wide sources (M_SRC0_WIDE / M_SRC1_WIDE) and
//   a wide output take two words per 8 channels; the word walk then runs two sub-steps per channel group.
//   Lanes beyond c_in in the last word are written as 0.  dst pitch = ceil(c_out / 8) words (x2 wide): with c_out > c_in a copy
//   lands in a channel sub-range of a wider tensor.  M_SRC0_REL / M_SRC1_REL / M_DST_REL: tile-relative operand, pixel
//   p - (tile_r0 - HALO_ROWS) * w (the region holds rows [tile_r0 - HALO_ROWS, tile_r0 + TILE_ROWS + HALO_ROWS)).
//
//   Buffer ports: two read ports (2-cycle latency) and one write port, IMG line read (2-cycle latency). cmd_ready while idle,
//   done = one-cycle pulse after the last write. tile_r0 / dir_k / group_g are the sequencer's loop counters.
//   LightNorm: C = c_in must be a power of two (the mean is a shift), as in LightNormInt.
//   OUTROWS: a plain copy (shift 0) to BUF_OUT; dst.addr = head << OUT_HEAD_SHIFT, word = pixel * ceil(C/8) + j = 64-byte row * 8 + k.
//            Words are issued only while out_room = 1 (the adapter's FIFO must hold the DRAIN words in flight).
module emy_vec import emy_pkg::*; import emy_engine_pkg::*; (
    input  logic clk,
    input  logic nRst,

    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  cmd_t        cmd,
    input  logic [15:0] tile_r0,
    input  logic [1:0]  dir_k,
    input  logic [15:0] group_g,
    output logic        done,

    output logic                  rd0_en,
    output logic [BUF_ID_W-1:0]   rd0_buf,
    output logic [BUF_ADDR_W-1:0] rd0_addr,
    input  logic [WORD_W-1:0]     rd0_data,
    output logic                  rd1_en,
    output logic [BUF_ID_W-1:0]   rd1_buf,
    output logic [BUF_ADDR_W-1:0] rd1_addr,
    input  logic [WORD_W-1:0]     rd1_data,
    output logic                  wr_en,
    output logic [BUF_ID_W-1:0]   wr_buf,
    output logic [BUF_ADDR_W-1:0] wr_addr,
    output logic [WORD_W-1:0]     wr_data,
    output logic [7:0]            wr_be,

    output logic                  img_en,
    output logic [IMG_ADDR_W-1:0] img_addr,
    input  logic [IMG_LINE_W-1:0] img_data,

    input  logic                  out_room      // OUTROWS only: the BRAM_OUT adapter can take the next word (SPEC §7.4 / §10)
);

// ---------- Local Parameters ---------- //
localparam int NCH_W  = 8;                 // channel words per pixel (<= 176)
localparam int RES_W  = 33;                // op result (16 x 16 product)
localparam int LN_D_W = 20;                // |C * q - S| <= 2^9 * 255 * 2
localparam int LN_W   = 40;                // d * INV and the affine accumulator (LightNormInt WIDE)
localparam int DRAIN  = 15;                // issue -> P1 -> P2 (request) -> 2 clk data -> mA .. mE + LN pass 1 ([Jae 2026-10-18] address pipeline; was 12)
                                           // deepest write: LN pass 2 n6 = issue + 12 ([Jae 2026-10-21] LN output register) < S_DONE at issue + 17
localparam int PIX_W  = 18;                // pixel / token index: L00 phase 0 addresses 320 x 320 = 102,400 pixels (SPEC §4.4, §7.1)

typedef enum logic [3:0] {S_IDLE, S_LATCH, S_PARAM, S_DIV, S_RUN, S_LN_WAIT, S_LN_LUT, S_DRAIN, S_DONE} state_t;
state_t state;

// ---------- Command registers ---------- //
cmd_t  c;
logic [15:0] r0_q, g_q;
logic [1:0]  k_q;
logic        is_rq, is_silu, is_add, is_mul, is_ln, is_mp, is_out;
logic        wide0, wide1, owide, src1_en, acc_init, f_silu, f_relu;
logic        rel0, rel1, reld;                 // tile-relative operands (M_SRC0_REL / M_SRC1_REL / M_DST_REL)
logic [19:0] p_off;                            // (tile_r0 - HALO_ROWS) * w, two's complement
logic [PIX_W-1:0] hw1_q;                       // (h - 1) * w: perm walk k3 row wrap ([Jae 2026-10-18] address pipeline)
logic [1:0]  am0, am1, amd;
logic [NCH_W-1:0] nch;                     // words per pixel (int8 view)
logic [3:0]  rem;                          // channels in the last word (1..8)
logic        nsub2;                        // two sub-steps per channel group
logic [NCH_W:0] pw0, pw1, pwd;             // pitch (words per pixel) per operand
logic signed [17:0] hs, he;                // row window
logic [31:0] L_q;                          // H * W
logic [PIX_W-1:0] l0;                      // first token of the group
logic [3:0]  nl;                           // tokens in the group
logic [3:0]  K_q;                          // log2(c_in) for LightNorm
logic [PIX_W-1:0] p_end;

// ---------- Walk registers ---------- //
logic [PIX_W-1:0] p;                       // raster pixel
logic [15:0] hh, ww;                       // its row / column
logic [3:0]  tok;                          // token in the group
logic [15:0] q_div, r_div;                 // perm: quotient / remainder of the token index by H
logic [PIX_W-1:0] p_perm;                  // perm token's pixel, kept by the walk (no multiplier at issue time; [Jae 2026-10-18] address pipeline)
logic [NCH_W-1:0] j;
logic        sub;
logic [4:0]  tap;
logic        pass;                         // LightNorm: 0 = statistics, 1 = normalise
logic [5:0]  wait_cnt;

// divider (restoring, PIX_W steps): l0 / H or (L - 1 - l0) / H
logic [PIX_W-1:0] dv_n, dv_q;
logic [PIX_W:0]   dv_r;
logic [4:0]  dv_i;

// ---------- Parameter memories ---------- //
logic [7:0]  silu_tab [0:255];
logic [63:0] ln_w [0:63];                  // up to 512 channels: 64 words of 8 weights
logic [63:0] ln_b [0:63];
logic [31:0] ln_lut [0:255];
logic [7:0]  prm_i, prm_n, prm_i_d, prm_i_d2;
logic        prm_v_d, prm_v_d2;                 // IMG read latency 2
logic [7:0]  lw_lines;                     // lines of w (= of b): ceil(nch / 4)

// ---------- Pipeline meta ---------- //
typedef struct packed {
    logic        v;          // a read / step issued
    logic        grp_last;   // last sub-step of the channel group (the group is complete)
    logic        tap_v;      // maxpool: the tap is inside the map
    logic        tap_first;
    logic        tap_last;
    logic        sub;
    logic        pass;
    logic        pix_first;  // first group of the pixel (LightNorm statistics reset)
    logic [NCH_W-1:0] j;
    logic [7:0]  mask;       // valid lanes
    logic [BUF_ADDR_W-1:0] wbase;
} meta_t;
meta_t mR, mA, mB, mC, mD, mE;             // mR: read data in flight ([Jae 2026-10-18] buffer read latency 2)

// stage B: lanes assembled from the words
logic signed [15:0] inA0 [0:7], inA1 [0:7];
logic signed [15:0] in0_hold [0:7], in1_hold [0:7];
// stage C: requantised lanes
logic signed [15:0] a0 [0:7], a1 [0:7];
logic signed [7:0]  a0_8 [0:7];
logic signed [15:0] a0_rq [0:7], a1_rq [0:7];
logic signed [15:0] mx [0:7];
// stage D / E
logic signed [RES_W-1:0] res [0:7];
logic signed [15:0] o16 [0:7];
logic signed [7:0]  o8 [0:7];
logic [63:0] wd_lo, wd_hi;
logic        pend_v;
logic [BUF_ADDR_W-1:0] pend_addr;
logic [63:0] pend_data;

// LightNorm
logic signed [11:0] g_sum;
logic signed [7:0]  g_max, g_min;
logic               g_v, g_first;
logic signed [19:0] sum_acc, sum_q;
logic signed [7:0]  max_acc, min_acc;
logic [8:0]         range_q;
logic [31:0]        lut_q;
logic               n1, n2, n3, n4, n5, n6;
logic [NCH_W-1:0]   kj1, kj2, kj3, kj4, kj5;
logic [BUF_ADDR_W-1:0] kw1, kw2, kw3, kw4, kw5, kw6;
logic [7:0]         km1, km2, km3, km4, km5, km6;
logic signed [LN_D_W-1:0] d1 [0:7];
logic signed [LN_W-1:0]   p2 [0:7], z3 [0:7], m4 [0:7], acc5 [0:7];
logic signed [7:0]        y5 [0:7], y6 [0:7];      // y6: requant output registered ([Jae 2026-10-21] LN output register)
logic [63:0] w_q, b_q;

// ========== ========== ========== Command decode ========== ========== ==========
assign cmd_ready = (state == S_IDLE);

function automatic logic [3:0] clog2_16(input logic [15:0] x);
    clog2_16 = 0;
    for (int i = 15; i >= 0; i--) if (x[i]) begin clog2_16 = i[3:0]; break; end
endfunction

always @(posedge clk) begin
    if (state == S_IDLE && cmd_valid) begin
        c    <= #1 cmd;
        r0_q <= #1 tile_r0;
        k_q  <= #1 dir_k;
        g_q  <= #1 group_g;
    end
end

wire [7:0]  fl = c.flags;
wire [15:0] ms = c.misc;
always @(*) begin
    is_out   = (c.op == OP_VEC_OUTROWS);
    is_rq    = (c.op == OP_VEC_RQ) || is_out;
    is_silu  = (c.op == OP_VEC_SILU);
    is_add   = (c.op == OP_VEC_ADD);
    is_mul   = (c.op == OP_VEC_MUL);
    is_ln    = (c.op == OP_VEC_LN);
    is_mp    = (c.op == OP_VEC_MAXPOOL);
    wide0    = ms[M_SRC0_WIDE];
    wide1    = ms[M_SRC1_WIDE];
    owide    = fl[F_OUT_WIDE];
    src1_en  = fl[F_SRC1_EN] && (is_add || is_mul);
    acc_init = fl[F_ACC_INIT];
    f_silu   = fl[F_SILU] || is_silu;
    f_relu   = fl[F_RELU];
    am0      = ms[M_AM0_LO +: 2];
    am1      = ms[M_AM1_LO +: 2];
    amd      = ms[M_AMD_LO +: 2];
    rel0     = ms[M_SRC0_REL];
    rel1     = ms[M_SRC1_REL];
    reld     = ms[M_DST_REL];
end

// derived sizes (registered in S_LATCH)
always @(posedge clk) begin
    if (state == S_LATCH) begin
        nch   <= #1 NCH_W'((c.c_in + 7) >> 3);
        rem   <= #1 (c.c_in[2:0] == 3'd0) ? 4'd8 : {1'b0, c.c_in[2:0]};
        nsub2 <= #1 (wide0 || (wide1 && src1_en) || owide) && !is_mp;
        pw0   <= #1 wide0 ? (((c.c_in + 7) >> 3) << 1) : ((c.c_in + 7) >> 3);   // wide: 2 words per 8 channels
        pw1   <= #1 wide1 ? (((c.c_in + 7) >> 3) << 1) : ((c.c_in + 7) >> 3);
        pwd   <= #1 owide ? (((c.c_out + 7) >> 3) << 1) : ((c.c_out + 7) >> 3);   // dst pitch from c_out (a copy into a channel sub-range of a wider tensor)
        p_off <= #1 20'(r0_q * c.w) - 20'(HALO_ROWS * c.w);      // two's complement; negative for tile_r0 = 0
        hw1_q <= #1 PIX_W'((c.h - 1) * c.w);
        hs    <= #1 ($signed({2'b0, r0_q}) + 18'(c.row_lo) < 0) ? 18'sd0 : ($signed({2'b0, r0_q}) + 18'(c.row_lo));
        he    <= #1 (c.row_hi <= 0 || $signed({2'b0, r0_q}) + 18'(c.row_hi) > $signed({2'b0, c.h})) ? $signed({2'b0, c.h}) : ($signed({2'b0, r0_q}) + 18'(c.row_hi));   // row_hi <= 0: to the end of the map
        L_q   <= #1 c.h * c.w;
        l0    <= #1 PIX_W'({g_q, 3'b000});
        K_q   <= #1 clog2_16(c.c_in);
        lw_lines <= #1 8'((((c.c_in + 7) >> 3) + 3) >> 2);
    end
end
wire [PIX_W-1:0] n_tok_left = (L_q > l0) ? PIX_W'(L_q - l0) : '0;
wire        use_tok    = (am0 != AM_RASTER) || (amd != AM_RASTER) || (src1_en && am1 != AM_RASTER);
wire        no_work    = use_tok ? (n_tok_left == 0) : (he <= hs);
wire        use_perm   = (am0 == AM_PERM) || (amd == AM_PERM) || (src1_en && am1 == AM_PERM);
wire        prm_done   = (prm_i == prm_n) && !prm_v_d && !prm_v_d2;
wire        init_walk  = (state == S_PARAM && prm_done && !no_work && !use_perm) || (state == S_DIV && dv_i == 5'(PIX_W));

// ========== ========== ========== FSM ========== ========== ==========
wire grp_done  = is_mp ? (tap == 5'd24) : (!nsub2 || sub);
wire pix_done  = grp_done && (j == nch - 1);
wire walk_end  = use_tok ? (tok == nl - 1) : (p == p_end - 1);
wire ln_p1_end = is_ln && pix_done && !pass;
wire issue     = (state == S_RUN) && (!is_out || out_room);     // OUTROWS pauses while the BRAM_OUT adapter is full

always @(posedge clk) begin
    if (!nRst) begin
        state <= #1 S_IDLE;
        done  <= #1 1'b0;
    end else begin
        done <= #1 1'b0;
        case (state)
            S_IDLE:  if (cmd_valid) state <= #1 S_LATCH;
            S_LATCH: state <= #1 S_PARAM;
            S_PARAM: if (prm_done) state <= #1 (no_work ? S_DONE : (use_perm ? S_DIV : S_RUN));
            S_DIV:   if (dv_i == 5'(PIX_W)) state <= #1 S_RUN;
            S_RUN: begin
                if (issue && ln_p1_end)                 state <= #1 S_LN_WAIT;
                else if (issue && pix_done && walk_end) state <= #1 S_DRAIN;
            end
            S_LN_WAIT: if (wait_cnt == 6'd7) state <= #1 S_LN_LUT;       // sum_acc of the last group lands at issue + 8 ([Jae 2026-10-18] address pipeline: was 5)
            S_LN_LUT:  if (wait_cnt == 6'd2) state <= #1 S_RUN;
            S_DRAIN:   if (wait_cnt == DRAIN) state <= #1 S_DONE;
            S_DONE: begin done <= #1 1'b1; state <= #1 S_IDLE; end
            default: state <= #1 S_IDLE;
        endcase
    end
end

always @(posedge clk) begin
    if      (state == S_LN_WAIT) wait_cnt <= #1 (wait_cnt == 6'd7) ? 6'd0 : wait_cnt + 1'b1;
    else if (state == S_LN_LUT)  wait_cnt <= #1 (wait_cnt == 6'd2) ? 6'd0 : wait_cnt + 1'b1;
    else if (state == S_DRAIN)   wait_cnt <= #1 wait_cnt + 1'b1;
    else                         wait_cnt <= #1 '0;
end

// ========== ========== ========== Parameter fetch (IMG lines) ========== ========== ==========
always @(*) begin
    prm_n = 8'd0;
    if (is_silu || (fl[F_SILU] && is_add)) prm_n = 8'd8;
    if (is_ln) prm_n = 8'd32 + {lw_lines, 1'b0};
end
assign img_en   = (state == S_PARAM) && (prm_i < prm_n);
assign img_addr = c.prm + prm_i;
always @(posedge clk) begin
    if (state == S_LATCH) prm_i <= #1 '0;
    else if (img_en) prm_i <= #1 prm_i + 1'b1;
    prm_v_d  <= #1 img_en;
    prm_i_d  <= #1 prm_i;
    prm_v_d2 <= #1 prm_v_d;            // the IMG line arrives two clocks after img_en ([Jae 2026-10-18] buffer read latency 2)
    prm_i_d2 <= #1 prm_i_d;
    if (prm_v_d2) begin
        if (is_silu || is_add) begin
            for (int b = 0; b < 32; b++) silu_tab[{prm_i_d2[2:0], b[4:0]}] <= #1 img_data[8*b +: 8];
        end
        if (is_ln) begin
            if (prm_i_d2 < lw_lines)
                for (int q = 0; q < 4; q++) ln_w[(prm_i_d2 << 2) + q] <= #1 img_data[64*q +: 64];
            else if (prm_i_d2 < (lw_lines << 1))
                for (int q = 0; q < 4; q++) ln_b[((prm_i_d2 - lw_lines) << 2) + q] <= #1 img_data[64*q +: 64];
            else
                for (int e = 0; e < 8; e++) ln_lut[((prm_i_d2 - (lw_lines << 1)) << 3) + e] <= #1 img_data[32*e +: 32];
        end
    end
end

// ========== ========== ========== Perm divider and walk ========== ========== ==========
// token index of the first token of the group in the direction's order: k1 counts up from l0, k3 counts down from L-1-l0
wire [PIX_W-1:0] dv_start = (k_q == 2'd3) ? PIX_W'(L_q - 1 - l0) : l0;
always @(posedge clk) begin
    if (state == S_PARAM) begin
        dv_i <= #1 '0; dv_q <= #1 '0; dv_r <= #1 '0; dv_n <= #1 dv_start;
    end else if (state == S_DIV && dv_i < 5'(PIX_W)) begin
        automatic logic [PIX_W:0] t;
        t = {dv_r[PIX_W-1:0], dv_n[PIX_W-1]};
        dv_n <= #1 {dv_n[PIX_W-2:0], 1'b0};
        if (t >= (PIX_W+1)'(c.h)) begin dv_r <= #1 t - (PIX_W+1)'(c.h); dv_q <= #1 {dv_q[PIX_W-2:0], 1'b1}; end
        else begin dv_r <= #1 t; dv_q <= #1 {dv_q[PIX_W-2:0], 1'b0}; end
        dv_i <= #1 dv_i + 1'b1;
    end
end

// p_perm = l0 + tok (k0) | r_div * w + q_div (k1, k3) | L - 1 - l0 - tok (k2): one multiply at init_walk, then +-1 / +-w per pixel
always @(posedge clk) begin
    if (init_walk) begin
        q_div <= #1 dv_q[15:0]; r_div <= #1 dv_r[15:0];
        p_perm <= #1 (k_q == 2'd0) ? l0 : (k_q == 2'd2) ? PIX_W'(L_q - 1 - l0) : PIX_W'(dv_r[15:0] * c.w + dv_q[15:0]);
        p     <= #1 PIX_W'(hs * c.w); hh <= #1 hs[15:0]; ww <= #1 '0;
        p_end <= #1 PIX_W'(he * c.w);
        nl    <= #1 (n_tok_left >= 8) ? 4'd8 : n_tok_left[3:0];
        tok   <= #1 '0; j <= #1 '0; sub <= #1 1'b0; tap <= #1 '0; pass <= #1 1'b0;
    end else if (issue) begin
        // inner walk: sub-step / tap, then channel word, then pixel
        if (is_mp) tap <= #1 (tap == 5'd24) ? 5'd0 : tap + 1'b1;
        else sub <= #1 nsub2 ? ~sub : 1'b0;
        if (grp_done) begin
            j <= #1 (j == nch - 1) ? '0 : j + 1'b1;
            if (j == nch - 1) begin
                if (is_ln && !pass) begin
                    pass <= #1 1'b1;                       // same pixel again (normalise pass)
                end else begin
                    pass <= #1 1'b0;
                    p <= #1 p + 1'b1;
                    if (ww == c.w - 1) begin ww <= #1 '0; hh <= #1 hh + 1'b1; end else ww <= #1 ww + 1'b1;
                    tok <= #1 tok + 1'b1;
                    case (k_q)
                        2'd0: p_perm <= #1 p_perm + 1'b1;
                        2'd2: p_perm <= #1 p_perm - 1'b1;
                        2'd1: if (r_div == c.h - 1) begin r_div <= #1 '0; q_div <= #1 q_div + 1'b1; p_perm <= #1 PIX_W'(q_div + 1'b1); end
                              else begin r_div <= #1 r_div + 1'b1; p_perm <= #1 p_perm + PIX_W'(c.w); end
                        default: if (r_div == 16'd0) begin r_div <= #1 c.h - 1; q_div <= #1 q_div - 1'b1; p_perm <= #1 hw1_q + PIX_W'(q_div) - 1'b1; end
                                 else begin r_div <= #1 r_div - 1'b1; p_perm <= #1 p_perm - PIX_W'(c.w); end
                    endcase
                end
            end
        end
    end
end

// ========== ========== ========== Stage A: addresses ========== ========== ==========
// (all operands as arguments: a continuous assignment with a function call is re-evaluated only when its arguments change)
function automatic logic [PIX_W-1:0] psel(input logic [1:0] am, input logic [PIX_W-1:0] p_r, input logic [3:0] tok_r, input logic [PIX_W-1:0] p_perm_r);
    case (am)
        AM_GROUP: psel = PIX_W'(tok_r);
        AM_PERM:  psel = p_perm_r;
        default:  psel = p_r;
    endcase
endfunction

// maxpool tap position
wire signed [4:0]  tdy = $signed({2'b0, tap / 5}) - 5'sd2;
wire signed [4:0]  tdx = $signed({2'b0, tap % 5}) - 5'sd2;
wire signed [17:0] th  = $signed({2'b0, hh}) + 18'(tdy);
wire signed [17:0] tw  = $signed({2'b0, ww}) + 18'(tdx);
wire               tap_in = (th >= 0) && (th < $signed({2'b0, c.h})) && (tw >= 0) && (tw < $signed({2'b0, c.w}));
// tap pixel = p + tdy * w + tdx (p = hh * w + ww by the walk); tdy * w from a 5-entry table, no multiplier ([Jae 2026-10-18] address pipeline)
wire signed [20:0] tdy_w = (tap < 5'd5)  ? -$signed({3'b0, c.w, 1'b0}) : (tap < 5'd10) ? -$signed({4'b0, c.w}) :
                           (tap < 5'd15) ? 21'sd0 : (tap < 5'd20) ? $signed({4'b0, c.w}) : $signed({3'b0, c.w, 1'b0});
wire [PIX_W-1:0]   p_tap  = PIX_W'($signed({3'b0, p}) + tdy_w + 21'(tdx));

wire [PIX_W-1:0] p0 = is_mp ? p_tap : psel(am0, p, tok, p_perm);
wire [PIX_W-1:0] p1 = psel(am1, p, tok, p_perm);
wire [PIX_W-1:0] pdst = psel(amd, p, tok, p_perm);
// tile-relative operands: pixel p - (tile_r0 - HALO_ROWS) * w (20-bit two's complement; the generator keeps the result in range)
wire [19:0] p0r = rel0 ? (20'(p0) - p_off) : 20'(p0);
wire [19:0] p1r = rel1 ? (20'(p1) - p_off) : 20'(p1);
wire [19:0] pdr = reld ? (20'(pdst) - p_off) : 20'(pdst);
wire rd0_now = issue && (is_mp ? tap_in : (wide0 || !sub));
wire rd1_now = issue && src1_en && !acc_init && (wide1 || !sub);

wire [7:0] lane_mask = (j == nch - 1) ? ((rem == 4'd8) ? 8'hff : 8'((1 << rem) - 1)) : 8'hff;

// Request pipeline ([Jae 2026-10-18] address pipeline): the xcku19p synthesis missed 10 ns on
//   perm multiply -> psel -> - p_off -> * pitch -> + base -> emy_buf switch -> URAM address.  Now:
//   P1 (issue + 1): pixel offsets p0r / p1r / pdr and word offsets registered;
//   P2 (issue + 2): addr = base + p_r * pitch + word (multiplier with registered inputs and outputs) -> rd*_en / rd*_addr to emy_buf;
//   data arrives two clocks after P2 (buffer read latency 2) = stage A.  Meta: mP1 -> mP2 (wbase) -> mR -> mA.
logic            p1_rd0, p1_rd1;
logic [19:0]     p1_p0r, p1_p1r, p1_pdr;
logic [NCH_W:0]  p1_o0, p1_o1, p1_od;
logic            rd0_en_q, rd1_en_q;
logic [BUF_ADDR_W-1:0] rd0_addr_q, rd1_addr_q;
meta_t mP1, mP2;
always @(posedge clk) begin
    if (!nRst) begin p1_rd0 <= #1 1'b0; p1_rd1 <= #1 1'b0; mP1.v <= #1 1'b0; end
    else begin p1_rd0 <= #1 rd0_now; p1_rd1 <= #1 rd1_now; mP1.v <= #1 issue; end
    p1_p0r <= #1 p0r;  p1_p1r <= #1 p1r;  p1_pdr <= #1 pdr;
    p1_o0  <= #1 wide0 ? {j, sub} : {1'b0, j};
    p1_o1  <= #1 wide1 ? {j, sub} : {1'b0, j};
    p1_od  <= #1 owide ? {j, 1'b0} : {1'b0, j};
    mP1.grp_last  <= #1 grp_done;
    mP1.tap_v     <= #1 tap_in;
    mP1.tap_first <= #1 (tap == 5'd0);
    mP1.tap_last  <= #1 (tap == 5'd24);
    mP1.sub       <= #1 sub;
    mP1.pass      <= #1 pass;
    mP1.pix_first <= #1 (j == 0);                     // evaluated at the group's last sub-step (LightNorm statistics reset)
    mP1.j         <= #1 j;
    mP1.mask      <= #1 lane_mask;
    mP1.wbase     <= #1 '0;
end
always @(posedge clk) begin
    if (!nRst) begin rd0_en_q <= #1 1'b0; rd1_en_q <= #1 1'b0; mP2.v <= #1 1'b0; mR.v <= #1 1'b0; end
    else begin rd0_en_q <= #1 p1_rd0; rd1_en_q <= #1 p1_rd1; mP2.v <= #1 mP1.v; mR.v <= #1 mP2.v; end
    rd0_addr_q <= #1 c.src0.addr + BUF_ADDR_W'(p1_p0r * pw0) + BUF_ADDR_W'(p1_o0);
    rd1_addr_q <= #1 c.src1.addr + BUF_ADDR_W'(p1_p1r * pw1) + BUF_ADDR_W'(p1_o1);
    mP2.grp_last <= #1 mP1.grp_last;  mP2.tap_v <= #1 mP1.tap_v;  mP2.tap_first <= #1 mP1.tap_first;  mP2.tap_last <= #1 mP1.tap_last;
    mP2.sub <= #1 mP1.sub;  mP2.pass <= #1 mP1.pass;  mP2.pix_first <= #1 mP1.pix_first;  mP2.j <= #1 mP1.j;  mP2.mask <= #1 mP1.mask;
    mP2.wbase  <= #1 c.dst.addr + BUF_ADDR_W'(p1_pdr * pwd) + BUF_ADDR_W'(p1_od);
    mR.grp_last <= #1 mP2.grp_last;  mR.tap_v <= #1 mP2.tap_v;  mR.tap_first <= #1 mP2.tap_first;  mR.tap_last <= #1 mP2.tap_last;
    mR.sub <= #1 mP2.sub;  mR.pass <= #1 mP2.pass;  mR.pix_first <= #1 mP2.pix_first;  mR.j <= #1 mP2.j;  mR.mask <= #1 mP2.mask;
    mR.wbase <= #1 mP2.wbase;
end
assign rd0_en = rd0_en_q;  assign rd0_buf = c.src0.buf_id;  assign rd0_addr = rd0_addr_q;
assign rd1_en = rd1_en_q;  assign rd1_buf = c.src1.buf_id;  assign rd1_addr = rd1_addr_q;
always @(posedge clk) mA <= #1 mR;                   // stage A sees the words two clocks after the P2 request (four after the issue)

// ========== ========== ========== Stage B: lanes from the words (data of the issue four cycles earlier) ========== ==========
always @(*) begin
    for (int i = 0; i < 8; i++) begin
        inA0[i] = in0_hold[i];
        inA1[i] = in1_hold[i];
        if (is_mp) begin
            inA0[i] = mA.tap_v ? 16'($signed(rd0_data[8*i +: 8])) : -16'sd128;
        end else if (wide0) begin
            if (!mA.sub && i < 4) inA0[i] = $signed(rd0_data[16*i +: 16]);
            if ( mA.sub && i >= 4) inA0[i] = $signed(rd0_data[16*(i-4) +: 16]);
        end else if (!mA.sub) begin
            inA0[i] = 16'($signed(rd0_data[8*i +: 8]));
        end
        if (acc_init || !src1_en) begin
            inA1[i] = '0;
        end else if (wide1) begin
            if (!mA.sub && i < 4) inA1[i] = $signed(rd1_data[16*i +: 16]);
            if ( mA.sub && i >= 4) inA1[i] = $signed(rd1_data[16*(i-4) +: 16]);
        end else if (!mA.sub) begin
            inA1[i] = 16'($signed(rd1_data[8*i +: 8]));
        end
    end
end
always @(posedge clk) begin
    if (mA.v) begin
        for (int i = 0; i < 8; i++) begin in0_hold[i] <= #1 inA0[i]; in1_hold[i] <= #1 inA1[i]; end
    end
    mB   <= #1 mA;
    mB.v <= #1 mA.v && (is_mp || mA.grp_last);           // a complete channel group (or a tap)
end

// ========== ========== ========== Stage C: input requant ========== ========== ==========
genvar gi;
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin: RQ_IN
        emy_requant #(.IN_W(16), .OUT_W(16)) rq0 (.din(in0_hold[gi]), .shift(c.shift0), .dout(a0_rq[gi]));
        emy_requant #(.IN_W(16), .OUT_W(16)) rq1 (.din(in1_hold[gi]), .shift(c.shift1), .dout(a1_rq[gi]));
    end
endgenerate
function automatic logic signed [7:0] sat8_16(input logic signed [15:0] x);
    if (x > 16'sd127) sat8_16 = 8'sd127; else if (x < -16'sd128) sat8_16 = -8'sd128; else sat8_16 = x[7:0];
endfunction
always @(posedge clk) begin
    if (mB.v) begin
        for (int i = 0; i < 8; i++) begin
            a0[i]   <= #1 a0_rq[i];
            a1[i]   <= #1 a1_rq[i];
            a0_8[i] <= #1 sat8_16(a0_rq[i]);
            if (is_mp) mx[i] <= #1 mB.tap_first ? a0_rq[i] : ((a0_rq[i] > mx[i]) ? a0_rq[i] : mx[i]);
        end
    end
    mC   <= #1 mB;
    mC.v <= #1 mB.v && (!is_mp || mB.tap_last);
end

// ========== ========== ========== Stage D: the operation ========== ========== ==========
always @(posedge clk) begin
    if (mC.v) begin
        for (int i = 0; i < 8; i++) begin
            if (is_add)      res[i] <= #1 RES_W'(a0[i]) + RES_W'(a1[i]);
            else if (is_mul) res[i] <= #1 RES_W'(a0[i] * a1[i]);
            else if (is_mp)  res[i] <= #1 RES_W'(mx[i]);
            else             res[i] <= #1 RES_W'(a0[i]);
        end
    end
    mD <= #1 mC;
end

// ========== ========== ========== Stage E: output requant, SiLU table, ReLU ========== ========== ==========
logic signed [15:0] o16_rq [0:7];
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin: RQ_OUT
        emy_requant #(.IN_W(RES_W), .OUT_W(16)) rqo (.din(res[gi]), .shift(c.shift_out), .dout(o16_rq[gi]));
    end
endgenerate
always @(posedge clk) begin
    if (mD.v) begin
        for (int i = 0; i < 8; i++) begin
            automatic logic signed [7:0] v8;
            v8 = sat8_16(o16_rq[i]);
            if (f_silu) v8 = silu_tab[{~v8[7], v8[6:0]}];
            if (f_relu && v8 < 0) v8 = 8'sd0;
            o8[i]  <= #1 mD.mask[i] ? v8 : 8'sd0;
            o16[i] <= #1 mD.mask[i] ? o16_rq[i] : 16'sd0;
        end
    end
    mE <= #1 mD;
end

// ========== ========== ========== LightNorm back end (from a0_8 of stage C) ========== ========== ==========
// pass 0: per group sum / max / min (registered), accumulated over the pixel's groups
always @(posedge clk) begin
    automatic logic signed [11:0] s;
    automatic logic signed [7:0]  x, n;
    s = '0; x = -8'sd128; n = 8'sd127;
    for (int i = 0; i < 8; i++) begin
        s = s + 12'(a0_8[i]);
        if (a0_8[i] > x) x = a0_8[i];
        if (a0_8[i] < n) n = a0_8[i];
    end
    g_v     <= #1 mC.v && is_ln && !mC.pass;
    g_first <= #1 mC.pix_first;
    g_sum   <= #1 s;  g_max <= #1 x;  g_min <= #1 n;
    if (g_v) begin
        if (g_first) begin sum_acc <= #1 20'(g_sum); max_acc <= #1 g_max; min_acc <= #1 g_min; end
        else begin
            sum_acc <= #1 sum_acc + 20'(g_sum);
            if (g_max > max_acc) max_acc <= #1 g_max;
            if (g_min < min_acc) min_acc <= #1 g_min;
        end
    end
    // LUT[R] out of its memory, then a register (state S_LN_LUT: cnt 0 latch range, 1 read, 2 register)
    if (state == S_LN_LUT && wait_cnt == 6'd0) begin sum_q <= #1 sum_acc; range_q <= #1 9'(max_acc) - 9'(min_acc); end
    if (state == S_LN_LUT && wait_cnt == 6'd1) lut_q <= #1 ln_lut[range_q[7:0]];
end

// pass 1: d | d * LUT | trunc0 | * w | + (b << LSH) | rshr + sat8 | register (n6) -> write
//   [Jae 2026-10-21] LN output register: the xcku19p impl (10-19 +0.022 ns, 10-21 -0.126 ns) had its worst path acc5 -> rql
//   (round add + saturate) -> wd_ln -> engine write mux -> emy_buf switch -> ACC URAM cascade (35 levels, 10.1 ns).  The requant
//   result is now registered (y6 / km6 / kw6 / n6) and the LN word is written one clock later: mC = issue + 6, n6 = issue + 12,
//   still inside S_DRAIN (DRAIN = 15 -> S_DONE at issue + 17).
always @(posedge clk) begin
    n1 <= #1 mC.v && is_ln && mC.pass;  n2 <= #1 n1;  n3 <= #1 n2;  n4 <= #1 n3;  n5 <= #1 n4;  n6 <= #1 n5;
    kj1 <= #1 mC.j;  kj2 <= #1 kj1;  kj3 <= #1 kj2;  kj4 <= #1 kj3;  kj5 <= #1 kj4;
    kw1 <= #1 mC.wbase;  kw2 <= #1 kw1;  kw3 <= #1 kw2;  kw4 <= #1 kw3;  kw5 <= #1 kw4;  kw6 <= #1 kw5;
    km1 <= #1 mC.mask;  km2 <= #1 km1;  km3 <= #1 km2;  km4 <= #1 km3;  km5 <= #1 km4;  km6 <= #1 km5;
    for (int i = 0; i < 8; i++) y6[i] <= #1 y5[i];
    if (n2) w_q <= #1 ln_w[kj2[5:0]];          // used at n3 (as LightNormInt: w at k2, b at k3)
    if (n3) b_q <= #1 ln_b[kj3[5:0]];
    for (int i = 0; i < 8; i++) begin
        automatic logic signed [LN_W-1:0] ap;
        if (mC.v && is_ln && mC.pass) d1[i] <= #1 (LN_D_W'(a0_8[i]) <<< K_q) - LN_D_W'(sum_q);
        if (n1) p2[i] <= #1 d1[i] * $signed({1'b0, lut_q});
        if (n2) begin
            ap = (p2[i] < 0) ? -p2[i] : p2[i];
            z3[i] <= #1 (p2[i] < 0) ? -(ap >>> K_q) : (ap >>> K_q);
        end
        if (n3) m4[i] <= #1 z3[i] * $signed(w_q[8*i +: 8]);
        if (n4) acc5[i] <= #1 m4[i] + (LN_W'($signed(b_q[8*i +: 8])) <<< c.shift_aux);
    end
end
generate
    for (gi = 0; gi < 8; gi = gi + 1) begin: RQ_LN
        emy_requant #(.IN_W(LN_W), .OUT_W(8)) rql (.din(acc5[gi]), .shift(c.shift_out), .dout(y5[gi]));
    end
endgenerate

// ========== ========== ========== Stage F: write ========== ========== ==========
always @(*) begin
    for (int i = 0; i < 8; i++) wd_lo[8*i +: 8] = o8[i];
    for (int i = 0; i < 4; i++) begin wd_hi[16*i +: 16] = o16[i+4]; end
end
wire [63:0] wd_w0 = {o16[3], o16[2], o16[1], o16[0]};
wire [63:0] wd_ln = {km6[7] ? y6[7] : 8'd0, km6[6] ? y6[6] : 8'd0, km6[5] ? y6[5] : 8'd0, km6[4] ? y6[4] : 8'd0,
                     km6[3] ? y6[3] : 8'd0, km6[2] ? y6[2] : 8'd0, km6[1] ? y6[1] : 8'd0, km6[0] ? y6[0] : 8'd0};
always @(posedge clk) begin
    if (!nRst) pend_v <= #1 1'b0;
    else begin
        pend_v <= #1 mE.v && owide && !is_ln;
        if (mE.v && owide) begin pend_addr <= #1 mE.wbase + 1'b1; pend_data <= #1 wd_hi; end
    end
end
always @(*) begin
    wr_en = 1'b0; wr_addr = '0; wr_data = '0; wr_be = 8'hff; wr_buf = c.dst.buf_id;
    if (is_ln) begin
        if (n6) begin wr_en = 1'b1; wr_addr = kw6; wr_data = wd_ln; end     // [Jae 2026-10-21] LN output register (was n5 / kw5)
    end else if (pend_v) begin
        wr_en = 1'b1; wr_addr = pend_addr; wr_data = pend_data;
    end else if (mE.v) begin
        wr_en = 1'b1; wr_addr = mE.wbase; wr_data = owide ? wd_w0 : wd_lo;
    end
end

endmodule
