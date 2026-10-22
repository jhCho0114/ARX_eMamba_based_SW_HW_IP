`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 10:36:50 PM
// Design Name: 
// Module Name: calculator_mean
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


// module calculator_mean #(
//     parameter integer DATA_WIDTH = 13,
//     parameter integer NUM_DIM    = 20
// )(
//     clk,
//     nRst,

//     dIn,
//     dOut
// );

// // ---------- Inputs / Outputs ---------- //
// input clk, nRst;

// input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];

// output logic signed [DATA_WIDTH-1:0] dOut;

// // ---------- Main Code ---------- //
// always @(posedge clk) begin
//     if (!nRst)
//         dOut <= #1 0;
//     else
//         dOut <= #1 (dIn[0]  +
//                     dIn[1]  +
//                     dIn[2]  +
//                     dIn[3]  +
//                     dIn[4]  +
//                     dIn[5]  +
//                     dIn[6]  +
//                     dIn[7]  +
//                     dIn[8]  +
//                     dIn[9]  +
//                     dIn[10] +
//                     dIn[11] +
//                     dIn[12] +
//                     dIn[13] +
//                     dIn[14] +
//                     dIn[15] +
//                     dIn[16] +
//                     dIn[17] +
//                     dIn[18] +
//                     dIn[19]) / NUM_DIM;
// end

// endmodule


module calculator_mean #(
    parameter integer DATA_WIDTH = 13,
    parameter integer NUM_DIM    = 20
)(
    clk,
    nRst,

    dIn,
    dOut
);

// Local Parameters //
// 4 < 2log20 < 5
localparam DATA_WIDTH_SUM = DATA_WIDTH + 5;

// ---------- Inputs / Outputs ---------- //
input clk, nRst;

input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];

output logic signed [DATA_WIDTH-1:0] dOut;

// ---------- Internal Variables ---------- //
logic signed [31:0] dIn_32 [NUM_DIM];

logic [31:0] sum_A [10];
logic [31:0] sum_B [5];
logic [31:0] sum_C [2];
logic [31:0] sum_D;
logic [31:0] sum_E;

logic signed [DATA_WIDTH_SUM-1:0] sum_sliced;

genvar i;

// ---------- Submodules ---------- //
generate
    for (i = 0; i < 10; i = i + 1) begin: Stage_A
        CLA_32 CLA_A (
            .dIn_1(dIn_32[2 * i]),
            .dIn_2(dIn_32[2 * i + 1]),
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

    for (i = 0; i < 2; i = i + 1) begin: Stage_C
        CLA_32 CLA_C (
            .dIn_1(sum_B[2 * i]),
            .dIn_2(sum_B[2 * i + 1]),
            .carryIn(0),

            .dOut(sum_C[i])
        );
    end
endgenerate

// Stage_D
CLA_32 CLA_D (
    .dIn_1(sum_C[0]),
    .dIn_2(sum_C[1]),
    .carryIn(0),

    .dOut(sum_D)
);

// Stage_E | Final Stage
CLA_32 CLA_E (
    .dIn_1(sum_B[4]),
    .dIn_2(sum_D),
    .carryIn(0),

    .dOut(sum_E)
);

// ---------- Main Code ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin
        assign dIn_32[i] = dIn[i];
    end
endgenerate

assign sum_sliced = sum_E[DATA_WIDTH_SUM-1:0];

always @(posedge clk) begin
    dOut <= #1 sum_sliced / NUM_DIM;
end

endmodule


// module calculator_mean #(
//     parameter integer DATA_WIDTH = 13,
//     parameter integer NUM_DIM    = 20
// )(
//     dIn,
//     dOut
// );

// // Local Parameters //
// // 4 < 2log20 < 5
// localparam DATA_WIDTH_SUM = DATA_WIDTH + 5;

// // ---------- Inputs / Outputs ---------- //
// input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];

// output logic signed [DATA_WIDTH-1:0] dOut;

// // ---------- Internal Variables ---------- //
// logic signed [31:0] dIn_32 [NUM_DIM];

// logic [31:0] sum_A [10];
// logic [31:0] sum_B [5];
// logic [31:0] sum_C [2];
// logic [31:0] sum_D;
// logic [31:0] sum_E;

// logic signed [DATA_WIDTH_SUM-1:0] sum_sliced;

// genvar i;

// // ---------- Submodules ---------- //
// generate
//     for (i = 0; i < 10; i = i + 1) begin: Stage_A
//         CLA_32 CLA_A (
//             .dIn_1(dIn_32[2 * i]),
//             .dIn_2(dIn_32[2 * i + 1]),
//             .carryIn(0),

//             .dOut(sum_A[i])
//         );
//     end

//     for (i = 0; i < 5; i = i + 1) begin: Stage_B
//         CLA_32 CLA_B (
//             .dIn_1(sum_A[2 * i]),
//             .dIn_2(sum_A[2 * i + 1]),
//             .carryIn(0),

//             .dOut(sum_B[i])
//         );
//     end

//     for (i = 0; i < 2; i = i + 1) begin: Stage_C
//         CLA_32 CLA_C (
//             .dIn_1(sum_B[2 * i]),
//             .dIn_2(sum_B[2 * i + 1]),
//             .carryIn(0),

//             .dOut(sum_C[i])
//         );
//     end
// endgenerate

// // Stage_D
// CLA_32 CLA_D (
//     .dIn_1(sum_C[0]),
//     .dIn_2(sum_C[1]),
//     .carryIn(0),

//     .dOut(sum_D)
// );

// // Stage_E | Final Stage
// CLA_32 CLA_E (
//     .dIn_1(sum_B[4]),
//     .dIn_2(sum_D),
//     .carryIn(0),

//     .dOut(sum_E)
// );

// // ---------- Main Code ---------- //
// generate
//     for (i = 0; i < NUM_DIM; i = i + 1) begin
//         assign dIn_32[i] = dIn[i];
//     end
// endgenerate

// assign sum_sliced = sum_E[DATA_WIDTH_SUM-1:0];
// assign dOut = sum_sliced / NUM_DIM;

// endmodule