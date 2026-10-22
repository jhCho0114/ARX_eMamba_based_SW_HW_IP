`timescale 1ns / 1ps
// DWConv3x3 : depthwise Conv 3x3, stride 1, pad 1, bias, per-channel requant (steps 03 / 11 / 24 of every block)
//
//   acc[c]  = bias[c] + sum_{i,j in 0..2} w[c][i][j] * x[c][h+i-1][w+j-1]        (x outside the frame = 0)
//   dOut[c] = sat8(rshr(acc[c], out_rshift[c]))
//
// Datapath: DWConv2d_3x3 (Anh): line buffer of 4 row RAMs (one word = NUM_LANE channels
//   of one column), NUM_LANE channels per cycle through an 8-stage pipeline, a 2-entry output FIFO. One output
//   pixel per ceil(NUM_CH / NUM_LANE) cycles. s_ready keeps the input fewer than 2 rows ahead of the reads.
//   NUM_LANE must be a multiple of 4 (or every channel is a lane); it need not divide NUM_CH: the last chunk
//   of a pixel holds the remaining channels (steps 24: 85 / 170 / 341 / 682 channels run with NUM_LANE lanes).
// Frames: after the last output pixel of a frame has been taken the module restarts itself (one cycle, no input
//   accepted in it), so frames stream continuously after one ps_start.
// Handshake: the common valid / ready rules (registered m_valid, dOut held until m_ready, s_ready independent of
//   s_valid). Contract: no s_valid in the cycle ps_start is 1.
// Parameters: weight / bias broadcast, window WB_BASE = emy_wb_map_pkg::WB_<step>:
//   W  NUM_CH x 9 bytes contiguous (padded to a word)   B  NUM_CH words int32   R  ceil4(NUM_CH) bytes int8 out_rshift
module DWConv3x3 import emy_pkg::*; #(
    parameter integer NUM_CH     = 32,
    parameter integer NUM_HEIGHT = 160,
    parameter integer NUM_WIDTH  = 160,
    parameter integer WB_BASE    = 0,
    parameter integer NUM_LANE   = 8
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:NUM_CH-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer LANE      = (NUM_LANE % 4 == 0) ? NUM_LANE : NUM_CH;
localparam integer NUM_PIXEL = NUM_HEIGHT * NUM_WIDTH;
localparam integer PIX_W     = $clog2(NUM_PIXEL + 1);
localparam integer WB_BASE_B = WB_BASE + ceil4(NUM_CH * 9);
localparam integer WB_BASE_R = WB_BASE_B + 4 * NUM_CH;

// ---------- Frame restart ---------- //
logic [PIX_W-1:0] out_count;
logic             restart, ps_i;

assign ps_i = ps_start | restart;

always @(posedge clk) begin
    if (!nRst || ps_i) begin
        out_count <= #1 '0;
        restart   <= #1 1'b0;
    end else begin
        if (m_valid && m_ready) out_count <= #1 out_count + 1'b1;
        else                    out_count <= #1 out_count;
        restart <= #1 m_valid && m_ready && (out_count == NUM_PIXEL - 1);
    end
end

// ---------- Datapath ---------- //
DWConv2d_3x3 #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM(NUM_CH),
    .NUM_H(NUM_HEIGHT),
    .NUM_W(NUM_WIDTH),
    .NUM_LANE(LANE),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(WB_BASE),
    .WB_BASE_B(WB_BASE_B),
    .WB_BASE_S(WB_BASE_R)
) dw (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_i),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .dOut(dOut),

    .s_valid(s_valid),
    .s_ready(s_ready),
    .m_valid(m_valid),
    .m_ready(m_ready)
);

endmodule
