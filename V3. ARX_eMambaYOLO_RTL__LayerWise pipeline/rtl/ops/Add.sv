`timescale 1ns / 1ps
// Add : element-wise add of two pixel-vector streams, wide result (no requant, no saturation)
//
//   T = max(NUM_SCALE_DIN0, NUM_SCALE_DIN1)          (SW.Add: residual adds of the VSS / XSS blocks)
//   dOut[c] = (dIn0[c] << (T - NUM_SCALE_DIN0)) + (dIn1[c] << (T - NUM_SCALE_DIN1))      shift T, WIDE_W bit
//   Operands may be int8 (DIN*_W = ACT_W) or wide (WIDE_W, e.g. step 29 r = step 21 wide). The consumer requantizes
//   (Requant, quant.json pass 'wide'). Model range: <= 16 bit (integration audit).
// Handshake (Linear_Transform_Dynamic_WB style, joined input, = Concat): both operand vectors are taken in the same
//   cycle, only when both are valid:  s_ready0 = accept & s_valid1,  s_ready1 = accept & s_valid0,
//   accept = (dIn_stat == EMPTY) | last_cycle.   INIT -> COMPUTE -> DONE, m_valid = DONE.
// Requirement: the producers' m_valid does not depend combinationally on s_ready (registered valid).
// A skip operand that arrives a frame / some rows earlier waits in an emy_stream_fifo in the block module.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module Add import emy_pkg::*; #(
    parameter integer NUM_DIM        = 32,
    parameter integer DIN0_W         = ACT_W,
    parameter integer DIN1_W         = ACT_W,
    parameter integer NUM_SCALE_DIN0 = 3,
    parameter integer NUM_SCALE_DIN1 = 3
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [DIN0_W-1:0] dIn0 [0:NUM_DIM-1],
    input  logic s_valid0,
    output logic s_ready0,

    input  logic signed [DIN1_W-1:0] dIn1 [0:NUM_DIM-1],
    input  logic s_valid1,
    output logic s_ready1,

    output logic signed [WIDE_W-1:0] dOut [0:NUM_DIM-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer NUM_SCALE_DOUT = (NUM_SCALE_DIN0 > NUM_SCALE_DIN1) ? NUM_SCALE_DIN0 : NUM_SCALE_DIN1;   // T
localparam integer LSH0           = NUM_SCALE_DOUT - NUM_SCALE_DIN0;
localparam integer LSH1           = NUM_SCALE_DOUT - NUM_SCALE_DIN1;

localparam INIT    = 2'd0,
           COMPUTE = 2'd1,
           DONE    = 2'd2;

localparam  EMPTY = 1'b0,
            LOAD  = 1'b1;

// ---------- Internal Variables ---------- //
logic [1:0] curr_state,
            next_state;

logic signed [DIN0_W-1:0] dIn_mem0 [0:NUM_DIM-1];
logic signed [DIN1_W-1:0] dIn_mem1 [0:NUM_DIM-1];
logic signed [WIDE_W-1:0] result   [0:NUM_DIM-1];

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

// ---------- Data Processing Logic: align to T, add ---------- //
always_comb begin
    for (int c = 0; c < NUM_DIM; c++)
        result[c] = (WIDE_W'(dIn_mem0[c]) <<< LSH0) + (WIDE_W'(dIn_mem1[c]) <<< LSH1);
end

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
