`timescale 1ns / 1ps
// emy_dw : the depthwise 3x3 engine of the shared-engine eMambaYOLO (docs/ENGINE_SPEC.md §7.2), 8 lanes = one 64-bit word
//
// (a) What it does
//   Depthwise 3x3 convolution, stride 1, zero padding 1 = layers_int8_emamba SW.Conv2d with groups = C:
//       acc[c][y][x] = bias[c] + sum_{i,j in 0..2} w[c][i][j] * in[c][y+i-1][x+j-1]    (in outside the frame = 0)
//       out[c][y][x] = sat8(rshr(acc, rshift[c]))                                  (emy_requant: rshift <= 0 = exact left shift)
//   Datapath transcribed from U_106 ss2d/DWConv2d_3x3.sv: 4 line-buffer slots (row r in slot r mod 4, word = column * NCH
//   + chunk), hist (per chunk the two previous columns), 9 products per lane, sums of 3 then of 3, 34-bit acc + int32 bias,
//   per-channel requant + sat8. Lanes P = 8 (one word = one chunk), NCH = ceil(c_in / 8) chunks per pixel, row length and
//   row window from the command, parameters read from IMG (no WB broadcast), output written word by word (no FIFO: the
//   write port has no back-pressure).
//
// (b) Command fields
//   op = OP_DW. c_in = C (NCH = ceil(C / 8) <= 86), w = W (W * NCH <= 1760), h = H.
//   Input rows [hs, he) = [tile_r0 + row_lo, tile_r0 + row_hi) ∩ [0, h) (row_hi <= 0: to h) of src0, read in raster order on
//   rd0, one word per clk: word src0.addr + p * NCH + cw, p = absolute raster pixel (the window is one contiguous range).
//   Output rows [hs + 1, he - 1), except: F_TOP_PAD = row hs is the frame top (zero row above it, row hs is output);
//   F_BOT_PAD = row he - 1 is the frame bottom (zero row below it, row he - 1 is output). Columns are zero padded at 0 and
//   w - 1. Output word dst.addr + p * NCH + cw (absolute pixel), lanes >= c_in of the last word written 0, wr_be = ff.
//   prm = IMG line of the first parameter chunk. Not used: c_out, shift*, src1, prm2, misc, dir_k, group_g; op is not checked
//   (the sequencer sends only OP_DW here) and flags other than F_TOP_PAD / F_BOT_PAD are ignored; rd1 stays idle.
//   The pad flags are taken literally: the row above hs / below he - 1 is zero whatever hs / he are.
//   A command without output rows, or outside the size limits (w > 160, c_in > 688, W * NCH > 1760, h >= 512), reads and
//   writes nothing and pulses done (simulation also prints an error for the size case).
//
// (c) IMG bytes read
//   4 lines (128 B) per chunk c = channels 8c .. 8c+7, at lines prm + 4c .. prm + 4c + 3 (ENGINE_SPEC §8 DW row):
//     bytes 0..71 w[l][i][j] at byte l*9 + i*3 + j | 72..103 bias int32 x 8 (little-endian) | 104..111 rshift int8 x 8 |
//     112..127 padding. Channels >= C of the last chunk carry zero parameters.
//   4 * NCH lines (<= 344) are read at the start of every command, in parallel with the first input rows.
//
// (d) Cycles per command
//   ((R0 + N_out) * W + 2) * NCH + 15 (measured),  N_out = output rows, R0 = input rows before the first output row can
//   start (1 with F_TOP_PAD, else 2). An output row is W column ticks of NCH clk (the zero-column tick of a row is also
//   tick 0 of the next row; only the first row has its own tick 0). Input reads (one word per clk) run up to two rows ahead
//   of the output row, so after the first rows the walk never waits: whole frame (R0 = 1, N_out = H) ~ (H + 1) * W * NCH,
//   a tile (12 input rows, 10 output rows) ~ 12 * W * NCH = its input reads. The parameter fetch (4 * NCH + 2 clk) is hidden
//   when the first output row waits for at least 3 input pixels, i.e. W >= 4 and more than one input row (W >= 3 suffices);
//   otherwise (tiny windows) the walk starts up to 4 * NCH clk later.
module emy_dw import emy_pkg::*; import emy_engine_pkg::*; (
    input  logic clk,
    input  logic nRst,

    input  logic        cmd_valid,
    output logic        cmd_ready,
    input  cmd_t        cmd,
    input  logic [15:0] tile_r0,
    input  logic [1:0]  dir_k,
    input  logic [15:0] group_g,
    output logic        done,

    output logic                  rd0_en,
    output logic [BUF_ID_W-1:0]   rd0_buf,
    output logic [BUF_ADDR_W-1:0] rd0_addr,
    input  logic [WORD_W-1:0]     rd0_data,
    output logic                  rd1_en,
    output logic [BUF_ID_W-1:0]   rd1_buf,
    output logic [BUF_ADDR_W-1:0] rd1_addr,
    input  logic [WORD_W-1:0]     rd1_data,
    output logic                  wr_en,
    output logic [BUF_ID_W-1:0]   wr_buf,
    output logic [BUF_ADDR_W-1:0] wr_addr,
    output logic [WORD_W-1:0]     wr_data,
    output logic [7:0]            wr_be,

    output logic                  img_en,
    output logic [IMG_ADDR_W-1:0] img_addr,
    input  logic [IMG_LINE_W-1:0] img_data
);

// ---------- Local Parameters ---------- //
localparam int NCH_MAX  = 86;              // chunks per pixel (c_in <= 688)
localparam int CH_W     = 7;
localparam int LB_DEPTH = 1760;            // words per line-buffer slot (W * NCH <= 160 * 11)
localparam int LB_W     = 11;
localparam int ROW_W    = 9;               // rows relative to hs
localparam int PIX_W    = 16;              // pixels of the input window (<= 25,600)
localparam int CW       = 64;              // one chunk = one word = 8 lanes of int8
localparam int SUM_W    = 20;              // 9 products of 16 bit
localparam int ACC_W    = 34;              // int32 bias + the 9-term sum, with headroom (DWConv2d_3x3 ACC_WIDTH)

typedef enum logic [2:0] {S_IDLE, S_LATCH, S_SETUP, S_INIT, S_RUN, S_DONE} state_t;
state_t state;

// ---------- Command registers ---------- //
cmd_t              c;
logic [15:0]       r0_q;
logic              f_top, f_bot;
logic [CH_W-1:0]   nch;                    // chunks per pixel
logic [3:0]        rem;                    // channels in the last chunk (1..8)
logic [7:0]        wcol;                   // W
logic signed [17:0] hs, he;                // input row window (absolute)
logic [11:0]       rowlen;                 // W * NCH: words per row
logic [ROW_W-1:0]  n_in;                   // input rows he - hs
logic [ROW_W-1:0]  or0, oer;               // first / last output row, relative to hs
logic              no_work;
logic              bad_lim, bad_size;      // command outside the size limits (S_LATCH / S_SETUP)
logic              merge_ok;              // W >= 2: the zero-column tick of a row is also tick 0 of the next
logic [PIX_W-1:0]  nb0;                    // pixel base of the row the first output row needs last

// ---------- Parameter fetch ---------- //
logic [8:0]        prm_i, prm_i_d, prm_i_d2;
logic              prm_v_d, prm_v_d2;      // IMG read latency 2 ([Jae 2026-10-18] buffer read latency 2)
logic [255:0]      pa0, pa1, pa2;          // first three lines of the chunk being fetched
(* ram_style = "distributed" *) logic [9*CW-1:0] w_mem [0:NCH_MAX-1];   // w[l][i][j] at byte l*9 + i*3 + j
(* ram_style = "distributed" *) logic [8*32-1:0] b_mem [0:NCH_MAX-1];   // bias int32 x 8
(* ram_style = "distributed" *) logic [8*8-1:0]  s_mem [0:NCH_MAX-1];   // rshift int8 x 8

// ---------- Input side ---------- //
logic [ROW_W-1:0]      ir;                 // relative row of the next read
logic [LB_W-1:0]       iw;                 // word inside the row (= line-buffer address)
logic [CH_W-1:0]       ich;                // chunk inside the pixel
logic [BUF_ADDR_W-1:0] i_addr;
logic                  in1_v, in1b_v, in2_v, in1_pl, in1b_pl, in2_pl;   // in1b: word in flight ([Jae 2026-10-18] buffer read latency 2)
logic [1:0]            in1_s, in1b_s, in2_s;
logic [LB_W-1:0]       in1_a, in1b_a, in2_a;
logic [CW-1:0]         in2_d;
logic [PIX_W-1:0]      wr_pix;             // pixels of the window completely in the line buffer

// ---------- Read walk ---------- //
logic [ROW_W-1:0]  hr;                     // output row (relative to hs)
logic [7:0]        col;                    // column tick 0..W
logic [CH_W-1:0]   k;
logic [LB_W-1:0]   rd_addr;
logic [PIX_W-1:0]  need_q, nbase;          // input pixel tick col needs = nbase + col
logic              lastc_q;                // col == W (the zero column)
logic              rd_done;
logic [CW-1:0]     rd_q [0:3];

// ---------- Pipeline ---------- //
logic              v1, v2, v3, v4, v5, v6, v7;
logic [CH_W-1:0]   k1, k2, k3, k4, k5;
logic              lk1, lk2, lk3, lk4, lk5, lk6;   // last chunk of the pixel (lane mask)
logic              first1, zcol1, out1, top1, bot1;
logic [1:0]        slot1;
(* ram_style = "distributed" *) logic [6*CW-1:0] hist_mem [0:NCH_MAX-1];   // per chunk {column c-1, column c-2}, rows {2,1,0}
logic [6*CW-1:0]   hist_q;
logic [CW-1:0]     new_r0, new_r1, new_r2; // column c, rows h-1, h, h+1
logic [9*CW-1:0]   w_q, w_q2;
logic [9*CW-1:0]   win2;                   // 3 columns x 3 rows x 8 lanes
logic signed [15:0]      prod3 [0:7][0:8];
logic signed [SUM_W-1:0] psum4 [0:7][0:2];
logic signed [SUM_W-1:0] sum5  [0:7];
logic signed [ACC_W-1:0] acc6  [0:7];
logic [8*32-1:0]   b_q;
logic [8*8-1:0]    s_q;
logic signed [7:0] y_rq [0:7];
logic [CW-1:0]     y7;
logic [7:0]        rem_mask;
logic [BUF_ADDR_W-1:0] wa_out;

// ========== ========== ========== Command decode ========== ========== ==========
assign cmd_ready = (state == S_IDLE);

always @(posedge clk) begin
    if (state == S_IDLE && cmd_valid) begin
        c    <= #1 cmd;
        r0_q <= #1 tile_r0;
    end
end

// S_LATCH: sizes and the input row window
always @(posedge clk) begin
    if (state == S_LATCH) begin
        nch   <= #1 CH_W'((c.c_in + 7) >> 3);
        rem   <= #1 (c.c_in[2:0] == 3'd0) ? 4'd8 : {1'b0, c.c_in[2:0]};
        wcol  <= #1 c.w[7:0];
        f_top <= #1 c.flags[F_TOP_PAD];
        f_bot <= #1 c.flags[F_BOT_PAD];
        bad_lim <= #1 (c.w > 16'd160) || (c.c_in > 16'd688) || (c.h >= 16'd512);
        hs    <= #1 ($signed({2'b0, r0_q}) + 18'(c.row_lo) < 0) ? 18'sd0 : ($signed({2'b0, r0_q}) + 18'(c.row_lo));
        he    <= #1 (c.row_hi <= 0 || $signed({2'b0, r0_q}) + 18'(c.row_hi) > $signed({2'b0, c.h})) ? $signed({2'b0, c.h})
                                                                                                    : ($signed({2'b0, r0_q}) + 18'(c.row_hi));
    end
end

// S_SETUP: row length, output rows
wire signed [17:0] n_rows = he - hs;
wire signed [17:0] n_out  = n_rows - (f_top ? 18'sd0 : 18'sd1) - (f_bot ? 18'sd0 : 18'sd1);
always @(posedge clk) begin
    if (state == S_SETUP) begin
        rowlen   <= #1 12'(wcol * nch);
        n_in     <= #1 ROW_W'(n_rows);
        or0      <= #1 f_top ? ROW_W'(0) : ROW_W'(1);
        oer      <= #1 ROW_W'((f_top ? 18'sd0 : 18'sd1) + n_out - 18'sd1);
        bad_size <= #1 bad_lim || (15'(wcol) * 15'(nch) > 15'd1760);
        no_work  <= #1 (n_out <= 0) || (nch == 0) || (wcol == 0) || bad_lim || (15'(wcol) * 15'(nch) > 15'd1760);
        merge_ok <= #1 (wcol >= 8'd2);
        // first output row or0 needs input row min(or0 + 1, n_in - 1) up to its column
        if (f_top) nb0 <= #1 (n_rows == 18'sd1) ? PIX_W'(0) : PIX_W'(wcol);
        else       nb0 <= #1 (n_rows == 18'sd2) ? PIX_W'(wcol) : PIX_W'({wcol, 1'b0});
        rem_mask <= #1 (rem == 4'd8) ? 8'hff : 8'((1 << rem) - 1);
    end
end
wire [BUF_ADDR_W-1:0] off_in = BUF_ADDR_W'(hs[8:0] * rowlen);     // first word of the window (S_INIT)
// [Jae 2026-10-16] tile-relative operands (M_SRC0_REL / M_DST_REL, SPEC §5): the region holds rows from tile_r0 - HALO_ROWS
wire [BUF_ADDR_W-1:0] off_rel = BUF_ADDR_W'(r0_q * rowlen) - BUF_ADDR_W'(HALO_ROWS * rowlen);
wire [BUF_ADDR_W-1:0] off_src = c.misc[M_SRC0_REL] ? off_rel : BUF_ADDR_W'(0);
wire [BUF_ADDR_W-1:0] off_dst = c.misc[M_DST_REL]  ? off_rel : BUF_ADDR_W'(0);

// ========== ========== ========== FSM ========== ========== ==========
wire busy   = in1_v || in1b_v || in2_v || v1 || v2 || v3 || v4 || v5 || v6 || v7;
wire in_end = (ir == n_in);

always @(posedge clk) begin
    if (!nRst) begin
        state <= #1 S_IDLE;
        done  <= #1 1'b0;
    end else begin
        done <= #1 1'b0;
        case (state)
            S_IDLE:  if (cmd_valid) state <= #1 S_LATCH;
            S_LATCH: state <= #1 S_SETUP;
            S_SETUP: state <= #1 S_INIT;
            S_INIT:  state <= #1 no_work ? S_DONE : S_RUN;
            S_RUN:   if (rd_done && in_end && !busy) state <= #1 S_DONE;
            S_DONE:  begin done <= #1 1'b1; state <= #1 S_IDLE; end
            default: state <= #1 S_IDLE;
        endcase
    end
end

// synthesis translate_off
always @(posedge clk)
    if (nRst && state == S_INIT && bad_size)
        $error("emy_dw: command outside the size limits (c_in %0d, w %0d, h %0d; need c_in <= 688, w <= 160, W*NCH <= 1760, h < 512): ignored",
               c.c_in, c.w, c.h);
// synthesis translate_on

// ========== ========== ========== Parameter fetch (IMG lines, overlapped with the first input rows) ========== ==========
wire [8:0] prm_n  = {nch, 2'b00};
wire       prm_ok = (prm_i == prm_n) && !prm_v_d && !prm_v_d2;          // every chunk written into w_mem / b_mem / s_mem
assign img_en   = (state == S_RUN) && (prm_i < prm_n);
assign img_addr = c.prm + IMG_ADDR_W'(prm_i);

always @(posedge clk) begin
    if (!nRst) begin prm_v_d <= #1 1'b0; prm_v_d2 <= #1 1'b0; end
    else begin prm_v_d <= #1 img_en; prm_v_d2 <= #1 prm_v_d; end
    if (!nRst || state == S_INIT) prm_i <= #1 '0;
    else if (img_en)              prm_i <= #1 prm_i + 1'b1;
    if (img_en)  prm_i_d  <= #1 prm_i;
    if (prm_v_d) prm_i_d2 <= #1 prm_i_d;
    if (prm_v_d2 && prm_i_d2[1:0] == 2'd0) pa0 <= #1 img_data;
    if (prm_v_d2 && prm_i_d2[1:0] == 2'd1) pa1 <= #1 img_data;
    if (prm_v_d2 && prm_i_d2[1:0] == 2'd2) pa2 <= #1 img_data;
end

// the chunk is complete with its fourth line: w = bytes 0..71, bias = bytes 72..103, rshift = bytes 104..111
wire            pw_we = prm_v_d2 && (prm_i_d2[1:0] == 2'd3);
wire [CH_W-1:0] pw_ch = prm_i_d2[8:2];
always @(posedge clk) if (pw_we) w_mem[pw_ch] <= #1 {pa2[63:0], pa1, pa0};
always @(posedge clk) if (pw_we) b_mem[pw_ch] <= #1 {img_data[63:0], pa2[255:64]};
always @(posedge clk) if (pw_we) s_mem[pw_ch] <= #1 img_data[127:64];

// ========== ========== ========== Input side: window rows -> line buffer ========== ========== ==========
// row ir goes to slot ir mod 4; it may be read once the walk is at row ir - 2 or later (the slot's previous row,
// ir - 4, is then no longer needed: output row hr reads rows hr - 1 .. hr + 1)
logic [ROW_W:0] hr2;
assign hr2 = {1'b0, hr} + (ROW_W+1)'(2);
wire in_go = (state == S_RUN) && (ir < n_in) && ({1'b0, ir} <= hr2);

assign rd0_en   = in_go;
assign rd0_buf  = c.src0.buf_id;
assign rd0_addr = i_addr;
assign rd1_en   = 1'b0;
assign rd1_buf  = '0;
assign rd1_addr = '0;

always @(posedge clk) begin
    if (state == S_INIT) begin
        ir     <= #1 '0;
        iw     <= #1 '0;
        ich    <= #1 '0;
        i_addr <= #1 c.src0.addr + off_in - off_src;
    end else if (in_go) begin
        i_addr <= #1 i_addr + 1'b1;
        ich    <= #1 (ich == nch - 1) ? '0 : ich + 1'b1;
        if (iw == rowlen - 1) begin iw <= #1 '0; ir <= #1 ir + 1'b1; end
        else                        iw <= #1 iw + 1'b1;
    end
end

// read data two clk after the read, registered, then written into the slot
always @(posedge clk) begin
    if (!nRst) begin
        in1_v  <= #1 1'b0;
        in1b_v <= #1 1'b0;
        in2_v  <= #1 1'b0;
    end else begin
        in1_v  <= #1 in_go;
        in1b_v <= #1 in1_v;
        in2_v  <= #1 in1b_v;
    end
    if (in_go)  begin in1_s  <= #1 ir[1:0]; in1_a  <= #1 iw;     in1_pl  <= #1 (ich == nch - 1); end
    if (in1_v)  begin in1b_s <= #1 in1_s;   in1b_a <= #1 in1_a;  in1b_pl <= #1 in1_pl; end
    if (in1b_v) begin in2_s  <= #1 in1b_s;  in2_a  <= #1 in1b_a; in2_pl  <= #1 in1b_pl; in2_d <= #1 rd0_data; end
    if (state == S_INIT)       wr_pix <= #1 '0;
    else if (in2_v && in2_pl)  wr_pix <= #1 wr_pix + 1'b1;
end

// ========== ========== ========== Read walk ========== ========== ==========
// output row hr = column ticks col = 0..W of NCH chunks. Tick col reads column col of rows hr-1, hr, hr+1 (one word of
// each of 3 slots; zero outside the window / frame) once input (min(hr+1, n_in-1), col) is in. hist keeps per chunk the
// two previous columns, so tick col >= 1 has the 3x3 window of pixel (hr, col-1); tick W uses the zero column.
// Tick W needs no read, so when another row follows (and W >= 2) it also is tick 0 of row hr+1: it reads column 0 of rows
// hr, hr+1, hr+2 into hist (input (min(hr+2, n_in-1), 0) needed) while pixel (hr, W-1) is computed from hist alone.
// A row then takes W ticks; only the first row of a command has its own tick 0.
wire last_row = (hr == oer);
wire mrg      = lastc_q && !last_row && merge_ok;
wire avail    = (lastc_q && !mrg) || (wr_pix > need_q);
wire issue    = (state == S_RUN) && prm_ok && !rd_done && avail;
wire tick_end = (k == nch - 1);
wire [PIX_W-1:0] nbase_nx = (hr2 < {1'b0, n_in}) ? nbase + PIX_W'(wcol) : nbase;   // row min(hr + 2, n_in - 1)

always @(posedge clk) begin
    if (state == S_INIT) begin
        hr      <= #1 or0;
        col     <= #1 '0;
        k       <= #1 '0;
        rd_addr <= #1 '0;
        lastc_q <= #1 1'b0;
        rd_done <= #1 1'b0;
        need_q  <= #1 nb0;
        nbase   <= #1 nb0;
    end else if (issue) begin
        k <= #1 tick_end ? '0 : k + 1'b1;
        if (!lastc_q || mrg) rd_addr <= #1 (rd_addr == rowlen - 1) ? '0 : rd_addr + 1'b1;
        if (tick_end) begin
            if (lastc_q) begin
                hr      <= #1 hr + 1'b1;
                nbase   <= #1 nbase_nx;
                col     <= #1 mrg ? 8'd1 : 8'd0;       // merged: tick 0 of the next row is done
                lastc_q <= #1 1'b0;                    // (merge_ok: W >= 2)
                need_q  <= #1 mrg ? nbase_nx + 1'b1 : nbase_nx;
                if (last_row) rd_done <= #1 1'b1;
            end else begin
                col     <= #1 col + 1'b1;
                lastc_q <= #1 (col == wcol - 1);
                need_q  <= #1 (col == wcol - 1) ? nbase_nx : need_q + 1'b1;   // tick W: column 0 of row hr + 2
            end
        end
    end
end

// line buffer: 4 slots of LB_DEPTH words (block RAM), one write (input) and one read (walk) per clk
genvar s;
generate
    for (s = 0; s < 4; s = s + 1) begin: Slot
        (* ram_style = "block" *) logic [CW-1:0] lb [0:LB_DEPTH-1];
        always @(posedge clk) if (in2_v && in2_s == s) lb[in2_a] <= #1 in2_d;
        always @(posedge clk) if (issue) rd_q[s] <= #1 lb[rd_addr];
    end
endgenerate

// ========== ========== ========== Pipeline ========== ========== ==========
//   S0 issue: slot reads of column col, w_mem[k]      S1 window (new column + hist), hist update
//   S2 9 products per lane       S3 three sums of 3   S4 their sum, b_mem[k]      S5 + bias, s_mem[k]
//   S6 requant (rshr + sat8), lane mask               S7 write
always @(posedge clk) begin
    if (!nRst) begin
        {v1, v2, v3, v4, v5, v6, v7} <= #1 '0;
    end else begin
        v1 <= #1 issue;
        v2 <= #1 v1 && out1;                  // tick 0 only fills hist
        v3 <= #1 v2;
        v4 <= #1 v3;
        v5 <= #1 v4;
        v6 <= #1 v5;
        v7 <= #1 v6;
    end
end

always @(posedge clk) begin
    if (issue) begin
        k1     <= #1 k;
        lk1    <= #1 tick_end;
        first1 <= #1 (col == 0) || mrg;        // hist: shift in column -1 = 0
        zcol1  <= #1 lastc_q;                  // window: newest column = 0 (column W)
        out1   <= #1 (col != 0);               // tick 0 only fills hist
        // rows of the column read: hr-1 .. hr+1, or hr .. hr+2 for a merged tick (tick 0 of row hr+1)
        top1   <= #1 !mrg && (hr == 0);        // row above the window: only reached with F_TOP_PAD
        bot1   <= #1 mrg ? (hr + 1'b1 == n_in - 1) : (hr == n_in - 1);   // row below: only with F_BOT_PAD
        slot1  <= #1 mrg ? hr[1:0] + 2'd1 : hr[1:0];
    end
    if (v1) begin k2 <= #1 k1; lk2 <= #1 lk1; end
    if (v2) begin k3 <= #1 k2; lk3 <= #1 lk2; end
    if (v3) begin k4 <= #1 k3; lk4 <= #1 lk3; end
    if (v4) begin k5 <= #1 k4; lk5 <= #1 lk4; end
    if (v5) lk6 <= #1 lk5;
end

always @(posedge clk) if (issue) w_q <= #1 w_mem[k];

// S1: the new column (rows h-1, h, h+1), the window, hist <= {column c, column c-1} (tick 0 shifts in column -1 = 0).
// Tick W: the window's newest column is 0; hist takes the column read (merged tick: column 0 of the next row; last tick:
// not used again, the next command starts with tick 0)
assign new_r0 = top1 ? '0 : rd_q[slot1 - 2'd1];
assign new_r1 = rd_q[slot1];
assign new_r2 = bot1 ? '0 : rd_q[slot1 + 2'd1];
assign hist_q = hist_mem[k1];

always @(posedge clk) if (v1) hist_mem[k1] <= #1 {new_r2, new_r1, new_r0, first1 ? {3*CW{1'b0}} : hist_q[6*CW-1:3*CW]};
always @(posedge clk) begin
    if (v1) begin
        win2 <= #1 {zcol1 ? {3*CW{1'b0}} : {new_r2, new_r1, new_r0}, hist_q};
        w_q2 <= #1 w_q;
    end
end

// win2 = {col c [r2 r1 r0], col c-1 [r2 r1 r0], col c-2 [r2 r1 r0]}: tap (i, j) = row i, column j
always @(posedge clk) begin
    for (int l = 0; l < 8; l++) begin
        if (v2)
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                    prod3[l][i * 3 + j] <= #1 $signed(w_q2[(l * 9 + i * 3 + j) * 8 +: 8]) *
                                              $signed(win2[(j * 3 + i) * CW + l * 8 +: 8]);
        if (v3)
            for (int q = 0; q < 3; q++)
                psum4[l][q] <= #1 SUM_W'(prod3[l][3 * q]) + prod3[l][3 * q + 1] + prod3[l][3 * q + 2];
        if (v4)
            sum5[l] <= #1 psum4[l][0] + psum4[l][1] + psum4[l][2];
        if (v5)
            acc6[l] <= #1 ACC_W'($signed(b_q[l * 32 +: 32])) + sum5[l];
    end
end

always @(posedge clk) begin
    if (v4) b_q <= #1 b_mem[k4];
    if (v5) s_q <= #1 s_mem[k5];
end

// S6: out = sat8(rshr(acc, rshift)) per lane (runtime shift: emy_requant), lanes >= c_in of the last chunk = 0
genvar gl;
generate
    for (gl = 0; gl < 8; gl = gl + 1) begin: RQ
        emy_requant #(.IN_W(ACC_W), .OUT_W(8)) rq (.din(acc6[gl]), .shift($signed(s_q[gl * 8 +: 8])), .dout(y_rq[gl]));
    end
endgenerate

always @(posedge clk) begin
    if (v6)
        for (int l = 0; l < 8; l++)
            y7[l * 8 +: 8] <= #1 (!lk6 || rem_mask[l]) ? y_rq[l] : 8'd0;
end

// ========== ========== ========== S7: write (output rows are one contiguous word range) ========== ==========
always @(posedge clk) begin
    if (state == S_INIT) wa_out <= #1 c.dst.addr + off_in - off_dst + ((or0 != 0) ? BUF_ADDR_W'(rowlen) : '0);
    else if (v7)         wa_out <= #1 wa_out + 1'b1;
end

assign wr_en   = v7;
assign wr_buf  = c.dst.buf_id;
assign wr_addr = wa_out;
assign wr_data = y7;
assign wr_be   = 8'hff;

endmodule
