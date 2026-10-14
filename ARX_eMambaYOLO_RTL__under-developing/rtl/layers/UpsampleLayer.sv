`timescale 1ns / 1ps
// UpsampleLayer : nearest x2 upsample of a pixel-vector stream, with the layer frame_done   (= the layer_out)
//
//   The two neck Upsample layers (L09 / L12, rtl/Lxx wrappers) are this module with their numbers. Values are
//   copied (s_in = s_out = layer_out shift, no requant). Pixel vectors [C], raster, Linear_Transform_Dynamic_WB
//   valid / ready.
//
//   instance       step (LOG / int8_WB)
//   s01_Upsample   01 Upsample   [C, H, W] -> [C, 2H, 2W]
//
//   frame_done : one-cycle pulse when the last layer_out pixel of a frame has been taken (m_valid & m_ready).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module UpsampleLayer import emy_pkg::*; #(
    parameter integer NUM_CH     = 256,
    parameter integer NUM_HEIGHT = 20,     // input map
    parameter integer NUM_WIDTH  = 20
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:NUM_CH-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

// ---------- Local Parameters ---------- //
localparam integer NUM_PIX = (2 * NUM_HEIGHT) * (2 * NUM_WIDTH);    // output pixels

// ---------- 01 Upsample ---------- //
Upsample #(
    .NUM_CH(NUM_CH),
    .NUM_WIDTH(NUM_WIDTH)
) s01_Upsample (
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
