`timescale 1ns / 1ps
// Concat : channel concat of two pixel-vector streams, per-input requant
//
//   dOut[0 .. C0-1]     = sat8(rshr(dIn0, NUM_SCALE_DIN0 - NUM_SCALE_DOUT))
//   dOut[C0 .. C0+C1-1] = sat8(rshr(dIn1, NUM_SCALE_DIN1 - NUM_SCALE_DOUT))     (<= 0: exact left shift)
//
//   = Concat module of the spec (inputs at their own s_in, align to T = max, concat, requant T -> s_out): one requant
//   per input gives the same value (checked for L10 / L13 / L16 / L19). Parameters are the step's shifts as written in
//   int8_WB quant.json (in[i].shift, out.shift); the per-input shift is computed here, never by hand.
//
// Handshake (Linear_Transform_Dynamic_WB style, joined input): both input vectors are taken in the same cycle,
//   only when both are valid:  s_ready0 = accept & s_valid1,  s_ready1 = accept & s_valid0,
//   accept = (dIn_stat == EMPTY) | last_cycle.   INIT -> COMPUTE -> DONE, m_valid = DONE.
// Requirement: the producers' m_valid does not depend combinationally on s_ready (registered valid, e.g.
//   Linear style DONE or emy_stream_fifo), so there is no combinational loop.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module Concat import emy_pkg::*; #(
    parameter integer NUM_DIM0       = 128,
    parameter integer NUM_DIM1       = 128,
    parameter integer NUM_SCALE_DIN0 = 3,
    parameter integer NUM_SCALE_DIN1 = 3,
    parameter integer NUM_SCALE_DOUT = 3,

    localparam integer NUM_OUT       = NUM_DIM0 + NUM_DIM1
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn0 [0:NUM_DIM0-1],
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [ACT_W-1:0] dIn1 [0:NUM_DIM1-1],
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [ACT_W-1:0] dOut [0:NUM_OUT-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer SHIFT0 = NUM_SCALE_DIN0 - NUM_SCALE_DOUT;
localparam integer SHIFT1 = NUM_SCALE_DIN1 - NUM_SCALE_DOUT;

localparam INIT    = 2'd0,
           COMPUTE = 2'd1,
           DONE    = 2'd2;

localparam  EMPTY = 1'b0,
            LOAD  = 1'b1;

// ---------- Internal Variables ---------- //
logic [1:0] curr_state,
            next_state;

logic signed [ACT_W-1:0] dIn_mem0 [0:NUM_DIM0-1];
logic signed [ACT_W-1:0] dIn_mem1 [0:NUM_DIM1-1];
logic signed [ACT_W-1:0] result   [0:NUM_OUT-1];

logic dIn_stat;
logic last_cycle;
logic accept;

logic s_handshaking, m_handshaking;

assign accept        = (dIn_stat == EMPTY) | last_cycle;
assign s_ready0      = accept & s_valid1;
assign s_ready1      = accept & s_valid0;
assign s_handshaking = accept & s_valid0 & s_valid1;
assign m_handshaking = m_valid & m_ready;

assign m_valid    = (curr_state == DONE);
assign last_cycle = (curr_state == COMPUTE);

// ---------- get input data ---------- //
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        dIn_stat <= #1 EMPTY;
    end else begin
        if (s_handshaking)   dIn_stat <= #1 LOAD;
        else if (last_cycle) dIn_stat <= #1 EMPTY;
        else                 dIn_stat <= #1 dIn_stat;
    end
end

always @(posedge clk) begin
    if (!nRst) begin
        dIn_mem0 <= #1 '{default:'0};
        dIn_mem1 <= #1 '{default:'0};
    end else if (s_handshaking) begin
        dIn_mem0 <= #1 dIn0;
        dIn_mem1 <= #1 dIn1;
    end else begin
        dIn_mem0 <= #1 dIn_mem0;
        dIn_mem1 <= #1 dIn_mem1;
    end
end

// ---------- Data Processing Logic: per-input requant ---------- //
genvar i;
generate
    for (i = 0; i < NUM_DIM0; i = i + 1) begin : rq0
        emy_requant #(
            .IN_W(ACT_W),
            .OUT_W(ACT_W)
        ) requant (
            .din(dIn_mem0[i]),
            .shift(8'(SHIFT0)),
            .dout(result[i])
        );
    end
    for (i = 0; i < NUM_DIM1; i = i + 1) begin : rq1
        emy_requant #(
            .IN_W(ACT_W),
            .OUT_W(ACT_W)
        ) requant (
            .din(dIn_mem1[i]),
            .shift(8'(SHIFT1)),
            .dout(result[NUM_DIM0 + i])
        );
    end
endgenerate

// ---------- Final output ---------- //
always @(posedge clk) begin
    if (!nRst) begin
        dOut <= #1 '{default:'0};
    end else begin
        if (curr_state == COMPUTE)
            dOut <= #1 result;
        else
            dOut <= #1 dOut;
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
            if (dIn_stat == LOAD)
                next_state = COMPUTE;
        end

        COMPUTE: next_state = DONE;

        DONE: begin
            if (m_handshaking) begin
                if (dIn_stat == LOAD)
                    next_state = COMPUTE;
                else
                    next_state = INIT;
            end
        end

        default: next_state = INIT;
    endcase
end

endmodule
