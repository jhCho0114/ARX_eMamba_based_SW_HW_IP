`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 10:48:02 AM
// Design Name: 
// Module Name: SSM_Preprocess
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


module SSM_Preprocess #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 40, // ED
    parameter integer NUM_DIM_2  = 8,  // N

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

    // 0: 1st MAMBA, 1: 2nd MAMBA
    parameter integer LAYER_ID = 0,
    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    dIn,
    delta_A,
    delta_B,
    matrix_C,

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

input   logic signed [DATA_WIDTH-1:0] dIn       [0:NUM_DIM_1-1];
output  logic signed [DATA_WIDTH-1:0] delta_A   [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8
output  logic signed [DATA_WIDTH-1:0] delta_B   [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8
output  logic signed [DATA_WIDTH-1:0] matrix_C  [0:NUM_DIM_2-1];                // 8

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] linEx_dBC_delta_dOut [0:NUM_DIM_DELTA-1]; // 32

logic signed [DATA_WIDTH-1:0] linEx_dBC_B_dOut      [0:NUM_DIM_2-1]; // 8
logic signed [DATA_WIDTH-1:0] linEx_dBC_B_dOut_FF_1 [0:NUM_DIM_2-1]; // 8

logic signed [DATA_WIDTH-1:0] linEx_dBC_C_dOut      [0:NUM_DIM_2-1]; // 8
logic signed [DATA_WIDTH-1:0] linEx_dBC_C_dOut_FF_1 [0:NUM_DIM_2-1]; // 8
logic signed [DATA_WIDTH-1:0] linEx_dBC_C_dOut_FF_2 [0:NUM_DIM_2-1]; // 8

logic signed [DATA_WIDTH-1:0] linEx_delta_dOut [0:NUM_DIM_1-1]; // 40

logic signed [DATA_WIDTH-1:0] ReLU_dOut [0:NUM_DIM_1-1]; // 40

logic signed [DATA_WIDTH * 2 - 1:0] delta_A_bfExp [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8

logic signed [DATA_WIDTH-1:0] dimEx_delta_B_dOut [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8

// Linear expand dBC
logic linEx_dBC_delta_layer_ready, linEx_dBC_delta_dOut_ready;
logic linEx_dBC_B_layer_ready, linEx_dBC_B_dOut_ready;
logic linEx_dBC_C_layer_ready, linEx_dBC_C_dOut_ready;

// Linear expand delta
logic linEx_delta_layer_ready, linEx_delta_dOut_ready;

// delta B - expand dimention
logic delta_B_layer_ready, delta_B_dOut_ready;

// EXP piecewise
logic pEXP_layer_ready, pEXP_dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
Linear_expand_dBC_delta #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),   // L(16)
    .NUM_DIM_1(NUM_DIM_1),     // ED(40)
    .NUM_DIM_2(NUM_DIM_DELTA), // 32

    .NUM_SCALE_DIN(LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .NUM_SCALE_DOUT(LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID)
) Linear_expand_dBC_delta (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(linEx_dBC_delta_dOut),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(linEx_delta_layer_ready),
    .layer_ready(linEx_dBC_delta_layer_ready),
    .dOut_ready(linEx_dBC_delta_dOut_ready)
);

Linear_expand_dBC_BC #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM_1(NUM_DIM_1),   // ED(40)
    .NUM_DIM_2(NUM_DIM_2),   // N(8)

    .NUM_SCALE_DIN(LINEX_DBC_B_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .NUM_SCALE_DOUT(LINEX_DBC_B_NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID * 2)
) Linear_expand_dBC_B (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(linEx_dBC_B_dOut),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(delta_B_layer_ready),
    .layer_ready(linEx_dBC_B_layer_ready),
    .dOut_ready(linEx_dBC_B_dOut_ready)
);

Linear_expand_dBC_BC #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM_1(NUM_DIM_1),   // ED(40)
    .NUM_DIM_2(NUM_DIM_2),   // N(8)

    .NUM_SCALE_DIN(LINEX_DBC_C_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .NUM_SCALE_DOUT(LINEX_DBC_C_NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID * 2 + 1)
) Linear_expand_dBC_C (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(linEx_dBC_C_dOut),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(linEx_dBC_C_layer_ready),
    .dOut_ready(linEx_dBC_C_dOut_ready)
);

Linear_expand_delta #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),   // L(16)
    .NUM_DIM_1(NUM_DIM_DELTA), // 32
    .NUM_DIM_2(NUM_DIM_1),     // ED(40)

    .NUM_SCALE_DIN(LINEX_DELTA_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DELTA_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_DELTA_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_DELTA_NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID)
) Linear_expand_delta (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(linEx_dBC_delta_dOut),
    .dOut(linEx_delta_dOut),

    .prev_layer_ready(linEx_dBC_delta_dOut_ready),
    .next_layer_ready(pEXP_layer_ready),
    .layer_ready(linEx_delta_layer_ready),
    .dOut_ready(linEx_delta_dOut_ready)
);

ReLU #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM(NUM_DIM_1)      // ED(40)
) ReLU (
    .dIn(linEx_delta_dOut),
    .dOut(ReLU_dOut)
);

Dim_expand_delta_B #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN_1(DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(DIMEX_DELTA_B_NUM_SCALE_DOUT)
) Dim_expand_delta_B (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .delta(ReLU_dOut), // delta
    .matrix_B(linEx_dBC_B_dOut_FF_1), // matrix B / N(8)
    .dOut(dimEx_delta_B_dOut),

    .prev_layer_ready(linEx_delta_dOut_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(delta_B_layer_ready),
    .dOut_ready(delta_B_dOut_ready)
);

Exp_piecewise #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1), // ED(40)
    .NUM_DIM_2(NUM_DIM_2), // N(8)

    .NUM_SCALE_DIN_1(DIMEX_DELTA_A_NUM_SCALE_DIN_1), // delta
    .NUM_SCALE_DIN_2(DIMEX_DELTA_A_NUM_SCALE_DIN_2), // A
    .NUM_SCALE_DOUT(DIMEX_DELTA_A_NUM_SCALE_DOUT),

    .LAYER_ID(LAYER_ID)
) Exp_piecewise (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .delta(ReLU_dOut),
    .dOut(delta_A),

    .prev_layer_ready(linEx_delta_dOut_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(pEXP_layer_ready),
    .dOut_ready(pEXP_dOut_ready)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
assign layer_ready = linEx_dBC_delta_layer_ready;
assign dOut_ready = pEXP_dOut_ready;

// Flip flop
always @(posedge clk) begin
    if (prev_layer_ready & next_layer_ready) begin
        linEx_dBC_B_dOut_FF_1 <= #1 linEx_dBC_B_dOut;
    end else begin
        linEx_dBC_B_dOut_FF_1 <= #1 linEx_dBC_B_dOut_FF_1;
    end
end

always @(posedge clk) begin
    if (prev_layer_ready & next_layer_ready) begin
        linEx_dBC_C_dOut_FF_1 <= #1 linEx_dBC_C_dOut;
        linEx_dBC_C_dOut_FF_2 <= #1 linEx_dBC_C_dOut_FF_1;
    end else begin
        linEx_dBC_C_dOut_FF_1 <= #1 linEx_dBC_C_dOut_FF_1;
        linEx_dBC_C_dOut_FF_2 <= #1 linEx_dBC_C_dOut_FF_2;
    end
end

assign matrix_C = linEx_dBC_C_dOut_FF_2;

assign delta_B = dimEx_delta_B_dOut;

endmodule