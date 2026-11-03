`timescale 1ns / 1ps
// emy_out_adapter : BUF_OUT words of the vector engine (VEC_OUTROWS, emy_buf out_wr_*) -> BRAM_OUT 64-byte rows (SPEC §7.4, §10)
//
//   Word address (emy_engine_pkg): head = addr[19:18] (0 P3, 1 P4, 2 P5), row in the frame = addr[17:3], word in the row = addr[2:0].
//   Words enter a FIFO (2^FIFO_AW words); `out_room` = at least ROOM_WORDS free entries, so the vector engine (which stops issuing
//   when out_room = 0 but still has DRAIN words in flight) never overflows it. The assembler pops one word per clock into a 512-bit
//   row; a complete row is written to BRAM_OUT when the head's current slot is free (out_full[2 * head + cur] = 0).
//   Slot convention of emy_ip_core as is: P3 slots 0 / 2^(OUT_AW-2) (2^(OUT_AW-2) / 64 rows each), P4 slots at 2^(OUT_AW-1) and
//   P5 slots at 2^(OUT_AW-1) + 2^(OUT_AW-2) (2^(OUT_AW-3) / 64 rows each); rows of a slot are consecutive; out_fill[2 * head + slot]
//   pulses one clock after the last row of a slot (or the last row of the frame) is written; then the other slot is used.
//   Frame rows per head = parameters P3_ROWS / P4_ROWS / P5_ROWS: the neck outputs 6,400 / 3,200 / 1,600 (80x80x1, 40x40x2,
//   20x20x4, default) or, with the L21 Detect head on the engine (gen_program --layers 21), 19,200 / 4,800 / 1,200 (3 rows per
//   pixel: box, cls 0-63, cls 64-79 + zeros; CPU_SEQUENCE §5) — [Jae 2026-10-19]. The frame row count ends the current slot
//   early when a frame is not a multiple of the slot rows (none of the two layouts is: 32 / 16 rows per slot divide all six).
//   ps_start (restart) resets the slot pointers and the FIFO.
//
//   [Jae 2026-10-21] candidate filter (filt_en, S_AXI FILTER register) — for the 3-rows-per-pixel head layout only:
//     rows of a head are counted mod 3 (box, cls 0-63, cls 64-79). The box row is parked (box_r[head]); the cls rows are scanned as
//     their words leave the FIFO (8 bytes per clock, two pipeline stages: 8-byte max, then the running max of the pixel; the first
//     channel wins a tie, as np.argmax). At the end of the third row the pixel is a candidate when qmax >= qthr[head] (signed int8;
//     CPU_SEQUENCE §5: conf > 0.25 <=> qthr -4 / -2 / -4 for cls shifts 2 / 1 / 2). A candidate emits two rows through the same slot
//     path: a META row = byte 0-1 pixel index (LE), 2 head, 3 cls, 4 qmax, 5 format (1), rest 0, then the parked box row.
//     Other pixels emit nothing. At the end of the frame (frame_end = sequencer END) each head gets an END row (format 0xFF,
//     byte 0-1 = candidate count of the head, byte 2 = head) and its partially filled slot is filled (out_fill) so the CPU can read
//     it; the CPU reads (META, box) pairs until the END row (META first, so a row in a header position is always adapter-made and its format byte is authoritative; a box row may contain any byte). OUT_ROWS counts the rows actually written.
//     filt_en = 0 is the previous behaviour bit for bit (no END rows; slots end by the frame row count).
//     DET mode (det_en, FILTER[1], B-plan): instead of (META, box) the candidate goes through emy_head_math (sigmoid, DFL x 4, corners;
//       19 clocks, bit-exact with the C emy_head_post.c) and ONE DET row is written: byte 0-1 pixel LE, 2 head, 3 cls, 4 qmax, 5 format 0x02,
//       6-7 conf (x65536), 8-15 x1 y1 x2 y2 (int16, 1/16 px), rest 0. The decision of the next candidate waits while the unit is busy
//       (pixels arrive at most every 24 clocks — 3 rows x 8 words — so it practically never waits). END rows as in META mode.
//     NMS mode (nms_en, FILTER[2], with DET mode): the DET rows are not written but stored in emy_nms (CAND_MAX 512, more are dropped and
//       counted); at the frame end, after everything of the frame has been stored, the unit runs the class-wise NMS (bit-exact with the C
//       emy_hp_finish, 7/10 constant) and its detection rows (format 0x03, same bytes as the DET row) go through head 0's slots in
//       conf order; then the END rows: head 0 = detections (bytes 0-1), heads 1 / 2 = 0; bytes 8-9 = candidates of that head,
//       bytes 10-11 = dropped candidates (head 0). OUT_ROWS = detections + 3. The CPU reads head 0 rows until END and only copies.
//     drained = nothing left in the FIFO / assembler / output queue / head-math unit and the frame-end flush is done: the engine delays frame_done
//     to the registers until drained, in both modes, so FRAME_DONE never precedes the last out_fill.
module emy_out_adapter import emy_engine_pkg::*; #(
    parameter int OUT_AW     = 13,            // BRAM_OUT byte address bits (8 KB)
    parameter int FIFO_AW    = 6,             // 64 words
    parameter int ROOM_WORDS = 16,            // out_room while this many entries are free
    parameter int P3_ROWS    = 6400,          // BRAM_OUT rows per frame, head 0 (gen_program program.json out_rows)
    parameter int P4_ROWS    = 3200,          //   head 1
    parameter int P5_ROWS    = 1600,          //   head 2
    parameter int P3_W       = 80,            // pixels per row of the head grids (DET mode corners): 80 / 40 / 20
    parameter int P4_W       = 40,
    parameter int P5_W       = 20
)(
    input  logic clk,
    input  logic nRst,
    input  logic restart,                     // ps_start

    // from emy_buf (BUF_OUT writes of the active engine)
    input  logic                  wr_en,
    input  logic [BUF_ADDR_W-1:0] wr_addr,
    input  logic [WORD_W-1:0]     wr_data,
    output logic                  out_room,

    // candidate filter (S_AXI FILTER register) and frame end (sequencer END pulse)
    input  logic                  filt_en,
    input  logic signed [7:0]     qthr0,      // head 0 (P3)
    input  logic signed [7:0]     qthr1,      // head 1 (P4)
    input  logic signed [7:0]     qthr2,      // head 2 (P5)
    input  logic                  det_en,     // DET mode: one DET row per candidate (emy_head_math) instead of (META, box)
    input  logic                  nms_en,     // NMS mode (with det_en): DET rows stored, NMS at the frame end, detection rows + END
    input  logic                  frame_end,
    output logic                  drained,

    // slot state (S_AXI registers) and the BRAM_OUT port
    input  logic [5:0]            out_full,   // {P5 s1, P5 s0, P4 s1, P4 s0, P3 s1, P3 s0}
    output logic [5:0]            out_fill,
    output logic                  out_bram_en,
    output logic [63:0]           out_bram_we,
    output logic [OUT_AW-1:0]     out_bram_addr,
    output logic [511:0]          out_bram_din,

    // status
    output logic                  fifo_overflow,   // sticky until restart (should never happen)
    output logic [31:0]           rows_written
);

localparam int ROW_B     = 64;
localparam int P3_ROWS_S = (2 ** (OUT_AW - 2)) / ROW_B;
localparam int PX_ROWS_S = (2 ** (OUT_AW - 3)) / ROW_B;
localparam int DEPTH     = 1 << FIFO_AW;
localparam int FW        = 2 + 3 + WORD_W;        // head, word-in-row, data
localparam logic [7:0] FMT_META = 8'h01, FMT_END = 8'hFF;   // DET rows (8'h02) are made by emy_head_math

function automatic int slot_rows(input int s);  return (s == 0) ? P3_ROWS_S : PX_ROWS_S; endfunction
function automatic int frame_rows(input int s); return (s == 0) ? P3_ROWS : (s == 1) ? P4_ROWS : P5_ROWS; endfunction
function automatic int head_w(input int s);     return (s == 0) ? P3_W : (s == 1) ? P4_W : P5_W; endfunction
function automatic int slot_base(input int s, input int k);    // byte address of slot k of head s
    return (s == 0) ? k * (2 ** (OUT_AW - 2)) : (2 ** (OUT_AW - 1)) + (s - 1) * (2 ** (OUT_AW - 2)) + k * (2 ** (OUT_AW - 3));
endfunction

// ---------- word FIFO ---------- //
logic [FW-1:0]      fifo [0:DEPTH-1];
logic [FIFO_AW:0]   wp, rp;                       // one extra bit: full / empty
wire  [FIFO_AW:0]   count = wp - rp;
wire                empty = (count == '0);
wire                full  = (count == DEPTH);
wire  [1:0]         wr_head = wr_addr[OUT_HEAD_SHIFT +: 2];
wire  [2:0]         wr_k    = wr_addr[2:0];
logic               pop;

assign out_room = (DEPTH - count) >= ROOM_WORDS;

always @(posedge clk) begin
    if (!nRst || restart) begin
        wp <= #1 '0; rp <= #1 '0; fifo_overflow <= #1 1'b0;
    end else begin
        if (wr_en) begin
            if (full) fifo_overflow <= #1 1'b1;
            else begin fifo[wp[FIFO_AW-1:0]] <= #1 {wr_head, wr_k, wr_data}; wp <= #1 wp + 1'b1; end
        end
        if (pop) rp <= #1 rp + 1'b1;
    end
end
wire [FW-1:0] head_word = fifo[rp[FIFO_AW-1:0]];
wire [1:0]    hw_head   = head_word[WORD_W+3 +: 2];
wire [2:0]    hw_k      = head_word[WORD_W +: 3];

// ---------- row assembler ---------- //
logic [511:0] row;
logic [1:0]   row_head;
logic         row_full;                           // a complete row waits (legacy: for its slot; filter: for the decision)

// ---------- filter: per-head row kind, pixel, running max; cls scan pipeline on the pop stream ---------- //
logic [1:0]        rk   [0:2];                    // kind of the row being assembled for the head: 0 box, 1 cls 0-63, 2 cls 64-79
logic [15:0]       pix  [0:2];                    // pixel index of the pixel being assembled
logic [6:0]        cx   [0:2], cy [0:2];           // its column / row in the head grid (DET mode corners), advance with pix
logic signed [7:0] qmax [0:2];
logic [6:0]        cls  [0:2];
logic [511:0]      box_r [0:2];                   // parked box row
logic signed [7:0] qthr [0:2];
assign qthr[0] = qthr0; assign qthr[1] = qthr1; assign qthr[2] = qthr2;
logic              dec_fire;                      // the pixel of dec_head is decided this clock (declared early: used by the pipeline)
logic [1:0]        dec_head;

// stage 1: the popped word (registered) -> 8-byte max and its index; stage 2: running max of the pixel
logic              p1_v, p2_v;
logic [1:0]        p1_head, p2_head;
logic [2:0]        p1_k;
logic [1:0]        p1_kind, p2_kind;
logic [WORD_W-1:0] p1_data;
logic signed [7:0] p2_m8;
logic [5:0]        p2_ch;                         // channel inside the row (0..63) of the 8-byte max
logic              p2_use;                        // this word takes part (kind 1 all words, kind 2 words 0..1)

function automatic void max8(input logic [WORD_W-1:0] d, output logic signed [7:0] m, output logic [2:0] i);
    logic signed [7:0] a [0:7]; logic signed [7:0] m01, m23, m45, m67, m03, m47; logic [2:0] i01, i23, i45, i67, i03, i47;
    for (int b = 0; b < 8; b++) a[b] = d[8*b +: 8];
    if (a[1] > a[0]) begin m01 = a[1]; i01 = 3'd1; end else begin m01 = a[0]; i01 = 3'd0; end   // first wins a tie
    if (a[3] > a[2]) begin m23 = a[3]; i23 = 3'd3; end else begin m23 = a[2]; i23 = 3'd2; end
    if (a[5] > a[4]) begin m45 = a[5]; i45 = 3'd5; end else begin m45 = a[4]; i45 = 3'd4; end
    if (a[7] > a[6]) begin m67 = a[7]; i67 = 3'd7; end else begin m67 = a[6]; i67 = 3'd6; end
    if (m23 > m01) begin m03 = m23; i03 = i23; end else begin m03 = m01; i03 = i01; end
    if (m67 > m45) begin m47 = m67; i47 = i67; end else begin m47 = m45; i47 = i45; end
    if (m47 > m03) begin m = m47; i = i47; end else begin m = m03; i = i03; end
endfunction

always @(posedge clk) begin
    if (!nRst || restart) begin
        p1_v <= #1 1'b0; p2_v <= #1 1'b0; p2_use <= #1 1'b0;
        for (int s = 0; s < 3; s++) begin rk[s] <= #1 '0; pix[s] <= #1 '0; cx[s] <= #1 '0; cy[s] <= #1 '0; qmax[s] <= #1 -8'sd128; cls[s] <= #1 '0; end
    end else begin
        // stage 1 register
        p1_v <= #1 pop && filt_en;
        p1_head <= #1 hw_head; p1_k <= #1 hw_k; p1_kind <= #1 rk[hw_head]; p1_data <= #1 head_word[WORD_W-1:0];
        if (pop && filt_en && hw_k == 3'd7) begin              // the row of this head is complete: next row kind / pixel
            rk[hw_head] <= #1 (rk[hw_head] == 2'd2) ? 2'd0 : rk[hw_head] + 2'd1;   // pix advances at the decision (dec_fire), not here
        end
        // stage 2: 8-byte max of the word
        p2_v <= #1 p1_v; p2_head <= #1 p1_head; p2_kind <= #1 p1_kind;
        begin
            logic signed [7:0] m; logic [2:0] i;
            max8(p1_data, m, i);
            p2_m8 <= #1 m; p2_ch <= #1 {p1_k, i};
        end
        p2_use <= #1 p1_v && ((p1_kind == 2'd1) || (p1_kind == 2'd2 && p1_k < 3'd2));
        // stage 3: running max of the pixel (channel = 64 * (kind - 1) + ch)
        if (p2_v && p2_use && (p2_m8 > qmax[p2_head])) begin
            qmax[p2_head] <= #1 p2_m8;
            cls[p2_head]  <= #1 (p2_kind == 2'd1) ? {1'b0, p2_ch} : {1'b1, p2_ch};
        end
        if (dec_fire) begin                                                                                                     // next pixel of that head
            qmax[dec_head] <= #1 -8'sd128; cls[dec_head] <= #1 '0; pix[dec_head] <= #1 pix[dec_head] + 16'd1;
            if (cx[dec_head] == 7'(head_w(dec_head) - 1)) begin cx[dec_head] <= #1 '0; cy[dec_head] <= #1 cy[dec_head] + 7'd1; end
            else cx[dec_head] <= #1 cx[dec_head] + 7'd1;
        end
    end
end

// ---------- decision / output queue (filter mode) ---------- //
logic [511:0] oq0, oq1;                           // rows waiting for the slot writer (META then box, or an END row)
logic [1:0]   oq_cnt, oq_head;
logic         oq_end;                             // oq0 is an END row: fill the slot after writing it
logic [1:0]   row_kind_c;                         // kind of the completed row in `row`
logic [1:0]   settle;                             // cycles until the cls pipeline has retired the completed row
wire  dec_ready = row_full && filt_en && settle == 2'd0 && !p1_v && !p2_v;
assign dec_head = row_head;
wire  dec_cand  = (qmax[dec_head] >= qthr[dec_head]);
logic         hm_busy, hm_done;                   // head-math unit (DET mode)
logic [511:0] hm_row;
logic [1:0]   hm_head_r;                          // head of the candidate in the unit
assign dec_fire = dec_ready && row_kind_c == 2'd2 && (oq_cnt == 2'd0) && !hm_busy;
wire  hm_start  = dec_fire && dec_cand && det_en;

function automatic logic [511:0] meta_row(input logic [1:0] h, input logic [15:0] p, input logic [6:0] c, input logic signed [7:0] q, input logic [7:0] fmt);
    logic [511:0] r; r = '0; r[15:0] = p; r[23:16] = {6'd0, h}; r[31:24] = {1'b0, c}; r[39:32] = q; r[47:40] = fmt; return r;
endfunction

// DET mode: sigmoid + DFL x 4 + corners on the parked box row of the decided pixel -> one DET row into the output queue
emy_head_math u_hm (
    .clk, .nRst, .start(hm_start), .head(dec_head), .pix(pix[dec_head]), .cx(cx[dec_head]), .cy(cy[dec_head]),
    .cls(cls[dec_head]), .qmax(qmax[dec_head]), .box(box_r[dec_head]), .det_row(hm_row), .done(hm_done), .busy(hm_busy));

// NMS mode: DET rows into the candidate store; the run at the frame end (before the END rows)
wire          nms_mode = det_en && nms_en;
logic         nms_start, nms_ack, nms_pend, nms_run;
logic         nms_row_v, nms_done, nms_busy;
logic [511:0] nms_row;
logic [15:0]  nms_ncand, nms_ndrop, nms_ndet;
emy_nms u_nms (
    .clk, .nRst, .restart, .push(hm_done && nms_mode), .cand(hm_row[127:0]), .start(nms_start),
    .row_v(nms_row_v), .row(nms_row), .row_ack(nms_ack), .done(nms_done), .busy(nms_busy),
    .n_cand(nms_ncand), .n_drop(nms_ndrop), .n_det(nms_ndet));

// flush at frame end: (NMS mode: the NMS run and its rows, then) END row per head, then fill the partial slot
logic        flush_pend;
logic [1:0]  flush_s;                             // next head to flush (0..2), 3 = done
logic [15:0] ncand [0:2];
wire  core_idle = empty && !row_full && oq_cnt == 2'd0 && !p1_v && !p2_v && !hm_busy;
assign drained  = core_idle && !flush_pend && !nms_busy;

function automatic logic [511:0] end_row(input logic [1:0] h, input logic [15:0] cnt, input logic [15:0] nc, input logic [15:0] dr);
    logic [511:0] r; r = '0; r[15:0] = cnt; r[23:16] = {6'd0, h}; r[47:40] = FMT_END; r[79:64] = nc; r[95:80] = dr; return r;
endfunction

// pop: legacy = while no complete row waits; filter = also while the output queue is busy (the decision needs it empty)
assign pop = !empty && !row_full;

// ---------- slot writer ---------- //
logic [2:0] cur;                                  // slot per head
logic [7:0] srow [0:2];                           // row in slot
logic [15:0] frow [0:2];                          // row in frame (< P3_ROWS .. : 6,400 neck / 19,200 head)
logic [2:0] o_free;
always_comb for (int s = 0; s < 3; s++) o_free[s] = ~out_full[2 * s + cur[s]];
wire [1:0]   w_head = filt_en ? oq_head : row_head;
wire [511:0] w_row  = filt_en ? oq0 : row;
wire wr       = filt_en ? (oq_cnt != 2'd0 && o_free[oq_head]) : (row_full && o_free[row_head]);
wire slot_end = (srow[w_head] == slot_rows(w_head) - 1) || (!filt_en && frow[w_head] == frame_rows(w_head) - 1)
                || (filt_en && oq_end && oq_cnt == 2'd1);                 // END row: close the slot whatever its fill
wire [OUT_AW-1:0] row_addr = OUT_AW'(slot_base(w_head, cur[w_head]) + srow[w_head] * ROW_B);
logic [5:0] fill_d;

always @(posedge clk) begin
    if (!nRst || restart) begin
        row_full <= #1 1'b0; row_head <= #1 '0; row <= #1 '0; cur <= #1 '0; fill_d <= #1 '0; rows_written <= #1 '0;
        row_kind_c <= #1 '0; settle <= #1 '0; oq_cnt <= #1 '0; oq_head <= #1 '0; oq_end <= #1 1'b0; oq0 <= #1 '0; oq1 <= #1 '0;
        flush_pend <= #1 1'b0; flush_s <= #1 '0; hm_head_r <= #1 '0;
        nms_start <= #1 1'b0; nms_ack <= #1 1'b0; nms_pend <= #1 1'b0; nms_run <= #1 1'b0;
        for (int s = 0; s < 3; s++) begin srow[s] <= #1 '0; frow[s] <= #1 '0; box_r[s] <= #1 '0; ncand[s] <= #1 '0; end
    end else begin
        fill_d <= #1 '0;
        if (settle != 2'd0) settle <= #1 settle - 2'd1;
        if (pop) begin
            row[64 * hw_k +: 64] <= #1 head_word[WORD_W-1:0];
            row_head <= #1 hw_head;
            if (hw_k == 3'd7) begin row_full <= #1 1'b1; row_kind_c <= #1 rk[hw_head]; settle <= #1 2'd2; end
        end
        // filter: consume the completed row
        if (dec_ready) begin
            case (row_kind_c)
                2'd0: begin box_r[row_head] <= #1 row; row_full <= #1 1'b0; end
                2'd1: row_full <= #1 1'b0;
                default: if (oq_cnt == 2'd0 && !hm_busy) begin
                    row_full <= #1 1'b0;
                    if (dec_cand) begin
                        if (det_en) hm_head_r <= #1 row_head;                                                         // DET: the unit starts (hm_start)
                        else begin
                            oq0 <= #1 meta_row(row_head, pix[row_head], cls[row_head], qmax[row_head], FMT_META);   // META first: every row in a
                            oq1 <= #1 box_r[row_head];                                                                // header position is adapter-made
                            oq_cnt <= #1 2'd2; oq_head <= #1 row_head; oq_end <= #1 1'b0;
                        end
                        ncand[row_head] <= #1 ncand[row_head] + 16'd1;
                    end
                end
            endcase
        end
        // DET mode: the unit is done -> its row into the (empty) queue (NMS mode: into the candidate store instead)
        if (hm_done && !nms_mode) begin oq0 <= #1 hm_row; oq_cnt <= #1 2'd1; oq_head <= #1 hm_head_r; oq_end <= #1 1'b0; end
        // frame end: (NMS mode: run the NMS once everything of the frame is stored, its rows through head 0) then END row per
        // head (filter mode only), after everything of the frame has left
        nms_start <= #1 1'b0; nms_ack <= #1 1'b0;
        if (frame_end) begin flush_pend <= #1 filt_en; flush_s <= #1 '0; nms_pend <= #1 nms_mode; nms_run <= #1 1'b0; end
        if (flush_pend && nms_pend) begin
            if (!nms_run && core_idle) begin nms_start <= #1 1'b1; nms_run <= #1 1'b1; end
            if (nms_row_v && !nms_ack && oq_cnt == 2'd0) begin
                oq0 <= #1 nms_row; oq_cnt <= #1 2'd1; oq_head <= #1 2'd0; oq_end <= #1 1'b0; nms_ack <= #1 1'b1;
            end
            if (nms_done) nms_pend <= #1 1'b0;
        end else if (flush_pend && core_idle) begin
            if (flush_s == 2'd3) flush_pend <= #1 1'b0;
            else begin
                oq0 <= #1 nms_mode ? end_row(flush_s, (flush_s == 2'd0) ? nms_ndet : 16'd0, ncand[flush_s], (flush_s == 2'd0) ? nms_ndrop : 16'd0)
                                   : end_row(flush_s, ncand[flush_s], 16'd0, 16'd0);
                oq_cnt <= #1 2'd1; oq_head <= #1 flush_s; oq_end <= #1 1'b1;
                flush_s <= #1 flush_s + 2'd1;
            end
        end
        // slot writer
        if (wr) begin
            rows_written <= #1 rows_written + 1'b1;
            if (filt_en) begin
                oq0 <= #1 oq1; oq_cnt <= #1 oq_cnt - 2'd1;
            end else begin
                row_full <= #1 1'b0;
            end
            if (slot_end) begin
                fill_d[2 * w_head + cur[w_head]] <= #1 1'b1;
                cur[w_head]  <= #1 ~cur[w_head];
                srow[w_head] <= #1 '0;
            end else begin
                srow[w_head] <= #1 srow[w_head] + 1'b1;
            end
            frow[w_head] <= #1 (frow[w_head] == frame_rows(w_head) - 1) ? 16'd0 : frow[w_head] + 16'd1;
        end
    end
end

// registered write port; fill follows the write by one clock so the row is in the BRAM before the CPU sees it
always @(posedge clk) begin
    if (!nRst) begin
        out_bram_en <= #1 1'b0; out_bram_we <= #1 '0; out_bram_addr <= #1 '0; out_bram_din <= #1 '0; out_fill <= #1 '0;
    end else begin
        out_bram_en   <= #1 wr;
        out_bram_we   <= #1 {64{wr}};
        out_bram_addr <= #1 row_addr;
        out_bram_din  <= #1 w_row;
        out_fill      <= #1 fill_d;
    end
end

endmodule
