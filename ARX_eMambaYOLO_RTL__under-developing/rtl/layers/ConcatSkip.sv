`timescale 1ns / 1ps
// ConcatSkip : [main ; skip] along channels, the skip operand buffered one frame   (= the layer_out)
//
//   The four neck Concat layers (L10 / L13 / L16 / L19, rtl/Lxx wrappers) are this module with their numbers.
//   The skip input (a backbone / earlier neck layer_out) arrives a frame before the main input (an SS2D block in
//   between needs its whole input frame), so it waits in a frame-deep FIFO and never stalls its producer.
//   Concat shifts are the step's quant.json shifts (in0, in1 -> out); the per-input shift is computed inside Concat.
//   Pixel vectors, raster order, Linear_Transform_Dynamic_WB valid / ready.
//
//   instance     step (LOG / int8_WB)
//   skip_fifo    (buffer)       skip [NUM_DIM1, H, W], depth = one frame
//   s01_Concat   01 Concat      main [NUM_DIM0] + skip -> [NUM_DIM0 + NUM_DIM1], S_IN0 / S_IN1 -> S_OUT
//
//   frame_done : one-cycle pulse when the last layer_out pixel of a frame has been taken (m_valid & m_ready).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module ConcatSkip import emy_pkg::*; #(
    parameter integer NUM_DIM0   = 256,    // main input channels
    parameter integer NUM_DIM1   = 128,    // skip input channels
    parameter integer NUM_HEIGHT = 40,
    parameter integer NUM_WIDTH  = 40,
    parameter integer S_IN0      = 4,
    parameter integer S_IN1      = 5,
    parameter integer S_OUT      = 4,

    localparam integer NUM_OUT   = NUM_DIM0 + NUM_DIM1
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn0 [0:NUM_DIM0-1],     // main
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [ACT_W-1:0] dIn1 [0:NUM_DIM1-1],     // skip
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [ACT_W-1:0] dOut [0:NUM_OUT-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

// ---------- Local Parameters ---------- //
localparam integer NUM_PIX = NUM_HEIGHT * NUM_WIDTH;

// ---------- Internal Variables ---------- //
logic signed [ACT_W-1:0] skip_q [0:NUM_DIM1-1];
logic skip_q_valid, skip_q_ready;

// ---------- skip operand: one-frame FIFO ---------- //
emy_stream_fifo #(
    .NUM_DIM(NUM_DIM1),
    .DEPTH(NUM_PIX)
) skip_fifo (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(dIn1),
    .s_valid(s_valid1),
    .s_ready(s_ready1),

    .dOut(skip_q),
    .m_ready(skip_q_ready),
    .m_valid(skip_q_valid)
);

// ---------- 01 Concat ---------- //
Concat #(
    .NUM_DIM0(NUM_DIM0),
    .NUM_DIM1(NUM_DIM1),
    .NUM_SCALE_DIN0(S_IN0),
    .NUM_SCALE_DIN1(S_IN1),
    .NUM_SCALE_DOUT(S_OUT)
) s01_Concat (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(dIn0),
    .s_valid0(s_valid0),
    .s_ready0(s_ready0),

    .dIn1(skip_q),
    .s_valid1(skip_q_valid),
    .s_ready1(skip_q_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid)
);

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

endmodule
