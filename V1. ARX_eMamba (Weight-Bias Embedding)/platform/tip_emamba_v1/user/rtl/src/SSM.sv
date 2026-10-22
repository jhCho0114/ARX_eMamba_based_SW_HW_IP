`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 10:46:45 AM
// Design Name: 
// Module Name: SSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SSM #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 40, // ED
    parameter integer NUM_DIM_2  = 8,  // N

    // Preprocess
    // Linear expand dBC delta
    parameter integer LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 6,

    // Linear expand dBC B
    parameter integer LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer LINEX_DBC_B_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DBC_B_NUM_SCALE_DOUT   = 6,

    // Linear expand dBC C
    parameter integer LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer LINEX_DBC_C_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DBC_C_NUM_SCALE_DOUT   = 5,

    // Linear expand dleta
    parameter integer LINEX_DELTA_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 3,
    parameter integer DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 6,
    parameter integer DIMEX_DELTA_B_NUM_SCALE_DOUT  = 3,

    // Computation
    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_C       = 5,
    parameter integer NUM_SCALE_D       = 6,
    parameter integer NUM_SCALE_DOUT    = 3,

    // 0: 1st MAMBA, 1: 2nd MAMBA
    parameter integer LAYER_ID = 0,
    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dIn_delayed,
    dOut,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_DIM_DELTA = 32;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] dIn           [0:NUM_DIM_1-1]; // 40
input   logic signed [DATA_WIDTH-1:0] dIn_delayed   [0:NUM_DIM_1-1]; // 40
output  logic signed [DATA_WIDTH-1:0] dOut          [0:NUM_DIM_1-1]; // 40

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] delta_A   [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8
logic signed [DATA_WIDTH-1:0] delta_B   [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8
logic signed [DATA_WIDTH-1:0] matrix_C  [0:NUM_DIM_2-1]; // 8

logic SSM_computation_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
SSM_Preprocess #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),  // ED
    .NUM_DIM_2(NUM_DIM_2),  // N

    // Linear expand dBC delta
    .LINEX_DBC_DELTA_NUM_SCALE_DIN(LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DBC_DELTA_NUM_SCALE_DOUT(LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .LINEX_DBC_B_NUM_SCALE_DIN(LINEX_DBC_B_NUM_SCALE_DIN),
    .LINEX_DBC_B_NUM_SCALE_WEIGHT(LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .LINEX_DBC_B_NUM_SCALE_DOUT(LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .LINEX_DBC_C_NUM_SCALE_DIN(LINEX_DBC_C_NUM_SCALE_DIN),
    .LINEX_DBC_C_NUM_SCALE_WEIGHT(LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .LINEX_DBC_C_NUM_SCALE_DOUT(LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .LINEX_DELTA_NUM_SCALE_DIN(LINEX_DELTA_NUM_SCALE_DIN),
    .LINEX_DELTA_NUM_SCALE_WEIGHT(LINEX_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DELTA_NUM_SCALE_BIAS(LINEX_DELTA_NUM_SCALE_BIAS),
    .LINEX_DELTA_NUM_SCALE_DOUT(LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .DIMEX_DELTA_A_NUM_SCALE_DIN_1(DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_A_NUM_SCALE_DIN_2(DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_A_NUM_SCALE_DOUT(DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .DIMEX_DELTA_B_NUM_SCALE_DIN_1(DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_B_NUM_SCALE_DIN_2(DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_B_NUM_SCALE_DOUT(DIMEX_DELTA_B_NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID),
    .DEBUG_SWITCH(DEBUG_SWITCH)
) SSM_Preprocess (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),

    .delta_A(delta_A),
    .delta_B(delta_B),
    .matrix_C(matrix_C),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(SSM_computation_ready),
    .layer_ready(layer_ready),
    .dOut_ready(SSM_preprocess_dOut_ready)
);

SSM_Computation #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(NUM_SCALE_DELTA_B),
    .NUM_SCALE_C(NUM_SCALE_C),
    .NUM_SCALE_D(NUM_SCALE_D),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID),
    .DEBUG_SWITCH(DEBUG_SWITCH)
) SSM_Computation (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),
    
    .dIn(dIn_delayed),
    .dOut(dOut),

    .delta_A(delta_A),
    .delta_B(delta_B),
    .matrix_C(matrix_C),

    .prev_layer_ready(SSM_preprocess_dOut_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(SSM_computation_ready),
    .dOut_ready(dOut_ready)
);

endmodule