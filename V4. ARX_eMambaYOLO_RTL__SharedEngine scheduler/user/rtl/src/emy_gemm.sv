`timescale 1ns / 1ps
// emy_gemm : GEMM engine of the shared-engine eMambaYOLO (docs/ENGINE_SPEC.md §7.1), 8 pixels x 4 outputs x 8 inputs
//            = 256 MAC / clk, with its input address generator emy_gather (§7.5)
//
// (a) What it does
//   y[p][o] = relu?( sat8( rshr( sum_i W[o][i] * x[p][i] + bias[o], rshift[o] ) ) ) for every pixel p of the command,
//   output channel o < c_out, input column i < Cin_pad = taps x (CW0 + CW1) x 8 (the gather word order).
//   Input loader: emy_gather names the words of up to 8 pixels (raster: 8 consecutive output pixels of the row
//   window, the last block may be short; token modes: the nl = min(8, L - 8g) tokens of group g); each word is read
//   (rd0, latency 2 since 2026-10-18), requantised per lane with shift0 / shift1 (by w_src, emy_requant) to int8 (w_zero -> 0) and
//   written into the pixel's RAM. 8 pixel RAMs, two banks of 512 words each ([Jae 2026-10-19] was 256: the L21 Detect head's
//   3x3 convs on P5 read 9 x 256 channels = 288 words per pixel): the next block is loaded while the
//   current one is computed.
//   Compute: per output group og (4 channels) the NW = Cin_pad / 8 weight lines prm + og*NW + j (one IMG line per clk,
//   byte 8b + i = weight of output 4og + b, input column 8j + i) meet word j of all 8 pixels:
//   acc[8 pix][4 out] (34 bit) += sum of 8 products. Pipeline: issue | products | 8-term sum | accumulate (+ bias /
//   rshift read) | + bias (int32) | emy_requant(rshift[o]) -> sat8 -> ReLU (F_RELU), channels >= c_out -> 0.
//   Two output groups make one 8-channel word per pixel; the nb pixel words of a block are written one per clk.
//   Output word = dst + p_out * ceil(c_out / 8) + cw, p_out = absolute output pixel (AM_RASTER, and token modes with a
//   non-GROUP dst: token index 8g + t) or t (dst am = AM_GROUP). Full words (wr_be = ff), padding channels 0.
// (b) Command fields: op (OP_GEMM), flags F_RELU / F_SRC1_EN, shift0 / shift1 (input requant per source), c_in = C0,
//     c_out, w / h (logical input size; output Wo = (W + 2P - K)/S + 1, Ho likewise), row_lo / row_hi (AM_RASTER: output
//     rows [tile_r0 + row_lo, tile_r0 + row_hi) clipped to [0, Ho), row_hi <= 0 = to Ho), src0 / src1, dst, prm (IMG line
//     of the weights), prm2 (C1 with F_SRC1_EN; else the offset of the bias / rshift block when != 0), misc kernel /
//     am0 / am1 / amd / M_UP0 / M_UP1; tile_r0, dir_k, group_g. shift_out is not used; shift_aux = source-0 pixel pitch in words (0 = ceil(c_in/8)), consumed by emy_gather ([Jae 2026-10-18] src0 pitch).
//     Not supported, executed as no work (done without writes; $error in simulation): NW > 512, c_out = 0 or > 1408,
//     c_in or C1 = 0 or > 2040, a token mode with a kernel other than 1x1, dst am = AM_PERM, M_SRC0_WIDE / M_SRC1_WIDE
//     (GEMM reads int8 only).
// (c) IMG lines read: NL = ceil(c_out / 4) * NW weight lines from prm, for every block of 8 pixels; once per command
//     ceil(c_out / 8) bias lines (int32 x c_out, little-endian) then ceil(c_out / 32) rshift lines (int8 x c_out) from
//     aux = prm + prm2 (!F_SRC1_EN and prm2 != 0) or prm + NL. They are kept in internal memories (c_out <= 1408).
//     NW <= 512 ([Jae 2026-10-19] NW_MAX 256 -> 512 for the L21 head, +16 RAMB36; ENGINE_SPEC §7.1: model max 288).
// (d) Cycles per command ~ 6 (decode) + max(ceil(c_out/8) + ceil(c_out/32) bias / rshift lines, 8 * NW + 5 first block
//     load) + nblk * max(NL, 8 * NW) + 15 (pipeline, last pixel writes, done), nblk = ceil(pixels / 8). The loader runs
//     one block ahead, so a block costs NL when ceil(c_out / 4) >= 8; a one-block command (phase 2, 8 tokens) cannot
//     overlap its load: XProj ~ NL + 8 * ceil(D/8) + 27 (+ 22 for k1 / k3), DtProj ~ NL + max(fetch, 8 * NW + 5) + 23.
//     A raster command not starting at pixel 0 adds one 22-clk division in the gather. Two word captures (one per two
//     output groups, 8 pixel writes) are kept >= 8 clk apart: the issue holds back when NW < 4, and when ceil(c_out / 4)
//     is odd and NW < 8 (the last two groups each complete a word). Measured: L07 proj 102,683 (ideal 102,400), XProj
//     L07 1,307 / group (NL 768), DtProj L07 871 / group (NL 768).
module emy_gemm import emy_pkg::*; import emy_engine_pkg::*; (
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
    input  logic [IMG_LINE_W-1:0] img_data
);

// ---------- Local Parameters ---------- //
localparam int AW     = BUF_ADDR_W;
localparam int NPIX   = 8;                 // pixels per block
localparam int NOUT   = 4;                 // outputs per IMG line
localparam int NIN    = 8;                 // inputs per word
localparam int NW_MAX = 512;               // words per input vector (pixel RAM bank) ([Jae 2026-10-19] 256 -> 512: L21 head 3x3 at C = 256 = 288 words)
localparam int BL_MAX = 176;               // bias lines   (c_out <= 1408)
localparam int RL_MAX = 44;                // rshift lines
localparam int ACC_W  = 34;
localparam int SB_W   = ACC_W + 1;         // accumulator + bias

typedef enum logic [2:0] {S_IDLE, S_LATCH, S_RUN, S_DRAIN, S_DONE} state_t;
state_t state;

// ---------- Command registers ---------- //
cmd_t          c;
logic [15:0]   r0_q, g_q;
logic [1:0]    k_q;
logic [2:0]    lc;                         // decode step in S_LATCH
logic [2:0]    km1;                        // K - 1
logic          s2;                         // stride 2
logic [1:0]    pd;                         // pad
logic [4:0]    taps;
logic [7:0]    cw0, cw1;                   // channel words per tap of source 0 / 1
logic [9:0]    nw;                         // words per pixel = weight lines per output group (<= NW_MAX = 512)
logic [8:0]    ng;                         // output groups ceil(c_out / 4)
logic [7:0]    cwo;                        // output words per pixel ceil(c_out / 8) = bias lines
logic [5:0]    nrl;                        // rshift lines ceil(c_out / 32)
logic [8:0]    pf_n;                       // parameter lines
logic [5:0]    bad;                        // unsupported command (see header (b)): executed as no work
logic          tokm, amd_grp, f_relu;
logic [15:0]   ho_n, wo_n;
logic [AW-1:0] lq, l0;
logic signed [17:0] hs, he;
logic [3:0]    nl_tok;
logic [17:0]   nlines;                     // NL = ng * nw
logic [AW-1:0] npix, pstart, opix0;
logic [16:0]   nblk;
logic [IMG_ADDR_W-1:0] aux;

// ---------- Parameter fetch ---------- //
logic [8:0]    pf_i, pf_i_d, pf_i_d2;
logic          pf_v_d, pf_v_d2;              // IMG read latency 2 ([Jae 2026-10-18] buffer read latency 2)
logic [255:0]  bias_mem [0:BL_MAX-1];
logic [255:0]  rsh_mem  [0:RL_MAX-1];

// ---------- Loader ---------- //
logic          g_busy, g_px_valid, g_px_ready, g_w_valid, g_w_src, g_w_zero, g_w_last;
logic [AW-1:0] g_px_idx, g_w_addr;
logic [BUF_ID_W-1:0] g_w_buf;
logic [AW-1:0] qn, rn;                     // pixels requested / received
logic [8:0]    jw;                         // word of the pixel being received ([Jae 2026-10-19] 8 -> 9 bit, NW_MAX 512)
logic [16:0]   rdone;                      // blocks loaded
logic          ld1_v, ld1_zero, ld1_src, ld1_last;   // word in flight ([Jae 2026-10-18] buffer read latency 2)
logic [AW-1:0] ld1_pix;
logic [8:0]    ld1_j;
logic          ld_v, ld_zero, ld_src, ld_last;       // word here (rd0_data)
logic [AW-1:0] ld_pix;
logic [8:0]    ld_j;
logic signed [7:0] ld_lane [0:NIN-1];
logic [63:0]   ld_word;

// ---------- Compute ---------- //
logic [16:0]   cblk;                       // block being computed (= blocks fully issued)
logic [17:0]   wl;                         // weight line inside the block
logic [8:0]    og;                         // output group
logic [8:0]    jc;                         // word / line inside the group ([Jae 2026-10-19] 8 -> 9 bit, NW_MAX 512)
logic [3:0]    gap;                        // clocks since the last capture issue (saturates at 8)
logic [AW-1:0] crem;                       // pixels from the current block to the end
logic [AW-1:0] obase_b;                    // dst word of the current block's first pixel
logic [AW-1:0] offo;                       // [Jae 2026-10-16] M_DST_REL: (tile_r0 - HALO_ROWS) * Wo subtracted from the output pixel (SPEC §5)
wire  [63:0]   pdat [0:NPIX-1];

typedef struct packed {
    logic          v;
    logic          first;                  // first line of the output group
    logic          last;                   // last line of the output group
    logic          cap;                    // this group completes an output word
    logic [8:0]    og;
    logic [3:0]    nb;                     // pixels of the block
    logic [AW-1:0] obase;
} meta_t;
meta_t mI0, mI, mA, mB, mC, mD;           // mI0: IMG line in flight ([Jae 2026-10-18] buffer read latency 2)

logic signed [15:0]      prod [0:NPIX-1][0:NOUT-1][0:NIN-1];
logic signed [18:0]      dot  [0:NPIX-1][0:NOUT-1];
logic signed [ACC_W-1:0] acc  [0:NPIX-1][0:NOUT-1];
logic signed [SB_W-1:0]  sb   [0:NPIX-1][0:NOUT-1];
logic [255:0]            bias_q, rsh_q;
logic signed [7:0]       rs_d [0:NOUT-1];
wire  signed [7:0]       o8_rq [0:NPIX-1][0:NOUT-1];
logic signed [7:0]       o8   [0:NPIX-1][0:NOUT-1];
logic [31:0]             lo   [0:NPIX-1];
logic [63:0]             ob   [0:NPIX-1];
logic                    dr_v;
logic [2:0]              dr_k;
logic [3:0]              dr_nb;
logic [AW-1:0]           dr_addr;

// ========== ========== ========== Command decode ========== ========== ==========
assign cmd_ready = (state == S_IDLE);

function automatic logic [10:0] kdec(input logic [2:0] kn);       // {K-1, stride 2, pad, taps}
    case (kn)
        KN_3X3_S1: kdec = {3'd2, 1'b0, 2'd1, 5'd9};
        KN_3X3_S2: kdec = {3'd2, 1'b1, 2'd1, 5'd9};
        KN_2X2_S2: kdec = {3'd1, 1'b1, 2'd0, 5'd4};
        KN_5X5_S1: kdec = {3'd4, 1'b0, 2'd2, 5'd25};
        default:   kdec = {3'd0, 1'b0, 2'd0, 5'd1};
    endcase
endfunction

always @(posedge clk) begin
    if (state == S_IDLE && cmd_valid) begin
        c    <= #1 cmd;
        r0_q <= #1 tile_r0;
        k_q  <= #1 dir_k;
        g_q  <= #1 group_g;
    end
end

always @(posedge clk) begin
    case (lc)
        3'd0: begin
            {km1, s2, pd, taps} <= #1 kdec(c.misc[M_KERNEL_LO +: 3]);
            cw0     <= #1 8'((c.c_in + 16'd7) >> 3);
            cw1     <= #1 c.flags[F_SRC1_EN] ? 8'((c.prm2 + 16'd7) >> 3) : 8'd0;
            ng      <= #1 9'((c.c_out + 16'd3) >> 2);
            cwo     <= #1 8'((c.c_out + 16'd7) >> 3);
            nrl     <= #1 6'((c.c_out + 16'd31) >> 5);
            tokm    <= #1 (c.misc[M_AM0_LO +: 2] != AM_RASTER);
            amd_grp <= #1 (c.misc[M_AMD_LO +: 2] == AM_GROUP);
            f_relu  <= #1 c.flags[F_RELU];
            lq      <= #1 AW'(c.h) * AW'(c.w);
            l0      <= #1 {g_q, 3'b000};
            hs      <= #1 ($signed({2'b0, r0_q}) + 18'(c.row_lo) < 0) ? 18'sd0 : ($signed({2'b0, r0_q}) + 18'(c.row_lo));
        end
        3'd1: begin
            automatic logic [16:0] sw, sh;
            automatic logic [13:0] nwf;
            sw = {1'b0, c.w} + {14'd0, pd, 1'b0} - {14'd0, km1} - 17'd1;            // W + 2P - K
            sh = {1'b0, c.h} + {14'd0, pd, 1'b0} - {14'd0, km1} - 17'd1;
            wo_n   <= #1 (s2 ? sw[16:1] : sw[15:0]) + 16'd1;
            ho_n   <= #1 (s2 ? sh[16:1] : sh[15:0]) + 16'd1;
            nwf     = 14'(taps) * (14'(cw0) + 14'(cw1));
            nw     <= #1 nwf[9:0];
            bad    <= #1 {nwf > 14'd512,
                          c.c_out == 16'd0 || c.c_out > 16'd1408,
                          tokm && c.misc[M_KERNEL_LO +: 3] != KN_1X1,
                          c.misc[M_AMD_LO +: 2] == AM_PERM,
                          c.c_in == 16'd0 || c.c_in > 16'd2040 || (c.flags[F_SRC1_EN] && (c.prm2 == 16'd0 || c.prm2 > 16'd2040)),
                          c.misc[M_SRC0_WIDE] || c.misc[M_SRC1_WIDE]};
            nl_tok <= #1 (lq <= l0) ? 4'd0 : ((lq - l0 >= AW'(8)) ? 4'd8 : 4'(lq - l0));
            pf_n   <= #1 {1'b0, cwo} + {3'b0, nrl};
        end
        3'd2: begin
            nlines <= #1 18'(ng) * 18'(nw);
            he     <= #1 (c.row_hi <= 0 || $signed({2'b0, r0_q}) + 18'(c.row_hi) > $signed({2'b0, ho_n})) ?
                         $signed({2'b0, ho_n}) : ($signed({2'b0, r0_q}) + 18'(c.row_hi));
        end
        3'd3: begin
            npix   <= #1 (bad != '0) ? AW'(0) : tokm ? AW'(nl_tok) : ((he > hs) ? AW'(he - hs) * AW'(wo_n) : AW'(0));
            pstart <= #1 tokm ? AW'(0) : AW'(hs) * AW'(wo_n);
            aux    <= #1 (!c.flags[F_SRC1_EN] && c.prm2 != 16'd0) ? c.prm + IMG_ADDR_W'(c.prm2) : c.prm + IMG_ADDR_W'(nlines);
            offo   <= #1 (c.misc[M_DST_REL] && !tokm) ? AW'(r0_q * wo_n) - AW'(HALO_ROWS * wo_n) : AW'(0);
        end
        3'd4: begin
            opix0  <= #1 tokm ? (amd_grp ? AW'(0) : l0) : pstart;
            nblk   <= #1 17'((npix + AW'(7)) >> 3);
        end
        default: ;
    endcase
end

`ifndef SYNTHESIS
always @(posedge clk)
    if (state == S_LATCH && lc == 3'd2 && bad != '0)
        $error("emy_gemm: unsupported command, executed as no work (NW>512 %0d, c_out %0d, token kernel %0d, dst PERM %0d, c_in/C1 %0d, wide src %0d)",
               bad[5], bad[4], bad[3], bad[2], bad[1], bad[0]);
