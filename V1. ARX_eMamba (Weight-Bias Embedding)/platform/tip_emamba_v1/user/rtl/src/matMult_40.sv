`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 12:57:58 PM
// Design Name: 
// Module Name: matMult_40
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


module matMult_40 #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SCALE_DIN    = 5,
    parameter integer NUM_SCALE_WEIGHT = 8,
    parameter integer NUM_SCALE_BIAS   = 9,
    parameter integer NUM_SCALE_DOUT   = 8
)(
    dIn,
    weight,
    bias,

    dOut
);

// ---------- Parameters ---------- //
localparam integer NUM_DIM = 40;

localparam integer NUM_LSH_BIAS = (NUM_SCALE_DIN + NUM_SCALE_WEIGHT) - NUM_SCALE_BIAS;
localparam integer DATA_WIDTH_BIAS_LSH = DATA_WIDTH + NUM_LSH_BIAS;

localparam integer NUM_RSH_DOUT = (NUM_SCALE_DIN + NUM_SCALE_WEIGHT) - NUM_SCALE_DOUT;

// 5 < log2 40 < 6
localparam DATA_WIDTH_DOUT_RSH = DATA_WIDTH * 2 + 6;

// ---------- Inputs / Outputs ---------- //
input logic signed [DATA_WIDTH-1:0] dIn    [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] bias;

output logic signed [DATA_WIDTH-1:0] dOut;

// ---------- Internal Variables ---------- //
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_temp;

logic signed [DATA_WIDTH_BIAS_LSH-1:0] bias_lsh;
logic signed [31:0] bias_lsh_32;

logic signed [31:0] elWise_prod [0:NUM_DIM-1];

logic [31:0] sum_A [20];
logic [31:0] sum_B [10];
logic [31:0] sum_C [5];
logic [31:0] sum_D [3];
logic [31:0] sum_E;
logic [31:0] sum_F;

genvar i;

// ---------- Submodules ---------- //
shifter_left #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SHIFT(NUM_LSH_BIAS)
) shifter_bias (
    .dIn(bias),
    .dOut(bias_lsh)
);

activator #(
    .DATA_WIDTH(DATA_WIDTH_DOUT_RSH),
    .NUM_RSH_DOUT(NUM_RSH_DOUT)
) activator_dOut (
    .dIn(dOut_temp),
    .dOut(dOut)
);

generate
    for (i = 0; i < 20; i = i + 1) begin: Stage_A
        CLA_32 CLA_A (
            .dIn_1(elWise_prod[2 * i]),
            .dIn_2(elWise_prod[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_A[i])
        );
    end

    for (i = 0; i < 10; i = i + 1) begin: Stage_B
        CLA_32 CLA_B (
            .dIn_1(sum_A[2 * i]),
            .dIn_2(sum_A[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_B[i])
        );
    end

    for (i = 0; i < 5; i = i + 1) begin: Stage_C
        CLA_32 CLA_C (
            .dIn_1(sum_B[2 * i]),
            .dIn_2(sum_B[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_C[i])
        );
    end
endgenerate

// Stage_D
CLA_32 CLA_D0 (
    .dIn_1(sum_C[0]),
    .dIn_2(sum_C[1]),
    .carryIn(0),

    .dOut(sum_D[0])
);

CLA_32 CLA_D1 (
    .dIn_1(sum_C[2]),
    .dIn_2(sum_C[3]),
    .carryIn(0),

    .dOut(sum_D[1])
);

CLA_32 CLA_D2 (
    .dIn_1(sum_C[4]),
    .dIn_2(bias_lsh_32),
    .carryIn(0),

    .dOut(sum_D[2])
);

// Stage_E
CLA_32 CLA_E (
    .dIn_1(sum_D[0]),
    .dIn_2(sum_D[1]),
    .carryIn(0),

    .dOut(sum_E)
);

// Stage_F | Final Stage
CLA_32 CLA_F (
    .dIn_1(sum_D[2]),
    .dIn_2(sum_E),
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

assign dOut_temp = sum_F[DATA_WIDTH_DOUT_RSH-1:0];

endmodule