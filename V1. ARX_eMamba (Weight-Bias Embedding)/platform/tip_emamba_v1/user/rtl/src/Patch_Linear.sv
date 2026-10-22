`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/02/2024 02:16:28 PM
// Design Name: 
// Module Name: Patch_Linear
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


module Patch_Linear #(
    parameter integer DATA_WIDTH    = 8,
    parameter integer NUM_SEQLEN    = 16,
    parameter integer NUM_DIM       = 20,
    parameter integer NUM_SCALE_DIN     = 6,
    parameter integer NUM_SCALE_WEIGHT  = 7,
    parameter integer NUM_SCALE_BIAS    = 8,
    parameter integer NUM_SCALE_DOUT    = 8
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// 4 < log2 20 < 5
localparam integer DATA_WIDTH_DOUT  = DATA_WIDTH*2 + 5;
localparam integer NUM_RSH_DOUT     = NUM_SCALE_DIN + NUM_SCALE_WEIGHT - NUM_SCALE_DOUT;

localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

localparam INIT         = 'd0,
           IDLE         = 'd1,
           COMPUTING    = 'd2;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] dIn   [0:NUM_SEQLEN-1][0:NUM_DIM-1]; // 16x20
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_DIM-1];                 // 1x20

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM-1][0:NUM_DIM-1]; // 20x20
logic signed [DATA_WIDTH-1:0] bias   [0:NUM_DIM-1]; // 20

logic [1:0] curr_state,
            next_state;

logic [3:0] curr_dIn_row,
            next_dIn_row;

logic [5:0] curr_weight_column,
            next_weight_column;

logic signed [DATA_WIDTH-1:0] matMult_dIn    [0:NUM_DIM-1]; // 1x20
logic signed [DATA_WIDTH-1:0] matMult_weight [0:NUM_DIM-1]; // 1x20
logic signed [DATA_WIDTH-1:0] matMult_bias;
logic signed [DATA_WIDTH_DOUT-1:0] matMult_dOut;
logic signed [DATA_WIDTH_DOUT_RSH-1:0] matMult_dOut_shifted;
logic signed [DATA_WIDTH-1:0] matMult_dOut_saturated;

integer i;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
matMult_20 #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(NUM_SCALE_BIAS)
) matMult_20 (
    .dIn(matMult_dIn),
    .weight(matMult_weight),
    .bias(matMult_bias),

    .dOut(matMult_dOut)
);

shifter_right #(
    .DATA_WIDTH(DATA_WIDTH_DOUT),
    .NUM_SHIFT(NUM_RSH_DOUT)
) shifter_right (
    .dIn(matMult_dOut),
    .dOut(matMult_dOut_shifted)
);

saturator #(
    .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
) saturator_dOut (
    .dIn(matMult_dOut_shifted),
    .dOut(matMult_dOut_saturated)
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
            if (curr_weight_column == NUM_DIM-1)
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
        curr_dIn_row        <= #1 'd0;
        curr_weight_column  <= #1 'd0;
    end else begin
        curr_dIn_row        <= #1 next_dIn_row;
        curr_weight_column  <= #1 next_weight_column;
    end
end

always @(*) begin
    next_dIn_row        = curr_dIn_row;
    next_weight_column  = curr_weight_column;
    
    case (curr_state)
        INIT: begin
            next_dIn_row        = 0;
            next_weight_column  = 0;
        end

        COMPUTING: begin
            if (curr_weight_column < NUM_DIM-1) begin
                next_dIn_row        = curr_dIn_row;
                next_weight_column  = curr_weight_column + 1;
            end else begin
                next_dIn_row        = curr_dIn_row + 1;
                next_weight_column  = 0;
            end
        end

        default: begin
            next_dIn_row        = curr_dIn_row;
            next_weight_column  = curr_weight_column;
        end
    endcase
end

// Matrix multiplier data
always @(*) begin
    matMult_dIn    = dIn[curr_dIn_row];
    matMult_weight = weight[curr_weight_column];
    matMult_bias   = bias[curr_weight_column];
end

// Final output
always @(posedge clk) begin
    if (!nRst)
        for (i = 0; i < NUM_DIM; i = i + 1)
            dOut[i] <= #1 'd0;
    else
        if (curr_state == COMPUTING)
            dOut[curr_weight_column] <= #1 matMult_dOut_saturated;
        else
            dOut <= #1 dOut;
end

// Ready signal
assign layer_ready = ((curr_state != COMPUTING) && next_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = (curr_state == IDLE) ? 1'b1 : 1'b0;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Hardcoding
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// weight
assign weight[0][0]   = -15;
assign weight[0][1]   = 24;
assign weight[0][2]   = 2;
assign weight[0][3]   = 0;
assign weight[0][4]   = 0;
assign weight[0][5]   = 13;
assign weight[0][6]   = 12;
assign weight[0][7]   = 17;
assign weight[0][8]   = -6;
assign weight[0][9]   = -2;
assign weight[0][10]  = 12;
assign weight[0][11]  = -2;
assign weight[0][12]  = 10;
assign weight[0][13]  = 2;
assign weight[0][14]  = 1;
assign weight[0][15]  = 44;
assign weight[0][16]  = -25;
assign weight[0][17]  = 4;
assign weight[0][18]  = 4;
assign weight[0][19]  = 0;
assign weight[1][0]   = 4;
assign weight[1][1]   = -37;
assign weight[1][2]   = 51;
assign weight[1][3]   = -7;
assign weight[1][4]   = 0;
assign weight[1][5]   = 16;
assign weight[1][6]   = -2;
assign weight[1][7]   = -3;
assign weight[1][8]   = -1;
assign weight[1][9]   = -1;
assign weight[1][10]  = 11;
assign weight[1][11]  = 5;
assign weight[1][12]  = 6;
assign weight[1][13]  = -3;
assign weight[1][14]  = -1;
assign weight[1][15]  = -5;
assign weight[1][16]  = -12;
assign weight[1][17]  = 3;
assign weight[1][18]  = -6;
assign weight[1][19]  = 0;
assign weight[2][0]   = -61;
assign weight[2][1]   = -29;
assign weight[2][2]   = -17;
assign weight[2][3]   = -2;
assign weight[2][4]   = 2;
assign weight[2][5]   = -10;
assign weight[2][6]   = 13;
assign weight[2][7]   = -19;
assign weight[2][8]   = 1;
assign weight[2][9]   = 3;
assign weight[2][10]  = 13;
assign weight[2][11]  = 0;
assign weight[2][12]  = 4;
assign weight[2][13]  = -3;
assign weight[2][14]  = 6;
assign weight[2][15]  = 18;
assign weight[2][16]  = 9;
assign weight[2][17]  = -6;
assign weight[2][18]  = 4;
assign weight[2][19]  = 6;
assign weight[3][0]   = -91;
assign weight[3][1]   = 14;
assign weight[3][2]   = 20;
assign weight[3][3]   = -5;
assign weight[3][4]   = 6;
assign weight[3][5]   = -8;
assign weight[3][6]   = -12;
assign weight[3][7]   = 0;
assign weight[3][8]   = -2;
assign weight[3][9]   = 3;
assign weight[3][10]  = 14;
assign weight[3][11]  = -14;
assign weight[3][12]  = -6;
assign weight[3][13]  = -4;
assign weight[3][14]  = 0;
assign weight[3][15]  = 21;
assign weight[3][16]  = -1;
assign weight[3][17]  = 0;
assign weight[3][18]  = -1;
assign weight[3][19]  = 0;
assign weight[4][0]   = -22;
assign weight[4][1]   = 11;
assign weight[4][2]   = -61;
assign weight[4][3]   = 3;
assign weight[4][4]   = 0;
assign weight[4][5]   = 2;
assign weight[4][6]   = 11;
assign weight[4][7]   = 3;
assign weight[4][8]   = -6;
assign weight[4][9]   = -4;
assign weight[4][10]  = 10;
assign weight[4][11]  = -6;
assign weight[4][12]  = 12;
assign weight[4][13]  = -5;
assign weight[4][14]  = -3;
assign weight[4][15]  = 25;
assign weight[4][16]  = -6;
assign weight[4][17]  = 7;
assign weight[4][18]  = -6;
assign weight[4][19]  = -3;
assign weight[5][0]   = 6;
assign weight[5][1]   = 37;
assign weight[5][2]   = 5;
assign weight[5][3]   = -1;
assign weight[5][4]   = 0;
assign weight[5][5]   = 0;
assign weight[5][6]   = -6;
assign weight[5][7]   = 1;
assign weight[5][8]   = 0;
assign weight[5][9]   = 0;
assign weight[5][10]  = 1;
assign weight[5][11]  = -7;
assign weight[5][12]  = 0;
assign weight[5][13]  = 1;
assign weight[5][14]  = 0;
assign weight[5][15]  = -3;
assign weight[5][16]  = 8;
assign weight[5][17]  = 0;
assign weight[5][18]  = 0;
assign weight[5][19]  = 0;
assign weight[6][0]   = -34;
assign weight[6][1]   = 30;
assign weight[6][2]   = -38;
assign weight[6][3]   = 2;
assign weight[6][4]   = 7;
assign weight[6][5]   = -14;
assign weight[6][6]   = -15;
assign weight[6][7]   = -8;
assign weight[6][8]   = 0;
assign weight[6][9]   = 5;
assign weight[6][10]  = 5;
assign weight[6][11]  = 9;
assign weight[6][12]  = -4;
assign weight[6][13]  = -3;
assign weight[6][14]  = 1;
assign weight[6][15]  = -17;
assign weight[6][16]  = 9;
assign weight[6][17]  = -4;
assign weight[6][18]  = -5;
assign weight[6][19]  = 3;
assign weight[7][0]   = 7;
assign weight[7][1]   = -12;
assign weight[7][2]   = -5;
assign weight[7][3]   = 1;
assign weight[7][4]   = 0;
assign weight[7][5]   = -3;
assign weight[7][6]   = -14;
assign weight[7][7]   = -2;
assign weight[7][8]   = 0;
assign weight[7][9]   = 0;
assign weight[7][10]  = -4;
assign weight[7][11]  = 4;
assign weight[7][12]  = 0;
assign weight[7][13]  = -1;
assign weight[7][14]  = -1;
assign weight[7][15]  = 4;
assign weight[7][16]  = -4;
assign weight[7][17]  = 1;
assign weight[7][18]  = -1;
assign weight[7][19]  = -1;
assign weight[8][0]   = 2;
assign weight[8][1]   = -3;
assign weight[8][2]   = 105;
assign weight[8][3]   = -12;
assign weight[8][4]   = 8;
assign weight[8][5]   = 6;
assign weight[8][6]   = -11;
assign weight[8][7]   = 15;
assign weight[8][8]   = 4;
assign weight[8][9]   = 0;
assign weight[8][10]  = 4;
assign weight[8][11]  = -8;
assign weight[8][12]  = 4;
assign weight[8][13]  = 1;
assign weight[8][14]  = -1;
assign weight[8][15]  = 15;
assign weight[8][16]  = -1;
assign weight[8][17]  = 2;
assign weight[8][18]  = 0;
assign weight[8][19]  = -2;
assign weight[9][0]   = -1;
assign weight[9][1]   = 31;
assign weight[9][2]   = 9;
assign weight[9][3]   = -1;
assign weight[9][4]   = -1;
assign weight[9][5]   = 3;
assign weight[9][6]   = 4;
assign weight[9][7]   = -2;
assign weight[9][8]   = 1;
assign weight[9][9]   = -1;
assign weight[9][10]  = -6;
assign weight[9][11]  = 4;
assign weight[9][12]  = 0;
assign weight[9][13]  = 2;
assign weight[9][14]  = 1;
assign weight[9][15]  = 5;
assign weight[9][16]  = -4;
assign weight[9][17]  = 0;
assign weight[9][18]  = 0;
assign weight[9][19]  = 1;
assign weight[10][0]  = 42;
assign weight[10][1]  = 27;
assign weight[10][2]  = 11;
assign weight[10][3]  = 0;
assign weight[10][4]  = 3;
assign weight[10][5]  = 18;
assign weight[10][6]  = -14;
assign weight[10][7]  = -11;
assign weight[10][8]  = 0;
assign weight[10][9]  = 2;
assign weight[10][10] = -12;
assign weight[10][11] = -1;
assign weight[10][12] = 13;
assign weight[10][13] = -3;
assign weight[10][14] = 2;
assign weight[10][15] = -22;
assign weight[10][16] = 23;
assign weight[10][17] = 16;
assign weight[10][18] = -1;
assign weight[10][19] = 1;
assign weight[11][0]  = -43;
assign weight[11][1]  = -18;
assign weight[11][2]  = -7;
assign weight[11][3]  = -5;
assign weight[11][4]  = 3;
assign weight[11][5]  = -1;
assign weight[11][6]  = -29;
assign weight[11][7]  = -1;
assign weight[11][8]  = -5;
assign weight[11][9]  = 4;
assign weight[11][10] = -2;
assign weight[11][11] = -7;
assign weight[11][12] = 9;
assign weight[11][13] = -3;
assign weight[11][14] = -1;
assign weight[11][15] = -7;
assign weight[11][16] = 2;
assign weight[11][17] = -6;
assign weight[11][18] = -1;
assign weight[11][19] = 2;
assign weight[12][0]  = -39;
assign weight[12][1]  = 21;
assign weight[12][2]  = 2;
assign weight[12][3]  = 1;
assign weight[12][4]  = 0;
assign weight[12][5]  = 0;
assign weight[12][6]  = -9;
assign weight[12][7]  = 2;
assign weight[12][8]  = 0;
assign weight[12][9]  = -2;
assign weight[12][10] = -18;
assign weight[12][11] = 7;
assign weight[12][12] = -15;
assign weight[12][13] = 6;
assign weight[12][14] = -5;
assign weight[12][15] = 2;
assign weight[12][16] = 3;
assign weight[12][17] = -8;
assign weight[12][18] = 0;
assign weight[12][19] = -3;
assign weight[13][0]  = -34;
assign weight[13][1]  = 31;
assign weight[13][2]  = 45;
assign weight[13][3]  = -8;
assign weight[13][4]  = -4;
assign weight[13][5]  = -14;
assign weight[13][6]  = -11;
assign weight[13][7]  = -2;
assign weight[13][8]  = -2;
assign weight[13][9]  = -3;
assign weight[13][10] = 2;
assign weight[13][11] = -2;
assign weight[13][12] = 13;
assign weight[13][13] = -2;
assign weight[13][14] = -4;
assign weight[13][15] = -16;
assign weight[13][16] = 5;
assign weight[13][17] = -9;
assign weight[13][18] = -4;
assign weight[13][19] = -4;
assign weight[14][0]  = 42;
assign weight[14][1]  = -2;
assign weight[14][2]  = -18;
assign weight[14][3]  = 2;
assign weight[14][4]  = 6;
assign weight[14][5]  = -10;
assign weight[14][6]  = 17;
assign weight[14][7]  = 2;
assign weight[14][8]  = -3;
assign weight[14][9]  = 6;
assign weight[14][10] = -23;
assign weight[14][11] = -10;
assign weight[14][12] = -2;
assign weight[14][13] = -1;
assign weight[14][14] = 5;
assign weight[14][15] = -17;
assign weight[14][16] = -7;
assign weight[14][17] = -7;
assign weight[14][18] = -2;
assign weight[14][19] = 4;
assign weight[15][0]  = 16;
assign weight[15][1]  = -28;
assign weight[15][2]  = 1;
assign weight[15][3]  = -2;
assign weight[15][4]  = -3;
assign weight[15][5]  = 0;
assign weight[15][6]  = 2;
assign weight[15][7]  = -4;
assign weight[15][8]  = -1;
assign weight[15][9]  = -3;
assign weight[15][10] = -3;
assign weight[15][11] = -10;
assign weight[15][12] = 0;
assign weight[15][13] = -1;
assign weight[15][14] = -2;
assign weight[15][15] = 7;
assign weight[15][16] = 12;
assign weight[15][17] = -5;
assign weight[15][18] = 1;
assign weight[15][19] = 0;
assign weight[16][0]  = -17;
assign weight[16][1]  = -23;
assign weight[16][2]  = -22;
assign weight[16][3]  = -1;
assign weight[16][4]  = -6;
assign weight[16][5]  = 7;
assign weight[16][6]  = 5;
assign weight[16][7]  = 35;
assign weight[16][8]  = -10;
assign weight[16][9]  = -3;
assign weight[16][10] = -14;
assign weight[16][11] = 0;
assign weight[16][12] = 8;
assign weight[16][13] = 5;
assign weight[16][14] = 4;
assign weight[16][15] = -35;
assign weight[16][16] = 10;
assign weight[16][17] = 16;
assign weight[16][18] = -1;
assign weight[16][19] = -1;
assign weight[17][0]  = -10;
assign weight[17][1]  = 11;
assign weight[17][2]  = -3;
assign weight[17][3]  = 2;
assign weight[17][4]  = 0;
assign weight[17][5]  = -6;
assign weight[17][6]  = -19;
assign weight[17][7]  = -12;
assign weight[17][8]  = 3;
assign weight[17][9]  = 0;
assign weight[17][10] = -9;
assign weight[17][11] = -26;
assign weight[17][12] = 2;
assign weight[17][13] = 2;
assign weight[17][14] = 1;
assign weight[17][15] = -16;
assign weight[17][16] = -1;
assign weight[17][17] = -1;
assign weight[17][18] = 2;
assign weight[17][19] = 0;
assign weight[18][0]  = -38;
assign weight[18][1]  = -10;
assign weight[18][2]  = 10;
assign weight[18][3]  = 8;
assign weight[18][4]  = 11;
assign weight[18][5]  = -24;
assign weight[18][6]  = 5;
assign weight[18][7]  = 15;
assign weight[18][8]  = 7;
assign weight[18][9]  = 5;
assign weight[18][10] = 1;
assign weight[18][11] = -4;
assign weight[18][12] = 18;
assign weight[18][13] = 5;
assign weight[18][14] = 3;
assign weight[18][15] = 29;
assign weight[18][16] = -4;
assign weight[18][17] = 23;
assign weight[18][18] = 5;
assign weight[18][19] = 4;
assign weight[19][0]  = 6;
assign weight[19][1]  = 3;
assign weight[19][2]  = -6;
assign weight[19][3]  = 0;
assign weight[19][4]  = 4;
assign weight[19][5]  = 26;
assign weight[19][6]  = -23;
assign weight[19][7]  = 5;
assign weight[19][8]  = -1;
assign weight[19][9]  = 5;
assign weight[19][10] = 22;
assign weight[19][11] = -4;
assign weight[19][12] = -5;
assign weight[19][13] = 2;
assign weight[19][14] = 3;
assign weight[19][15] = 13;
assign weight[19][16] = 4;
assign weight[19][17] = -1;
assign weight[19][18] = -2;
assign weight[19][19] = 0;

// bias
assign bias[0]  = -23;
assign bias[1]  = 49;
assign bias[2]  = 45;
assign bias[3]  = 17;
assign bias[4]  = -38;
assign bias[5]  = -121;
assign bias[6]  = -79;
assign bias[7]  = 105;
assign bias[8]  = -11;
assign bias[9]  = -128;
assign bias[10] = -53;
assign bias[11] = 91;
assign bias[12] = -73;
assign bias[13] = -73;
assign bias[14] = 48;
assign bias[15] = 96;
assign bias[16] = 33;
assign bias[17] = 127;
assign bias[18] = -13;
assign bias[19] = 76;

endmodule