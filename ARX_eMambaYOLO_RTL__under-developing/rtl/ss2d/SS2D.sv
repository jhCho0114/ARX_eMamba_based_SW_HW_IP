`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: SS2D
// Description: the SS2D of one VSSBlock / XSSBlock, steps 09-20, input = output of 08, output = output of 20.
//              Anh's SS2D ( frame sequencer, Linear_Transform_PerCh, DWConv2d_3x3,
//              CrossScan / SS2D_Core4 / CrossMerge, LightNormInt, Gate_Lanes) with the SiLU of the design
//              (emy_silu_pwl, chord8 table) and one WB window per block:
//
//   in (C) -> Requant -> 09 in_proj (C -> 2D) -+- z -> Requant -> 10 SiLU -------------------------> Z buffer
//                                              +- x -> Requant -> 11 DWConv -> Requant -> 12 SiLU -> 13 CrossScan
//   for k = 0..3:  13 CrossScan (dir k) -> SS2D_Core4 (14 XProj, 15 DtProj + ReLU: bank k; 16 SelectiveScan k) -> 17 CrossMerge
//   17 CrossMerge (merge, + requant) -> 18 LightNorm (LightNormInt) -> 19 x Z (Gate_Lanes, + requant) -> 20 out_proj
//
//   Phases: LOAD  the frame streams in; 09-12 run token by token; ends when CrossScan holds all L tokens
//           SCAN  the four directions one after another through SS2D_Core4 (one XProj / DtProj, weight bank = direction)
//           MERGE CrossMerge reads the grid in raster order; 17-20 run token by token
//           DONE  one cycle: the internal restart (every counter and sub-module back to LOAD), so frames stream
//                 continuously after one ps_start. No input is accepted in that cycle (s_ready = 0 outside LOAD).
//   Tokens are one pixel's channels, raster order, valid / ready.
//
//   Parameters: map size, R / N, the shifts (one set per block; core shifts one set per direction), the SiLU
//   in / out shifts (10 / 12), the LightNorm shifts (18) and WB_BASE, the byte address of the block's SS2D window
//   (emy_wb_map_pkg::WB_<block>_ss2d); all filled in from the step graph.
//   NUM_LANE (P): channels per cycle in DWConv, out_norm and the gate (a token is 2C / P chunks); the block's pace
//   is set by the linear layers (one output channel per cycle), so P well below 2C costs little time.
//
//   WB window (byte addresses from WB_BASE, in this order, every section padded to a word; 4 bytes per 32-bit word,
//   the lowest-index element in bits [7:0]; int32 values one per word) = emy_wb_map_pkg window '<block>_ss2d':
//     in_proj W [2D][C] (rows padded), rshift [2D] | DWConv W [D][9] (contiguous), bias [D] (int32), rshift [D]
//     core windows of directions 0..3 (XProj W, rshift; DtProj W, bias, rshift; A, D) | LightNorm w [D], b [D], LUT [256] (words)
//     out_proj W [C][D], rshift [C]
//   The loaders inside count words from the first address of their section, so every section must arrive in
//   ascending address order with no gap (a plain sweep of the image does).
//
// Dependencies: Requant (rtl/ops), emy_silu_pwl (rtl/core); Linear_Transform_PerCh, DWConv2d_3x3, CrossScan,
//               SS2D_Core4, CrossMerge, LightNormInt, Gate_Lanes, Wb_Row_Loader, Fifo2, Requant_Var_Pipe,
//               Requant_Lane (rtl/ss2d); shifter_left / shifter_right / saturator (rtl/emamba)
//////////////////////////////////////////////////////////////////////////////////
module SS2D import emy_pkg::*; #(
    parameter integer NUM_C       = 32,     // block channels; D = 2C
    parameter integer NUM_H       = 160,
    parameter integer NUM_W       = 160,
    parameter integer NUM_R       = 2,
    parameter integer NUM_N       = 16,

    // requant between steps (s_from - s_to)
    parameter integer SH_08_09    = 0,
    parameter integer SH_09_10    = 0,
    parameter integer SH_09_11    = 1,
    parameter integer SH_11_12    = 0,
    parameter integer SH_12_U0    = 0,
    parameter integer SH_12_U1    = 0,
    parameter integer SH_12_U2    = 0,
    parameter integer SH_12_U3    = 0,

    // 10 / 12 SiLU: in / out shift
    parameter integer S10_IN      = 4,
    parameter integer S10_OUT     = 4,
    parameter integer S12_IN      = 4,
    parameter integer S12_OUT     = 4,

    // core shifts, direction 0
    parameter integer K0_S_U      = 4,
    parameter integer K0_S_DELTA  = 5,
    parameter integer K0_S_A      = 6,
    parameter integer K0_S_DA     = 7,
    parameter integer K0_S_B      = 7,
    parameter integer K0_S_DB     = 5,
    parameter integer K0_S_C      = 7,
    parameter integer K0_S_D      = 10,
    parameter integer K0_S_Y      = 5,
    // core shifts, direction 1
    parameter integer K1_S_U      = 4,
    parameter integer K1_S_DELTA  = 5,
    parameter integer K1_S_A      = 6,
    parameter integer K1_S_DA     = 7,
    parameter integer K1_S_B      = 7,
    parameter integer K1_S_DB     = 5,
    parameter integer K1_S_C      = 7,
    parameter integer K1_S_D      = 10,
    parameter integer K1_S_Y      = 5,
    // core shifts, direction 2
    parameter integer K2_S_U      = 4,
    parameter integer K2_S_DELTA  = 5,
    parameter integer K2_S_A      = 6,
    parameter integer K2_S_DA     = 7,
    parameter integer K2_S_B      = 7,
    parameter integer K2_S_DB     = 5,
    parameter integer K2_S_C      = 7,
    parameter integer K2_S_D      = 10,
    parameter integer K2_S_Y      = 5,
    // core shifts, direction 3
    parameter integer K3_S_U      = 4,
    parameter integer K3_S_DELTA  = 5,
    parameter integer K3_S_A      = 6,
    parameter integer K3_S_DA     = 7,
    parameter integer K3_S_B      = 7,
    parameter integer K3_S_DB     = 5,
    parameter integer K3_S_C      = 7,
    parameter integer K3_S_D      = 10,
    parameter integer K3_S_Y      = 5,

    // 17 CrossMerge (T - s_y[k]) and the requant into 18 (T - s_in 18)
    parameter integer CM_LSH_0    = 0,
    parameter integer CM_LSH_1    = 0,
    parameter integer CM_LSH_2    = 0,
    parameter integer CM_LSH_3    = 0,
    parameter integer CM_RSH      = 1,
    // 18 LightNorm: s_in, s_w, s_b, s_out (s_in only through the INV table of the window)
    parameter integer S18_IN      = 3,
    parameter integer S18_W       = 4,
    parameter integer S18_B       = 6,
    parameter integer S18_OUT     = 3,
    // 19 gate: s_out 18, s_out 10, s_in 20
    parameter integer G_S1        = 2,
    parameter integer G_S2        = 4,
    parameter integer G_SO        = 3,

    parameter integer WB_BASE     = 0,              // byte address of the block's SS2D window (word-aligned)
    parameter integer NUM_LANE    = 8               // channels per cycle in DWConv, out_norm, gate (divides 2 * NUM_C)
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn [0:NUM_C-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:NUM_C-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer NUM_D     = 2 * NUM_C;
localparam integer NUM_PIXEL = NUM_H * NUM_W;
localparam integer PIX_W     = $clog2(NUM_PIXEL + 1);
localparam integer NUM_DBC   = NUM_R + 2 * NUM_N;
localparam integer LN_F      = 20;                                      // fraction bits of the INV table (SW LN_F)
localparam integer LN_LSH    = LN_F + S18_W - S18_B;
localparam integer LN_RSH    = LN_F + S18_W - S18_OUT;

// the window ('<block>_ss2d', every section a whole number of words)
localparam integer IP_W      = WB_BASE;
localparam integer IP_S      = IP_W + 2 * NUM_D * ceil4(NUM_C);          // weight rows padded to a word
localparam integer DW_W      = IP_S + ceil4(2 * NUM_D);
localparam integer DW_B      = DW_W + ceil4(NUM_D * 9);
localparam integer DW_S      = DW_B + NUM_D * 4;
localparam integer CORE_BASE = DW_S + ceil4(NUM_D);
localparam integer CORE_SIZE = NUM_DBC * ceil4(NUM_D) + ceil4(NUM_DBC) + NUM_D * ceil4(NUM_R) + NUM_D * 4
                             + ceil4(NUM_D) + NUM_D * NUM_N + ceil4(NUM_D);
localparam integer LN_W      = CORE_BASE + 4 * CORE_SIZE;
localparam integer LN_B      = LN_W + ceil4(NUM_D);
localparam integer LN_L      = LN_B + ceil4(NUM_D);
localparam integer OP_W      = LN_L + 256 * 4;
localparam integer OP_S      = OP_W + NUM_C * ceil4(NUM_D);
localparam integer WB_END    = OP_S + ceil4(NUM_C);

localparam LOAD  = 2'd0,
           SCAN  = 2'd1,
           MERGE = 2'd2,
           DONE  = 2'd3;

// ---------- Internal Variables ---------- //
logic [1:0] state;
logic [1:0] cur_dir;
logic       start_pulse, merge_pulse;
logic       ps_i;                         // ps_start or the internal restart after a frame
logic [PIX_W-1:0] in_count, x_count, y_count, z_wr, z_rd, out_count;

// 09-12
logic signed [ACT_W-1:0] in_rq    [0:NUM_C-1];
logic signed [ACT_W-1:0] ip_out   [0:2*NUM_D-1];
logic signed [ACT_W-1:0] ip_x     [0:NUM_D-1];
logic signed [ACT_W-1:0] ip_z     [0:NUM_D-1];
logic signed [ACT_W-1:0] x_rq     [0:NUM_D-1];
logic signed [ACT_W-1:0] z_rq     [0:NUM_D-1];
logic signed [ACT_W-1:0] z10      [0:NUM_D-1];
logic signed [ACT_W-1:0] dw_out   [0:NUM_D-1];
logic signed [ACT_W-1:0] x12_rq   [0:NUM_D-1];
logic signed [ACT_W-1:0] x12      [0:NUM_D-1];
logic [ACT_W*NUM_D-1:0]  z_mem    [0:NUM_PIXEL-1];         // Z buffer: one token per address, registered read
logic [ACT_W*NUM_D-1:0]  z_row, z_q;
logic [PIX_W-1:0]        z_q_addr;
logic signed [ACT_W-1:0] z_tok    [0:NUM_D-1];
logic                    z_ok;
logic ip_s_valid, ip_s_ready, ip_m_valid, dw_s_ready, dw_m_valid, cs_s_ready;

// 13-17
logic signed [ACT_W-1:0]  u_tok    [0:NUM_D-1];
logic signed [ACT_W-1:0]  core_y   [0:NUM_D-1];
logic signed [ACT_W-1:0]  cm_in    [0:NUM_D-1];
logic signed [ACT_W-1:0]  cm_out   [0:NUM_D-1];
logic signed [WIDE_W-1:0] cm_wide  [0:NUM_D-1];
logic cs_m_valid, cs_m_ready, cm_s_valid, cm_s_ready, cm_m_valid;
logic core_s_ready, core_m_valid;

// 18-20
logic signed [ACT_W-1:0] ln_out  [0:NUM_D-1];
logic signed [ACT_W-1:0] gate    [0:NUM_D-1];
logic ln_s_ready, ln_m_valid, ln_m_ready, gt_s_valid, gt_s_ready, op_s_valid, op_s_ready;

genvar g, k;

// ---------- Frame sequencer ---------- //
assign ps_i = ps_start || (state == DONE);

always @(posedge clk) begin
    if (!nRst || ps_i) begin
        state       <= #1 LOAD;
        cur_dir     <= #1 2'd0;
        start_pulse <= #1 1'b0;
        merge_pulse <= #1 1'b0;
        in_count    <= #1 '0;
        x_count     <= #1 '0;
        y_count     <= #1 '0;
        z_wr        <= #1 '0;
        z_rd        <= #1 '0;
        out_count   <= #1 '0;
    end else begin
        start_pulse <= #1 1'b0;
        merge_pulse <= #1 1'b0;
        if (s_valid && s_ready)       in_count  <= #1 in_count + 1'b1;
        if (ip_m_valid && dw_s_ready) z_wr      <= #1 z_wr + 1'b1;
        if (dw_m_valid && cs_s_ready) x_count   <= #1 x_count + 1'b1;
        if (gt_s_valid && gt_s_ready) z_rd      <= #1 z_rd + 1'b1;
        if (m_valid && m_ready)       out_count <= #1 out_count + 1'b1;
        case (state)
            LOAD: if (x_count == NUM_PIXEL) begin
                state       <= #1 SCAN;
                cur_dir     <= #1 2'd0;
                y_count     <= #1 '0;
                start_pulse <= #1 1'b1;
            end
            SCAN: if (cm_s_valid && cm_s_ready) begin
                if (y_count == NUM_PIXEL - 1) begin
                    y_count <= #1 '0;
                    if (cur_dir == 2'd3) begin
                        state       <= #1 MERGE;
                        merge_pulse <= #1 1'b1;
                    end else begin
                        cur_dir     <= #1 cur_dir + 1'b1;
                        start_pulse <= #1 1'b1;
                    end
                end else begin
                    y_count <= #1 y_count + 1'b1;
                end
            end
            MERGE: if (m_valid && m_ready && out_count == NUM_PIXEL - 1) state <= #1 DONE;
            default: ;
        endcase
    end
end

// ---------- 08 -> 09 -> 10 / 11 -> 12 ---------- //
assign ip_s_valid = s_valid && (state == LOAD) && (in_count < NUM_PIXEL);
assign s_ready    = ip_s_ready && (state == LOAD) && (in_count < NUM_PIXEL);

Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(SH_08_09),
    .NUM_SCALE_DOUT(0)
) Rq_08_09 (
    .dIn(dIn),
    .dOut(in_rq)
);

Linear_Transform_PerCh #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM_IN(NUM_C),
    .NUM_DIM_OUT(2 * NUM_D),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(IP_W),
    .WB_BASE_B(IP_S),
    .WB_BASE_S(IP_S)
) in_proj (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .bank(1'b0),

    .dIn(in_rq),
    .s_valid(ip_s_valid),
    .s_ready(ip_s_ready),

    .dOut(ip_out),
    .m_valid(ip_m_valid),
    .m_ready(dw_s_ready)           // fork: z is written in the same cycle
);

// in_proj output: first D = x, last D = z
generate
    for (g = 0; g < NUM_D; g = g + 1) begin : Split_09
        assign ip_x[g] = ip_out[g];
        assign ip_z[g] = ip_out[NUM_D + g];
    end
endgenerate

Requant #(
    .NUM_DIM(NUM_D),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(SH_09_11),
    .NUM_SCALE_DOUT(0)
) Rq_09_11 (
    .dIn(ip_x),
    .dOut(x_rq)
);

Requant #(
    .NUM_DIM(NUM_D),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(SH_09_10),
    .NUM_SCALE_DOUT(0)
) Rq_09_10 (
    .dIn(ip_z),
    .dOut(z_rq)
);

Requant #(
    .NUM_DIM(NUM_D),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(SH_11_12),
    .NUM_SCALE_DOUT(0)
) Rq_11_12 (
    .dIn(dw_out),
    .dOut(x12_rq)
);

emy_silu_pwl #(
    .NUM_DIM(NUM_D),
    .NUM_SCALE_DIN(S10_IN),
    .NUM_SCALE_DOUT(S10_OUT)
) silu_z (
    .dIn(z_rq),

    .dOut(z10)
);

emy_silu_pwl #(
    .NUM_DIM(NUM_D),
    .NUM_SCALE_DIN(S12_IN),
    .NUM_SCALE_DOUT(S12_OUT)
) silu_x (
    .dIn(x12_rq),

    .dOut(x12)
);

generate
    for (g = 0; g < NUM_D; g = g + 1) begin : Z_Pack
        assign z_row[g*ACT_W +: ACT_W] = z10[g];
        assign z_tok[g]                = z_q[g*ACT_W +: ACT_W];
    end
endgenerate

always @(posedge clk) begin
    if (ip_m_valid && dw_s_ready)
        z_mem[z_wr] <= #1 z_row;
end

// The Z buffer is read every cycle at z_rd; z_q_addr says which token z_q holds. The gate's handshake waits
// until it is token z_rd (one cycle after each step of z_rd).
always @(posedge clk) begin
    if (z_rd < NUM_PIXEL) z_q <= #1 z_mem[z_rd];       // z_rd = NUM_PIXEL after the last token
end

always @(posedge clk) begin
    if (!nRst || ps_i) z_q_addr <= #1 '1;
    else               z_q_addr <= #1 z_rd;
end

assign z_ok       = (z_q_addr == z_rd) && (state == MERGE);
assign gt_s_valid = ln_m_valid && z_ok;
assign ln_m_ready = gt_s_ready && z_ok;

DWConv2d_3x3 #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM(NUM_D),
    .NUM_H(NUM_H),
    .NUM_W(NUM_W),
    .NUM_LANE(NUM_LANE),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(DW_W),
    .WB_BASE_B(DW_B),
    .WB_BASE_S(DW_S)
) dwconv (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(x_rq),
    .s_valid(ip_m_valid),
    .s_ready(dw_s_ready),

    .dOut(dw_out),
    .m_valid(dw_m_valid),
    .m_ready(cs_s_ready)
);

// ---------- 13 -> cores -> 17 ---------- //
CrossScan #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM(NUM_D),
    .NUM_H(NUM_H),
    .NUM_W(NUM_W),
    .NUM_SHIFT_0(SH_12_U0),
    .NUM_SHIFT_1(SH_12_U1),
    .NUM_SHIFT_2(SH_12_U2),
    .NUM_SHIFT_3(SH_12_U3)
) cross_scan (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .dIn(x12),
    .s_valid(dw_m_valid),
    .s_ready(cs_s_ready),

    .dir(cur_dir),
    .start(start_pulse),
    .dOut(u_tok),
    .m_valid(cs_m_valid),
    .m_ready(cs_m_ready)
);

assign cs_m_ready = (state == SCAN) && core_s_ready;
assign cm_s_valid = (state == SCAN) && core_m_valid;
assign cm_in      = core_y;

// the four directions through one core: one XProj / DtProj (weight bank = direction), a SelectiveScan per direction
SS2D_Core4 #(
    .DATA_WIDTH(ACT_W),
    .NUM_SEQLEN(NUM_PIXEL),
    .NUM_DIM(NUM_D),
    .NUM_R(NUM_R),
    .NUM_N(NUM_N),
    .K0_S_U(K0_S_U), .K0_S_DELTA(K0_S_DELTA), .K0_S_A(K0_S_A), .K0_S_DA(K0_S_DA), .K0_S_B(K0_S_B),
    .K0_S_DB(K0_S_DB), .K0_S_C(K0_S_C), .K0_S_D(K0_S_D), .K0_S_Y(K0_S_Y),
    .K1_S_U(K1_S_U), .K1_S_DELTA(K1_S_DELTA), .K1_S_A(K1_S_A), .K1_S_DA(K1_S_DA), .K1_S_B(K1_S_B),
    .K1_S_DB(K1_S_DB), .K1_S_C(K1_S_C), .K1_S_D(K1_S_D), .K1_S_Y(K1_S_Y),
    .K2_S_U(K2_S_U), .K2_S_DELTA(K2_S_DELTA), .K2_S_A(K2_S_A), .K2_S_DA(K2_S_DA), .K2_S_B(K2_S_B),
    .K2_S_DB(K2_S_DB), .K2_S_C(K2_S_C), .K2_S_D(K2_S_D), .K2_S_Y(K2_S_Y),
    .K3_S_U(K3_S_U), .K3_S_DELTA(K3_S_DELTA), .K3_S_A(K3_S_A), .K3_S_DA(K3_S_DA), .K3_S_B(K3_S_B),
    .K3_S_DB(K3_S_DB), .K3_S_C(K3_S_C), .K3_S_D(K3_S_D), .K3_S_Y(K3_S_Y),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE(CORE_BASE),
    .CORE_SIZE(CORE_SIZE)
) core (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dir(cur_dir),

    .dIn(u_tok),
    .s_valid((state == SCAN) && cs_m_valid),
    .s_ready(core_s_ready),

    .dOut(core_y),
    .m_valid(core_m_valid),
    .m_ready((state == SCAN) && cm_s_ready)
);

CrossMerge #(
    .DATA_WIDTH(ACT_W),
    .WIDE_WIDTH(WIDE_W),
    .NUM_DIM(NUM_D),
    .NUM_H(NUM_H),
    .NUM_W(NUM_W),
    .NUM_LSH_0(CM_LSH_0),
    .NUM_LSH_1(CM_LSH_1),
    .NUM_LSH_2(CM_LSH_2),
    .NUM_LSH_3(CM_LSH_3),
    .NUM_RSH(CM_RSH)
) cross_merge (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .dir(cur_dir),
    .start(start_pulse),
    .dIn(cm_in),
    .s_valid(cm_s_valid),
    .s_ready(cm_s_ready),

    .merge(merge_pulse),
    .dOut(cm_out),
    .dOut_wide(cm_wide),
    .m_valid(cm_m_valid),
    .m_ready(ln_s_ready)
);

// ---------- 18 -> 19 -> 20 ---------- //
LightNormInt #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM(NUM_D),
    .NUM_LANE(NUM_LANE),
    .NUM_LSH_BIAS(LN_LSH),
    .NUM_RSH_DOUT(LN_RSH),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LN_W),
    .WB_BASE_B(LN_B),
    .WB_BASE_L(LN_L)
) out_norm (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(cm_out),
    .dOut(ln_out),

    .s_valid(cm_m_valid),
    .s_ready(ln_s_ready),
    .m_valid(ln_m_valid),
    .m_ready(ln_m_ready)
);

Gate_Lanes #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM(NUM_D),
    .NUM_LANE(NUM_LANE),
    .NUM_SCALE_DIN_1(G_S1),
    .NUM_SCALE_DIN_2(G_S2),
    .NUM_SCALE_DOUT(G_SO)
) gate_mul (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .dIn_1(ln_out),
    .dIn_2(z_tok),
    .dOut(gate),

    .s_valid(gt_s_valid),
    .s_ready(gt_s_ready),
    .m_valid(op_s_valid),
    .m_ready(op_s_ready)
);

Linear_Transform_PerCh #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM_IN(NUM_D),
    .NUM_DIM_OUT(NUM_C),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(OP_W),
    .WB_BASE_B(OP_S),
    .WB_BASE_S(OP_S)
) out_proj (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .bank(1'b0),

    .dIn(gate),
    .dOut(dOut),

    .s_valid(op_s_valid),
    .s_ready(op_s_ready),
    .m_valid(m_valid),
    .m_ready(m_ready)
);

// ---------- Parameter guards ---------- //
generate
    if (WB_END > (64'd1 << WB_ADDR_W))
        $error("SS2D: the WB window does not fit WB_ADDR_W");
    if (WB_BASE < 0 || WB_BASE % 4 != 0)
        $error("SS2D: WB_BASE must be a non-negative multiple of 4");
    if (NUM_D % NUM_LANE != 0)
        $error("SS2D: NUM_LANE must divide 2 * NUM_C");
    if (LN_LSH < 0)
        $error("SS2D: LightNorm F + s_w - s_b < 0 not supported");
endgenerate

endmodule
