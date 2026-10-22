`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2024 11:57:14 PM
// Design Name: 
// Module Name: eMamba
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


module eMamba #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_CHANNEL = 5,
    parameter integer NUM_HEIGHT  = 8,
    parameter integer NUM_WIDTH   = 8,
    parameter integer PATCH1      = 2,
    parameter integer PATCH2      = 2,
    parameter integer NUM_SEQLEN  = 16, // L
    parameter integer NUM_DIM     = 20, // D
    parameter integer NUM_ED      = 40, // ED
    parameter integer NUM_N       = 8,  // N
    parameter integer NUM_DELTA   = 32,
    parameter integer NUM_DBC     = 48, // NUM_DELTA + NUM_N * 2
    parameter integer NUM_CLASS   = 57,

    // ========== ========== ========== ========== ==========
    // Patch embedding
    parameter integer PATCH_NUM_SCALE_DIN    = 3,
    parameter integer PATCH_NUM_SCALE_WEIGHT = 7,
    parameter integer PATCH_NUM_SCALE_BIAS   = 8,
    parameter integer PATCH_NUM_SCALE_DOUT   = 5,

    // ========== ========== ========== ========== ==========
    // MAMBA BLOCK 1ST
    // LightNorm
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_BIAS   = 7,
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand x1
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_DOUT   = 6,

    // Linear expand z1
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_DOUT   = 5,

    // SiLU piecewise
    parameter integer MAMBA_1ST_SILU_NUM_SCALE_DIN  = 5,
    parameter integer MAMBA_1ST_SILU_NUM_SCALE_DOUT = 5,

    // Convolution 1D
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_BIAS   = 9,
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_DOUT   = 5,

    // SSM
    // Preprocess
    // Linear expand dBC delta
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 5,

    // Linear expand dBC B
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DOUT   = 5,

    // Linear expand dBC C
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DOUT   = 5,

    // Linear expand dleta
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 3,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT  = 3,

    // Computation
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DIN     = 5,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DELTA_A = 7,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DELTA_B = 3,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_C       = 5,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_D       = 6,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DOUT    = 1,

    // Elementwise Production
    parameter integer MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_1 = 1,
    parameter integer MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_1ST_EW_PROD_NUM_SCALE_DOUT  = 2,

    // Linear contract
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_DIN    = 2,
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_BIAS   = 9,
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_DOUT   = 3,

    // Elementwise Addition
    parameter integer MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_1 = 3,
    parameter integer MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_1ST_EW_ADD_NUM_SCALE_DOUT  = 3,

    // ========== ========== ========== ========== ==========
    // MAMBA BLOCK 2ND
    // LightNorm
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_DIN    = 3,
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_BIAS   = 7,
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand x1
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_DOUT   = 6,

    // Linear expand z1
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_DOUT   = 5,

    // SiLU piecewise
    parameter integer MAMBA_2ND_SILU_NUM_SCALE_DIN  = 5,
    parameter integer MAMBA_2ND_SILU_NUM_SCALE_DOUT = 5,

    // Convolution 1D
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_DOUT   = 5,

    // SSM
    // Preprocess
    // Linear expand dBC delta
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 5,

    // Linear expand dBC B
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DOUT   = 3,

    // Linear expand dBC C
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DOUT   = 3,

    // Linear expand dleta
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 2,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 3,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT  = 1,

    // Computation
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DIN     = 5,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DELTA_A = 7,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DELTA_B = 1,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_C       = 3,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_D       = 6,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DOUT    = -3,

    // Elementwise Production
    parameter integer MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_1 = -3,
    parameter integer MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_2ND_EW_PROD_NUM_SCALE_DOUT  = -4,

    // Linear contract
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_DIN    = -4,
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_BIAS   = 9,
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_DOUT   = -3,

    // Elementwise Addition
    parameter integer MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_1 = -3,
    parameter integer MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_2 = 3,
    parameter integer MAMBA_2ND_EW_ADD_NUM_SCALE_DOUT  = -3,

    // ========== ========== ========== ========== ==========
    // Outputhead
    // LightNorm
    parameter integer OH_LNORM_NUM_SCALE_DIN    = -3,
    parameter integer OH_LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer OH_LNORM_NUM_SCALE_BIAS   = 7,
    parameter integer OH_LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand
    parameter integer OH_LINEX_NUM_SCALE_DIN    = 6,
    parameter integer OH_LINEX_NUM_SCALE_WEIGHT = 8,
    parameter integer OH_LINEX_NUM_SCALE_BIAS   = 8,
    parameter integer OH_LINEX_NUM_SCALE_DOUT   = 6
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    dOut_ready,
    dOut_seqlength,
    frameDout_ready,
    
    eMamba_start
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DEBUG_SWITCH_PATCHEMBEDDING  = 1,
                   DEBUG_SWITCH_MAMBA_1ST   = 1,
                   DEBUG_SWITCH_MAMBA_2ND   = 2,
                   DEBUG_SWITCH_OUTPUTHEAD  = 1;

localparam IDLE = 1'b0,
           BUSY = 1'b1;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;
input ps_start;

input   logic signed [DATA_WIDTH * NUM_CHANNEL * NUM_HEIGHT * NUM_WIDTH - 1:0] dIn; // 1x5x8x8
output  logic signed [DATA_WIDTH * NUM_CLASS - 1:0] dOut; // Class 57

output dOut_ready;
output [3:0] dOut_seqlength;
output frameDout_ready;

output  eMamba_start;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main FSM
logic curr_startCtrl_state, next_startCtrl_state;
logic curr_validCtrl_state, next_validCtrl_state;
logic [5:0] seq_counter, token_counter;

// Frame data signal
logic frameData_ready;
logic eMamba_running;

// 1. Patchembedding
logic signed [DATA_WIDTH-1:0] patch_dOut [0:NUM_DIM-1];
logic patch_layer_ready, patch_dOut_ready;

// 1st MAMBA
logic signed [DATA_WIDTH-1:0] MAMBA_1st_dOut [0:NUM_DIM-1];
logic MAMBA_1st_layer_ready, MAMBA_1st_dOut_ready;

// 2nd MAMBA
logic signed [DATA_WIDTH-1:0] MAMBA_2nd_dOut [0:NUM_DIM-1];
logic MAMBA_2nd_layer_ready, MAMBA_2nd_dOut_ready;

// Outputhead
logic signed [DATA_WIDTH-1:0] OH_dOut [0:NUM_CLASS-1];
logic OH_layer_ready, OH_dOut_ready;

// PS start signal edges
logic ps_start_rising, ps_start_falling;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Indexing
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
genvar c, h, w;

// Initial Input
logic signed [DATA_WIDTH-1:0] dIn_arr [0:NUM_CHANNEL-1][0:NUM_HEIGHT-1][0:NUM_WIDTH-1]; // 1x5x8x8
generate
    for (c = 0; c < NUM_CHANNEL; c = c + 1) begin
        for (h = 0; h < NUM_HEIGHT; h = h + 1) begin
            for (w = 0; w < NUM_WIDTH; w = w + 1) begin
                assign dIn_arr[c][h][w] = dIn[(c * NUM_HEIGHT * NUM_WIDTH + h * NUM_WIDTH + w) * DATA_WIDTH +: DATA_WIDTH];
            end
        end
    end
endgenerate

// Final Output
generate
    for (c = 0; c < NUM_CLASS; c = c + 1) begin
        assign dOut[c * DATA_WIDTH +: DATA_WIDTH] = OH_dOut[c];
    end
endgenerate



// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
Patchembedding #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNEL(NUM_CHANNEL),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .PATCH1(PATCH1),
    .PATCH2(PATCH2),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM(NUM_DIM),       // D(20)

    .NUM_SCALE_DIN(PATCH_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(PATCH_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(PATCH_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(PATCH_NUM_SCALE_DOUT),

    .DEBUG_SWITCH(DEBUG_SWITCH_PATCHEMBEDDING)
) Patchembedding (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(dIn_arr),
    .dOut(patch_dOut),

    .prev_layer_ready(frameData_ready),
    .next_layer_ready(MAMBA_1st_layer_ready),
    .layer_ready(patch_layer_ready),
    .dOut_ready(patch_dOut_ready)
);

MAMBA #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM_1(NUM_DIM),   // D(20)
    .NUM_DIM_2(NUM_ED),   // ED(40)

    // LightNorm
    .LNORM_NUM_SCALE_DIN(MAMBA_1ST_LNORM_NUM_SCALE_DIN),
    .LNORM_NUM_SCALE_WEIGHT(MAMBA_1ST_LNORM_NUM_SCALE_WEIGHT),
    .LNORM_NUM_SCALE_BIAS(MAMBA_1ST_LNORM_NUM_SCALE_BIAS),
    .LNORM_NUM_SCALE_DOUT(MAMBA_1ST_LNORM_NUM_SCALE_DOUT),

    // Linear expand x1
    .LINEX_X1_NUM_SCALE_DIN(MAMBA_1ST_LINEX_X1_NUM_SCALE_DIN),
    .LINEX_X1_NUM_SCALE_WEIGHT(MAMBA_1ST_LINEX_X1_NUM_SCALE_WEIGHT),
    .LINEX_X1_NUM_SCALE_BIAS(MAMBA_1ST_LINEX_X1_NUM_SCALE_BIAS),
    .LINEX_X1_NUM_SCALE_DOUT(MAMBA_1ST_LINEX_X1_NUM_SCALE_DOUT),

    // Linear expand z1
    .LINEX_Z1_NUM_SCALE_DIN(MAMBA_1ST_LINEX_Z1_NUM_SCALE_DIN),
    .LINEX_Z1_NUM_SCALE_WEIGHT(MAMBA_1ST_LINEX_Z1_NUM_SCALE_WEIGHT),
    .LINEX_Z1_NUM_SCALE_BIAS(MAMBA_1ST_LINEX_Z1_NUM_SCALE_BIAS),
    .LINEX_Z1_NUM_SCALE_DOUT(MAMBA_1ST_LINEX_Z1_NUM_SCALE_DOUT),

    // SiLU piecewise
    .SILU_NUM_SCALE_DIN(MAMBA_1ST_SILU_NUM_SCALE_DIN),
    .SILU_NUM_SCALE_DOUT(MAMBA_1ST_SILU_NUM_SCALE_DOUT),

    // Convolution 1D
    .CONV1D_NUM_SCALE_DIN(MAMBA_1ST_CONV1D_NUM_SCALE_DIN),
    .CONV1D_NUM_SCALE_WEIGHT(MAMBA_1ST_CONV1D_NUM_SCALE_WEIGHT),
    .CONV1D_NUM_SCALE_BIAS(MAMBA_1ST_CONV1D_NUM_SCALE_BIAS),
    .CONV1D_NUM_SCALE_DOUT(MAMBA_1ST_CONV1D_NUM_SCALE_DOUT),

    // SSM
    // Preprocess
    // Linear expand dBC delta
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .SSM_LINEX_DBC_B_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_B_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .SSM_LINEX_DBC_C_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_C_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .SSM_LINEX_DELTA_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DELTA_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DELTA_NUM_SCALE_BIAS(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_BIAS),
    .SSM_LINEX_DELTA_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1(MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2(MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT(MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1(MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2(MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT(MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT),

    // Computation
    .SSM_NUM_SCALE_DIN(MAMBA_1ST_SSM_NUM_SCALE_DIN),
    .SSM_NUM_SCALE_DELTA_A(MAMBA_1ST_SSM_NUM_SCALE_DELTA_A),
    .SSM_NUM_SCALE_DELTA_B(MAMBA_1ST_SSM_NUM_SCALE_DELTA_B),
    .SSM_NUM_SCALE_C(MAMBA_1ST_SSM_NUM_SCALE_C),
    .SSM_NUM_SCALE_D(MAMBA_1ST_SSM_NUM_SCALE_D),
    .SSM_NUM_SCALE_DOUT(MAMBA_1ST_SSM_NUM_SCALE_DOUT),

    // Elementwise Production
    .EW_PROD_NUM_SCALE_DIN_1(MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_1),
    .EW_PROD_NUM_SCALE_DIN_2(MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_2),
    .EW_PROD_NUM_SCALE_DOUT(MAMBA_1ST_EW_PROD_NUM_SCALE_DOUT),

    // Linear contract
    .LINCONT_NUM_SCALE_DIN(MAMBA_1ST_LINCONT_NUM_SCALE_DIN),
    .LINCONT_NUM_SCALE_WEIGHT(MAMBA_1ST_LINCONT_NUM_SCALE_WEIGHT),
    .LINCONT_NUM_SCALE_BIAS(MAMBA_1ST_LINCONT_NUM_SCALE_BIAS),
    .LINCONT_NUM_SCALE_DOUT(MAMBA_1ST_LINCONT_NUM_SCALE_DOUT),

    // Elementwise Addition
    .EW_ADD_NUM_SCALE_DIN_1(MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_1),
    .EW_ADD_NUM_SCALE_DIN_2(MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_2),
    .EW_ADD_NUM_SCALE_DOUT(MAMBA_1ST_EW_ADD_NUM_SCALE_DOUT),

    .MAMBA_ID(0),
    .DEBUG_SWITCH(DEBUG_SWITCH_MAMBA_1ST)
) MAMBA_1st (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(patch_dOut),
    .dOut(MAMBA_1st_dOut),

    .prev_layer_ready(patch_dOut_ready),
    .next_layer_ready(MAMBA_2nd_layer_ready),
    .layer_ready(MAMBA_1st_layer_ready),
    .dOut_ready(MAMBA_1st_dOut_ready)
);

MAMBA #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM_1(NUM_DIM),   // D(20)
    .NUM_DIM_2(NUM_ED),   // ED(40)

    // LightNorm
    .LNORM_NUM_SCALE_DIN(MAMBA_2ND_LNORM_NUM_SCALE_DIN),
    .LNORM_NUM_SCALE_WEIGHT(MAMBA_2ND_LNORM_NUM_SCALE_WEIGHT),
    .LNORM_NUM_SCALE_BIAS(MAMBA_2ND_LNORM_NUM_SCALE_BIAS),
    .LNORM_NUM_SCALE_DOUT(MAMBA_2ND_LNORM_NUM_SCALE_DOUT),

    // Linear expand x1
    .LINEX_X1_NUM_SCALE_DIN(MAMBA_2ND_LINEX_X1_NUM_SCALE_DIN),
    .LINEX_X1_NUM_SCALE_WEIGHT(MAMBA_2ND_LINEX_X1_NUM_SCALE_WEIGHT),
    .LINEX_X1_NUM_SCALE_BIAS(MAMBA_2ND_LINEX_X1_NUM_SCALE_BIAS),
    .LINEX_X1_NUM_SCALE_DOUT(MAMBA_2ND_LINEX_X1_NUM_SCALE_DOUT),

    // Linear expand z1
    .LINEX_Z1_NUM_SCALE_DIN(MAMBA_2ND_LINEX_Z1_NUM_SCALE_DIN),
    .LINEX_Z1_NUM_SCALE_WEIGHT(MAMBA_2ND_LINEX_Z1_NUM_SCALE_WEIGHT),
    .LINEX_Z1_NUM_SCALE_BIAS(MAMBA_2ND_LINEX_Z1_NUM_SCALE_BIAS),
    .LINEX_Z1_NUM_SCALE_DOUT(MAMBA_2ND_LINEX_Z1_NUM_SCALE_DOUT),

    // SiLU piecewise
    .SILU_NUM_SCALE_DIN(MAMBA_2ND_SILU_NUM_SCALE_DIN),
    .SILU_NUM_SCALE_DOUT(MAMBA_2ND_SILU_NUM_SCALE_DOUT),

    // Convolution 1D
    .CONV1D_NUM_SCALE_DIN(MAMBA_2ND_CONV1D_NUM_SCALE_DIN),
    .CONV1D_NUM_SCALE_WEIGHT(MAMBA_2ND_CONV1D_NUM_SCALE_WEIGHT),
    .CONV1D_NUM_SCALE_BIAS(MAMBA_2ND_CONV1D_NUM_SCALE_BIAS),
    .CONV1D_NUM_SCALE_DOUT(MAMBA_2ND_CONV1D_NUM_SCALE_DOUT),

    // SSM
    // Preprocess
    // Linear expand dBC delta
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .SSM_LINEX_DBC_B_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_B_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .SSM_LINEX_DBC_C_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_C_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .SSM_LINEX_DELTA_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DELTA_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DELTA_NUM_SCALE_BIAS(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_BIAS),
    .SSM_LINEX_DELTA_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1(MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2(MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT(MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1(MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2(MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT(MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT),

    // Computation
    .SSM_NUM_SCALE_DIN(MAMBA_2ND_SSM_NUM_SCALE_DIN),
    .SSM_NUM_SCALE_DELTA_A(MAMBA_2ND_SSM_NUM_SCALE_DELTA_A),
    .SSM_NUM_SCALE_DELTA_B(MAMBA_2ND_SSM_NUM_SCALE_DELTA_B),
    .SSM_NUM_SCALE_C(MAMBA_2ND_SSM_NUM_SCALE_C),
    .SSM_NUM_SCALE_D(MAMBA_2ND_SSM_NUM_SCALE_D),
    .SSM_NUM_SCALE_DOUT(MAMBA_2ND_SSM_NUM_SCALE_DOUT),

    // Elementwise Production
    .EW_PROD_NUM_SCALE_DIN_1(MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_1),
    .EW_PROD_NUM_SCALE_DIN_2(MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_2),
    .EW_PROD_NUM_SCALE_DOUT(MAMBA_2ND_EW_PROD_NUM_SCALE_DOUT),

    // Linear contract
    .LINCONT_NUM_SCALE_DIN(MAMBA_2ND_LINCONT_NUM_SCALE_DIN),
    .LINCONT_NUM_SCALE_WEIGHT(MAMBA_2ND_LINCONT_NUM_SCALE_WEIGHT),
    .LINCONT_NUM_SCALE_BIAS(MAMBA_2ND_LINCONT_NUM_SCALE_BIAS),
    .LINCONT_NUM_SCALE_DOUT(MAMBA_2ND_LINCONT_NUM_SCALE_DOUT),

    // Elementwise Addition
    .EW_ADD_NUM_SCALE_DIN_1(MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_1),
    .EW_ADD_NUM_SCALE_DIN_2(MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_2),
    .EW_ADD_NUM_SCALE_DOUT(MAMBA_2ND_EW_ADD_NUM_SCALE_DOUT),

    .MAMBA_ID(1),
    .DEBUG_SWITCH(DEBUG_SWITCH_MAMBA_2ND)
) MAMBA_2nd (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(MAMBA_1st_dOut),
    .dOut(MAMBA_2nd_dOut),

    .prev_layer_ready(MAMBA_1st_dOut_ready),
    .next_layer_ready(OH_layer_ready),
    .layer_ready(MAMBA_2nd_layer_ready),
    .dOut_ready(MAMBA_2nd_dOut_ready)
);

Outputhead #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),
    .NUM_CLASS(NUM_CLASS),

    // LightNorm
    .LNORM_NUM_SCALE_DIN(OH_LNORM_NUM_SCALE_DIN),
    .LNORM_NUM_SCALE_WEIGHT(OH_LNORM_NUM_SCALE_WEIGHT),
    .LNORM_NUM_SCALE_BIAS(OH_LNORM_NUM_SCALE_BIAS),
    .LNORM_NUM_SCALE_DOUT(OH_LNORM_NUM_SCALE_DOUT),

    // Linear expand
    .LINEX_NUM_SCALE_DIN(OH_LINEX_NUM_SCALE_DIN),
    .LINEX_NUM_SCALE_WEIGHT(OH_LINEX_NUM_SCALE_WEIGHT),
    .LINEX_NUM_SCALE_BIAS(OH_LINEX_NUM_SCALE_BIAS),
    .LINEX_NUM_SCALE_DOUT(OH_LINEX_NUM_SCALE_DOUT),

    .DEBUG_SWITCH(DEBUG_SWITCH_OUTPUTHEAD)
) Outputhead (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(MAMBA_2nd_dOut),
    .dOut(OH_dOut),

    .prev_layer_ready(MAMBA_2nd_dOut_ready),
    .next_layer_ready(eMamba_running),
    .layer_ready(OH_layer_ready),
    .dOut_ready(OH_dOut_ready),

    .dOut_seqlength(dOut_seqlength)
);

edgeDetector edgeDetector (
    .clk(clk),
    .nRst(nRst),

    .curr_signal(ps_start),

    .rising_edge(ps_start_rising),
    .falling_edge(ps_start_falling)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Start control FSM
always @(posedge clk) begin
    if (!nRst)
        curr_startCtrl_state <= #1 IDLE;
    else
        curr_startCtrl_state <= #1 next_startCtrl_state;
end

always @(*) begin
    next_startCtrl_state = curr_startCtrl_state;

    case (curr_startCtrl_state)
        IDLE: begin
            if (ps_start_rising)
                next_startCtrl_state = BUSY;
            else
                next_startCtrl_state = curr_startCtrl_state;
        end

        BUSY: begin
            if (seq_counter == 0)
                next_startCtrl_state = IDLE;
            else
                next_startCtrl_state = curr_startCtrl_state;
        end
    endcase
end

// Output valid control FSM
always @(posedge clk) begin
    if (!nRst)
        curr_validCtrl_state <= #1 IDLE;
    else
        curr_validCtrl_state <= #1 next_validCtrl_state;
end

always @(*) begin
    next_validCtrl_state = curr_validCtrl_state;

    case (curr_validCtrl_state)
        IDLE: begin
            if (ps_start_rising)
                next_validCtrl_state = BUSY;
            else
                next_validCtrl_state = curr_validCtrl_state;
        end

        BUSY: begin
            if (token_counter == 0)
                next_validCtrl_state = IDLE;
            else
                next_validCtrl_state = curr_validCtrl_state;
        end
    endcase
end

// Control & Ready signals
assign eMamba_start = frameData_ready && (seq_counter == NUM_SEQLEN);
assign eMamba_running = (curr_validCtrl_state == BUSY) ? 1'b1 : 1'b0;
assign frameData_ready = ((curr_startCtrl_state == BUSY) && patch_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = OH_dOut_ready && eMamba_running;
assign frameDout_ready = (token_counter == 0);

// Sequence length counter
// Each frame has 16 seqlength
always @(posedge clk) begin
    if (curr_startCtrl_state == IDLE)
        seq_counter <= #1 NUM_SEQLEN;
    else
        if (seq_counter == 0)
            seq_counter <= #1 seq_counter;
        else
            if (frameData_ready)
                seq_counter <= #1 seq_counter - 1;
            else
                seq_counter <= #1 seq_counter;
end

// Final output token valid counter
always @(posedge clk) begin
    if (curr_validCtrl_state == IDLE)
        token_counter <= #1 NUM_SEQLEN;
    else
        if (token_counter == 0)
            token_counter <= #1 token_counter;
        else
            if (OH_dOut_ready) // If not work well use rising edge
                token_counter <= #1 token_counter - 1;
            else
                token_counter <= #1 token_counter;
end

endmodule