`timescale 1ns / 1ps
// L16 Concat : [L15 Conv ; L11 XSSBlock] along channels  (= L16 layer_out) = ConcatSkip with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)   shape / shift
//   skip_fifo        (buffer)               skip [128, 40, 40] s5 (L11 XSSBlock layer_out), depth = one frame
//   s01_Concat       L16_Concat_01_Concat   main [64, 40, 40] s3 (L15 Conv) + skip -> [192, 40, 40] s4
//
// Concat shifts are the step's quant.json shifts (in 3, 5 -> out 4). layer_out = output (s_lo 4).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L16_Concat import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn0 [0:64-1],     // main: L15 Conv
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [ACT_W-1:0] dIn1 [0:128-1],     // skip: L11 XSSBlock
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [ACT_W-1:0] dOut [0:192-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

ConcatSkip #(
    .NUM_DIM0(64),
    .NUM_DIM1(128),
    .NUM_HEIGHT(40),
    .NUM_WIDTH(40),
    .S_IN0(3),
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
