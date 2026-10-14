`timescale 1ns / 1ps
// L09 Upsample : nearest x2  (= L09 layer_out, consumed by L10 Concat main) = UpsampleLayer with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)        shape / shift
//   s01_Upsample     L09_Upsample_01_Upsample   [256, 20, 20] s4 (L08 SPPF layer_out) -> [256, 40, 40] s4
//
// s_in = s_out = s_lo = 4: values are copied, no requant.
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L09_Upsample import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:256-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:256-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

UpsampleLayer #(
    .NUM_CH(256),
    .NUM_HEIGHT(20),
    .NUM_WIDTH(20)
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
