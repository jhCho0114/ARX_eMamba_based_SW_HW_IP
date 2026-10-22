`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/02/2024 02:15:56 PM
// Design Name: 
// Module Name: Patch_Rearrange
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


module Patch_Rearrange #(
    parameter integer DATA_WIDTH    = 8,
    parameter integer NUM_CHANNEL   = 5,
    parameter integer NUM_HEIGHT    = 8,
    parameter integer NUM_WIDTH     = 8,
    parameter integer PATCH1        = 2,
    parameter integer PATCH2        = 2
)(
    dIn,
    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_SEQLEN   = (NUM_HEIGHT / PATCH1) * (NUM_WIDTH / PATCH2);
localparam integer NUM_DIM      = PATCH1 * PATCH2 * NUM_CHANNEL;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input   logic signed [DATA_WIDTH-1:0] dIn   [0:NUM_CHANNEL-1][0:NUM_HEIGHT-1][0:NUM_WIDTH-1]; // 5x8x8
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_SEQLEN-1][0:NUM_DIM-1];                    // 16x20

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
genvar c, h, w, ph, pw;

generate
    for (h = 0; h < NUM_HEIGHT/PATCH1; h = h + 1) begin
        for (w = 0; w < NUM_WIDTH/PATCH2; w = w + 1) begin
            for (ph = 0; ph < PATCH1; ph = ph + 1) begin
                for (pw = 0; pw < PATCH2; pw = pw + 1) begin
                    for (c = 0; c < NUM_CHANNEL; c = c + 1) begin
                        assign dOut[h * (NUM_WIDTH/PATCH2) + w][(PATCH2 * ph + pw) * NUM_CHANNEL + c] = 
                                dIn[c][PATCH1 * h + ph][PATCH2 * w + pw];
                    end
                end
            end
        end
    end
endgenerate

endmodule