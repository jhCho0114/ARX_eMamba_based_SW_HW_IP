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
    clk,     // [J-Timing] A1 (곱셈) 레지스터용
    nRst,    // [J-unopt-reset] Ax_q/Bu_q 리셋용
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
input clk;                                         // [J-Timing]
input nRst;                                        // [J-unopt-reset]
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

// [J-Timing] A1 레지스터. 곱셈 바로 뒤라 DSP48E2 PREG 로 흡수되게 리셋 없음.
// [J-unopt-reset] 위 "리셋 없음" 은 va_1_unoptimized_reset 에서 해제 — 모든 posedge clk FF 에 nRst 동기 리셋 (DSP PREG 흡수 안 될 수 있음)
//            column 은 토큰당 한 번만 읽고 쓰므로 xk 쓰기가 1 cycle 늦어도 의존 안 깨짐 (U_SSM_Computation 참고)
logic signed [DATA_WIDTH_AX-1:0] Ax_q [0:NUM_N-1];
logic signed [DATA_WIDTH_BU-1:0] Bu_q [0:NUM_N-1];

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
            .dIn(Bu_q[n]),              // [J-Timing] Bu -> Bu_q
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
        end

        // [J-Timing] A1: mux -> DSP 곱셈 -> FF   (기존: mux -> 곱셈 -> 덧셈 -> 반올림 -> xk 쓰기 한 클럭)
        always @(posedge clk) begin
            if (!nRst) begin                                  // [J-unopt-reset]
                Ax_q[n] <= #1 '0;                             // [J-unopt-reset]
                Bu_q[n] <= #1 '0;                             // [J-unopt-reset]
            end else begin                                    // [J-unopt-reset]
            Ax_q[n] <= #1 Ax[n];
            Bu_q[n] <= #1 Bu[n];
            end                                               // [J-unopt-reset]
        end

        // [J-Timing] A2: 덧셈 -> (shifter_right 반올림) -> xk_ssm_state / xkP1_d2
        always @(*) begin
            xkP1[n] = Ax_q[n] + Bu_left_shifted[n]; // x[k+1] = Ax[n] + Bu_scale_fitted[n]
        end
    end
endgenerate

endmodule