`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/01/2024 03:51:18 PM
// Design Name: 
// Module Name: matMult_20
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


module matMult_20 #(
    parameter integer DATA_WIDTH       = 8,
    parameter integer NUM_SCALE_DIN    = 6,
    parameter integer NUM_SCALE_WEIGHT = 7,
    parameter integer NUM_SCALE_BIAS   = 8
)(
    dIn,
    weight,
    bias,

    dOut
);

// ---------- Parameters ---------- //
localparam integer NUM_DIM = 20;
localparam integer NUM_LSH_BIAS = NUM_SCALE_DIN + NUM_SCALE_WEIGHT - NUM_SCALE_BIAS;
localparam integer DATA_WIDTH_BIAS_LSH = DATA_WIDTH + NUM_LSH_BIAS;

// 4 < log2 20 < 5
localparam DATA_WIDTH_DOUT = DATA_WIDTH * 2 + 5;

// ---------- Inputs / Outputs ---------- //
input logic signed [DATA_WIDTH-1:0] dIn    [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] bias;

output logic signed [DATA_WIDTH_DOUT-1:0] dOut;

// ---------- Internal Variables ---------- //
logic signed [DATA_WIDTH_BIAS_LSH-1:0] bias_lsh;
logic signed [31:0] bias_lsh_32;

logic signed [31:0] elWise_prod [0:NUM_DIM-1];

logic [31:0] sum_A [10];
logic [31:0] sum_B [5];
logic [31:0] sum_C [3];
logic [31:0] sum_D;
logic [31:0] sum_E;

genvar i;

// ---------- Submodules ---------- //
shifter_left #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SHIFT(NUM_LSH_BIAS)
) shifter_left (
    .dIn(bias),
    .dOut(bias_lsh)
);

generate
    for (i = 0; i < 10; i = i + 1) begin: Stage_A
        CLA_32 CLA_A (
            .dIn_1(elWise_prod[2 * i]),
            .dIn_2(elWise_prod[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_A[i])
        );
    end

    for (i = 0; i < 5; i = i + 1) begin: Stage_B
        CLA_32 CLA_B (
            .dIn_1(sum_A[2 * i]),
            .dIn_2(sum_A[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_B[i])
        );
    end
endgenerate

// Stage_C
CLA_32 CLA_C0 (
    .dIn_1(sum_B[0]),
    .dIn_2(sum_B[1]),
    .carryIn(0),

    .dOut(sum_C[0])
);

CLA_32 CLA_C1 (
    .dIn_1(sum_B[2]),
    .dIn_2(sum_B[3]),
    .carryIn(0),

    .dOut(sum_C[1])
);

CLA_32 CLA_C2 (
    .dIn_1(sum_B[4]),
    .dIn_2(bias_lsh_32),
    .carryIn(0),

    .dOut(sum_C[2])
);

// Stage_D
CLA_32 CLA_D (
    .dIn_1(sum_C[0]),
    .dIn_2(sum_C[1]),
    .carryIn(0),

    .dOut(sum_D)
);

// Stage_E | Final Stage
CLA_32 CLA_E (
    .dIn_1(sum_C[2]),
    .dIn_2(sum_D),
    .carryIn(0),

    .dOut(sum_E)
);

// ---------- Main Code ---------- //
assign bias_lsh_32 = bias_lsh;

generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin
        assign elWise_prod[i] = weight[i] * dIn[i];
    end
endgenerate

assign dOut = sum_E[DATA_WIDTH_DOUT-1:0];

endmodule