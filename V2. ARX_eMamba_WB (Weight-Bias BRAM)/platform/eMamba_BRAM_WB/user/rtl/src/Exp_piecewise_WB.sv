`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Exp_piecewise_WB
// Description: delta[ed] * A[ed][n] ->  piecewise_exp ->  delta_A[ed][n]
//////////////////////////////////////////////////////////////////////////////////

module Exp_piecewise_WB  #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 40,  // ED
    parameter integer NUM_DIM_2  = 8,   // N

    parameter integer NUM_SCALE_DIN_1 = 4,
    parameter integer NUM_SCALE_DIN_2 = 3,
    parameter integer NUM_SCALE_DOUT  = 7,

     // [J-WB] ---------- wb loader ----------
    parameter string  LOG_NAME     = "",
    parameter integer DEBUG_SWITCH = 0,
    parameter integer WB_ADDR_W    = 15,
    parameter integer WB_BASE_W    = 0
)(
    clk,
    nRst,

    ps_start,

    delta,//input data
    // matrix_A,//input data                // [J-WB]
    // ↑ 삭제 : wb_* broadcast 로 수신
    wb_valid,                               // [J-WB]
    wb_addr,                                // [J-WB]
    wb_data,                                // [J-WB]

    dOut,//output data 2D

    s_valid, // input
    m_ready, // input

    s_ready, // output
    m_valid //output
);

// ========== Local Parameters ==========
localparam integer DATA_WIDTH_DIN    = DATA_WIDTH * 2;
localparam integer NUM_SCALE_DIN_EXP = NUM_SCALE_DIN_1 + NUM_SCALE_DIN_2;

localparam INIT      = 'd0,
           COMPUTING = 'd1,
           WAIT      = 'd2,     // [J-pExp-ff] 마지막 ED 가 P2 를 지나 dOut 에 써질 때까지 대기
           DONE      = 'd3;     // [J-pExp-ff] 'd2 -> 'd3

localparam  EMPTY = 1'b0,
            LOAD = 1'b1;

// [J] ED 카운터 폭 계산 (elaborate 단계에서 결정되므로 overhead 없어)
localparam integer ED_CNT_WIDTH = ($clog2(NUM_DIM_1) > 0) ? $clog2(NUM_DIM_1) : 1;

// [J-pExp-ff] 발행(P1) -> dOut 쓰기까지 파이프 단수. WAIT 는 이 만큼 머문다.
//             1 단이라 drain 카운터 없이 WAIT 1 사이클 뒤 바로 DONE.
localparam integer PEXP_PIPE = 1;

// ========== I/O Ports ==========
input clk, nRst;
input ps_start;

input  logic signed [DATA_WIDTH-1:0] delta    [0:NUM_DIM_1-1];

output logic signed [DATA_WIDTH-1:0] dOut     [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

input  s_valid, m_ready;
output s_ready, m_valid;

// ========== Internal Signals ==========
logic [1:0] curr_state, next_state;

// [J] curr_dIn_column[5:0], curr_dIn_row[3:0]
logic [ED_CNT_WIDTH-1:0] curr_ed_idx, next_ed_idx;

logic signed [DATA_WIDTH_DIN-1:0] compute_pExp_dIn   [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH_DIN-1:0] pExp_dIn_q         [0:NUM_DIM_2-1];   // [J-pExp-ff] P1/P2 경계 FF
logic signed [DATA_WIDTH-1:0]     compute_pExp_dOut  [0:NUM_DIM_2-1];

// [J-pExp-ff] 패킷 (ed · valid) 을 데이터와 같은 단수만큼 지연. _d1: P2 (dOut 쓰기 주소)
logic [ED_CNT_WIDTH-1:0] ed_d1;
logic                    v_d1;

logic signed [DATA_WIDTH-1:0] delta_mem    [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] matrix_A_mem [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

logic dIn_stat;
logic last_cycle;
logic s_handshaking, m_handshaking;

assign last_cycle = (curr_state == COMPUTING) && (curr_ed_idx == NUM_DIM_1-1);

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign s_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid  = (curr_state == DONE);

// ========== Input data ==========
always @(posedge clk) begin
    if (!nRst || ps_start)
        dIn_stat <= #1 EMPTY;
    else begin
        if (s_handshaking) dIn_stat <= #1 LOAD;
        else if (last_cycle) dIn_stat <= #1 EMPTY;
    end
end

always @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        delta_mem    <= #1 '{default:'0};                     // [J-unopt-reset]
    end else if (s_handshaking) begin                         // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        delta_mem    <= #1 delta;
    end
end

// ---------- ---------- ---------- ---------- [J-WB] matrix_A Broadcast ---------- ---------- ---------- ----------
//   matrix_A 는 [ED][N] row-major 320 B. N(=8) 이 4 의 배수라 한 워드가 행을 안넘고있어
// ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ----------
localparam integer A_BYTES   = NUM_DIM_1 * NUM_DIM_2;          // 320
localparam integer A_ROW_W   = $clog2(NUM_DIM_1);
localparam integer A_COL_W   = $clog2(NUM_DIM_2);

logic [A_ROW_W-1:0] a_row;
logic [A_COL_W-1:0] a_col;

// ---------- ---------- ---------- ---------- [J-WBPIPE] WB 수신 파이프라인 ---------- ---------- ---------- ----------
//   stage0 : broadcaster 에서 오는 장거리 배선을 FF 에서 끊어. 로직 없음.
//   stage1 : 주소 비교 결과(hit / first)를 레지스터로. 데이터는 한 단 더 같이 밀어줘 (wb_d_q2).
//   stage2 : 기존 쓰기 로직 그대로. hit / first / wb_d_q2 만 사용.
//   -> 모든 쓰기가 똑같이 2클럭 뒤로 밀릴 뿐 순서/내용 불변. loader 의 wb_done 도 2클럭 지연시켜 맞춤.
// ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ----------
//   [J-WBPIPE] stage0 FF 는 25개 수신기에서 D/clk/reset 이 전부 같아 합성이 하나로 합쳐버릴 수 있어 (equivalent register removal).
//             합쳐지면 장거리 배선이 다시 비교 로직과 같은 사이클에 들어가므로 DONT_TOUCH 로 인스턴스마다 따로 남겨.
(* DONT_TOUCH = "TRUE" *) logic                 wb_v_q;
(* DONT_TOUCH = "TRUE" *) logic [WB_ADDR_W-1:0] wb_a_q;
(* DONT_TOUCH = "TRUE" *) logic [31:0]          wb_d_q;
logic [31:0]          wb_d_q2;

always @(posedge clk) begin
    if (!nRst) begin
        wb_v_q  <= #1 1'b0;
        wb_a_q  <= #1 '0;
        wb_d_q  <= #1 '0;
        wb_d_q2 <= #1 '0;
    end else begin
        wb_v_q  <= #1 wb_valid;
        wb_a_q  <= #1 wb_addr;
        wb_d_q  <= #1 wb_data;
        wb_d_q2 <= #1 wb_d_q;
    end
end

logic a_hit, a_first;   // [J-WBPIPE] stage1 레지스터 (기존 wire 대체)
always @(posedge clk) begin
    if (!nRst) begin
        a_hit           <= #1 1'b0;
        a_first         <= #1 1'b0;
    end else begin
        a_hit           <= #1 wb_v_q && (wb_a_q >= WB_BASE_W) && (wb_a_q < WB_BASE_W + A_BYTES);
        a_first         <= #1 wb_v_q && (wb_a_q == WB_BASE_W);
    end
end

wire [A_ROW_W-1:0] r_now = a_first ? '0 : a_row;
wire [A_COL_W-1:0] c_now = a_first ? '0 : a_col;

always @(posedge clk) begin
    if (!nRst) begin
        matrix_A_mem <= #1 '{default:'0};
    end else if (a_hit) begin
        matrix_A_mem[r_now][c_now    ] <= #1 wb_d_q2[ 7: 0];
        matrix_A_mem[r_now][c_now + 1] <= #1 wb_d_q2[15: 8];
        matrix_A_mem[r_now][c_now + 2] <= #1 wb_d_q2[23:16];
        matrix_A_mem[r_now][c_now + 3] <= #1 wb_d_q2[31:24];
    end
end

always @(posedge clk) begin
    if (!nRst) begin
        a_row <= #1 '0;
        a_col <= #1 '0;
    end else if (a_hit) begin
        if (c_now == NUM_DIM_2 - 4) begin
            a_col <= #1 '0;
            a_row <= #1 r_now + 1'b1;
        end else begin
            a_col <= #1 c_now + 'd4;
            a_row <= #1 r_now;
        end
    end
end
// ========== ========== ========== ========== [J-WB] matrix_A Broadcast ========== ========== ========== ==========

// ========== Output ==========
always @(posedge clk) begin
    if (!nRst)                                                // [J-unopt-reset]
        dOut <= #1 '{default:'0};                             // [J-unopt-reset]
    else if (v_d1)                                            // [J-pExp-ff] curr_state==COMPUTING / curr_ed_idx -> 패킷 v_d1 / ed_d1
        dOut[ed_d1] <= #1 compute_pExp_dOut;
end

// ========== [J-pExp-ff] 패킷 shift ==========
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        v_d1  <= #1 1'b0;
        ed_d1 <= #1 '0;                                       // [J-unopt-reset] ed_d1 도 리셋
    end
    else begin
        v_d1  <= #1 (curr_state == COMPUTING);                // P1 발행
        ed_d1 <= #1 curr_ed_idx;
    end
end

// ---------- ---------- ---------- ---------- Data Processing Logic ---------- ---------- ---------- ----------
// ========== P1 : delta × A ==========
Dim_expand_delta_A_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_ED(NUM_DIM_2)
) Dim_expand_delta_A_compute (
    // [J] curr_dIn_column ->  curr_ed_idx
    .delta(delta_mem[curr_ed_idx]), //input
    .matrix(matrix_A_mem[curr_ed_idx]), //input
    .dOut(compute_pExp_dIn) //output
);

// ========== [J-pExp-ff] P1 -> P2 pipeline register ==========
// 값은 v_d1 이 0 이면 버려진다. 리셋은 [J-unopt-reset] 규칙 그대로.
always @(posedge clk) begin
    if (!nRst)                                                // [J-unopt-reset]
        pExp_dIn_q <= #1 '{default:'0};                       // [J-unopt-reset]
    else
        pExp_dIn_q <= #1 compute_pExp_dIn;
end

// ========== P2 : piecewise exp ==========
Exp_piecewise_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_DIM_2),
    .NUM_SCALE_DIN(NUM_SCALE_DIN_EXP),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) Exp_piecewise_compute (
    .dIn(pExp_dIn_q), //input   [J-pExp-ff] compute_pExp_dIn -> pExp_dIn_q
    .dOut_8bit(compute_pExp_dOut) //output
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
                next_state = WAIT;                            // [J-pExp-ff] DONE -> WAIT
        end

        WAIT: next_state = DONE;

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
    if (!nRst || ps_start)
        curr_ed_idx <= #1 'd0;
    else
        curr_ed_idx <= #1 next_ed_idx;
end

always @(*) begin
    next_ed_idx = curr_ed_idx;

    case (curr_state)
        INIT:       next_ed_idx = 'd0;
        COMPUTING:  next_ed_idx = last_cycle ? 'd0 : (curr_ed_idx + 1);
        WAIT:       next_ed_idx = 'd0;                        // [J-pExp-ff]
        DONE:       next_ed_idx = 'd0;
        default:    next_ed_idx = 'd0;
    endcase
end
endmodule