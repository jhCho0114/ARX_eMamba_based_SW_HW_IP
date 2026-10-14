`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: U_SSM_Preprocess
// Description: SSM 전처리 (x_proj delta / x_proj B / x_proj C / dt_proj / ReLU / 이산화).
//              선형 계층은 Linear_Transform_Dynamic 사용.
//              x_proj 가중치는 unpacked array 슬라이스로 직접 연결.
//////////////////////////////////////////////////////////////////////////////////

module U_SSM_Preprocess #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 40, // ED
    parameter integer NUM_DIM_2  = 8,  // N

    parameter integer NUM_DIM_DELTA     = 32, // J added

    parameter integer LIN_DBC_DELTA_W_BASE = 0,
    parameter integer LIN_DBC_B_W_BASE = 0,
    parameter integer LIN_DBC_C_W_BASE = 0,
    parameter integer LIN_DELTA_W_BASE = 0,
    parameter integer SSM_A_BASE = 0,
    parameter integer WB_ADDR_W = 15,

    // Linear expand dBC delta
    parameter integer LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 6,

    // Linear expand dBC B
    parameter integer LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer LINEX_DBC_B_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DBC_B_NUM_SCALE_DOUT   = 6,

    // Linear expand dBC C
    parameter integer LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer LINEX_DBC_C_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DBC_C_NUM_SCALE_DOUT   = 5,

    // Linear expand delta (dt_proj)
    parameter integer LINEX_DELTA_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 3,
    parameter integer DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 6,
    parameter integer DIMEX_DELTA_B_NUM_SCALE_DOUT  = 3,

    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    dIn,

    delta_A,
    delta_B,
    matrix_C,

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    wb_valid,
    wb_addr,
    wb_data,

    s_valid, // input
    s_ready, // output

    m_ready, // input
    m_valid //output
);

// ========== Local Parameters ==========
localparam integer NUM_DIM_DBC       = NUM_DIM_DELTA + NUM_DIM_2 * 2; 
localparam integer IDX_BC_B_START    = NUM_DIM_DELTA;                 
localparam integer IDX_BC_C_START    = NUM_DIM_DELTA + NUM_DIM_2;     

localparam AVAIL = 1'b0;
// ========== I/O Ports ==========
input clk, nRst;

input ps_start;

input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM_1-1];

output logic signed [DATA_WIDTH-1:0] delta_A  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
output logic signed [DATA_WIDTH-1:0] delta_B  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
output logic signed [DATA_WIDTH-1:0] matrix_C [0:NUM_DIM_2-1];

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

input  s_valid, m_ready;
output s_ready, m_valid;

// ========== Internal Signals ==========
logic signed [DATA_WIDTH-1:0] linEx_dBC_delta_dOut [0:NUM_DIM_DELTA-1];

logic signed [DATA_WIDTH-1:0] linEx_dBC_B_dOut      [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] linEx_dBC_B_aligned   [0:NUM_DIM_2-1]; // [J] Ring_Buffer 출력

logic signed [DATA_WIDTH-1:0] linEx_dBC_C_dOut      [0:NUM_DIM_2-1];

logic signed [DATA_WIDTH-1:0] linEx_delta_dOut [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] ReLU_dOut        [0:NUM_DIM_1-1];

logic signed [DATA_WIDTH-1:0] dimEx_delta_B_dOut [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

logic linEx_dBC_delta_s_ready, linEx_dBC_delta_m_valid;
logic linEx_dBC_B_s_ready,     linEx_dBC_B_m_valid;
logic linEx_dBC_C_s_ready,     linEx_dBC_C_m_valid;

logic linEx_delta_s_ready, linEx_delta_m_valid;

logic delta_B_s_ready, delta_B_m_valid;

logic pEXP_s_ready, pEXP_m_valid;

// [J] Ring_Buffer backpressure — LinTrans_dBC_B/C 's m_ready
logic B_buf_full, C_buf_full;

// [J-FORK] fork bookkeeping (see Fork_Ack)
logic [2:0] fork_in_cv;      // entrance fork : [0]=LinTrans_dBC_delta, [1]=LinTrans_dBC_B, [2]=LinTrans_dBC_C
logic [1:0] fork_dl_cv;      // delta fork    : [0]=Exp_piecewise, [1]=dim_expand_delta_B
logic       fork_dl_pready;

// [J] 3 branch share s_valid 
// [J-FORK] s_ready is driven by fork_in.p_ready (was delta_s_ready & B_s_ready & C_s_ready)
// [J] the last-output join. 
// dim_expand_delta_B 는 payload 당 ED=384 clk, Exp 보다 한참 늦어, 
//     (matrix_C 는 Ring_Buffer 가 backpressure 를 맡아 늘 앞서 있으므로 the last-output join 에 안 껴)
assign m_valid = pEXP_m_valid & delta_B_m_valid;

// [J-FORK] entrance fork : dIn token -> {LinTrans_dBC_delta, LinTrans_dBC_B, LinTrans_dBC_C}
Fork_Ack #(.N(3)) fork_in (
    .clk(clk), .nRst(nRst), .ps_start(ps_start),
    .p_valid(s_valid), .p_ready(s_ready),
    .c_valid(fork_in_cv),
    .c_ready({linEx_dBC_C_s_ready, linEx_dBC_B_s_ready, linEx_dBC_delta_s_ready}),
    .advance()
);

// [J-FORK] delta fork : LinTrans_delta -> {Exp_piecewise, dim_expand_delta_B}
Fork_Ack #(.N(2)) fork_dl (
    .clk(clk), .nRst(nRst), .ps_start(ps_start),
    .p_valid(linEx_delta_m_valid), .p_ready(fork_dl_pready),
    .c_valid(fork_dl_cv),
    .c_ready({delta_B_s_ready, pEXP_s_ready}),
    .advance()
);

// ========== Submodules ==========

// x_proj B (ED ->  N, bias 없음)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_1),
    .NUM_DIM_OUT(NUM_DIM_2),

    .USE_BIAS(1'b0),
    .USE_ACTIVATOR(1'b1),

    .NUM_SCALE_DIN(LINEX_DBC_B_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .NUM_SCALE_DOUT(LINEX_DBC_B_NUM_SCALE_DOUT),

    .LOG_NAME("WB_SSM_LinTrans_dBC_B"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LIN_DBC_B_W_BASE)
) LinTrans_dBC_B (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(linEx_dBC_B_dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(fork_in_cv[1]), // [J-FORK] was s_valid
    .s_ready(linEx_dBC_B_s_ready), // output

    .m_ready( B_buf_full == AVAIL ), // input
    .m_valid(linEx_dBC_B_m_valid) // output
);

// x_proj C (ED ->  N, bias 없음)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_1),
    .NUM_DIM_OUT(NUM_DIM_2),

    .USE_BIAS(1'b0),
    .USE_ACTIVATOR(1'b1),

    .NUM_SCALE_DIN(LINEX_DBC_C_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .NUM_SCALE_DOUT(LINEX_DBC_C_NUM_SCALE_DOUT),

    .LOG_NAME("WB_SSM_LinTrans_dBC_C"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LIN_DBC_C_W_BASE)
) LinTrans_dBC_C (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(linEx_dBC_C_dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(fork_in_cv[2]), // [J-FORK] was s_valid
    .s_ready(linEx_dBC_C_s_ready), // output

    .m_ready( C_buf_full == AVAIL ), // input
    .m_valid(linEx_dBC_C_m_valid) // output
);

// [J] matrix_C token result store:  LinTrans_dBC_C (16 clk) 가 delta 경로
//     (dBC_delta 12 -> delta 384 -> Exp_piecewise) 보다 훨씬 먼저 끝나므로 버퍼링이 필요해.
//     C 의 출구 전송 -> push,  Preprocess 자신의 출구 전송 = pop.
Ring_Buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),
    .DEPTH_POWER_2(4)  // hard coded 4
)Matrix_C_Ring_Buffer(
    .clk(clk), 
    .nRst(nRst), 

    .ps_start(ps_start),

    // [J] C 자신의 출구 -> (m_ready & linEx_dBC_C_m_valid)
    .push(linEx_dBC_C_m_valid & (C_buf_full == AVAIL) ), 
    .pop(m_valid & m_ready),

    .dIn(linEx_dBC_C_dOut) ,
    .dOut(matrix_C),

    .full(C_buf_full), 
    .empty()
);


// x_proj delta (ED ->  dt_rank, bias 없음)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_1),
    .NUM_DIM_OUT(NUM_DIM_DELTA),

    .USE_BIAS(1'b0),
    .USE_ACTIVATOR(1'b1),

    .NUM_SCALE_DIN(LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .NUM_SCALE_DOUT(LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    .LOG_NAME("WB_SSM_LinTrans_dBC_delta"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LIN_DBC_DELTA_W_BASE)
) LinTrans_dBC_delta (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(linEx_dBC_delta_dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),


    .s_valid(fork_in_cv[0]), // [J-FORK] was s_valid
    .s_ready(linEx_dBC_delta_s_ready), // output

    .m_ready(linEx_delta_s_ready), // input
    .m_valid(linEx_dBC_delta_m_valid) // output
);

// dt_proj (dt_rank ->  ED, bias 있음)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_DELTA),
    .NUM_DIM_OUT(NUM_DIM_1),

    .USE_BIAS(1'b1),
    .USE_ACTIVATOR(1'b1),

    .NUM_SCALE_DIN(LINEX_DELTA_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_DELTA_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_DELTA_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_DELTA_NUM_SCALE_DOUT),

    .LOG_NAME("WB_SSM_LinTrans_delta"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LIN_DELTA_W_BASE)
) LinTrans_delta (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(linEx_dBC_delta_dOut),
    .dOut(linEx_delta_dOut),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(linEx_dBC_delta_m_valid), // input
    .s_ready(linEx_delta_s_ready), // output

    // [J] F5: linEx_delta_dOut -> ReLU -> Exp_piecewise 와 U_Dim_expand_delta_B 로 갈라져.
    //     dim_expand can miss tokens if pEXP_s_ready is only the input signal
    .m_ready(fork_dl_pready), // [J-FORK] was pEXP_s_ready & delta_B_s_ready
    .m_valid(linEx_delta_m_valid) // output
);

ReLU #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM_1)
) ReLU (
    .dIn(linEx_delta_dOut),
    .dOut(ReLU_dOut)
);

// [J] matrix_B 토큰 정렬: U_Dim_expand_delta_B 는 delta 경로 핸드셰이크로만 동작하고 matrix_B 는 버퍼가 필요해.
//     push = LinTrans_dBC_B 의 출력 타이밍,  pop = U_Dim_expand_delta_B 의 입력 타이밍.
Ring_Buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),
    .DEPTH_POWER_2(4)
)LinEx_dBC_B_Ring_Buffer(
    .clk(clk), 
    .nRst(nRst), 

    .ps_start(ps_start),

    // [J] (linEx_delta_s_ready & linEx_dBC_delta_m_valid) 는 dBC_delta->delta 링크라
    //     linEx_dBC_B_dOut 과 무관했어. B 자신의 출구 전송으로 교체.
    .push(linEx_dBC_B_m_valid & (B_buf_full == AVAIL) ), 
    .pop(fork_dl_cv[1] & delta_B_s_ready), // [J-FORK] dim_expand's accept (was linEx_delta_m_valid & delta_B_s_ready)

    .dIn(linEx_dBC_B_dOut) ,
    .dOut(linEx_dBC_B_aligned),

    .full(B_buf_full), 
    .empty()
);

U_Dim_expand_delta_B #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN_1(DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(DIMEX_DELTA_B_NUM_SCALE_DOUT)
) dim_expand_delta_B (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .delta(ReLU_dOut), //input
    .matrix_B(linEx_dBC_B_aligned), // input

    .dOut(dimEx_delta_B_dOut), // output 2D

    .s_valid(fork_dl_cv[1]), // [J-FORK] was linEx_delta_m_valid
    .s_ready(delta_B_s_ready), // output

    // [J] fork 경로인 Exp_piecewise 와 맞춰서 전진 - [Eng] Join: forward to the next stage, only when both are ready, 
    .m_ready(m_ready & pEXP_m_valid), // input
    .m_valid(delta_B_m_valid) // output
);

Exp_piecewise_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN_1(DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(DIMEX_DELTA_A_NUM_SCALE_DOUT),

    .LOG_NAME("WB_SSM_matrix"),             // [J-WB]
    .DEBUG_SWITCH(DEBUG_SWITCH),            // [J-WB]
    .WB_ADDR_W(WB_ADDR_W),                  // [J-WB]
    .WB_BASE_W(SSM_A_BASE)                  // [J-WB]
) Exp_piecewise (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .delta(ReLU_dOut),

    .wb_valid(wb_valid),                    // [J-WB]
    .wb_addr(wb_addr),                      // [J-WB]
    .wb_data(wb_data),                      // [J-WB]
    
    .dOut(delta_A),

    .s_valid(fork_dl_cv[0]), // [J-FORK] was linEx_delta_m_valid
    .s_ready(pEXP_s_ready), // output

    // [J] fork 경로인 dim_expand_delta_B 와 맞춰서 전진 - [Eng] Join: forward to the next stage, only when both are ready.
    .m_ready(m_ready & delta_B_m_valid), // input
    .m_valid(pEXP_m_valid) // output
);

assign delta_B  = dimEx_delta_B_dOut;

// ---------- ---------- ---------- [J_LOG] 레이어 덤프 ---------- ---------- ----------
// [J_LOG] SSM_delta_A / delta_B : 토큰당 ED 줄 x N 값  (16토큰 -> 640줄, legacy 와 동일)
// [J_LOG] SSM_C                 : 토큰당 N 값
// [J_LOG] 트리거 = 이 모듈의 출력 전송 (m_valid & m_ready)
integer jlog_fd;
integer jlog_e, jlog_n;
always @(posedge clk) begin
    if (nRst && m_valid && m_ready) begin
        jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "SSM_delta_A.txt"});
        if (jlog_fd) begin
            for (jlog_e = 0; jlog_e < NUM_DIM_1; jlog_e = jlog_e + 1)
                for (jlog_n = 0; jlog_n < NUM_DIM_2; jlog_n = jlog_n + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", delta_A[jlog_e][jlog_n]);
                        if (jlog_n == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
            $fclose(jlog_fd);
        end
        jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "SSM_delta_B.txt"});
        if (jlog_fd) begin
            for (jlog_e = 0; jlog_e < NUM_DIM_1; jlog_e = jlog_e + 1)
                for (jlog_n = 0; jlog_n < NUM_DIM_2; jlog_n = jlog_n + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", delta_B[jlog_e][jlog_n]);
                        if (jlog_n == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
            $fclose(jlog_fd);
        end
        jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "SSM_C.txt"});
        if (jlog_fd) begin
            for (jlog_n = 0; jlog_n < NUM_DIM_2; jlog_n = jlog_n + 1)
                begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                    $fwrite(jlog_fd, "%0d", matrix_C[jlog_n]);
                    if (jlog_n == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                end
            $fclose(jlog_fd);
        end
    end
end
// ========== ========== ========== [J_LOG] ========== ========== ==========

endmodule
