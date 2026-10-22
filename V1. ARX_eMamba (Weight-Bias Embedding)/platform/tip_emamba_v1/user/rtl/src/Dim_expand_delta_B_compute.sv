`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2024 12:17:44 PM
// Design Name: 
// Module Name: Dim_expand_delta_B_compute
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


module Dim_expand_delta_B_compute #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_ED     = 8,

    parameter integer NUM_SCALE_DIN_1 = 4,
    parameter integer NUM_SCALE_DIN_2 = 3,
    parameter integer NUM_SCALE_DOUT  = 1
)(
    delta,
    matrix,

    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH * 2;

localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN_1 + NUM_SCALE_DIN_2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] delta;
input logic signed [DATA_WIDTH-1:0] matrix [0:NUM_ED-1];

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_ED-1];

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_DOUT-1:0] dOut_ori [0:NUM_ED-1];
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_shifted [0:NUM_ED-1];

genvar n;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_ED; n = n + 1) begin: dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(dOut_ori[n]),
            .dOut(dOut_shifted[n])
        );
    end

    for (n = 0; n < NUM_ED; n = n + 1) begin: dOut_saturation
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator_dOut (
            .dIn(dOut_shifted[n]),
            .dOut(dOut[n])
        );
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_ED; n = n + 1) begin
        always @(*) begin
            dOut_ori[n] = delta * matrix[n];
        end
    end
endgenerate

endmodule

// dout [ed][n] = delta[ed] * matrix B[n]