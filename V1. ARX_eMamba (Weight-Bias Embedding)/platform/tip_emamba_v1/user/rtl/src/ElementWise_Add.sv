`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 11:41:28 AM
// Design Name: 
// Module Name: ElementWise_Add
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


module ElementWise_Add #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM    = 20,

    parameter integer NUM_SCALE_DIN_1 = 5, // Linear contract
    parameter integer NUM_SCALE_DIN_2 = 8, // skip
    parameter integer NUM_SCALE_DOUT  = 5
)(
    dIn_1,
    dIn_2,

    dOut_8bit
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_LSH_DIN_1 = NUM_SCALE_DIN_2 - NUM_SCALE_DIN_1;
localparam integer NUM_RSH_DOUT  = NUM_SCALE_DIN_2 - NUM_SCALE_DOUT;

localparam integer DATA_WIDTH_DIN_1_LSH = DATA_WIDTH + NUM_LSH_DIN_1;
localparam integer DATA_WIDTH_DOUT      = DATA_WIDTH_DIN_1_LSH + 1;   // + 1 -> same bitwidth addition
localparam integer DATA_WIDTH_DOUT_RSH  = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] dIn_1 [0:NUM_DIM-1]; // 1x20
input logic signed [DATA_WIDTH-1:0] dIn_2 [0:NUM_DIM-1]; // 1x20

output logic signed [DATA_WIDTH-1:0] dOut_8bit [0:NUM_DIM-1]; // 1x20

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_DIN_1_LSH-1: 0] dIn_1_left_shifted [0:NUM_DIM-1]; // 1x20

logic signed [DATA_WIDTH_DOUT-1:0]     dOut               [0:NUM_DIM-1];
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_right_shifted [0:NUM_DIM-1];

genvar d;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (d = 0; d < NUM_DIM; d = d + 1) begin : dIn_1_upScaling
        shifter_left #(
            .DATA_WIDTH(DATA_WIDTH),
            .NUM_SHIFT(NUM_LSH_DIN_1)
        ) Shifter_dIn (
            .dIn(dIn_1[d]),
            .dOut(dIn_1_left_shifted[d])
        );
    end

    for (d = 0; d < NUM_DIM; d = d + 1) begin : dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(dOut[d]),
            .dOut(dOut_right_shifted[d])
        );
    end

    for (d = 0; d < NUM_DIM; d = d + 1) begin : dOut_saturation
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator_dOut (
            .dIn(dOut_right_shifted[d]),
            .dOut(dOut_8bit[d])
        );
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (d = 0; d < NUM_DIM; d = d + 1) begin : dOut_computation
        assign dOut[d] = dIn_1_left_shifted[d] + dIn_2[d];
    end
endgenerate

endmodule