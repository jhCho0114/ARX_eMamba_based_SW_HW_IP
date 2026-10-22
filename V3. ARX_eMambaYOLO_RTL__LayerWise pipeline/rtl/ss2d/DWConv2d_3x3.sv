`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: DWConv2d_3x3
// Description: depthwise 3x3 convolution, stride 1, zero padding 1 -- step 11 of SS2D
//              (layers_int8_emamba.SW.Conv2d with groups = channels):
//                  acc[c]      = bias[c] + sum_{i,j in 0..2} weight[c][i][j] * x[c][h+i-1][w+j-1]
//                  dOut[c]     = sat8(rshr(acc[c], rshift[c]))       (x outside the frame = 0)
//
//   Input and output are token streams in raster order, one token = one pixel's NUM_DIM
//   channels, with s_valid/s_ready and m_valid/m_ready.
//
//   NUM_LANE (P) channels are computed per cycle: a token is NCH = ceil(NUM_DIM / P) chunks, and an
//   output pixel takes NCH cycles (P >= NUM_DIM: one pixel per cycle).  When P does not divide
//   NUM_DIM the last chunk has PL = NUM_DIM - (NCH - 1) * P channels: the other lanes of it carry
//   zeros (input, weight, bias and shift) and are dropped from the output token.
//
//   Line buffer: 4 RAMs, one per row slot (row r in slot r % 4), NUM_W * NCH words of P channels,
//   word = column * NCH + chunk.  An input token is written one chunk per cycle.  s_ready holds the
//   input back to fewer than 2 rows ahead of the reads (in_count < rd_pix + 2*NUM_W), so a new row
//   only ever overwrites a row no pending read needs, whatever m_ready does.
//
//   Reads walk each output row h as NUM_W + 1 column ticks c = 0..NUM_W, each tick NCH chunks:
//   tick c reads column c of rows h-1, h, h+1 (one word of each of 3 slots; zero outside the
//   frame, and column NUM_W is all zero), as soon as input (min(h+1, H-1), c) is in.  hist keeps,
//   per chunk, the two previous columns, so tick c >= 1 has the 3x3 window of pixel (h, c-1).
//
//   Pipeline, one chunk per stage, all stages held while the output FIFO is full:
//     S0 issue: RAM read of column c        S1 window (new column + hist), hist update
//     S2 9 products per lane                S3 three sums of 3      S4 their sum
//     S5 + bias                             S6 rounding shift       S7 sat8 -> chunk of the output token
//   The output token is assembled from its NCH chunks and goes into a 2-entry FIFO.
//
//   WB window (byte addresses, 4 bytes per word, lowest byte = lowest index), sent in ascending
//   word order (Wb_Row_Loader counts the words; NUM_LANE % 4 == 0 unless NUM_LANE >= NUM_DIM, so
//   every chunk's rows start on a word; a short last chunk has its own loaders):
//     WB_BASE_W : weight[c][i][j], c then i then j, NUM_DIM*9 bytes (padded to a word)
//     WB_BASE_B : bias[c], one int32 word each
//     WB_BASE_S : rshift[c], one byte each (padded to a word)
//
// Dependencies: Requant_Var_Pipe.sv, Wb_Row_Loader.sv, Fifo2.sv
//////////////////////////////////////////////////////////////////////////////////
module DWConv2d_3x3 #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_DIM     = 64,
    parameter integer NUM_H       = 160,
    parameter integer NUM_W       = 160,
    parameter integer NUM_LANE    = NUM_DIM,
    parameter integer SHIFT_WIDTH = 5,

    parameter integer WB_ADDR_W   = 24,
    parameter integer WB_BASE_W   = 0,
    parameter integer WB_BASE_B   = WB_BASE_W + ((NUM_DIM * 9 + 3) / 4) * 4,
    parameter integer WB_BASE_S   = WB_BASE_B + NUM_DIM * 4
)(
    clk,
    nRst,
    ps_start,

    wb_valid,
    wb_addr,
    wb_data,

    dIn,
    dOut,

    s_valid,
    s_ready,
    m_valid,
    m_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer P         = (NUM_LANE < NUM_DIM) ? NUM_LANE : NUM_DIM;
localparam integer NCH       = (NUM_DIM + P - 1) / P;
localparam integer PL        = NUM_DIM - (NCH - 1) * P;   // channels of the last chunk (1..P)
localparam integer ACC_WIDTH = 34;           // int32 bias + 9 products, with headroom
localparam integer SUM_WIDTH = 2 * DATA_WIDTH + 4;   // 9 products of 2 * DATA_WIDTH bits
localparam integer NUM_PIXEL = NUM_H * NUM_W;
localparam integer PIX_W     = $clog2(NUM_PIXEL + 2 * NUM_W + 1);
localparam integer ROW_W     = ($clog2(NUM_H + 1) > 2) ? $clog2(NUM_H + 1) : 2;   // h[1:0] picks the slot
localparam integer COL_W     = $clog2(NUM_W + 1);
localparam integer CH_W      = ($clog2(NCH) > 0) ? $clog2(NCH) : 1;
localparam integer LB_DEPTH  = NUM_W * NCH;
localparam integer LB_W      = ($clog2(LB_DEPTH) > 0) ? $clog2(LB_DEPTH) : 1;
localparam integer CW        = P * DATA_WIDTH;            // one chunk of one token
localparam integer TW        = NUM_DIM * DATA_WIDTH;      // one token
localparam integer TWP       = NCH * CW;                  // one token in whole chunks

// WB rows: one chunk each (the last one PL channels)
localparam integer W_WORDS  = (P * 9 + 3) / 4;
localparam integer S_WORDS  = (P + 3) / 4;
localparam integer WL_WORDS = (PL * 9 + 3) / 4;
localparam integer SL_WORDS = (PL + 3) / 4;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic                 wb_valid;
input  logic [WB_ADDR_W-1:0] wb_addr;
input  logic [31:0]          wb_data;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM-1];
output logic signed [7:0]            dOut [0:NUM_DIM-1];

input  logic s_valid, m_ready;
output logic s_ready, m_valid;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// weights, bias, shift: one row per chunk
logic [P*9*DATA_WIDTH-1:0] w_mem [0:NCH-1];
logic [P*32-1:0]           b_mem [0:NCH-1];
logic [P*SHIFT_WIDTH-1:0]  s_mem [0:NCH-1];
logic [P*9*DATA_WIDTH-1:0] w_q, w_q2;
logic [P*32-1:0]           b_q;
logic [P*SHIFT_WIDTH-1:0]  s_q;
logic                      w_we, b_we, s_we;
logic [CH_W-1:0]           w_row, b_row, s_row;
logic [P*9*DATA_WIDTH-1:0] w_data;
logic [P*32-1:0]           b_data;
logic [P*DATA_WIDTH-1:0]   s_data;
logic [P*SHIFT_WIDTH-1:0]  s_pack;

// input side
logic [PIX_W-1:0] in_count, wr_count;
logic [TWP-1:0]   din_pad;               // dIn, zero lanes after channel NUM_DIM - 1
logic [TWP-1:0]   in_buf;                // token being written, chunk 0 in the low bits
logic             in_busy;
logic [CH_W-1:0]  wr_ch;
logic [LB_W-1:0]  wr_addr;
logic [1:0]       wr_slot;
logic             wr_last;

// read side
logic [ROW_W-1:0] h;
logic [PIX_W-1:0] hw_base;               // h * NUM_W
logic [PIX_W-1:0] need_q;                // input pixel tick c needs: min(h+1, H-1) * NUM_W + c
logic             lastc_q;               // c == NUM_W
logic [COL_W-1:0] c;
logic [CH_W-1:0]  k;
logic [LB_W-1:0]  rd_addr;
logic [PIX_W-1:0] rd_pix;                // pixels whose reads are all issued
logic             rd_done, avail, issue, tick_end;
logic [CW-1:0]    rd_q [0:3];

// pipeline
logic             adv;
logic             v1, v2, v3, v4, v5, v6, v7;
logic [CH_W-1:0]  k1, k2, k3, k4, k5, k6, k7;
logic             first1, lastc1, top1, bot1;
logic [1:0]       slot1;                 // h % 4 at S1
logic [6*CW-1:0]  hist_mem [0:NCH-1];    // per chunk: {column c-1, column c-2}, rows {2, 1, 0} each
logic [6*CW-1:0]  hist_q;
logic [CW-1:0]    new_r [0:2];           // column c, rows h-1, h, h+1
logic [9*CW-1:0]  win2;                  // window: 3 columns x 3 rows x P lanes
logic signed [2*DATA_WIDTH-1:0] prod3 [0:P-1][0:8];
logic signed [SUM_WIDTH-1:0]    psum4 [0:P-1][0:2];
logic signed [SUM_WIDTH-1:0]    sum5  [0:P-1];
logic signed [ACC_WIDTH-1:0]    acc6  [0:P-1];
logic signed [7:0]              y7    [0:P-1];

// output side
logic [CW-1:0]    y_chunk;
logic [TWP-1:0]   out_token;
logic [(NCH > 1 ? TWP - CW : 1)-1:0] asm_q;  // the first NCH - 1 chunks of the token being built
logic             push, pop;
logic [TW-1:0]    fifo_dout;
logic [1:0]       fcount;

// ---------- ---------- ---------- ---------- Parameter guards ---------- ---------- ---------- ----------
generate
    if (NUM_LANE < 1)
        $error("DWConv2d_3x3: NUM_LANE = %0d", NUM_LANE);
    if (NCH > 1 && P % 4 != 0)
        $error("DWConv2d_3x3: NUM_LANE must be a multiple of 4 (a chunk of the WB rows starts on a word)");
    if (NUM_H < 1 || NUM_W < 1)
        $error("DWConv2d_3x3: empty frame");
endgenerate

// ---------- ---------- ---------- ---------- Weight Broadcast ---------- ---------- ---------- ----------
generate
    if (PL == P) begin: Wb_Even
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_W), .ROWS(NCH), .ROW_WORDS(W_WORDS), .ROW_BITS(P * 9 * DATA_WIDTH))
            load_w (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(w_we), .row(w_row), .data(w_data));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_B), .ROWS(NCH), .ROW_WORDS(P), .ROW_BITS(P * 32))
            load_b (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(b_we), .row(b_row), .data(b_data));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_S), .ROWS(NCH), .ROW_WORDS(S_WORDS), .ROW_BITS(P * DATA_WIDTH))
            load_s (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(s_we), .row(s_row), .data(s_data));
    end else begin: Wb_Short
        // chunks 0 .. NCH-2 as above (NCH >= 2 here); the short last chunk starts on a word right after
        // them and is zero-extended to P lanes.  The two loaders of a region never fire in one cycle.
        localparam integer RF_W = ($clog2(NCH - 1) > 0) ? $clog2(NCH - 1) : 1;
        logic [RF_W-1:0]             w_row_f, b_row_f, s_row_f;
        logic                        w_we_f, b_we_f, s_we_f, w_we_l, b_we_l, s_we_l;
        logic [P*9*DATA_WIDTH-1:0]   w_data_f;
        logic [PL*9*DATA_WIDTH-1:0]  w_data_l;
        logic [P*32-1:0]             b_data_f;
        logic [PL*32-1:0]            b_data_l;
        logic [P*DATA_WIDTH-1:0]     s_data_f;
        logic [PL*DATA_WIDTH-1:0]    s_data_l;

        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_W), .ROWS(NCH - 1), .ROW_WORDS(W_WORDS), .ROW_BITS(P * 9 * DATA_WIDTH))
            load_w (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(w_we_f), .row(w_row_f), .data(w_data_f));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_W + (NCH - 1) * P * 9), .ROWS(1), .ROW_WORDS(WL_WORDS),
                        .ROW_BITS(PL * 9 * DATA_WIDTH))
            load_wl (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                     .we(w_we_l), .row(), .data(w_data_l));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_B), .ROWS(NCH - 1), .ROW_WORDS(P), .ROW_BITS(P * 32))
            load_b (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(b_we_f), .row(b_row_f), .data(b_data_f));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_B + (NCH - 1) * P * 4), .ROWS(1), .ROW_WORDS(PL), .ROW_BITS(PL * 32))
            load_bl (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                     .we(b_we_l), .row(), .data(b_data_l));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_S), .ROWS(NCH - 1), .ROW_WORDS(S_WORDS), .ROW_BITS(P * DATA_WIDTH))
            load_s (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(s_we_f), .row(s_row_f), .data(s_data_f));
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_S + (NCH - 1) * P), .ROWS(1), .ROW_WORDS(SL_WORDS),
                        .ROW_BITS(PL * DATA_WIDTH))
            load_sl (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                     .we(s_we_l), .row(), .data(s_data_l));

        assign w_we   = w_we_f || w_we_l;
        assign b_we   = b_we_f || b_we_l;
        assign s_we   = s_we_f || s_we_l;
        assign w_row  = w_we_l ? CH_W'(NCH - 1) : CH_W'(w_row_f);
        assign b_row  = b_we_l ? CH_W'(NCH - 1) : CH_W'(b_row_f);
        assign s_row  = s_we_l ? CH_W'(NCH - 1) : CH_W'(s_row_f);
        assign w_data = w_we_l ? {{((P - PL) * 9 * DATA_WIDTH){1'b0}}, w_data_l} : w_data_f;
        assign b_data = b_we_l ? {{((P - PL) * 32){1'b0}}, b_data_l} : b_data_f;
        assign s_data = s_we_l ? {{((P - PL) * DATA_WIDTH){1'b0}}, s_data_l} : s_data_f;
    end
endgenerate

always @(posedge clk) begin
    if (w_we) w_mem[w_row] <= #1 w_data;
    if (b_we) b_mem[b_row] <= #1 b_data;
    if (s_we) s_mem[s_row] <= #1 s_pack;
end

genvar l;
generate
    for (l = 0; l < P; l = l + 1) begin: Shift_Pack
        assign s_pack[l * SHIFT_WIDTH +: SHIFT_WIDTH] = s_data[l * DATA_WIDTH +: SHIFT_WIDTH];
    end
endgenerate

// ---------- ---------- ---------- ---------- Input side ---------- ---------- ---------- ----------
// accept a token, then write it one chunk per cycle (the last write cycle can accept the next)
assign wr_last = in_busy && (wr_ch == NCH - 1);
assign s_ready = (!in_busy || wr_last) && (in_count < NUM_PIXEL) && (in_count < rd_pix + 2 * NUM_W);

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        in_count <= #1 '0;
        in_busy  <= #1 1'b0;
        wr_ch    <= #1 '0;
        wr_count <= #1 '0;
        wr_addr  <= #1 '0;
        wr_slot  <= #1 '0;
    end else begin
        if (in_busy) begin
            wr_ch   <= #1 wr_last ? '0 : wr_ch + 1'b1;
            wr_addr <= #1 (wr_addr == LB_DEPTH - 1) ? '0 : wr_addr + 1'b1;
            if (wr_addr == LB_DEPTH - 1) wr_slot <= #1 wr_slot + 1'b1;
            if (wr_last) wr_count <= #1 wr_count + 1'b1;
        end
        if (s_valid && s_ready) begin
            in_count <= #1 in_count + 1'b1;
            in_busy  <= #1 1'b1;
        end else if (wr_last) begin
            in_busy  <= #1 1'b0;
        end
    end
end

generate
    for (l = 0; l < NUM_DIM; l = l + 1) begin: Din_Pad
        assign din_pad[l * DATA_WIDTH +: DATA_WIDTH] = dIn[l];
    end
    if (TWP > TW) begin: Din_Zero
        assign din_pad[TWP-1:TW] = '0;
    end
endgenerate

always @(posedge clk) begin
    if (s_valid && s_ready)
        in_buf <= #1 din_pad;
    else if (in_busy && NCH > 1)
        in_buf <= #1 in_buf >> CW;
end

genvar s;
generate
    for (s = 0; s < 4; s = s + 1) begin: Slot
        logic [CW-1:0] lb [0:LB_DEPTH-1];
        always @(posedge clk) if (in_busy && wr_slot == s) lb[wr_addr] <= #1 in_buf[CW-1:0];
        // read whenever the pipeline moves (the enable stays off the issue logic): rd_addr only
        // steps on an issue, and a read that is not one is dropped (v1 = 0)
        always @(posedge clk) if (adv) rd_q[s] <= #1 lb[rd_addr];
    end
endgenerate

// ---------- ---------- ---------- ---------- Read walk ---------- ---------- ---------- ----------
// tick c of row h needs input (min(h+1, H-1), c) written; tick NUM_W reads nothing.  The pixel index
// is kept in a register stepped with (h, c), so issue is one compare away from flip-flops (worked
// out from h and c each cycle it was the longest path at P = 32)
assign avail    = lastc_q || (wr_count > need_q);
assign issue    = adv && !rd_done && avail;
assign tick_end = (k == NCH - 1);

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        h       <= #1 '0;
        hw_base <= #1 '0;
        need_q  <= #1 (NUM_H == 1) ? PIX_W'(0) : PIX_W'(NUM_W);
        lastc_q <= #1 1'b0;
        c       <= #1 '0;
        k       <= #1 '0;
        rd_addr <= #1 '0;
        rd_pix  <= #1 '0;
        rd_done <= #1 1'b0;
    end else if (issue) begin
        k <= #1 tick_end ? '0 : k + 1'b1;
        if (c != NUM_W) rd_addr <= #1 (rd_addr == LB_DEPTH - 1) ? '0 : rd_addr + 1'b1;
        if (tick_end) begin
            if (c != 0) rd_pix <= #1 rd_pix + 1'b1;
            if (c == NUM_W) begin
                c       <= #1 '0;
                lastc_q <= #1 1'b0;
                h       <= #1 h + 1'b1;
                hw_base <= #1 hw_base + NUM_W;
                need_q  <= #1 (h == NUM_H - 2) ? hw_base + NUM_W : hw_base + 2 * NUM_W;   // row h + 1
                if (h == NUM_H - 1) rd_done <= #1 1'b1;
            end else begin
                c       <= #1 c + 1'b1;
                lastc_q <= #1 (c == NUM_W - 1);
                need_q  <= #1 need_q + 1'b1;
            end
        end
    end
end

// ---------- ---------- ---------- ---------- Pipeline ---------- ---------- ---------- ----------
// the pipeline moves while the output FIFO is not full.  adv is a register (FIFO not full in this
// cycle, worked out the cycle before) so its fanout -- the enable of every pipeline register -- starts
// at a flip-flop Vivado can replicate (from S7 / FIFO logic it missed 300 MHz after routing at P = 8)
wire [1:0] fcount_next = fcount + {1'b0, push} - {1'b0, pop};
(* max_fanout = 64 *) logic adv_q;
always @(posedge clk) begin
    if (!nRst || ps_start) adv_q <= #1 1'b1;
    else                   adv_q <= #1 (fcount_next != 2'd2);
end
assign adv = adv_q;

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        {v1, v2, v3, v4, v5, v6, v7} <= #1 '0;
    end else if (adv) begin
        v1 <= #1 issue;
        v2 <= #1 v1 && !first1;              // tick 0 only fills hist
        v3 <= #1 v2;
        v4 <= #1 v3;
        v5 <= #1 v4;
        v6 <= #1 v5;
        v7 <= #1 v6;
    end
end

always @(posedge clk) begin
    if (adv) begin
        k1 <= #1 k;   k2 <= #1 k1;   k3 <= #1 k2;   k4 <= #1 k3;   k5 <= #1 k4;   k6 <= #1 k5;   k7 <= #1 k6;
        first1 <= #1 (c == 0);
        lastc1 <= #1 (c == NUM_W);
        top1   <= #1 (h == 0);
        bot1   <= #1 (h == NUM_H - 1);
        slot1  <= #1 h[1:0];
    end
end

// S1: the new column (rows h-1, h, h+1), the window, hist <= {column c, column c-1}
//     (tick 0 shifts in column -1 = 0)
assign new_r[0] = (lastc1 || top1) ? '0 : rd_q[slot1 - 2'd1];
assign new_r[1] =  lastc1          ? '0 : rd_q[slot1];
assign new_r[2] = (lastc1 || bot1) ? '0 : rd_q[slot1 + 2'd1];
assign hist_q   = hist_mem[k1];

always @(posedge clk) begin
    if (adv && v1) begin
        hist_mem[k1] <= #1 {new_r[2], new_r[1], new_r[0], first1 ? {3*CW{1'b0}} : hist_q[6*CW-1:3*CW]};
        win2         <= #1 {new_r[2], new_r[1], new_r[0], hist_q};
        w_q2         <= #1 w_q;
    end
end

// the chunk's weights are read with its column (S0) and registered again at S1
always @(posedge clk) if (adv) w_q <= #1 w_mem[k];

// win2 = {col c [r2 r1 r0], col c-1 [r2 r1 r0], col c-2 [r2 r1 r0]}: tap (i, j) = row i, column j
generate
    for (l = 0; l < P; l = l + 1) begin: Lane
        always @(posedge clk) begin
            if (adv && v2)
                for (int i = 0; i < 3; i++)
                    for (int j = 0; j < 3; j++)
                        prod3[l][i * 3 + j] <= #1
                            $signed(w_q2[(l * 9 + i * 3 + j) * DATA_WIDTH +: DATA_WIDTH]) *
                            $signed(win2[(j * 3 + i) * CW + l * DATA_WIDTH +: DATA_WIDTH]);
            if (adv && v3)
                for (int q = 0; q < 3; q++)
                    psum4[l][q] <= #1 SUM_WIDTH'(prod3[l][3 * q]) + prod3[l][3 * q + 1] + prod3[l][3 * q + 2];
            if (adv && v4)
                sum5[l] <= #1 psum4[l][0] + psum4[l][1] + psum4[l][2];
            if (adv && v5)
                acc6[l] <= #1 ACC_WIDTH'($signed(b_q[l * 32 +: 32])) + sum5[l];
        end

        Requant_Var_Pipe #(
            .DATA_WIDTH_DIN(ACC_WIDTH),
            .SHIFT_WIDTH(SHIFT_WIDTH)
        ) requant (
            .clk(clk),
            .en(adv && v6),
            .dIn(acc6[l]),
            .shift(s_q[l * SHIFT_WIDTH +: SHIFT_WIDTH]),
            .dOut(y7[l])
        );
        assign y_chunk[l * DATA_WIDTH +: DATA_WIDTH] = y7[l];
    end
endgenerate

always @(posedge clk) begin
    if (adv && v4) b_q <= #1 b_mem[k4];
    if (adv && v5) s_q <= #1 s_mem[k5];
end

// ---------- ---------- ---------- ---------- Output ---------- ---------- ---------- ----------
assign push = adv && v7 && (k7 == NCH - 1);
assign pop  = m_ready && (fcount != 2'd0);

generate
    if (NCH > 1) begin: Assemble
        assign out_token = {y_chunk, asm_q};
        always @(posedge clk) if (adv && v7 && (k7 != NCH - 1)) asm_q <= #1 ({y_chunk, asm_q} >> CW);
    end else begin: Whole
        assign out_token = y_chunk;
    end
endgenerate

Fifo2 #(.WIDTH(TW)) out_fifo (
    .clk(clk), .nRst(nRst), .clear(ps_start),
    .push(push), .din(out_token[TW-1:0]),
    .pop(pop), .dout(fifo_dout), .count(fcount)
);

assign m_valid = (fcount != 2'd0);
generate
    for (l = 0; l < NUM_DIM; l = l + 1) begin: Out
        assign dOut[l] = fifo_dout[l * DATA_WIDTH +: 8];
    end
endgenerate

endmodule
