`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2024 02:08:32 AM
// Design Name: 
// Module Name: Exp_piecewise_compute
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


module Exp_piecewise_compute #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_N      = 8,  // N(8)

    parameter integer NUM_SCALE_DIN  = 7,  // 2^N
    parameter integer NUM_SCALE_DOUT = 7
)(
    dIn,
    dOut_8bit
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DIN  = DATA_WIDTH * 2;
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_DIN * 2 + 1;

localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN * 2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

localparam integer VALUE_SCALE_DIN = 2 ** NUM_SCALE_DIN;
localparam integer VALUE_SCALE_DIN_SQUARE = VALUE_SCALE_DIN ** 2;

localparam integer VALUE_IF_1  = VALUE_SCALE_DIN * (-4.000);
localparam integer VALUE_IF_2  = VALUE_SCALE_DIN * (-3.513);
localparam integer VALUE_IF_3  = VALUE_SCALE_DIN * (-3.026);
localparam integer VALUE_IF_4  = VALUE_SCALE_DIN * (-2.539);
localparam integer VALUE_IF_5  = VALUE_SCALE_DIN * (-2.052);
localparam integer VALUE_IF_6  = VALUE_SCALE_DIN * (-1.565);
localparam integer VALUE_IF_7  = VALUE_SCALE_DIN * (-1.077);
localparam integer VALUE_IF_8  = VALUE_SCALE_DIN * (-0.590);
localparam integer VALUE_IF_9  = VALUE_SCALE_DIN * (-0.103);
localparam integer VALUE_IF_10 = VALUE_SCALE_DIN * (0.384);
localparam integer VALUE_IF_11 = VALUE_SCALE_DIN * (0.871);
localparam integer VALUE_IF_12 = VALUE_SCALE_DIN * (1.000);
// VALUE_IF_13 is else

localparam integer VALUE_MULT_1  = VALUE_SCALE_DIN * (0);
localparam integer VALUE_MULT_2  = VALUE_SCALE_DIN * (0.024);
localparam integer VALUE_MULT_3  = VALUE_SCALE_DIN * (0.038);
localparam integer VALUE_MULT_4  = VALUE_SCALE_DIN * (0.063);
localparam integer VALUE_MULT_5  = VALUE_SCALE_DIN * (0.102);
localparam integer VALUE_MULT_6  = VALUE_SCALE_DIN * (0.166);
localparam integer VALUE_MULT_7  = VALUE_SCALE_DIN * (0.270);
localparam integer VALUE_MULT_8  = VALUE_SCALE_DIN * (0.439);
localparam integer VALUE_MULT_9  = VALUE_SCALE_DIN * (0.714);
localparam integer VALUE_MULT_10 = VALUE_SCALE_DIN * (1.162);
localparam integer VALUE_MULT_11 = VALUE_SCALE_DIN * (1.891);
localparam integer VALUE_MULT_12 = VALUE_SCALE_DIN * (2.550);
localparam integer VALUE_MULT_13 = VALUE_SCALE_DIN * (2.718);

localparam integer VALUE_ADD_1  = VALUE_SCALE_DIN_SQUARE * (0);
localparam integer VALUE_ADD_2  = VALUE_SCALE_DIN_SQUARE * (0.113);
localparam integer VALUE_ADD_3  = VALUE_SCALE_DIN_SQUARE * (0.165);
localparam integer VALUE_ADD_4  = VALUE_SCALE_DIN_SQUARE * (0.238);
localparam integer VALUE_ADD_5  = VALUE_SCALE_DIN_SQUARE * (0.337);
localparam integer VALUE_ADD_6  = VALUE_SCALE_DIN_SQUARE * (0.468);
localparam integer VALUE_ADD_7  = VALUE_SCALE_DIN_SQUARE * (0.631);
localparam integer VALUE_ADD_8  = VALUE_SCALE_DIN_SQUARE * (0.813);
localparam integer VALUE_ADD_9  = VALUE_SCALE_DIN_SQUARE * (0.976);
localparam integer VALUE_ADD_10 = VALUE_SCALE_DIN_SQUARE * (1.022);
localparam integer VALUE_ADD_11 = VALUE_SCALE_DIN_SQUARE * (0.742);
localparam integer VALUE_ADD_12 = VALUE_SCALE_DIN_SQUARE * (0.16);
localparam integer VALUE_ADD_13 = VALUE_SCALE_DIN_SQUARE * (0);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH_DIN-1:0] dIn [0:NUM_N-1];

output logic signed [DATA_WIDTH-1:0] dOut_8bit [0:NUM_N-1];

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_DOUT-1:0] dOut [0:NUM_N-1];
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_right_shifted [0:NUM_N-1];

genvar n;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_N; n = n + 1) begin : dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(dOut[n]),
            .dOut(dOut_right_shifted[n])
        );
    end

    for (n = 0; n < NUM_N; n = n + 1) begin : dOut_saturation
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator_dOut (
            .dIn(dOut_right_shifted[n]),
            .dOut(dOut_8bit[n])
        );
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_N; n = n + 1) begin : pExp_computation
        always @(*) begin
            if (dIn[n] < VALUE_IF_1)
                dOut[n] = 0;

            else if (dIn[n] <= VALUE_IF_2)
                dOut[n] = VALUE_MULT_2 * dIn[n] + VALUE_ADD_2;

            else if (dIn[n] <= VALUE_IF_3)
                dOut[n] = VALUE_MULT_3 * dIn[n] + VALUE_ADD_3;

            else if (dIn[n] <= VALUE_IF_4)
                dOut[n] = VALUE_MULT_4 * dIn[n] + VALUE_ADD_4;

            else if (dIn[n] <= VALUE_IF_5)
                dOut[n] = VALUE_MULT_5 * dIn[n] + VALUE_ADD_5;

            else if (dIn[n] <= VALUE_IF_6)
                dOut[n] = VALUE_MULT_6 * dIn[n] + VALUE_ADD_6;

            else if (dIn[n] <= VALUE_IF_7)
                dOut[n] = VALUE_MULT_7 * dIn[n] + VALUE_ADD_7;

            else if (dIn[n] <= VALUE_IF_8)
                dOut[n] = VALUE_MULT_8 * dIn[n] + VALUE_ADD_8;

            else if (dIn[n] <= VALUE_IF_9)
                dOut[n] = VALUE_MULT_9 * dIn[n] + VALUE_ADD_9;

            else if (dIn[n] <= VALUE_IF_10)
                dOut[n] = VALUE_MULT_10 * dIn[n] + VALUE_ADD_10;

            else if (dIn[n] <= VALUE_IF_11)
                dOut[n] = VALUE_MULT_11 * dIn[n] + VALUE_ADD_11;

            else if (dIn[n] <= VALUE_IF_12)
                dOut[n] = VALUE_MULT_12 * dIn[n] + VALUE_ADD_12;

            else
                dOut[n] = VALUE_MULT_13;
        end
    end
endgenerate

endmodule