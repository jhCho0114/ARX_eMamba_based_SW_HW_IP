`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: U_MAMBA
// Shape (new model default):
//   hidden_states  [1, 197, 192]  NUM_SEQLEN=197, NUM_DIM_1=192
//   x, z           [1, 384, 197]  NUM_DIM_2=384
//   dt_low_rank    [197, 12]      NUM_DIM_DELTA=12
//   B, C           [1, 16, 197]    NUM_DIM_N=16
//   A              [384, 16]
//
// Old model: NUM_SEQLEN=16, NUM_DIM_1=20, NUM_DIM_2=40, NUM_DIM_N=8, NUM_DIM_DELTA=32
//////////////////////////////////////////////////////////////////////////////////

module U_MAMBA #(
    parameter integer DATA_WIDTH = 8,

    // --- Shape parameters ---
    parameter integer NUM_SEQLEN    = 197,  // L  (old: 16)
    parameter integer NUM_DIM_1     = 192,  // D  (old: 20)
    parameter integer NUM_DIM_2     = 384,  // ED (old: 40)
    parameter integer NUM_DIM_N     = 16,   // SSM state N (old: 8)
    parameter integer NUM_DIM_DELTA = 12,   // dt_low_rank  (old: 32)

    localparam integer NUM_DIM_DBC = NUM_DIM_DELTA + NUM_DIM_N * 2,

    // [J-WB] ---------- wb loader ----------
    parameter integer WB_ADDR_W = 15,     // wb_addr 폭. eMamba_IP 의 WB_BRAM_ADDR_W 와 같게

    parameter integer LIGHTNORM_W_BASE = 0,
    parameter integer LINEX_X1_W_BASE = 0,
    parameter integer LINEX_Z1_W_BASE = 0,
    parameter integer CONV1D_W_BASE = 0,

    parameter integer LIN_DBC_DELTA_W_BASE = 0,
    parameter integer LIN_DBC_B_W_BASE = 0,
    parameter integer LIN_DBC_C_W_BASE = 0,
    parameter integer SSM_A_BASE = 0, 
    parameter integer SSM_D_BASE = 0, 
    parameter integer LIN_DELTA_W_BASE = 0,

    parameter integer LINCONT_W_BASE = 0,
    // [J-WB] ---------- wb loader ----------

    // LightNorm
    parameter integer LNORM_NUM_SCALE_DIN    = 5,
    parameter integer LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer LNORM_NUM_SCALE_BIAS   = 10,
    parameter integer LNORM_NUM_SCALE_DOUT   = 6,

    // in_proj x
    parameter integer LINEX_X1_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_X1_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_X1_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_X1_NUM_SCALE_DOUT   = 6,

    // in_proj z
    parameter integer LINEX_Z1_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_Z1_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_Z1_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_Z1_NUM_SCALE_DOUT   = 5,

    // SiLU
    parameter integer SILU_NUM_SCALE_DIN  = 5,
    parameter integer SILU_NUM_SCALE_DOUT = 6,

    // conv1d (per-token ED->ED linear, Linear_Transform_Dynamic)
    parameter integer CONV1D_NUM_SCALE_DIN    = 6,
    parameter integer CONV1D_NUM_SCALE_WEIGHT = 8,
    parameter integer CONV1D_NUM_SCALE_BIAS   = 9,
    parameter integer CONV1D_NUM_SCALE_DOUT   = 5,

    // SSM preprocess
    parameter integer SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 6,

    parameter integer SSM_LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DBC_B_NUM_SCALE_DOUT   = 6,

    parameter integer SSM_LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DBC_C_NUM_SCALE_DOUT   = 5,

    parameter integer SSM_LINEX_DELTA_NUM_SCALE_DIN    = 6,
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer SSM_LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    parameter integer SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 3,
    parameter integer SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    parameter integer SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 6,
    parameter integer SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT  = 3,

    // SSM computation
    parameter integer SSM_NUM_SCALE_DIN     = 5,
    parameter integer SSM_NUM_SCALE_DELTA_A = 7,
    parameter integer SSM_NUM_SCALE_DELTA_B = 3,
    parameter integer SSM_NUM_SCALE_C       = 5,
    parameter integer SSM_NUM_SCALE_D       = 6,
    parameter integer SSM_NUM_SCALE_DOUT    = 3,

    // Elementwise Prod / Add
    parameter integer EW_PROD_NUM_SCALE_DIN_1 = 3,
    parameter integer EW_PROD_NUM_SCALE_DIN_2 = 6,
    parameter integer EW_PROD_NUM_SCALE_DOUT  = 5,

    // out_proj
    parameter integer LINCONT_NUM_SCALE_DIN    = 5,
    parameter integer LINCONT_NUM_SCALE_WEIGHT = 8,
    parameter integer LINCONT_NUM_SCALE_BIAS   = 9,
    parameter integer LINCONT_NUM_SCALE_DOUT   = 5,

    parameter integer EW_ADD_NUM_SCALE_DIN_1 = 5,
    parameter integer EW_ADD_NUM_SCALE_DIN_2 = 8,
    parameter integer EW_ADD_NUM_SCALE_DOUT  = 5,

    parameter integer DEBUG_SWITCH = 0
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

// ========== I/O Ports ==========
input clk, nRst;
input ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM_1-1];
output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM_1-1];

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

input  s_valid, m_ready;
output s_ready, m_valid;

// ========== Internal Signals ==========
// [J] skip_FF_1..8 -> Ring_Buffer. 깊이를 손으로 맞추던 shift 체인이었어.
logic signed [DATA_WIDTH-1:0] skip_aligned [0:NUM_DIM_1-1];
logic skip_buf_full;

logic signed [DATA_WIDTH-1:0] lightNorm_dOut [0:NUM_DIM_1-1];
logic lightNorm_s_ready, lightNorm_m_valid;

logic signed [DATA_WIDTH-1:0] linEx_x1_dOut [0:NUM_DIM_2-1];
logic linEx_x1_s_ready, linEx_x1_m_valid;

logic signed [DATA_WIDTH-1:0] linEx_z1_dOut [0:NUM_DIM_2-1];
logic linEx_z1_s_ready, linEx_z1_m_valid;

logic signed [DATA_WIDTH-1:0] SiLU_dOut [0:NUM_DIM_2-1];
// [J] SiLU_dOut_FF_1..5 -> Ring_Buffer
logic signed [DATA_WIDTH-1:0] SiLU_aligned [0:NUM_DIM_2-1];
logic SiLU_buf_full;

logic signed [DATA_WIDTH-1:0] conv1d_dOut [0:NUM_DIM_2-1];
// [J] conv1d_dOut_FF_1..3 삭제 — dIn 정렬을 U_SSM 안으로.
//     pop 시점(Preprocess->Computation 링크)이 여기서는 안 보여서 manual depth adjustment를 손으로 맞출 수밖에 없었거든.
logic conv1d_s_ready, conv1d_m_valid;

logic signed [DATA_WIDTH-1:0] SSM_dOut [0:NUM_DIM_2-1];
logic SSM_s_ready, SSM_m_valid;

logic signed [DATA_WIDTH-1:0] elWise_prod_dOut [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] linCont_dOut [0:NUM_DIM_1-1];
logic linCont_s_ready;
logic signed [DATA_WIDTH-1:0] elWise_add_dOut [0:NUM_DIM_1-1];

// [J-FORK] fork bookkeeping (see Fork_Ack)
logic [1:0] fork_in_cv;      // entrance fork   : [0]=LightNorm, [1]=skip_Ring_Buffer
logic [1:0] fork_ln_cv;      // LightNorm fork  : [0]=LinTrans_x1, [1]=LinTrans_z1
logic       fork_ln_pready;

// [J] Ring_Buffer full 
localparam AVAIL = 1'b0;

// ========== Submodules ==========

U_LightNorm_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM_1),

    .NUM_PARALLEL(NUM_DIM_1 / 2 ),

    .NUM_SCALE_DIN(LNORM_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LNORM_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LNORM_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LNORM_NUM_SCALE_DOUT),

    .LOG_NAME("WB_LightNorm"),
    .DEBUG_SWITCH(DEBUG_SWITCH),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LIGHTNORM_W_BASE)
) u_light_norm (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(lightNorm_dOut),
    
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(fork_in_cv[0]),                       // [J-FORK] was s_valid
    .s_ready(lightNorm_s_ready),

    // [J] lightNorm_dOut 은 LinTrans_x1 과 LinTrans_z1 로 분기, 둘 다 .s_valid(lightNorm_m_valid) 를 공유해. 
    //     x1 의 ready 만 보면 z1 이 아직 못 받을 때도 전송.
    .m_ready(fork_ln_pready),                      // [J-FORK] was linEx_x1_s_ready & linEx_z1_s_ready
    .m_valid(lightNorm_m_valid)
);

// in_proj x  (D -> ED)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_1),
    .NUM_DIM_OUT(NUM_DIM_2),
    .USE_BIAS(1'b1),
    .USE_ACTIVATOR(1'b1),
    .NUM_SCALE_DIN(LINEX_X1_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_X1_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_X1_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_X1_NUM_SCALE_DOUT),

    .LOG_NAME("WB_LinTrans_x1"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LINEX_X1_W_BASE)
) LinTrans_x1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),
    .dIn(lightNorm_dOut),
    .dOut(linEx_x1_dOut),
        // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid), // input : wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // input : wb 의 addr.
    .wb_data(wb_data), // input : wb 의 data.

    .s_valid(fork_ln_cv[0]),                       // [J-FORK] was lightNorm_m_valid
    .m_ready(conv1d_s_ready),
    .s_ready(linEx_x1_s_ready),
    .m_valid(linEx_x1_m_valid)
);

// in_proj z  (D -> ED)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_1),
    .NUM_DIM_OUT(NUM_DIM_2),
    .USE_BIAS(1'b1),
    .USE_ACTIVATOR(1'b1),
    .NUM_SCALE_DIN(LINEX_Z1_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_Z1_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_Z1_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_Z1_NUM_SCALE_DOUT),

    .LOG_NAME("WB_LinTrans_z1"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LINEX_Z1_W_BASE)
) LinTrans_z1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(lightNorm_dOut),
    .dOut(linEx_z1_dOut),

        // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid), // input : wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // input : wb 의 addr.
    .wb_data(wb_data), // input : wb 의 data.

    .s_valid(fork_ln_cv[1]),                       // [J-FORK] was lightNorm_m_valid
    .s_ready(linEx_z1_s_ready),

    .m_ready(SiLU_buf_full == AVAIL),// [J] linCont_s_ready -> ~full
    .m_valid(linEx_z1_m_valid)
);

SiLU_piecewise #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),
    .NUM_SCALE_DIN(SILU_NUM_SCALE_DIN),
    .NUM_SCALE_DOUT(SILU_NUM_SCALE_DOUT)
) SiLU_piecewise (
    .dIn(linEx_z1_dOut),
    .dOut(SiLU_dOut)
);

// conv1d  (ED -> ED, per-token linear)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_2),
    .NUM_DIM_OUT(NUM_DIM_2),
    .USE_BIAS(1'b1),
    .USE_ACTIVATOR(1'b1),
    .NUM_SCALE_DIN(CONV1D_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(CONV1D_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(CONV1D_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(CONV1D_NUM_SCALE_DOUT),

    .LOG_NAME("WB_LinTrans_conv1d"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(CONV1D_W_BASE)
) LinTrans_conv1d (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),
    .dIn(linEx_x1_dOut),
    .dOut(conv1d_dOut),
        // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid), // input : wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // input : wb 의 addr.
    .wb_data(wb_data), // input : wb 의 data.

    .s_valid(linEx_x1_m_valid),
    .m_ready(SSM_s_ready),
    .s_ready(conv1d_s_ready),
    .m_valid(conv1d_m_valid)
);

U_SSM #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_1(NUM_DIM_2),       // ED
    .NUM_DIM_2(NUM_DIM_N),        // N
    .NUM_DIM_DELTA(NUM_DIM_DELTA),
    .LINEX_DBC_DELTA_NUM_SCALE_DIN(SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DBC_DELTA_NUM_SCALE_DOUT(SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT),
    .LINEX_DBC_B_NUM_SCALE_DIN(SSM_LINEX_DBC_B_NUM_SCALE_DIN),
    .LINEX_DBC_B_NUM_SCALE_WEIGHT(SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .LINEX_DBC_B_NUM_SCALE_DOUT(SSM_LINEX_DBC_B_NUM_SCALE_DOUT),
    .LINEX_DBC_C_NUM_SCALE_DIN(SSM_LINEX_DBC_C_NUM_SCALE_DIN),
    .LINEX_DBC_C_NUM_SCALE_WEIGHT(SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .LINEX_DBC_C_NUM_SCALE_DOUT(SSM_LINEX_DBC_C_NUM_SCALE_DOUT),
    .LINEX_DELTA_NUM_SCALE_DIN(SSM_LINEX_DELTA_NUM_SCALE_DIN),
    .LINEX_DELTA_NUM_SCALE_WEIGHT(SSM_LINEX_DELTA_NUM_SCALE_WEIGHT),
    .LINEX_DELTA_NUM_SCALE_BIAS(SSM_LINEX_DELTA_NUM_SCALE_BIAS),
    .LINEX_DELTA_NUM_SCALE_DOUT(SSM_LINEX_DELTA_NUM_SCALE_DOUT),
    .DIMEX_DELTA_A_NUM_SCALE_DIN_1(SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_A_NUM_SCALE_DIN_2(SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_A_NUM_SCALE_DOUT(SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT),
    .DIMEX_DELTA_B_NUM_SCALE_DIN_1(SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .DIMEX_DELTA_B_NUM_SCALE_DIN_2(SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .DIMEX_DELTA_B_NUM_SCALE_DOUT(SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT),
    .NUM_SCALE_DIN(SSM_NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(SSM_NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(SSM_NUM_SCALE_DELTA_B),
    .NUM_SCALE_C(SSM_NUM_SCALE_C),
    .NUM_SCALE_D(SSM_NUM_SCALE_D),
    .NUM_SCALE_DOUT(SSM_NUM_SCALE_DOUT),
    .DEBUG_SWITCH(DEBUG_SWITCH),

    .WB_ADDR_W(WB_ADDR_W),

    .LIN_DBC_DELTA_W_BASE(LIN_DBC_DELTA_W_BASE),
    .LIN_DBC_B_W_BASE(LIN_DBC_B_W_BASE),
    .LIN_DBC_C_W_BASE(LIN_DBC_C_W_BASE),
    .SSM_A_BASE(SSM_A_BASE),
    .SSM_D_BASE(SSM_D_BASE),
    .LIN_DELTA_W_BASE(LIN_DELTA_W_BASE)
) SSM (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(conv1d_dOut),
    .dOut(SSM_dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(conv1d_m_valid), // input
    .s_ready(SSM_s_ready), // output

    .m_ready(linCont_s_ready), // input
    .m_valid(SSM_m_valid) // output
);

ElementWise_Prod_Dynamic #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),

    .BROADCAST_DIN_1(1'b0),

    .NUM_SCALE_DIN_1(EW_PROD_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(EW_PROD_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(EW_PROD_NUM_SCALE_DOUT)
) ElementWise_Prod (

    .dIn_1_scalar(),  // input scalar - used for Dim_expand
    .dIn_1_vec(SSM_dOut),    // input 1D
    .dIn_2(SiLU_aligned), // [J] SiLU_dOut_FF_5 -> Ring_Buffer 출력

    .dOut(elWise_prod_dOut) // output 1D
);

// out_proj  (ED -> D)
Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM_2),
    .NUM_DIM_OUT(NUM_DIM_1),
    .USE_BIAS(1'b1),
    .USE_ACTIVATOR(1'b1),
    .NUM_SCALE_DIN(LINCONT_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINCONT_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINCONT_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINCONT_NUM_SCALE_DOUT),

    .LOG_NAME("WB_LinTrans_out"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LINCONT_W_BASE)
) LinTrans_out (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),
    .dIn(elWise_prod_dOut),
    .dOut(linCont_dOut),
    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid), // input : wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // input : wb 의 addr.
    .wb_data(wb_data), // input : wb 의 data.
    
    .s_valid(SSM_m_valid),
    .m_ready(m_ready),
    .s_ready(linCont_s_ready),
    .m_valid(m_valid)
);

ElementWise_Add #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_1),
    .NUM_SCALE_DIN_1(EW_ADD_NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(EW_ADD_NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(EW_ADD_NUM_SCALE_DOUT)
) ElementWise_Add (
    .dIn_1(linCont_dOut),
    .dIn_2(skip_aligned), // [J] skip_FF_8 -> Ring_Buffer 출력
    .dOut_8bit(elWise_add_dOut)
);

// ========== Main Code ==========
// [J]  ~full 을 AND 하면 : data miss prevention,  full 을 AND 하면 : data loss prevention.
// [J-FORK] s_ready is now driven by fork_in.p_ready (was lightNorm_s_ready & ~skip_buf_full)
assign dOut        = elWise_add_dOut;

// [J-FORK] entrance fork : upstream token -> {LightNorm, skip_Ring_Buffer}
Fork_Ack #(.N(2)) fork_in (
    .clk(clk), .nRst(nRst), .ps_start(ps_start),
    .p_valid(s_valid), .p_ready(s_ready),
    .c_valid(fork_in_cv),
    .c_ready({(skip_buf_full == AVAIL), lightNorm_s_ready}),
    .advance()
);

// [J-FORK] LightNorm fork : lightNorm_dOut -> {LinTrans_x1, LinTrans_z1}
Fork_Ack #(.N(2)) fork_ln (
    .clk(clk), .nRst(nRst), .ps_start(ps_start),
    .p_valid(lightNorm_m_valid), .p_ready(fork_ln_pready),
    .c_valid(fork_ln_cv),
    .c_ready({linEx_z1_s_ready, linEx_x1_s_ready}),
    .advance()
);

// ---------- ---------- ---------- 지연 정렬 (Ring_Buffer) ---------- ---------- ----------
// [J] push = U_MAMBA 입구 전송,  pop = U_MAMBA 출구 전송.
Ring_Buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_1),
    .DEPTH_POWER_2(16) // [J] 옛 shift cascade 3 종류(skip x8, conv1d x3, SiLU x5)
) skip_Ring_Buffer (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .push(fork_in_cv[1] & (skip_buf_full == AVAIL)), // [J-FORK] FIFO branch of the entrance fork (was s_valid & s_ready)
    .pop (m_valid & m_ready), // 출구 전송

    .dIn (dIn),
    .dOut(skip_aligned),

    .full(skip_buf_full),
    .empty()
);

// gate 경로 : SiLU(z1) 출력을 SSM 출력과 같은 토큰으로 맞춰주ㅜ
// [J] push = LinTrans_z1 출구 전송,  pop = LinTrans_out 입구 전송.
Ring_Buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_DIM(NUM_DIM_2),
    .DEPTH_POWER_2(16)
) SiLU_Ring_Buffer (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .push(linEx_z1_m_valid & (SiLU_buf_full == AVAIL)), // z1 출구 전송
    .pop (SSM_m_valid & linCont_s_ready), // LinTrans_out 입구 전송

    .dIn (SiLU_dOut),
    .dOut(SiLU_aligned),

    .full(SiLU_buf_full),
    .empty()
);
// ========== ========== ========== 지연 정렬 (Ring_Buffer) ========== ========== ==========

// ---------- ---------- ---------- [J_LOG] 레이어 덤프 ---------- ---------- ----------
// [J_LOG] 각 중간 신호를 "그 신호가 실제로 소비되는 링크의 전송 시점"에 찍는다.
//         valid 만 보고 찍으면 같은 토큰이 여러 번 나오고,
//         엉뚱한 ready 와 짝지으면 전송이 아닌 순간에 찍혀.
//
//   LightNorm.txt        <- lightNorm  -> x1/z1 fork 전송
//   Linear_x1.txt        <- x1         -> conv1d 전송
//   Linear_z1.txt        <- z1         -> SiLU 버퍼 push
//   SiLU.txt             <- 같은 시점 (SiLU_piecewise 는 조합회로)
//   Conv1D.txt           <- conv1d     -> U_SSM 전송
//   Elementwise_Prod.txt <- gate       -> LinTrans_out 입력 전송
//   Linear_contract.txt  <- 이 모듈의 출력 전송
integer jlog_fd;
integer jlog_i;
always @(posedge clk) begin
    if (!nRst) begin
        // nothing
    end
    else begin
        if (lightNorm_m_valid && linEx_x1_s_ready && linEx_z1_s_ready) begin
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "LightNorm.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_1; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", lightNorm_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_1-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
        end

        if (linEx_x1_m_valid && conv1d_s_ready) begin
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "Linear_x1.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_2; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", linEx_x1_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
        end

        if (linEx_z1_m_valid && (SiLU_buf_full == AVAIL)) begin
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "Linear_z1.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_2; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", linEx_z1_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "SiLU.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_2; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", SiLU_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
        end

        if (conv1d_m_valid && SSM_s_ready) begin
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "Conv1D.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_2; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", conv1d_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
        end

        if (SSM_m_valid && linCont_s_ready) begin
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "Elementwise_Prod.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_2; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", elWise_prod_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_2-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
        end

        if (m_valid && m_ready) begin
            jlog_fd = U_log_pkg::opn({U_log_pkg::pfx(DEBUG_SWITCH), "Linear_contract.txt"});
            if (jlog_fd) begin
                for (jlog_i = 0; jlog_i < NUM_DIM_1; jlog_i = jlog_i + 1)
                    begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                        $fwrite(jlog_fd, "%0d", linCont_dOut[jlog_i]);
                        if (jlog_i == NUM_DIM_1-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                    end
                $fclose(jlog_fd);
            end
        end
    end
end
// ========== ========== ========== [J_LOG] ========== ========== ==========

endmodule
