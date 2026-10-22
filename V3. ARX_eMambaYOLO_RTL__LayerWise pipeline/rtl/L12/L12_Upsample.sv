`timescale 1ns / 1ps
// L12 Upsample : nearest x2  (= L12 layer_out, consumed by L13 Concat main) = UpsampleLayer with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)        shape / shift
//   s01_Upsample     L12_Upsample_01_Upsample   [128, 40, 40] s5 (L11 XSSBlock layer_out) -> [128, 80, 80] s5
//
// s_in = s_out = s_lo = 5: values are copied, no requant.
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L12_Upsample import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:128-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:128-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

UpsampleLayer #(
    .NUM_CH(128),
    .NUM_HEIGHT(40),
    .NUM_WIDTH(40)
) blk (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid),
    .frame_done(frame_done)
);

endmodule
