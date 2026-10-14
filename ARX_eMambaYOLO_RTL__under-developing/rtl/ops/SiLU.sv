`timescale 1ns / 1ps
// SiLU : SiLU (8-chord PWL, v002 golden = new_U_SiLU_piecewise) on one pixel vector, Linear_Transform_Dynamic_WB handshake
//
//   s_valid/s_ready : dIn[0:NUM_DIM-1] latched into dIn_mem on s_valid & s_ready
//   s_ready = (dIn_stat == EMPTY) | last_cycle      (last_cycle = COMPUTE: next vector accepted while computing)
//   INIT -> COMPUTE (1 cycle, emy_silu_pwl on all NUM_DIM lanes) -> DONE
//   m_valid = (state == DONE), dOut held until m_valid & m_ready; DONE -> COMPUTE directly if a vector is loaded
//   nRst : synchronous, active low. ps_start : synchronous soft reset of the FSM and the input status
//
// Parameters: vector length and the step's input / output shift (int8_WB quant.json). The PWL fraction bits are
// fixed inside emy_silu_pwl. The module input requant (s_from -> NUM_SCALE_DIN) is not included: for the SiLU steps
// outside the SSM blocks s_from == s_in.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module SiLU import emy_pkg::*; #(
    parameter integer NUM_DIM        = 16,
    parameter integer NUM_SCALE_DIN  = 2,
    parameter integer NUM_SCALE_DOUT = 2
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_DIM-1],
    output logic signed [ACT_W-1:0] dOut [0:NUM_DIM-1],

    input  logic s_valid,
    input  logic m_ready,
    output logic s_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam INIT    = 2'd0,
           COMPUTE = 2'd1,
           DONE    = 2'd2;

localparam  EMPTY = 1'b0,
            LOAD  = 1'b1;

// ---------- Internal Variables ---------- //
logic [1:0] curr_state,
            next_state;

logic signed [ACT_W-1:0] dIn_mem [0:NUM_DIM-1];
logic signed [ACT_W-1:0] result  [0:NUM_DIM-1];

logic dIn_stat;
logic last_cycle;

logic s_handshaking, m_handshaking;

assign s_handshaking = s_valid & s_ready;
assign m_handshaking = m_valid & m_ready;

assign s_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid = (curr_state == DONE);

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
        dIn_mem <= #1 '{default:'0};
    end else if (s_handshaking) begin
        dIn_mem <= #1 dIn;
    end else begin
        dIn_mem <= #1 dIn_mem;
    end
end

// ---------- Data Processing Logic ---------- //
emy_silu_pwl #(
    .NUM_DIM(NUM_DIM),
    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) silu_pwl (
    .dIn(dIn_mem),

    .dOut(result)
);

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
