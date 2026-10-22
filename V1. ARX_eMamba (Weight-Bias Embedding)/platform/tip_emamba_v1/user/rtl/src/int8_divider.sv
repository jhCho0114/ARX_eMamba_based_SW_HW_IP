`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2024 09:29:40 PM
// Design Name: 
// Module Name: int8_divider
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


module int8_divider #(
    // DATA_WIDTH of numbers in bits
    parameter DATA_WIDTH = 8
)(
    clk,
    nRst,

    start,

    dividend,
    divisor,

    valid,

    result
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam IDLE  = 'd0,
           INIT  = 'd1,
           CALC  = 'd2,
           ROUND = 'd3,
           DONE  = 'd4;

// Iteration count: unsigned input DATA_WIDTH
localparam NUM_ITER = DATA_WIDTH;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;
input start;

input logic signed [DATA_WIDTH-1:0] dividend;
input logic signed [DATA_WIDTH-1:0] divisor;

output logic valid;
output logic signed [DATA_WIDTH-1:0] result;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [2:0] curr_state, next_state;

// Iteration counter (allow NUM_ITER+1 iterations for rounding)
logic [$clog2(NUM_ITER)-1:0] curr_iteration, next_iteration;

logic dividend_sign, divisor_sign, sign_diff;        // Signs of inputs and whether different
logic [DATA_WIDTH-1:0] dividend_abs, divisor_abs;    // Absolute version of inputs (unsigned)
logic [DATA_WIDTH-1:0] curr_quo, next_quo;           // Intermediate quotients (unsigned)
logic [DATA_WIDTH:0]   curr_acc, next_acc, temp_acc; // Accumulator (unsigned but 1 bit wider)

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Signs & Absolute data
assign dividend_sign = dividend[DATA_WIDTH-1];
assign divisor_sign  = divisor[DATA_WIDTH-1];

assign sign_diff = (dividend_sign ^ divisor_sign);

assign dividend_abs = (dividend_sign) ? -dividend : dividend;
assign divisor_abs  = (divisor_sign)  ? -divisor  : divisor;

// FSM
always @(posedge clk) begin
    if (!nRst)
        curr_state <= #1 IDLE;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        IDLE, DONE: begin
            if (start)
                if (divisor == 0)
                    next_state = DONE;
                else
                    next_state = INIT;
            else
                next_state = curr_state;
        end

        INIT: next_state = CALC;

        CALC: begin
            if (curr_iteration == NUM_ITER-1)
                next_state = ROUND;
            else
                next_state = curr_state;
        end

        ROUND: next_state = DONE;

        default: next_state = curr_state;
    endcase
end

// Iteration
always @(posedge clk) begin
    if (!nRst)
        curr_iteration <= #1 0;
    else
        curr_iteration <= #1 next_iteration;
end

always @(*) begin
    if (curr_state == INIT)
        next_iteration = 0;
    else if (curr_state == CALC)
        next_iteration = curr_iteration + 1; 
    else
        next_iteration = curr_iteration;
end

// Accumulator & Quotients
always @(posedge clk) begin
    if (!nRst) begin
        curr_acc <= #1 0;
        curr_quo <= #1 0;
    end else begin
        case (curr_state)
            IDLE, DONE: begin
                if (start) begin
                    curr_acc <= #1 0;
                    curr_quo <= #1 0;
                end else begin
                    curr_acc <= #1 curr_acc;
                    curr_quo <= #1 curr_quo;
                end
            end

            INIT: begin
                curr_acc <= #1 {{DATA_WIDTH{1'b0}}, dividend_abs[DATA_WIDTH-1]};
                curr_quo <= #1 {dividend_abs[DATA_WIDTH-2:0], 1'b0};
            end

            CALC: begin
                curr_acc <= #1 next_acc;
                curr_quo <= #1 next_quo;
            end

            // ROUND: begin
            //     curr_acc <= #1 curr_acc;
            //     if (curr_acc >= divisor_abs)
            //         curr_quo <= #1 curr_quo + 1;
            //     else
            //         curr_quo <= #1 curr_quo;
            // end
            
            default: begin
                curr_acc <= #1 curr_acc;
                curr_quo <= #1 curr_quo;
            end
        endcase
    end
end

always @(*) begin
    temp_acc = curr_acc - {1'b0, divisor_abs};
end

always @(*) begin
    if (curr_state == IDLE) begin
        next_acc = curr_acc;
        next_quo = curr_quo;
    end else begin
        if (curr_acc >= divisor_abs) begin
            {next_acc, next_quo} = {temp_acc[DATA_WIDTH-1:0], curr_quo, 1'b1};
        end else begin
            {next_acc, next_quo} = {curr_acc, curr_quo} << 1;
        end
    end
end

// Valid signal
always @(*) begin
    if (curr_state == DONE)
        valid = 1;
    else
        valid = 0;
end

// Final output quotient
always @(*) begin
    if (divisor == 0)
        result = dividend;
    else
        if (sign_diff)
            if (curr_quo[DATA_WIDTH-1])
                result = {1'b1, {DATA_WIDTH-1{1'b0}}};
            else
                result = -curr_quo;
        else
            if (curr_quo[DATA_WIDTH-1])
                result = {1'b0, {DATA_WIDTH-1{1'b1}}};
            else
                result = curr_quo;
end

endmodule