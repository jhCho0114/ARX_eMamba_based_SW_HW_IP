`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/01/2024 08:05:43 PM
// Design Name: 
// Module Name: MAMBA
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


module MAMBA #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 20,
    parameter integer NUM_DIM_2  = 40,

    // LightNorm
    parameter integer LNORM_NUM_SCALE_DIN    = 5,
    parameter integer LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer LNORM_NUM_SCALE_BIAS   = 10,
    parameter integer LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand x1
    parameter integer LINEX_X1_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_X1_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_X1_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_X1_NUM_SCALE_DOUT   = 6,

    // Linear expand z1
    parameter integer LINEX_Z1_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_Z1_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_Z1_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_Z1_NUM_SCALE_DOUT   = 5,

    // SiLU piecewise
    parameter integer SILU_NUM_SCALE_DIN  = 5,
    parameter integer SILU_NUM_SCALE_DOUT = 6,

    // Convolution 1D
    parameter integer CONV1D_NUM_SCALE_DIN    = 6,
    parameter integer CONV1D_NUM_SCALE_WEIGHT = 8,
    parameter integer CONV1D_NUM_SCALE_BIAS   = 9,
    parameter integer CONV1D_NUM_SCALE_DOUT   = 5,

    // SSM
    // Preprocess
    // Linear expand dBC delta
    parameter integer SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 6,

    // Linear expand dBC B
    parameter integer SSM_LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DBC_B_NUM_SCALE_DOUT   = 6,

    // Linear expand dBC C
    parameter integer SSM_LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DBC_C_NUM_SCALE_DOUT   = 5,

    // Linear expand dleta
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_DIN    = 6,
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 3,
    parameter integer SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 6,
    parameter integer SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT  = 3,

    // Computation
    parameter integer SSM_NUM_SCALE_DIN     = 5,
    parameter integer SSM_NUM_SCALE_DELTA_A = 7,
    parameter integer SSM_NUM_SCALE_DELTA_B = 3,
    parameter integer SSM_NUM_SCALE_C       = 5,
    parameter integer SSM_NUM_SCALE_D       = 6,
    parameter integer SSM_NUM_SCALE_DOUT    = 3,

    // Elementwise Production
    parameter integer EW_PROD_NUM_SCALE_DIN_1 = 3,
    parameter integer EW_PROD_NUM_SCALE_DIN_2 = 6,
    parameter integer EW_PROD_NUM_SCALE_DOUT  = 5,

    // Linear contract
    parameter integer LINCONT_NUM_SCALE_DIN    = 5,
    parameter integer LINCONT_NUM_SCALE_WEIGHT = 8,
    parameter integer LINCONT_NUM_SCALE_BIAS   = 9,
    parameter integer LINCONT_NUM_SCALE_DOUT   = 5,

    // Elementwise Addition
    parameter integer EW_ADD_NUM_SCALE_DIN_1 = 5,
    parameter integer EW_ADD_NUM_SCALE_DIN_2 = 8,
    parameter integer EW_ADD_NUM_SCALE_DOUT  = 5,

    parameter integer MAMBA_ID = 0,
    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM_1-1]; // 20
output  logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM_1-1]; // 20 / Elementwise Addition

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Make skip data
logic signed [DATA_WIDTH-1:0] skip_FF_1 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_2 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_3 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_4 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_5 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_6 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_7 [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] skip_FF_8 [0:NUM_DIM_1-1];

// 2. LightNorm
logic signed [DATA_WIDTH-1:0] lightNorm_dOut [0:NUM_DIM_1-1];
logic lightNorm_layer_ready, lightNorm_dOut_ready;

// 3-1. Linear expand x1
logic signed [DATA_WIDTH-1:0] linEx_x1_dOut [0:NUM_DIM_2-1];
logic linEx_x1_layer_ready, linEx_x1_dOut_ready;

// 3-2. Linear expand z1
logic signed [DATA_WIDTH-1:0] linEx_z1_dOut [0:NUM_DIM_2-1];
logic linEx_z1_layer_ready, linEx_z1_dOut_ready;

// SiLU
logic signed [DATA_WIDTH-1:0] SiLU_dOut [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] SiLU_dOut_FF_1 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] SiLU_dOut_FF_2 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] SiLU_dOut_FF_3 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] SiLU_dOut_FF_4 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] SiLU_dOut_FF_5 [0:NUM_DIM_2-1];

// 4. Convolution 1D
logic signed [DATA_WIDTH-1:0] conv1d_dOut [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] conv1d_dOut_FF_1 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] conv1d_dOut_FF_2 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] conv1d_dOut_FF_3 [0:NUM_DIM_2-1];
logic conv1d_layer_ready, conv1d_dOut_ready;

// 5. SSM
logic signed [DATA_WIDTH-1:0] SSM_dOut [0:NUM_DIM_2-1]; // 40 / SSM
logic SSM_layer_ready, SSM_dOut_ready;

// 6. Elementwise Production
logic signed [DATA_WIDTH-1:0] elWise_prod_dOut [0:NUM_DIM_2-1]; // 40 

// 7. Linear contract
logic signed [DATA_WIDTH-1:0] linCont_dOut [0:NUM_DIM_1-1]; // 20
logic linCont_layer_ready;

// 8. elWise_add_dOut
logic signed [DATA_WIDTH-1:0] elWise_add_dOut [0:NUM_DIM_1-1]; //20

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
LightNorm #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM_1),

    .NUM_SCALE_DIN(LNORM_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LNORM_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LNORM_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LNORM_NUM_SCALE_DOUT),

    .LAYER_ID(MAMBA_ID)
) LightNorm (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(lightNorm_dOut),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(linEx_x1_layer_ready),
    .layer_ready(lightNorm_layer_ready),
    .dOut_ready(lightNorm_dOut_ready)
);

Linear_expand #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN(LINEX_X1_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_X1_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_X1_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_X1_NUM_SCALE_DOUT),

    .LAYER_ID(MAMBA_ID * 2)
) Linear_expand_x1 (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(lightNorm_dOut),
    .dOut(linEx_x1_dOut),

    .prev_layer_ready(lightNorm_dOut_ready),
    .next_layer_ready(conv1d_layer_ready),
    .layer_ready(linEx_x1_layer_ready),
    .dOut_ready(linEx_x1_dOut_ready)
);

Linear_expand #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN(LINEX_Z1_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_Z1_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_Z1_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_Z1_NUM_SCALE_DOUT),

    .LAYER_ID(MAMBA_ID * 2 + 1)
) Linear_expand_z1 (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(lightNorm_dOut),
    .dOut(linEx_z1_dOut),

    .prev_layer_ready(lightNorm_dOut_ready),
    .next_layer_ready(conv1d_layer_ready),
    .layer_ready(linEx_z1_layer_ready),
    .dOut_ready(linEx_z1_dOut_ready)
);

SiLU_piecewise #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),

    .NUM_SCALE_DIN(SILU_NUM_SCALE_DIN),
    .NUM_SCALE_DOUT(SILU_NUM_SCALE_DOUT)
) SiLU_piecewise (
    .dIn(linEx_z1_dOut),
    .dOut(SiLU_dOut)
);

Convolution1D #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM_2),

    .NUM_SCALE_DIN(CONV1D_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(CONV1D_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(CONV1D_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(CONV1D_NUM_SCALE_DOUT),

    .LAYER_ID(MAMBA_ID)
) Convolution1D (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(linEx_x1_dOut),
    .dOut(conv1d_dOut),

    .prev_layer_ready(linEx_x1_dOut_ready),
    .next_layer_ready(SSM_layer_ready),
    .layer_ready(conv1d_layer_ready),
    .dOut_ready(conv1d_dOut_ready)
);

SSM #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_2), // ED
    .NUM_DIM_2(8),         // N

    // Preprocess
    // Linear expand dBC delta
    .LINEX_DBC_DELTA_NUM_SCALE_DIN(SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DBC_DELTA_NUM_SCALE_DOUT(SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .LINEX_DBC_B_NUM_SCALE_DIN(SSM_LINEX_DBC_B_NUM_SCALE_DIN),
    .LINEX_DBC_B_NUM_SCALE_WEIGHT(SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .LINEX_DBC_B_NUM_SCALE_DOUT(SSM_LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .LINEX_DBC_C_NUM_SCALE_DIN(SSM_LINEX_DBC_C_NUM_SCALE_DIN),
    .LINEX_DBC_C_NUM_SCALE_WEIGHT(SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .LINEX_DBC_C_NUM_SCALE_DOUT(SSM_LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .LINEX_DELTA_NUM_SCALE_DIN(SSM_LINEX_DELTA_NUM_SCALE_DIN),
    .LINEX_DELTA_NUM_SCALE_WEIGHT(SSM_LINEX_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DELTA_NUM_SCALE_BIAS(SSM_LINEX_DELTA_NUM_SCALE_BIAS),
    .LINEX_DELTA_NUM_SCALE_DOUT(SSM_LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .DIMEX_DELTA_A_NUM_SCALE_DIN_1(SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_A_NUM_SCALE_DIN_2(SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_A_NUM_SCALE_DOUT(SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .DIMEX_DELTA_B_NUM_SCALE_DIN_1(SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_B_NUM_SCALE_DIN_2(SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_B_NUM_SCALE_DOUT(SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT),

    // Computation
    .NUM_SCALE_DIN(SSM_NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(SSM_NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(SSM_NUM_SCALE_DELTA_B),
    .NUM_SCALE_C(SSM_NUM_SCALE_C),
    .NUM_SCALE_D(SSM_NUM_SCALE_D),
    .NUM_SCALE_DOUT(SSM_NUM_SCALE_DOUT),

    .LAYER_ID(MAMBA_ID),
    .DEBUG_SWITCH(DEBUG_SWITCH)
) SSM (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(conv1d_dOut),
    .dIn_delayed(conv1d_dOut_FF_3),
    .dOut(SSM_dOut),

    .prev_layer_ready(conv1d_dOut_ready),
    .next_layer_ready(linCont_layer_ready),
    .layer_ready(SSM_layer_ready),
    .dOut_ready(SSM_dOut_ready)
);

ElementWise_Prod #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2), // ED

    .NUM_SCALE_DIN_1(EW_PROD_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(EW_PROD_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(EW_PROD_NUM_SCALE_DOUT)
) ElementWise_Prod (
    .dIn_1(SSM_dOut),       // SSM
    .dIn_2(SiLU_dOut_FF_5), // SiLU

    .dOut(elWise_prod_dOut)
);

Linear_contract #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L
    .NUM_DIM_1(NUM_DIM_2),   // ED
    .NUM_DIM_2(NUM_DIM_1),   // D

    .NUM_SCALE_DIN(LINCONT_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINCONT_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINCONT_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINCONT_NUM_SCALE_DOUT),

    .LAYER_ID(MAMBA_ID)
) Linear_contract (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(elWise_prod_dOut),
    .dOut(linCont_dOut),

    .prev_layer_ready(SSM_dOut_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(linCont_layer_ready),
    .dOut_ready(dOut_ready)
);

ElementWise_Add #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_1),

    .NUM_SCALE_DIN_1(EW_ADD_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(EW_ADD_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(EW_ADD_NUM_SCALE_DOUT)
) ElementWise_Add (
    .dIn_1(linCont_dOut), // Linear contract
    .dIn_2(skip_FF_8), // Skip

    .dOut_8bit(elWise_add_dOut)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Ready signals
assign layer_ready = lightNorm_layer_ready;

// Output data
assign dOut = elWise_add_dOut;

// Flip Flops for skipping data
always @(posedge clk) begin
    if (prev_layer_ready & lightNorm_layer_ready) begin
        skip_FF_1 <= #1 dIn;
        skip_FF_2 <= #1 skip_FF_1;
        skip_FF_3 <= #1 skip_FF_2;
        skip_FF_4 <= #1 skip_FF_3;
        skip_FF_5 <= #1 skip_FF_4;
        skip_FF_6 <= #1 skip_FF_5;
        skip_FF_7 <= #1 skip_FF_6;
        skip_FF_8 <= #1 skip_FF_7;
    end else begin
        skip_FF_1 <= #1 skip_FF_1;
        skip_FF_2 <= #1 skip_FF_2;
        skip_FF_3 <= #1 skip_FF_3;
        skip_FF_4 <= #1 skip_FF_4;
        skip_FF_5 <= #1 skip_FF_5;
        skip_FF_6 <= #1 skip_FF_6;
        skip_FF_7 <= #1 skip_FF_7;
        skip_FF_8 <= #1 skip_FF_8;
    end
end

always @(posedge clk) begin
    if (conv1d_dOut_ready & SSM_layer_ready) begin
        conv1d_dOut_FF_1 <= #1 conv1d_dOut;
        conv1d_dOut_FF_2 <= #1 conv1d_dOut_FF_1;
        conv1d_dOut_FF_3 <= #1 conv1d_dOut_FF_2;
    end else begin
        conv1d_dOut_FF_1 <= #1 conv1d_dOut_FF_1;
        conv1d_dOut_FF_2 <= #1 conv1d_dOut_FF_2;
        conv1d_dOut_FF_3 <= #1 conv1d_dOut_FF_3;
    end
end

always @(posedge clk) begin
    if (linEx_z1_dOut_ready & conv1d_layer_ready) begin
        SiLU_dOut_FF_1 <= #1 SiLU_dOut;
        SiLU_dOut_FF_2 <= #1 SiLU_dOut_FF_1;
        SiLU_dOut_FF_3 <= #1 SiLU_dOut_FF_2;
        SiLU_dOut_FF_4 <= #1 SiLU_dOut_FF_3;
        SiLU_dOut_FF_5 <= #1 SiLU_dOut_FF_4;
    end else begin
        SiLU_dOut_FF_1 <= #1 SiLU_dOut_FF_1;
        SiLU_dOut_FF_2 <= #1 SiLU_dOut_FF_2;
        SiLU_dOut_FF_3 <= #1 SiLU_dOut_FF_3;
        SiLU_dOut_FF_4 <= #1 SiLU_dOut_FF_4;
        SiLU_dOut_FF_5 <= #1 SiLU_dOut_FF_5;
    end
end


// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Print Result Logs
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// integer index_lightNorm = 0;
// integer file_lightNorm;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_lightNorm = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_LightNorm.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_lightNorm = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_LightNorm.txt", "w");

//     if (file_lightNorm == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_lightNorm);
// end

// always @(posedge lightNorm_dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_lightNorm < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_lightNorm = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_LightNorm.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_lightNorm = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_LightNorm.txt", "a");

//             if (file_lightNorm == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 20; i++) begin
//                 if (i < 19)
//                     $fwrite(file_lightNorm, "%0d,", lightNorm_dOut[i]);
//                 else
//                     $fwrite(file_lightNorm, "%0d\n", lightNorm_dOut[i]);
//             end
//             index_lightNorm = index_lightNorm + 1;

//         $fclose(file_lightNorm);
//         end
//     end
// end

// integer index_linEx_x1 = 0;
// integer file_linEx_x1;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_linEx_x1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Linear_x1.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_linEx_x1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Linear_x1.txt", "w");

//     if (file_linEx_x1 == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_linEx_x1);
// end

// always @(posedge linEx_x1_dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_linEx_x1 < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_linEx_x1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Linear_x1.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_linEx_x1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Linear_x1.txt", "a");

//             if (file_linEx_x1 == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_linEx_x1, "%0d,", linEx_x1_dOut[i]);
//                 else
//                     $fwrite(file_linEx_x1, "%0d\n", linEx_x1_dOut[i]);
//             end
//             index_linEx_x1 = index_linEx_x1 + 1;

//         $fclose(file_linEx_x1);
//         end
//     end
// end

// integer index_linEx_z1 = 0;
// integer file_linEx_z1;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_linEx_z1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Linear_z1.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_linEx_z1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Linear_z1.txt", "w");

//     if (file_linEx_z1 == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_linEx_z1);
// end

// always @(posedge linEx_z1_dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_linEx_z1 < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_linEx_z1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Linear_z1.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_linEx_z1 = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Linear_z1.txt", "a");
            
//             if (file_linEx_z1 == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_linEx_z1, "%0d,", linEx_z1_dOut[i]);
//                 else
//                     $fwrite(file_linEx_z1, "%0d\n", linEx_z1_dOut[i]);
//             end
//             index_linEx_z1 = index_linEx_z1 + 1;

//         $fclose(file_linEx_z1);
//         end
//     end
// end

// integer index_conv1d = 0;
// integer file_conv1d;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_conv1d = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Conv1D.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_conv1d = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Conv1D.txt", "w");

//     if (file_conv1d == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_conv1d);
// end

// always @(posedge conv1d_dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_conv1d < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_conv1d = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Conv1D.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_conv1d = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Conv1D.txt", "a");

//             if (file_conv1d == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_conv1d, "%0d,", conv1d_dOut[i]);
//                 else
//                     $fwrite(file_conv1d, "%0d\n", conv1d_dOut[i]);
//             end
//             index_conv1d = index_conv1d + 1;

//         $fclose(file_conv1d);
//         end
//     end
// end

// integer index_linCont = 0;
// integer file_linCont;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_linCont = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Linear_contract.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_linCont = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Linear_contract.txt", "w");

//     if (file_linCont == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_linCont);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_linCont < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_linCont = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Linear_contract.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_linCont = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Linear_contract.txt", "a");
                
//             if (file_linCont == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 20; i++) begin
//                 if (i < 19)
//                     $fwrite(file_linCont, "%0d,", linCont_dOut[i]);
//                 else
//                     $fwrite(file_linCont, "%0d\n", linCont_dOut[i]);
//             end
//             index_linCont = index_linCont + 1;

//         $fclose(file_linCont);
//         end
//     end
// end

// integer index_pSiLU = 0;
// integer file_pSiLU;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_pSiLU = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SiLU.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_pSiLU = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SiLU.txt", "w");

//     if (file_pSiLU == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_pSiLU);
// end

// always @(posedge linEx_z1_dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_pSiLU < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_pSiLU = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SiLU.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_pSiLU = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SiLU.txt", "a");
            
//             if (file_pSiLU == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_pSiLU, "%0d,", SiLU_dOut[i]);
//                 else
//                     $fwrite(file_pSiLU, "%0d\n", SiLU_dOut[i]);
//             end
//             index_pSiLU = index_pSiLU + 1;

//         $fclose(file_pSiLU);
//         end
//     end
// end

// integer index_elWise_prod = 0;
// integer file_elWise_prod;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_elWise_prod = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Elementwise_Prod.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_elWise_prod = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Elementwise_Prod.txt", "w");

//     if (file_elWise_prod == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_elWise_prod);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_elWise_prod < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_elWise_prod = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_Elementwise_Prod.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_elWise_prod = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_Elementwise_Prod.txt", "a");
                
//             if (file_elWise_prod == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_elWise_prod, "%0d,", elWise_prod_dOut[i]);
//                 else
//                     $fwrite(file_elWise_prod, "%0d\n", elWise_prod_dOut[i]);
//             end
//             index_elWise_prod = index_elWise_prod + 1;

//         $fclose(file_elWise_prod);
//         end
//     end
// end

endmodule