`endif

// ========== ========== ========== FSM ========== ========== ==========
wire pipe_busy = mI0.v || mI.v || mA.v || mB.v || mC.v || mD.v || dr_v;

always @(posedge clk) begin
    if (!nRst) begin
        state <= #1 S_IDLE;
        lc    <= #1 '0;
        done  <= #1 1'b0;
    end else begin
        done <= #1 1'b0;
        case (state)
            S_IDLE:  if (cmd_valid) begin state <= #1 S_LATCH; lc <= #1 '0; end
            S_LATCH: begin
                lc <= #1 lc + 1'b1;
                if (lc == 3'd5) state <= #1 (npix == '0) ? S_DONE : S_RUN;
            end
            S_RUN:   if (cblk == nblk) state <= #1 S_DRAIN;
            S_DRAIN: if (!pipe_busy) state <= #1 S_DONE;
            S_DONE:  begin done <= #1 1'b1; state <= #1 S_IDLE; end
            default: state <= #1 S_IDLE;
        endcase
    end
end

// ========== ========== ========== Bias / rshift fetch (IMG lines from aux) ========== ========== ==========
wire pf_issue = (state == S_RUN) && (pf_i < pf_n);
wire prm_done = (state == S_RUN) && (pf_i == pf_n) && !pf_v_d && !pf_v_d2;

always @(posedge clk) begin
    if (!nRst) begin pf_v_d <= #1 1'b0; pf_v_d2 <= #1 1'b0; end
    else begin pf_v_d <= #1 pf_issue; pf_v_d2 <= #1 pf_v_d; end
    if (state == S_LATCH) pf_i <= #1 '0;
    else if (pf_issue)    pf_i <= #1 pf_i + 1'b1;
    if (pf_issue) pf_i_d  <= #1 pf_i;
    if (pf_v_d)   pf_i_d2 <= #1 pf_i_d;
    if (pf_v_d2) begin
        if (pf_i_d2 < {1'b0, cwo}) bias_mem[pf_i_d2] <= #1 img_data;
        else                       rsh_mem[pf_i_d2 - {1'b0, cwo}] <= #1 img_data;
    end
end

// ========== ========== ========== Input loader (gather -> requant -> pixel RAMs) ========== ========== ==========
assign g_px_valid = (state == S_RUN) && (qn < npix) && (17'(qn >> 3) < cblk + 17'd2);   // its bank is free
assign g_px_idx   = pstart + qn;

emy_gather u_gather (
    .clk      (clk),
    .nRst     (nRst),
    .init     (state == S_LATCH && lc == 3'd0),
    .cmd      (c),
    .tile_r0  (r0_q),
    .dir_k    (k_q),
    .group_g  (g_q),
    .busy     (g_busy),
    .px_valid (g_px_valid),
    .px_ready (g_px_ready),
    .px_idx   (g_px_idx),
    .w_valid  (g_w_valid),
    .w_ready  (1'b1),
    .w_buf    (g_w_buf),
    .w_addr   (g_w_addr),
    .w_src    (g_w_src),
    .w_zero   (g_w_zero),
    .w_last   (g_w_last)
);

assign rd0_en   = g_w_valid && !g_w_zero;
assign rd0_buf  = g_w_buf;
assign rd0_addr = g_w_addr;
assign rd1_en   = 1'b0;
assign rd1_buf  = '0;
assign rd1_addr = '0;

always @(posedge clk) begin
    if (state == S_LATCH) qn <= #1 '0;
    else if (g_px_valid && g_px_ready) qn <= #1 qn + 1'b1;
    if (state == S_LATCH) begin
        rn <= #1 '0;
        jw <= #1 '0;
    end else if (g_w_valid) begin
        if (g_w_last) begin rn <= #1 rn + 1'b1; jw <= #1 '0; end
        else jw <= #1 jw + 1'b1;
    end
end

always @(posedge clk) begin
    if (!nRst) begin ld1_v <= #1 1'b0; ld_v <= #1 1'b0; end
    else begin ld1_v <= #1 g_w_valid; ld_v <= #1 ld1_v; end
    if (g_w_valid) begin
        ld1_zero <= #1 g_w_zero; ld1_src <= #1 g_w_src; ld1_last <= #1 g_w_last; ld1_pix <= #1 rn; ld1_j <= #1 jw;
    end
    if (ld1_v) begin
        ld_zero <= #1 ld1_zero; ld_src <= #1 ld1_src; ld_last <= #1 ld1_last; ld_pix <= #1 ld1_pix; ld_j <= #1 ld1_j;
    end
    if (state == S_LATCH) rdone <= #1 '0;
    else if (ld_v && ld_last && (ld_pix[2:0] == 3'd7 || ld_pix == npix - 1'b1)) rdone <= #1 rdone + 1'b1;
end

genvar gp, gb;
generate
    for (gp = 0; gp < NIN; gp = gp + 1) begin: RQ_IN
        emy_requant #(.IN_W(8), .OUT_W(8)) rq (.din(rd0_data[8*gp +: 8]), .shift(ld_src ? c.shift1 : c.shift0), .dout(ld_lane[gp]));
        assign ld_word[8*gp +: 8] = ld_zero ? 8'd0 : ld_lane[gp];
    end
endgenerate

// ========== ========== ========== Compute issue ========== ========== ==========
wire       c_lastj = ({1'b0, jc} == nw - 1'b1);
wire       c_cap   = c_lastj && (og[0] || og == ng - 1'b1);
wire       c_avail = (state == S_RUN) && prm_done && (cblk < nblk) && (rdone > cblk);
wire       cissue  = c_avail && (!c_cap || gap[3]);
wire [3:0] cur_nb  = (crem >= AW'(8)) ? 4'd8 : crem[3:0];

always @(posedge clk) begin
    if (state == S_LATCH) begin
        wl <= #1 '0; og <= #1 '0; jc <= #1 '0; cblk <= #1 '0; gap <= #1 4'd8;
        crem    <= #1 npix;
        obase_b <= #1 c.dst.addr + (opix0 - offo) * AW'(cwo);
    end else begin
        if (cissue && c_cap) gap <= #1 4'd1;
        else if (!gap[3])    gap <= #1 gap + 1'b1;
        if (cissue) begin
            if (wl == nlines - 1'b1) begin
                wl <= #1 '0; og <= #1 '0; jc <= #1 '0;
                cblk    <= #1 cblk + 1'b1;
                crem    <= #1 crem - AW'(8);
                obase_b <= #1 obase_b + {cwo, 3'b000};
            end else begin
                wl <= #1 wl + 1'b1;
                if (c_lastj) begin jc <= #1 '0; og <= #1 og + 1'b1; end
                else jc <= #1 jc + 1'b1;
            end
        end
    end
end

assign img_en   = pf_issue || cissue;
assign img_addr = pf_issue ? aux + IMG_ADDR_W'(pf_i) : c.prm + IMG_ADDR_W'(wl);

// pixel RAMs: bank = block bit 0, word j; written by the loader, all 8 read together by the issue
generate
    for (gp = 0; gp < NPIX; gp = gp + 1) begin: PRAM
        logic [63:0] mem [0:2*NW_MAX-1];
        logic [63:0] q, q2;                  // q2: held one more clock, the IMG line arrives two clocks after cissue
        always @(posedge clk) begin
            if (ld_v && ld_pix[2:0] == gp) mem[{ld_pix[3], ld_j}] <= #1 ld_word;
            if (cissue) q <= #1 mem[{cblk[0], jc}];
            q2 <= #1 q;
        end
        assign pdat[gp] = q2;
    end
endgenerate

// ========== ========== ========== MAC pipeline ========== ========== ==========
always @(posedge clk) begin
    if (!nRst) begin
        mI0 <= #1 '0; mI <= #1 '0; mA <= #1 '0; mB <= #1 '0; mC <= #1 '0; mD <= #1 '0;
    end else begin
        mI0 <= #1 '{v: cissue, first: (jc == 9'd0), last: c_lastj, cap: c_cap, og: og, nb: cur_nb, obase: obase_b};
        mI <= #1 mI0;
        mA <= #1 mI;
        mB <= #1 mA;
        mC <= #1 mB;
        mD <= #1 mC;
    end
end

// stage A: 256 products (weight line and pixel words of the issue two clocks earlier)
always @(posedge clk) begin
    if (mI.v)
        for (int p = 0; p < NPIX; p++)
            for (int b = 0; b < NOUT; b++)
                for (int i = 0; i < NIN; i++)
                    prod[p][b][i] <= #1 $signed(pdat[p][8*i +: 8]) * $signed(img_data[64*b + 8*i +: 8]);
end

// stage B: 8-term sums
always @(posedge clk) begin
    if (mA.v)
        for (int p = 0; p < NPIX; p++)
            for (int b = 0; b < NOUT; b++) begin
                automatic logic signed [18:0] s;
                s = '0;
                for (int i = 0; i < NIN; i++) s = s + 19'(prod[p][b][i]);
                dot[p][b] <= #1 s;
            end
end

// stage C: accumulate; bias / rshift lines of the group
always @(posedge clk) begin
    if (mB.v)
        for (int p = 0; p < NPIX; p++)
            for (int b = 0; b < NOUT; b++)
                acc[p][b] <= #1 mB.first ? ACC_W'(dot[p][b]) : acc[p][b] + ACC_W'(dot[p][b]);
    if (mB.v && mB.last) begin
        bias_q <= #1 bias_mem[mB.og[8:1]];
        rsh_q  <= #1 rsh_mem[mB.og[8:3]];
    end
end

// stage D: + bias (int32)
always @(posedge clk) begin
    if (mC.v && mC.last) begin
        for (int b = 0; b < NOUT; b++) rs_d[b] <= #1 rsh_q[8 * (4 * mC.og[2:0] + b) +: 8];
        for (int p = 0; p < NPIX; p++)
            for (int b = 0; b < NOUT; b++)
                sb[p][b] <= #1 SB_W'(acc[p][b]) + SB_W'($signed(bias_q[32 * (4 * mC.og[0] + b) +: 32]));
    end
end

// stage E: requant (rshift per channel) -> sat8 -> ReLU, channels >= c_out -> 0; pairs of groups -> output words
generate
    for (gp = 0; gp < NPIX; gp = gp + 1) begin: RQ_P
        for (gb = 0; gb < NOUT; gb = gb + 1) begin: RQ_O
            emy_requant #(.IN_W(SB_W), .OUT_W(8)) rq (.din(sb[gp][gb]), .shift(rs_d[gb]), .dout(o8_rq[gp][gb]));
        end
    end
endgenerate

always @(*) begin
    for (int p = 0; p < NPIX; p++)
        for (int b = 0; b < NOUT; b++) begin
            automatic logic signed [7:0] v;
            v = o8_rq[p][b];
            if (f_relu && v < 0) v = 8'sd0;
            if ({5'd0, mD.og, 2'(b)} >= c.c_out) v = 8'sd0;
            o8[p][b] = v;
        end
end

wire cap_now = mD.v && mD.last && mD.cap;
always @(posedge clk) begin
    if (mD.v && mD.last && !mD.og[0])
        for (int p = 0; p < NPIX; p++) lo[p] <= #1 {o8[p][3], o8[p][2], o8[p][1], o8[p][0]};
    if (cap_now)
        for (int p = 0; p < NPIX; p++)
            ob[p] <= #1 mD.og[0] ? {o8[p][3], o8[p][2], o8[p][1], o8[p][0], lo[p]} : {32'h0, o8[p][3], o8[p][2], o8[p][1], o8[p][0]};
end

// ========== ========== ========== Output writes (one pixel word per clk) ========== ========== ==========
always @(posedge clk) begin
    if (!nRst) begin
        dr_v <= #1 1'b0;
    end else if (cap_now) begin
        dr_v    <= #1 1'b1;
        dr_k    <= #1 '0;
        dr_nb   <= #1 mD.nb;
        dr_addr <= #1 mD.obase + AW'(mD.og[8:1]);
    end else if (dr_v) begin
        dr_k    <= #1 dr_k + 1'b1;
        dr_addr <= #1 dr_addr + AW'(cwo);
        if ({1'b0, dr_k} == dr_nb - 1'b1) dr_v <= #1 1'b0;
    end
end

assign wr_en   = dr_v;
assign wr_buf  = c.dst.buf_id;
assign wr_addr = dr_addr;
assign wr_data = ob[dr_k];
assign wr_be   = 8'hff;

endmodule
