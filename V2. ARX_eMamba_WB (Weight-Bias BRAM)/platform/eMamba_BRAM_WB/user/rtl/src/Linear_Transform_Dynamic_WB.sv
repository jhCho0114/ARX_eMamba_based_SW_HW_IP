`timescale 1ns / 1ps
// -=--=-=-=-=-=-=- BRAM WB Loader ADDED -=--=-=-=-=-=-=-
module Linear_Transform_Dynamic_WB #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_SEQLEN  = 16,   // 정보용 (내부 미사용)
    parameter integer NUM_DIM_IN  = 40,   // 내적(입력) 차원
    parameter integer NUM_DIM_OUT = 32,   // 출력 차원

    parameter bit USE_BIAS      = 1'b0,
    parameter bit USE_ACTIVATOR = 1'b1,   // 1: 재양자화+포화 (8bit 출력)

    parameter integer NUM_SCALE_DIN    = 5,
    parameter integer NUM_SCALE_WEIGHT = 8,
    parameter integer NUM_SCALE_BIAS   = 8, // USE_BIAS=1일 때만 의미 있음
    parameter integer NUM_SCALE_DOUT   = 6, // USE_ACTIVATOR=1일 때만 의미 있음
    // parameter integer PIPE_STAGE       = 3, //[J-addertree-ff] MatMult 경계 FF 위치 (CLA stage)
    //[J-mm-ff] ↑ 삭제 : 트리 stage 마다 FF

    // [J-WB] ---------- wb loader ----------
    parameter string  LOG_NAME  = "",
    parameter integer WB_ADDR_W = 15,     // wb_addr 폭. eMamba_IP 의 WB_BRAM_ADDR_W 와 같게
    parameter integer WB_BASE_W = 0      // weight 창의 첫 워드 번호,  BIAS 주소는 내부 계산해
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    wb_valid,
    wb_addr,
    wb_data,

    s_valid, // input
    m_ready, // input
    s_ready, // output
    m_valid //output
);

// [J] Local Parameters
// [J-V6] COMPUTING -> MULT / ADD: 한 열을 곱셈 cycle + 덧셈(CLA 트리) cycle 로 나눔
// [J-mm-ff] MULT / ADD -> COMPUTING / WAIT : 매 cycle 한 열 발행, WAIT 에서 마지막 열 도착 대기
localparam INIT      = 'd0,
           COMPUTING = 'd1,   // [J-mm-ff] weight[col] x dIn 발행 (col 매 cycle 증가)
           WAIT      = 'd2,   // [J-mm-ff] 마지막 열이 MatMult 파이프를 빠져나올 때까지
           DONE      = 'd3;

localparam  EMPTY = 1'b0,
            LOAD = 1'b1;

// MatMult_Dynamic의 출력 폭 계산
localparam integer NUM_ELEM           = USE_BIAS ? NUM_DIM_IN + 1 : NUM_DIM_IN;
localparam bit     DIN_UPSCALE        = USE_BIAS && ((NUM_SCALE_DIN + NUM_SCALE_WEIGHT) < NUM_SCALE_BIAS);
localparam integer NUM_LSH_DIN        = NUM_SCALE_BIAS - (NUM_SCALE_DIN + NUM_SCALE_WEIGHT);
localparam integer DATA_WIDTH_DIN_LSH = DATA_WIDTH + (DIN_UPSCALE ? NUM_LSH_DIN : 0);
localparam integer DATA_WIDTH_SUM     = DATA_WIDTH_DIN_LSH + DATA_WIDTH + $clog2(NUM_ELEM);

// 재양자화 시프트 비트 = 누산값 스케일 - 목표 스케일
//  - DIN_UPSCALE=1 : 누산값 스케일 = NUM_SCALE_BIAS
//  - DIN_UPSCALE=0 : 누산값 스케일 = NUM_SCALE_DIN + NUM_SCALE_WEIGHT
localparam integer NUM_RSH_DOUT = DIN_UPSCALE ? (NUM_SCALE_BIAS - NUM_SCALE_DOUT)
                                              : (NUM_SCALE_DIN + NUM_SCALE_WEIGHT - NUM_SCALE_DOUT);

// activator를 쓰면 8bit, 안 쓰면 그냥있는 누산값 폭
localparam integer DATA_WIDTH_OUT = USE_ACTIVATOR ? DATA_WIDTH : DATA_WIDTH_SUM;

// 출력 열 카운터 폭
localparam integer CNT_WIDTH = ($clog2(NUM_DIM_OUT) > 0) ? $clog2(NUM_DIM_OUT) : 1;

// [J-WB] ---------- broadcast 수신용 constants ----------
localparam integer WEIGHT_BYTES = NUM_DIM_OUT * NUM_DIM_IN;
localparam integer BIAS_BYTES   = ((NUM_DIM_OUT + 3) / 4) * 4;  // bias 창 워드 수 (57 -> 15, 마지막은 부분 워드)
localparam integer WB_BASE_B    = WB_BASE_W + WEIGHT_BYTES;
localparam integer COL_WIDTH    = $clog2(NUM_DIM_IN);


// [J] I/O Ports
input clk, nRst;

input ps_start;

input  logic signed [DATA_WIDTH-1:0]     dIn  [0:NUM_DIM_IN-1];
output logic signed [DATA_WIDTH_OUT-1:0] dOut [0:NUM_DIM_OUT-1];

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

input  s_valid, m_ready;
output s_ready, m_valid;

// [J] Internal Variables
logic [1:0] curr_state,
            next_state;

logic [CNT_WIDTH-1:0] curr_weight_column,
                      next_weight_column;

logic signed [DATA_WIDTH-1:0]     matMult_bias;
logic signed [DATA_WIDTH_SUM-1:0] matMult_dOut;  // MatMult_Dynamic 원시 누산 출력
logic signed [DATA_WIDTH_OUT-1:0] result;        // 재양자화(또는 원시) 최종 결과

logic signed [DATA_WIDTH-1:0] dIn_mem    [0:NUM_DIM_IN-1];
logic signed [DATA_WIDTH-1:0] weight_mem [0:NUM_DIM_OUT-1][0:NUM_DIM_IN-1];
logic signed [DATA_WIDTH-1:0] bias_mem   [0:NUM_DIM_OUT-1];

logic                 mm_v;     // [J-mm-tag] matMult_dOut valid
logic [CNT_WIDTH-1:0] mm_col;   // [J-mm-tag] matMult_dOut 의 열
logic                 mm_last;  // [J-mm-tag] 마지막 열이 출력에 도착

logic dIn_stat;
logic last_cycle;

logic s_handshaking, m_handshaking;

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign s_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid  = (curr_state == DONE);

// assign last_cycle = (curr_state == ADD) && (curr_weight_column == NUM_DIM_OUT-1); // [J-V6] COMPUTING -> ADD (마지막 열의 덧셈 cycle)
assign last_cycle = (curr_state == COMPUTING) && (curr_weight_column == NUM_DIM_OUT-1); // [J-mm-ff] 마지막 열 발행 cycle

// [J] get input data
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        dIn_stat <= #1 EMPTY;
    end else begin                                        // [J-RST] else + 안쪽 if 로 재구성 (회로 동일)
        if (s_handshaking)   dIn_stat <= #1 LOAD;
        else if (last_cycle) dIn_stat <= #1 EMPTY;
        else                 dIn_stat <= #1 dIn_stat;     // [J-RST] hold 명시
    end
end

// [J-WB] dIn_mem 만 초기화
always @(posedge clk) begin
    if (!nRst) begin
        dIn_mem <= #1 '{default:'0};                      // [J-unopt-reset]
    end else if (s_handshaking) begin
        dIn_mem <= #1 dIn;
    end else begin                                        // [J-RST] hold 명시
        dIn_mem <= #1 dIn_mem;
    end
end

// ---------- ---------- ---------- ---------- [J-WB] Weight Broadcast  ---------- ---------- ---------- ----------
//   loader가 내보내는 (wb_valid, wb_addr, wb_data) 를 받기만하다가, 
//   wb_addr 이 내 범위 안이면
//   32bit 워드 하나를 8bit 4개로 쪼개 weight_mem 의 연속된 4열
//
//   my_weight_hit   : 지금 loader의 broadcast가 내 꺼야. wb_valid 를 AND
//   my_first_weight : 내 꺼의 첫 워드. 카운터를 0 초기화, "창 진입"
//   r_now/c_now : my_first_weight 인 클럭에는 레지스터가 아직 옛 값이라 조합으로 덮어써ㅓ
// ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ---------- ----------
logic [CNT_WIDTH-1:0] w_row;
logic [COL_WIDTH-1 :0] w_col;

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

logic my_weight_hit, my_first_weight;   // [J-WBPIPE] stage1 레지스터 (기존 wire 대체)
always @(posedge clk) begin
    if (!nRst) begin
        my_weight_hit   <= #1 1'b0;
        my_first_weight <= #1 1'b0;
    end else begin
        my_weight_hit   <= #1 wb_v_q && (wb_a_q >= WB_BASE_W) && (wb_a_q < WB_BASE_W + WEIGHT_BYTES);
        my_first_weight <= #1 wb_v_q && (wb_a_q == WB_BASE_W);
    end
end

wire [CNT_WIDTH -1:0] r_now = my_first_weight ? '0 : w_row;
wire [COL_WIDTH -1:0] c_now = my_first_weight ? '0 : w_col;

always @(posedge clk) begin
    if (!nRst) begin
        weight_mem <= #1 '{default:'0};
    end else if (my_weight_hit) begin
        weight_mem[r_now][c_now ]     <= #1 wb_d_q2[7 : 0];
        weight_mem[r_now][c_now  + 1] <= #1 wb_d_q2[15 : 8];
        weight_mem[r_now][c_now  + 2] <= #1 wb_d_q2[23 : 16];
        weight_mem[r_now][c_now  + 3] <= #1 wb_d_q2[31 : 24];
    end
    else begin
        weight_mem <= #1 weight_mem;  // [J-RST] hold 명시
    end
end

always @(posedge clk) begin
    if (!nRst) begin
        w_row      <= #1 '0;
        w_col      <= #1 '0;
    end else if (my_weight_hit) begin
        if (c_now == NUM_DIM_IN - 4) begin
            w_col <= #1 '0;
            w_row <= #1 r_now + 1'b1;
        end else begin
            w_col <= #1 c_now + 'd4;
            w_row <= #1 r_now;
        end
    end
end

generate
if (USE_BIAS) begin : WB_Bias_USE_BIAS
    localparam integer BIDX_W = $clog2(BIAS_BYTES  + 1);

    logic [BIDX_W-1:0] b_byte;

    logic b_hit, b_first;   // [J-WBPIPE] stage1 레지스터 (기존 wire 대체)
    always @(posedge clk) begin
        if (!nRst) begin
            b_hit           <= #1 1'b0;
            b_first         <= #1 1'b0;
        end else begin
            b_hit           <= #1 wb_v_q && (wb_a_q >= WB_BASE_B) && (wb_a_q < WB_BASE_B + BIAS_BYTES);
            b_first         <= #1 wb_v_q && (wb_a_q == WB_BASE_B);
        end
    end

    wire [BIDX_W-1:0] b_now = b_first ? '0 : b_byte;

    always @(posedge clk) begin
        if (!nRst) begin
            bias_mem <= #1 '{default:'0};
            b_byte   <= #1 '0;
        end else if (b_hit) begin
            for (int b = 0; b < 4; b++)
                if (b_now + b < NUM_DIM_OUT)            // 마지막 워드의 남는 바이트는 버려
                    bias_mem[b_now + b] <= #1 wb_d_q2[b*8 +: 8];

            b_byte <= #1 b_now + 'd4;
        end
    end
end else begin : WB_Bias_NO_BIAS
    always @(posedge clk) begin
        if (!nRst) bias_mem <= #1 '{default:'0};
    end
end
endgenerate
// ========== ========== ========== ========== [J-WB] Weight Broadcast Sink ========== ========== ========== ==========

// [J] Final output
always @(posedge clk) begin
    if (!nRst) begin
        dOut <= #1 '{default:'0};                         // [J-RST]
    end else begin
        if (mm_v)                                         // [J-mm-tag] (curr_state == ADD) -> 태그
            dOut[mm_col] <= #1 result;                    // [J-mm-tag] curr_weight_column -> mm_col
        else
            dOut <= #1 dOut;                              // [J-RST] hold 명시
    end
end


// ---------- ---------- ---------- ---------- Data Processing Logic ---------- ---------- ---------- ----------
// [J] Submodule: 내적 엔진
MatMult_Dynamic #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_IN),
    .USE_BIAS(USE_BIAS),
    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(NUM_SCALE_BIAS),

    .COL_WIDTH(CNT_WIDTH)             // [J-mm-tag]
) MatMult (
    .clk(clk),                        // [J-V6]
    .nRst(nRst),                      // [J-unopt-reset]
    .ps_start(ps_start),              // [J-mm-tag] 태그 valid 클리어

    .v_in(curr_state == COMPUTING),   // [J-mm-tag] prod_en 삭제 -> 발행 cycle 태그
    .col_in(curr_weight_column),      // [J-mm-tag]
    .dIn(dIn_mem),
    .weight(weight_mem[curr_weight_column]),   // [J-WB] 읽는 쪽은 원본 그대로
    .bias(matMult_bias),

    .v_out(mm_v),                     // [J-mm-tag] matMult_dOut 과 같은 cycle 의 태그
    .col_out(mm_col),                 // [J-mm-tag]
    .dOut(matMult_dOut)
);

// [J-mm-tag] 마지막 열이 출력에 도착 -> 이 에지에 dOut[NUM_DIM_OUT-1] 쓰기 + WAIT -> DONE
assign mm_last = mm_v && (mm_col == NUM_DIM_OUT-1);

generate
    if (USE_BIAS) begin: Bias_Sel
        assign matMult_bias = bias_mem[curr_weight_column];
    end else begin: Bias_Tie
        assign matMult_bias = '0;
    end
endgenerate

// [J] Submodule: 재양자화 + 포화
generate
    if (USE_ACTIVATOR) begin: Out_Activator
        activator #(
            .DATA_WIDTH(DATA_WIDTH_SUM),
            .NUM_RSH_DOUT(NUM_RSH_DOUT)
        ) activator_dOut (
            .dIn(matMult_dOut),
            .dOut(result)
        );
    end else begin: Out_Raw
        assign result = matMult_dOut;
    end
endgenerate
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
                next_state = COMPUTING;           // [J-mm-ff] MULT -> COMPUTING
        end

        // MULT: next_state = ADD;                   // [J-V6] 곱셈 1 cycle 후 덧셈으로
        // ADD: 마지막 열이면 DONE, 아니면 다음 열 MULT
        // ↑ 삭제 : [J-mm-ff] 매 cycle 한 열 발행, 마지막 열 발행 후 WAIT
        COMPUTING: begin
            if (last_cycle)
                next_state = WAIT;
        end

        // [J-mm-tag] 마지막 열 태그가 MatMult 출력에 도착한 cycle 에 DONE (같은 에지에 dOut[NUM_DIM_OUT-1] 쓰기)
        WAIT: if (mm_last) next_state = DONE;

        DONE: begin
            if (m_handshaking) begin
                if (dIn_stat == LOAD)
                    next_state = COMPUTING;       // [J-mm-ff] MULT -> COMPUTING
                else
                    next_state = INIT;
            end
        end

        default: next_state = INIT;
    endcase
end
// ========== ========== ========== ========== FSM ========== ========== ========== ==========

// ---------- ---------- ---------- ---------- Compute row ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_weight_column <= #1 'd0;
    else
        curr_weight_column <= #1 next_weight_column;
end

always @(*) begin
    next_weight_column = curr_weight_column;

    case (curr_state)
        INIT:       next_weight_column = 'd0;
        // MULT:       next_weight_column = curr_weight_column;                        // [J-V6] 곱셈 cycle 동안 열 유지
        // ADD:        next_weight_column = last_cycle ? 'd0 : (curr_weight_column + 1); // [J-V6] COMPUTING -> ADD
        COMPUTING:  next_weight_column = last_cycle ? 'd0 : (curr_weight_column + 1); // [J-mm-ff] 매 cycle 다음 열
        WAIT:       next_weight_column = 'd0;                                         // [J-mm-ff]
        DONE:       next_weight_column = 'd0;
        default:    next_weight_column = 'd0;
    endcase
end
// ========== ========== ========== ========== Compute row ========== ========== ========== ==========

// ---------- [J_LOG] WB dump (로드 완료 후 1회) ----------
integer jlog_fd, jlog_r, jlog_c;
always @(posedge clk) begin
    if (nRst && ps_start && (LOG_NAME.len() != 0)) begin
        // weight: 행(NUM_DIM_OUT)마다 한 줄, 열(NUM_DIM_IN) 콤마 구분
        jlog_fd = $fopen({U_log_pkg::LOG_DIR, "/", LOG_NAME, "_w.txt"}, "w");
        if (jlog_fd) begin
            for (jlog_r = 0; jlog_r < NUM_DIM_OUT; jlog_r = jlog_r + 1) begin
                for (jlog_c = 0; jlog_c < NUM_DIM_IN; jlog_c = jlog_c + 1) begin
                    $fwrite(jlog_fd, "%0d", weight_mem[jlog_r][jlog_c]);
                    if (jlog_c == NUM_DIM_IN-1) $fwrite(jlog_fd, "\n");
                    else                        $fwrite(jlog_fd, ",");
                end
            end
            $fclose(jlog_fd);
        end
        if (jlog_fd == 0) begin
            $display("Error opening file.");
            $finish;
        end
        // bias (USE_BIAS=1일 때만)
        if (USE_BIAS) begin
            jlog_fd = U_log_pkg::opn({LOG_NAME, "_b.txt"});
            if (jlog_fd) begin
                for (jlog_c = 0; jlog_c < NUM_DIM_OUT; jlog_c = jlog_c + 1) begin
                    $fwrite(jlog_fd, "%0d", bias_mem[jlog_c]);
                    if (jlog_c == NUM_DIM_OUT-1) $fwrite(jlog_fd, "\n");
                    else                         $fwrite(jlog_fd, ",");
                end
                $fclose(jlog_fd);
            end
        end
    end
end
endmodule
