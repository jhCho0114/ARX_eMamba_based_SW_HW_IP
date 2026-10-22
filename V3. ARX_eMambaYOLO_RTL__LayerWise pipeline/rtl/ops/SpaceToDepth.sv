`timescale 1ns / 1ps
// SpaceToDepth : 2x2 pixels -> channels,  dOut[q*C + c, i, j] = x[c, 2i + dh, 2j + dw],  q = dh + 2*dw
//                (offsets (0,0), (1,0), (0,1), (1,1), as torch.cat in VisionClueMerge)
//
// = emy_im2col with K = S = 2, P = 0 and the S2D patch order: the "patch" of output pixel (i, j) is exactly the
// SpaceToDepth output vector [4C]. No arithmetic, the shift is kept (out_view shift = input shift for L02/04/06).
// Input : pixel vectors [NUM_CH], raster (h, w).
// Output: pixel vectors [4*NUM_CH], raster (i, j), H/2 x W/2. Output row i starts once input rows 2i, 2i+1 are in.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module SpaceToDepth import emy_pkg::*; #(
    parameter integer NUM_CH     = 32,
    parameter integer NUM_HEIGHT = 160,
    parameter integer NUM_WIDTH  = 160
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:4*NUM_CH-1],
    input  logic m_ready,
    output logic m_valid
);

emy_im2col #(
    .NUM_CH(NUM_CH),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .KERNEL(2),
    .STRIDE(2),
    .PAD(0),
    .PATCH_S2D(1'b1)
) im2col (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid)
);

endmodule
