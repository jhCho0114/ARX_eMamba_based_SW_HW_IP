`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Jiyong Kim
// 
// Create Date: 10/09/2024 06:00:15 PM
// Design Name: 
// Module Name: CLA_16
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


module CLA_16 (
    dIn_1,
    dIn_2,
    carryIn,

    dOut,
    carryOut
);

localparam integer DATA_WIDTH = 16;

input logic [DATA_WIDTH-1:0] dIn_1, dIn_2;
input logic carryIn;

output logic [DATA_WIDTH-1:0] dOut; // Sum
output logic carryOut;

logic [3:0] carry;

CLA_4 CLA_0 (
    .dIn_1(dIn_1[3:0]),
    .dIn_2(dIn_2[3:0]),
    .carryIn(carryIn),

    .dOut(dOut[3:0]),
    .carryOut(carry[0])
);

CLA_4 CLA_1 (
    .dIn_1(dIn_1[7:4]),
    .dIn_2(dIn_2[7:4]),
    .carryIn(carry[0]),

    .dOut(dOut[7:4]),
    .carryOut(carry[1])
);

CLA_4 CLA_2 (
    .dIn_1(dIn_1[11:8]),
    .dIn_2(dIn_2[11:8]),
    .carryIn(carry[1]),

    .dOut(dOut[11:8]),
    .carryOut(carry[2])
);

CLA_4 CLA_3 (
    .dIn_1(dIn_1[15:12]),
    .dIn_2(dIn_2[15:12]),
    .carryIn(carry[2]),

    .dOut(dOut[15:12]),
    .carryOut(carry[3])
);

assign carryOut = carry[3];

endmodule