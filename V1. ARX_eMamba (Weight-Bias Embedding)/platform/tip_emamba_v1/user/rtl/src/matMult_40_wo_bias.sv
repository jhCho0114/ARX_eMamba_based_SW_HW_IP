`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/07/2024 06:23:35 PM
// Design Name: 
// Module Name: matMult_40_wo_bias
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


module matMult_40_wo_bias #(
    parameter integer DATA_WIDTH = 8
)(
    dIn,
    weight,

    dOut
);

// ---------- Parameters ---------- //
localparam integer NUM_DIM = 40;

// 5 < log2 39 < 6
localparam DATA_WIDTH_DOUT = DATA_WIDTH * 2 + 6;

// ---------- Inputs / Outputs ---------- //
input logic signed [DATA_WIDTH-1:0] dIn    [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1];

output logic signed [DATA_WIDTH_DOUT-1:0] dOut;

// ---------- Internal Variables ---------- //
logic signed [31:0] elWise_prod [0:NUM_DIM-1];

logic [31:0] sum_A [20];
logic [31:0] sum_B [10];
logic [31:0] sum_C [5];
logic [31:0] sum_D [2];
logic [31:0] sum_E;
logic [31:0] sum_F;

genvar i;

// ---------- Submodules ---------- //
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
    .dIn_1(sum_C[4]),
    .dIn_2(sum_E),
    .carryIn(0),

    .dOut(sum_F)
);

// ---------- Main Code ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin
        assign elWise_prod[i] = weight[i] * dIn[i];
    end
endgenerate

assign dOut = sum_F[DATA_WIDTH_DOUT-1:0];

endmodule