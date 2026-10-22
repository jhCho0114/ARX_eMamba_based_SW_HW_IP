`timescale 1ns / 1ps
// L08 SPPF : cv1 -> SiLU (a) -> MaxPool (y1) -> MaxPool (y2) -> MaxPool (y3) -> Concat [a, y1, y2, y3] -> cv2 -> SiLU
//
//   instance (= LOG / int8_WB step)   module        shape / shift
//   L08_SPPF_01_cv1_Conv2d            Conv1x1       [256, 20, 20] s4 (L07 layer_out) -> [128] s3, out_rshift 7..9
//   L08_SPPF_02_cv1_SiLU              SiLU          s3 -> s3                                              -> a
//   L08_SPPF_03_MaxPool2d_1           MaxPool5x5    s3 -> s3                                              -> y1
//   L08_SPPF_04_MaxPool2d_2           MaxPool5x5    s3 -> s3                                              -> y2
//   L08_SPPF_05_MaxPool2d_3           MaxPool5x5    s3 -> s3                                              -> y3
//   L08_SPPF_06_Concat                Concat x3     [a, y1] [y2, y3] -> [512], all s3 (no shift)
//   L08_SPPF_07_cv2_Conv2d            Conv1x1       512 -> 256, s3 -> s3, out_rshift 8..10
//   L08_SPPF_08_cv2_SiLU              SiLU          s3 -> s4, layer_out s4
//
// Branch alignment: y3 row h needs y2 rows <= h+2, y1 rows <= h+4, a rows <= h+6, so a / y1 / y2 wait in FIFOs
// (emy_stream_fork -> emy_stream_fifo) until the matching y3 pixel exists. FIFO depth = one 20x20 frame (internal
// constant): fifo_a needs about 7 rows, FIFO depth 160 was simulated to pass, 100 deadlocks.
// All handshakes: Linear_Transform_Dynamic_WB valid/ready. wb_* : weight / bias broadcast (WB_<instance> windows).
// frame_done : one-cycle pulse when the last layer_out pixel of a frame has been taken (m_valid & m_ready).
module L08_SPPF import emy_pkg::*, emy_wb_map_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:255],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:255],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

localparam integer NUM_H      = 20;
localparam integer NUM_W      = 20;
localparam integer FIFO_DEPTH = NUM_H * NUM_W;

logic signed [ACT_W-1:0] cv1_dOut [0:127];
logic signed [ACT_W-1:0] a        [0:127], a_mp [0:127], a_ff [0:127], a_q [0:127];
logic signed [ACT_W-1:0] y1       [0:127], y1_mp[0:127], y1_ff[0:127], y1_q[0:127];
logic signed [ACT_W-1:0] y2       [0:127], y2_mp[0:127], y2_ff[0:127], y2_q[0:127];
logic signed [ACT_W-1:0] y3       [0:127];
logic signed [ACT_W-1:0] cat01    [0:255], cat23 [0:255];
logic signed [ACT_W-1:0] cat      [0:511];
logic signed [ACT_W-1:0] cv2_dOut [0:255];

logic cv1_valid, cv1_ready;
logic a_valid,  a_ready,  a_mp_valid,  a_mp_ready,  a_ff_valid,  a_ff_ready,  a_q_valid,  a_q_ready;
logic y1_valid, y1_ready, y1_mp_valid, y1_mp_ready, y1_ff_valid, y1_ff_ready, y1_q_valid, y1_q_ready;
logic y2_valid, y2_ready, y2_mp_valid, y2_mp_ready, y2_ff_valid, y2_ff_ready, y2_q_valid, y2_q_ready;
logic y3_valid, y3_ready;
logic cat01_valid, cat01_ready, cat23_valid, cat23_ready, cat_valid, cat_ready;
logic cv2_valid, cv2_ready;

// ---------- 01 cv1 / 02 SiLU -> a ---------- //
Conv1x1 #(
    .NUM_CH(256),
    .NUM_OUT(128),
    .WB_BASE(WB_L08_SPPF_01_cv1_Conv2d)
) L08_SPPF_01_cv1_Conv2d (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(cv1_dOut),
    .m_ready(cv1_ready),
    .m_valid(cv1_valid)
);

SiLU #(
    .NUM_DIM(128),
    .NUM_SCALE_DIN(3),
    .NUM_SCALE_DOUT(3)
) L08_SPPF_02_cv1_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(cv1_dOut),
    .s_valid(cv1_valid),
    .s_ready(cv1_ready),

    .dOut(a),
    .m_ready(a_ready),
    .m_valid(a_valid)
);

emy_stream_fork #(
    .NUM_DIM(128)
) fork_a (
    .dIn(a),
    .s_valid(a_valid),
    .s_ready(a_ready),

    .dOut0(a_mp),
    .m_ready0(a_mp_ready),
    .m_valid0(a_mp_valid),

    .dOut1(a_ff),
    .m_ready1(a_ff_ready),
    .m_valid1(a_ff_valid)
);

emy_stream_fifo #(
    .NUM_DIM(128),
    .DEPTH(FIFO_DEPTH)
) fifo_a (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(a_ff),
    .s_valid(a_ff_valid),
    .s_ready(a_ff_ready),

    .dOut(a_q),
    .m_ready(a_q_ready),
    .m_valid(a_q_valid)
);

// ---------- 03 MaxPool -> y1 ---------- //
MaxPool5x5 #(
    .NUM_CH(128),
    .NUM_HEIGHT(NUM_H),
    .NUM_WIDTH(NUM_W)
) L08_SPPF_03_MaxPool2d_1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(a_mp),
    .s_valid(a_mp_valid),
    .s_ready(a_mp_ready),

    .dOut(y1),
    .m_ready(y1_ready),
    .m_valid(y1_valid)
);

emy_stream_fork #(
    .NUM_DIM(128)
) fork_y1 (
    .dIn(y1),
    .s_valid(y1_valid),
    .s_ready(y1_ready),

    .dOut0(y1_mp),
    .m_ready0(y1_mp_ready),
    .m_valid0(y1_mp_valid),

    .dOut1(y1_ff),
    .m_ready1(y1_ff_ready),
    .m_valid1(y1_ff_valid)
);

emy_stream_fifo #(
    .NUM_DIM(128),
    .DEPTH(FIFO_DEPTH)
) fifo_y1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(y1_ff),
    .s_valid(y1_ff_valid),
    .s_ready(y1_ff_ready),

    .dOut(y1_q),
    .m_ready(y1_q_ready),
    .m_valid(y1_q_valid)
);

// ---------- 04 MaxPool -> y2 ---------- //
MaxPool5x5 #(
    .NUM_CH(128),
    .NUM_HEIGHT(NUM_H),
    .NUM_WIDTH(NUM_W)
) L08_SPPF_04_MaxPool2d_2 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(y1_mp),
    .s_valid(y1_mp_valid),
    .s_ready(y1_mp_ready),

    .dOut(y2),
    .m_ready(y2_ready),
    .m_valid(y2_valid)
);

emy_stream_fork #(
    .NUM_DIM(128)
) fork_y2 (
    .dIn(y2),
    .s_valid(y2_valid),
    .s_ready(y2_ready),

    .dOut0(y2_mp),
    .m_ready0(y2_mp_ready),
    .m_valid0(y2_mp_valid),

    .dOut1(y2_ff),
    .m_ready1(y2_ff_ready),
    .m_valid1(y2_ff_valid)
);

emy_stream_fifo #(
    .NUM_DIM(128),
    .DEPTH(FIFO_DEPTH)
) fifo_y2 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(y2_ff),
    .s_valid(y2_ff_valid),
    .s_ready(y2_ff_ready),

    .dOut(y2_q),
    .m_ready(y2_q_ready),
    .m_valid(y2_q_valid)
);

// ---------- 05 MaxPool -> y3 ---------- //
MaxPool5x5 #(
    .NUM_CH(128),
    .NUM_HEIGHT(NUM_H),
    .NUM_WIDTH(NUM_W)
) L08_SPPF_05_MaxPool2d_3 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(y2_mp),
    .s_valid(y2_mp_valid),
    .s_ready(y2_mp_ready),

    .dOut(y3),
    .m_ready(y3_ready),
    .m_valid(y3_valid)
);

// ---------- 06 Concat [a, y1, y2, y3] (all s3) ---------- //
Concat #(
    .NUM_DIM0(128),
    .NUM_DIM1(128),
    .NUM_SCALE_DIN0(3),
    .NUM_SCALE_DIN1(3),
    .NUM_SCALE_DOUT(3)
) L08_SPPF_06_Concat_a_y1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(a_q),
    .s_valid0(a_q_valid),
    .s_ready0(a_q_ready),

    .dIn1(y1_q),
    .s_valid1(y1_q_valid),
    .s_ready1(y1_q_ready),

    .dOut(cat01),
    .m_ready(cat01_ready),
    .m_valid(cat01_valid)
);

Concat #(
    .NUM_DIM0(128),
    .NUM_DIM1(128),
    .NUM_SCALE_DIN0(3),
    .NUM_SCALE_DIN1(3),
    .NUM_SCALE_DOUT(3)
) L08_SPPF_06_Concat_y2_y3 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(y2_q),
    .s_valid0(y2_q_valid),
    .s_ready0(y2_q_ready),

    .dIn1(y3),
    .s_valid1(y3_valid),
    .s_ready1(y3_ready),

    .dOut(cat23),
    .m_ready(cat23_ready),
    .m_valid(cat23_valid)
);

Concat #(
    .NUM_DIM0(256),
    .NUM_DIM1(256),
    .NUM_SCALE_DIN0(3),
    .NUM_SCALE_DIN1(3),
    .NUM_SCALE_DOUT(3)
) L08_SPPF_06_Concat (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(cat01),
    .s_valid0(cat01_valid),
    .s_ready0(cat01_ready),

    .dIn1(cat23),
    .s_valid1(cat23_valid),
    .s_ready1(cat23_ready),

    .dOut(cat),
    .m_ready(cat_ready),
    .m_valid(cat_valid)
);

// ---------- 07 cv2 / 08 SiLU = layer_out ---------- //
Conv1x1 #(
    .NUM_CH(512),
    .NUM_OUT(256),
    .WB_BASE(WB_L08_SPPF_07_cv2_Conv2d)
) L08_SPPF_07_cv2_Conv2d (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(cat),
    .s_valid(cat_valid),
    .s_ready(cat_ready),

    .dOut(cv2_dOut),
    .m_ready(cv2_ready),
    .m_valid(cv2_valid)
);

SiLU #(
    .NUM_DIM(256),
    .NUM_SCALE_DIN(3),
    .NUM_SCALE_DOUT(4)
) L08_SPPF_08_cv2_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(cv2_dOut),
    .s_valid(cv2_valid),
    .s_ready(cv2_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid)
);

emy_frame_counter #(
    .NUM_PIX(NUM_H * NUM_W)
) frame_cnt (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .valid(m_valid),
    .ready(m_ready),
    .frame_done(frame_done)
);

endmodule
