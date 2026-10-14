`timescale 1ns / 1ps
// ConvSiLU : 01 Conv 3x3 (pad 1, stride STRIDE, BN folded) -> 02 SiLU   (= the layer_out; the YOLO "Conv" layer)
//
//   The two neck Conv layers (L15 / L18, rtl/Lxx wrappers) are this module with their numbers. No requant: the
//   conv input shift is the previous layer_out shift, the conv output shift is the SiLU input shift (int8_WB).
//   Pixel vectors, raster order, Linear_Transform_Dynamic_WB valid / ready.
//
//   instance      step (LOG / int8_WB)
//   s01_Conv3x3   01 conv Conv2d   [C, H, W] -> [O, H/STRIDE, W/STRIDE], per-channel out_rshift (WB_01)
//   s02_SiLU      02 SiLU          S02_IN -> S02_OUT = layer_out shift
//
//   Parameters: the step geometry (int8_WB meta.json), the SiLU in / out shift (quant.json), the conv window
//   WB_01 = emy_wb_map_pkg::WB_<step>.
//   frame_done : one-cycle pulse when the last layer_out pixel of a frame has been taken (m_valid & m_ready).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module ConvSiLU import emy_pkg::*; #(
    parameter integer NUM_CH     = 64,     // input channels C
    parameter integer NUM_HEIGHT = 80,     // input map
    parameter integer NUM_WIDTH  = 80,
    parameter integer NUM_OUT    = 64,     // output channels O
    parameter integer STRIDE     = 2,
    parameter integer S02_IN     = 3,
    parameter integer S02_OUT    = 3,
    parameter integer WB_01      = 0
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

    output logic signed [ACT_W-1:0] dOut [0:NUM_OUT-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

// ---------- Local Parameters ---------- //
localparam integer NUM_HO  = (NUM_HEIGHT + 2 - 3) / STRIDE + 1;    // kernel 3, pad 1
localparam integer NUM_WO  = (NUM_WIDTH  + 2 - 3) / STRIDE + 1;
localparam integer NUM_PIX = NUM_HO * NUM_WO;

// ---------- Internal Variables ---------- //
logic signed [ACT_W-1:0] conv_dOut [0:NUM_OUT-1];
logic conv_valid, conv_ready;

// ---------- 01 conv Conv2d ---------- //
Conv3x3 #(
    .NUM_CH(NUM_CH),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .NUM_OUT(NUM_OUT),
    .STRIDE(STRIDE),
    .WB_BASE(WB_01)
) s01_Conv3x3 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(conv_dOut),
    .m_ready(conv_ready),
    .m_valid(conv_valid)
);

// ---------- 02 SiLU ---------- //
SiLU #(
    .NUM_DIM(NUM_OUT),
    .NUM_SCALE_DIN(S02_IN),
    .NUM_SCALE_DOUT(S02_OUT)
) s02_SiLU (
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
