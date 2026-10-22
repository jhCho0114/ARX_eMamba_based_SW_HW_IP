`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 09:43:22 PM
// Design Name: 
// Module Name: LightNorm_compute
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LightNorm_compute #(
    parameter integer DATA_WIDTH     = 8,
    parameter integer DATA_WIDTH_DIN = 13, // 8-bit + 5-bit(upScaling)
    parameter integer NUM_DIM = 20,
    parameter integer NUM_LSH_DIN = 5,
    parameter integer NUM_SCALE_WEIGHT = 7,
    parameter integer NUM_SCALE_BIAS   = 7
)(
    clk,
    nRst,
    
    start,

    dIn,
    dIn_mean,
    dIn_range,

    weight,
    bias,

    valid,
    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_BIAS_LSH = NUM_SCALE_WEIGHT + 3 - NUM_SCALE_BIAS; // 2^3 = 8

localparam integer DATA_WIDTH_NORM = DATA_WIDTH_DIN + DATA_WIDTH + 4;
localparam integer DATA_WIDTH_BIAS_LSH = DATA_WIDTH + NUM_BIAS_LSH;

localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_NORM - NUM_LSH_DIN + 1;
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input start;

input logic signed [DATA_WIDTH_DIN-1:0] dIn;
input logic signed [DATA_WIDTH_DIN-1:0] dIn_mean;
input logic        [DATA_WIDTH_DIN-1:0] dIn_range;

input logic signed [DATA_WIDTH-1:0] weight;
input logic signed [DATA_WIDTH-1:0] bias;

output logic valid;
output logic signed [DATA_WIDTH_DOUT-1:0] dOut;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH_NORM-1:0] dividend;
logic        [DATA_WIDTH_NORM-1:0] divisor;

logic signed [DATA_WIDTH_NORM - NUM_LSH_DIN - 1:0] result;

logic signed [DATA_WIDTH_BIAS_LSH-1:0] bias_lsh;

logic signed [15:0] dIn_16, dIn_mean_16;
logic        [15:0] dIn_sub_16;
logic signed [DATA_WIDTH_DIN-1:0] dIn_sub;
logic carryOut;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
int8_divider #(
    .DATA_WIDTH(DATA_WIDTH_NORM - NUM_LSH_DIN)
) int8_divider (
    .clk(clk),
    .nRst(nRst),

    .start(start),

    .dividend(dividend[24:5]),
    .divisor(divisor[24:5]),

    .valid(valid),

    .result(result) // rounded value
);

shifter_left #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SHIFT(NUM_BIAS_LSH)
) shifter_left_bias (
    .dIn(bias),
    .dOut(bias_lsh)
);

CLA_16 CLA_16 (
    .dIn_1(dIn_16),
    .dIn_2(dIn_mean_16),
    .carryIn(0),

    .dOut(dIn_sub_16),
    .carryOut(carryOut)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
assign dIn_16 = dIn;
assign dIn_mean_16 = -dIn_mean;
assign dIn_sub = dIn_sub_16;

always @(*) begin
    // 25-bit = 8-bit * 13-bit * 4bit
    // dividend = weight * (dIn - dIn_mean) * 25;
    dividend = weight * dIn_sub * 25;

    // 25-bit = {12-bit, 13-bit}
    divisor = {12'd0, dIn_range};
end

// 21-bit = 20-bit + 10-bit
assign dOut = result + bias_lsh;

endmodule