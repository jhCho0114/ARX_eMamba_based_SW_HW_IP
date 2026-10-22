`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 11:13:05 AM
// Design Name: 
// Module Name: Exp_piecewise
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


module Exp_piecewise #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 40, // ED(40)
    parameter integer NUM_DIM_2  = 8,  // N(8)

    parameter integer NUM_SCALE_DIN_1  = 4, // delta scale
    parameter integer NUM_SCALE_DIN_2  = 3, // matrix A scale
    parameter integer NUM_SCALE_DOUT = 7,

    // 0: 1st MAMBA, 1: 2nd MAMBA
    parameter integer LAYER_ID = 0
)(
    clk,
    nRst,

    ps_start,

    delta,
    dOut,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DIN       = DATA_WIDTH * 2;
localparam integer NUM_SCALE_DIN_EXP    = NUM_SCALE_DIN_1 + NUM_SCALE_DIN_2;

localparam INIT         = 'd0,
           IDLE         = 'd1,
           COMPUTING    = 'd2;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] delta [0:NUM_DIM_1-1];                // ED(40)
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] matrix_A [0:NUM_DIM_1-1][0:NUM_DIM_2-1]; // 40x8

logic [1:0] curr_state,
            next_state;

logic [3:0] curr_dIn_row, // Sequnce length
            next_dIn_row;

logic [5:0] curr_dIn_column,
            next_dIn_column;

logic signed [DATA_WIDTH_DIN-1:0] compute_pExp_dIn [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] compute_pExp_dOut [0:NUM_DIM_2-1];

logic signed [DATA_WIDTH-1:0] delta_mem [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] dOut_mem [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
Dim_expand_delta_A_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_ED(NUM_DIM_2) // N(8)
) Dim_expand_delta_A_compute (
    .delta(delta_mem[curr_dIn_column]),
    .matrix(matrix_A[curr_dIn_column]),

    .dOut(compute_pExp_dIn)
);

Exp_piecewise_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN_EXP),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) Exp_piecewise_compute (
    .dIn(compute_pExp_dIn),
    .dOut_8bit(compute_pExp_dOut)
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

// Final output
always @(posedge clk) begin
    if (curr_state == COMPUTING)
        dOut_mem[curr_dIn_column] <= #1 compute_pExp_dOut;
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
    if (prev_layer_ready & next_layer_ready)
        delta_mem <= #1 delta;
    else
        delta_mem <= #1 delta_mem;
end

// Ready signal
assign layer_ready = ((curr_state != COMPUTING) && next_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = ((curr_state == IDLE) && prev_layer_ready) ? 1'b1 : 1'b0;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Hard Coding
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    if (LAYER_ID == 0) begin
        assign matrix_A[0][0]  = -5;
        assign matrix_A[0][1]  = -20;
        assign matrix_A[0][2]  = -20;
        assign matrix_A[0][3]  = -48;
        assign matrix_A[0][4]  = -26;
        assign matrix_A[0][5]  = -32;
        assign matrix_A[0][6]  = -48;
        assign matrix_A[0][7]  = -47;
        assign matrix_A[1][0]  = -4;
        assign matrix_A[1][1]  = -8;
        assign matrix_A[1][2]  = -18;
        assign matrix_A[1][3]  = -14;
        assign matrix_A[1][4]  = -45;
        assign matrix_A[1][5]  = -38;
        assign matrix_A[1][6]  = -21;
        assign matrix_A[1][7]  = -90;
        assign matrix_A[2][0]  = -6;
        assign matrix_A[2][1]  = -13;
        assign matrix_A[2][2]  = -31;
        assign matrix_A[2][3]  = -34;
        assign matrix_A[2][4]  = -47;
        assign matrix_A[2][5]  = -27;
        assign matrix_A[2][6]  = -39;
        assign matrix_A[2][7]  = -61;
        assign matrix_A[3][0]  = -5;
        assign matrix_A[3][1]  = -15;
        assign matrix_A[3][2]  = -21;
        assign matrix_A[3][3]  = -27;
        assign matrix_A[3][4]  = -38;
        assign matrix_A[3][5]  = -67;
        assign matrix_A[3][6]  = -82;
        assign matrix_A[3][7]  = -57;
        assign matrix_A[4][0]  = -5;
        assign matrix_A[4][1]  = -8;
        assign matrix_A[4][2]  = -13;
        assign matrix_A[4][3]  = -8;
        assign matrix_A[4][4]  = -16;
        assign matrix_A[4][5]  = -73;
        assign matrix_A[4][6]  = -100;
        assign matrix_A[4][7]  = -74;
        assign matrix_A[5][0]  = -7;
        assign matrix_A[5][1]  = -16;
        assign matrix_A[5][2]  = -30;
        assign matrix_A[5][3]  = -30;
        assign matrix_A[5][4]  = -69;
        assign matrix_A[5][5]  = -48;
        assign matrix_A[5][6]  = -62;
        assign matrix_A[5][7]  = -37;
        assign matrix_A[6][0]  = -3;
        assign matrix_A[6][1]  = -9;
        assign matrix_A[6][2]  = -43;
        assign matrix_A[6][3]  = -31;
        assign matrix_A[6][4]  = -25;
        assign matrix_A[6][5]  = -24;
        assign matrix_A[6][6]  = -39;
        assign matrix_A[6][7]  = -119;
        assign matrix_A[7][0]  = -3;
        assign matrix_A[7][1]  = -12;
        assign matrix_A[7][2]  = -21;
        assign matrix_A[7][3]  = -68;
        assign matrix_A[7][4]  = -36;
        assign matrix_A[7][5]  = -30;
        assign matrix_A[7][6]  = -40;
        assign matrix_A[7][7]  = -50;
        assign matrix_A[8][0]  = -8;
        assign matrix_A[8][1]  = -17;
        assign matrix_A[8][2]  = -23;
        assign matrix_A[8][3]  = -31;
        assign matrix_A[8][4]  = -42;
        assign matrix_A[8][5]  = -49;
        assign matrix_A[8][6]  = -58;
        assign matrix_A[8][7]  = -62;
        assign matrix_A[9][0]  = -5;
        assign matrix_A[9][1]  = -20;
        assign matrix_A[9][2]  = -20;
        assign matrix_A[9][3]  = -32;
        assign matrix_A[9][4]  = -55;
        assign matrix_A[9][5]  = -33;
        assign matrix_A[9][6]  = -80;
        assign matrix_A[9][7]  = -44;
        assign matrix_A[10][0] = -12;
        assign matrix_A[10][1] = -19;
        assign matrix_A[10][2] = -25;
        assign matrix_A[10][3] = -11;
        assign matrix_A[10][4] = -30;
        assign matrix_A[10][5] = -37;
        assign matrix_A[10][6] = -58;
        assign matrix_A[10][7] = -54;
        assign matrix_A[11][0] = -5;
        assign matrix_A[11][1] = -30;
        assign matrix_A[11][2] = -16;
        assign matrix_A[11][3] = -17;
        assign matrix_A[11][4] = -45;
        assign matrix_A[11][5] = -19;
        assign matrix_A[11][6] = -66;
        assign matrix_A[11][7] = -40;
        assign matrix_A[12][0] = -4;
        assign matrix_A[12][1] = -8;
        assign matrix_A[12][2] = -23;
        assign matrix_A[12][3] = -31;
        assign matrix_A[12][4] = -46;
        assign matrix_A[12][5] = -58;
        assign matrix_A[12][6] = -38;
        assign matrix_A[12][7] = -66;
        assign matrix_A[13][0] = -5;
        assign matrix_A[13][1] = -21;
        assign matrix_A[13][2] = -23;
        assign matrix_A[13][3] = -70;
        assign matrix_A[13][4] = -30;
        assign matrix_A[13][5] = -80;
        assign matrix_A[13][6] = -50;
        assign matrix_A[13][7] = -107;
        assign matrix_A[14][0] = -9;
        assign matrix_A[14][1] = -16;
        assign matrix_A[14][2] = -23;
        assign matrix_A[14][3] = -53;
        assign matrix_A[14][4] = -21;
        assign matrix_A[14][5] = -25;
        assign matrix_A[14][6] = -82;
        assign matrix_A[14][7] = -37;
        assign matrix_A[15][0] = -15;
        assign matrix_A[15][1] = -27;
        assign matrix_A[15][2] = -24;
        assign matrix_A[15][3] = -26;
        assign matrix_A[15][4] = -57;
        assign matrix_A[15][5] = -55;
        assign matrix_A[15][6] = -81;
        assign matrix_A[15][7] = -76;
        assign matrix_A[16][0] = -6;
        assign matrix_A[16][1] = -15;
        assign matrix_A[16][2] = -22;
        assign matrix_A[16][3] = -42;
        assign matrix_A[16][4] = -38;
        assign matrix_A[16][5] = -62;
        assign matrix_A[16][6] = -72;
        assign matrix_A[16][7] = -76;
        assign matrix_A[17][0] = -5;
        assign matrix_A[17][1] = -19;
        assign matrix_A[17][2] = -29;
        assign matrix_A[17][3] = -22;
        assign matrix_A[17][4] = -49;
        assign matrix_A[17][5] = -39;
        assign matrix_A[17][6] = -71;
        assign matrix_A[17][7] = -32;
        assign matrix_A[18][0] = -1;
        assign matrix_A[18][1] = -1;
        assign matrix_A[18][2] = -5;
        assign matrix_A[18][3] = -15;
        assign matrix_A[18][4] = -2;
        assign matrix_A[18][5] = -21;
        assign matrix_A[18][6] = -59;
        assign matrix_A[18][7] = -114;
        assign matrix_A[19][0] = -8;
        assign matrix_A[19][1] = -16;
        assign matrix_A[19][2] = -23;
        assign matrix_A[19][3] = -31;
        assign matrix_A[19][4] = -46;
        assign matrix_A[19][5] = -38;
        assign matrix_A[19][6] = -53;
        assign matrix_A[19][7] = -79;
        assign matrix_A[20][0] = -4;
        assign matrix_A[20][1] = -5;
        assign matrix_A[20][2] = -21;
        assign matrix_A[20][3] = -38;
        assign matrix_A[20][4] = -37;
        assign matrix_A[20][5] = -82;
        assign matrix_A[20][6] = -59;
        assign matrix_A[20][7] = -65;
        assign matrix_A[21][0] = -4;
        assign matrix_A[21][1] = -6;
        assign matrix_A[21][2] = -25;
        assign matrix_A[21][3] = -42;
        assign matrix_A[21][4] = -18;
        assign matrix_A[21][5] = -19;
        assign matrix_A[21][6] = -27;
        assign matrix_A[21][7] = -128;
        assign matrix_A[22][0] = -8;
        assign matrix_A[22][1] = -15;
        assign matrix_A[22][2] = -24;
        assign matrix_A[22][3] = -32;
        assign matrix_A[22][4] = -39;
        assign matrix_A[22][5] = -48;
        assign matrix_A[22][6] = -56;
        assign matrix_A[22][7] = -64;
        assign matrix_A[23][0] = -7;
        assign matrix_A[23][1] = -12;
        assign matrix_A[23][2] = -16;
        assign matrix_A[23][3] = -39;
        assign matrix_A[23][4] = -30;
        assign matrix_A[23][5] = -40;
        assign matrix_A[23][6] = -38;
        assign matrix_A[23][7] = -13;
        assign matrix_A[24][0] = -7;
        assign matrix_A[24][1] = -14;
        assign matrix_A[24][2] = -19;
        assign matrix_A[24][3] = -30;
        assign matrix_A[24][4] = -37;
        assign matrix_A[24][5] = -47;
        assign matrix_A[24][6] = -45;
        assign matrix_A[24][7] = -57;
        assign matrix_A[25][0] = -3;
        assign matrix_A[25][1] = -5;
        assign matrix_A[25][2] = -5;
        assign matrix_A[25][3] = -49;
        assign matrix_A[25][4] = -8;
        assign matrix_A[25][5] = -73;
        assign matrix_A[25][6] = -46;
        assign matrix_A[25][7] = -43;
        assign matrix_A[26][0] = -6;
        assign matrix_A[26][1] = -21;
        assign matrix_A[26][2] = -7;
        assign matrix_A[26][3] = -30;
        assign matrix_A[26][4] = -11;
        assign matrix_A[26][5] = -128;
        assign matrix_A[26][6] = -95;
        assign matrix_A[26][7] = -44;
        assign matrix_A[27][0] = -4;
        assign matrix_A[27][1] = -11;
        assign matrix_A[27][2] = -25;
        assign matrix_A[27][3] = -9;
        assign matrix_A[27][4] = -10;
        assign matrix_A[27][5] = -11;
        assign matrix_A[27][6] = -50;
        assign matrix_A[27][7] = -89;
        assign matrix_A[28][0] = -2;
        assign matrix_A[28][1] = -10;
        assign matrix_A[28][2] = -19;
        assign matrix_A[28][3] = -25;
        assign matrix_A[28][4] = -80;
        assign matrix_A[28][5] = -69;
        assign matrix_A[28][6] = -53;
        assign matrix_A[28][7] = -30;
        assign matrix_A[29][0] = -6;
        assign matrix_A[29][1] = -28;
        assign matrix_A[29][2] = -21;
        assign matrix_A[29][3] = -19;
        assign matrix_A[29][4] = -35;
        assign matrix_A[29][5] = -57;
        assign matrix_A[29][6] = -41;
        assign matrix_A[29][7] = -62;
        assign matrix_A[30][0] = -8;
        assign matrix_A[30][1] = -16;
        assign matrix_A[30][2] = -24;
        assign matrix_A[30][3] = -32;
        assign matrix_A[30][4] = -41;
        assign matrix_A[30][5] = -49;
        assign matrix_A[30][6] = -61;
        assign matrix_A[30][7] = -63;
        assign matrix_A[31][0] = -8;
        assign matrix_A[31][1] = -17;
        assign matrix_A[31][2] = -32;
        assign matrix_A[31][3] = -54;
        assign matrix_A[31][4] = -42;
        assign matrix_A[31][5] = -51;
        assign matrix_A[31][6] = -66;
        assign matrix_A[31][7] = -93;
        assign matrix_A[32][0] = -4;
        assign matrix_A[32][1] = -16;
        assign matrix_A[32][2] = -34;
        assign matrix_A[32][3] = -27;
        assign matrix_A[32][4] = -25;
        assign matrix_A[32][5] = -49;
        assign matrix_A[32][6] = -60;
        assign matrix_A[32][7] = -102;
        assign matrix_A[33][0] = -9;
        assign matrix_A[33][1] = -19;
        assign matrix_A[33][2] = -33;
        assign matrix_A[33][3] = -18;
        assign matrix_A[33][4] = -59;
        assign matrix_A[33][5] = -69;
        assign matrix_A[33][6] = -50;
        assign matrix_A[33][7] = -68;
        assign matrix_A[34][0] = -4;
        assign matrix_A[34][1] = -8;
        assign matrix_A[34][2] = -13;
        assign matrix_A[34][3] = -18;
        assign matrix_A[34][4] = -43;
        assign matrix_A[34][5] = -43;
        assign matrix_A[34][6] = -22;
        assign matrix_A[34][7] = -69;
        assign matrix_A[35][0] = -10;
        assign matrix_A[35][1] = -13;
        assign matrix_A[35][2] = -25;
        assign matrix_A[35][3] = -12;
        assign matrix_A[35][4] = -39;
        assign matrix_A[35][5] = -24;
        assign matrix_A[35][6] = -33;
        assign matrix_A[35][7] = -63;
        assign matrix_A[36][0] = -4;
        assign matrix_A[36][1] = -10;
        assign matrix_A[36][2] = -14;
        assign matrix_A[36][3] = -9;
        assign matrix_A[36][4] = -55;
        assign matrix_A[36][5] = -44;
        assign matrix_A[36][6] = -40;
        assign matrix_A[36][7] = -54;
        assign matrix_A[37][0] = -5;
        assign matrix_A[37][1] = -13;
        assign matrix_A[37][2] = -14;
        assign matrix_A[37][3] = -17;
        assign matrix_A[37][4] = -19;
        assign matrix_A[37][5] = -60;
        assign matrix_A[37][6] = -92;
        assign matrix_A[37][7] = -69;
        assign matrix_A[38][0] = -8;
        assign matrix_A[38][1] = -17;
        assign matrix_A[38][2] = -25;
        assign matrix_A[38][3] = -33;
        assign matrix_A[38][4] = -41;
        assign matrix_A[38][5] = -50;
        assign matrix_A[38][6] = -56;
        assign matrix_A[38][7] = -65;
        assign matrix_A[39][0] = -3;
        assign matrix_A[39][1] = -8;
        assign matrix_A[39][2] = -13;
        assign matrix_A[39][3] = -43;
        assign matrix_A[39][4] = -34;
        assign matrix_A[39][5] = -21;
        assign matrix_A[39][6] = -40;
        assign matrix_A[39][7] = -128;
    end

    else if (LAYER_ID == 1) begin
        assign matrix_A[0][0]  = -4;
        assign matrix_A[0][1]  = -8;
        assign matrix_A[0][2]  = -12;
        assign matrix_A[0][3]  = -16;
        assign matrix_A[0][4]  = -18;
        assign matrix_A[0][5]  = -25;
        assign matrix_A[0][6]  = -27;
        assign matrix_A[0][7]  = -31;
        assign matrix_A[1][0]  = -3;
        assign matrix_A[1][1]  = -5;
        assign matrix_A[1][2]  = -14;
        assign matrix_A[1][3]  = -16;
        assign matrix_A[1][4]  = -21;
        assign matrix_A[1][5]  = -23;
        assign matrix_A[1][6]  = -28;
        assign matrix_A[1][7]  = -26;
        assign matrix_A[2][0]  = -4;
        assign matrix_A[2][1]  = -5;
        assign matrix_A[2][2]  = -10;
        assign matrix_A[2][3]  = -15;
        assign matrix_A[2][4]  = -23;
        assign matrix_A[2][5]  = -9;
        assign matrix_A[2][6]  = -28;
        assign matrix_A[2][7]  = -36;
        assign matrix_A[3][0]  = -5;
        assign matrix_A[3][1]  = -8;
        assign matrix_A[3][2]  = -13;
        assign matrix_A[3][3]  = -17;
        assign matrix_A[3][4]  = -21;
        assign matrix_A[3][5]  = -27;
        assign matrix_A[3][6]  = -30;
        assign matrix_A[3][7]  = -33;
        assign matrix_A[4][0]  = -2;
        assign matrix_A[4][1]  = -4;
        assign matrix_A[4][2]  = -8;
        assign matrix_A[4][3]  = -13;
        assign matrix_A[4][4]  = -9;
        assign matrix_A[4][5]  = -10;
        assign matrix_A[4][6]  = -11;
        assign matrix_A[4][7]  = -17;
        assign matrix_A[5][0]  = -2;
        assign matrix_A[5][1]  = -3;
        assign matrix_A[5][2]  = -15;
        assign matrix_A[5][3]  = -8;
        assign matrix_A[5][4]  = -14;
        assign matrix_A[5][5]  = -39;
        assign matrix_A[5][6]  = -10;
        assign matrix_A[5][7]  = -27;
        assign matrix_A[6][0]  = -3;
        assign matrix_A[6][1]  = -3;
        assign matrix_A[6][2]  = -9;
        assign matrix_A[6][3]  = -16;
        assign matrix_A[6][4]  = -22;
        assign matrix_A[6][5]  = -21;
        assign matrix_A[6][6]  = -29;
        assign matrix_A[6][7]  = -38;
        assign matrix_A[7][0]  = -2;
        assign matrix_A[7][1]  = -6;
        assign matrix_A[7][2]  = -3;
        assign matrix_A[7][3]  = -4;
        assign matrix_A[7][4]  = -16;
        assign matrix_A[7][5]  = -21;
        assign matrix_A[7][6]  = -34;
        assign matrix_A[7][7]  = -20;
        assign matrix_A[8][0]  = -3;
        assign matrix_A[8][1]  = -8;
        assign matrix_A[8][2]  = -11;
        assign matrix_A[8][3]  = -11;
        assign matrix_A[8][4]  = -25;
        assign matrix_A[8][5]  = -27;
        assign matrix_A[8][6]  = -37;
        assign matrix_A[8][7]  = -24;
        assign matrix_A[9][0]  = -4;
        assign matrix_A[9][1]  = -8;
        assign matrix_A[9][2]  = -12;
        assign matrix_A[9][3]  = -43;
        assign matrix_A[9][4]  = -18;
        assign matrix_A[9][5]  = -6;
        assign matrix_A[9][6]  = -21;
        assign matrix_A[9][7]  = -44;
        assign matrix_A[10][0] = -3;
        assign matrix_A[10][1] = -14;
        assign matrix_A[10][2] = -12;
        assign matrix_A[10][3] = -25;
        assign matrix_A[10][4] = -35;
        assign matrix_A[10][5] = -28;
        assign matrix_A[10][6] = -59;
        assign matrix_A[10][7] = -29;
        assign matrix_A[11][0] = -2;
        assign matrix_A[11][1] = -7;
        assign matrix_A[11][2] = -12;
        assign matrix_A[11][3] = -9;
        assign matrix_A[11][4] = -16;
        assign matrix_A[11][5] = -38;
        assign matrix_A[11][6] = -18;
        assign matrix_A[11][7] = -22;
        assign matrix_A[12][0] = -4;
        assign matrix_A[12][1] = -8;
        assign matrix_A[12][2] = -12;
        assign matrix_A[12][3] = -16;
        assign matrix_A[12][4] = -20;
        assign matrix_A[12][5] = -25;
        assign matrix_A[12][6] = -28;
        assign matrix_A[12][7] = -32;
        assign matrix_A[13][0] = -3;
        assign matrix_A[13][1] = -8;
        assign matrix_A[13][2] = -15;
        assign matrix_A[13][3] = -19;
        assign matrix_A[13][4] = -38;
        assign matrix_A[13][5] = -10;
        assign matrix_A[13][6] = -51;
        assign matrix_A[13][7] = -77;
        assign matrix_A[14][0] = -5;
        assign matrix_A[14][1] = -11;
        assign matrix_A[14][2] = -12;
        assign matrix_A[14][3] = -20;
        assign matrix_A[14][4] = -32;
        assign matrix_A[14][5] = -17;
        assign matrix_A[14][6] = -27;
        assign matrix_A[14][7] = -57;
        assign matrix_A[15][0] = -4;
        assign matrix_A[15][1] = -8;
        assign matrix_A[15][2] = -12;
        assign matrix_A[15][3] = -13;
        assign matrix_A[15][4] = -20;
        assign matrix_A[15][5] = -31;
        assign matrix_A[15][6] = -24;
        assign matrix_A[15][7] = -33;
        assign matrix_A[16][0] = -4;
        assign matrix_A[16][1] = -15;
        assign matrix_A[16][2] = -5;
        assign matrix_A[16][3] = -27;
        assign matrix_A[16][4] = -48;
        assign matrix_A[16][5] = -8;
        assign matrix_A[16][6] = -92;
        assign matrix_A[16][7] = -17;
        assign matrix_A[17][0] = -3;
        assign matrix_A[17][1] = -7;
        assign matrix_A[17][2] = -12;
        assign matrix_A[17][3] = -11;
        assign matrix_A[17][4] = -14;
        assign matrix_A[17][5] = -20;
        assign matrix_A[17][6] = -40;
        assign matrix_A[17][7] = -25;
        assign matrix_A[18][0] = -4;
        assign matrix_A[18][1] = -8;
        assign matrix_A[18][2] = -12;
        assign matrix_A[18][3] = -16;
        assign matrix_A[18][4] = -20;
        assign matrix_A[18][5] = -24;
        assign matrix_A[18][6] = -27;
        assign matrix_A[18][7] = -31;
        assign matrix_A[19][0] = -4;
        assign matrix_A[19][1] = -12;
        assign matrix_A[19][2] = -21;
        assign matrix_A[19][3] = -19;
        assign matrix_A[19][4] = -51;
        assign matrix_A[19][5] = -21;
        assign matrix_A[19][6] = -54;
        assign matrix_A[19][7] = -67;
        assign matrix_A[20][0] = -4;
        assign matrix_A[20][1] = -7;
        assign matrix_A[20][2] = -10;
        assign matrix_A[20][3] = -16;
        assign matrix_A[20][4] = -13;
        assign matrix_A[20][5] = -27;
        assign matrix_A[20][6] = -19;
        assign matrix_A[20][7] = -17;
        assign matrix_A[21][0] = -5;
        assign matrix_A[21][1] = -8;
        assign matrix_A[21][2] = -12;
        assign matrix_A[21][3] = -17;
        assign matrix_A[21][4] = -18;
        assign matrix_A[21][5] = -23;
        assign matrix_A[21][6] = -29;
        assign matrix_A[21][7] = -29;
        assign matrix_A[22][0] = -4;
        assign matrix_A[22][1] = -6;
        assign matrix_A[22][2] = -19;
        assign matrix_A[22][3] = -32;
        assign matrix_A[22][4] = -11;
        assign matrix_A[22][5] = -13;
        assign matrix_A[22][6] = -10;
        assign matrix_A[22][7] = -15;
        assign matrix_A[23][0] = -4;
        assign matrix_A[23][1] = -8;
        assign matrix_A[23][2] = -12;
        assign matrix_A[23][3] = -16;
        assign matrix_A[23][4] = -20;
        assign matrix_A[23][5] = -24;
        assign matrix_A[23][6] = -28;
        assign matrix_A[23][7] = -32;
        assign matrix_A[24][0] = -4;
        assign matrix_A[24][1] = -10;
        assign matrix_A[24][2] = -12;
        assign matrix_A[24][3] = -37;
        assign matrix_A[24][4] = -18;
        assign matrix_A[24][5] = -15;
        assign matrix_A[24][6] = -21;
        assign matrix_A[24][7] = -25;
        assign matrix_A[25][0] = -4;
        assign matrix_A[25][1] = -8;
        assign matrix_A[25][2] = -12;
        assign matrix_A[25][3] = -16;
        assign matrix_A[25][4] = -20;
        assign matrix_A[25][5] = -25;
        assign matrix_A[25][6] = -28;
        assign matrix_A[25][7] = -32;
        assign matrix_A[26][0] = -4;
        assign matrix_A[26][1] = -9;
        assign matrix_A[26][2] = -12;
        assign matrix_A[26][3] = -16;
        assign matrix_A[26][4] = -20;
        assign matrix_A[26][5] = -24;
        assign matrix_A[26][6] = -28;
        assign matrix_A[26][7] = -32;
        assign matrix_A[27][0] = -3;
        assign matrix_A[27][1] = -8;
        assign matrix_A[27][2] = -6;
        assign matrix_A[27][3] = -15;
        assign matrix_A[27][4] = -11;
        assign matrix_A[27][5] = -15;
        assign matrix_A[27][6] = -15;
        assign matrix_A[27][7] = -14;
        assign matrix_A[28][0] = -4;
        assign matrix_A[28][1] = -5;
        assign matrix_A[28][2] = -8;
        assign matrix_A[28][3] = -9;
        assign matrix_A[28][4] = -10;
        assign matrix_A[28][5] = -11;
        assign matrix_A[28][6] = -11;
        assign matrix_A[28][7] = -15;
        assign matrix_A[29][0] = -8;
        assign matrix_A[29][1] = -10;
        assign matrix_A[29][2] = -8;
        assign matrix_A[29][3] = -15;
        assign matrix_A[29][4] = -7;
        assign matrix_A[29][5] = -27;
        assign matrix_A[29][6] = -13;
        assign matrix_A[29][7] = -12;
        assign matrix_A[30][0] = -2;
        assign matrix_A[30][1] = -12;
        assign matrix_A[30][2] = -5;
        assign matrix_A[30][3] = -10;
        assign matrix_A[30][4] = -14;
        assign matrix_A[30][5] = -11;
        assign matrix_A[30][6] = -29;
        assign matrix_A[30][7] = -16;
        assign matrix_A[31][0] = -3;
        assign matrix_A[31][1] = -5;
        assign matrix_A[31][2] = -13;
        assign matrix_A[31][3] = -12;
        assign matrix_A[31][4] = -19;
        assign matrix_A[31][5] = -22;
        assign matrix_A[31][6] = -24;
        assign matrix_A[31][7] = -30;
        assign matrix_A[32][0] = -4;
        assign matrix_A[32][1] = -6;
        assign matrix_A[32][2] = -15;
        assign matrix_A[32][3] = -18;
        assign matrix_A[32][4] = -18;
        assign matrix_A[32][5] = -34;
        assign matrix_A[32][6] = -27;
        assign matrix_A[32][7] = -30;
        assign matrix_A[33][0] = -3;
        assign matrix_A[33][1] = -8;
        assign matrix_A[33][2] = -6;
        assign matrix_A[33][3] = -5;
        assign matrix_A[33][4] = -9;
        assign matrix_A[33][5] = -27;
        assign matrix_A[33][6] = -10;
        assign matrix_A[33][7] = -15;
        assign matrix_A[34][0] = -4;
        assign matrix_A[34][1] = -8;
        assign matrix_A[34][2] = -12;
        assign matrix_A[34][3] = -16;
        assign matrix_A[34][4] = -20;
        assign matrix_A[34][5] = -23;
        assign matrix_A[34][6] = -28;
        assign matrix_A[34][7] = -32;
        assign matrix_A[35][0] = -4;
        assign matrix_A[35][1] = -8;
        assign matrix_A[35][2] = -12;
        assign matrix_A[35][3] = -16;
        assign matrix_A[35][4] = -20;
        assign matrix_A[35][5] = -24;
        assign matrix_A[35][6] = -28;
        assign matrix_A[35][7] = -31;
        assign matrix_A[36][0] = -4;
        assign matrix_A[36][1] = -8;
        assign matrix_A[36][2] = -10;
        assign matrix_A[36][3] = -23;
        assign matrix_A[36][4] = -15;
        assign matrix_A[36][5] = -22;
        assign matrix_A[36][6] = -20;
        assign matrix_A[36][7] = -22;
        assign matrix_A[37][0] = -2;
        assign matrix_A[37][1] = -6;
        assign matrix_A[37][2] = -6;
        assign matrix_A[37][3] = -8;
        assign matrix_A[37][4] = -15;
        assign matrix_A[37][5] = -44;
        assign matrix_A[37][6] = -12;
        assign matrix_A[37][7] = -30;
        assign matrix_A[38][0] = -2;
        assign matrix_A[38][1] = -15;
        assign matrix_A[38][2] = -5;
        assign matrix_A[38][3] = -5;
        assign matrix_A[38][4] = -18;
        assign matrix_A[38][5] = -26;
        assign matrix_A[38][6] = -30;
        assign matrix_A[38][7] = -26;
        assign matrix_A[39][0] = -3;
        assign matrix_A[39][1] = -6;
        assign matrix_A[39][2] = -7;
        assign matrix_A[39][3] = -32;
        assign matrix_A[39][4] = -7;
        assign matrix_A[39][5] = -21;
        assign matrix_A[39][6] = -16;
        assign matrix_A[39][7] = -7;
    end

endgenerate

endmodule