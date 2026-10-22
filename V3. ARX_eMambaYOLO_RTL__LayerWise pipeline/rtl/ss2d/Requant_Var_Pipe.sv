`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Requant_Var_Pipe
// Description: Requant_Var (dOut = sat8(rshr(dIn, shift)), round half up, shift loaded at run time)
//              with a register between the rounding shift and the saturation: dIn / shift in this
//              cycle (when en), dOut from the register the next cycle.  Same arithmetic, written
//              the same way as Requant_Var.
//////////////////////////////////////////////////////////////////////////////////
module Requant_Var_Pipe #(
    parameter integer DATA_WIDTH_DIN = 24,
    parameter integer SHIFT_WIDTH    = 5
)(
    clk,
    en,
    dIn,
    shift,
    dOut
);

input  logic                             clk, en;
input  logic signed [DATA_WIDTH_DIN-1:0] dIn;
input  logic        [SHIFT_WIDTH-1:0]    shift;
output logic signed [7:0]                dOut;

logic signed [DATA_WIDTH_DIN:0] dIn_ext, half, rounded, shifted, shifted_q;

always @(*) begin
    dIn_ext = dIn;
    half    = '0;
    if (shift != 0)
        half[shift - 1] = 1'b1;
    rounded = dIn_ext + half;
    shifted = rounded >>> shift;
end

always @(posedge clk) if (en) shifted_q <= #1 shifted;

always @(*) begin
    if (shifted_q > 127)
        dOut = 8'sd127;
    else if (shifted_q < -128)
        dOut = -8'sd128;
    else
        dOut = shifted_q[7:0];
end

endmodule
