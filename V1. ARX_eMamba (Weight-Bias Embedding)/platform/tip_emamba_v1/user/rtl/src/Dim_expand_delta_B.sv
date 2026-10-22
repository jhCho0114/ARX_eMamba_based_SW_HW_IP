`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/07/2024 04:32:04 PM
// Design Name: 
// Module Name: Dim_expand_delta_B
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


module Dim_expand_delta_B #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM_1  = 40,
    parameter integer NUM_DIM_2  = 8,

    parameter integer NUM_SCALE_DIN_1 = 4,
    parameter integer NUM_SCALE_DIN_2 = 3,
    parameter integer NUM_SCALE_DOUT  = 1
)(
    clk,
    nRst,

    ps_start,

    delta,
    matrix_B,
    dOut,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH * 2;

localparam INIT         = 'd0,
           IDLE         = 'd1,
           COMPUTING    = 'd2;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] delta     [0:NUM_DIM_1-1];                // 40
input   logic signed [DATA_WIDTH-1:0] matrix_B  [0:NUM_DIM_2-1];                // 8
output  logic signed [DATA_WIDTH-1:0] dOut      [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [1:0] curr_state,
            next_state;

logic [3:0] curr_dIn_row, // Sequnce length
            next_dIn_row;

logic [5:0] curr_dIn_column,
            next_dIn_column;

logic signed [DATA_WIDTH-1:0] compute_delta;
logic signed [DATA_WIDTH-1:0] compute_matrix_B  [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] compute_dOut      [0:NUM_DIM_2-1];

logic signed [DATA_WIDTH-1:0] delta_mem     [0:NUM_DIM_1-1];                // 40
logic signed [DATA_WIDTH-1:0] matrix_B_mem  [0:NUM_DIM_2-1];                // 8
logic signed [DATA_WIDTH-1:0] dOut_mem      [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
Dim_expand_delta_B_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_ED(NUM_DIM_2),

    .NUM_SCALE_DIN_1(NUM_SCALE_DIN_1),
    .NUM_SCALE_DIN_2(NUM_SCALE_DIN_2),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) Dim_expand_delta_B_compute (
    .delta(compute_delta),
    .matrix(compute_matrix_B),

    .dOut(compute_dOut)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// FSM
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        INIT, IDLE: begin
            if (prev_layer_ready & next_layer_ready)
                next_state = COMPUTING;
            else
                next_state = curr_state;
        end

        COMPUTING: begin
            if (curr_dIn_column == NUM_DIM_1-1)
                next_state = IDLE;
            else
                next_state = curr_state;
        end

        default: next_state = curr_state;
    endcase
end

// Compute cycle
always @(posedge clk) begin
    if (!nRst) begin
        curr_dIn_row    <= #1 'd0;
        curr_dIn_column <= #1 'd0;
    end else begin
        curr_dIn_row    <= #1 next_dIn_row;
        curr_dIn_column <= #1 next_dIn_column;
    end
end

always @(*) begin
    next_dIn_row    = curr_dIn_row;
    next_dIn_column = curr_dIn_column;
    
    case (curr_state)
        INIT: begin
            next_dIn_row    = 0;
            next_dIn_column = 0;
        end

        COMPUTING: begin
            if (curr_dIn_column < NUM_DIM_1-1) begin
                next_dIn_row    = curr_dIn_row;
                next_dIn_column = curr_dIn_column + 1;
            end else begin
                next_dIn_row    = curr_dIn_row + 1;
                next_dIn_column = 0;
            end
        end

        default: begin
            next_dIn_row    = curr_dIn_row;
            next_dIn_column = curr_dIn_column;
        end
    endcase
end

// Matrix multiplier data
always @(*) begin
    compute_delta       = delta_mem[curr_dIn_column];
    compute_matrix_B    = matrix_B_mem;
end

// Final output
always @(posedge clk) begin
    if (curr_state == COMPUTING)
        dOut_mem[curr_dIn_column] <= #1 compute_dOut;
    else
        dOut_mem <= #1 dOut_mem;
end

genvar i;
generate
    for (i = 0; i < NUM_DIM_1; i = i + 1) begin
        assign dOut[i] = dOut_mem[i];
    end
endgenerate

// Input FF
always @(posedge clk) begin
    if (prev_layer_ready & next_layer_ready) begin
        delta_mem       <= #1 delta;
        matrix_B_mem    <= #1 matrix_B;
    end else begin
        delta_mem       <= #1 delta_mem;
        matrix_B_mem    <= #1 matrix_B_mem;
    end
end

// Ready signal
assign layer_ready = ((curr_state != COMPUTING) && next_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = ((curr_state == IDLE) && prev_layer_ready) ? 1'b1 : 1'b0;

endmodule