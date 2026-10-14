`timescale 1ns / 1ps
// [J-FORK] Fork_Ack : one producer stream -> N consumer streams.
//   Each consumer accepts with its own s_ready, so consumers with different latency
//   are not ready in the same cycle. This block remembers which consumers have
//   already accepted the current token (sticky ack), drops valid to those, and
//   releases the producer only when every consumer has taken the token once.
//   A FIFO can be one of the consumers: give it c_ready = ~full and use
//   c_valid[i] & c_ready[i] as its push.
module Fork_Ack#(
    parameter integer N = 2
)(
    input  logic         clk,
    input  logic         nRst,
    input  logic         ps_start,
    input  logic         p_valid,    // producer m_valid
    output logic         p_ready,    // producer m_ready
    output logic [N-1:0] c_valid,    // consumer s_valid
    input  logic [N-1:0] c_ready,    // consumer s_ready (FIFO: ~full)
    output logic         advance     // 1-cycle pulse when the token leaves
);
    logic [N-1:0] acked;
    logic [N-1:0] take;

    assign c_valid = {N{p_valid}} & ~acked;          // already-acked consumers see no valid
    assign take    = c_valid & c_ready;              // accepting this cycle
    assign p_ready = &(acked | take);                // all consumers took it (now or before)
    assign advance = p_valid & p_ready;

    always_ff @(posedge clk) begin
        if (!nRst || ps_start) acked <= #1 '0;
        else if (advance)      acked <= #1 '0;
        else                   acked <= #1 acked | take;
    end
endmodule
