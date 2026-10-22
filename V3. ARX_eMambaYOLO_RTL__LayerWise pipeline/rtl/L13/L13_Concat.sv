`timescale 1ns / 1ps
// L13 Concat : [L12 Upsample ; L03 VSSBlock] along channels  (= L13 layer_out) = ConcatSkip with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)   shape / shift
//   skip_fifo        (buffer)               skip [64, 80, 80] s5 (L03 VSSBlock layer_out), depth = one frame
//   s01_Concat       L13_Concat_01_Concat   main [128, 80, 80] s5 (L12 Upsample) + skip -> [192, 80, 80] s5
//
// Concat shifts are the step's quant.json shifts (in 5, 5 -> out 5). layer_out = output (s_lo 5).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L13_Concat import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn0 [0:128-1],     // main: L12 Upsample
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [ACT_W-1:0] dIn1 [0:64-1],     // skip: L03 VSSBlock
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [ACT_W-1:0] dOut [0:192-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

ConcatSkip #(
    .NUM_DIM0(128),
    .NUM_DIM1(64),
    .NUM_HEIGHT(80),
    .NUM_WIDTH(80),
    .S_IN0(5),
    .S_IN1(5),
    .S_OUT(5)
) blk (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(dIn0),
    .s_valid0(s_valid0),
    .s_ready0(s_ready0),

    .dIn1(dIn1),
    .s_valid1(s_valid1),
    .s_ready1(s_ready1),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid),
    .frame_done(frame_done)
);

endmodule
