`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// [J-BRAM] Module Name: Token_Fetcher
// Description: Patch_Rearrange 의 "배선 순열" 을 "주소 순열" 로 옮긴 모듈.
//
//   Patch_Rearrange 는
//     token[h*WP + w][(ph*P2 + pw)*C + c] = dIn[c][P1*h + ph][P2*w + pw]
//   를 2,560 개 wire 로 그렸다. 프레임이 BRAM 에 있으면 wire 대신 주소다:
//     byte  = c*H*W + (P1*h + ph)*W + P2*w      (CHW 순서, S_AXI word 1..80 그대로)
//     word  = byte / 4 ,  lane = byte % 4
//   P2*w 가 짝수라 pw = 0,1 은 항상 같은 워드의 인접 바이트 → 워드 하나로 바이트 2개.
//   토큰 하나 = C x P1 = 10 워드 읽기 (+1 지연) ≈ 12 clk.
//
//   포트 규약은 Patch_Rearrange + rearrange_dOut[row] 를 대체하도록 맞췄다:
//     s_valid/s_ready/row  <- U_Frame_Sequencer (그대로)
//     rd_en/rd_addr/rd_data -> my_bram port B (S_AXI 에서 관통)
//     token/m_valid/m_ready -> Linear_Transform_Dynamic.dIn/s_valid/s_ready
//
//   FSM : IDLE -> FETCH(주소 10개 발행) -> DRAIN(마지막 워드 수신) -> HOLD(m_valid) -> IDLE
//   수신은 상태와 무관하게 vld_q 파이프로 처리한다 (T 에 낸 주소의 데이터는 T+1 에).
//////////////////////////////////////////////////////////////////////////////////

module Token_Fetcher #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_CHANNEL = 5,
    parameter integer NUM_HEIGHT  = 8,
    parameter integer NUM_WIDTH   = 8,
    parameter integer PATCH1      = 2,
    parameter integer PATCH2      = 2,
    parameter integer NUM_SEQLEN  = 16,
    parameter integer NUM_DIM     = 20,
    parameter integer AXI_W       = 32,
    parameter integer RD_AW       = 7      // my_bram DEPTH=128 -> 7bit
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    // ---------- from U_Frame_Sequencer ----------
    input  logic                                          s_valid,
    output logic                                          s_ready,
    input  logic [((NUM_SEQLEN > 1) ? $clog2(NUM_SEQLEN) : 1)-1:0] row,

    // ---------- my_bram port B ----------
    output logic                 rd_en,
    output logic [RD_AW-1:0]     rd_addr,
    input  logic [AXI_W-1:0]     rd_data,

    // ---------- to Linear_Transform_Dynamic ----------
    output logic signed [DATA_WIDTH-1:0] token [0:NUM_DIM-1],
    output logic                         m_valid,
    input  logic                         m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer WP  = NUM_WIDTH  / PATCH2;    // 토큰 열 수 (4)
localparam integer BPW = AXI_W / DATA_WIDTH;     // 워드당 바이트 (4)
localparam integer C_W = (NUM_CHANNEL > 1) ? $clog2(NUM_CHANNEL) : 1;
localparam integer P_W = (PATCH1      > 1) ? $clog2(PATCH1)      : 1;
localparam integer L_W = (BPW         > 1) ? $clog2(BPW)         : 1;
localparam integer E_W = (NUM_DIM     > 1) ? $clog2(NUM_DIM)     : 1;

// pw = 0..P2-1 이 한 워드 안에 들어가야 "워드 1개 = 바이트 P2개" 가 성립
initial begin
    if ((BPW % PATCH2) != 0 || (NUM_WIDTH % BPW) != 0)
        $error("[J-BRAM] Token_Fetcher: PATCH2=%0d / NUM_WIDTH=%0d 는 워드 경계를 넘는다", PATCH2, NUM_WIDTH);
end

localparam IDLE = 2'd0, FETCH = 2'd1, DRAIN = 2'd2, HOLD = 2'd3;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [1:0]     st;
logic [C_W-1:0] c;          // 발행 카운터 (안쪽)
logic [P_W-1:0] ph;         // 발행 카운터 (바깥쪽)
logic           last_issue;

// row -> (h, w)
integer h_i, w_i;
always_comb begin
    h_i = row / WP;
    w_i = row % WP;
end

// 발행 주소 (T)
integer byte_base;
always_comb begin
    byte_base = c * NUM_HEIGHT * NUM_WIDTH + (PATCH1 * h_i + ph) * NUM_WIDTH + PATCH2 * w_i;
    rd_addr   = byte_base / BPW;
end
assign rd_en      = (st == FETCH);
assign last_issue = (c == NUM_CHANNEL-1) && (ph == PATCH1-1);

// 수신 파이프 (T+1) : 어느 워드를 요청했는지 한 클럭 들고 간다
logic           vld_q;
logic [C_W-1:0] c_q;
logic [P_W-1:0] ph_q;
logic [L_W-1:0] lane_q;

always_ff @(posedge clk) begin
    if (!nRst || ps_start) begin
        vld_q  <= #1 1'b0;
        c_q    <= #1 '0;
        ph_q   <= #1 '0;
        lane_q <= #1 '0;
    end else begin
        vld_q  <= #1 rd_en;
        c_q    <= #1 c;
        ph_q   <= #1 ph;
        lane_q <= #1 byte_base % BPW;
    end
end

// 도착한 워드에서 pw = 0..P2-1 바이트를 token[(ph*P2 + pw)*C + c] 에 배치
integer pw;
always_ff @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        token <= #1 '{default:'0};                            // [J-unopt-reset]
    end else if (vld_q) begin                                 // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        for (pw = 0; pw < PATCH2; pw = pw + 1)
            token[(ph_q * PATCH2 + pw) * NUM_CHANNEL + c_q]
                <= #1 rd_data[(lane_q + pw) * DATA_WIDTH +: DATA_WIDTH];
    end
end

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Handshake
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
assign m_valid = (st == HOLD);
assign s_ready = (st == HOLD) && m_ready;   // 토큰이 소비된 클럭에 시퀀서 row 를 넘긴다

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// FSM
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
always_ff @(posedge clk) begin
    if (!nRst || ps_start) begin
        st <= #1 IDLE;
        c  <= #1 '0;
        ph <= #1 '0;
    end else begin
        case (st)
            IDLE: begin
                c  <= #1 '0;
                ph <= #1 '0;
                if (s_valid) st <= #1 FETCH;
            end
            FETCH: begin
                if (c == NUM_CHANNEL-1) begin
                    c  <= #1 '0;
                    ph <= #1 ph + 1'b1;
                end else begin
                    c  <= #1 c + 1'b1;
                end
                if (last_issue) st <= #1 DRAIN;
            end
            DRAIN: st <= #1 HOLD;          // 마지막 발행분이 vld_q 로 들어오는 클럭
            HOLD : if (m_ready) st <= #1 IDLE;
            default: st <= #1 IDLE;
        endcase
    end
end

endmodule
