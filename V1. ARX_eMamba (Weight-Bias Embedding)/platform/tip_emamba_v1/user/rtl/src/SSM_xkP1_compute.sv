`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 05:06:27 PM
// Design Name: 
// Module Name: SSM_xkP1_compute
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


module SSM_xkP1_compute #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_N      = 8,

    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_DOUT    = 4,

    parameter integer DATA_WIDTH_BU       = DATA_WIDTH * 2,
    parameter integer DATA_WIDTH_BU_LSH   = DATA_WIDTH_BU + NUM_SCALE_DELTA_A,
    parameter integer DATA_WIDTH_AX       = DATA_WIDTH_BU_LSH,
    parameter integer DATA_WIDTH_XKP1     = DATA_WIDTH_AX + 1,
    parameter integer DATA_WIDTH_XKP1_RSH = DATA_WIDTH_XKP1 - NUM_SCALE_DELTA_A
)(
    dIn,     // Input u
    delta_A, // Input delta A
    delta_B, // Input delta B
    xk,      // Input x[k]

    xkP1,               // Output x[k+1]
    xkP1_right_shifted  // Output x[k+1] down scaled
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH-1:0] dIn;
input logic signed [DATA_WIDTH-1:0] delta_A [0:NUM_N-1];
input logic signed [DATA_WIDTH-1:0] delta_B [0:NUM_N-1];
input logic signed [DATA_WIDTH_XKP1_RSH-1:0] xk [0:NUM_N-1];

output logic signed [DATA_WIDTH_XKP1-1:0] xkP1 [0:NUM_N-1];
output logic signed [DATA_WIDTH_XKP1_RSH-1:0] xkP1_right_shifted [0:NUM_N-1];

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_BU-1:0]     Bu              [0:NUM_N-1];
logic signed [DATA_WIDTH_BU_LSH-1:0] Bu_left_shifted [0:NUM_N-1];

logic signed [DATA_WIDTH_AX-1:0] Ax [0:NUM_N-1];

genvar n;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_N; n = n + 1) begin : Bu_upScaling
        shifter_left #(
            .DATA_WIDTH(DATA_WIDTH_BU),
            .NUM_SHIFT(NUM_SCALE_DELTA_A)
        ) shifter_Bu (
            .dIn(Bu[n]),
            .dOut(Bu_left_shifted[n])
        );
    end

    for (n = 0; n < NUM_N; n = n + 1) begin : xKP1_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_XKP1),
            .NUM_SHIFT(NUM_SCALE_DELTA_A)
        ) shifter_xkP1 (
            .dIn(xkP1[n]),
            .dOut(xkP1_right_shifted[n])
        );
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_N; n = n + 1) begin : xkP1_computation
        always @(*) begin
            Ax[n] = delta_A[n] * xk[n]; // Ax[n] = delta_A[n] * xk[n]
            Bu[n] = delta_B[n] * dIn;   // Bu[n] = delta_B[n] * dIn[ed]
            xkP1[n] = Ax[n] + Bu_left_shifted[n]; // x[k+1] = Ax[n] + Bu_scale_fitted[n]
        end
    end
endgenerate

endmodule