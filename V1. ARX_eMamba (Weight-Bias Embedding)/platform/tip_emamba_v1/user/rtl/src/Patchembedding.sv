`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/02/2024 02:15:12 PM
// Design Name: 
// Module Name: Patchembedding
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


module Patchembedding #(
    parameter integer DATA_WIDTH    = 8,
    parameter integer NUM_CHANNEL   = 5,
    parameter integer NUM_HEIGHT    = 8,
    parameter integer NUM_WIDTH     = 8,
    parameter integer PATCH1        = 2,
    parameter integer PATCH2        = 2,
    parameter integer NUM_SEQLEN    = 16,
    parameter integer NUM_DIM       = 20,
    parameter integer NUM_SCALE_DIN     = 6,
    parameter integer NUM_SCALE_WEIGHT  = 7,
    parameter integer NUM_SCALE_BIAS    = 8,
    parameter integer NUM_SCALE_DOUT    = 8,

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

input   logic signed [DATA_WIDTH-1:0] dIn   [0:NUM_CHANNEL-1][0:NUM_HEIGHT-1][0:NUM_WIDTH-1]; // 1x5x8x8
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_DIM-1];                                    // 1x20

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] rearrange_dOut [0:NUM_SEQLEN-1][0:NUM_DIM-1]; // 16x20

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
Patch_Rearrange #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNEL(NUM_CHANNEL),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .PATCH1(PATCH1),
    .PATCH2(PATCH2)
) Patch_Rearrange (
    .dIn(dIn),
    .dOut(rearrange_dOut)
);

Patch_Linear #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),
    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) Patch_Linear (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(rearrange_dOut),
    .dOut(dOut),

    .prev_layer_ready(prev_layer_ready),
    .next_layer_ready(next_layer_ready),
    .layer_ready(layer_ready),
    .dOut_ready(dOut_ready)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Print Result Logs
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========

/*
integer index_patch_lin = 0;
integer file_patch_lin;
initial begin
    file_patch_lin = $fopen("/home/jiyong/workspace/eMamba/eMamba_DAC/simulation_results/Patch_linear.txt", "w");
    if (file_patch_lin == 0) begin
        $display("Error: Cannot open file.");
        $finish;
    end
    $fclose(file_patch_lin);
end

always @(posedge dOut_ready) begin
    if (DEBUG_SWITCH) begin
        if (index_patch_lin < 16) begin
            file_patch_lin = $fopen("/home/jiyong/workspace/eMamba/eMamba_DAC/simulation_results/Patch_linear.txt", "a");
            if (file_patch_lin == 0) begin
                $display("Error: Cannot open file.");
                $finish;
            end
            for (int i = 0; i < 20; i++) begin
                if (i < 19)
                    $fwrite(file_patch_lin, "%0d,", dOut[i]);
                else
                    $fwrite(file_patch_lin, "%0d\n", dOut[i]);
            end
            index_patch_lin = index_patch_lin + 1;

        $fclose(file_patch_lin);
        end
    end
end
*/
endmodule