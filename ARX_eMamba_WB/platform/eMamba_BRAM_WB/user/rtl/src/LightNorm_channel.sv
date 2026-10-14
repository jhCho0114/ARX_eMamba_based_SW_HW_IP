`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: LightNorm_channel
// Description: LightNorm 채널 1개 normalize (combinational, divider 없음).
//              raw_out -> activator -> 8bit dOut
//////////////////////////////////////////////////////////////////////////////////

module LightNorm_channel #(
    parameter integer DATA_WIDTH       = 8,
    parameter integer DATA_WIDTH_DIN   = 13,
    parameter integer NUM_LSH_DIN      = 5,
    parameter integer FRAC_BITS        = 16,
    parameter integer NUM_SCALE_WEIGHT = 7,
    parameter integer NUM_SCALE_BIAS   = 10
)(
    clk,
    nRst,                                   // [J-unopt-reset]

    x,
    mean,
    weight,
    bias,
    inv_range,

    raw_out
);

localparam integer NUM_BIAS_LSH        = NUM_SCALE_WEIGHT + 3 - NUM_SCALE_BIAS;
localparam integer DATA_WIDTH_NORM     = DATA_WIDTH_DIN + DATA_WIDTH + 4;
localparam integer DATA_WIDTH_BIAS_LSH = DATA_WIDTH + NUM_BIAS_LSH;
localparam integer DIV_DATA_WIDTH      = DATA_WIDTH_NORM - NUM_LSH_DIN; // 20
localparam integer DATA_WIDTH_DOUT     = DATA_WIDTH_NORM - NUM_LSH_DIN + 1; // 21
localparam integer INV_EXT_W           = FRAC_BITS + 2;                 // 18
localparam integer PROD_WIDTH          = DIV_DATA_WIDTH + INV_EXT_W;    // 38
input clk;
input nRst;                                 // [J-unopt-reset]

input  logic signed [DATA_WIDTH_DIN-1:0] x;
input  logic signed [DATA_WIDTH_DIN-1:0] mean;
input  logic signed [DATA_WIDTH-1:0]     weight;
input  logic signed [DATA_WIDTH-1:0]     bias;
input  logic        [FRAC_BITS:0]        inv_range;

output logic signed [DATA_WIDTH_DOUT-1:0] raw_out;

logic signed [DATA_WIDTH_DIN-1:0]         centered;
logic signed [DATA_WIDTH_NORM-1:0]       dividend;
logic signed [DIV_DATA_WIDTH-1:0]        num_slice;
logic signed [INV_EXT_W-1:0]             inv_ext;
logic signed [PROD_WIDTH-1:0]            prod;
logic signed [DIV_DATA_WIDTH-1:0]        norm_core;
logic signed [DATA_WIDTH_BIAS_LSH-1:0]   bias_lsh;

logic signed [DIV_DATA_WIDTH-1:0] num_slice_q;
logic signed [PROD_WIDTH-1:0] prod_q;
logic signed [DATA_WIDTH_BIAS_LSH-1:0] bias_lsh_q1, bias_lsh_q2;


shifter_left #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SHIFT(NUM_BIAS_LSH)
) u_bias_lsh (
    .dIn (bias),
    .dOut(bias_lsh)
);

assign centered  = x - mean;
assign dividend  = weight * centered * 25;
assign num_slice = dividend[DATA_WIDTH_NORM-1:NUM_LSH_DIN];
assign inv_ext   = {1'b0, inv_range};
// assign prod      = num_slice * inv_ext;
always @(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        num_slice_q <= #1 '0;                                 // [J-unopt-reset]
        bias_lsh_q1 <= #1 '0;                                 // [J-unopt-reset]
    end else begin                                            // [J-unopt-reset]
        num_slice_q <= #1 num_slice;
        bias_lsh_q1 <= #1 bias_lsh;
    end                                                       // [J-unopt-reset]
end

always@(posedge clk) begin
    if (!nRst) begin                                          // [J-unopt-reset]
        prod_q      <= #1 '0;                                 // [J-unopt-reset]
        bias_lsh_q2 <= #1 '0;                                 // [J-unopt-reset]
    end else begin                                            // [J-unopt-reset]
        prod_q <= #1 num_slice_q * inv_ext;
        bias_lsh_q2 <= #1 bias_lsh_q1;
    end                                                       // [J-unopt-reset]
end



// assign norm_core = prod >>> FRAC_BITS;

wire signed [PROD_WIDTH-1:0] prod_abs  = prod_q[PROD_WIDTH-1] ? -prod_q : prod_q;
wire signed [PROD_WIDTH-1:0] quot_abs  = prod_abs >>> FRAC_BITS;
assign norm_core = prod_q[PROD_WIDTH-1] ? -quot_abs : quot_abs;

assign raw_out   = norm_core + bias_lsh_q2;

endmodule