`timescale 1ns / 1ps
// emy_stream_fork : one pixel-vector stream -> two consumers (broadcast), combinational
//
//   A vector is handed over only when both consumers are ready, in the same cycle to both:
//     s_ready  = m_ready0 & m_ready1
//     m_valid0 = s_valid & m_ready1,   m_valid1 = s_valid & m_ready0
//   so m_valid_i & m_ready_i == s_valid & s_ready for both branches.
// Requirement (true for every Linear_Transform_Dynamic_WB style module and emy_stream_fifo): the consumers' s_ready
// does not depend combinationally on their s_valid, so there is no combinational loop.
module emy_stream_fork import emy_pkg::*; #(
    parameter integer NUM_DIM = 128,
    parameter integer DATA_W  = ACT_W     // lane width (WIDE_W for a wide residual)
)(
    input  logic signed [DATA_W-1:0] dIn   [0:NUM_DIM-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [DATA_W-1:0] dOut0 [0:NUM_DIM-1],
    output logic m_valid0,
    input  logic m_ready0,

    output logic signed [DATA_W-1:0] dOut1 [0:NUM_DIM-1],
    output logic m_valid1,
    input  logic m_ready1
);

assign dOut0    = dIn;
assign dOut1    = dIn;
assign s_ready  = m_ready0 & m_ready1;
assign m_valid0 = s_valid & m_ready1;
assign m_valid1 = s_valid & m_ready0;

endmodule
