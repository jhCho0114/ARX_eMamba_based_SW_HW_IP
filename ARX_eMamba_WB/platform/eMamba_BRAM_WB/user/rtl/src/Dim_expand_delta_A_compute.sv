`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2024 02:30:06 PM
// Design Name: 
// Module Name: Dim_expand_delta_A_compute
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


module Dim_expand_delta_A_compute #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_ED     = 8
)(
    delta,
    matrix,

    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH * 2;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] delta;
input logic signed [DATA_WIDTH-1:0] matrix [0:NUM_ED-1];

output logic signed [DATA_WIDTH_DOUT-1:0] dOut [0:NUM_ED-1];

genvar n;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_ED; n = n + 1) begin
        assign dOut[n] = delta * matrix[n];
    end
endgenerate

endmodule