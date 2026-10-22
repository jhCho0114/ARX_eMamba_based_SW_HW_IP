`timescale 1ns / 1ps
// emy_conv_core : one output pixel of a dense conv = dot products of a patch vector with O weight rows
//
//   acc[o]  = sum_k w[o][k] * x[k] + bias[o]            int8 x int8, int32 bias (shift s_in + s_w[o])
//   dOut[o] = sat8(rshr(acc[o], out_rshift[o]))          round half up, per output channel shift (0..31)
//   Patch / weight order: k = ci*KH*KW + kh*KW + kw  (= C order of weight.npy [O, Cg, KH, KW])
//   (INT8 reference model layers_int8_emamba.py, SW.Conv2d)
//
// Datapath: Linear_Transform_PerCh (Anh), the linear layer of the design that has been
//   synthesized and timed (SS2D steps 09 / 14 / 15 / 20 use it directly): the weights in a RAM of NUM_DIM_OUT rows
//   (one row = the NUM_DIM_IN weights, block RAM), one output channel per cycle through a pipeline — row read (two
//   registers) | products | adder tree with a register every two levels | + bias | rounding shift | sat8 -> dOut[o].
//   Per patch NUM_DIM_OUT + ceil(log2(NUM_DIM_IN) / 2) + 6 cycles, then DONE until m_ready.
// Handshake (U_eMamba Linear_Transform_Dynamic_WB): dIn latched on s_valid & s_ready, s_ready = EMPTY | (the last
//   channel's products are being taken), m_valid = DONE, dOut held until m_valid & m_ready. nRst synchronous, active
//   low; ps_start soft reset. Contract: no s_valid in the cycle ps_start is 1.
// Parameters come from the weight / bias broadcast, window at byte address WB_BASE (emy_wb_map_pkg::WB_<step>,
//   emy_wb_map_pkg):
//     W  NUM_DIM_OUT rows x ceil4(NUM_DIM_IN) bytes   int8 weight row o (patch order), padding bytes ignored
//     B  NUM_DIM_OUT words                            int32 bias (only when USE_BIAS)
//     R  ceil4(NUM_DIM_OUT) bytes                     int8 out_rshift[o] = s_in + s_w[o] - s_out (meta.json)
//   Load the image before ps_start; the memories are not cleared by ps_start.
module emy_conv_core import emy_pkg::*; #(
    parameter integer NUM_DIM_IN  = 27,     // patch length Cg*KH*KW
    parameter integer NUM_DIM_OUT = 16,     // output channels O
    parameter bit     USE_BIAS    = 1'b1,
    parameter integer WB_BASE     = 0       // byte address of the parameter window
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_DIM_IN-1],
    output logic signed [ACT_W-1:0] dOut [0:NUM_DIM_OUT-1],

    input  logic s_valid,
    input  logic m_ready,
    output logic s_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer WB_BASE_B = WB_BASE + NUM_DIM_OUT * ceil4(NUM_DIM_IN);
localparam integer WB_BASE_R = WB_BASE_B + (USE_BIAS ? 4 * NUM_DIM_OUT : 0);

Linear_Transform_PerCh #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM_IN(NUM_DIM_IN),
    .NUM_DIM_OUT(NUM_DIM_OUT),
    .USE_BIAS(USE_BIAS),
    .USE_RELU(1'b0),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(WB_BASE),
    .WB_BASE_B(WB_BASE_B),
    .WB_BASE_S(WB_BASE_R)
) linear (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),
    .bank(1'b0),

    .dIn(dIn),
    .dOut(dOut),

    .s_valid(s_valid),
    .s_ready(s_ready),
    .m_valid(m_valid),
    .m_ready(m_ready)
);

endmodule
