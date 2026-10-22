`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Dim_expand_delta_B
// Description: delta[ed] * B[n] ->  delta_B[ed][n]  (스칼라×벡터, ED 방향 FSM)
//////////////////////////////////////////////////////////////////////////////////

module U_Dim_expand_delta_B #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM_1  = 40,  // ED
    parameter integer NUM_DIM_2  = 8,   // N

    parameter integer NUM_SCALE_DIN_1 = 4,
    parameter integer NUM_SCALE_DIN_2 = 3,
    parameter integer NUM_SCALE_DOUT  = 1
)(
    clk,
    nRst,

    ps_start,

    delta,// input
    matrix_B,// input

    dOut,//output 2D

    s_valid, // input
    s_ready, // output

    m_ready, // input
    m_valid //output
);

// ========== Local Parameters ==========
localparam INIT      = 'd0,
           COMPUTING = 'd1,
           DONE      = 'd2;

localparam EMPTY     = 'd0,
           LOAD      = 'd1;

// [J] ED 카운터 폭 계산 (elaborate 단계에서 결정되므로 overhead 없어), 63->384 업데이트 자동
localparam integer ED_CNT_WIDTH = ($clog2(NUM_DIM_1) > 0) ? $clog2(NUM_DIM_1) : 1;

// ========== I/O Ports ==========
input clk, nRst;
input ps_start;

input   logic signed [DATA_WIDTH-1:0] delta    [0:NUM_DIM_1-1];
input   logic signed [DATA_WIDTH-1:0] matrix_B [0:NUM_DIM_2-1];
output  logic signed [DATA_WIDTH-1:0] dOut     [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

input  s_valid, m_ready;
output s_ready, m_valid;

// ========== Internal Signals ==========
logic [1:0] curr_state, next_state;

// [J] curr_dIn_column[5:0], curr_dIn_row[3:0] 
logic [ED_CNT_WIDTH-1:0] curr_ed_idx, next_ed_idx;

logic signed [DATA_WIDTH-1:0] compute_dOut [0:NUM_DIM_2-1];

logic signed [DATA_WIDTH-1:0] delta_mem    [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] matrix_B_mem [0:NUM_DIM_2-1];

logic dIn_stat;
logic last_cycle;
logic s_handshaking, m_handshaking;

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign s_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid  = (curr_state == DONE);

assign last_cycle = (curr_state == COMPUTING) && (curr_ed_idx == NUM_DIM_1-1);

always @(posedge clk) begin
    if (!nRst || ps_start)  dIn_stat <= #1 EMPTY;
    else if (s_handshaking) dIn_stat <= #1 LOAD;
    else if (last_cycle)    dIn_stat <= #1 EMPTY;
end

always @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        delta_mem    <= #1 '{default:'0};                     // [J-unopt-reset]
        matrix_B_mem <= #1 '{default:'0};                     // [J-unopt-reset]
    end else if (s_handshaking) begin                         // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        delta_mem    <= #1 delta;
        matrix_B_mem <= #1 matrix_B;
    end
end

always @(posedge clk) begin
    if (!nRst)                                                // [J-unopt-reset]
        dOut <= #1 '{default:'0};                             // [J-unopt-reset]
    else if (curr_state == COMPUTING)                         // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        dOut[curr_ed_idx] <= #1 compute_dOut;
end

// ---------- ---------- ---------- ---------- Data Processing Logic ---------- ---------- ---------- ---------- 
ElementWise_Prod_Dynamic #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),

    .BROADCAST_DIN_1(1'b1),
    
    .NUM_SCALE_DIN_1(NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) Dim_expand_delta_B_compute (
    // [J] delta_mem 바로 사용 & curr_ed_idx로 통일
    .dIn_1_scalar(delta_mem[curr_ed_idx]),
    .dIn_1_vec(),
    .dIn_2(matrix_B_mem),
    .dOut(compute_dOut)
);
// ========== ========== ========== ========== Data Processing Logic ========== ========== ========== ========== 

// ---------- ---------- ---------- ---------- FSM ---------- ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        INIT: begin
            if (dIn_stat == LOAD)
                next_state = COMPUTING;
        end

        COMPUTING: begin
            if (last_cycle)
                next_state = DONE;
        end

        DONE: begin
            if (m_handshaking) begin
                if (dIn_stat == LOAD) 
                    next_state = COMPUTING;
                else 
                    next_state = INIT;
            end
        end

        default: next_state = INIT;
    endcase
end
// ========== ========== ========== ========== FSM ========== ========== ========== ========== 

// ---------- ---------- ---------- ---------- ED scan counter ---------- ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst)
        curr_ed_idx <= #1 'd0;
    else
        curr_ed_idx <= #1 next_ed_idx;
end

always @(*) begin
    next_ed_idx = curr_ed_idx;

    case (curr_state)
        INIT:       next_ed_idx = 'd0;
        COMPUTING:  next_ed_idx = last_cycle ? 'd0 : (curr_ed_idx + 1);
        DONE:       next_ed_idx = 'd0;
        default:    next_ed_idx = 'd0;
    endcase
end
// ========== ========== ========== ========== ED scan counter ========== ========== ========== ========== 


endmodule