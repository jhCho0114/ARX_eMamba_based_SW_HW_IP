`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Linear_Transform_PerCh
// Description: per-token linear layer with a right shift per output channel:
//                  acc[o]  = sum_c weight[o][c] * dIn[c]  (+ bias[o])
//                  dOut[o] = sat8(rshr(acc[o], rshift[o]))  (then max(0, .) if USE_RELU)
//              Used for
//                  09 in_proj, 20 out_proj   Conv2d 1x1, no bias, rshift = out_rshift[o]
//                  14 XProj                  weight = [w_dt; w_B; w_C], rshift per row group
//                  15 DtProj + ReLU          bias = bias[d] << (s_dtlow + s_wdtp - s_bias)
//              (and the block 1x1 convs 01, 04, 06, 23, 28, whose int32 bias is already at
//              accumulator scale).
//
//   Ports, handshake and WB loading as Linear_Transform_Dynamic_WB of eMamba (token in, all output
//   channels out, s_valid/s_ready, m_valid/m_ready), with a shift per output channel and an int32
//   bias at accumulator scale.  The dot product is a pipeline, one output channel per cycle:
//     S0  read the weight row of channel o (a RAM of NUM_DIM_OUT rows, one row = NUM_DIM_IN
//         weights; synthesis maps it to block RAM), then a second register (the RAM's output
//         register: no RAM -> multiplier path)
//     S1  NUM_DIM_IN products, registered
//     S2  the adder tree, a register after every ADD_LEVELS levels (NT register stages)
//     S3  + bias        S4  rounding shift (rshr), registered        S5  sat8 (+ ReLU) -> dOut[o]
//   The sum is the same integer MatMult_Dynamic of eMamba forms (its two-cycle MULT / ADD
//   schedule with a gate-level adder tree was ~140 MHz at 512 inputs); written with + the tree maps
//   onto the carry chains.  Per token: NUM_DIM_OUT + NT + 6 cycles, then DONE until m_ready; the
//   next token's input can load as soon as the last channel's products are taken.
//
//   WB window (byte addresses, 4 bytes per word, lowest byte = lowest index):
//     WB_BASE_W : weight[o][c], row o then c; every row padded to a whole word (ROW_BYTES =
//                 ceil4(NUM_DIM_IN)), so a word never spans two rows; words in ascending order
//     WB_BASE_B : bias[o], one int32 word each               (USE_BIAS only)
//     WB_BASE_S : rshift[o], one byte each (padded to a word)
//
//   Banks (NUM_BANK > 1): NUM_BANK sets of weight / bias / rshift, bank k's window at the addresses
//   above + k * BANK_STRIDE (e.g. the four scan directions of SS2D, which run one after another);
//   the input bank picks the set a token uses and must not change while a token is in the module.
//   NUM_BANK = 1 (the default): one set, bank unused.
//
// Dependencies: Requant_Var_Pipe.sv, Wb_Row_Loader.sv
//////////////////////////////////////////////////////////////////////////////////
module Linear_Transform_PerCh #(
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_DIM_IN  = 32,
    parameter integer NUM_DIM_OUT = 128,
    parameter bit     USE_BIAS    = 1'b0,
    parameter bit     USE_RELU    = 1'b0,
    parameter integer SHIFT_WIDTH = 5,
    parameter integer ADD_LEVELS  = 2,          // adder-tree levels between two registers

    parameter integer WB_ADDR_W   = 24,
    parameter integer WB_BASE_W   = 0,
    parameter integer WB_BASE_B   = WB_BASE_W + NUM_DIM_OUT * (((NUM_DIM_IN + 3) / 4) * 4),
    parameter integer WB_BASE_S   = WB_BASE_B + (USE_BIAS ? NUM_DIM_OUT * 4 : 0),
    parameter integer NUM_BANK    = 1,
    parameter integer BANK_STRIDE = 0
)(
    clk,
    nRst,
    ps_start,

    wb_valid,
    wb_addr,
    wb_data,

    bank,

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
localparam INIT  = 2'd0,
           RUN   = 2'd1,
           DRAIN = 2'd2,
           DONE  = 2'd3;

localparam EMPTY = 1'b0,
           LOAD  = 1'b1;

localparam integer LV             = $clog2(NUM_DIM_IN);                         // adder-tree levels
localparam integer NT             = (LV + ADD_LEVELS - 1) / ADD_LEVELS;         // their register stages
localparam integer NS             = NT + 5;                                     // stage of the dOut write
localparam integer DATA_WIDTH_SUM = DATA_WIDTH + DATA_WIDTH + LV + 1;
localparam integer ACC_WIDTH      = 34;                                         // + int32 bias
localparam integer CNT_WIDTH      = ($clog2(NUM_DIM_OUT) > 0) ? $clog2(NUM_DIM_OUT) : 1;
localparam integer ROW_BYTES      = ((NUM_DIM_IN + 3) / 4) * 4;     // one weight row on the WB bus, padded to a word
localparam integer WPR            = ROW_BYTES / 4;                  // words per row
localparam integer WPR_W          = ($clog2(WPR) > 0) ? $clog2(WPR) : 1;
localparam integer W_BYTES        = NUM_DIM_OUT * ROW_BYTES;
localparam integer S_ROWS         = (NUM_DIM_OUT + 3) / 4;
localparam integer S_W            = ($clog2(S_ROWS) > 0) ? $clog2(S_ROWS) : 1;
// banks: rows of bank k at k * 2^CNT_WIDTH (the row index is {bank, row}); one bank: as before
localparam integer BANK_W         = (NUM_BANK > 1) ? $clog2(NUM_BANK) : 1;
localparam integer RA_W           = (NUM_BANK > 1) ? BANK_W + CNT_WIDTH : CNT_WIDTH;
localparam integer SA_W           = (NUM_BANK > 1) ? BANK_W + S_W : S_W;
localparam integer W_DEPTH        = (NUM_BANK > 1) ? (NUM_BANK << CNT_WIDTH) : NUM_DIM_OUT;
localparam integer S_DEPTH        = (NUM_BANK > 1) ? (NUM_BANK << S_W) : S_ROWS;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic clk, nRst, ps_start;

input  logic                 wb_valid;
input  logic [WB_ADDR_W-1:0] wb_addr;
input  logic [31:0]          wb_data;

input  logic [BANK_W-1:0]    bank;

input  logic signed [DATA_WIDTH-1:0] dIn  [0:NUM_DIM_IN-1];
output logic signed [7:0]            dOut [0:NUM_DIM_OUT-1];

input  logic s_valid, m_ready;
output logic s_ready, m_valid;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [1:0]           state;
logic [CNT_WIDTH-1:0] col;

logic signed [DATA_WIDTH-1:0]     dIn_mem    [0:NUM_DIM_IN-1];
logic [NUM_DIM_IN*DATA_WIDTH-1:0] weight_ram [0:W_DEPTH-1];
logic [NUM_DIM_IN*DATA_WIDTH-1:0] w_q, w_q2;
logic [NUM_DIM_IN*DATA_WIDTH-1:0] row_full;
logic [CNT_WIDTH-1:0]             w_row_now;
logic [WPR_W-1:0]                 w_word_now;
logic                             w_hit, w_last;
logic [BANK_W-1:0]                w_bank;
// per bank: the window hit, its row / word now, its last word
logic [NUM_BANK-1:0]              wk_hit, wk_last;
logic [CNT_WIDTH-1:0]             wk_row_now  [0:NUM_BANK-1];
logic [WPR_W-1:0]                 wk_word_now [0:NUM_BANK-1];
// bias: one word per channel;  shift: one word per 4 channels (lowest byte = lowest channel).  Both
// RAMs, written whole words by Wb_Row_Loader (a per-byte address decode over 1024 shift registers
// missed 300 MHz after routing)
logic [31:0]                      bias_mem   [0:W_DEPTH-1];
logic [31:0]                      shift_mem  [0:S_DEPTH-1];
logic                             b_we, s_we;
logic [RA_W-1:0]                  b_waddr, w_waddr, w_raddr, b_raddr;
logic [SA_W-1:0]                  s_waddr, s_raddr;
logic [NUM_BANK-1:0]              bk_we, sk_we;
logic [CNT_WIDTH-1:0]             bk_row  [0:NUM_BANK-1];
logic [S_W-1:0]                   sk_row  [0:NUM_BANK-1];
logic [31:0]                      bk_data [0:NUM_BANK-1];
logic [31:0]                      sk_data [0:NUM_BANK-1];
logic [31:0]                      b_data, s_data, s_word;
logic [1:0]                       s_sel;
logic signed [31:0]               b_q;
logic        [SHIFT_WIDTH-1:0]    s_q;

// pipeline: v[s] / cp[s] = valid / output channel of the data in stage s's registers
logic                 v  [1:NS];
logic [CNT_WIDTH-1:0] cp [1:NS];
logic                 busy, issue, last_use;
// tree[0] = the products (S1); tree[s + 1] = level s's sums, registered or not
logic signed [DATA_WIDTH_SUM-1:0] tree [0:LV][0:NUM_DIM_IN-1];
logic signed [ACC_WIDTH-1:0]      acc;
logic signed [7:0]                result, result_act;

logic dIn_stat;
logic s_handshaking, m_handshaking;

// ---------- ---------- ---------- ---------- Parameter guards ---------- ---------- ---------- ----------
// rshift values are run-time data: they must be 0 .. 2^SHIFT_WIDTH-1 (right shifts only; a negative
// out_rshift of the export is not supported -- none occurs in steps 09, 14, 15, 20).
generate
    if (SHIFT_WIDTH > 8)
        $error("Linear_Transform_PerCh: SHIFT_WIDTH must be <= 8 (a shift is taken from one WB byte)");
    if (64'(WB_BASE_S) + 64'(NUM_BANK - 1) * BANK_STRIDE + S_ROWS * 4 > (64'd1 << WB_ADDR_W))
        $error("Linear_Transform_PerCh: the WB window does not fit WB_ADDR_W");
    if (NUM_BANK < 1)
        $error("Linear_Transform_PerCh: NUM_BANK must be >= 1");
    if (NUM_BANK > 1 && BANK_STRIDE < WB_BASE_S + S_ROWS * 4 - WB_BASE_W)
        $error("Linear_Transform_PerCh: BANK_STRIDE = %0d is less than one bank's window", BANK_STRIDE);
    if (ADD_LEVELS < 1)
        $error("Linear_Transform_PerCh: ADD_LEVELS must be >= 1");
endgenerate

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

// the token's input is free once the last channel's products are taken (this edge)
assign last_use = v[2] && (cp[2] == NUM_DIM_OUT - 1);
assign s_ready  = (dIn_stat == EMPTY) | last_use;
assign m_valid  = (state == DONE);
assign issue    = (state == RUN);

// ---------- ---------- ---------- ---------- Weight Broadcast ---------- ---------- ---------- ----------
// W: NUM_DIM_OUT rows of ROW_BYTES bytes, in ascending address order (the broadcast sweeps the image):
// the words of a row are gathered in row_words and the row is written with its last word.  The row and
// word counters restart at the first word of the window (the eMamba loader scheme).  One window and
// counter pair per bank; the windows do not overlap, so at most one bank takes a word.  row_words is
// shared: the words of one row must not be interleaved with another bank's (an ascending sweep of
// the image, which every loader here assumes, sends bank k's whole window before bank k+1's).
genvar gb;
generate
    for (gb = 0; gb < NUM_BANK; gb = gb + 1) begin: W_Bank
        localparam integer BASE = WB_BASE_W + gb * BANK_STRIDE;
        logic [CNT_WIDTH-1:0] row_c;
        logic [WPR_W-1:0]     word_c;
        wire hit   = wb_valid && wb_addr >= BASE && wb_addr < BASE + W_BYTES;
        wire first = hit && wb_addr == BASE;
        assign wk_hit[gb]      = hit;
        assign wk_row_now[gb]  = first ? '0 : row_c;
        assign wk_word_now[gb] = first ? '0 : word_c;
        assign wk_last[gb]     = (wk_word_now[gb] == WPR - 1);
        always @(posedge clk) begin
            if (!nRst) begin
                row_c  <= #1 '0;
                word_c <= #1 '0;
            end else if (hit) begin
                if (wk_last[gb]) begin
                    word_c <= #1 '0;
                    row_c  <= #1 wk_row_now[gb] + 1'b1;
                end else begin
                    word_c <= #1 wk_word_now[gb] + 1'b1;
                    row_c  <= #1 wk_row_now[gb];
                end
            end
        end
    end
endgenerate

always @(*) begin
    w_hit = 1'b0; w_last = 1'b0; w_row_now = '0; w_word_now = '0; w_bank = '0;
    for (int k = 0; k < NUM_BANK; k++)
        if (wk_hit[k]) begin
            w_hit = 1'b1; w_last = wk_last[k]; w_row_now = wk_row_now[k]; w_word_now = wk_word_now[k];
            w_bank = BANK_W'(k);
        end
end

// [xsim] the waiting words of a row as a word array and the row assembled word by word (see Wb_Row_Loader:
// xsim garbled a variable part-select into one wide vector and a wide constant part-select of it)
localparam integer W_TAIL = NUM_DIM_IN * DATA_WIDTH - 32 * (WPR - 1);     // bits of the last word in the row
generate
    if (WPR == 1) begin: One_Word_Row
        assign row_full = wb_data[W_TAIL-1:0];
    end else begin: Many_Word_Row
        logic [31:0] row_words [0:WPR-2];
        for (genvar gw = 0; gw < WPR - 1; gw = gw + 1) begin: Word
            assign row_full[gw * 32 +: 32] = row_words[gw];
        end
        assign row_full[NUM_DIM_IN*DATA_WIDTH-1:32 * (WPR - 1)] = wb_data[W_TAIL-1:0];
        always @(posedge clk) if (w_hit && !w_last) row_words[w_word_now] <= #1 wb_data;
    end
    if (NUM_BANK > 1) begin: Bank_Addr
        assign w_waddr = {w_bank, w_row_now};
        assign w_raddr = {bank, col};
    end else begin: One_Addr
        assign w_waddr = w_row_now;
        assign w_raddr = col;
    end
endgenerate

always @(posedge clk) begin
    if (w_hit && w_last)
        weight_ram[w_waddr] <= #1 row_full;
end

// rshift (and bias) words: one Wb_Row_Loader per bank, one write port
generate
    for (gb = 0; gb < NUM_BANK; gb = gb + 1) begin: S_Bank
        Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_S + gb * BANK_STRIDE), .ROWS(S_ROWS), .ROW_WORDS(1), .ROW_BITS(32))
            load_s (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                    .we(sk_we[gb]), .row(sk_row[gb]), .data(sk_data[gb]));
    end
    if (USE_BIAS) begin: Bias
        for (gb = 0; gb < NUM_BANK; gb = gb + 1) begin: B_Bank
            Wb_Row_Loader #(.WB_ADDR_W(WB_ADDR_W), .BASE(WB_BASE_B + gb * BANK_STRIDE), .ROWS(NUM_DIM_OUT), .ROW_WORDS(1), .ROW_BITS(32))
                load_b (.clk(clk), .nRst(nRst), .wb_valid(wb_valid), .wb_addr(wb_addr), .wb_data(wb_data),
                        .we(bk_we[gb]), .row(bk_row[gb]), .data(bk_data[gb]));
        end
    end else begin: No_Bias
        assign bk_we = '0;
        for (gb = 0; gb < NUM_BANK; gb = gb + 1) begin: B_None
            assign bk_row[gb]  = '0;
            assign bk_data[gb] = '0;
        end
    end
endgenerate

always @(*) begin
    s_we = 1'b0; s_waddr = '0; s_data = '0;
    b_we = 1'b0; b_waddr = '0; b_data = '0;
    for (int k = 0; k < NUM_BANK; k++) begin
        if (sk_we[k]) begin
            s_we = 1'b1; s_data = sk_data[k];
            s_waddr = (NUM_BANK > 1) ? SA_W'((k << S_W) | sk_row[k]) : SA_W'(sk_row[k]);
        end
        if (bk_we[k]) begin
            b_we = 1'b1; b_data = bk_data[k];
            b_waddr = (NUM_BANK > 1) ? RA_W'((k << CNT_WIDTH) | bk_row[k]) : RA_W'(bk_row[k]);
        end
    end
end

always @(posedge clk) if (s_we) shift_mem[s_waddr] <= #1 s_data;
always @(posedge clk) if (USE_BIAS && b_we) bias_mem[b_waddr] <= #1 b_data;

// ---------- ---------- ---------- ---------- Input ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start)
        dIn_stat <= #1 EMPTY;
    else if (s_handshaking)
        dIn_stat <= #1 LOAD;
    else if (last_use)
        dIn_stat <= #1 EMPTY;
end

always @(posedge clk) begin
    if (s_handshaking)
        dIn_mem <= #1 dIn;
end

// ---------- ---------- ---------- ---------- Pipeline ---------- ---------- ---------- ----------
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        for (int s = 1; s <= NS; s++) v[s] <= #1 1'b0;
    end else begin
        v[1] <= #1 issue;
        for (int s = 2; s <= NS; s++) v[s] <= #1 v[s-1];
    end
end

always @(posedge clk) begin
    cp[1] <= #1 col;
    for (int s = 2; s <= NS; s++) cp[s] <= #1 cp[s-1];
end

always @(*) begin
    busy = 1'b0;
    for (int s = 1; s <= NS; s++) busy = busy | v[s];
end

// S0: the row of channel col (of the bank), through two registers
always @(posedge clk) begin
    if (issue) w_q  <= #1 weight_ram[w_raddr];
    if (v[1])  w_q2 <= #1 w_q;
end

// S1: products
genvar gi, gs, gk;
generate
    for (gi = 0; gi < NUM_DIM_IN; gi = gi + 1) begin: Prod
        always @(posedge clk) begin
            if (v[2]) tree[0][gi] <= #1 $signed(w_q2[gi*DATA_WIDTH +: DATA_WIDTH]) * dIn_mem[gi];
        end
    end
endgenerate

// S2: the adder tree; level s + 1 is registered at every ADD_LEVELS-th level and at the last one
// (the registers load while a token is in the pipeline: idle otherwise)
generate
    for (gs = 0; gs < LV; gs = gs + 1) begin: Level
        localparam integer N_IN  = (NUM_DIM_IN + (1 << gs) - 1) >> gs;
        localparam integer N_OUT = (N_IN + 1) / 2;
        localparam bit     REG   = ((gs + 1) % ADD_LEVELS == 0) || (gs + 1 == LV);
        for (gk = 0; gk < N_OUT; gk = gk + 1) begin: Node
            if (2 * gk + 1 < N_IN) begin: Pair
                if (REG) begin: R
                    always @(posedge clk) if (busy) tree[gs + 1][gk] <= #1 tree[gs][2 * gk] + tree[gs][2 * gk + 1];
                end else begin: C
                    assign tree[gs + 1][gk] = tree[gs][2 * gk] + tree[gs][2 * gk + 1];
                end
            end else begin: Odd                  // the odd one passes
                if (REG) begin: R
                    always @(posedge clk) if (busy) tree[gs + 1][gk] <= #1 tree[gs][2 * gk];
                end else begin: C
                    assign tree[gs + 1][gk] = tree[gs][2 * gk];
                end
            end
        end
    end
endgenerate

// S3: + bias (bias and shift are read one stage ahead, with the channel of that stage)
generate
    if (NUM_BANK > 1) begin: Bank_Read
        assign b_raddr = {bank, cp[NS-3]};
        assign s_raddr = {bank, S_W'(cp[NS-3] >> 2)};
    end else begin: One_Read
        assign b_raddr = cp[NS-3];
        assign s_raddr = S_W'(cp[NS-3] >> 2);
    end
endgenerate

always @(posedge clk) begin
    if (v[NS-3]) b_q    <= #1 USE_BIAS ? bias_mem[b_raddr] : 32'sd0;
    if (v[NS-3]) s_word <= #1 shift_mem[s_raddr];
    if (v[NS-3]) s_sel  <= #1 cp[NS-3][1:0];
    if (v[NS-2]) s_q    <= #1 s_word[s_sel * 8 +: SHIFT_WIDTH];
    if (v[NS-2]) acc <= #1 ACC_WIDTH'(tree[LV][0]) + ACC_WIDTH'(b_q);
end

// S4: rshr, registered;  S5: sat8 (+ ReLU) -> dOut[channel]
Requant_Var_Pipe #(
    .DATA_WIDTH_DIN(ACC_WIDTH),
    .SHIFT_WIDTH(SHIFT_WIDTH)
) requant (
    .clk(clk),
    .en(v[NS-1]),
    .dIn(acc),
    .shift(s_q),
    .dOut(result)
);

assign result_act = (USE_RELU && result < 0) ? 8'sd0 : result;

always @(posedge clk) begin
    if (v[NS])
        dOut[cp[NS]] <= #1 result_act;
end

// ---------- ---------- ---------- ---------- FSM ---------- ---------- ---------- ----------
// RUN issues channels 0 .. NUM_DIM_OUT-1, one per cycle; DRAIN waits for the last one's write; the
// next token starts after the handshake (dOut is written in place)
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        state <= #1 INIT;
        col   <= #1 '0;
    end else begin
        case (state)
            INIT: if (dIn_stat == LOAD) begin
                col   <= #1 '0;
                state <= #1 RUN;
            end
            RUN: begin
                if (col == NUM_DIM_OUT - 1) begin
                    col   <= #1 '0;
                    state <= #1 DRAIN;
                end else begin
                    col <= #1 col + 1'b1;
                end
            end
            DRAIN: if (v[NS] && cp[NS] == NUM_DIM_OUT - 1) state <= #1 DONE;
            DONE:  if (m_handshaking) state <= #1 (dIn_stat == LOAD) ? RUN : INIT;
        endcase
    end
end

endmodule
