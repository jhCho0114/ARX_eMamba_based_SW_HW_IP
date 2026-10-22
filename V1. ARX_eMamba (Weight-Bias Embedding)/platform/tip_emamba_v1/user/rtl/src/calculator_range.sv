`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 10:36:50 PM
// Design Name: 
// Module Name: calculator_range
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


module calculator_range #(
    parameter integer DATA_WIDTH = 13,
    parameter integer NUM_DIM    = 20
)(
    dIn,
    dIn_mean,
    dOut
);

// ---------- Inputs / Outputs ---------- //
input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] dIn_mean;

output logic [DATA_WIDTH-1:0] dOut; // Range

// ---------- Internal Variables ---------- //
logic signed [DATA_WIDTH-1:0] dIn_max_A [10];
logic signed [DATA_WIDTH-1:0] dIn_min_A [10];

logic signed [DATA_WIDTH-1:0] dIn_max_B [5];
logic signed [DATA_WIDTH-1:0] dIn_min_B [5];

logic signed [DATA_WIDTH-1:0] dIn_max_C [2];
logic signed [DATA_WIDTH-1:0] dIn_min_C [2];

logic signed [DATA_WIDTH-1:0] dIn_max_D;
logic signed [DATA_WIDTH-1:0] dIn_min_D;

logic signed [DATA_WIDTH-1:0] dIn_max;
logic signed [DATA_WIDTH-1:0] dIn_min;

// ---------- Submodules ---------- //
genvar i, j, k;
generate
    for (i = 0; i < 10; i = i + 1) begin: stage_A
        comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_A (
            .dIn_1(dIn[i*2] - dIn_mean),
            .dIn_2(dIn[i*2+1] - dIn_mean),

            .dOut_max(dIn_max_A[i]),
            .dOut_min(dIn_min_A[i])
        );
    end

    for (j = 0; j < 5; j = j + 1) begin: stage_B_max
        comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_B_max (
            .dIn_1(dIn_max_A[j*2]),
            .dIn_2(dIn_max_A[j*2+1]),

            .dOut_max(dIn_max_B[j]),
            .dOut_min()
        );
    end

    for (j = 0; j < 5; j = j + 1) begin: stage_B_min
        comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_B_min (
            .dIn_1(dIn_min_A[j*2]),
            .dIn_2(dIn_min_A[j*2+1]),

            .dOut_max(),
            .dOut_min(dIn_min_B[j])
        );
    end

    for (k = 0; k < 2; k = k + 1) begin: stage_C_max
        comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_C_max (
            .dIn_1(dIn_max_B[k*2]),
            .dIn_2(dIn_max_B[k*2+1]),

            .dOut_max(dIn_max_C[k]),
            .dOut_min()
        );
    end

    for (k = 0; k < 2; k = k + 1) begin: stage_C_min
        comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_C_min (
            .dIn_1(dIn_min_B[k*2]),
            .dIn_2(dIn_min_B[k*2+1]),

            .dOut_max(),
            .dOut_min(dIn_min_C[k])
        );
    end

    comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_D_max (
        .dIn_1(dIn_max_C[0]),
        .dIn_2(dIn_max_C[1]),

        .dOut_max(dIn_max_D),
        .dOut_min()
    );

    comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_D_min (
        .dIn_1(dIn_min_C[0]),
        .dIn_2(dIn_min_C[1]),

        .dOut_max(),
        .dOut_min(dIn_min_D)
    );

    comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_final_max (
        .dIn_1(dIn_max_D),
        .dIn_2(dIn_max_B[4]),

        .dOut_max(dIn_max),
        .dOut_min()
    );

    comparator #(.DATA_WIDTH(DATA_WIDTH)) comparator_final_min (
        .dIn_1(dIn_min_D),
        .dIn_2(dIn_min_B[4]),

        .dOut_max(),
        .dOut_min(dIn_min)
    );
endgenerate

assign dOut = dIn_max - dIn_min;

endmodule