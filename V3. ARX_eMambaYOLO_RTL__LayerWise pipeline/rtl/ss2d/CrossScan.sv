`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: CrossScan
// Description: step 13 -- unfold the [d, H, W] output of step 12 into the token sequence of
//              one direction and requantise it to that direction's u shift
//              (layers_int8_emamba.SW.CrossScan + Requant):
//                  u_k[l] = sat8(rshr(x[p_k(l)], NUM_SHIFT_k)),   NUM_SHIFT_k = s_out(12) - s_u[k]
//              with p the raster position h*W + w and
//                  k = 0 row-forward   p = l
//                  k = 1 col-forward   p = (l mod H)*W + l div H
//                  k = 2 row-reverse   p = L-1-l
//                  k = 3 col-reverse   p = p_1(L-1-l)
//              No arithmetic besides the requant: the direction is only an address sequence.
//
//   Write side: the frame in raster order, one token (d channels) per s_valid/s_ready.
//   Read side : dir + start (one cycle) once the frame is in, then L tokens on m_valid/m_ready.
//   The frame stays, so the four directions can be read one after another.
//
//   The frame is a RAM (one write port, one read port, read through a register: one token of
//   d bytes per address), so synthesis maps it to block / ultra RAM.  A read is issued only while
//   the two-entry output FIFO has room for it, and the requant sits between the RAM register and
//   the FIFO: one token per cycle when m_ready stays high, none lost when it drops.
//
// Dependencies: Requant_Lane.sv -> shifter_right.sv, shifter_left.sv (U_eMamba/RTL), Fifo2.sv
//////////////////////////////////////////////////////////////////////////////////
module CrossScan #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_DIM     = 64,
    parameter integer NUM_H       = 160,
    parameter integer NUM_W       = 160,
    parameter integer NUM_SHIFT_0 = 0,
    parameter integer NUM_SHIFT_1 = 0,
    parameter integer NUM_SHIFT_2 = 0,
    parameter integer NUM_SHIFT_3 = 0
)(
    clk,
    nRst,
    ps_start,

    dIn,
    s_valid,
    s_ready,

    dir,
    start,
    dOut,
    m_valid,
    m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_PIXEL = NUM_H * NUM_W;
localparam integer PIX_W     = $clog2(NUM_PIXEL + 1);
localparam integer ROW_W     = ($clog2(NUM_H) > 0) ? $clog2(NUM_H) : 1;
localparam integer COL_W     = ($clog2(NUM_W) > 0) ? $clog2(NUM_W) : 1;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];
input  logic s_valid;
output logic s_ready;

input  logic [1:0] dir;
input  logic       start;
output logic signed [7:0] dOut [0:NUM_DIM-1];
output logic m_valid;
input  logic m_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer ROW_BITS = NUM_DIM * DATA_WIDTH;

logic [ROW_BITS-1:0] frame [0:NUM_PIXEL-1];
logic [ROW_BITS-1:0] din_row, rd_q, u_row;

logic [PIX_W-1:0] wr_count, rd_count;
logic [ROW_W-1:0] h;
logic [COL_W-1:0] w;
logic [1:0]       rd_dir;
logic             reading;          // tokens of this direction left to issue
logic             rd_vld;           // rd_q holds the token read on the previous edge
logic             issue, pop;
logic [1:0]       fcount;
logic [ROW_BITS-1:0] fifo_dout;

logic signed [7:0] u_k [0:3][0:NUM_DIM-1];

// ---------- ---------- ---------- ---------- Write side ---------- ---------- ---------- ----------
assign s_ready = (wr_count < NUM_PIXEL);

genvar g;
generate
    for (g = 0; g < NUM_DIM; g = g + 1) begin: Pack
        assign din_row[g*DATA_WIDTH +: DATA_WIDTH] = dIn[g];
    end
endgenerate

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        wr_count <= #1 '0;
    end else if (s_valid && s_ready) begin
        wr_count <= #1 wr_count + 1'b1;
    end
end

always @(posedge clk) begin
    if (s_valid && s_ready)
        frame[wr_count] <= #1 din_row;
end

// ---------- ---------- ---------- ---------- Read side ---------- ---------- ---------- ----------
// (h, w) walks the frame in direction rd_dir, one step per issued read
assign pop   = m_valid && m_ready;
assign issue = reading && (fcount + rd_vld < 2 + pop);

always @(posedge clk) begin
    if (issue)
        rd_q <= #1 frame[h * NUM_W + w];
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        reading  <= #1 1'b0;
        rd_vld   <= #1 1'b0;
        rd_count <= #1 '0;
        rd_dir   <= #1 2'd0;
    end else if (start) begin
        reading  <= #1 1'b1;
        rd_vld   <= #1 1'b0;
        rd_count <= #1 '0;
        rd_dir   <= #1 dir;
        h        <= #1 (dir >= 2) ? NUM_H - 1 : '0;
        w        <= #1 (dir >= 2) ? NUM_W - 1 : '0;
    end else begin
        rd_vld <= #1 issue;
        if (issue) begin
            rd_count <= #1 rd_count + 1'b1;
            if (rd_count == NUM_PIXEL - 1) reading <= #1 1'b0;
            case (rd_dir)
                2'd0: if (w == NUM_W - 1) begin w <= #1 '0;        h <= #1 h + 1'b1; end else w <= #1 w + 1'b1;
                2'd1: if (h == NUM_H - 1) begin h <= #1 '0;        w <= #1 w + 1'b1; end else h <= #1 h + 1'b1;
                2'd2: if (w == 0)         begin w <= #1 NUM_W - 1; h <= #1 h - 1'b1; end else w <= #1 w - 1'b1;
                2'd3: if (h == 0)         begin h <= #1 NUM_H - 1; w <= #1 w - 1'b1; end else h <= #1 h - 1'b1;
            endcase
        end
    end
end

// ---------- ---------- ---------- ---------- Requant per direction, into the FIFO ---------- ----------
generate
    for (g = 0; g < NUM_DIM; g = g + 1) begin: Requant_Lane
        Requant_Lane #(.DATA_WIDTH_DIN(DATA_WIDTH), .NUM_SHIFT(NUM_SHIFT_0)) requant_0 (.dIn(rd_q[g*DATA_WIDTH +: DATA_WIDTH]), .dOut(u_k[0][g]));
        Requant_Lane #(.DATA_WIDTH_DIN(DATA_WIDTH), .NUM_SHIFT(NUM_SHIFT_1)) requant_1 (.dIn(rd_q[g*DATA_WIDTH +: DATA_WIDTH]), .dOut(u_k[1][g]));
        Requant_Lane #(.DATA_WIDTH_DIN(DATA_WIDTH), .NUM_SHIFT(NUM_SHIFT_2)) requant_2 (.dIn(rd_q[g*DATA_WIDTH +: DATA_WIDTH]), .dOut(u_k[2][g]));
        Requant_Lane #(.DATA_WIDTH_DIN(DATA_WIDTH), .NUM_SHIFT(NUM_SHIFT_3)) requant_3 (.dIn(rd_q[g*DATA_WIDTH +: DATA_WIDTH]), .dOut(u_k[3][g]));
        assign u_row[g*8 +: 8] = u_k[rd_dir][g];
        assign dOut[g]         = fifo_dout[g*8 +: 8];
    end
endgenerate

Fifo2 #(
    .WIDTH(ROW_BITS)
) out_fifo (
    .clk(clk),
    .nRst(nRst),
    .clear(ps_start || start),
    .push(rd_vld),
    .din(u_row),
    .pop(pop),
    .dout(fifo_dout),
    .count(fcount)
);

assign m_valid = (fcount != 2'd0);

endmodule
