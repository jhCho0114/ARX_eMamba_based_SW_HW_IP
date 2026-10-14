`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/05/2026 03:36:13 PM
// Design Name: 
// Module Name: U_Frame_Sequencer
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


module U_Frame_Sequencer #(
    parameter integer NUM_SEQLEN = 16
)(
    clk,
    nRst,
    ps_start,

    frame_valid,    // input
    frame_done,    // output

    m_valid,    // output
    m_ready,    // input  

    row         // output upcoming sequence index
);

localparam integer SEQ_W = (NUM_SEQLEN > 1) ? $clog2(NUM_SEQLEN) : 1;

localparam IDLE = 0, RUN = 1; // 대기 & 다음거

input logic clk, nRst, ps_start;

input logic frame_valid, m_ready;
output logic frame_done, m_valid;

output logic [SEQ_W-1:0] row;

logic frame_handshaking, m_handshaking;
logic last_row;

logic curr_state, next_state;

assign frame_handshaking = frame_valid & frame_done;
assign m_valid = (curr_state == RUN);
assign m_handshaking = m_valid & m_ready;

assign last_row = (row == NUM_SEQLEN - 1);

// ---------- ---------- ---------- row counter ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst || ps_start) row <= #1 'd0;
    else if (m_handshaking) row <= #1 (last_row) ? 'd0 : row + 1;
end
// ========== ========== ========== row counter ========== ========== ========== 

// ---------- ---------- ---------- frame done ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst || ps_start)                  frame_done <= #1 1'b0;
    else if (m_handshaking && last_row)   frame_done <= #1 1'b1;
    else if (frame_handshaking)             frame_done <= #1 1'b0;
end
// ========== ========== ========== frame done ========== ========== ========== 

// ---------- ---------- ---------- FSM ---------- ---------- ---------- 
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 IDLE;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        IDLE: begin
            if (frame_valid && !frame_done) next_state = RUN;
        end
        RUN: begin
            if (m_handshaking && last_row) next_state = IDLE;
        end
    endcase
end
// ========== ========== ========== FSM ========== ========== ========== 

endmodule