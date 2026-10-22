`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/01/2026 08:39:32 PM
// Design Name: 
// Module Name: U_PatchEmbedding
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module U_PatchEmbedding #(
    parameter integer DATA_WIDTH    = 8,
    parameter integer NUM_CHANNEL   = 5,
    parameter integer NUM_HEIGHT    = 8,
    parameter integer NUM_WIDTH     = 8,
    parameter integer PATCH1        = 2,
    parameter integer PATCH2        = 2,
    parameter integer NUM_SEQLEN    = 16,
    parameter integer NUM_DIM       = 20,
    parameter integer NUM_SCALE_DIN     = 6,
    parameter integer NUM_SCALE_WEIGHT  = 7,
    parameter integer NUM_SCALE_BIAS    = 8,
    parameter integer NUM_SCALE_DOUT    = 8,

    // [J-WB] ---------- wb loader ----------
    parameter integer WB_ADDR_W = 15,     // wb_addr 폭. eMamba_IP 의 WB_BRAM_ADDR_W 와 같게
    parameter integer PATCH_LINEAR_W_BASE = 0,      // weight 창의 첫 워드 번호

    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    in_rd_en,     // [J-EXT-BRAM] v7 의 dIn[c][h][w] 대신 BRAM 읽기 신호 3개 (Token_Fetcher 가 만든다)
    in_rd_addr,   // [J-EXT-BRAM]
    in_rd_data,   // [J-EXT-BRAM]
    // dIn,
    dOut,

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    wb_valid,
    wb_addr,
    wb_data,

    frame_valid, // input
    frame_done, // output

    m_valid, //output
    m_ready // input
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

// [J-EXT-BRAM] v7 : input dIn[5][8][8] (프레임 전체가 병렬로 들어옴). 지금은 프레임이 BRAM 에 있으니
//                   Token_Fetcher 가 필요한 워드만 하나씩 읽는다. 이 3개가 BRAM 까지 가는 통로.
output logic        in_rd_en;     // [J-EXT-BRAM] Token_Fetcher -> (U_eMamba -> eMamba_IP ->) BRAM Port B en
output logic [6:0]  in_rd_addr;   // [J-EXT-BRAM] Token_Fetcher -> BRAM Port B addr (워드 번호 0..79)
input  logic [31:0] in_rd_data;   // [J-EXT-BRAM] BRAM Port B dout -> Token_Fetcher (요청 다음 클럭)
// input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_CHANNEL-1][0:NUM_HEIGHT-1][0:NUM_WIDTH-1]; // 1x5x8x8
output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1];                                    // 1x20

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

input  frame_valid, m_ready;
output frame_done, m_valid;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// [J-EXT-BRAM] v7 : rearrange_dOut[16][20] (토큰 16개가 전부 병렬로 준비돼 있고 row 로 골라 씀).
//                   지금 : 토큰 1개짜리 버퍼. Token_Fetcher 가 row 에 해당하는 토큰을 BRAM 에서 조립해 채운다.
logic signed [DATA_WIDTH-1:0] fetched_token [0:NUM_DIM-1];   // [J-EXT-BRAM] 토큰 1개 (20 바이트)
logic fetched_valid, fetched_ready;                          // [J-EXT-BRAM] Token_Fetcher <-> patch_linear 핸드셰이크
// logic signed [DATA_WIDTH-1:0] rearrange_dOut [0:NUM_SEQLEN-1][0:NUM_DIM-1]; // 16x20

logic [$clog2(NUM_SEQLEN)-1:0] row;
logic token_valid, token_ready;
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========

U_Frame_Sequencer #(
    .NUM_SEQLEN(NUM_SEQLEN)
)U_Frame_Sequencer (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .frame_valid(frame_valid),    // input
    .frame_done(frame_done),    // output

    .m_valid(token_valid),    // output
    .m_ready(token_ready),    // input  

    .row(row)         // output upcoming sequence index
);

// Patch_Rearrange #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .NUM_CHANNEL(NUM_CHANNEL),
//     .NUM_HEIGHT(NUM_HEIGHT),
//     .NUM_WIDTH(NUM_WIDTH),
    
//     .PATCH1(PATCH1),
//     .PATCH2(PATCH2),
//     .NUM_SEQLEN(NUM_SEQLEN), 
//     .NUM_DIM(NUM_DIM)
// ) Patch_Rearrange (
//     .dIn(dIn),
//     .dOut(rearrange_dOut)
// );

// ------------------------------------------------------------------------------------------
//       byte = c*H*W + (P1*h + ph)*W + P2*w      (S_AXI 옛 word 1..80 의 바이트 순서 그대로)
//       word = byte / 4
// ------------------------------------------------------------------------------------------
Token_Fetcher #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNEL(NUM_CHANNEL),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .PATCH1(PATCH1),
    .PATCH2(PATCH2),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),
    .AXI_W(32),               // BRAM 워드 폭
    .RD_AW(7)                 // 워드 주소 폭 (0..79 -> 7bit)
) Token_Fetcher (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .s_valid(token_valid),    // <- U_Frame_Sequencer.m_valid : "row 번째 토큰 만들어라"
    .s_ready(token_ready),    // -> U_Frame_Sequencer.m_ready : 토큰이 patch_linear 로 넘어간 클럭에 1
    .row(row),

    .rd_en(in_rd_en),         // -> BRAM Port B (U_eMamba, eMamba_IP 를 거쳐 BD 의 BRAM 까지)
    .rd_addr(in_rd_addr),
    .rd_data(in_rd_data),

    .token(fetched_token),    // -> patch_linear.dIn
    .m_valid(fetched_valid),
    .m_ready(fetched_ready)
);

Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH), 
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM), 
    .NUM_DIM_OUT(NUM_DIM),

    .USE_BIAS(1'b1), 
    .USE_ACTIVATOR(1'b1),

    .NUM_SCALE_DIN(NUM_SCALE_DIN), 
    .NUM_SCALE_WEIGHT(NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(NUM_SCALE_BIAS), 
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .LOG_NAME("WB_Patch_linear"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(PATCH_LINEAR_W_BASE)
) patch_linear (
    .clk(clk), 
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(fetched_token),      // [J-EXT-BRAM] v7 : rearrange_dOut[row]
    .dOut(dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid), // input : wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // input : wb 의 addr.
    .wb_data(wb_data), // input : wb 의 data.

    .s_valid(fetched_valid),  // [J-EXT-BRAM] v7 : token_valid (시퀀서 직결) -> Token_Fetcher 출력
    .s_ready(fetched_ready),  // [J-EXT-BRAM] v7 : token_ready

    .m_ready(m_ready),
    .m_valid(m_valid)
);

// ---------- ---------- ---------- [J_LOG] 레이어 덤프 ---------- ---------- ----------
// [J_LOG] Patch_linear.txt : 토큰당 D 값. 트리거 = 이 모듈의 출력 전송.
integer jlog_fd;
integer jlog_i;
always @(posedge clk) begin
    if (nRst && m_valid && m_ready) begin
        jlog_fd = U_log_pkg::opn("Patch_linear.txt");
        if (jlog_fd) begin
            for (jlog_i = 0; jlog_i < NUM_DIM; jlog_i = jlog_i + 1)
                begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                    $fwrite(jlog_fd, "%0d", dOut[jlog_i]);
                    if (jlog_i == NUM_DIM-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                end
            $fclose(jlog_fd);
        end
    end
end
// ========== ========== ========== [J_LOG] ========== ========== ==========

endmodule