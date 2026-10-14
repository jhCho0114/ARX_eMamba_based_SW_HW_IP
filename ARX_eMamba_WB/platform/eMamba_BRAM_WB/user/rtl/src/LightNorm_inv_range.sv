`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: LightNorm_inv_range
// Description: range의 역수(고정소수점) 계산.
//              원본 LightNorm_compute 는 divisor[24:5] = range >> NUM_LSH_DIN
//              이니까 inv ~= (1 << FRAC_BITS) / (range >> NUM_LSH_DIN)
//////////////////////////////////////////////////////////////////////////////////

module LightNorm_inv_range #(
    parameter integer RANGE_WIDTH = 13,
    parameter integer FRAC_BITS   = 16,
    parameter integer NUM_LSH_DIN = 5
)(
    clk,
    nRst,

    range, //input
    inv_range, //output

    start, //input

    valid //output
);

// 2^FRAC_BITS 가 signed 로 들어가려면 FRAC_BITS+2 비트 필요해 (16->18)
localparam integer DIV_WIDTH = FRAC_BITS + 2;
// localparam signed [DIV_WIDTH-1:0] DIV_ONE = 1 <<< FRAC_BITS;
localparam signed [DIV_WIDTH-1:0] DIV_ONE_M1 = (DIV_WIDTH'(1) <<< FRAC_BITS) - 1;

input clk, nRst;

input  start;
input  logic [RANGE_WIDTH-1:0] range;

output logic                 valid;
output logic [FRAC_BITS:0]   inv_range;

logic                       div_start;
logic                       div_valid;
logic                       busy;
logic signed [DIV_WIDTH-1:0] div_result;
logic signed [DIV_WIDTH-1:0] divisor_s;
logic        [RANGE_WIDTH-1:0] range_div;

assign range_div  = range >> NUM_LSH_DIN;
assign div_start  = start && (range_div != '0);
assign divisor_s  = range_div;

divider #(
    .DATA_WIDTH(DIV_WIDTH)
) divider (
    .clk     (clk),
    .nRst    (nRst),
    .start   (div_start),
    // .dividend(DIV_ONE),
    .dividend(DIV_ONE_M1 + divisor_s),
    .divisor (divisor_s),
    .valid   (div_valid),
    .result  (div_result)
);

always @(posedge clk) begin
    if (!nRst) begin
        valid     <= #1 1'b0;
        inv_range <= #1 '0;
        busy      <= #1 1'b0;
    end else begin
        valid <= #1 1'b0;

        if (start) begin
            if (range_div == '0) begin
                valid     <= #1 1'b1;
                inv_range <= #1 '0;
                busy      <= #1 1'b0;
            end else begin
                busy      <= #1 1'b1;
            end
        end else if (busy && div_valid) begin
            valid     <= #1 1'b1;
            inv_range <= #1 (div_result < 0) ? '0 : div_result[FRAC_BITS:0];
            busy      <= #1 1'b0;
        end
    end
end

endmodule