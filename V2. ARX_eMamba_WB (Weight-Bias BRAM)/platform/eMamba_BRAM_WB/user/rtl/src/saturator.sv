`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 11:42:03 PM
// Design Name: 
// Module Name: saturator
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


module saturator #(
    parameter integer DATA_WIDTH = 8
)(
    dIn,
    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DOUT = 8;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] dIn;

output logic signed [DATA_WIDTH_DOUT-1:0] dOut;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
always @(*) begin
    if (dIn >= 127)
        dOut = 'd127;
    else if (dIn <= -128)
        dOut = -'d128;
    else
        dOut = dIn;
end

endmodule