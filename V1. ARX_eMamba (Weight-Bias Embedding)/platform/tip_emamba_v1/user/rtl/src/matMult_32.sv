`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/07/2024 05:55:16 PM
// Design Name: 
// Module Name: matMult_32
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


module matMult_32 #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SCALE_DIN    = 6,
    parameter integer NUM_SCALE_WEIGHT = 8,
    parameter integer NUM_SCALE_BIAS   = 8
)(
    dIn,
    weight,
    bias,

    dOut
);

// ---------- Parameters ---------- //
localparam integer NUM_DIM = 32;
localparam integer NUM_LSH_BIAS = NUM_SCALE_DIN + NUM_SCALE_WEIGHT - NUM_SCALE_BIAS;
localparam integer DATA_WIDTH_BIAS_LSH = DATA_WIDTH + NUM_LSH_BIAS;

// 4 < log2 32 = 5
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

logic [31:0] sum_A [16];
logic [31:0] sum_B [8];
logic [31:0] sum_C [4];
logic [31:0] sum_D [2];
logic [31:0] sum_E;
logic [31:0] sum_F;

genvar i;

// ---------- Submodules ---------- //
shifter_left #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SHIFT(NUM_LSH_BIAS)
) shifter_left (
    .dIn(bias),
    .dOut(bias_lsh)
);

// 여기부터 만들어야함
generate
    for (i = 0; i < 16; i = i + 1) begin: Stage_A
        CLA_32 CLA_A (
            .dIn_1(elWise_prod[2 * i]),
            .dIn_2(elWise_prod[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_A[i])
        );
    end

    for (i = 0; i < 8; i = i + 1) begin: Stage_B
        CLA_32 CLA_B (
            .dIn_1(sum_A[2 * i]),
            .dIn_2(sum_A[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_B[i])
        );
    end

    for (i = 0; i < 4; i = i + 1) begin: Stage_C
        CLA_32 CLA_C (
            .dIn_1(sum_B[2 * i]),
            .dIn_2(sum_B[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_C[i])
        );
    end

    for (i = 0; i < 2; i = i + 1) begin: Stage_D
        CLA_32 CLA_D (
            .dIn_1(sum_C[2 * i]),
            .dIn_2(sum_C[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_D[i])
        );
    end
endgenerate

// Stage_E
CLA_32 CLA_E (
    .dIn_1(sum_D[0]),
    .dIn_2(sum_D[1]),
    .carryIn(0),

    .dOut(sum_E)
);

// Stage_F | Final Stage
CLA_32 CLA_F (
    .dIn_1(sum_E),
    .dIn_2(bias_lsh_32),
    .carryIn(0),

    .dOut(sum_F)
);

// ---------- Main Code ---------- //
assign bias_lsh_32 = bias_lsh;

generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin
        assign elWise_prod[i] = weight[i] * dIn[i];
    end
endgenerate

assign dOut = sum_F[DATA_WIDTH_DOUT-1:0];

endmodule