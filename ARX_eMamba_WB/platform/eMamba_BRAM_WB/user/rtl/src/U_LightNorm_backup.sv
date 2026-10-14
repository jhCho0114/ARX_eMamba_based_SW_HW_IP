`timescale 1ns / 1ps

module U_LightNorm #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_SEQLEN  = 197,
    parameter integer NUM_DIM     = 192,

    parameter integer NUM_PARALLEL = 10,

    parameter integer NUM_SCALE_DIN    = 5,
    parameter integer NUM_SCALE_WEIGHT = 7,
    parameter integer NUM_SCALE_BIAS   = 7,
    parameter integer NUM_SCALE_DOUT   = 6,

    // [J-WB] ---------- wb loader ----------
    parameter integer WB_ADDR_W = 15,     // wb_addr 폭. eMamba_IP 의 WB_BRAM_ADDR_W 와 같게
    parameter integer WB_BASE_W = 0      // weight 창의 첫 워드 번호
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    weight,
    bias,

    s_valid, // input
    s_ready, // output
    
    m_ready, // input
    m_valid //output
);

localparam integer NUM_LSH_DIN = 5;

localparam integer NUM_BATCH   = (NUM_DIM + NUM_PARALLEL - 1) / NUM_PARALLEL;
// [J-IMP] BATCH_CNT_W -> NORM_CYC 기준으로 아래서 재정의

localparam integer NUM_STAGE        = ($clog2(NUM_DIM) > 0) ? $clog2(NUM_DIM) : 1;
localparam integer DATA_WIDTH_DIN   = DATA_WIDTH + NUM_LSH_DIN;
localparam integer DATA_WIDTH_SUM   = DATA_WIDTH_DIN + NUM_STAGE;
localparam integer DATA_WIDTH_NORM  = DATA_WIDTH_DIN + DATA_WIDTH + 4;
localparam integer DATA_WIDTH_RAW   = DATA_WIDTH_NORM - NUM_LSH_DIN + 1;
localparam integer NUM_RSH_DOUT     = NUM_SCALE_WEIGHT + 3 - NUM_SCALE_DOUT;
// [J-IMP] LANE_IDX_W  -> NORM_CYC 기준으로 아래서 재정의
localparam integer DIM_IDX_W        = $clog2(NUM_DIM > 1 ? NUM_DIM : 2);

localparam integer NUM_SLICE_W = DATA_WIDTH_NORM - NUM_LSH_DIN;   // 20
localparam integer RANGE_DIV_W = DATA_WIDTH_DIN  - NUM_LSH_DIN;   // 8
localparam integer FRAC_BITS   = (NUM_SLICE_W - 1) + RANGE_DIV_W; // 27

localparam integer LANE_PIPE = 2;                       // [J-IMP] LightNorm_channel 레지스터 단수
localparam integer NORM_CYC  = NUM_BATCH + LANE_PIPE;   // [J-IMP] NORMALIZE 체류 사이클
localparam integer BATCH_CNT_W = ($clog2(NORM_CYC) > 0) ? $clog2(NORM_CYC) : 1;          // [J-IMP] NUM_BATCH → NORM_CYC
localparam integer LANE_IDX_W  = $clog2((NORM_CYC * NUM_PARALLEL) > 1 ? (NORM_CYC * NUM_PARALLEL) : 2); // [J-IMP] ch_idx 가 drain 중 overflow 안 하게

logic [BATCH_CNT_W-1:0] wr_batch_q [1:LANE_PIPE];       // [J-IMP]
logic                   wr_valid_q [1:LANE_PIPE];       // [J-IMP]


localparam INIT      = 'd0,
           STATS     = 'd1,
           INV       = 'd2,
           NORMALIZE = 'd3,
           DONE      = 'd4;

localparam EMPTY = 'd0,
           LOAD  = 'd1;

input clk, nRst;
input ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1];
output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1];

input logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1];
input logic signed [DATA_WIDTH-1:0] bias   [0:NUM_DIM-1];

input  s_valid, m_ready;
output s_ready, m_valid;

logic [2:0] curr_state, next_state;
logic [BATCH_CNT_W-1:0] batch_idx, next_batch_idx;

logic signed [DATA_WIDTH_DIN-1:0] dIn_lsh    [0:NUM_DIM-1];
logic signed [DATA_WIDTH_DIN-1:0] dIn_mem    [0:NUM_DIM-1];
logic signed [DATA_WIDTH-1:0]     weight_mem [0:NUM_DIM-1];
logic signed [DATA_WIDTH-1:0]     bias_mem   [0:NUM_DIM-1];

logic signed [DATA_WIDTH_SUM-1:0] stats_sum;
logic signed [DATA_WIDTH_DIN-1:0] stats_max, stats_min;
logic        [DATA_WIDTH_DIN-1:0] stats_range;

logic signed [DATA_WIDTH_DIN-1:0] mean;
logic        [DATA_WIDTH_DIN-1:0] range_latched;
logic signed [DATA_WIDTH_SUM-1:0] sum_latched;
logic        [FRAC_BITS:0]        inv_range;

logic inv_start, inv_valid, inv_started, mean_valid;
logic mean_start;// [J-IMP] mean divider start (range_div==0 예방해)

logic signed [DATA_WIDTH_RAW-1:0] raw_out   [0:NUM_PARALLEL-1];
logic signed [DATA_WIDTH-1:0]     lane_dOut [0:NUM_PARALLEL-1];

integer i;

logic last_cycle;
logic dIn_stat;

logic s_handshaking, m_handshaking;

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign s_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid  = (curr_state == DONE);

assign last_cycle = (curr_state == NORMALIZE) && (batch_idx == NORM_CYC - 1); 


// [J] get input data
always @(posedge clk) begin
    if (!nRst || ps_start)  dIn_stat <= #1 EMPTY;
    else if (s_handshaking) dIn_stat <= #1 LOAD;
    else if (last_cycle)    dIn_stat <= #1 EMPTY;
end

always @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        dIn_mem    <= #1 '{default:'0};                       // [J-unopt-reset]
        weight_mem <= #1 '{default:'0};                       // [J-unopt-reset]
        bias_mem   <= #1 '{default:'0};                       // [J-unopt-reset]
    end else if (s_handshaking) begin                         // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        dIn_mem    <= #1 dIn_lsh;
        weight_mem <= #1 weight;
        bias_mem   <= #1 bias;
    end
end

// [J-IMP] 발행 사이클 (batch_idx < NUM_BATCH) 만 유효. drain 사이클엔 ch_valid 가 이미 0
always @(posedge clk) begin
    if (!nRst || ps_start) begin                                         // [J-IMP] ps_start 중단 시 stale write 방지
        for (i = 1; i <= LANE_PIPE; i = i + 1) wr_valid_q[i] <= #1 1'b0;
        for (i = 1; i <= LANE_PIPE; i = i + 1) wr_batch_q[i] <= #1 '0;       // [J-unopt-reset] wr_batch_q 도 리셋
    end
    else begin
        wr_valid_q[1] <= #1 (curr_state == NORMALIZE) && (batch_idx < NUM_BATCH);
        wr_batch_q[1] <= #1 batch_idx;
        for (i = 2; i <= LANE_PIPE; i = i + 1) begin
            wr_valid_q[i] <= #1 wr_valid_q[i-1];
            wr_batch_q[i] <= #1 wr_batch_q[i-1];
        end
    end
end

// [J] Final output — 파이프 끝의 batch 로 주소
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        for (i = 0; i < NUM_DIM; i = i + 1)
            dOut[i] <= #1 '0;
    end
    else if (wr_valid_q[LANE_PIPE]) begin                                   // [J-IMP] curr_state==NORMALIZE →
        for (i = 0; i < NUM_PARALLEL; i = i + 1)
            if ((wr_batch_q[LANE_PIPE] * NUM_PARALLEL + i) < NUM_DIM)
                dOut[wr_batch_q[LANE_PIPE] * NUM_PARALLEL + i] <= #1 lane_dOut[i];
    end
end

// ---------- ---------- ---------- ---------- Data Processing Logic ---------- ---------- ---------- ---------- 
genvar n, m;

generate
    for (n = 0; n < NUM_DIM; n = n + 1) begin : DIN_UPSCALE
        shifter_left #(
            .DATA_WIDTH(DATA_WIDTH),
            .NUM_SHIFT(NUM_LSH_DIN)
        ) shifter (
            .dIn (dIn[n]),
            .dOut(dIn_lsh[n])
        );
    end
endgenerate

LightNorm_stats #(
    .DATA_WIDTH(DATA_WIDTH_DIN),
    .NUM_DIM   (NUM_DIM)
) middle_values (
    .dIn    (dIn_mem), // input Data 1D

    .sum    (stats_sum), // output Data Scalar
    .max_val(stats_max), // unused
    .min_val(stats_min), // unused
    .range  (stats_range) // output Data Scalar
);

// stats_range skips 1 cycle caused by calculator_mean,
//      to be used as input for inv_range.
always @(posedge clk) begin
    if (!nRst) begin
        range_latched <= #1 '0;
        sum_latched   <= #1 '0;
    end
    else if (curr_state == STATS) begin
        range_latched <= #1 stats_range;
        sum_latched   <= #1 stats_sum;
    end
end

LightNorm_mean_unit #(
    .DATA_WIDTH    (DATA_WIDTH_DIN),
    .DATA_WIDTH_SUM(DATA_WIDTH_SUM),
    .NUM_DIM       (NUM_DIM)
) calculator_mean (
    .clk (clk),
    .nRst(nRst),

    .sum (sum_latched), // input Data Scalar

    .mean(mean), // output Data Scalar

    .start(mean_start), // [J-IMP] input  
    .valid(mean_valid)  // [J-IMP] output
);

LightNorm_inv_range #(
    .RANGE_WIDTH(DATA_WIDTH_DIN),
    .FRAC_BITS  (FRAC_BITS),
    .NUM_LSH_DIN(NUM_LSH_DIN)
) u_inv (
    .clk      (clk),
    .nRst     (nRst),

    .range    (range_latched), // input Data Scalar - 1cycle skipped stats_range
    .inv_range(inv_range), // output Data Scalar

    .start    (inv_start), // input

    .valid    (inv_valid) // output
);
// INV edge detector
assign inv_start = (curr_state == INV) && !inv_started;

assign mean_start = inv_start && ((range_latched >> NUM_LSH_DIN) != '0);   // [J-IMP]

always @(posedge clk) begin
    if (!nRst || ps_start)
        inv_started <= #1 1'b0;
    else if (curr_state != INV)
        inv_started <= #1 1'b0;
    else
        inv_started <= #1 1'b1;
end

// ---------- ---------- ---------- ---------- Data Processing Logic ---------- ---------- ---------- ---------- 
generate
    for (m = 0; m < NUM_PARALLEL; m = m + 1) begin : LANES
        logic [LANE_IDX_W-1:0] ch_idx;
        logic [DIM_IDX_W-1:0]  ch_idx_safe;
        logic ch_valid;

        assign ch_idx      = batch_idx * NUM_PARALLEL + m;
        assign ch_valid    = (ch_idx < NUM_DIM);
        assign ch_idx_safe = ch_valid ? ch_idx[DIM_IDX_W-1:0] : '0;

        LightNorm_channel #(
            .DATA_WIDTH      (DATA_WIDTH),
            .DATA_WIDTH_DIN  (DATA_WIDTH_DIN),
            .NUM_LSH_DIN     (NUM_LSH_DIN),
            .FRAC_BITS       (FRAC_BITS),
            .NUM_SCALE_WEIGHT(NUM_SCALE_WEIGHT),
            .NUM_SCALE_BIAS  (NUM_SCALE_BIAS)
        ) channel_core (
            .clk      (clk),
            .nRst     (nRst),                                 // [J-unopt-reset]
            .x        (dIn_mem[ch_idx_safe]),
            .mean     (mean),
            .weight   (weight_mem[ch_idx_safe]),
            .bias     (bias_mem[ch_idx_safe]),
            .inv_range(inv_range),

            .raw_out  (raw_out[m]) // output Data Scalar
        );

        activator #(
            .DATA_WIDTH  (DATA_WIDTH_RAW),
            .NUM_RSH_DOUT(NUM_RSH_DOUT)
        ) activator (
            .dIn (raw_out[m]),
            .dOut(lane_dOut[m])
        );
    end
endgenerate
// ========== ========== ========== ========== Data Processing Logic ========== ========== ========== ========== 

// ---------- ---------- ---------- ---------- FSM # state---------- ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state     = curr_state;

    case (curr_state)
        INIT: begin
            if (dIn_stat == LOAD)
                next_state     = STATS;
        end

        STATS: begin
            next_state = INV;
        end

        INV: begin
            if (inv_valid) begin
                next_state     = NORMALIZE;
            end
        end

        NORMALIZE: begin
            if (last_cycle)
                next_state     = DONE;
        end

        DONE: begin
            if (m_handshaking)begin
                if (dIn_stat == LOAD) 
                    next_state = STATS;
                else 
                    next_state = INIT;
            end
        end

        default: next_state = INIT;
    endcase
end
// ========== ========== ========== ========== FSM # state ========== ========== ========== ========== 

// ---------- ---------- ---------- ---------- FSM # batch_idx ---------- ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst)
        batch_idx <= #1 '0;
    else
        batch_idx <= #1 next_batch_idx;
end
always @(*) begin
    next_batch_idx = batch_idx;

    case (curr_state)
        INIT: begin
            if (dIn_stat == LOAD) begin
                next_batch_idx = '0;
            end
        end

        STATS: begin
            next_batch_idx = batch_idx;
        end

        INV: begin
            if (inv_valid) begin
                next_batch_idx = '0;
            end
        end

        NORMALIZE: begin
            if (last_cycle) next_batch_idx = '0;
            else            next_batch_idx = batch_idx + 1;
        end

        DONE: begin
            next_batch_idx = batch_idx;
        end

        default: next_batch_idx = '0;
    endcase
end
// ========== ========== ========== ========== FSM # batch_idx ========== ========== ========== ========== 



endmodule