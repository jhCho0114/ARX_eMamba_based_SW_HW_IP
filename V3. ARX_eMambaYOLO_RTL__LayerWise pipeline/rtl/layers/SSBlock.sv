`timescale 1ns / 1ps
// SSBlock : one VSSBlock / XSSBlock (steps 01-29, SS2D 09-20 inside), every size and shift a parameter
//
//   The ten blocks of the model (L01 / L03 / L05 x3 / L07 VSSBlock, L11 / L14 / L17 / L20 XSSBlock) are this module
//   with the numbers of rtl/Lxx/<block>.sv (generated wrappers). XSSBlock = VSSBlock with
//   NUM_CIN != NUM_C (step 01 projects the concat input to C). The wiring is the one of the generated blocks of
//   earlier per-block version, bit exact against the v002 LOG at every step output.
//
//   instance         step (LOG / int8_WB)      module        | instance         step                 module
//   s01_Conv1x1      01 proj / in_proj Conv2d  Conv1x1       | s21_Add          21 Add               Add
//   s02_SiLU         02 proj / in_proj SiLU    SiLU          | s22_LightNorm    22 norm2 LightNorm   LightNorm
//   s03_DWConv3x3    03 ls_fc1 DWConv2d        DWConv3x3     | s23_Conv1x1      23 mlp_fc1 Conv2d    Conv1x1
//   s04_Conv1x1      04 ls_fc2 Conv2d          Conv1x1       | s24_DWConv3x3    24 mlp DWConv2d      DWConv3x3
//   s05_SiLU         05 ls SiLU                SiLU          | s25_Add          25 mlp Add           Add
//   s06_Conv1x1      06 ls_fc3 Conv2d          Conv1x1       | s26_SiLU         26 mlp SiLU          SiLU
//   s07_Add          07 ls Add                 Add           | s27_Mul          27 mlp Mul           Mul
//   s08_LightNorm    08 norm LightNorm         LightNorm     | s28_Conv1x1      28 mlp_fc2 Conv2d    Conv1x1
//   ss2d             09-20 ss2d_*              SS2D          | s29_Add          29 Add               Add
//
//   Streams: pixel vectors in raster order, Linear_Transform_Dynamic_WB valid / ready. A value with n consumers goes
//   through n-1 chained emy_stream_fork (sNN_fork_b<i>); an Add / Mul operand that arrives earlier than the other
//   waits in a one-frame emy_stream_fifo (sNN_in<j>_fifo). Step 23 -> x = [0:NUM_HID-1], v = [NUM_HID:2*NUM_HID-1].
//   Every Conv / DW / SiLU / LightNorm input has a Requant (sNN_requant) from the shift of its source to the
//   step's input shift: a wire when the shifts are equal and the source is int8, sat8(rshr) after an Add / Mul
//   (wide). The block output is the 29 Add: int8 at S_OUT (DOUT_W = ACT_W) or the wide sum (DOUT_W = WIDE_W).
//
//   Parameters are the step graph numbers only (channels, map size, the int8_WB / LOG quant.json shifts, the WB
//   windows of emy_wb_map_pkg); everything the model fixes by arithmetic is a localparam below (D = 2C, dt_rank
//   R = C / 16, d_state N = 16, MLP hidden = C * 8 / 3, Add / Mul output shifts, the requant shifts, the SS2D
//   boundary shifts). Shift names: S<step>_IN / S<step>_OUT = in / out shift of the step, S<step>_W / _B = the
//   LightNorm weight / bias shifts, K<k>_S_* = SS2D core shifts of direction k (shifts.json), S_IN / S_OUT = the
//   block input (previous layer_out pass) / output shift.
//   wb_* : weight / bias broadcast (load before ps_start). frame_done : one-cycle pulse when the last block output
//   pixel of a frame has been taken; frames stream continuously after one ps_start (no s_valid in the ps_start cycle).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module SSBlock import emy_pkg::*; #(
    // geometry
    parameter integer NUM_CIN  = 32,          // block input channels (XSSBlock: the concat width)
    parameter integer NUM_C    = 32,          // block channels C
    parameter integer NUM_H    = 160,
    parameter integer NUM_W    = 160,
    parameter integer DIN_W    = ACT_W,       // WIDE_W when the previous block hands on its wide 29 sum
    parameter integer DOUT_W   = ACT_W,       // WIDE_W when this block hands on its wide 29 sum

    // block input / output shift
    parameter integer S_IN     = 0,
    parameter integer S_OUT    = 3,           // only with DOUT_W = ACT_W

    // steps 01-08
    parameter integer S01_IN   = 0,
    parameter integer S01_OUT  = 1,
    parameter integer S02_IN   = 1,
    parameter integer S02_OUT  = 3,
    parameter integer S03_IN   = 3,
    parameter integer S03_OUT  = 3,
    parameter integer S04_IN   = 3,
    parameter integer S04_OUT  = 2,
    parameter integer S05_IN   = 2,
    parameter integer S05_OUT  = 2,
    parameter integer S06_IN   = 2,
    parameter integer S06_OUT  = 4,
    parameter integer S08_IN   = 3,
    parameter integer S08_W    = 4,
    parameter integer S08_B    = 5,
    parameter integer S08_OUT  = 3,

    // SS2D 09-20
    parameter integer S09_IN   = 3,
    parameter integer S09_OUT  = 4,
    parameter integer S10_IN   = 4,
    parameter integer S10_OUT  = 4,
    parameter integer S11_IN   = 3,
    parameter integer S11_OUT  = 4,
    parameter integer S12_IN   = 4,
    parameter integer S12_OUT  = 4,
    parameter integer K0_S_U   = 4,
    parameter integer K0_S_DELTA = 5,
    parameter integer K0_S_A   = 6,
    parameter integer K0_S_DA  = 7,
    parameter integer K0_S_B   = 7,
    parameter integer K0_S_DB  = 5,
    parameter integer K0_S_C   = 7,
    parameter integer K0_S_D   = 10,
    parameter integer K0_S_Y   = 5,
    parameter integer K1_S_U   = 4,
    parameter integer K1_S_DELTA = 5,
    parameter integer K1_S_A   = 6,
    parameter integer K1_S_DA  = 7,
    parameter integer K1_S_B   = 7,
    parameter integer K1_S_DB  = 5,
    parameter integer K1_S_C   = 7,
    parameter integer K1_S_D   = 10,
    parameter integer K1_S_Y   = 5,
    parameter integer K2_S_U   = 4,
    parameter integer K2_S_DELTA = 5,
    parameter integer K2_S_A   = 6,
    parameter integer K2_S_DA  = 7,
    parameter integer K2_S_B   = 7,
    parameter integer K2_S_DB  = 5,
    parameter integer K2_S_C   = 7,
    parameter integer K2_S_D   = 10,
    parameter integer K2_S_Y   = 5,
    parameter integer K3_S_U   = 4,
    parameter integer K3_S_DELTA = 5,
    parameter integer K3_S_A   = 6,
    parameter integer K3_S_DA  = 7,
    parameter integer K3_S_B   = 7,
    parameter integer K3_S_DB  = 5,
    parameter integer K3_S_C   = 7,
    parameter integer K3_S_D   = 10,
    parameter integer K3_S_Y   = 5,
    parameter integer S18_IN   = 4,
    parameter integer S18_W    = 3,
    parameter integer S18_B    = 6,
    parameter integer S18_OUT  = 2,
    parameter integer S20_IN   = 3,
    parameter integer S20_OUT  = 4,

    // steps 21-29
    parameter integer S22_IN   = 3,
    parameter integer S22_W    = 4,
    parameter integer S22_B    = 5,
    parameter integer S22_OUT  = 3,
    parameter integer S23_IN   = 3,
    parameter integer S23_OUT  = 3,
    parameter integer S24_IN   = 3,
    parameter integer S24_OUT  = 3,
    parameter integer S26_IN   = 3,
    parameter integer S26_OUT  = 3,
    parameter integer S28_IN   = 3,
    parameter integer S28_OUT  = 4,

    // weight / bias windows (byte addresses, emy_wb_map_pkg::WB_<step>; WB_SS2D = WB_<block>_ss2d, steps 09-20)
    parameter integer WB_01    = 0,
    parameter integer WB_03    = 0,
    parameter integer WB_04    = 0,
    parameter integer WB_06    = 0,
    parameter integer WB_08    = 0,
    parameter integer WB_SS2D  = 0,
    parameter integer WB_22    = 0,
    parameter integer WB_23    = 0,
    parameter integer WB_24    = 0,
    parameter integer WB_28    = 0,

    // channels per cycle in DWConv (03 / 11 / 24), LightNorm (08 / 18 / 22) and the SS2D gate; a DWConv whose
    // channel count is not a multiple of it (24: C * 8 / 3) runs all its channels in parallel
    parameter integer NUM_LANE = 8
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [DIN_W-1:0] dIn [0:NUM_CIN-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [DOUT_W-1:0] dOut [0:NUM_C-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

// ---------- Local Parameters: fixed by the model ---------- //
localparam integer NUM_PIX = NUM_H * NUM_W;
localparam integer NUM_R   = NUM_C / 16;                  // dt_rank
localparam integer NUM_N   = 16;                          // d_state
localparam integer NUM_HID = (NUM_C * 8) / 3;             // RGBlock hidden h'; 23 mlp_fc1 outputs [x; v] = 2h'

// Add / Mul output shifts (Add: T = max of the operands, Mul: the sum), the inputs of the wide requants
localparam integer S07 = (S02_OUT > S06_OUT) ? S02_OUT : S06_OUT;
localparam integer S21 = (S02_OUT > S20_OUT) ? S02_OUT : S20_OUT;
localparam integer S25 = (S24_OUT > S23_OUT) ? S24_OUT : S23_OUT;
localparam integer S27 = S26_OUT + S23_OUT;
localparam integer S29 = (S21 > S28_OUT) ? S21 : S28_OUT;

// SS2D boundary shifts (s_from - s_to) and the CrossMerge alignment T = max s_y
localparam integer T_Y   = ((K0_S_Y > K1_S_Y) ? K0_S_Y : K1_S_Y) > ((K2_S_Y > K3_S_Y) ? K2_S_Y : K3_S_Y) ?
                           ((K0_S_Y > K1_S_Y) ? K0_S_Y : K1_S_Y) : ((K2_S_Y > K3_S_Y) ? K2_S_Y : K3_S_Y);

// ---------- Internal Variables ---------- //
logic signed [DIN_W-1:0]  blk_in_dOut   [0:NUM_CIN-1];
logic                     blk_in_valid, blk_in_ready;
logic signed [ACT_W-1:0]  s01_rq        [0:NUM_CIN-1];
logic signed [ACT_W-1:0]  s01_dOut      [0:NUM_C-1];
logic                     s01_valid, s01_ready;
logic signed [ACT_W-1:0]  s02_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s02_dOut      [0:NUM_C-1];
logic                     s02_valid, s02_ready;
logic signed [ACT_W-1:0]  s02_b0_dOut   [0:NUM_C-1];
logic                     s02_b0_valid, s02_b0_ready;
logic signed [ACT_W-1:0]  s02_r0_dOut   [0:NUM_C-1];
logic                     s02_r0_valid, s02_r0_ready;
logic signed [ACT_W-1:0]  s02_b1_dOut   [0:NUM_C-1];
logic                     s02_b1_valid, s02_b1_ready;
logic signed [ACT_W-1:0]  s02_b2_dOut   [0:NUM_C-1];
logic                     s02_b2_valid, s02_b2_ready;
logic signed [ACT_W-1:0]  s02_b1_q_dOut [0:NUM_C-1];
logic                     s02_b1_q_valid, s02_b1_q_ready;
logic signed [ACT_W-1:0]  s02_b2_q_dOut [0:NUM_C-1];
logic                     s02_b2_q_valid, s02_b2_q_ready;
logic signed [ACT_W-1:0]  s03_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s03_dOut      [0:NUM_C-1];
logic                     s03_valid, s03_ready;
logic signed [ACT_W-1:0]  s04_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s04_dOut      [0:NUM_C-1];
logic                     s04_valid, s04_ready;
logic signed [ACT_W-1:0]  s05_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s05_dOut      [0:NUM_C-1];
logic                     s05_valid, s05_ready;
logic signed [ACT_W-1:0]  s06_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s06_dOut      [0:NUM_C-1];
logic                     s06_valid, s06_ready;
logic signed [WIDE_W-1:0] s07_dOut      [0:NUM_C-1];
logic                     s07_valid, s07_ready;
logic signed [ACT_W-1:0]  s08_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s08_dOut      [0:NUM_C-1];
logic                     s08_valid, s08_ready;
logic signed [ACT_W-1:0]  ss2d_in_dOut  [0:NUM_C-1];
logic                     ss2d_in_valid, ss2d_in_ready;
logic signed [WIDE_W-1:0] s21_dOut      [0:NUM_C-1];
logic                     s21_valid, s21_ready;
logic signed [WIDE_W-1:0] s21_b0_dOut   [0:NUM_C-1];
logic                     s21_b0_valid, s21_b0_ready;
logic signed [WIDE_W-1:0] s21_b1_dOut   [0:NUM_C-1];
logic                     s21_b1_valid, s21_b1_ready;
logic signed [WIDE_W-1:0] s21_b1_q_dOut [0:NUM_C-1];
logic                     s21_b1_q_valid, s21_b1_q_ready;
logic signed [ACT_W-1:0]  s22_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s22_dOut      [0:NUM_C-1];
logic                     s22_valid, s22_ready;
logic signed [ACT_W-1:0]  s23_rq        [0:NUM_C-1];
logic signed [ACT_W-1:0]  s23_dOut      [0:2*NUM_HID-1];
logic                     s23_valid, s23_ready;
logic signed [ACT_W-1:0]  s23_b0_dOut   [0:2*NUM_HID-1];
logic                     s23_b0_valid, s23_b0_ready;
logic signed [ACT_W-1:0]  s23_r0_dOut   [0:2*NUM_HID-1];
logic                     s23_r0_valid, s23_r0_ready;
logic signed [ACT_W-1:0]  s23_b1_dOut   [0:2*NUM_HID-1];
logic                     s23_b1_valid, s23_b1_ready;
logic signed [ACT_W-1:0]  s23_b2_dOut   [0:2*NUM_HID-1];
logic                     s23_b2_valid, s23_b2_ready;
logic signed [ACT_W-1:0]  s23_b0_sl     [0:NUM_HID-1];
logic signed [ACT_W-1:0]  s23_b1_sl     [0:NUM_HID-1];
logic signed [ACT_W-1:0]  s23_b2_sl     [0:NUM_HID-1];
logic signed [ACT_W-1:0]  s23_b1_q_dOut [0:NUM_HID-1];
logic                     s23_b1_q_valid, s23_b1_q_ready;
logic signed [ACT_W-1:0]  s23_b2_q_dOut [0:NUM_HID-1];
logic                     s23_b2_q_valid, s23_b2_q_ready;
logic signed [ACT_W-1:0]  s24_rq        [0:NUM_HID-1];
logic signed [ACT_W-1:0]  s24_dOut      [0:NUM_HID-1];
logic                     s24_valid, s24_ready;
logic signed [WIDE_W-1:0] s25_dOut      [0:NUM_HID-1];
logic                     s25_valid, s25_ready;
logic signed [ACT_W-1:0]  s26_rq        [0:NUM_HID-1];
logic signed [ACT_W-1:0]  s26_dOut      [0:NUM_HID-1];
logic                     s26_valid, s26_ready;
logic signed [WIDE_W-1:0] s27_dOut      [0:NUM_HID-1];
logic                     s27_valid, s27_ready;
logic signed [ACT_W-1:0]  s28_rq        [0:NUM_HID-1];
logic signed [ACT_W-1:0]  s28_dOut      [0:NUM_C-1];
logic                     s28_valid, s28_ready;
logic signed [WIDE_W-1:0] s29_wide      [0:NUM_C-1];
logic signed [DOUT_W-1:0] s29_dOut      [0:NUM_C-1];
logic                     s29_valid, s29_ready;

// ---------- module ports ---------- //
assign blk_in_dOut   = dIn;
assign blk_in_valid  = s_valid;
assign s_ready       = blk_in_ready;

// ---------- forks (broadcast to every consumer of a value) ---------- //
emy_stream_fork #(
    .NUM_DIM(NUM_C),
    .DATA_W(ACT_W)
) s02_fork_b0 (
    .dIn(s02_dOut),
    .s_valid(s02_valid),
    .s_ready(s02_ready),

    .dOut0(s02_b0_dOut),
    .m_valid0(s02_b0_valid),
    .m_ready0(s02_b0_ready),

    .dOut1(s02_r0_dOut),
    .m_valid1(s02_r0_valid),
    .m_ready1(s02_r0_ready)
);

emy_stream_fork #(
    .NUM_DIM(NUM_C),
    .DATA_W(ACT_W)
) s02_fork_b1 (
    .dIn(s02_r0_dOut),
    .s_valid(s02_r0_valid),
    .s_ready(s02_r0_ready),

    .dOut0(s02_b1_dOut),
    .m_valid0(s02_b1_valid),
    .m_ready0(s02_b1_ready),

    .dOut1(s02_b2_dOut),
    .m_valid1(s02_b2_valid),
    .m_ready1(s02_b2_ready)
);

emy_stream_fork #(
    .NUM_DIM(NUM_C),
    .DATA_W(WIDE_W)
) s21_fork_b0 (
    .dIn(s21_dOut),
    .s_valid(s21_valid),
    .s_ready(s21_ready),

    .dOut0(s21_b0_dOut),
    .m_valid0(s21_b0_valid),
    .m_ready0(s21_b0_ready),

    .dOut1(s21_b1_dOut),
    .m_valid1(s21_b1_valid),
    .m_ready1(s21_b1_ready)
);

emy_stream_fork #(
    .NUM_DIM(2*NUM_HID),
    .DATA_W(ACT_W)
) s23_fork_b0 (
    .dIn(s23_dOut),
    .s_valid(s23_valid),
    .s_ready(s23_ready),

    .dOut0(s23_b0_dOut),
    .m_valid0(s23_b0_valid),
    .m_ready0(s23_b0_ready),

    .dOut1(s23_r0_dOut),
    .m_valid1(s23_r0_valid),
    .m_ready1(s23_r0_ready)
);

emy_stream_fork #(
    .NUM_DIM(2*NUM_HID),
    .DATA_W(ACT_W)
) s23_fork_b1 (
    .dIn(s23_r0_dOut),
    .s_valid(s23_r0_valid),
    .s_ready(s23_r0_ready),

    .dOut0(s23_b1_dOut),
    .m_valid0(s23_b1_valid),
    .m_ready0(s23_b1_ready),

    .dOut1(s23_b2_dOut),
    .m_valid1(s23_b2_valid),
    .m_ready1(s23_b2_ready)
);

// ---------- skip operands: one-frame FIFOs ---------- //
emy_stream_fifo #(
    .NUM_DIM(NUM_C),
    .DEPTH(NUM_PIX),
    .DATA_W(ACT_W)
) s07_in0_fifo (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s02_b1_dOut),
    .s_valid(s02_b1_valid),
    .s_ready(s02_b1_ready),

    .dOut(s02_b1_q_dOut),
    .m_ready(s02_b1_q_ready),
    .m_valid(s02_b1_q_valid)
);

emy_stream_fifo #(
    .NUM_DIM(NUM_C),
    .DEPTH(NUM_PIX),
    .DATA_W(ACT_W)
) s21_in0_fifo (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s02_b2_dOut),
    .s_valid(s02_b2_valid),
    .s_ready(s02_b2_ready),

    .dOut(s02_b2_q_dOut),
    .m_ready(s02_b2_q_ready),
    .m_valid(s02_b2_q_valid)
);

emy_stream_fifo #(
    .NUM_DIM(NUM_C),
    .DEPTH(NUM_PIX),
    .DATA_W(WIDE_W)
) s29_in0_fifo (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s21_b1_dOut),
    .s_valid(s21_b1_valid),
    .s_ready(s21_b1_ready),

    .dOut(s21_b1_q_dOut),
    .m_ready(s21_b1_q_ready),
    .m_valid(s21_b1_q_valid)
);

assign s23_b0_sl = s23_b0_dOut[0:NUM_HID-1];
assign s23_b1_sl = s23_b1_dOut[0:NUM_HID-1];
assign s23_b2_sl = s23_b2_dOut[NUM_HID:2*NUM_HID-1];

emy_stream_fifo #(
    .NUM_DIM(NUM_HID),
    .DEPTH(NUM_PIX),
    .DATA_W(ACT_W)
) s25_in1_fifo (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s23_b1_sl),
    .s_valid(s23_b1_valid),
    .s_ready(s23_b1_ready),

    .dOut(s23_b1_q_dOut),
    .m_ready(s23_b1_q_ready),
    .m_valid(s23_b1_q_valid)
);

emy_stream_fifo #(
    .NUM_DIM(NUM_HID),
    .DEPTH(NUM_PIX),
    .DATA_W(ACT_W)
) s27_in1_fifo (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s23_b2_sl),
    .s_valid(s23_b2_valid),
    .s_ready(s23_b2_ready),

    .dOut(s23_b2_q_dOut),
    .m_ready(s23_b2_q_ready),
    .m_valid(s23_b2_q_valid)
);

// ---------- 09-20 SS2D ---------- //
SS2D #(
    .NUM_C(NUM_C),
    .NUM_H(NUM_H),
    .NUM_W(NUM_W),
    .NUM_R(NUM_R),
    .NUM_N(NUM_N),
    .SH_08_09(S08_OUT - S09_IN),
    .SH_09_10(S09_OUT - S10_IN),
    .SH_09_11(S09_OUT - S11_IN),
    .SH_11_12(S11_OUT - S12_IN),
    .SH_12_U0(S12_OUT - K0_S_U),
    .SH_12_U1(S12_OUT - K1_S_U),
    .SH_12_U2(S12_OUT - K2_S_U),
    .SH_12_U3(S12_OUT - K3_S_U),
    .S10_IN(S10_IN),
    .S10_OUT(S10_OUT),
    .S12_IN(S12_IN),
    .S12_OUT(S12_OUT),
    .K0_S_U(K0_S_U),
    .K0_S_DELTA(K0_S_DELTA),
    .K0_S_A(K0_S_A),
    .K0_S_DA(K0_S_DA),
    .K0_S_B(K0_S_B),
    .K0_S_DB(K0_S_DB),
    .K0_S_C(K0_S_C),
    .K0_S_D(K0_S_D),
    .K0_S_Y(K0_S_Y),
    .K1_S_U(K1_S_U),
    .K1_S_DELTA(K1_S_DELTA),
    .K1_S_A(K1_S_A),
    .K1_S_DA(K1_S_DA),
    .K1_S_B(K1_S_B),
    .K1_S_DB(K1_S_DB),
    .K1_S_C(K1_S_C),
    .K1_S_D(K1_S_D),
    .K1_S_Y(K1_S_Y),
    .K2_S_U(K2_S_U),
    .K2_S_DELTA(K2_S_DELTA),
    .K2_S_A(K2_S_A),
    .K2_S_DA(K2_S_DA),
    .K2_S_B(K2_S_B),
    .K2_S_DB(K2_S_DB),
    .K2_S_C(K2_S_C),
    .K2_S_D(K2_S_D),
    .K2_S_Y(K2_S_Y),
    .K3_S_U(K3_S_U),
    .K3_S_DELTA(K3_S_DELTA),
    .K3_S_A(K3_S_A),
    .K3_S_DA(K3_S_DA),
    .K3_S_B(K3_S_B),
    .K3_S_DB(K3_S_DB),
    .K3_S_C(K3_S_C),
    .K3_S_D(K3_S_D),
    .K3_S_Y(K3_S_Y),
    .CM_LSH_0(T_Y - K0_S_Y),
    .CM_LSH_1(T_Y - K1_S_Y),
    .CM_LSH_2(T_Y - K2_S_Y),
    .CM_LSH_3(T_Y - K3_S_Y),
    .CM_RSH(T_Y - S18_IN),
    .S18_IN(S18_IN),
    .S18_W(S18_W),
    .S18_B(S18_B),
    .S18_OUT(S18_OUT),
    .G_S1(S18_OUT),
    .G_S2(S10_OUT),
    .G_SO(S20_IN),
    .WB_BASE(WB_SS2D),
    .NUM_LANE(NUM_LANE)
) ss2d (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s08_dOut),
    .s_valid(s08_valid),
    .s_ready(s08_ready),

    .dOut(ss2d_in_dOut),
    .m_ready(ss2d_in_ready),
    .m_valid(ss2d_in_valid)
);

// ---------- 01 proj Conv2d ---------- //
Requant #(
    .NUM_DIM(NUM_CIN),
    .DIN_W(DIN_W),
    .NUM_SCALE_DIN(S_IN),
    .NUM_SCALE_DOUT(S01_IN)
) s01_requant (
    .dIn(blk_in_dOut),
    .dOut(s01_rq)
);

Conv1x1 #(
    .NUM_CH(NUM_CIN),
    .NUM_OUT(NUM_C),
    .USE_BIAS(1'b1),
    .WB_BASE(WB_01)
) s01_Conv1x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s01_rq),
    .s_valid(blk_in_valid),
    .s_ready(blk_in_ready),

    .dOut(s01_dOut),
    .m_ready(s01_ready),
    .m_valid(s01_valid)
);

// ---------- 02 proj SiLU ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S01_OUT),
    .NUM_SCALE_DOUT(S02_IN)
) s02_requant (
    .dIn(s01_dOut),
    .dOut(s02_rq)
);

SiLU #(
    .NUM_DIM(NUM_C),
    .NUM_SCALE_DIN(S02_IN),
    .NUM_SCALE_DOUT(S02_OUT)
) s02_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s02_rq),
    .s_valid(s01_valid),
    .s_ready(s01_ready),

    .dOut(s02_dOut),
    .m_ready(s02_ready),
    .m_valid(s02_valid)
);

// ---------- 03 ls_fc1 DWConv2d ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S02_OUT),
    .NUM_SCALE_DOUT(S03_IN)
) s03_requant (
    .dIn(s02_b0_dOut),
    .dOut(s03_rq)
);

DWConv3x3 #(
    .NUM_CH(NUM_C),
    .NUM_HEIGHT(NUM_H),
    .NUM_WIDTH(NUM_W),
    .WB_BASE(WB_03),
    .NUM_LANE(NUM_LANE)
) s03_DWConv3x3 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s03_rq),
    .s_valid(s02_b0_valid),
    .s_ready(s02_b0_ready),

    .dOut(s03_dOut),
    .m_ready(s03_ready),
    .m_valid(s03_valid)
);

// ---------- 04 ls_fc2 Conv2d ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S03_OUT),
    .NUM_SCALE_DOUT(S04_IN)
) s04_requant (
    .dIn(s03_dOut),
    .dOut(s04_rq)
);

Conv1x1 #(
    .NUM_CH(NUM_C),
    .NUM_OUT(NUM_C),
    .USE_BIAS(1'b1),
    .WB_BASE(WB_04)
) s04_Conv1x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s04_rq),
    .s_valid(s03_valid),
    .s_ready(s03_ready),

    .dOut(s04_dOut),
    .m_ready(s04_ready),
    .m_valid(s04_valid)
);

// ---------- 05 ls SiLU ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S04_OUT),
    .NUM_SCALE_DOUT(S05_IN)
) s05_requant (
    .dIn(s04_dOut),
    .dOut(s05_rq)
);

SiLU #(
    .NUM_DIM(NUM_C),
    .NUM_SCALE_DIN(S05_IN),
    .NUM_SCALE_DOUT(S05_OUT)
) s05_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s05_rq),
    .s_valid(s04_valid),
    .s_ready(s04_ready),

    .dOut(s05_dOut),
    .m_ready(s05_ready),
    .m_valid(s05_valid)
);

// ---------- 06 ls_fc3 Conv2d ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S05_OUT),
    .NUM_SCALE_DOUT(S06_IN)
) s06_requant (
    .dIn(s05_dOut),
    .dOut(s06_rq)
);

Conv1x1 #(
    .NUM_CH(NUM_C),
    .NUM_OUT(NUM_C),
    .USE_BIAS(1'b1),
    .WB_BASE(WB_06)
) s06_Conv1x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s06_rq),
    .s_valid(s05_valid),
    .s_ready(s05_ready),

    .dOut(s06_dOut),
    .m_ready(s06_ready),
    .m_valid(s06_valid)
);

// ---------- 07 ls Add ---------- //
Add #(
    .NUM_DIM(NUM_C),
    .DIN0_W(ACT_W),
    .DIN1_W(ACT_W),
    .NUM_SCALE_DIN0(S02_OUT),
    .NUM_SCALE_DIN1(S06_OUT)
) s07_Add (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(s02_b1_q_dOut),
    .s_valid0(s02_b1_q_valid),
    .s_ready0(s02_b1_q_ready),

    .dIn1(s06_dOut),
    .s_valid1(s06_valid),
    .s_ready1(s06_ready),

    .dOut(s07_dOut),
    .m_ready(s07_ready),
    .m_valid(s07_valid)
);

// ---------- 08 norm LightNorm ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(WIDE_W),
    .NUM_SCALE_DIN(S07),
    .NUM_SCALE_DOUT(S08_IN)
) s08_requant (
    .dIn(s07_dOut),
    .dOut(s08_rq)
);

LightNorm #(
    .NUM_DIM(NUM_C),
    .NUM_SCALE_DIN(S08_IN),
    .NUM_SCALE_W(S08_W),
    .NUM_SCALE_B(S08_B),
    .NUM_SCALE_DOUT(S08_OUT),
    .WB_BASE(WB_08),
    .NUM_LANE(NUM_LANE)
) s08_LightNorm (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s08_rq),
    .s_valid(s07_valid),
    .s_ready(s07_ready),

    .dOut(s08_dOut),
    .m_ready(s08_ready),
    .m_valid(s08_valid)
);

// ---------- 21 Add ---------- //
Add #(
    .NUM_DIM(NUM_C),
    .DIN0_W(ACT_W),
    .DIN1_W(ACT_W),
    .NUM_SCALE_DIN0(S02_OUT),
    .NUM_SCALE_DIN1(S20_OUT)
) s21_Add (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(s02_b2_q_dOut),
    .s_valid0(s02_b2_q_valid),
    .s_ready0(s02_b2_q_ready),

    .dIn1(ss2d_in_dOut),
    .s_valid1(ss2d_in_valid),
    .s_ready1(ss2d_in_ready),

    .dOut(s21_dOut),
    .m_ready(s21_ready),
    .m_valid(s21_valid)
);

// ---------- 22 norm2 LightNorm ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(WIDE_W),
    .NUM_SCALE_DIN(S21),
    .NUM_SCALE_DOUT(S22_IN)
) s22_requant (
    .dIn(s21_b0_dOut),
    .dOut(s22_rq)
);

LightNorm #(
    .NUM_DIM(NUM_C),
    .NUM_SCALE_DIN(S22_IN),
    .NUM_SCALE_W(S22_W),
    .NUM_SCALE_B(S22_B),
    .NUM_SCALE_DOUT(S22_OUT),
    .WB_BASE(WB_22),
    .NUM_LANE(NUM_LANE)
) s22_LightNorm (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s22_rq),
    .s_valid(s21_b0_valid),
    .s_ready(s21_b0_ready),

    .dOut(s22_dOut),
    .m_ready(s22_ready),
    .m_valid(s22_valid)
);

// ---------- 23 mlp_fc1 Conv2d ---------- //
Requant #(
    .NUM_DIM(NUM_C),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S22_OUT),
    .NUM_SCALE_DOUT(S23_IN)
) s23_requant (
    .dIn(s22_dOut),
    .dOut(s23_rq)
);

Conv1x1 #(
    .NUM_CH(NUM_C),
    .NUM_OUT(2*NUM_HID),
    .USE_BIAS(1'b1),
    .WB_BASE(WB_23)
) s23_Conv1x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s23_rq),
    .s_valid(s22_valid),
    .s_ready(s22_ready),

    .dOut(s23_dOut),
    .m_ready(s23_ready),
    .m_valid(s23_valid)
);

// ---------- 24 mlp DWConv2d ---------- //
Requant #(
    .NUM_DIM(NUM_HID),
    .DIN_W(ACT_W),
    .NUM_SCALE_DIN(S23_OUT),
    .NUM_SCALE_DOUT(S24_IN)
) s24_requant (
    .dIn(s23_b0_sl),
    .dOut(s24_rq)
);

DWConv3x3 #(
    .NUM_CH(NUM_HID),
    .NUM_HEIGHT(NUM_H),
    .NUM_WIDTH(NUM_W),
    .WB_BASE(WB_24),
    .NUM_LANE(NUM_LANE)
) s24_DWConv3x3 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s24_rq),
    .s_valid(s23_b0_valid),
    .s_ready(s23_b0_ready),

    .dOut(s24_dOut),
    .m_ready(s24_ready),
    .m_valid(s24_valid)
);

// ---------- 25 mlp Add ---------- //
Add #(
    .NUM_DIM(NUM_HID),
    .DIN0_W(ACT_W),
    .DIN1_W(ACT_W),
    .NUM_SCALE_DIN0(S24_OUT),
    .NUM_SCALE_DIN1(S23_OUT)
) s25_Add (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(s24_dOut),
    .s_valid0(s24_valid),
    .s_ready0(s24_ready),

    .dIn1(s23_b1_q_dOut),
    .s_valid1(s23_b1_q_valid),
    .s_ready1(s23_b1_q_ready),

    .dOut(s25_dOut),
    .m_ready(s25_ready),
    .m_valid(s25_valid)
);

// ---------- 26 mlp SiLU ---------- //
Requant #(
    .NUM_DIM(NUM_HID),
    .DIN_W(WIDE_W),
    .NUM_SCALE_DIN(S25),
    .NUM_SCALE_DOUT(S26_IN)
) s26_requant (
    .dIn(s25_dOut),
    .dOut(s26_rq)
);

SiLU #(
    .NUM_DIM(NUM_HID),
    .NUM_SCALE_DIN(S26_IN),
    .NUM_SCALE_DOUT(S26_OUT)
) s26_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(s26_rq),
    .s_valid(s25_valid),
    .s_ready(s25_ready),

    .dOut(s26_dOut),
    .m_ready(s26_ready),
    .m_valid(s26_valid)
);

// ---------- 27 mlp Mul ---------- //
Mul #(
    .NUM_DIM(NUM_HID),
    .DIN0_W(ACT_W),
    .DIN1_W(ACT_W)
) s27_Mul (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(s26_dOut),
    .s_valid0(s26_valid),
    .s_ready0(s26_ready),

    .dIn1(s23_b2_q_dOut),
    .s_valid1(s23_b2_q_valid),
    .s_ready1(s23_b2_q_ready),

    .dOut(s27_dOut),
    .m_ready(s27_ready),
    .m_valid(s27_valid)
);

// ---------- 28 mlp_fc2 Conv2d ---------- //
Requant #(
    .NUM_DIM(NUM_HID),
    .DIN_W(WIDE_W),
    .NUM_SCALE_DIN(S27),
    .NUM_SCALE_DOUT(S28_IN)
) s28_requant (
    .dIn(s27_dOut),
    .dOut(s28_rq)
);

Conv1x1 #(
    .NUM_CH(NUM_HID),
    .NUM_OUT(NUM_C),
    .USE_BIAS(1'b1),
    .WB_BASE(WB_28)
) s28_Conv1x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s28_rq),
    .s_valid(s27_valid),
    .s_ready(s27_ready),

    .dOut(s28_dOut),
    .m_ready(s28_ready),
    .m_valid(s28_valid)
);

// ---------- 29 Add ---------- //
Add #(
    .NUM_DIM(NUM_C),
    .DIN0_W(WIDE_W),
    .DIN1_W(ACT_W),
    .NUM_SCALE_DIN0(S21),
    .NUM_SCALE_DIN1(S28_OUT)
) s29_Add (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(s21_b1_q_dOut),
    .s_valid0(s21_b1_q_valid),
    .s_ready0(s21_b1_q_ready),

    .dIn1(s28_dOut),
    .s_valid1(s28_valid),
    .s_ready1(s28_ready),

    .dOut(s29_wide),
    .m_ready(s29_ready),
    .m_valid(s29_valid)
);

generate
    if (DOUT_W == ACT_W) begin : s29_out_int8
        Requant #(
            .NUM_DIM(NUM_C),
            .DIN_W(WIDE_W),
            .NUM_SCALE_DIN(S29),
            .NUM_SCALE_DOUT(S_OUT)
        ) s29_requant (
            .dIn(s29_wide),
            .dOut(s29_dOut)
        );
    end else begin : s29_out_wide
        assign s29_dOut = s29_wide;
    end
endgenerate

// ---------- block output ---------- //
assign dOut      = s29_dOut;
assign m_valid   = s29_valid;
assign s29_ready = m_ready;

emy_frame_counter #(
    .NUM_PIX(NUM_PIX)
) frame_cnt (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .valid(m_valid),
    .ready(m_ready),
    .frame_done(frame_done)
);

// synthesis translate_off
initial begin
    if (DOUT_W == WIDE_W && S_OUT != S29)
        $error("SSBlock: a wide output is handed on at the 29 sum shift S29 = %0d (S_OUT %0d is not used)", S29, S_OUT);
    if (DIN_W != ACT_W && DIN_W != WIDE_W)
        $error("SSBlock: DIN_W must be ACT_W or WIDE_W");
end
// synthesis translate_on

endmodule
