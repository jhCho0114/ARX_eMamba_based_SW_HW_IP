`timescale 1ns / 1ps
// emy_head_math : head post-processing of one candidate pixel inside the output adapter (B-plan, DET mode = FILTER[1]):
//   sigmoid (conf), DFL expectation of the 4 box sides (emy_dfl_side x 4) and the box corners, bit-exact with the C emy_head_post.c
//   (hp_dfl_side_q8, emy_sig_tab, x1 = ((cx * 256 + 128) - d_l) * stride ...; the DET row carries the corners >> 4 = 1/16 px int16,
//   the unit the C NMS works in). The CPU then only sorts and runs NMS.
//   in : start (one clock, ignored while busy), head (0 P3 / 1 P4 / 2 P5), pix (pixel index), cx / cy (its column / row, counters kept by
//        the adapter), cls, qmax (signed int8), box (the parked box row: byte c = channel c, side s = channels 16s .. 16s+15)
//   out: det_row (512 bit) valid with done — bytes 0-1 pix LE, 2 head, 3 cls, 4 qmax, 5 format 0x02, 6-7 conf (x65536, 16 bit),
//        8-9 x1, 10-11 y1, 12-13 x2, 14-15 y2 (int16, 1/16 px), rest 0.   done = one-clock pulse, 19 clocks after start.
//   conf = SIG_ROM[kind][qmax + 128], kind 1 for P4 (cls lsb 1/2), 0 for P3 / P5 (lsb 1/4).
//   corners: t = ax -/+ d (ax = cx * 256 + 128, 1/256 grid); x_16 = (t * stride) >> 4 = t >>> 1 (P3, stride 8) / t (P4, 16) / t <<< 1 (P5, 32).
module emy_head_math import emy_head_rom_pkg::*; (
    input  logic              clk,
    input  logic              nRst,
    input  logic              start,
    input  logic [1:0]        head,
    input  logic [15:0]       pix,
    input  logic [6:0]        cx,
    input  logic [6:0]        cy,
    input  logic [6:0]        cls,
    input  logic signed [7:0] qmax,
    input  logic [511:0]      box,
    output logic [511:0]      det_row,
    output logic              done,
    output logic              busy
);

localparam logic [7:0] FMT_DET = 8'h02;

// ---------- capture ---------- //
logic              run;                           // from the accepted start to done
logic [1:0]        head_r;
logic [15:0]       pix_r;
logic [6:0]        cx_r, cy_r, cls_r;
logic signed [7:0] qmax_r;
logic [15:0]       conf_r;
wire  go = start && !run;
always @(posedge clk) begin
    if (!nRst) run <= #1 1'b0;
    else begin
        if (go) begin
            run <= #1 1'b1;
            head_r <= #1 head; pix_r <= #1 pix; cx_r <= #1 cx; cy_r <= #1 cy; cls_r <= #1 cls; qmax_r <= #1 qmax;
            conf_r <= #1 SIG_ROM[head == 2'd1][{~qmax[7], qmax[6:0]}];       // index qmax + 128
        end
        if (done) run <= #1 1'b0;
    end
end
assign busy = run;

// ---------- the four sides ---------- //
logic [11:0] d [0:3];                             // l, t, r, b
logic        sd [0:3];
genvar s;
generate for (s = 0; s < 4; s++) begin : g_side
    emy_dfl_side u_side (.clk, .nRst, .start(go), .q(box[128 * s +: 128]), .d(d[s]), .done(sd[s]), .busy());
end endgenerate

// ---------- corners: stage A (t = ax -/+ d), stage B (stride scale, row) ---------- //
logic signed [15:0] t [0:3];
logic a_v;
wire  [14:0] ax = {cx_r, 8'h80};                  // cx * 256 + 128
wire  [14:0] ay = {cy_r, 8'h80};
always @(posedge clk) begin
    if (!nRst) a_v <= #1 1'b0;
    else begin
        a_v <= #1 sd[0];                          // all sides finish together
        if (sd[0]) begin
            t[0] <= #1 $signed({1'b0, ax}) - $signed({4'd0, d[0]});
            t[1] <= #1 $signed({1'b0, ay}) - $signed({4'd0, d[1]});
            t[2] <= #1 $signed({1'b0, ax}) + $signed({4'd0, d[2]});
            t[3] <= #1 $signed({1'b0, ay}) + $signed({4'd0, d[3]});
        end
    end
end
function automatic logic [15:0] scale(input logic signed [15:0] v, input logic [1:0] h);
    case (h)
        2'd0:    return v >>> 1;                  // stride 8  : (v * 8) >> 4
        2'd1:    return v;                        // stride 16 : (v * 16) >> 4
        default: return v <<< 1;                  // stride 32 : (v * 32) >> 4
    endcase
endfunction
always @(posedge clk) begin
    if (!nRst) begin done <= #1 1'b0; det_row <= #1 '0; end
    else begin
        done <= #1 a_v;
        if (a_v) begin
            det_row <= #1 '0;
            det_row[15:0]    <= #1 pix_r;
            det_row[23:16]   <= #1 {6'd0, head_r};
            det_row[31:24]   <= #1 {1'b0, cls_r};
            det_row[39:32]   <= #1 qmax_r;
            det_row[47:40]   <= #1 FMT_DET;
            det_row[63:48]   <= #1 conf_r;
            det_row[79:64]   <= #1 scale(t[0], head_r);
            det_row[95:80]   <= #1 scale(t[1], head_r);
            det_row[111:96]  <= #1 scale(t[2], head_r);
            det_row[127:112] <= #1 scale(t[3], head_r);
        end
    end
end

endmodule
