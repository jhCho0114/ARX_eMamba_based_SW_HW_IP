`timescale 1ns / 1ps
// VisionClueMerge : 01 SpaceToDepth -> 02 pw_linear Conv 1x1 (4C -> 2C) -> 03 SiLU   (= the layer_out)
//
//   The three VisionClueMerge layers (L02 / L04 / L06, rtl/Lxx wrappers) are this module with their numbers.
//   SpaceToDepth keeps the shift and the conv input shift equals it; the conv output shift equals the SiLU input
//   shift (int8_WB meta / quant.json, no requant). The SpaceToDepth vector order (q*C + c) is the input order of the
//   int8_WB 1x1 weights [2C, 4C]. Pixel vectors, raster order, Linear_Transform_Dynamic_WB valid / ready.
//
//   instance           step (LOG / int8_WB)
//   s01_SpaceToDepth   01 SpaceToDepth      [C, H, W] -> [4C, H/2, W/2]
//   s02_Conv1x1        02 pw_linear Conv2d  4C -> 2C, per-channel out_rshift (WB_02)
//   s03_SiLU           03 SiLU              S03_IN -> S03_OUT = layer_out shift
//
//   Parameters: the input map (int8_WB meta.json), the SiLU in / out shift (quant.json), the conv window
//   WB_02 = emy_wb_map_pkg::WB_<step>.
//   frame_done : one-cycle pulse when the last layer_out pixel of a frame has been taken (m_valid & m_ready).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module VisionClueMerge import emy_pkg::*; #(
    parameter integer NUM_CH     = 32,     // input channels C
    parameter integer NUM_HEIGHT = 160,    // input map
    parameter integer NUM_WIDTH  = 160,
    parameter integer S03_IN     = 4,
    parameter integer S03_OUT    = 4,
    parameter integer WB_02      = 0
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:2*NUM_CH-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

// ---------- Local Parameters ---------- //
localparam integer NUM_PIX = (NUM_HEIGHT / 2) * (NUM_WIDTH / 2);    // output pixels

// ---------- Internal Variables ---------- //
logic signed [ACT_W-1:0] s2d_dOut  [0:4*NUM_CH-1];
logic signed [ACT_W-1:0] conv_dOut [0:2*NUM_CH-1];
logic s2d_valid, s2d_ready, conv_valid, conv_ready;

// ---------- 01 SpaceToDepth ---------- //
SpaceToDepth #(
    .NUM_CH(NUM_CH),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH)
) s01_SpaceToDepth (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(s2d_dOut),
    .m_ready(s2d_ready),
    .m_valid(s2d_valid)
);

// ---------- 02 pw_linear Conv2d ---------- //
Conv1x1 #(
    .NUM_CH(4*NUM_CH),
    .NUM_OUT(2*NUM_CH),
    .WB_BASE(WB_02)
) s02_Conv1x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(s2d_dOut),
    .s_valid(s2d_valid),
    .s_ready(s2d_ready),

    .dOut(conv_dOut),
    .m_ready(conv_ready),
    .m_valid(conv_valid)
);

// ---------- 03 SiLU ---------- //
SiLU #(
    .NUM_DIM(2*NUM_CH),
    .NUM_SCALE_DIN(S03_IN),
    .NUM_SCALE_DOUT(S03_OUT)
) s03_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(conv_dOut),
    .s_valid(conv_valid),
    .s_ready(conv_ready),

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
