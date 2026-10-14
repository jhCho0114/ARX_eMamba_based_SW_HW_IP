`timescale 1ns / 1ps


module MatMult_Dynamic #(
    parameter integer DATA_WIDTH       = 8,
    parameter integer NUM_DIM          = 20,   // 내적 차원
    parameter bit     USE_BIAS         = 1'b1, // 마지막 곱에 bias 를 더할지말지
    parameter integer NUM_SCALE_DIN    = 6,
    parameter integer NUM_SCALE_WEIGHT = 7,
    parameter integer NUM_SCALE_BIAS   = 8,

    parameter integer COL_WIDTH        = 1     // [J-mm-tag] column 태그 폭 (부모 열 카운터 폭)
)(
    clk,
    nRst,     // [J-unopt-reset] 모든 FF 동기 리셋
    ps_start, // [J-mm-tag] 태그 valid 클리어

    v_in,     // [J-mm-tag] 입력 열 valid
    col_in,   // [J-mm-tag] 입력 열 번호
    dIn,
    weight,
    bias,

    v_out,    // [J-mm-tag] dOut valid
    col_out,  // [J-mm-tag] dOut 의 열 번호
    dOut
);

// [J] Parameters
localparam integer NUM_ACC   = USE_BIAS ? NUM_DIM + 1 : NUM_DIM;  // [J-mm-bias] 누산 항 수 (폭 계산용, 기존 NUM_ELEM 과 같은 값)
localparam integer NUM_STAGE = $clog2(NUM_DIM);                   // [J-mm-bias] 트리 leaf 는 NUM_DIM 개

// bias 스케일 정렬 방향
localparam integer NUM_LSH_BIAS = (NUM_SCALE_DIN + NUM_SCALE_WEIGHT) - NUM_SCALE_BIAS;
localparam integer NUM_LSH_DIN  = NUM_SCALE_BIAS - (NUM_SCALE_DIN + NUM_SCALE_WEIGHT);
localparam bit     DIN_UPSCALE  = USE_BIAS && (NUM_LSH_BIAS < 0);

localparam integer DATA_WIDTH_BIAS_LSH = DATA_WIDTH + ((USE_BIAS && !DIN_UPSCALE) ? NUM_LSH_BIAS : 0);
localparam integer DATA_WIDTH_DIN_LSH  = DATA_WIDTH + (DIN_UPSCALE ? NUM_LSH_DIN : 0);

// 누산 결과의 실제 유효 폭 (accumulation result effective width)
localparam integer DATA_WIDTH_SUM = DATA_WIDTH_DIN_LSH + DATA_WIDTH + $clog2(NUM_ACC);

// [J] Inputs / Outputs
input clk;
input nRst;                                                  // [J-unopt-reset]
input ps_start;                                              // [J-mm-tag]

input logic                 v_in;                            // [J-mm-tag]
input logic [COL_WIDTH-1:0] col_in;                          // [J-mm-tag]
input logic signed [DATA_WIDTH-1:0] dIn    [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] bias;   // USE_BIAS=0이면 미사용

output logic                 v_out;                          // [J-mm-tag]
output logic [COL_WIDTH-1:0] col_out;                        // [J-mm-tag]
output logic signed [DATA_WIDTH_SUM-1:0] dOut;

// [J] Internal Variables
logic signed [DATA_WIDTH_DIN_LSH-1:0]  dIn_x  [0:NUM_DIM-1]; // 곱셈에 들어가는 dIn (DIN_UPSCALE 이면 shift)
logic signed [DATA_WIDTH_BIAS_LSH-1:0] bias_x;               // 마지막 곱에 더하는 bias (DIN_UPSCALE 아니면 shift)

// [J-mm-ff] tree[s][k] = stage s 의 k 번째 값 (전부 FF). tree[0] = leaf FF (곱셈 결과)
//           sum[s][k]  = stage s 의 CLA 조합 출력 -> 다음 클럭 tree[s+1][k]
logic signed [31:0] tree [0:NUM_STAGE][0:NUM_DIM-1];
logic signed [31:0] sum  [0:NUM_STAGE][0:NUM_DIM-1];

// [J-mm-tag] v_t[s] / col_t[s] = tree[s] 와 같은 cycle 에 있는 열 태그
logic                 v_t   [0:NUM_STAGE];
logic [COL_WIDTH-1:0] col_t [0:NUM_STAGE];

genvar s, k, i;

// [J] Scale align
generate
    if (DIN_UPSCALE) begin: DIn_UpScaling
        // bias 스케일이 곱 스케일보다 클 때: dIn을 왼쪽 시프트, bias 는 그대로
        for (i = 0; i < NUM_DIM; i = i + 1) begin: Sh
            shifter_left #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_SHIFT(NUM_LSH_DIN)
            ) shifter_dIn (
                .dIn(dIn[i]),
                .dOut(dIn_x[i])
            );
        end
        assign bias_x = bias;
    end else begin: DIn_Direct
        for (i = 0; i < NUM_DIM; i = i + 1) begin: Dr
            assign dIn_x[i] = dIn[i];
        end
        if (USE_BIAS) begin: Bias_Shift
            shifter_left #(
                .DATA_WIDTH(DATA_WIDTH),
                .NUM_SHIFT(NUM_LSH_BIAS)
            ) shifter_bias (
                .dIn(bias),
                .dOut(bias_x)
            );
        end else begin: Bias_Tie
            assign bias_x = '0;
        end
    end
endgenerate

// [J-mm-ff] L : 곱셈 -> leaf FF.   [J-mm-bias] 마지막 곱에만 bias 를 더함 (DSP A×B+C)
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin: Leaf
        if (USE_BIAS && (i == NUM_DIM-1)) begin: MulAdd
            always @(posedge clk) begin
                if (!nRst) tree[0][i] <= #1 '0;                                  // [J-unopt-reset]
                else       tree[0][i] <= #1 weight[i] * dIn_x[i] + bias_x;       // [J-mm-bias]
            end
        end else begin: Mul
            always @(posedge clk) begin
                if (!nRst) tree[0][i] <= #1 '0;                                  // [J-unopt-reset]
                else       tree[0][i] <= #1 weight[i] * dIn_x[i];
            end
        end
    end
endgenerate

// [J-mm-ff] T : CLA 트리, stage 마다 FF. 입력 개수가 홀수면 마지막 1 개는 짝 없이 FF 만 통과 (pass-through)
generate
    for (s = 0; s < NUM_STAGE; s = s + 1) begin: Stage
        localparam integer N_IN = (NUM_DIM + (1 << s) - 1) >> s;   // ceil(NUM_DIM / 2^s)

        for (k = 0; k < N_IN / 2; k = k + 1) begin: Add
            CLA_32 CLA (
                .dIn_1(tree[s][2 * k]),
                .dIn_2(tree[s][2 * k + 1]),
                .carryIn(1'b0),

                .dOut(sum[s][k]),
                .carryOut()
            );

            always @(posedge clk) begin
                if (!nRst) tree[s + 1][k] <= #1 '0;                              // [J-unopt-reset]
                else       tree[s + 1][k] <= #1 sum[s][k];
            end
        end

        if (N_IN % 2 == 1) begin: Pass
            always @(posedge clk) begin
                if (!nRst) tree[s + 1][N_IN / 2] <= #1 '0;                       // [J-unopt-reset]
                else       tree[s + 1][N_IN / 2] <= #1 tree[s][N_IN - 1];
            end
        end
    end
endgenerate

// [J-mm-tag] 열 태그: 데이터와 같은 단 (leaf + 트리 stage 마다)
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        for (int t = 0; t <= NUM_STAGE; t++) begin
            v_t[t]   <= #1 1'b0;
            col_t[t] <= #1 '0;
        end
    end
    else begin
        v_t[0]   <= #1 v_in;                     // L (tree[0] 와 같은 에지)
        col_t[0] <= #1 col_in;
        for (int t = 1; t <= NUM_STAGE; t++) begin // T{t} (tree[t] 와 같은 에지)
            v_t[t]   <= #1 v_t[t-1];
            col_t[t] <= #1 col_t[t-1];
        end
    end
end

// [J] Output
assign dOut    = tree[NUM_STAGE][0][DATA_WIDTH_SUM-1:0];
assign v_out   = v_t[NUM_STAGE];
assign col_out = col_t[NUM_STAGE];

endmodule
