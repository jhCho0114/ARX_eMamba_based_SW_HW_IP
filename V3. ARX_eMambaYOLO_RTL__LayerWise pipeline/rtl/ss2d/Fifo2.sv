`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Fifo2
// Description: two-entry register FIFO, the output buffer behind a RAM with a one-cycle read.
//              A reader that issues a RAM read only while count + reads in flight - pop < 2 never
//              overflows it, and a token waits in it while m_ready is low (back-pressure), so the
//              stream keeps one token per cycle when nothing stalls.
//
//   push / pop in the same cycle are both taken.  dout is the oldest entry (valid when count != 0).
//////////////////////////////////////////////////////////////////////////////////
module Fifo2 #(
    parameter integer WIDTH = 8
)(
    clk,
    nRst,
    clear,

    push,
    din,

    pop,
    dout,
    count
);

input  logic             clk, nRst, clear;
input  logic             push;
input  logic [WIDTH-1:0] din;
input  logic             pop;
output logic [WIDTH-1:0] dout;
output logic [1:0]       count;

logic [WIDTH-1:0] d0, d1;

assign dout = d0;

always @(posedge clk) begin
    if (!nRst || clear) begin
        count <= #1 2'd0;
    end else begin
        case ({push, pop && count != 2'd0})
            2'b10: count <= #1 count + 1'b1;
            2'b01: count <= #1 count - 1'b1;
            default: ;
        endcase
    end
end

// data registers carry no reset: a wide FIFO of a token vector is only flip-flops this way
always @(posedge clk) begin
    case ({push, pop && count != 2'd0})
        2'b10: begin
            if (count == 2'd0) d0 <= #1 din;
            else               d1 <= #1 din;
        end
        2'b01: d0 <= #1 d1;
        2'b11: begin
            if (count == 2'd1) d0 <= #1 din;
            else begin
                d0 <= #1 d1;
                d1 <= #1 din;
            end
        end
        default: ;
    endcase
end

endmodule
