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

    parameter integer DATA_WIDTH_XKP1 = 8,

    parameter integer COL_WIDTH = 1     // [J-ytree-tag] column 태그 폭 (부모 ED 카운터 폭)
)(
    clk,      // [J-Timing] Y1 (곱셈) 레지스터용
    nRst,     // [J-unopt-reset] prod_q/Du_q 리셋용
    ps_start, // [J-ytree-tag] 태그 valid 클리어 (부모 v_d* 와 같이)

    v_in,     // [J-ytree-tag] 입력 column valid
    col_in,   // [J-ytree-tag] 입력 column 번호
    dIn,      // Input u
    matrix_C, // Input matrix C
    matrix_D, // Input matrix D
    xkP1,     // Input x[k+1]

    v_out,    // [J-ytree-tag] dOut_8bit valid
    col_out,  // [J-ytree-tag] dOut_8bit 의 column 번호
    dOut_8bit // Output y
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_LSH_DU = NUM_SCALE_DELTA_A + NUM_SCALE_DELTA_B + NUM_SCALE_C - NUM_SCALE_D;
localparam integer NUM_RSH_DOUT = (NUM_SCALE_DIN + NUM_SCALE_DELTA_A + NUM_SCALE_DELTA_B + NUM_SCALE_C) - NUM_SCALE_DOUT;

localparam integer DATA_WIDTH_DU = DATA_WIDTH * 2; // 16-bit: matrix_D(8-bit) * dIn(8-bit)
localparam integer DATA_WIDTH_DU_LSH = DATA_WIDTH_DU + NUM_LSH_DU;

// [J] N=8 고정 +3 -> NUM_N에 따른 누적 비트 폭 ($clog2(NUM_N))
localparam integer N_SUM_WIDTH     = ($clog2(NUM_N) > 0) ? $clog2(NUM_N) : 1;
localparam integer DATA_WIDTH_CXKP1 = (DATA_WIDTH + DATA_WIDTH_XKP1) + N_SUM_WIDTH;

localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_CXKP1 + 1; // Cx[k+1] 의 비트가 Du shifted 된 것 보다 더 클 것
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// [J-Timing] Y2 덧셈 트리 (for 루프 직렬 누산 -> 2진 트리, 정수 덧셈이라 결과 동일)
localparam integer Y_STAGE = N_SUM_WIDTH;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk;                                          // [J-Timing]
input nRst;                                         // [J-unopt-reset]
input ps_start;                                     // [J-ytree-tag]

input logic                 v_in;                   // [J-ytree-tag]
input logic [COL_WIDTH-1:0] col_in;                 // [J-ytree-tag]
input logic signed [DATA_WIDTH-1:0] dIn;
input logic signed [DATA_WIDTH-1:0] matrix_C [0:NUM_N-1];
input logic signed [DATA_WIDTH-1:0] matrix_D;
input logic signed [DATA_WIDTH_XKP1-1:0] xkP1 [0:NUM_N-1];

output logic                 v_out;                 // [J-ytree-tag]
output logic [COL_WIDTH-1:0] col_out;               // [J-ytree-tag]
output logic signed [DATA_WIDTH-1:0] dOut_8bit;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_DU-1:0] Du;
logic signed [DATA_WIDTH_DU_LSH-1:0] Du_left_shifted;
logic signed [DATA_WIDTH_CXKP1-1:0] CxkP1;

// [J-Timing] Y1 레지스터. 곱셈 바로 뒤라 DSP48E2 PREG 로 흡수되게 리셋 없음.
//            (리포트: DSP_A_B_DATA_INST/CLK -> 곱셈 -> 8항 누산 -> +Du -> 반올림 -> 포화 -> dOut_reg 27 levels, slack -0.24)
// [J-ytree-ff] prod_q -> ytree[0] 로 직접 저장 (같은 배열에 assign 과 always 를 섞지 않게)
//              ytree[s] (s>=1) 도 전부 FF. ytree[s][k] = 레벨 s 의 k 번째 부분합
logic signed [DATA_WIDTH_CXKP1-1:0] ytree [0:Y_STAGE][0:NUM_N-1];

// [J-ytree-ff] Du_d[0] = Du_q (Y1), Du_d[s] = 트리 레벨 s 와 같은 cycle 의 Du
logic signed [DATA_WIDTH_DU-1:0]    Du_d  [0:Y_STAGE];

// [J-ytree-tag] v_t[s] / col_t[s] = ytree[s] 와 같은 cycle 에 있는 column 태그
logic                 v_t   [0:Y_STAGE];
logic [COL_WIDTH-1:0] col_t [0:Y_STAGE];

logic signed [DATA_WIDTH_DOUT-1:0] dOut;
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_right_shifted;


// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
shifter_left #(
    .DATA_WIDTH(DATA_WIDTH_DU),
    .NUM_SHIFT(NUM_LSH_DU)
) shifter_Du (
    .dIn(Du_d[Y_STAGE]),        // [J-ytree-ff] Du_q -> Du_d[Y_STAGE] (트리 출력과 정렬)
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
// y = C x+ xkP1 + D * u
always @(*) begin
    Du = matrix_D * dIn; // matrix_D[ed] * dIn[ed]
end

// [J] matrix_C[0]~[7] 하드코딩 -> NUM_N 루프 (N=16 등 확장할 수 있어,)
// [J-Timing] Y1: 곱셈 -> FF.  (기존: always @(*) CxkP1 = CxkP1 + matrix_C[i] * xkP1[i] 직렬 누산이 곱셈과 한 클럭)
genvar yn, ys, yk;
generate
    for (yn = 0; yn < NUM_N; yn = yn + 1) begin : Y1
        always @(posedge clk) begin                                          // [J-unopt-reset]
            if (!nRst) ytree[0][yn] <= #1 '0;                                // [J-ytree-ff] prod_q -> ytree[0]
            else       ytree[0][yn] <= #1 matrix_C[yn] * xkP1[yn];           // [J-ytree-ff] prod_q -> ytree[0]
        end                                                                  // [J-unopt-reset]
    end
endgenerate
always @(posedge clk) begin                                  // [J-unopt-reset] [J-Timing] Y1
    if (!nRst) Du_d[0] <= #1 '0;                             // [J-ytree-ff] Du_q -> Du_d[0]
    else       Du_d[0] <= #1 Du;                             // [J-ytree-ff] Du_q -> Du_d[0]
end                                                          // [J-unopt-reset]

// [J-Timing] Y2: 2진 덧셈 트리. 레벨 입력 개수가 홀수면 마지막 1 개는 짝이 없어 그대로 다음 레벨로 넘김 (pass-through)
// [J-ytree-ff] 트리의 모든 레벨 출력에 FF (덧셈 칸, pass-through 칸 모두). 레벨당 정확히 1 clk.
//              Du 도 레벨마다 FF 1 단씩 같이 밀어서 CxkP1 과 같은 cycle 에 더한다.
generate
    for (ys = 0; ys < Y_STAGE; ys = ys + 1) begin : Y2
        localparam integer N_IN = (NUM_N + (1 << ys) - 1) >> ys;
        for (yk = 0; yk < N_IN / 2; yk = yk + 1) begin : Add
            always @(posedge clk) begin                                                  // [J-ytree-ff]
                if (!nRst) ytree[ys+1][yk] <= #1 '0;                                     // [J-ytree-ff]
                else       ytree[ys+1][yk] <= #1 ytree[ys][2*yk] + ytree[ys][2*yk+1];    // [J-ytree-ff]
            end                                                                          // [J-ytree-ff]
        end
        if (N_IN % 2 == 1) begin : Pass
            always @(posedge clk) begin                                                  // [J-ytree-ff]
                if (!nRst) ytree[ys+1][N_IN/2] <= #1 '0;                                 // [J-ytree-ff]
                else       ytree[ys+1][N_IN/2] <= #1 ytree[ys][N_IN-1];                  // [J-ytree-ff]
            end                                                                          // [J-ytree-ff]
        end
        always @(posedge clk) begin                                                      // [J-ytree-ff] Du 정렬
            if (!nRst) Du_d[ys+1] <= #1 '0;                                              // [J-ytree-ff]
            else       Du_d[ys+1] <= #1 Du_d[ys];                                        // [J-ytree-ff]
        end                                                                              // [J-ytree-ff]
    end
endgenerate
assign CxkP1 = ytree[Y_STAGE][0];

always @(*) begin
    dOut = CxkP1 + Du_left_shifted;
end

// ========== [J-ytree-tag] column 태그: 데이터와 같은 단 (Y1 + 트리 레벨마다) ==========
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        for (int s = 0; s <= Y_STAGE; s++) begin
            v_t[s]   <= #1 1'b0;
            col_t[s] <= #1 '0;
        end
    end
    else begin
        v_t[0]   <= #1 v_in;                    // Y1 (ytree[0], Du_d[0] 와 같은 에지)
        col_t[0] <= #1 col_in;
        for (int s = 1; s <= Y_STAGE; s++) begin // 트리 레벨 s (ytree[s], Du_d[s] 와 같은 에지)
            v_t[s]   <= #1 v_t[s-1];
            col_t[s] <= #1 col_t[s-1];
        end
    end
end
assign v_out   = v_t[Y_STAGE];
assign col_out = col_t[Y_STAGE];

endmodule