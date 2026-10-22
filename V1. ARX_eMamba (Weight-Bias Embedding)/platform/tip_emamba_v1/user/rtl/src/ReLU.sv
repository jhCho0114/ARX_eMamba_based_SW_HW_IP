`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 11:12:46 AM
// Design Name: 
// Module Name: ReLU
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


module ReLU #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM    = 40
)(
    dIn,
    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1];

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
genvar i;
generate
    for(i = 0; i < NUM_DIM; i = i + 1) begin
        always @(*) begin
            if (dIn[i] > 0)
                dOut[i] = dIn[i];
            else
                dOut[i] = 'd0;
        end
    end
endgenerate

endmodule