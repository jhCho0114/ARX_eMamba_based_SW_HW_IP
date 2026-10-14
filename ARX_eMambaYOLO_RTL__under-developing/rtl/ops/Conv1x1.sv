`timescale 1ns / 1ps
// Conv1x1 : pointwise Conv 1x1, BN folded, per-channel requant
//
//   dOut[o] = sat8(rshr(sum_c w[o, c] * x[c] + bias[o], out_rshift[o]))     per pixel
//
// A 1x1 conv needs no window: the input pixel vector [NUM_CH] is the patch, so this is emy_conv_core alone
// (Linear_Transform_Dynamic_WB handshake on both sides, 2*NUM_OUT + 1 cycles per pixel).
// Parameters: channel counts (int8_WB meta.json) and WB_BASE = emy_wb_map_pkg::WB_<step> (weight / bias / out_rshift window of the broadcast).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module Conv1x1 import emy_pkg::*; #(
    parameter integer NUM_CH    = 256,
    parameter integer NUM_OUT   = 128,
    parameter bit     USE_BIAS  = 1'b1,
    parameter integer WB_BASE   = 0
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

emy_conv_core #(
    .NUM_DIM_IN(NUM_CH),
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

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid)
);

endmodule
