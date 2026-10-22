`timescale 1ns / 1ps
// Conv3x3 : dense Conv 3x3, pad 1 (same), stride STRIDE, BN folded, per-channel requant
//
//   dOut[o, ho, wo] = sat8(rshr(sum_{c,kh,kw} w[o,c,kh,kw] * x[c, ho*S + kh - 1, wo*S + kw - 1] + bias[o], out_rshift[o]))
//   = emy_im2col (patch [C*9], weight.npy order) -> emy_conv_core
//
// Input : pixel vectors [NUM_CH] in raster order (s_valid / s_ready).
// Output: pixel vectors [NUM_OUT] in raster order (m_valid / m_ready).  Linear_Transform_Dynamic_WB handshake.
// Output row ho starts as soon as input rows up to ho*STRIDE + 1 are in (emy_im2col line buffer of K + STRIDE rows);
// frames stream continuously after one ps_start.
// Parameters: the step's geometry (int8_WB meta.json) and WB_BASE = emy_wb_map_pkg::WB_<step> (weight / bias / out_rshift window of the broadcast).
// Kernel 3 and pad 1 are fixed (the name); every 3x3 conv of the model outside the SSM blocks has pad 1.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module Conv3x3 import emy_pkg::*; #(
    parameter integer NUM_CH     = 3,
    parameter integer NUM_HEIGHT = 640,
    parameter integer NUM_WIDTH  = 640,
    parameter integer NUM_OUT    = 16,
    parameter integer STRIDE     = 2,
    parameter bit     USE_BIAS   = 1'b1,
    parameter integer WB_BASE    = 0
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
    output logic m_valid
);

localparam integer KERNEL    = 3;
localparam integer PAD       = 1;
localparam integer PATCH_LEN = NUM_CH * KERNEL * KERNEL;

logic signed [ACT_W-1:0] patch [0:PATCH_LEN-1];
logic patch_valid, patch_ready;

emy_im2col #(
    .NUM_CH(NUM_CH),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .KERNEL(KERNEL),
    .STRIDE(STRIDE),
    .PAD(PAD)
) im2col (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(patch),
    .m_ready(patch_ready),
    .m_valid(patch_valid)
);

emy_conv_core #(
    .NUM_DIM_IN(PATCH_LEN),
    .NUM_DIM_OUT(NUM_OUT),
    .USE_BIAS(USE_BIAS),
    .WB_BASE(WB_BASE)
) conv_core (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(patch),
    .s_valid(patch_valid),
    .s_ready(patch_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid)
);

endmodule
