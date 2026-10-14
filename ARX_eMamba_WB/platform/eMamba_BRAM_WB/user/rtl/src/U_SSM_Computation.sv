`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: U_SSM_Computation
// Description: SSM 본연산 — 토큰당 ED 순회, x[k+1] 갱신, y 출력.
//              NUM_DIM_1(ED), NUM_DIM_2(N), NUM_SEQLEN(L) parameter화.
//
// [J] 인덱스 규약 (legacy 이름 유지, 의미는 아래와 같아)
//   curr_dIn_column : ED 채널 인덱스 (inner loop, 0..ED-1). COMPUTING 매 clk 증가.
//                     dIn_mem / delta_*_mem / xk_ssm_state / dOut 의 주소.
//   curr_seq_idx    : 토큰(시퀀스) 인덱스 k (outer loop, 0..L-1). 토큰 1개 끝날 때 1회 증가.
//                     어떤 메모리도 인덱싱하지 않고, "프레임 끝" 판정 전용.
//                     -> 프레임 끝에서 recurrent state(xk_ssm_state)를 0으로 초기화.
//
// [J] 파이프라인 2단
//   stage1 (COMPUTING, curr_dIn_column)    : SSM_xkP1_compute -> x[k+1], state write-back
//   stage2 (COMPUTING/WAIT, ..._delayed_1) : SSM_y_compute    -> dOut[]
//   stage2 피연산자는 "인덱스"가 아니라 "데이터"를 지연시켜야 해.
//   last_cycle 에 새 payload 를 받으면 *_mem 이 그 edge 에 덮어써지는데,
//   인덱스만 지연하면 WAIT 에서 마지막 채널 y 가 다음 토큰 데이터로 계산돼 버려.
//
// [J-Timing] 파이프라인 4단 (곱셈 뒤 FF 2개 추가, DSP PREG)
//   A1 (COMPUTING, curr_dIn_column) : mux -> δA×xk, δB×u  -> Ax_q/Bu_q      (SSM_xkP1_compute 안)
//   A2 (v_d1, col_d1)               : Ax_q + Bu_q<<7 -> 반올림 -> xk_ssm_state[col_d1] ; xkP1_delayed_2
//   Y1 (v_d2)                       : C×xkP1, D×u -> prod_q/Du_q             (SSM_y_compute 안)
//   Y2 (v_d3, col_d3)               : 덧셈 트리 + Du -> 반올림 -> 포화 -> dOut[col_d3]
//   WAIT 는 SSM_PIPE(3) 사이클. frame_last 클리어는 fl_d1 로 A2 에 맞춤.
//////////////////////////////////////////////////////////////////////////////////

module U_SSM_Computation#(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16, // L
    parameter integer NUM_DIM_1  = 40, // ED
    parameter integer NUM_DIM_2  = 8,  // N

    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_C       = 5,
    parameter integer NUM_SCALE_D       = 6,
    parameter integer NUM_SCALE_DOUT    = 3,

    parameter integer DEBUG_SWITCH = 0,
        // [J-WB] ---------- wb loader ----------
    parameter string  LOG_NAME  = "",
    parameter integer WB_ADDR_W = 15,
    parameter integer WB_BASE_W = 0      // matrix_D 창의 첫 바이트 주소
)(
    clk,
    nRst,

    ps_start,

    dIn,//input

    delta_A,//input
    delta_B,//input
    matrix_C,//input
    
    wb_valid,  // [J-WB]
    wb_addr,   // [J-WB]
    wb_data,   // [J-WB]

    dOut,//output

    s_valid, // input
    s_ready, // output

    m_ready, // input
    m_valid //output
);

// ========== Local Parameters ==========
localparam INIT         = 'd0,
           COMPUTING    = 'd1,
           WAIT         = 'd2,
           DONE         = 'd3;

localparam EMPTY = 1'b0,
           LOAD  = 1'b1;

localparam integer DATA_WIDTH_BU       = DATA_WIDTH * 2;
localparam integer DATA_WIDTH_BU_LSH   = DATA_WIDTH_BU + NUM_SCALE_DELTA_A;
localparam integer DATA_WIDTH_AX       = DATA_WIDTH_BU_LSH;
localparam integer DATA_WIDTH_XKP1     = DATA_WIDTH_AX + 1;
localparam integer DATA_WIDTH_XKP1_RSH = DATA_WIDTH_XKP1 - NUM_SCALE_DELTA_A;

// [J] ED(NUM_DIM_1), seq(NUM_SEQLEN) 카운터 폭 — Dim_expand_delta_B와 동일 패턴
// [J-Timing] 발행(A1) -> dOut 쓰기까지 파이프 단수. A1(곱셈 FF) -> A2(xk 쓰기) -> Y1(곱셈 FF) -> Y2(dOut 쓰기)
//            WAIT 는 이 만큼 머물러 마지막 column 이 dOut 에 도착한 뒤 DONE 으로 간다 (기존 1 -> 3)
// localparam integer SSM_PIPE = 3;
// ↑ 삭제 : [J-ytree-tag] 자식 지연을 부모가 알 필요 없음. WAIT 탈출은 자식이 내보내는 태그 (v_y, col_y) 기준

localparam integer ED_CNT_WIDTH  = ($clog2(NUM_DIM_1)  > 0) ? $clog2(NUM_DIM_1)  : 1;
localparam integer ROW_CNT_WIDTH = ($clog2(NUM_SEQLEN) > 0) ? $clog2(NUM_SEQLEN) : 1;

// ========== I/O Ports ==========
input clk, nRst;

input ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM_1-1];

input logic signed [DATA_WIDTH-1:0] delta_A  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
input logic signed [DATA_WIDTH-1:0] delta_B  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
input logic signed [DATA_WIDTH-1:0] matrix_C [0:NUM_DIM_2-1];

input logic                  wb_valid; // [J-WB]
input logic [WB_ADDR_W-1:0]  wb_addr;  // [J-WB]
input logic [31:0]           wb_data;  // [J-WB]

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM_1-1];

input  s_valid, m_ready;
output s_ready, m_valid;

// ========== Internal Signals ==========
logic [1:0] curr_state,
            next_state;

// [J] NUM_SEQLEN based dynamic width (L=197 -> 8bit)
logic [ROW_CNT_WIDTH-1:0] curr_seq_idx,
                          next_seq_idx;

// [J] ED index [5:0](max 63) -> NUM_DIM_1 based dynamic width (ED=384 -> 9bit)
logic [ED_CNT_WIDTH-1:0] curr_dIn_column,
                         next_dIn_column;

// [J-Timing] 패킷 (col · valid · frame_last) 을 데이터와 같은 단수만큼 지연
//            _d1: A2 (xk_ssm_state 쓰기 주소)   _d2: Y1 입력   _d3: Y2 (dOut 쓰기 주소)
// [J-ytree-tag] _d3 이후는 SSM_y_compute_FF 안에서 데이터와 같이 통과 -> (v_y, col_y) 로 돌아옴
logic [ED_CNT_WIDTH-1:0] col_d1, col_d2;              // [J-ytree-tag] col_d3 삭제
logic                    v_d1, v_d2;                  // [J-ytree-tag] v_d3 삭제
logic                    fl_d1;                       // frame_last 지연 -> xk_ssm_state 클리어도 같이 늦춤
// logic [1:0]              drain_cnt;                   // WAIT 체류 카운터
// ↑ 삭제 : [J-ytree-tag] WAIT 탈출을 y_last 로

logic                    v_y;                         // [J-ytree-tag] output_y valid
logic [ED_CNT_WIDTH-1:0] col_y;                       // [J-ytree-tag] output_y 의 column
logic                    y_last;                      // [J-ytree-tag] 마지막 column 이 출력에 도착

// stage1
logic signed [DATA_WIDTH_XKP1-1:0]     xkP1_compute_dOut  [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH_XKP1_RSH-1:0] xkP1_right_shifted [0:NUM_DIM_2-1];

// [J] SSM hidden state 누적해서 저장해. accumulate and store
// [J-Korean]  seq_idx(curr_/next_seq_idx) 돌면서 in-place update, seq 끝나면 frame_last 에서 초기화. (x[k+1] -> x[k] 갱신)
// [J-English] seq_idx(curr_/next_seq_idx) loop in-place update, seq end then frame_last initialize. (x[k+1] -> x[k] update)
logic signed [DATA_WIDTH_XKP1_RSH-1:0] xk_ssm_state [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

// latching buffer
logic signed [DATA_WIDTH-1:0] dIn_mem      [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] delta_A_mem  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] delta_B_mem  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] matrix_C_mem [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] matrix_D_mem [0:NUM_DIM_1-1];

// stage2 operands
// [J-Timing] A1 에 1 단이 들어가 y 입력이 t+2 에지에 맞춰짐 -> dIn/D/C 는 2 단, xkP1 은 A2 출력을 1 단
logic signed [DATA_WIDTH_XKP1-1:0] xkP1_compute_dOut_delayed_2 [0:NUM_DIM_2-1];   // [J-Timing] _delayed_1 -> _delayed_2
logic signed [DATA_WIDTH-1:0]      dIn_delayed_1,      dIn_delayed_2;              // [J-Timing]
logic signed [DATA_WIDTH-1:0]      matrix_D_delayed_1, matrix_D_delayed_2;         // [J-Timing]
logic signed [DATA_WIDTH-1:0]      matrix_C_delayed_1 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0]      matrix_C_delayed_2 [0:NUM_DIM_2-1];             // [J-Timing]
logic signed [DATA_WIDTH-1:0]      output_y;

integer i;

logic dIn_stat;
logic s_handshaking, m_handshaking;
logic last_cycle;   // payload(= 토큰 1개) 마지막 계산 cycle || English: last cycle of payload (1 token)
logic frame_last;   // 시퀀스(L 토큰) 마지막 계산 cycle || English: last cycle of sequence (L tokens)

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign s_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid = (curr_state == DONE);

assign last_cycle = (curr_state == COMPUTING) && (curr_dIn_column == NUM_DIM_1-1); // cloumn done
assign frame_last = last_cycle && (curr_seq_idx == NUM_SEQLEN-1); // real done - flush ssm_xkP1_compute result

always @(posedge clk) begin
    if (!nRst)                  dIn_stat <= #1 EMPTY;
    else begin
        if (ps_start)           dIn_stat <= #1 EMPTY;
        else if (s_handshaking) dIn_stat <= #1 LOAD;
        else if (last_cycle)    dIn_stat <= #1 EMPTY;
    end
end

// ========== Input latch ==========
always @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        dIn_mem      <= #1 '{default:'0};                     // [J-unopt-reset]
        delta_A_mem  <= #1 '{default:'0};                     // [J-unopt-reset]
        delta_B_mem  <= #1 '{default:'0};                     // [J-unopt-reset]
        matrix_C_mem <= #1 '{default:'0};                     // [J-unopt-reset]
    end else if (s_handshaking) begin                         // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        dIn_mem      <= #1 dIn;
        delta_A_mem  <= #1 delta_A;
        delta_B_mem  <= #1 delta_B;
        matrix_C_mem <= #1 matrix_C;
    end
end

// ---------- ---------- ---------- ---------- [J-WB] matrix_D Broadcast ---------- ---------- ---------- ----------
localparam integer D_BYTES = ((NUM_DIM_1 + 3) / 4) * 4;       // 40 -> 40
localparam integer D_IDX_W = $clog2(D_BYTES + 1);

logic [D_IDX_W-1:0] d_byte;

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

logic d_hit, d_first;   // [J-WBPIPE] stage1 레지스터 (기존 wire 대체)
always @(posedge clk) begin
    if (!nRst) begin
        d_hit           <= #1 1'b0;
        d_first         <= #1 1'b0;
    end else begin
        d_hit           <= #1 wb_v_q && (wb_a_q >= WB_BASE_W) && (wb_a_q < WB_BASE_W + D_BYTES);
        d_first         <= #1 wb_v_q && (wb_a_q == WB_BASE_W);
    end
end

wire [D_IDX_W-1:0] d_now = d_first ? '0 : d_byte;

always @(posedge clk) begin
    if (!nRst) begin
        matrix_D_mem <= #1 '{default:'0};
        d_byte       <= #1 '0;
    end else if (d_hit) begin
        for (int b = 0; b < 4; b++)
            if (d_now + b < NUM_DIM_1)
                matrix_D_mem[d_now + b] <= #1 wb_d_q2[b*8 +: 8];
        d_byte <= #1 d_now + 'd4;
    end
end
// ========== ========== ========== ========== [J-WB] matrix_D Broadcast ========== ========== ========== ==========

// ========== Output ==========
always @(posedge clk) begin
    if (!nRst)
        for (i = 0; i < NUM_DIM_1; i = i + 1)
            dOut[i] <= #1 'd0;
    else if (v_y)                                      // [J-Timing] (COMPUTING||WAIT) && delayed_1 -> 패킷 v_d3 / col_d3
        dOut[col_y] <= #1 output_y;                    // [J-ytree-tag] v_d3/col_d3 -> 자식이 돌려준 v_y/col_y
end

// ========== [J-Timing] 패킷 shift ==========
// [J-ytree-tag] _d3 삭제. _d2 는 SSM_y_compute_FF 의 v_in/col_in 으로 들어가 데이터와 같이 이동
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        v_d1 <= #1 1'b0; v_d2 <= #1 1'b0;
        fl_d1 <= #1 1'b0;
        col_d1 <= #1 '0; col_d2 <= #1 '0;              // [J-unopt-reset] col_d* 도 리셋
    end
    else begin
        v_d1   <= #1 (curr_state == COMPUTING);        // A1 발행
        col_d1 <= #1 curr_dIn_column;
        fl_d1  <= #1 frame_last;
        v_d2   <= #1 v_d1;   col_d2 <= #1 col_d1;
    end
end



// ---------- ---------- ---------- ---------- Data Processing Logic ---------- ---------- ---------- ----------

// ========== stage1 : x[k+1] ==========
SSM_xkP1_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(NUM_SCALE_DELTA_B),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .DATA_WIDTH_BU(DATA_WIDTH_BU),
    .DATA_WIDTH_BU_LSH(DATA_WIDTH_BU_LSH),
    .DATA_WIDTH_AX(DATA_WIDTH_AX),
    .DATA_WIDTH_XKP1(DATA_WIDTH_XKP1),
    .DATA_WIDTH_XKP1_RSH(DATA_WIDTH_XKP1_RSH)
) SSM_xkP1_compute (
    .clk                (clk),                          // [J-Timing]
    .nRst               (nRst),                         // [J-unopt-reset]
    .dIn                (dIn_mem[curr_dIn_column]),     //input Data Scalar
    .delta_A            (delta_A_mem[curr_dIn_column]), //input Data 1D
    .delta_B            (delta_B_mem[curr_dIn_column]), //input Data 1D
    .xk                 (xk_ssm_state[curr_dIn_column]), //input Data 1D

    .xkP1               (xkP1_compute_dOut), //output Data 1D
    .xkP1_right_shifted (xkP1_right_shifted) //output Data 1D
);

// ========== Hidden state (xk_ssm_state) ==========
// [J] sequence end then frame_last initialize. (x[k+1] -> x[k] update)
//     if frame_last, xk_ssm_state reset to 0
always @(posedge clk) begin
    if (!nRst || ps_start)
        for (int i = 0; i < NUM_DIM_1; i++)
            for (int j = 0; j < NUM_DIM_2; j++)
                xk_ssm_state[i][j] <= #1 'd0;
    // [J-Timing] 쓰기가 A2 (발행 +1) 로 밀림. column 은 토큰당 한 번만 읽고 쓰므로 의존 안 깨짐.
    //            frame_last 클리어도 같이 1 cycle 늦춰(fl_d1) 마지막 column 의 늦은 쓰기가 클리어 뒤에 남지 않게 한다.
    //            (기존: curr_state==COMPUTING && frame_last / curr_dIn_column)
    else if (fl_d1)
        for (int i = 0; i < NUM_DIM_1; i++)
            for (int j = 0; j < NUM_DIM_2; j++)
                xk_ssm_state[i][j] <= #1 'd0;
    else if (v_d1) // [J] sustain xk_ssm_state until "frame_last" :: [legacy] index delay
        xk_ssm_state[col_d1] <= #1 xkP1_right_shifted;
end

// ========== stage1 -> stage2 pipeline registers ==========
// [J] data delay to avoid last_cycle overwrite of *_mem :: [legacy] index delay 
// [J-Timing] 리셋 없음 — 값은 v_d* 가 0 이면 버려지고, Y1 의 DSP 가 이 FF 를 A/B 레지스터로 흡수하게 둔다.
// [J-unopt-reset] 위 "[J-Timing] 리셋 없음" 은 va_1_unoptimized_reset 에서 해제 — 모든 posedge clk FF 에 nRst 동기 리셋 (DSP A/B 레지스터 흡수 안 될 수 있음)
always @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        dIn_delayed_1               <= #1 '0;                 // [J-unopt-reset]
        matrix_D_delayed_1          <= #1 '0;                 // [J-unopt-reset]
        matrix_C_delayed_1          <= #1 '{default:'0};      // [J-unopt-reset]
        dIn_delayed_2               <= #1 '0;                 // [J-unopt-reset]
        matrix_D_delayed_2          <= #1 '0;                 // [J-unopt-reset]
        matrix_C_delayed_2          <= #1 '{default:'0};      // [J-unopt-reset]
        xkP1_compute_dOut_delayed_2 <= #1 '{default:'0};      // [J-unopt-reset]
    end else begin                                            // [J-unopt-reset]
    // A1 에지: mux 출력을 잡는다 (last_cycle 에 *_mem 이 새 토큰으로 바뀌어도 여기서 옛 값이 확정됨)
    dIn_delayed_1      <= #1 dIn_mem[curr_dIn_column];
    matrix_D_delayed_1 <= #1 matrix_D_mem[curr_dIn_column];
    matrix_C_delayed_1 <= #1 matrix_C_mem;
    // A2 에지: 한 단 더 (xkP1 은 SSM_xkP1_compute 안에서 이미 1 단 지났으므로 여기서 1 단만)
    dIn_delayed_2               <= #1 dIn_delayed_1;
    matrix_D_delayed_2          <= #1 matrix_D_delayed_1;
    matrix_C_delayed_2          <= #1 matrix_C_delayed_1;
    xkP1_compute_dOut_delayed_2 <= #1 xkP1_compute_dOut;
    end                                                       // [J-unopt-reset]
end

// ========== stage2 : y ==========
SSM_y_compute #(                       // [J-ytree-ff] SSM_y_compute -> SSM_y_compute_FF
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(NUM_SCALE_DELTA_B),
    .NUM_SCALE_C(NUM_SCALE_C),
    .NUM_SCALE_D(NUM_SCALE_D),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .DATA_WIDTH_XKP1(DATA_WIDTH_XKP1),

    .COL_WIDTH(ED_CNT_WIDTH)                  // [J-ytree-tag]
) SSM_y_compute (
    .clk        (clk),                //input [J-Timing]
    .nRst       (nRst),               // [J-unopt-reset]
    .ps_start   (ps_start),           // [J-ytree-tag] 태그 valid 클리어

    .v_in       (v_d2),               // [J-ytree-tag] 데이터 (*_delayed_2) 와 같은 cycle 의 태그
    .col_in     (col_d2),             // [J-ytree-tag]
    .dIn        (dIn_delayed_2),      //input Data Scalar   [J-Timing] _1 -> _2
    .matrix_C   (matrix_C_delayed_2), //input Data 1D       [J-Timing]
    .matrix_D   (matrix_D_delayed_2), //input Data Scalar   [J-Timing]
    .xkP1       (xkP1_compute_dOut_delayed_2), //input Data 1D [J-Timing]

    .v_out      (v_y),                // [J-ytree-tag] output_y 와 같은 cycle 의 태그
    .col_out    (col_y),              // [J-ytree-tag]
    .dOut_8bit  (output_y) //output Data Scalar
);

// [J-ytree-tag] 마지막 column 이 출력에 도착 -> 이 에지에 dOut[ED-1] 쓰기 + WAIT -> DONE
assign y_last = v_y && (col_y == NUM_DIM_1-1);
// ========== ========== ========== ========== Data Processing Logic ========== ========== ========== ==========

// ========== FSM ==========
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

// [J-Timing] WAIT 체류 카운터
// always @(posedge clk) begin
//     if (!nRst || ps_start)          drain_cnt <= #1 '0;
//     else if (curr_state == WAIT)    drain_cnt <= #1 drain_cnt + 1'b1;
//     else                            drain_cnt <= #1 '0;
// end
// ↑ 삭제 : [J-ytree-tag] WAIT 탈출을 자식 태그 (y_last) 로. 파이프 단수를 셀 필요 없음

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        INIT: begin
            if (dIn_stat == LOAD)
                next_state = COMPUTING;
        end

        COMPUTING: begin
            if (last_cycle)
                next_state = WAIT;
        end

        // [J] stage2 last column dOut write
        // [J-Timing] 마지막 column 이 파이프(SSM_PIPE 단)를 다 지나 dOut 에 써진 뒤 DONE
        // WAIT: if (drain_cnt == SSM_PIPE-1) next_state = DONE;
        // ↑ 삭제 : [J-ytree-tag] 마지막 column 태그가 출력에 도착한 cycle 에 DONE (같은 에지에 dOut[ED-1] 쓰기)
        WAIT: if (y_last) next_state = DONE;

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

// ========== ED / token 카운터 ==========
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        curr_seq_idx    <= #1 'd0;
        curr_dIn_column <= #1 'd0;
    end
    else begin
        curr_seq_idx    <= #1 next_seq_idx;
        curr_dIn_column <= #1 next_dIn_column;
    end
end

always @(*) begin
    next_seq_idx    = curr_seq_idx;
    next_dIn_column = curr_dIn_column;

    case (curr_state)
        INIT: begin
            next_dIn_column = 'd0;
        end

        COMPUTING: begin
            if (!last_cycle) begin
                next_dIn_column = curr_dIn_column + 1;
            end
            else begin
                // [J] 마지막 토큰(L-1) ED sweep 후 row=0
                next_seq_idx    = (curr_seq_idx == NUM_SEQLEN-1) ? 'd0 : (curr_seq_idx + 1);
                next_dIn_column = 'd0;
            end
        end

        default: begin
            next_seq_idx    = curr_seq_idx;
            next_dIn_column = curr_dIn_column;
        end
    endcase
end


endmodule
