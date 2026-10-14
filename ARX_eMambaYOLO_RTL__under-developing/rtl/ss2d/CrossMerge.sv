`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: CrossMerge
// Description: step 17 -- put the four direction outputs y_k back on the [H, W] grid and sum them
//              (layers_int8_emamba.SW.CrossMerge), then requantise into step 18 (out_norm):
//                  wide[p] = sum_k y_k[l_k(p)] << NUM_LSH_k        NUM_LSH_k = T - s_y[k],  T = max s_y
//                  dOut[p] = sat8(rshr(wide[p], NUM_RSH))          NUM_RSH   = T - s_in(18)
//              The sum is exact (the golden keeps it wide); only the requant rounds.
//
//   Write side: for each direction, dir + start (one cycle), then its L tokens in scan order on
//   s_valid/s_ready.  Token l of direction k is stored at the position p_k(l) it came from
//   (the same address walk as CrossScan), so the merge reads all four at the same address.
//   Read side : merge (one cycle) after the four directions, then L tokens in raster order on
//   m_valid/m_ready -- dOut (int8, input of 18) and dOut_wide (the exact sum, for checking).
//
//   Storage is one RAM of the running sum, wide[L][d] (WIDE_WIDTH bits per lane, one token per
//   address, read through a register), not the four y_k: direction 0 writes y_0 << NUM_LSH_0,
//   directions 1-3 read the sum at the position, add y_k << NUM_LSH_k and write it back (integer, so
//   the order of the four additions does not change it).  Half the memory of four int8 frames, and a
//   shape synthesis maps to block / ultra RAM.  Two-stage read-add-write: a token that hits the
//   position written on the same edge (the last token of direction 1 and the first of direction 2
//   are both at L-1) takes the sum being written instead of the stale RAM word.  The merge reads only
//   once the last write is done (direction 3 ends at position 0, where the merge starts), through a
//   two-entry output FIFO.
//
// Dependencies: Requant_Lane.sv -> shifter_right.sv, shifter_left.sv (U_eMamba/RTL), Fifo2.sv
//////////////////////////////////////////////////////////////////////////////////
module CrossMerge #(
    parameter integer DATA_WIDTH = 8,
    parameter integer WIDE_WIDTH = 16,
    parameter integer NUM_DIM    = 64,
    parameter integer NUM_H      = 160,
    parameter integer NUM_W      = 160,
    parameter integer NUM_LSH_0  = 0,
    parameter integer NUM_LSH_1  = 0,
    parameter integer NUM_LSH_2  = 0,
    parameter integer NUM_LSH_3  = 0,
    parameter integer NUM_RSH    = 1,
    parameter         RAM_STYLE  = "block"      // the running-sum RAM: shallow (L) and wide (d x 16 bit), so the
                                                // tool's own choice is distributed RAM (131k LUTs at L07)
)(
    clk,
    nRst,
    ps_start,

    dir,
    start,
    dIn,
    s_valid,
    s_ready,

    merge,
    dOut,
    dOut_wide,
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

input  logic [1:0] dir;
input  logic       start;
input  logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1];
input  logic s_valid;
output logic s_ready;

input  logic merge;
output logic signed [7:0]            dOut      [0:NUM_DIM-1];
output logic signed [WIDE_WIDTH-1:0] dOut_wide [0:NUM_DIM-1];
output logic m_valid;
input  logic m_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer ACC_BITS = NUM_DIM * WIDE_WIDTH;

(* ram_style = RAM_STYLE *) logic [ACC_BITS-1:0] acc_mem [0:NUM_PIXEL-1];
logic [ACC_BITS-1:0] rd_q, y_sh, y_q, old_sum, new_sum, fwd_q;

logic [PIX_W-1:0] wr_count, rd_count, addr_now, p_q, rd_addr;
logic [ROW_W-1:0] h;
logic [COL_W-1:0] w;
logic [1:0]       wr_dir;
logic             writing, reading;
logic             accept, first_q, vld_q, fwd_hit_q;
logic             rd_vld, issue, pop;
logic [1:0]       fcount;
logic [ACC_BITS-1:0] fifo_dout;

// ---------- ---------- ---------- ---------- Parameter guards ---------- ---------- ---------- ----------
localparam integer MAX_LSH = (NUM_LSH_0 > NUM_LSH_1 ? NUM_LSH_0 : NUM_LSH_1) > (NUM_LSH_2 > NUM_LSH_3 ? NUM_LSH_2 : NUM_LSH_3)
                           ? (NUM_LSH_0 > NUM_LSH_1 ? NUM_LSH_0 : NUM_LSH_1) : (NUM_LSH_2 > NUM_LSH_3 ? NUM_LSH_2 : NUM_LSH_3);
generate
    if (NUM_LSH_0 < 0 || NUM_LSH_1 < 0 || NUM_LSH_2 < 0 || NUM_LSH_3 < 0)
        $error("CrossMerge: NUM_LSH_k = T - s_y[k] must be >= 0 (T is the largest s_y)");
    if (WIDE_WIDTH < DATA_WIDTH + MAX_LSH + 2)
        $error("CrossMerge: WIDE_WIDTH must be >= DATA_WIDTH + max NUM_LSH_k + 2 (sum of four shifted int8)");
endgenerate

// ---------- ---------- ---------- ---------- Write side: read, add y_k, write back ---------- ----------
assign s_ready  = writing;
assign accept   = writing && s_valid;
assign addr_now = h * NUM_W + w;

genvar g;
generate
    for (g = 0; g < NUM_DIM; g = g + 1) begin: Lane
        logic signed [WIDE_WIDTH-1:0] y_ext, old_l, sum_l;
        assign y_ext = WIDE_WIDTH'(dIn[g]);
        always_comb begin
            case (wr_dir)
                2'd0:    y_sh[g*WIDE_WIDTH +: WIDE_WIDTH] = y_ext <<< NUM_LSH_0;
                2'd1:    y_sh[g*WIDE_WIDTH +: WIDE_WIDTH] = y_ext <<< NUM_LSH_1;
                2'd2:    y_sh[g*WIDE_WIDTH +: WIDE_WIDTH] = y_ext <<< NUM_LSH_2;
                default: y_sh[g*WIDE_WIDTH +: WIDE_WIDTH] = y_ext <<< NUM_LSH_3;
            endcase
        end
        assign old_l = old_sum[g*WIDE_WIDTH +: WIDE_WIDTH];
        assign sum_l = old_l + $signed(y_q[g*WIDE_WIDTH +: WIDE_WIDTH]);
        assign new_sum[g*WIDE_WIDTH +: WIDE_WIDTH] = sum_l;
    end
endgenerate

// direction 0 starts the sum; otherwise the word read with the token, or the sum written on that edge
assign old_sum = first_q ? '0 : (fwd_hit_q ? fwd_q : rd_q);

// start may coincide with the last token of the previous direction: that token is taken with the old
// wr_dir, h, w, and the counters restart for the new direction
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        writing <= #1 1'b0;
        vld_q   <= #1 1'b0;
    end else begin
        vld_q <= #1 accept;
        if (start) begin
            writing  <= #1 1'b1;
            wr_count <= #1 '0;
            wr_dir   <= #1 dir;
            h        <= #1 (dir >= 2) ? NUM_H - 1 : '0;
            w        <= #1 (dir >= 2) ? NUM_W - 1 : '0;
        end else if (accept) begin
            wr_count <= #1 wr_count + 1'b1;
            if (wr_count == NUM_PIXEL - 1) writing <= #1 1'b0;
            case (wr_dir)
                2'd0: if (w == NUM_W - 1) begin w <= #1 '0;        h <= #1 h + 1'b1; end else w <= #1 w + 1'b1;
                2'd1: if (h == NUM_H - 1) begin h <= #1 '0;        w <= #1 w + 1'b1; end else h <= #1 h + 1'b1;
                2'd2: if (w == 0)         begin w <= #1 NUM_W - 1; h <= #1 h - 1'b1; end else w <= #1 w - 1'b1;
                2'd3: if (h == 0)         begin h <= #1 NUM_H - 1; w <= #1 w - 1'b1; end else h <= #1 h - 1'b1;
            endcase
        end
    end
end

always @(posedge clk) begin
    if (accept) begin
        p_q       <= #1 addr_now;
        y_q       <= #1 y_sh;
        first_q   <= #1 (wr_dir == 2'd0);
        fwd_hit_q <= #1 vld_q && (p_q == addr_now);
        fwd_q     <= #1 new_sum;
    end
end

// ---------- ---------- ---------- ---------- The RAM: one write port, one registered read port ---------- ----------
always @(posedge clk) begin
    if (vld_q)
        acc_mem[p_q] <= #1 new_sum;
end

// one read address and one enable: written as two reads (one per branch) the tool sees two read ports
// plus the write port, which block RAM cannot give (it fell back to 131k LUTs of distributed RAM)
assign rd_addr = accept ? addr_now : rd_count;

always @(posedge clk) begin
    if (accept || issue)
        rd_q <= #1 acc_mem[rd_addr];
end

// ---------- ---------- ---------- ---------- Read side: raster order, through the FIFO ---------- ----------
assign pop   = m_valid && m_ready;
assign issue = reading && !vld_q && !accept && (fcount + rd_vld < 2 + pop);

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        reading  <= #1 1'b0;
        rd_vld   <= #1 1'b0;
        rd_count <= #1 '0;
    end else if (merge) begin
        reading  <= #1 1'b1;
        rd_vld   <= #1 1'b0;
        rd_count <= #1 '0;
    end else begin
        rd_vld <= #1 issue;
        if (issue) begin
            rd_count <= #1 rd_count + 1'b1;
            if (rd_count == NUM_PIXEL - 1) reading <= #1 1'b0;
        end
    end
end

Fifo2 #(
    .WIDTH(ACC_BITS)
) out_fifo (
    .clk(clk),
    .nRst(nRst),
    .clear(ps_start || merge),
    .push(rd_vld),
    .din(rd_q),
    .pop(pop),
    .dout(fifo_dout),
    .count(fcount)
);

assign m_valid = (fcount != 2'd0);

generate
    for (g = 0; g < NUM_DIM; g = g + 1) begin: Out_Lane
        assign dOut_wide[g] = fifo_dout[g*WIDE_WIDTH +: WIDE_WIDTH];

        Requant_Lane #(
            .DATA_WIDTH_DIN(WIDE_WIDTH),
            .NUM_SHIFT(NUM_RSH)
        ) requant (
            .dIn(dOut_wide[g]),
            .dOut(dOut[g])
        );
    end
endgenerate

endmodule
