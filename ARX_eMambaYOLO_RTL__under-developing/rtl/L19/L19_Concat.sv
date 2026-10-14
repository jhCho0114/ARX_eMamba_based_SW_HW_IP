`timescale 1ns / 1ps
// L19 Concat : [L18 Conv ; L08 SPPF] along channels  (= L19 layer_out) = ConcatSkip with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)   shape / shift
//   skip_fifo        (buffer)               skip [256, 20, 20] s4 (L08 SPPF layer_out), depth = one frame
//   s01_Concat       L19_Concat_01_Concat   main [128, 20, 20] s3 (L18 Conv) + skip -> [384, 20, 20] s3
//
// Concat shifts are the step's quant.json shifts (in 3, 4 -> out 3). layer_out = output (s_lo 3).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L19_Concat import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn0 [0:128-1],     // main: L18 Conv
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [ACT_W-1:0] dIn1 [0:256-1],     // skip: L08 SPPF
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [ACT_W-1:0] dOut [0:384-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

ConcatSkip #(
    .NUM_DIM0(128),
    .NUM_DIM1(256),
    .NUM_HEIGHT(20),
    .NUM_WIDTH(20),
    .S_IN0(3),
    .S_IN1(4),
    .S_OUT(3)
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
