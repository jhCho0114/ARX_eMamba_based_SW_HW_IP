`timescale 1ns / 1ps
// Upsample : nearest x2 upsample of a pixel-vector stream,  dOut[c, h, w] = dIn[c, h >> 1, w >> 1]
//
//   input  : [C] per pixel, raster (h, w), H x W        output : [C] per pixel, raster, 2H x 2W, same shift
//   (INT8 reference model SW.Upsample; L09 / L12 have s_in = s_out = s_lo and input shift = previous layer_out shift:
//    no requant, values are copied)
//
// Row replay, one row buffer [W][C]:
//   PASS   : each input pixel (h, w) is sent twice -> output (2h, 2w), (2h, 2w+1), and stored in rowbuf[w]
//   REPLAY : after the last pixel of the row, rowbuf[0..W-1] is sent again, each twice -> output row 2h+1
//
// Handshake (Linear_Transform_Dynamic_WB style):
//   input  : dIn latched into dIn_mem on s_valid & s_ready, s_ready = (dIn_stat == EMPTY) (registered only), so
//            the next pixel is prefetched while the current one is being sent / the row replayed
//   output : dOut register, m_valid in DUP0 / DUP1 / RP0 / RP1, held until m_valid & m_ready
//   INIT -> DUP0 -> DUP1 -> (next pixel) DUP0 ... last pixel of row: DUP1 -> RP0 -> RP1 -> RP0 ... -> DUP0 / INIT
//   nRst : synchronous, active low. ps_start : synchronous soft reset (new frame)
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module Upsample import emy_pkg::*; #(
    parameter integer NUM_CH     = 256,
    parameter integer NUM_WIDTH  = 20      // input row width W
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:NUM_CH-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam INIT = 3'd0,
           DUP0 = 3'd1,   // pass: first copy  (2h, 2w)
           DUP1 = 3'd2,   // pass: second copy (2h, 2w+1)
           RP0  = 3'd3,   // replay: first copy  (2h+1, 2w)
           RP1  = 3'd4;   // replay: second copy (2h+1, 2w+1)

localparam  EMPTY = 1'b0,
            LOAD  = 1'b1;

localparam integer COL_W = ($clog2(NUM_WIDTH) > 0) ? $clog2(NUM_WIDTH) : 1;

// ---------- Internal Variables ---------- //
logic [2:0] curr_state,
            next_state;

logic signed [ACT_W-1:0] dIn_mem [0:NUM_CH-1];
logic signed [ACT_W-1:0] rowbuf  [0:NUM_WIDTH-1][0:NUM_CH-1];

logic [COL_W-1:0] col;        // column of the next input pixel of this row
logic [COL_W-1:0] rp_col;     // column being replayed
logic             cur_last;   // pixel in dOut (pass) is the last of its row

logic dIn_stat;
logic s_handshaking, m_handshaking;
logic take;                   // dIn_mem -> dOut (start DUP0 with a new pixel)
logic to_replay;              // last pass copy of the row sent -> RP0 with rowbuf[0]
logic rp_next;                // replay copy 2 sent, more columns -> RP0 with rowbuf[rp_col+1]
logic row_done;               // last replay copy of the row sent

assign s_ready = (dIn_stat == EMPTY);
assign m_valid = (curr_state == DUP0) || (curr_state == DUP1) || (curr_state == RP0) || (curr_state == RP1);

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign to_replay = (curr_state == DUP1) && m_handshaking &&  cur_last;
assign rp_next   = (curr_state == RP1)  && m_handshaking && (rp_col != NUM_WIDTH-1);
assign row_done  = (curr_state == RP1)  && m_handshaking && (rp_col == NUM_WIDTH-1);
assign take      = (dIn_stat == LOAD) &&
                   ((curr_state == INIT) || ((curr_state == DUP1) && m_handshaking && !cur_last) || row_done);

// ---------- get input data ---------- //
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        dIn_stat <= #1 EMPTY;
    end else begin
        if (s_handshaking) dIn_stat <= #1 LOAD;
        else if (take)     dIn_stat <= #1 EMPTY;
        else               dIn_stat <= #1 dIn_stat;
    end
end

always @(posedge clk) begin
    if (!nRst) begin
        dIn_mem <= #1 '{default:'0};
    end else if (s_handshaking) begin
        dIn_mem <= #1 dIn;
    end else begin
        dIn_mem <= #1 dIn_mem;
    end
end

// ---------- row buffer / column counters ---------- //
always @(posedge clk) begin
    if (take) rowbuf[col] <= #1 dIn_mem;
end

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        col      <= #1 '0;
        cur_last <= #1 1'b0;
        rp_col   <= #1 '0;
    end else begin
        if (take) begin
            cur_last <= #1 (col == NUM_WIDTH-1);
            col      <= #1 (col == NUM_WIDTH-1) ? '0 : col + 1'b1;
        end else begin
            cur_last <= #1 cur_last;
            col      <= #1 col;
        end
        if (to_replay)    rp_col <= #1 '0;
        else if (rp_next) rp_col <= #1 rp_col + 1'b1;
        else              rp_col <= #1 rp_col;
    end
end

// ---------- Final output ---------- //
always @(posedge clk) begin
    if (!nRst) begin
        dOut <= #1 '{default:'0};
    end else begin
        if (take)           dOut <= #1 dIn_mem;
        else if (to_replay) dOut <= #1 rowbuf[0];
        else if (rp_next)   dOut <= #1 rowbuf[rp_col + 1'b1];
        else                dOut <= #1 dOut;
    end
end

// ---------- FSM ---------- //
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        INIT: begin
            if (take) next_state = DUP0;
        end

        DUP0: begin
            if (m_handshaking) next_state = DUP1;
        end

        DUP1: begin
            if (m_handshaking) begin
                if (cur_last)  next_state = RP0;
                else if (take) next_state = DUP0;
                else           next_state = INIT;
            end
        end

        RP0: begin
            if (m_handshaking) next_state = RP1;
        end

        RP1: begin
            if (m_handshaking) begin
                if (!row_done) next_state = RP0;
                else if (take) next_state = DUP0;
                else           next_state = INIT;
            end
        end

        default: next_state = INIT;
    endcase
end

endmodule
