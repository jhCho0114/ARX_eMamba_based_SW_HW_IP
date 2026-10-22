`timescale 1ns / 1ps

module LightNorm_mean_unit #(
    parameter integer DATA_WIDTH     = 13,
    parameter integer DATA_WIDTH_SUM = 18,
    parameter integer NUM_DIM        = 20
)(
    clk,
    nRst,

    sum,
    mean,

    start, // [J-IMP] input
    valid  // [J-IMP] output
);

// ---------- I/O Ports ---------- //
input clk, nRst;

input  logic signed [DATA_WIDTH_SUM-1:0] sum;
output logic signed [DATA_WIDTH-1:0]       mean;

input start;
output valid;

// ---------- Internal Variables ---------- //
localparam signed [DATA_WIDTH_SUM-1:0] DIVISOR = NUM_DIM; // [J-IMP] constant
logic signed [DATA_WIDTH_SUM-1:0] div_result;

// ---------- Main Code ---------- //

always @(posedge clk) begin
    if (!nRst)
        mean <= #1 '0;
    else if (valid)
        mean <= #1 div_result[DATA_WIDTH-1:0];
end

// [J-IMP] '/' -> 순차 divider
divider #(                                               
    .DATA_WIDTH(DATA_WIDTH_SUM)
) u_div (
    .clk     (clk),
    .nRst    (nRst),
    .start   (start),
    .dividend(sum),
    .divisor (DIVISOR),
    .valid   (valid),
    .result  (div_result)
);    

endmodule