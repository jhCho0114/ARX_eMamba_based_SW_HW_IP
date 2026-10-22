`timescale 1ns / 1ps
// L10 Concat : [L09 Upsample ; L05 VSSBlock2] along channels  (= L10 layer_out) = ConcatSkip with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)   shape / shift
//   skip_fifo        (buffer)               skip [128, 40, 40] s5 (L05 VSSBlock2 layer_out), depth = one frame
//   s01_Concat       L10_Concat_01_Concat   main [256, 40, 40] s4 (L09 Upsample) + skip -> [384, 40, 40] s4
//
// Concat shifts are the step's quant.json shifts (in 4, 5 -> out 4). layer_out = output (s_lo 4).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L10_Concat import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn0 [0:256-1],     // main: L09 Upsample
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [ACT_W-1:0] dIn1 [0:128-1],     // skip: L05 VSSBlock2
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [ACT_W-1:0] dOut [0:384-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

ConcatSkip #(
    .NUM_DIM0(256),
    .NUM_DIM1(128),
    .NUM_HEIGHT(40),
    .NUM_WIDTH(40),
    .S_IN0(4),
    .S_IN1(5),
    .S_OUT(4)
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
