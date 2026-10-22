`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 04:50:21 PM
// Design Name: 
// Module Name: SSM_y_compute
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


module SSM_y_compute #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_N      = 8,

    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_C       = 5,
    parameter integer NUM_SCALE_D       = 6,
    parameter integer NUM_SCALE_DOUT    = 3,

    parameter integer DATA_WIDTH_XKP1 = 8
)(
    dIn,      // Input u
    matrix_C, // Input matrix C
    matrix_D, // Input matrix D
    xkP1,     // Input x[k+1]

    dOut_8bit // Output y
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_LSH_DU = NUM_SCALE_DELTA_A + NUM_SCALE_DELTA_B + NUM_SCALE_C - NUM_SCALE_D;
localparam integer NUM_RSH_DOUT = (NUM_SCALE_DIN + NUM_SCALE_DELTA_A + NUM_SCALE_DELTA_B + NUM_SCALE_C) - NUM_SCALE_DOUT;

localparam integer DATA_WIDTH_DU = DATA_WIDTH * 2; // 16-bit: matrix_D(8-bit) * dIn(8-bit)
localparam integer DATA_WIDTH_DU_LSH = DATA_WIDTH_DU + NUM_LSH_DU;
localparam integer DATA_WIDTH_CXKP1 = (DATA_WIDTH + DATA_WIDTH_XKP1) + 3; // 8-bit + xkP1-bit + 2log 7 < 3

localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_CXKP1 + 1; // Cx[k+1] 의 비트가 Du shifted 된 것 보다 더 클 것
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] dIn;
input logic signed [DATA_WIDTH-1:0] matrix_C [0:NUM_N-1];
input logic signed [DATA_WIDTH-1:0] matrix_D;
input logic signed [DATA_WIDTH_XKP1-1:0] xkP1 [0:NUM_N-1];

output logic signed [DATA_WIDTH-1:0] dOut_8bit;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_DU-1:0] Du;
logic signed [DATA_WIDTH_DU_LSH-1:0] Du_left_shifted;
logic signed [DATA_WIDTH_CXKP1-1:0] CxkP1;

logic signed [DATA_WIDTH_DOUT-1:0] dOut;
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_right_shifted;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
shifter_left #(
    .DATA_WIDTH(DATA_WIDTH_DU),
    .NUM_SHIFT(NUM_LSH_DU)
) shifter_Du (
    .dIn(Du),
    .dOut(Du_left_shifted)
);

shifter_right #(
    .DATA_WIDTH(DATA_WIDTH_DOUT),
    .NUM_SHIFT(NUM_RSH_DOUT)
) shifter_dOut (
    .dIn(dOut),
    .dOut(dOut_right_shifted)
);

saturator #(
    .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
) saturator_dOut (
    .dIn(dOut_right_shifted),
    .dOut(dOut_8bit)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// y = C @ xkP1 + D * u
always @(*) begin
    Du = matrix_D * dIn; // matrix_D[ed] * dIn[ed]
end

always @(*) begin
    CxkP1 = matrix_C[0] * xkP1[0] +
            matrix_C[1] * xkP1[1] +
            matrix_C[2] * xkP1[2] +
            matrix_C[3] * xkP1[3] +
            matrix_C[4] * xkP1[4] +
            matrix_C[5] * xkP1[5] +
            matrix_C[6] * xkP1[6] +
            matrix_C[7] * xkP1[7] ;
end

always @(*) begin
    dOut = CxkP1 + Du_left_shifted;
end

endmodule