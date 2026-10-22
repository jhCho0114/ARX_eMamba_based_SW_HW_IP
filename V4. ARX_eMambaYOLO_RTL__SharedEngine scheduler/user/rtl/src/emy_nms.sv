`timescale 1ns / 1ps
// emy_nms : class-wise NMS of the DET rows of one frame inside the output adapter (NMS mode = FILTER[2], with DET mode).
//   Bit-exact with the C emy_head_post.c (emy_hp_finish / hp_iou_over) on the 1/16 px int16 corners of the DET rows:
//     order     : conf (x65536) descending, ties by anchor index (ANC_BASE[head] + pixel: 0 / 6400 / 8000) ascending;
//     suppress  : same cls and 10 * inter > 7 * union, all in the C's uint32 arithmetic (widths int32, products / sums / compare
//                 mod 2^32 — so even degenerate boxes agree with the board code);
//     stop      : no alive candidate left, or DET_MAX detections.
//   Instead of sorting, every round finds the alive candidate with the best (conf, anc) by one scan (the rest alive are all
//   <= it, exactly the "boxes after a" of the sorted greedy), emits it, then scans once more: every alive b of the same class
//   goes through the IoU pipeline (one per clock, no divide: min/max, two subtractions, one multiply for inter, one for area_b,
//   add/sub, constant multiplies 10 and 7 as shift-adds, compare) and is killed when it overlaps. ~2 n + 16 clocks per round.
//   in : push + cand (bytes 0-15 of a DET row = pixel, head, cls, qmax, fmt, conf, x1 y1 x2 y2) during the frame — stored in a
//        block RAM (CAND_MAX entries; beyond that the candidate is dropped and n_drop counts); restart (START) clears the store.
//        start (one clock) runs the NMS over the store; rows leave through row_v / row (bytes 0-15 = the candidate with format
//        byte 0x03, rest 0) / row_ack; done pulses after the last row was taken; n_det = rows emitted.
module emy_nms #(
    parameter int CAND_MAX = 512,             // candidate store entries (RAMB36 x 2)
    parameter int DET_MAX  = 300              // EMY_HP_MAX_DET
)(
    input  logic         clk,
    input  logic         nRst,
    input  logic         restart,             // frame start: empty the store
    input  logic         push,
    input  logic [127:0] cand,
    input  logic         start,
    output logic         row_v,
    output logic [511:0] row,
    input  logic         row_ack,
    output logic         done,
    output logic         busy,
    output logic [15:0]  n_cand,
    output logic [15:0]  n_drop,
    output logic [15:0]  n_det
);

localparam int AW = $clog2(CAND_MAX);
localparam logic [7:0] FMT_NMS = 8'h03;

// ---------- candidate store ---------- //
(* ram_style = "block" *) logic [127:0] mem [0:CAND_MAX-1];
logic [AW-1:0]  ra;                           // read address (scan / pick)
logic [127:0]   mem_q;                        // registered read data (valid one clock after ra)
logic [CAND_MAX-1:0] alive;
logic [AW:0]    n;                            // stored candidates (n_cand)
wire  store_ok = push && (n < CAND_MAX);
always_ff @(posedge clk) if (store_ok) mem[n[AW-1:0]] <= cand;       // simple dual port: write port (push), read port (scan / pick)
always_ff @(posedge clk) mem_q <= mem[ra];
assign n_cand = 16'(n);

// fields of a stored entry
function automatic logic [15:0] f_conf(input logic [127:0] e); return e[63:48]; endfunction
function automatic logic [6:0]  f_cls (input logic [127:0] e); return e[30:24]; endfunction
function automatic logic signed [15:0] f_x1(input logic [127:0] e); return e[79:64];   endfunction
function automatic logic signed [15:0] f_y1(input logic [127:0] e); return e[95:80];   endfunction
function automatic logic signed [15:0] f_x2(input logic [127:0] e); return e[111:96];  endfunction
function automatic logic signed [15:0] f_y2(input logic [127:0] e); return e[127:112]; endfunction
function automatic logic [13:0] f_anc(input logic [127:0] e);      // ANC_BASE[head] + pixel
    case (e[17:16])
        2'd1:    return 14'(e[15:0] + 16'd6400);
        2'd2:    return 14'(e[15:0] + 16'd8000);
        default: return 14'(e[15:0]);
    endcase
endfunction

// ---------- control ---------- //
typedef enum logic [3:0] {S_IDLE, S_MAX, S_MAX_WAIT, S_PICK, S_PICK_WAIT, S_AREA0, S_AREA1, S_EMIT, S_SUP, S_SUP_WAIT, S_FIN} state_t;
state_t state;
logic [AW:0]   i;                             // scan index
logic [3:0]    wait_cnt;
logic [AW:0]   ndet;
assign n_det = 16'(ndet);
assign busy  = (state != S_IDLE);

// max-find: the registered read data belongs to index i - 1 (valid m1_v)
logic          m1_v;
logic [AW-1:0] m1_idx;
logic          found;
logic [AW-1:0] best;
logic [15:0]   best_conf;
logic [13:0]   best_anc;
wire  [15:0]   m_conf = f_conf(mem_q);
wire  [13:0]   m_anc  = f_anc(mem_q);
wire  m_better = !found || (m_conf > best_conf) || (m_conf == best_conf && m_anc < best_anc);

// the chosen candidate a
logic [127:0]  a_e;
logic signed [15:0] ax1, ay1, ax2, ay2;
logic [6:0]    a_cls;
logic signed [16:0] wa, ha;                   // int16 differences: 17-bit signed; the low 32 bits of the product = the C's uint32 product
logic [31:0]   area_a;

// suppression pipeline (one b per clock); every stage carries its index and validity
logic          v1, ok2, ok3, ok4, ok5, ok6;
logic [AW-1:0] j1, j2, j3, j4, j5, j6;
logic signed [15:0] ixl2, ixr2, iyt2, iyb2;
logic signed [16:0] wb2, hb2, iw3, ih3;
wire           pos3 = (iw3 > 0) && (ih3 > 0);
logic [31:0]   areab3, areab4, inter4, uni5, t10_5, t10_6, t7_6;
wire  sup6 = ok6 && (t10_6 > t7_6);

always @(posedge clk) begin
    if (!nRst || restart) begin
        state <= #1 S_IDLE; n <= #1 '0; n_drop <= #1 '0; ndet <= #1 '0; alive <= #1 '0; done <= #1 1'b0; row_v <= #1 1'b0;
        i <= #1 '0; wait_cnt <= #1 '0; found <= #1 1'b0; m1_v <= #1 1'b0; v1 <= #1 1'b0;
        ok2 <= #1 1'b0; ok3 <= #1 1'b0; ok4 <= #1 1'b0; ok5 <= #1 1'b0; ok6 <= #1 1'b0; ra <= #1 '0;
    end else begin
        done <= #1 1'b0;
        // store
        if (push) begin
            if (n < CAND_MAX) begin alive[n[AW-1:0]] <= #1 1'b1; n <= #1 n + 1'b1; end
            else n_drop <= #1 n_drop + 1'b1;
        end
        // max-find stage 1 (data of index i-1)
        m1_v <= #1 (state == S_MAX);
        m1_idx <= #1 i[AW-1:0];
        if (m1_v && alive[m1_idx] && m_better) begin
            found <= #1 1'b1; best <= #1 m1_idx; best_conf <= #1 m_conf; best_anc <= #1 m_anc;
        end
        // suppression pipeline
        v1 <= #1 (state == S_SUP); j1 <= #1 i[AW-1:0];
        // s2: b fields (mem_q belongs to j1)
        ok2 <= #1 v1 && alive[j1] && (f_cls(mem_q) == a_cls);  j2 <= #1 j1;
        ixl2 <= #1 (f_x1(mem_q) > ax1) ? f_x1(mem_q) : ax1;    ixr2 <= #1 (f_x2(mem_q) < ax2) ? f_x2(mem_q) : ax2;
        iyt2 <= #1 (f_y1(mem_q) > ay1) ? f_y1(mem_q) : ay1;    iyb2 <= #1 (f_y2(mem_q) < ay2) ? f_y2(mem_q) : ay2;
        wb2  <= #1 17'(f_x2(mem_q)) - 17'(f_x1(mem_q));        hb2  <= #1 17'(f_y2(mem_q)) - 17'(f_y1(mem_q));
        // s3
        ok3 <= #1 ok2; j3 <= #1 j2;
        iw3 <= #1 17'(ixr2) - 17'(ixl2);  ih3 <= #1 17'(iyb2) - 17'(iyt2);
        areab3 <= #1 32'(34'(wb2 * hb2));                              // (uint32)(x2-x1) * (uint32)(y2-y1) mod 2^32
        // s4
        ok4 <= #1 ok3 && pos3; j4 <= #1 j3;
        inter4 <= #1 32'(34'(iw3 * ih3)); areab4 <= #1 areab3;
        // s5
        ok5 <= #1 ok4; j5 <= #1 j4;
        uni5  <= #1 area_a + areab4 - inter4;
        t10_5 <= #1 (inter4 << 3) + (inter4 << 1);
        // s6
        ok6 <= #1 ok5; j6 <= #1 j5;
        t7_6  <= #1 (uni5 << 3) - uni5; t10_6 <= #1 t10_5;
        // s7: kill
        if (sup6) alive[j6] <= #1 1'b0;

        case (state)
            S_IDLE: if (start) begin state <= #1 S_MAX; i <= #1 '0; ra <= #1 '0; found <= #1 1'b0; ndet <= #1 '0; end
            S_MAX: begin                                               // issue reads 0 .. n-1 (ra = i), compare one clock later
                if (i + 1 < n) begin i <= #1 i + 1'b1; ra <= #1 AW'(i + 1); end
                if (i + 1 >= n) begin state <= #1 S_MAX_WAIT; wait_cnt <= #1 4'd2; end
            end
            S_MAX_WAIT: begin                                          // let the last compare land (m1 stage), then pick
                if (wait_cnt != 0) wait_cnt <= #1 wait_cnt - 1'b1;
                else if (!found) state <= #1 S_FIN;
                else begin state <= #1 S_PICK; ra <= #1 best; end
            end
            S_PICK:      state <= #1 S_PICK_WAIT;                       // mem_q <= mem[best] next clock
            S_PICK_WAIT: begin
                a_e <= #1 mem_q; ax1 <= #1 f_x1(mem_q); ay1 <= #1 f_y1(mem_q); ax2 <= #1 f_x2(mem_q); ay2 <= #1 f_y2(mem_q); a_cls <= #1 f_cls(mem_q);
                state <= #1 S_AREA0;
            end
            S_AREA0: begin wa <= #1 17'(ax2) - 17'(ax1); ha <= #1 17'(ay2) - 17'(ay1); state <= #1 S_AREA1; end
            S_AREA1: begin
                area_a <= #1 32'(34'(wa * ha));
                row <= #1 {384'd0, a_e[127:48], FMT_NMS, a_e[39:0]}; row_v <= #1 1'b1;
                alive[best] <= #1 1'b0; ndet <= #1 ndet + 1'b1;
                state <= #1 S_EMIT;
            end
            S_EMIT: if (row_ack) begin
                row_v <= #1 1'b0;
                if (ndet >= DET_MAX) state <= #1 S_FIN;
                else begin state <= #1 S_SUP; i <= #1 '0; ra <= #1 '0; end
            end
            S_SUP: begin                                               // issue reads 0 .. n-1; the pipeline kills overlapping b
                if (i + 1 < n) begin i <= #1 i + 1'b1; ra <= #1 AW'(i + 1); end
                if (i + 1 >= n) begin state <= #1 S_SUP_WAIT; wait_cnt <= #1 4'd8; end
            end
            S_SUP_WAIT: begin                                          // drain the pipeline, then the next round
                if (wait_cnt != 0) wait_cnt <= #1 wait_cnt - 1'b1;
                else begin state <= #1 S_MAX; i <= #1 '0; ra <= #1 '0; found <= #1 1'b0; end
            end
            S_FIN: begin done <= #1 1'b1; state <= #1 S_IDLE; end
            default: state <= #1 S_IDLE;
        endcase
    end
end

endmodule
