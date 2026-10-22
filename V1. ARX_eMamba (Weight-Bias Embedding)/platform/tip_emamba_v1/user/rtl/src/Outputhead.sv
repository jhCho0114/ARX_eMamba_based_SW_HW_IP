`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 10:28:20 AM
// Design Name: 
// Module Name: Outputhead
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


module Outputhead #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM    = 20,
    parameter integer NUM_CLASS  = 57,

    // LightNorm
    parameter integer LNORM_NUM_SCALE_DIN    = 5,
    parameter integer LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer LNORM_NUM_SCALE_BIAS   = 10,
    parameter integer LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand
    parameter integer LINEX_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_NUM_SCALE_DOUT   = 6,

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
    dOut_ready,

    dOut_seqlength
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] dIn   [0:NUM_DIM-1];
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_CLASS-1]; // Linear expand

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

output [3:0] dOut_seqlength;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// LightNorm
logic signed [DATA_WIDTH-1:0] lightNorm_dOut [0:NUM_DIM-1];
logic lightNorm_dOut_ready;

// Linear expand
logic linEx_layer_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
LightNorm #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),

    .NUM_SCALE_DIN(LNORM_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LNORM_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LNORM_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LNORM_NUM_SCALE_DOUT),

    .LAYER_ID(2)
) OH_LightNorm (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(lightNorm_dOut),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(linEx_layer_ready),
    .layer_ready(layer_ready),
    .dOut_ready(lightNorm_dOut_ready)
);

Linear_expand #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM),
    .NUM_DIM_2(NUM_CLASS),

    .NUM_SCALE_DIN(LINEX_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_NUM_SCALE_DOUT),

    .LAYER_ID(4)
) OH_Linear_expand (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(lightNorm_dOut),
    .dOut(dOut),

    .prev_layer_ready(lightNorm_dOut_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(linEx_layer_ready),
    .dOut_ready(dOut_ready),

    .dOut_seqlength(dOut_seqlength)
);


// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Print Result Logs
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// integer index_lightNorm = 0;
// integer file_lightNorm;
// initial begin
//     file_lightNorm = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/OH_LightNorm.txt", "w");
//     if (file_lightNorm == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_lightNorm);
// end

// always @(posedge lightNorm_dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_lightNorm < 16) begin
//             file_lightNorm = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/OH_LightNorm.txt", "a");
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

// integer index_linEx = 0;
// integer file_linEx;
// initial begin
//     file_linEx = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/OH_Linear.txt", "w");
//     if (file_linEx == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_linEx);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_linEx < 16) begin
//             file_linEx = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/OH_Linear.txt", "a");
//             if (file_linEx == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 57; i++) begin
//                 if (i < 56)
//                     $fwrite(file_linEx, "%0d,", dOut[i]);
//                 else
//                     $fwrite(file_linEx, "%0d\n", dOut[i]);
//             end
//             index_linEx = index_linEx + 1;

//         $fclose(file_linEx);
//         end
//     end
// end

endmodule