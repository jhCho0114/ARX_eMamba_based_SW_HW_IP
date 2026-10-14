`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 10:28:20 AM
// Design Name: 
// Module Name: Outputhead
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


module U_Outputhead #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM    = 20,
    parameter integer NUM_CLASS  = 57,

    // LightNorm
    parameter integer LNORM_NUM_SCALE_DIN    = 5,
    parameter integer LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer LNORM_NUM_SCALE_BIAS   = 10,
    parameter integer LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand
    parameter integer LINEX_NUM_SCALE_DIN    = 6,
    parameter integer LINEX_NUM_SCALE_WEIGHT = 8,
    parameter integer LINEX_NUM_SCALE_BIAS   = 8,
    parameter integer LINEX_NUM_SCALE_DOUT   = 6,

    // [J-WB] ---------- wb loader ----------
    parameter string  LOG_NAME  = "",
    parameter integer WB_ADDR_W = 15,     // wb_addr 폭. eMamba_IP 의 WB_BRAM_ADDR_W 와 같게
    parameter integer LIGHTNORM_W_BASE = 0,      // weight 창의 첫 워드 번호
    parameter integer OH_LINEAR_W_BASE = 0,      // weight 창의 첫 워드 번호

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

    s_valid,
    m_ready,
    s_ready,
    m_valid,

    dOut_seq_idx,
    frame_done
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer SEQ_W = (NUM_SEQLEN > 1) ? $clog2(NUM_SEQLEN) : 1 ;

input clk, nRst;

input ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1];
output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_CLASS-1]; // Linear expand

input  logic s_valid, m_ready;
output logic s_ready, m_valid;

output logic [SEQ_W-1:0] dOut_seq_idx;
output logic frame_done;

// [J-WB] 브로드캐스트 버스. 모든 잎에 같은 3 신호가 병렬로 간다.
input logic                  wb_valid;
input logic [WB_ADDR_W-1:0]  wb_addr;
input logic [31:0]           wb_data;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========

// LightNorm
logic signed [DATA_WIDTH-1:0] lightNorm_dOut [0:NUM_DIM-1];
logic lightNorm_m_valid;

// Linear expand
logic linEx_s_ready;

logic [SEQ_W-1:0] out_row;

logic frame_done_r;
logic m_handshaking, last_row;
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
U_LightNorm_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),

    .NUM_SCALE_DIN(LNORM_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LNORM_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LNORM_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LNORM_NUM_SCALE_DOUT),

    .LOG_NAME("WB_OH_LightNorm"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(LIGHTNORM_W_BASE)
) OH_LightNorm (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start),

    .dIn(dIn),
    .dOut(lightNorm_dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(s_valid),
    .m_ready(linEx_s_ready),
    .s_ready(s_ready),
    .m_valid(lightNorm_m_valid)
);

Linear_Transform_Dynamic_WB #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM_IN(NUM_DIM),
    .NUM_DIM_OUT(NUM_CLASS),

    .USE_BIAS(1'b1),
    .USE_ACTIVATOR(1'b1),

    .NUM_SCALE_DIN(LINEX_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(LINEX_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(LINEX_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(LINEX_NUM_SCALE_DOUT),

    .LOG_NAME("WB_OH_Linear"),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(OH_LINEAR_W_BASE)
) OH_Linear (
    .clk(clk), 
    .nRst(nRst), 
    .ps_start(ps_start),

    .dIn(lightNorm_dOut), 
    .dOut(dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(lightNorm_m_valid), 
    .s_ready(linEx_s_ready),

    .m_ready(m_ready),
    .m_valid(m_valid)
);

//---------- ---------- ---------- row counter ---------- ---------- ----------

assign m_handshaking  = m_valid & m_ready;

assign dOut_seq_idx = out_row;
assign frame_done     = frame_done_r;
assign last_row       = (out_row == NUM_SEQLEN-1);

always @(posedge clk) begin
    if (!nRst || ps_start)  out_row <= #1 'd0;
    else if (m_handshaking) out_row <= #1 last_row ? 'd0 : (out_row + 1'b1);
end

always @(posedge clk) begin
    if (!nRst || ps_start)              frame_done_r <= #1 1'b0;
    else if (m_handshaking && last_row) frame_done_r <= #1 1'b1;
end
//========== ========== ========== row counter ========== ========== ==========

// ---------- ---------- ---------- [J_LOG] 레이어 덤프 ---------- ---------- ----------
// [J_LOG] OH_LightNorm.txt : LightNorm -> Linear 링크 전송 시점
// [J_LOG] OH_Linear.txt    : 이 모듈의 출력 전송 시점
integer jlog_fd;
integer jlog_i;
always @(posedge clk) begin
    if (nRst && lightNorm_m_valid && linEx_s_ready) begin
        jlog_fd = U_log_pkg::opn("OH_LightNorm.txt");
        if (jlog_fd) begin
            for (jlog_i = 0; jlog_i < NUM_DIM; jlog_i = jlog_i + 1)
                begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                    $fwrite(jlog_fd, "%0d", lightNorm_dOut[jlog_i]);
                    if (jlog_i == NUM_DIM-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                end
            $fclose(jlog_fd);
        end
    end
    if (nRst && m_valid && m_ready) begin
        jlog_fd = U_log_pkg::opn("OH_Linear.txt");
        if (jlog_fd) begin
            for (jlog_i = 0; jlog_i < NUM_CLASS; jlog_i = jlog_i + 1)
                begin // [J_LOG] 삼항 포맷문자열을 xsim 은 포맷으로 안 봐. 리터럴로 분리.
                    $fwrite(jlog_fd, "%0d", dOut[jlog_i]);
                    if (jlog_i == NUM_CLASS-1) $fwrite(jlog_fd, "\n"); else $fwrite(jlog_fd, ",");
                end
            $fclose(jlog_fd);
        end
    end
end
// ========== ========== ========== [J_LOG] ========== ========== ==========

endmodule