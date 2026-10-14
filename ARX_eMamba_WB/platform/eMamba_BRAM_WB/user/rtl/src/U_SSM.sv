`timescale 1ns / 1ps

module U_SSM #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 197,  // [J] L  (16 -> 197)
    parameter integer NUM_DIM_1  = 384,  // [J] ED (40 -> 384)
    parameter integer NUM_DIM_2  = 16,   // [J] N  (8  -> 16)
    parameter integer NUM_DIM_DELTA = 12, // [J] dt_low_rank (localparam 32 -> parameter 12)

    // Preprocess
    parameter integer LIN_DBC_DELTA_W_BASE = 0,
    parameter integer LIN_DBC_B_W_BASE = 0,
    parameter integer LIN_DBC_C_W_BASE = 0,
    parameter integer LIN_DELTA_W_BASE = 0,

    parameter integer SSM_A_BASE = 0, 
    parameter integer SSM_D_BASE = 0, 

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

    // Linear expand dleta
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

    // Computation
    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_C       = 5,
    parameter integer NUM_SCALE_D       = 6,
    parameter integer NUM_SCALE_DOUT    = 3,

    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    // [J] Deleted dIn_delayed 포트 삭제. 

    dIn,
    dOut,

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    wb_valid,
    wb_addr,
    wb_data,

    s_valid, // input
    s_ready, // output
    
    m_ready, // input
    m_valid //output
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// [J] localparam NUM_DIM_DELTA = 32 제거 -> module parameter NUM_DIM_DELTA 로 넣어줘   
localparam integer NUM_DIM_DBC = NUM_DIM_DELTA + NUM_DIM_2 * 2; // [J] x_proj [delta+B+C, ED] = [44, 384]

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn           [0:NUM_DIM_1-1]; // [J] 384 (x_after_conv_silu)
output logic signed [DATA_WIDTH-1:0] dOut          [0:NUM_DIM_1-1]; // [J] 384 (y_after_gate)

input  s_valid, m_ready;
output s_ready, m_valid;

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] delta_A   [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // [J] 384x16
logic signed [DATA_WIDTH-1:0] delta_B   [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // [J] 384x16
logic signed [DATA_WIDTH-1:0] matrix_C  [0:NUM_DIM_2-1]; // [J] 16

logic SSM_computation_ready;
logic SSM_preprocess_m_valid; // [J] 누락 선언 추가

localparam AVAIL = 1'b0;

logic signed [DATA_WIDTH-1:0] dIn_aligned [0:NUM_DIM_1-1];
logic dIn_buf_full;
logic preprocess_s_ready;
logic [1:0] fork_in_cv;      // [J-FORK] entrance fork : [0]=U_SSM_Preprocess, [1]=dIn_Ring_Buffer

// [J] 버퍼가 오버플로하지 않도록 입구 ready 에 ~full 을 AND
// [J-FORK] entrance fork : upstream token -> {U_SSM_Preprocess, dIn_Ring_Buffer}
//          s_ready is driven by fork_in.p_ready (was preprocess_s_ready & ~dIn_buf_full)
Fork_Ack #(.N(2)) fork_in (
    .clk(clk), .nRst(nRst), .ps_start(ps_start),
    .p_valid(s_valid), .p_ready(s_ready),
    .c_valid(fork_in_cv),
    .c_ready({(dIn_buf_full == AVAIL), preprocess_s_ready}),
    .advance()
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
U_SSM_Preprocess #( // [J] SSM_Preprocess -> U_SSM_Preprocess
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),  // ED
    .NUM_DIM_2(NUM_DIM_2),  // N
    .NUM_DIM_DELTA(NUM_DIM_DELTA), // [J] dt_rank 전달

    // Linear expand dBC delta
    .LINEX_DBC_DELTA_NUM_SCALE_DIN(LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DBC_DELTA_NUM_SCALE_DOUT(LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .LINEX_DBC_B_NUM_SCALE_DIN(LINEX_DBC_B_NUM_SCALE_DIN),
    .LINEX_DBC_B_NUM_SCALE_WEIGHT(LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .LINEX_DBC_B_NUM_SCALE_DOUT(LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .LINEX_DBC_C_NUM_SCALE_DIN(LINEX_DBC_C_NUM_SCALE_DIN),
    .LINEX_DBC_C_NUM_SCALE_WEIGHT(LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .LINEX_DBC_C_NUM_SCALE_DOUT(LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .LINEX_DELTA_NUM_SCALE_DIN(LINEX_DELTA_NUM_SCALE_DIN),
    .LINEX_DELTA_NUM_SCALE_WEIGHT(LINEX_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DELTA_NUM_SCALE_BIAS(LINEX_DELTA_NUM_SCALE_BIAS),
    .LINEX_DELTA_NUM_SCALE_DOUT(LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .DIMEX_DELTA_A_NUM_SCALE_DIN_1(DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_A_NUM_SCALE_DIN_2(DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_A_NUM_SCALE_DOUT(DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .DIMEX_DELTA_B_NUM_SCALE_DIN_1(DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_B_NUM_SCALE_DIN_2(DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_B_NUM_SCALE_DOUT(DIMEX_DELTA_B_NUM_SCALE_DOUT),

    .DEBUG_SWITCH(DEBUG_SWITCH),

    .SSM_A_BASE(SSM_A_BASE),
    .LIN_DBC_DELTA_W_BASE(LIN_DBC_DELTA_W_BASE),
    .LIN_DBC_B_W_BASE(LIN_DBC_B_W_BASE),
    .LIN_DBC_C_W_BASE(LIN_DBC_C_W_BASE),
    .LIN_DELTA_W_BASE(LIN_DELTA_W_BASE),
    .WB_ADDR_W(WB_ADDR_W)
) SSM_Preprocess (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),


    .delta_A(delta_A),
    .delta_B(delta_B),
    .matrix_C(matrix_C),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(fork_in_cv[0]),                       // [J-FORK] was s_valid
    .m_ready(SSM_computation_ready),
    .s_ready(preprocess_s_ready), // [J] s_ready -> preprocess_s_ready (위에서 ~full 과 AND)
    .m_valid(SSM_preprocess_m_valid)
);

// [J] dIn 정렬 버퍼 — Preprocess 지연(LinTrans 2단 + Exp)만큼 dIn 을 늦춰서
//     Computation 이 delta_A/B/C 와 같은 토큰의 dIn 을 보게 해.
Ring_Buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_1),
    .DEPTH_POWER_2(16) // [J] 깊이는 이 한 줄로 조정
) dIn_Ring_Buffer (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .push(fork_in_cv[1] & (dIn_buf_full == AVAIL)),            // [J-FORK] FIFO branch of the entrance fork (was s_valid & s_ready)
    .pop (SSM_preprocess_m_valid & SSM_computation_ready),     // Preprocess -> Computation 전송

    .dIn (dIn),
    .dOut(dIn_aligned),

    .full(dIn_buf_full),
    .empty()
);

U_SSM_Computation #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_1),
    .NUM_DIM_2(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(NUM_SCALE_DELTA_B),
    .NUM_SCALE_C(NUM_SCALE_C),
    .NUM_SCALE_D(NUM_SCALE_D),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .LOG_NAME("WB_SSM_matrix_D"),  // [J-WB]
    .WB_ADDR_W(WB_ADDR_W),        // [J-WB]
    .WB_BASE_W(SSM_D_BASE),       // [J-WB]
    .DEBUG_SWITCH(DEBUG_SWITCH)
) SSM_Computation (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),
    
    .dIn(dIn_aligned), // [J] dIn_delayed -> 내부 Ring_Buffer 출력

    .delta_A(delta_A), // input
    .delta_B(delta_B), // input
    .matrix_C(matrix_C), // input
    
    .wb_valid(wb_valid), // [J-WB]
    .wb_addr(wb_addr), // [J-WB]
    .wb_data(wb_data), // [J-WB]

    .dOut(dOut), // output

    .s_valid(SSM_preprocess_m_valid), // input
    .s_ready(SSM_computation_ready), // output

    .m_ready(m_ready), // input
    .m_valid(m_valid) // output
);

endmodule