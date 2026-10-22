`timescale 1ns / 1ps
// emy_stream_fifo : FIFO of pixel vectors, show-ahead (dOut = oldest entry while m_valid)
//
//   s_ready = not full, m_valid = not empty (both from registers, no combinational path from valid to ready)
//   write on s_valid & s_ready, read on m_valid & m_ready, both in the same cycle allowed
//   nRst : synchronous, active low. ps_start : synchronous clear (abort; a frame boundary needs no clear, the
//   pointers wrap)
// Storage: a RAM of DEPTH words, one word = one vector (NUM_DIM * DATA_W bits), one write port and one read port
//   with a read register (the block / ultra RAM shape), and a two-entry output buffer in front of dOut (as Fifo2):
//   a RAM read is issued only while the buffer has room for it, so a vector waits in the buffer while m_ready is
//   low and the stream keeps one vector per cycle when nothing stalls. Latency write -> m_valid: 3 clocks.
// DEPTH is set by the layer module from its frame size (H*W), never by hand.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module emy_stream_fifo import emy_pkg::*; #(
    parameter integer NUM_DIM = 128,
    parameter integer DEPTH   = 400,
    parameter integer DATA_W  = ACT_W     // lane width (WIDE_W for a wide residual)
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [DATA_W-1:0] dIn  [0:NUM_DIM-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [DATA_W-1:0] dOut [0:NUM_DIM-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer PTR_W = ($clog2(DEPTH) > 0) ? $clog2(DEPTH) : 1;
localparam integer CNT_W = $clog2(DEPTH + 1);
localparam integer VW    = NUM_DIM * DATA_W;                 // one vector

// ---------- Internal Variables ---------- //
logic [VW-1:0]    mem [0:DEPTH-1];
logic [VW-1:0]    din_v, rd_q, out0, out1;
logic [PTR_W-1:0] wr_ptr, rd_ptr;
logic [CNT_W-1:0] count;                                      // vectors in the RAM not yet read out of it
logic [CNT_W-1:0] total;                                      // vectors accepted and not yet taken (s_ready)
logic             rd_v;                                       // rd_q holds a vector (read issued last cycle)
logic [1:0]       ocount;                                     // vectors in the output buffer
logic             s_handshaking, m_handshaking, rd_issue, push, pop;

genvar g;
generate
    for (g = 0; g < NUM_DIM; g = g + 1) begin : Pack
        assign din_v[g*DATA_W +: DATA_W] = dIn[g];
        assign dOut[g]                   = out0[g*DATA_W +: DATA_W];
    end
endgenerate

assign s_ready = (total < DEPTH);
assign m_valid = (ocount != 2'd0);

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;
assign pop           = m_handshaking;
assign push          = rd_v;
// a read is issued only when the buffer will have room for it when it lands (one read in flight at most)
assign rd_issue      = (count != 0) && ((ocount + CNT_W'(rd_v) - CNT_W'(pop)) < 2);

// ---------- RAM ---------- //
always @(posedge clk) begin
    if (s_handshaking)
        mem[wr_ptr] <= #1 din_v;
end

always @(posedge clk) begin
    if (rd_issue) rd_q <= #1 mem[rd_ptr];
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        wr_ptr <= #1 '0;
        rd_ptr <= #1 '0;
        count  <= #1 '0;
        total  <= #1 '0;
        rd_v   <= #1 1'b0;
    end else begin
        if (s_handshaking) wr_ptr <= #1 (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1'b1;
        else               wr_ptr <= #1 wr_ptr;
        if (rd_issue)      rd_ptr <= #1 (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1'b1;
        else               rd_ptr <= #1 rd_ptr;
        count <= #1 count + CNT_W'(s_handshaking) - CNT_W'(rd_issue);
        total <= #1 total + CNT_W'(s_handshaking) - CNT_W'(pop);
        rd_v  <= #1 rd_issue;
    end
end

// ---------- Output buffer (two entries, oldest in out0) ---------- //
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        ocount <= #1 2'd0;
    end else begin
        case ({push, pop})
            2'b10:   ocount <= #1 ocount + 1'b1;
            2'b01:   ocount <= #1 ocount - 1'b1;
            default: ocount <= #1 ocount;
        endcase
    end
end

always @(posedge clk) begin
    case ({push, pop})
        2'b10: begin
            if (ocount == 2'd0) out0 <= #1 rd_q;
            else                out1 <= #1 rd_q;
        end
        2'b01: out0 <= #1 out1;
        2'b11: begin
            if (ocount == 2'd1) out0 <= #1 rd_q;
            else begin
                out0 <= #1 out1;
                out1 <= #1 rd_q;
            end
        end
        default: ;
    endcase
end

endmodule
