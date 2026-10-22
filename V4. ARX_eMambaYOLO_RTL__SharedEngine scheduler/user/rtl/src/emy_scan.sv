`timescale 1ns / 1ps
// emy_scan : the scan engine of the shared-engine eMambaYOLO (docs/ENGINE_SPEC.md §7.3), one channel per cycle, N = 16
//
// (a) What it does
//   One command = one group of nl = min(8, L - 8g) tokens of one CrossScan direction (L = h * w, g = group_g) over
//   D = c_in channels. Per token, channel d and state lane n (layers_int8_emamba.SW.SelectiveScan, the loop version):
//       dA   = sat8(rshr(chord8(delta * A[d][n]), 2 s_in - S_DA))              s_in = S_DELTA + S_A
//       dB   = sat8(rshr(delta * B[n], S_DELTA + S_B - S_DB))
//       Ax   = wrap_{16 + S_DA}(dA * x[d][n])
//       x'   = Ax + ((dB * u) << S_DA),   x[d][n] <- rshr(x', S_DA)
//       y[d] = sat8(rshr(sum_n C[n] * x' + ((D[d] * u) << (S_DA + S_DB + S_C - S_D)), S_U + S_DA + S_DB + S_C - S_Y))
//   Datapath = the channel-stream SelectiveScan of U_106 transcribed (Dim_expand_delta_A_compute, Exp_PWL_Pipe /
//   new_U_Exp_piecewise_compute, shifter_right + saturator of dB, SSM_xkP1_compute, SSM_y_compute_Pipe). What were
//   elaboration parameters are runtime values of the direction: the chord8 constants (IF / MULT / ADD for
//   k = 2^s_in) come from a ROM over s_in = 0..15 built by constant functions, the exp output shift, the Ax wrap
//   width, the dB / x / y right shifts (emy_requant) and the left shifts (exact) are registers.
//   The state x is 17 bits per lane whatever S_DA is (16 + S_DA + 1 - S_DA) and lives in x_mem (D rows x 16 lanes);
//   it persists across the commands of a direction and reads as 0 at the first token of a command with F_SEQ_START
//   (the RAM is not cleared).
//
// (b) Command fields
//   op = OP_SCAN; c_in = D (multiple of 8, 16..512); h, w = frame size (L = h * w tokens); group_g = g, dir_k = k.
//   src0 (X) : u of token t at src0.addr + pix * ceil(D/8) + cw, pix = p_k(8g + t) with AM_PERM in misc am0 (CrossScan
//              order: k0 p = l, k1 p = (l mod H) * W + l div H, k2 p = L-1-l, k3 p = p_1(L-1-l)), else pix = t
//              (AM_GROUP); requantised with shift0: u = sat8(rshr(x, shift0)).
//   src1 (WORK): delta of token t at src1.addr + t * ceil(D/8) + cw (token order); xp row of token t at
//              src1.addr + 8 * ceil(D/8) + t * XPW, XPW = ceil((prm2 + 32) / 8): B[n] = byte prm2 + n,
//              C[n] = byte prm2 + 16 + n of the row (channel c = byte c % 8 of word c / 8; prm2 = R).
//   dst      : y of token t at dst.addr + t * ceil(D/8) + cw (8 channels per word, written whole).
//   flags    : F_SEQ_START = first group of the direction (x reads 0 at its first token, parameters fetched).
//   prm      : IMG line of the direction's parameter block (c).
//   Unused: shift1, shift_out, shift_aux, c_out, row_lo / row_hi, tile_r0, flags other than F_SEQ_START (F_RELU,
//   F_OUT_WIDE, F_ACC_INIT, F_TOP_PAD, F_BOT_PAD, F_SRC1_EN, F_SILU), misc am1 / amd / kernel / wide / up bits.
//   The buffer ids of src0 / src1 / dst are used as given (X / WORK / WORK in phase 2).
//
// (c) IMG bytes read (ENGINE_SPEC §8 scan row), only when F_SEQ_START is set, prm differs from the last fetched
//   prm or nothing was fetched since reset (otherwise none):
//     A      : D rows x 16 B, row d at line prm + d/2, bytes 16 (d % 2) .. +15, n fastest            -> a_mem
//     D      : D bytes from line prm + D/2, 32 per line                                                 -> d_mem
//     shifts : 9 bytes at line prm + D/2 + ceil(D/32): S_U, S_DELTA, S_A, S_DA, S_B, S_DB, S_C, S_D, S_Y  -> registers
//   One line read per cycle: D + D/8 + 1 reads (an A line is read twice, a D line four times).
//
// (d) Cycles per command (cmd_valid to done, measured by sim_1/new/tb_scan.sv)
//   latch, prep, (16-step token-index divider with AM_PERM for k1 / k3), B / C of the first token (8), nl * D (one
//   channel per cycle; the next token's B / C and u address are prepared during the current one), pipeline (15), done:
//   nl * D + 26 with AM_GROUP and with AM_PERM k0 / k2, nl * D + 42 with AM_PERM k1 / k3, + D + D/8 + 4 when the
//   parameters are fetched (e.g. D = 512: 4122 / 4138 per group of 8 tokens = D + 3.25 / D + 5.25 per token).
//
// Supported runtime ranges
//   D = c_in: multiple of 8, 16..512 (x write-back 8 cycles after the read, B / C prefetch in channels 9..15); any other
//      c_in: the command is ignored (done without any buffer / IMG access; "WARNING emy_scan" line in simulation)
//   s_in = S_DELTA + S_A: 0..15 (ROM), S_DA: 0..10 (Ax 16 + S_DA <= 26 bit, x' <= 27 bit), du = S_DA + S_DB + S_C - S_D:
//      0..15; outside: clamped ("ERROR emy_scan" line in simulation)
//   exp shift 2 s_in - S_DA, db = S_DELTA + S_B - S_DB, y shift = S_U + S_DA + S_DB + S_C - S_Y, shift0: any value. The
//      derived shifts are clamped to -128..127, which is exact: every one feeds an emy_requant with an 8-bit output,
//      where a right shift >= 40 gives 0 for the input widths here and a left shift >= 8 saturates every non-zero value
//   (measured over the 10 blocks x 4 directions: s_in 10..11, exp shift 13..15, db 5..7, du 2..11, y 15..19, S_DA 7)
//
// Reset: nRst clears the FSM, the pipeline valid bits, the write / fetch strobes and the "parameters fetched" flag
// (as emy_vec); data registers and memories hold until written (each is enabled by its stage's valid).
//
// Pipeline, k = cycles after the issue of channel d (v of m[k] marks it):
//   0  issue: u word (rd0) and delta word (rd1) at channel % 8 == 0; a_mem / x_mem / d_mem read
//   1  word select, u requant                         2  RAM output registers, u, delta
//   3  delta * A[n], delta * B[n]                    4  exp segment (compare with IF), dB = sat8(rshr(delta B, db))
//   5  MULT * p + ADD                                6  dA = sat8(rshr(., 2 s_in - S_DA)), dB, u, x (0 on first), C
//   7  dA * x, dB * u                                 8  x' = wrap(dA x) + (dB u << S_DA) -> x = rshr(x', S_DA) -> x_mem
//   9  C[n] * x', D * u    10..13 adder tree (4 levels)    14 sum + (D u << du) -> y = sat8(rshr(., y shift)) -> dst word
module emy_scan import emy_pkg::*; import emy_engine_pkg::*; (
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
localparam int N       = 16;               // state lanes (SCAN_N)
localparam int D_MAX   = 512;              // SCAN_D_MAX
localparam int COL_W   = 9;                // channel index
localparam int NCH_W   = 7;                // words per token (<= 64)
localparam int SDA_MAX = 10;
localparam int DU_MAX  = 15;
localparam int X_W     = 17;               // state per lane
localparam int P_W     = 25;               // dA * x
localparam int AX_W    = 16 + SDA_MAX;     // Ax, wrapped to 16 + S_DA bits at run time
localparam int XP_W    = AX_W + 1;         // x'
localparam int CX_W    = 8 + XP_W + 4;     // sum over the 16 lanes of C * x'
localparam int Y_W     = CX_W + 1;         // + (D * u << du)
localparam int EXP_W   = 33;               // MULT * p + ADD (DATA_WIDTH_DOUT of the exp)
localparam int IF_W    = 20;               // breakpoints: |IF| <= 5.5 * 2^15
localparam int MU_W    = 17;               // slopes: <= 0.85 * 2^15
localparam int AD_W    = 32;               // intercepts: <= 2^30
localparam int K_X     = 8;                // stage of the x write-back
localparam int K_Y     = 14;               // stage of y
localparam int PF_END  = 8;                // last step of the B / C prefetch (7 + 1: buffer read latency 2)

typedef enum logic [3:0] {S_IDLE, S_LATCH, S_PREP, S_PARAM, S_CFG, S_DIV, S_BC, S_RUN, S_DRAIN, S_DONE} state_t;
state_t state;

// ---------- chord8 exp constants (new_U_Exp_piecewise_compute) as a ROM over s_in ---------- //
// V60 = the IEEE double of each literal (EXP8_BP / EXP8_SLOPE / EXP8_ICEPT of layers_int8_emamba.py) times 2^60, an
// exact integer. k * v for k = 2^s is then V60 / 2^(60 - s) exactly as Verilog's real product, and rnd_away rounds it
// half away from zero like the real -> integer conversion of the original's localparams.
localparam longint V60_BP [8] = '{       // -5.5000000000 -4.0461704523 -3.0643424924 -2.3111745951
    -64'sd6341068275337658368, -64'sd4664916925761482752, -64'sd3532946356968503296, -64'sd2664602891591812096,
    -64'sd1970162116285151232, -64'sd1363963729416684544, -64'sd848065548874643328,  -64'sd398156489011067264};
                                         // -1.7088432373 -1.1830499509 -0.7355796084 -0.3453457043  (BP[8] = 0)
localparam longint V60_SLOPE [8] = '{    // 0.0092187223 0.0297356625 0.0696527311 0.1360221466
    64'sd10628463184668692,  64'sd34282884749981396,  64'sd80304131539788128,  64'sd156822857917925120,
    64'sd274678282273024704, 64'sd445442730153224192, 64'sd675821409368921344, 64'sd974910796458611456};
                                         // 0.2382454323 0.3863599806 0.5861816322 0.8456003228
localparam longint V60_ICEPT [8] = '{    // 0.0547897443 0.1378047813 0.2601243508 0.4135156578
    64'sd63168274435380416,  64'sd158878095798413504, 64'sd299902957909215296, 64'sd476751094369266048,
    64'sd678147539184930176, 64'sd880170410872109312, 64'sd1049632269589659904, 64'sd1152921504606846976};
                                         // 0.5881992282 0.7634261373 0.9104108696 1.0000000000

function automatic longint rnd_away(input longint v, input int sh);
    longint a;
    a = (v < 0) ? -v : v;
    a = (a + (64'sd1 <<< (sh - 1))) >>> sh;
    return (v < 0) ? -a : a;
endfunction

// rom_*[s][j]: IF_j (j = 0..7), MULT_{j+1}, ADD_{j+1} for k = 2^s
logic signed [IF_W-1:0] rom_if   [0:15][0:7];
logic signed [MU_W-1:0] rom_mult [0:15][0:7];
logic signed [AD_W-1:0] rom_add  [0:15][0:7];
genvar gs, gj, gn;
generate
    for (gs = 0; gs < 16; gs = gs + 1) begin: G_ROM
        for (gj = 0; gj < 8; gj = gj + 1) begin: G_K
            assign rom_if[gs][gj]   = IF_W'(rnd_away(V60_BP[gj], 60 - gs));
            assign rom_mult[gs][gj] = MU_W'(rnd_away(V60_SLOPE[gj], 60 - gs));
            assign rom_add[gs][gj]  = AD_W'(rnd_away(V60_ICEPT[gj], 60 - 2 * gs));
        end
    end
endgenerate

// ---------- Command registers ---------- //
cmd_t  c;
logic [1:0]  k_q;
logic [15:0] g_q;
logic [NCH_W-1:0] nch;                     // ceil(D / 8)
logic [9:0]  dlen;                         // D
logic [31:0] L_q;                          // h * w
logic [15:0] l0;                           // first token of the group
logic [3:0]  nl;                           // tokens in the group
logic [15:0] xpw;                          // xp row pitch (words)
logic [2:0]  rb;                           // byte offset of B in its first word (R % 8)
logic [12:0] rw;                           // word of B in the xp row (R / 8)
logic [2:0]  nw;                           // xp words holding B, C
logic [BUF_ADDR_W-1:0] xp0;                // xp region
logic [IMG_ADDR_W-1:0] dline0, sline;      // IMG lines of the D vector and of the shifts
logic [10:0] n_items;                      // parameter items: D A rows, D/8 D words, 1 shift line
wire  use_perm = (c.misc[M_AM0_LO +: 2] == AM_PERM);
wire  bad_d    = (c.c_in < 16) || (c.c_in > D_MAX) || (c.c_in[2:0] != 3'd0);    // command ignored
wire  f_first  = c.flags[F_SEQ_START];

// parameters of the last fetch
logic        prm_ok;
logic [23:0] prm_last;
wire  need_fetch = f_first || !prm_ok || (c.prm != prm_last);

// ---------- Parameter memories and runtime shifts ---------- //
logic [8*N-1:0]  a_mem [0:D_MAX-1];        // A[d][n] at bits 8n
logic [63:0]     d_mem [0:D_MAX/8-1];      // D[8w + i] at bits 8i
logic [X_W*N-1:0] x_mem [0:D_MAX-1];       // x[d][n] at bits 17n
logic signed [7:0] sh_raw [0:8];           // S_U, S_DELTA, S_A, S_DA, S_B, S_DB, S_C, S_D, S_Y
logic [3:0]        s_in_r, sda_r, du_r;
logic signed [7:0] ersh_r, db_r, ysh_r;
logic signed [IF_W-1:0] if_r [0:7];
logic signed [MU_W-1:0] mu_r [0:7];
logic signed [AD_W-1:0] ad_r [0:7];
logic signed [AD_W-1:0] sq_r;              // k^2 = exp(0)
logic [1:0]  cfg_c;

// ---------- Walk ---------- //
logic [COL_W-1:0] col;
logic [2:0]       tok;
logic [BUF_ADDR_W-1:0] ubase, dl_base;     // u / delta word of channel 0 of the current token
// prefetch of the next token: pixel, u address, B / C
logic [3:0]  pf_cnt;
logic [2:0]  pf_tok;
logic [15:0] p_r;
logic [BUF_ADDR_W-1:0] ubase_n;
logic [63:0] bc_raw [0:4];
logic signed [7:0] bB [0:1][0:N-1], bC [0:1][0:N-1];    // bank = token % 2
// perm divider (restoring, 16 steps): l0 / H or (L - 1 - l0) / H, then the walk registers of k1 / k3
logic [15:0] dv_n, dv_q;
logic [16:0] dv_r;
logic [4:0]  dv_i;
logic [15:0] q_div, r_div;

// ---------- Pipeline ---------- //
typedef struct packed {
    logic             v;
    logic             first;      // x reads as 0
    logic             last;       // last channel of the command
    logic             wlast;      // last channel of a y word
    logic [2:0]       tok;
    logic [COL_W-1:0] col;
} meta_t;
meta_t m [0:K_Y];                          // m[0]: buffer reads in flight ([Jae 2026-10-18] buffer read latency 2)

logic [8*N-1:0]   a_r, a_q;
logic [X_W*N-1:0] x_r, x_q, x3, x4, x5;
logic [63:0]      dm_r, dm_q, uw_h, dw_h;
logic signed [7:0] u_rq, u2, u3, u4, u5, u_s, u_y1, u_y2;
logic signed [7:0] dl2, d3, d4, d5, d_s, d_y1, d_y2;
logic signed [15:0] pa_q [0:N-1], pb_q [0:N-1];
logic signed [7:0]  db_c [0:N-1], db4 [0:N-1], db5 [0:N-1];
logic signed [15:0] x_a [0:N-1];
logic signed [MU_W-1:0] mu_a [0:N-1];
logic signed [AD_W-1:0] ad_a [0:N-1];
logic signed [EXP_W-1:0] y_b [0:N-1];
logic signed [7:0]  ex_c [0:N-1];
logic signed [7:0]  dA_s [0:N-1], dB_s [0:N-1], C_s [0:N-1], C_y1 [0:N-1], C_y2 [0:N-1];
logic signed [X_W-1:0] xk_s [0:N-1];
logic signed [P_W-1:0]  ax_p [0:N-1];
logic signed [15:0]     bu_q [0:N-1];
logic signed [XP_W-1:0] xkp1_c [0:N-1], xkp1_q [0:N-1];
logic signed [X_W-1:0]  xn_c [0:N-1];
logic [X_W*N-1:0]       xn_v;
logic signed [CX_W-1:0] yt [0:4][0:N-1];
logic signed [15:0]     du_d [0:4];
logic signed [Y_W-1:0]  yq;
logic signed [7:0]      y8;
logic signed [7:0]      ybuf [0:7];
logic                   wr_v;
logic [BUF_ADDR_W-1:0]  wr_a;
logic [63:0]            wr_d;

// ========== ========== ========== Command decode ========== ========== ==========
assign cmd_ready = (state == S_IDLE);

always @(posedge clk) begin
    if (state == S_IDLE && cmd_valid) begin
        c   <= #1 cmd;
        k_q <= #1 dir_k;
        g_q <= #1 group_g;
    end
end

always @(posedge clk) begin
    if (state == S_LATCH) begin
        nch     <= #1 NCH_W'((c.c_in + 7) >> 3);
        dlen    <= #1 c.c_in[9:0];
        L_q     <= #1 c.h * c.w;
        l0      <= #1 {g_q[12:0], 3'b000};
        xpw     <= #1 (c.prm2 + 16'd39) >> 3;
        rb      <= #1 c.prm2[2:0];
        rw      <= #1 c.prm2[15:3];
        nw      <= #1 (c.prm2[2:0] == 3'd0) ? 3'd4 : 3'd5;
        xp0     <= #1 c.src1.addr + BUF_ADDR_W'(((c.c_in + 7) >> 3) << 3);
        dline0  <= #1 c.prm + (c.c_in >> 1);
        sline   <= #1 c.prm + (c.c_in >> 1) + ((c.c_in + 31) >> 5);
        n_items <= #1 11'(c.c_in + ((c.c_in + 7) >> 3) + 1);
    end
end
wire [31:0] n_tok_left = (L_q > {16'd0, l0}) ? (L_q - l0) : 32'd0;
always @(posedge clk) if (state == S_PREP) nl <= #1 (n_tok_left >= 32'd8) ? 4'd8 : n_tok_left[3:0];
wire no_work = (nl == 4'd0);

// ========== ========== ========== FSM ========== ========== ==========
wire div_end  = !use_perm || !k_q[0] || (dv_i == 5'd16);   // k0 / k2 need no division
wire col_end  = ({1'b0, col} == dlen - 1'b1);
wire tok_end  = ({1'b0, tok} == nl - 1'b1);
wire issue    = (state == S_RUN);
logic        fv_d, fv_d2;                   // IMG read latency 2 ([Jae 2026-10-18] buffer read latency 2)
logic [10:0] fi, fi_d, fi_d2;
wire last_item = fv_d2 && (fi_d2 == n_items - 1'b1);

always @(posedge clk) begin
    if (!nRst) begin
        state <= #1 S_IDLE;
        done  <= #1 1'b0;
    end else begin
        done <= #1 1'b0;
        case (state)
            S_IDLE:  if (cmd_valid) state <= #1 S_LATCH;
            S_LATCH: state <= #1 S_PREP;
            S_PREP:  state <= #1 bad_d ? S_DONE : need_fetch ? S_PARAM : S_DIV;
            S_PARAM: if (last_item) state <= #1 S_CFG;
            S_CFG:   if (cfg_c == 2'd1) state <= #1 S_DIV;
            S_DIV:   if (no_work) state <= #1 S_DONE; else if (div_end) state <= #1 S_BC;
            S_BC:    if (pf_cnt == PF_END) state <= #1 S_RUN;
            S_RUN:   if (col_end && tok_end) state <= #1 S_DRAIN;
            S_DRAIN: if (m[K_Y].v && m[K_Y].last) state <= #1 S_DONE;    // the last y word is registered on this edge
            S_DONE:  begin done <= #1 1'b1; state <= #1 S_IDLE; end
            default: state <= #1 S_IDLE;
        endcase
    end
end

// ========== ========== ========== Parameter fetch (IMG lines) ========== ========== ==========
wire [10:0] wi = fi - {1'b0, dlen};        // D word index of item fi
assign img_en   = (state == S_PARAM) && (fi < n_items);
assign img_addr = (fi < {1'b0, dlen})     ? (c.prm + fi[10:1]) :
                  (fi < {1'b0, dlen} + nch) ? (dline0 + wi[10:2]) : sline;

wire [10:0] wi_d = fi_d2 - {1'b0, dlen};
wire a_we = fv_d2 && (fi_d2 < {1'b0, dlen});
wire d_we = fv_d2 && !a_we && (fi_d2 < {1'b0, dlen} + nch);
wire s_we = fv_d2 && !a_we && !d_we;
always @(posedge clk) begin
    if (state == S_PREP) fi <= #1 '0;
    else if (img_en) fi <= #1 fi + 1'b1;
    fi_d  <= #1 fi;
    fi_d2 <= #1 fi_d;
    if (!nRst) begin fv_d <= #1 1'b0; fv_d2 <= #1 1'b0; end else begin fv_d <= #1 img_en; fv_d2 <= #1 fv_d; end
end
always @(posedge clk) if (a_we) a_mem[fi_d2[8:0]] <= #1 fi_d2[0] ? img_data[255:128] : img_data[127:0];
always @(posedge clk) if (d_we) d_mem[wi_d[5:0]] <= #1 img_data[64*wi_d[1:0] +: 64];
always @(posedge clk) if (s_we) for (int b = 0; b < 9; b++) sh_raw[b] <= #1 img_data[8*b +: 8];

// runtime shifts of the direction (S_CFG: 0 derived shifts, 1 exp constants of s_in)
function automatic logic signed [7:0] clamp8(input int x);
    return (x > 127) ? 8'sd127 : (x < -128) ? -8'sd128 : 8'(x);
endfunction
function automatic logic [3:0] clampu(input int x, input int hi);
    return (x < 0) ? 4'd0 : (x > hi) ? 4'(hi) : 4'(x);
endfunction
always @(posedge clk) begin
    if (state != S_CFG) cfg_c <= #1 '0; else cfg_c <= #1 cfg_c + 1'b1;
    if (state == S_CFG && cfg_c == 2'd0) begin
        automatic int s_u, s_dl, s_a, s_da, s_b, s_db, s_c, s_d, s_y;
        s_u = sh_raw[0]; s_dl = sh_raw[1]; s_a = sh_raw[2]; s_da = sh_raw[3]; s_b = sh_raw[4];
        s_db = sh_raw[5]; s_c = sh_raw[6]; s_d = sh_raw[7]; s_y = sh_raw[8];
        s_in_r <= #1 clampu(s_dl + s_a, 15);
        sda_r  <= #1 clampu(s_da, SDA_MAX);
        du_r   <= #1 clampu(s_da + s_db + s_c - s_d, DU_MAX);
        ersh_r <= #1 clamp8(2 * (s_dl + s_a) - s_da);
        db_r   <= #1 clamp8(s_dl + s_b - s_db);
        ysh_r  <= #1 clamp8(s_u + s_da + s_db + s_c - s_y);
        // synthesis translate_off
        if (s_dl + s_a < 0 || s_dl + s_a > 15) $display("ERROR emy_scan: s_in = S_DELTA + S_A = %0d outside 0..15", s_dl + s_a);
        if (s_da < 0 || s_da > SDA_MAX)        $display("ERROR emy_scan: S_DA = %0d outside 0..%0d", s_da, SDA_MAX);
        if (s_da + s_db + s_c - s_d < 0 || s_da + s_db + s_c - s_d > DU_MAX)
            $display("ERROR emy_scan: du = %0d outside 0..%0d", s_da + s_db + s_c - s_d, DU_MAX);
        // synthesis translate_on
    end
    if (state == S_CFG && cfg_c == 2'd1) begin
        for (int j = 0; j < 8; j++) begin
            if_r[j] <= #1 rom_if[s_in_r][j];
            mu_r[j] <= #1 rom_mult[s_in_r][j];
            ad_r[j] <= #1 rom_add[s_in_r][j];
        end
        sq_r <= #1 AD_W'(1) <<< {s_in_r, 1'b0};
    end
end
always @(posedge clk) begin
    if (!nRst) prm_ok <= #1 1'b0;
    else if (state == S_CFG && cfg_c == 2'd1) begin prm_ok <= #1 1'b1; prm_last <= #1 c.prm; end
end

// synthesis translate_off
always @(posedge clk) if (state == S_PREP) begin
    if (bad_d) $display("WARNING emy_scan: c_in = %0d is not a multiple of 8 in 16..%0d, command ignored", c.c_in, D_MAX);
end
// synthesis translate_on

// ========== ========== ========== Perm divider ========== ========== ==========
wire [15:0] dv_start = (k_q == 2'd3) ? 16'(L_q - 1 - l0) : l0;
always @(posedge clk) begin
    if (state != S_DIV) begin
        dv_i <= #1 '0; dv_q <= #1 '0; dv_r <= #1 '0; dv_n <= #1 dv_start;
    end else if (dv_i < 5'd16) begin
        automatic logic [16:0] t;
        t = {dv_r[15:0], dv_n[15]};
        dv_n <= #1 {dv_n[14:0], 1'b0};
        if (t >= {1'b0, c.h}) begin dv_r <= #1 t - {1'b0, c.h}; dv_q <= #1 {dv_q[14:0], 1'b1}; end
        else begin dv_r <= #1 t; dv_q <= #1 {dv_q[14:0], 1'b0}; end
        dv_i <= #1 dv_i + 1'b1;
    end
end

// ========== ========== ========== Prefetch of a token: pixel, u address, B / C ========== ========== ==========
// pf_cnt 1: pixel of token pf_tok (k1 / k3 walk registers step on), xp read 0;  2: u address;  1..nw: xp reads;
// 3..nw+2: xp words in (read latency 2);  PF_END: B / C into bank pf_tok % 2. During S_RUN it runs at channels 9..16 of the previous
// token, where rd1 is free (delta words are read at channel % 8 == 0) and the bank is no longer read (stage <= 5).
wire pf_go = (state == S_DIV && !no_work && div_end) || (issue && col == COL_W'(8) && !tok_end);
always @(posedge clk) begin
    if (!nRst) pf_cnt <= #1 '0;
    else if (pf_go) pf_cnt <= #1 4'd1;
    else if (pf_cnt == PF_END) pf_cnt <= #1 '0;
    else if (pf_cnt != 0) pf_cnt <= #1 pf_cnt + 1'b1;
end

function automatic logic [15:0] p_of(input logic perm, input logic [1:0] k, input logic [15:0] l0_r, input logic [2:0] t,
                                     input logic [31:0] L, input logic [15:0] r, input logic [15:0] q, input logic [15:0] w);
    if (!perm) return {13'd0, t};
    case (k)
        2'd0:    return l0_r + t;
        2'd2:    return 16'(L - 1 - l0_r - t);
        default: return 16'(r * w + q);
    endcase
endfunction

// xp word 0 of the token being prefetched: registered at pf_go ([Jae 2026-10-18] address pipeline -- keeps the multiply out of the rd1 address path)
logic [BUF_ADDR_W-1:0] xpt;
wire  [2:0] pf_tok_n = (state == S_DIV) ? 3'd0 : tok + 1'b1;
always @(posedge clk) begin
    if (state == S_DIV && div_end) begin
        q_div <= #1 dv_q; r_div <= #1 dv_r[15:0];
    end else if (pf_cnt == 4'd1) begin
        if (k_q == 2'd1) begin
            if (r_div == c.h - 1) begin r_div <= #1 '0; q_div <= #1 q_div + 1'b1; end else r_div <= #1 r_div + 1'b1;
        end else if (k_q == 2'd3) begin
            if (r_div == 16'd0) begin r_div <= #1 c.h - 1; q_div <= #1 q_div - 1'b1; end else r_div <= #1 r_div - 1'b1;
        end
    end
    if (pf_go) pf_tok <= #1 pf_tok_n;
    if (pf_go) xpt    <= #1 xp0 + BUF_ADDR_W'(pf_tok_n) * BUF_ADDR_W'(xpw) + BUF_ADDR_W'(rw);
    if (pf_cnt == 4'd1) p_r <= #1 p_of(use_perm, k_q, l0, pf_tok, L_q, r_div, q_div, c.w);
    if (pf_cnt == 4'd2) ubase_n <= #1 c.src0.addr + BUF_ADDR_W'(p_r) * BUF_ADDR_W'(nch);
    if (pf_cnt >= 4'd3 && pf_cnt <= {1'b0, nw} + 4'd2) bc_raw[pf_cnt - 4'd3] <= #1 rd1_data;   // [Jae 2026-10-18] buffer read latency 2
end
wire [319:0] bc_cat = {bc_raw[4], bc_raw[3], bc_raw[2], bc_raw[1], bc_raw[0]};
wire [255:0] bc_sh  = 256'(bc_cat >> {rb, 3'b000});
always @(posedge clk) begin
    if (pf_cnt == PF_END)
        for (int n = 0; n < N; n++) begin
            bB[pf_tok[0]][n] <= #1 bc_sh[8*n +: 8];
            bC[pf_tok[0]][n] <= #1 bc_sh[128 + 8*n +: 8];
        end
end

// ========== ========== ========== Channel walk ========== ========== ==========
always @(posedge clk) begin
    if (state == S_BC && pf_cnt == PF_END) begin
        col <= #1 '0; tok <= #1 '0;
        ubase <= #1 ubase_n; dl_base <= #1 c.src1.addr;
    end else if (issue) begin
        if (col_end) begin
            col <= #1 '0; tok <= #1 tok + 1'b1;
            ubase <= #1 ubase_n; dl_base <= #1 dl_base + nch;
        end else col <= #1 col + 1'b1;
    end
end

wire rd1_pf = (pf_cnt >= 4'd1) && (pf_cnt <= {1'b0, nw});
assign rd0_en   = issue && (col[2:0] == 3'd0);
assign rd0_buf  = c.src0.buf_id;
assign rd0_addr = ubase + BUF_ADDR_W'(col[COL_W-1:3]);
assign rd1_en   = rd1_pf || (issue && col[2:0] == 3'd0);
assign rd1_buf  = c.src1.buf_id;
assign rd1_addr = rd1_pf ? (xpt + BUF_ADDR_W'(pf_cnt - 1'b1)) : (dl_base + BUF_ADDR_W'(col[COL_W-1:3]));

// ---------- meta ---------- //
always @(posedge clk) begin
    if (!nRst) begin
        for (int k = 0; k <= K_Y; k++) m[k].v <= #1 1'b0;
    end else begin
        m[0].v <= #1 issue;
        for (int k = 1; k <= K_Y; k++) m[k].v <= #1 m[k-1].v;
    end
    m[0].first <= #1 f_first && (tok == 3'd0);
    m[0].last  <= #1 col_end && tok_end;
    m[0].wlast <= #1 (col[2:0] == 3'd7) || col_end;
    m[0].tok   <= #1 tok;
    m[0].col   <= #1 col;
    for (int k = 1; k <= K_Y; k++) begin
        m[k].first <= #1 m[k-1].first; m[k].last <= #1 m[k-1].last; m[k].wlast <= #1 m[k-1].wlast;
        m[k].tok   <= #1 m[k-1].tok;   m[k].col  <= #1 m[k-1].col;
    end
end

// ========== ========== ========== Stage 0 -> 1: RAM reads ========== ========== ==========
always @(posedge clk) begin
    if (m[0].v) begin                         // one stage after the issue: the buffer words arrive with m[1]
        a_r  <= #1 a_mem[m[0].col];
        x_r  <= #1 x_mem[m[0].col];
        dm_r <= #1 d_mem[m[0].col[COL_W-1:3]];
    end
end

// ========== ========== ========== Stage 1 -> 2: u, delta of the channel; RAM output registers ========== ==========
wire [63:0] uw = (m[1].col[2:0] == 3'd0) ? rd0_data : uw_h;
wire [63:0] dw = (m[1].col[2:0] == 3'd0) ? rd1_data : dw_h;
emy_requant #(.IN_W(8), .OUT_W(8)) rq_u (.din(uw[8*m[1].col[2:0] +: 8]), .shift(c.shift0), .dout(u_rq));
always @(posedge clk) begin
    if (m[1].v) begin
        uw_h <= #1 uw;  dw_h <= #1 dw;
        u2   <= #1 u_rq;
        dl2  <= #1 dw[8*m[1].col[2:0] +: 8];
        a_q  <= #1 a_r;  x_q <= #1 x_r;  dm_q <= #1 dm_r;
    end
end

// ========== ========== ========== Stage 2 -> 3: delta * A, delta * B ========== ========== ==========
always @(posedge clk) begin
    if (m[2].v) begin
        for (int n = 0; n < N; n++) begin
            pa_q[n] <= #1 dl2 * $signed(a_q[8*n +: 8]);
            pb_q[n] <= #1 dl2 * bB[m[2].tok[0]][n];
        end
        u3 <= #1 u2;  x3 <= #1 x_q;
        d3 <= #1 dm_q[8*m[2].col[2:0] +: 8];
    end
end

// ========== ========== ========== Stages 3 -> 5: exp (segment, chord), dB ========== ========== ==========
generate
    for (gn = 0; gn < N; gn = gn + 1) begin: L_DB
        emy_requant #(.IN_W(16), .OUT_W(8)) rq_db (.din(pb_q[gn]), .shift(db_r), .dout(db_c[gn]));
    end
endgenerate
always @(posedge clk) begin
    if (m[3].v) begin
        for (int n = 0; n < N; n++) begin
            automatic logic signed [IF_W-1:0] p;
            p = pa_q[n];
            x_a[n] <= #1 pa_q[n];
            // segments as new_U_Exp_piecewise_compute: below IF_0 -> 0, chord j: IF_{j-1} < p <= IF_j (chord 1 includes
            // IF_0), above IF_8 = 0 -> k^2
            if (p <= if_r[4]) begin
                if (p <= if_r[2]) begin
                    if (p < if_r[0])       begin mu_a[n] <= #1 '0;      ad_a[n] <= #1 '0;      end
                    else if (p <= if_r[1]) begin mu_a[n] <= #1 mu_r[0]; ad_a[n] <= #1 ad_r[0]; end
                    else                   begin mu_a[n] <= #1 mu_r[1]; ad_a[n] <= #1 ad_r[1]; end
                end else begin
                    if (p <= if_r[3])      begin mu_a[n] <= #1 mu_r[2]; ad_a[n] <= #1 ad_r[2]; end
                    else                   begin mu_a[n] <= #1 mu_r[3]; ad_a[n] <= #1 ad_r[3]; end
                end
            end else begin
                if (p <= if_r[6]) begin
                    if (p <= if_r[5])      begin mu_a[n] <= #1 mu_r[4]; ad_a[n] <= #1 ad_r[4]; end
                    else                   begin mu_a[n] <= #1 mu_r[5]; ad_a[n] <= #1 ad_r[5]; end
                end else begin
                    if (p <= if_r[7])      begin mu_a[n] <= #1 mu_r[6]; ad_a[n] <= #1 ad_r[6]; end
                    else if (p <= 0)       begin mu_a[n] <= #1 mu_r[7]; ad_a[n] <= #1 ad_r[7]; end
                    else                   begin mu_a[n] <= #1 '0;      ad_a[n] <= #1 sq_r;    end
                end
            end
            db4[n] <= #1 db_c[n];
        end
        u4 <= #1 u3;  x4 <= #1 x3;  d4 <= #1 d3;
    end
    if (m[4].v) begin
        for (int n = 0; n < N; n++) begin
            y_b[n] <= #1 mu_a[n] * x_a[n] + ad_a[n];
            db5[n] <= #1 db4[n];
        end
        u5 <= #1 u4;  x5 <= #1 x4;  d5 <= #1 d4;
    end
end

// ========== ========== ========== Stage 5 -> 6: operands of the state update ========== ========== ==========
generate
    for (gn = 0; gn < N; gn = gn + 1) begin: L_EXP
        emy_requant #(.IN_W(EXP_W), .OUT_W(8)) rq_exp (.din(y_b[gn]), .shift(ersh_r), .dout(ex_c[gn]));
    end
endgenerate
always @(posedge clk) begin
    if (m[5].v) begin
        for (int n = 0; n < N; n++) begin
            dA_s[n] <= #1 ex_c[n];
            dB_s[n] <= #1 db5[n];
            C_s[n]  <= #1 bC[m[5].tok[0]][n];
            xk_s[n] <= #1 m[5].first ? '0 : $signed(x5[X_W*n +: X_W]);
        end
        u_s <= #1 u5;  d_s <= #1 d5;
    end
end

// ========== ========== ========== Stage 6 -> 7 -> 8: x' ========== ========== ==========
// Ax = dA * x truncated to 16 + S_DA bits (the AX register width of SSM_xkP1_compute): bits above 15 + S_DA = bit 15 + S_DA
function automatic logic signed [AX_W-1:0] wrap_ax(input logic signed [P_W-1:0] p, input logic [3:0] sda);
    logic signed [AX_W-1:0] e;
    int sb;
    e  = p;
    sb = 15 + sda;
    for (int i = 16; i < AX_W; i++) if (i > sb) e[i] = e[sb];
    return e;
endfunction

always @(posedge clk) begin
    if (m[6].v) begin
        for (int n = 0; n < N; n++) begin
            ax_p[n] <= #1 dA_s[n] * xk_s[n];
            bu_q[n] <= #1 dB_s[n] * u_s;
            C_y1[n] <= #1 C_s[n];
        end
        u_y1 <= #1 u_s;  d_y1 <= #1 d_s;
    end
end
always @(*) begin
    for (int n = 0; n < N; n++) begin
        automatic logic signed [XP_W-1:0] bu_ls;
        bu_ls     = bu_q[n];
        bu_ls     = bu_ls <<< sda_r;
        xkp1_c[n] = wrap_ax(ax_p[n], sda_r) + bu_ls;
    end
end
always @(posedge clk) begin
    if (m[7].v) begin
        for (int n = 0; n < N; n++) begin
            xkp1_q[n] <= #1 xkp1_c[n];
            C_y2[n]   <= #1 C_y1[n];
        end
        u_y2 <= #1 u_y1;  d_y2 <= #1 d_y1;
    end
end

// x <- rshr(x', S_DA): 17 bits always hold it (|x'| < 2^(15 + S_DA) + 2^(14 + S_DA)), written back K_X = 8 cycles
// after the read of the same row; the next token reads the row D >= 16 cycles after it was read
generate
    for (gn = 0; gn < N; gn = gn + 1) begin: L_XN
        emy_requant #(.IN_W(XP_W), .OUT_W(X_W)) rq_x (.din(xkp1_q[gn]), .shift({4'd0, sda_r}), .dout(xn_c[gn]));
        assign xn_v[X_W*gn +: X_W] = xn_c[gn];
    end
endgenerate
always @(posedge clk) if (m[K_X].v) x_mem[m[K_X].col] <= #1 xn_v;

// ========== ========== ========== Stages 8 -> 14: y ========== ========== ==========
always @(posedge clk) begin
    if (m[8].v) begin
        for (int n = 0; n < N; n++) yt[0][n] <= #1 C_y2[n] * xkp1_q[n];
        du_d[0] <= #1 d_y2 * u_y2;
    end
    for (int s = 0; s < 4; s++) begin
        if (m[9 + s].v) begin
            for (int j = 0; j < (N >> (s + 1)); j++) yt[s+1][j] <= #1 yt[s][2*j] + yt[s][2*j+1];
            du_d[s+1] <= #1 du_d[s];
        end
    end
    if (m[13].v) begin
        automatic logic signed [Y_W-1:0] du_ls;
        du_ls = du_d[4];
        yq <= #1 yt[4][0] + (du_ls <<< du_r);
    end
end
emy_requant #(.IN_W(Y_W), .OUT_W(8)) rq_y (.din(yq), .shift(ysh_r), .dout(y8));

// ========== ========== ========== Write: one dst word per 8 channels ========== ========== ==========
always @(posedge clk) begin
    if (!nRst) wr_v <= #1 1'b0;
    else       wr_v <= #1 m[K_Y].v && m[K_Y].wlast;
    if (m[K_Y].v) begin
        ybuf[m[K_Y].col[2:0]] <= #1 y8;
        if (m[K_Y].wlast) begin
            wr_a    <= #1 c.dst.addr + BUF_ADDR_W'(m[K_Y].tok) * BUF_ADDR_W'(nch) + BUF_ADDR_W'(m[K_Y].col[COL_W-1:3]);
            for (int i = 0; i < 8; i++)
                wr_d[8*i +: 8] <= #1 (i < m[K_Y].col[2:0]) ? ybuf[i] : (i == m[K_Y].col[2:0]) ? y8 : 8'sd0;
        end
    end
end
assign wr_en   = wr_v;
assign wr_buf  = c.dst.buf_id;
assign wr_addr = wr_a;
assign wr_data = wr_d;
assign wr_be   = 8'hff;

endmodule
