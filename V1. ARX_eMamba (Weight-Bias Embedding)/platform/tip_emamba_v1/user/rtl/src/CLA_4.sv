`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Jiyong Kim
// 
// Create Date: 10/09/2024 06:15:00 PM
// Design Name: 
// Module Name: CLA_4
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


module CLA_4 (
    dIn_1,
    dIn_2,
    carryIn,

    dOut,
    carryOut
);

localparam integer DATA_WIDTH = 4;

input logic [DATA_WIDTH-1:0] dIn_1, dIn_2;
input logic carryIn;

output logic [DATA_WIDTH-1:0] dOut; // Sum
output logic carryOut;

logic [DATA_WIDTH-1:0] gen;  // Generate
logic [DATA_WIDTH-1:0] prop; // Propagate
logic [DATA_WIDTH:0] carry;  // Carry

genvar i;

generate
    for (i = 0; i < DATA_WIDTH; i = i + 1) begin : GnP // Generate & Propagate
        assign gen[i]  = dIn_1[i] & dIn_2[i];
        assign prop[i] = dIn_1[i] | dIn_2[i];
    end

    for (i = 0; i <= DATA_WIDTH; i = i + 1) begin : Carry
        if (i == 0)
            assign carry[i] = carryIn;
        else
            assign carry[i] = gen[i-1] | (prop[i-1] & carry[i-1]);
    end
endgenerate

assign carryOut = carry[DATA_WIDTH];

assign dOut = dIn_1 ^ dIn_2 ^ carry[DATA_WIDTH-1:0];

endmodule