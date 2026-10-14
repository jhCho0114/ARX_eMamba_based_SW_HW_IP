`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Jiyong Kim
// 
// Create Date: 10/10/2024 12:56:36 PM
// Design Name: 
// Module Name: CLA_32
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


module CLA_32 (
    dIn_1,
    dIn_2,
    carryIn,

    dOut,
    carryOut
);

localparam integer DATA_WIDTH = 32;

input logic [DATA_WIDTH-1:0] dIn_1, dIn_2;
input logic carryIn;

output logic [DATA_WIDTH-1:0] dOut; // Sum
output logic carryOut;

logic [1:0] carry;

CLA_16 CLA_0 (
    .dIn_1(dIn_1[15:0]),
    .dIn_2(dIn_2[15:0]),
    .carryIn(carryIn),

    .dOut(dOut[15:0]),
    .carryOut(carry[0])
);

CLA_16 CLA_1 (
    .dIn_1(dIn_1[31:16]),
    .dIn_2(dIn_2[31:16]),
    .carryIn(carry[0]),

    .dOut(dOut[31:16]),
    .carryOut(carry[1])
);

assign carryOut = carry[1];

endmodule