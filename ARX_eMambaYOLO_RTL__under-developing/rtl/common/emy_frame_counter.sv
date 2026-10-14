`timescale 1ns / 1ps
// emy_frame_counter : counts the pixel vectors handed over on a stream (valid & ready);
// frame_done = one-cycle pulse after every NUM_PIX of them (the count wraps: frames stream continuously).
// ps_start (synchronous) restarts the count.
module emy_frame_counter #(
    parameter integer NUM_PIX = 400
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,
    input  logic valid,
    input  logic ready,
    output logic frame_done
);

logic [$clog2(NUM_PIX)-1:0] out_cnt;

always @(posedge clk) begin
    if (!nRst || ps_start) begin
        out_cnt    <= #1 '0;
        frame_done <= #1 1'b0;
    end else if (valid && ready) begin
        out_cnt    <= #1 (out_cnt == NUM_PIX - 1) ? '0 : out_cnt + 1'b1;
        frame_done <= #1 (out_cnt == NUM_PIX - 1);
    end else begin
        out_cnt    <= #1 out_cnt;
        frame_done <= #1 1'b0;
    end
end

endmodule
