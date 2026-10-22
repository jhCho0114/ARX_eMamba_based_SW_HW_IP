`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/07/2024 06:00:43 PM
// Design Name: 
// Module Name: Linear_expand_dBC_BC
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


module Linear_expand_dBC_BC #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16,
    parameter integer NUM_DIM_1  = 40,
    parameter integer NUM_DIM_2  = 8,

    parameter integer NUM_SCALE_DIN    = 5,
    parameter integer NUM_SCALE_WEIGHT = 8,
    parameter integer NUM_SCALE_DOUT   = 6,

    // 0: matrix B, 1: matrix C | 1st MAMBA
    // 2: matrix B, 3: matrix C | 2nd MAMBA
    parameter integer LAYER_ID = 0
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
// 5 < log2 40 < 6
localparam DATA_WIDTH_DOUT = DATA_WIDTH*2 + 6;

localparam INIT         = 'd0,
           IDLE         = 'd1,
           COMPUTING    = 'd2;

localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN + NUM_SCALE_WEIGHT - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_8_BIT = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] dIn   [0:NUM_DIM_1-1]; // 1x40
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_DIM_2-1]; // 1x8

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] weight [0:NUM_DIM_2-1][0:NUM_DIM_1-1]; // 8x40

logic [1:0] curr_state,
            next_state;

logic [3:0] curr_dIn_row,
            next_dIn_row;

logic [5:0] curr_weight_column,
            next_weight_column;

logic signed [DATA_WIDTH-1:0] matMult_dIn    [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] matMult_weight [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH_DOUT-1:0] matMult_dOut;
logic signed [DATA_WIDTH_DOUT_8_BIT-1:0] matMult_dOut_shifted;
logic signed [DATA_WIDTH-1:0] matMult_dOut_shifted_8bit;

logic signed [DATA_WIDTH-1:0] dIn_mem [0:NUM_DIM_1-1];

integer i;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
matMult_40_wo_bias #(
    .DATA_WIDTH(DATA_WIDTH)
) matMult_40_wo_bias (
    .dIn(matMult_dIn),
    .weight(matMult_weight),

    .dOut(matMult_dOut)
);

shifter_right #(
    .DATA_WIDTH(DATA_WIDTH_DOUT),
    .NUM_SHIFT(NUM_RSH_DOUT)
) shifter_right (
    .dIn(matMult_dOut),
    .dOut(matMult_dOut_shifted)
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
            if (curr_weight_column == NUM_DIM_2-1)
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
            if (curr_weight_column < NUM_DIM_2-1) begin
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
    matMult_dIn     = dIn_mem;
    matMult_weight  = weight[curr_weight_column];
end

// Final output
always @(posedge clk) begin
    if (!nRst)
        for (i = 0; i < NUM_DIM_2; i = i + 1)
            dOut[i] <= #1 'd0;
    else
        if (curr_state == COMPUTING)
            dOut[curr_weight_column] <= #1 matMult_dOut_shifted_8bit;
        else
            dOut <= #1 dOut;
end

// Activation / Set output data width to 8 bits
always @(*) begin
    if (matMult_dOut_shifted >= 127)
        matMult_dOut_shifted_8bit = 'd127;
    else if (matMult_dOut_shifted <= -128)
        matMult_dOut_shifted_8bit = -'d128;
    else
        matMult_dOut_shifted_8bit = matMult_dOut_shifted;
end

// Input FF
always @(posedge clk) begin
    if (prev_layer_ready & next_layer_ready)
        dIn_mem <= #1 dIn;
    else
        dIn_mem <= #1 dIn_mem;
end

// Ready signal
assign layer_ready = ((curr_state != COMPUTING) && next_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = ((curr_state == IDLE) && prev_layer_ready) ? 1'b1 : 1'b0;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Hard Coding
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    if (LAYER_ID == 0) begin
        assign weight[0][0]  = -66;
        assign weight[0][1]  = -23;
        assign weight[0][2]  = 16;
        assign weight[0][3]  = 46;
        assign weight[0][4]  = 30;
        assign weight[0][5]  = -7;
        assign weight[0][6]  = 62;
        assign weight[0][7]  = 56;
        assign weight[0][8]  = 34;
        assign weight[0][9]  = 39;
        assign weight[0][10] = -12;
        assign weight[0][11] = -11;
        assign weight[0][12] = -37;
        assign weight[0][13] = -35;
        assign weight[0][14] = -34;
        assign weight[0][15] = -11;
        assign weight[0][16] = -38;
        assign weight[0][17] = -2;
        assign weight[0][18] = 3;
        assign weight[0][19] = 75;
        assign weight[0][20] = 17;
        assign weight[0][21] = -69;
        assign weight[0][22] = 17;
        assign weight[0][23] = 20;
        assign weight[0][24] = 0;
        assign weight[0][25] = 82;
        assign weight[0][26] = 20;
        assign weight[0][27] = 13;
        assign weight[0][28] = -55;
        assign weight[0][29] = 7;
        assign weight[0][30] = 22;
        assign weight[0][31] = -41;
        assign weight[0][32] = 45;
        assign weight[0][33] = -26;
        assign weight[0][34] = 12;
        assign weight[0][35] = 64;
        assign weight[0][36] = 27;
        assign weight[0][37] = 8;
        assign weight[0][38] = -67;
        assign weight[0][39] = -41;
        assign weight[1][0]  = 28;
        assign weight[1][1]  = 3;
        assign weight[1][2]  = 30;
        assign weight[1][3]  = 33;
        assign weight[1][4]  = -34;
        assign weight[1][5]  = -14;
        assign weight[1][6]  = 25;
        assign weight[1][7]  = 28;
        assign weight[1][8]  = 8;
        assign weight[1][9]  = 34;
        assign weight[1][10] = -21;
        assign weight[1][11] = 6;
        assign weight[1][12] = -4;
        assign weight[1][13] = -34;
        assign weight[1][14] = -28;
        assign weight[1][15] = 15;
        assign weight[1][16] = -1;
        assign weight[1][17] = 6;
        assign weight[1][18] = -43;
        assign weight[1][19] = 17;
        assign weight[1][20] = 13;
        assign weight[1][21] = -40;
        assign weight[1][22] = 15;
        assign weight[1][23] = 1;
        assign weight[1][24] = -46;
        assign weight[1][25] = -8;
        assign weight[1][26] = -23;
        assign weight[1][27] = 37;
        assign weight[1][28] = -37;
        assign weight[1][29] = -29;
        assign weight[1][30] = -50;
        assign weight[1][31] = -19;
        assign weight[1][32] = 4;
        assign weight[1][33] = -57;
        assign weight[1][34] = -18;
        assign weight[1][35] = 35;
        assign weight[1][36] = 15;
        assign weight[1][37] = 0;
        assign weight[1][38] = -36;
        assign weight[1][39] = -40;
        assign weight[2][0]  = -38;
        assign weight[2][1]  = 49;
        assign weight[2][2]  = 60;
        assign weight[2][3]  = -13;
        assign weight[2][4]  = 16;
        assign weight[2][5]  = 23;
        assign weight[2][6]  = 43;
        assign weight[2][7]  = 19;
        assign weight[2][8]  = 12;
        assign weight[2][9]  = 18;
        assign weight[2][10] = 37;
        assign weight[2][11] = -26;
        assign weight[2][12] = 15;
        assign weight[2][13] = 1;
        assign weight[2][14] = 58;
        assign weight[2][15] = 64;
        assign weight[2][16] = -64;
        assign weight[2][17] = -20;
        assign weight[2][18] = -14;
        assign weight[2][19] = 50;
        assign weight[2][20] = 30;
        assign weight[2][21] = -55;
        assign weight[2][22] = 7;
        assign weight[2][23] = 25;
        assign weight[2][24] = -5;
        assign weight[2][25] = 47;
        assign weight[2][26] = 9;
        assign weight[2][27] = -27;
        assign weight[2][28] = -21;
        assign weight[2][29] = 17;
        assign weight[2][30] = -8;
        assign weight[2][31] = -3;
        assign weight[2][32] = -5;
        assign weight[2][33] = -31;
        assign weight[2][34] = -11;
        assign weight[2][35] = 20;
        assign weight[2][36] = -40;
        assign weight[2][37] = 11;
        assign weight[2][38] = -78;
        assign weight[2][39] = 17;
        assign weight[3][0]  = -19;
        assign weight[3][1]  = -52;
        assign weight[3][2]  = 4;
        assign weight[3][3]  = -12;
        assign weight[3][4]  = 21;
        assign weight[3][5]  = 51;
        assign weight[3][6]  = -1;
        assign weight[3][7]  = 21;
        assign weight[3][8]  = 75;
        assign weight[3][9]  = 21;
        assign weight[3][10] = 11;
        assign weight[3][11] = -3;
        assign weight[3][12] = 29;
        assign weight[3][13] = 15;
        assign weight[3][14] = -11;
        assign weight[3][15] = -61;
        assign weight[3][16] = -20;
        assign weight[3][17] = -56;
        assign weight[3][18] = -18;
        assign weight[3][19] = -27;
        assign weight[3][20] = 30;
        assign weight[3][21] = -5;
        assign weight[3][22] = -18;
        assign weight[3][23] = -28;
        assign weight[3][24] = -53;
        assign weight[3][25] = -63;
        assign weight[3][26] = 32;
        assign weight[3][27] = 118;
        assign weight[3][28] = -7;
        assign weight[3][29] = 15;
        assign weight[3][30] = -7;
        assign weight[3][31] = 19;
        assign weight[3][32] = -41;
        assign weight[3][33] = -32;
        assign weight[3][34] = 15;
        assign weight[3][35] = -15;
        assign weight[3][36] = 26;
        assign weight[3][37] = -24;
        assign weight[3][38] = 20;
        assign weight[3][39] = -16;
        assign weight[4][0]  = 39;
        assign weight[4][1]  = -11;
        assign weight[4][2]  = -1;
        assign weight[4][3]  = 3;
        assign weight[4][4]  = 34;
        assign weight[4][5]  = -15;
        assign weight[4][6]  = -33;
        assign weight[4][7]  = -8;
        assign weight[4][8]  = 1;
        assign weight[4][9]  = -21;
        assign weight[4][10] = -10;
        assign weight[4][11] = 1;
        assign weight[4][12] = 7;
        assign weight[4][13] = 23;
        assign weight[4][14] = -43;
        assign weight[4][15] = -7;
        assign weight[4][16] = -13;
        assign weight[4][17] = -3;
        assign weight[4][18] = 2;
        assign weight[4][19] = -74;
        assign weight[4][20] = 18;
        assign weight[4][21] = 45;
        assign weight[4][22] = -26;
        assign weight[4][23] = -16;
        assign weight[4][24] = -24;
        assign weight[4][25] = -37;
        assign weight[4][26] = -44;
        assign weight[4][27] = 25;
        assign weight[4][28] = 10;
        assign weight[4][29] = -32;
        assign weight[4][30] = 11;
        assign weight[4][31] = 19;
        assign weight[4][32] = -38;
        assign weight[4][33] = 73;
        assign weight[4][34] = 7;
        assign weight[4][35] = -53;
        assign weight[4][36] = 18;
        assign weight[4][37] = 9;
        assign weight[4][38] = 63;
        assign weight[4][39] = 18;
        assign weight[5][0]  = -33;
        assign weight[5][1]  = -52;
        assign weight[5][2]  = 11;
        assign weight[5][3]  = 3;
        assign weight[5][4]  = -19;
        assign weight[5][5]  = 19;
        assign weight[5][6]  = 21;
        assign weight[5][7]  = 20;
        assign weight[5][8]  = 20;
        assign weight[5][9]  = 35;
        assign weight[5][10] = -6;
        assign weight[5][11] = -15;
        assign weight[5][12] = 12;
        assign weight[5][13] = 8;
        assign weight[5][14] = 54;
        assign weight[5][15] = 20;
        assign weight[5][16] = -11;
        assign weight[5][17] = 13;
        assign weight[5][18] = -23;
        assign weight[5][19] = -29;
        assign weight[5][20] = -15;
        assign weight[5][21] = 6;
        assign weight[5][22] = -15;
        assign weight[5][23] = 5;
        assign weight[5][24] = -38;
        assign weight[5][25] = -5;
        assign weight[5][26] = -42;
        assign weight[5][27] = -29;
        assign weight[5][28] = 20;
        assign weight[5][29] = 39;
        assign weight[5][30] = 43;
        assign weight[5][31] = 3;
        assign weight[5][32] = -46;
        assign weight[5][33] = 44;
        assign weight[5][34] = 11;
        assign weight[5][35] = -33;
        assign weight[5][36] = -15;
        assign weight[5][37] = 16;
        assign weight[5][38] = 72;
        assign weight[5][39] = 54;
        assign weight[6][0]  = 19;
        assign weight[6][1]  = 1;
        assign weight[6][2]  = 44;
        assign weight[6][3]  = 9;
        assign weight[6][4]  = 7;
        assign weight[6][5]  = 6;
        assign weight[6][6]  = 23;
        assign weight[6][7]  = -36;
        assign weight[6][8]  = -9;
        assign weight[6][9]  = 54;
        assign weight[6][10] = 41;
        assign weight[6][11] = -23;
        assign weight[6][12] = 11;
        assign weight[6][13] = -33;
        assign weight[6][14] = -5;
        assign weight[6][15] = -12;
        assign weight[6][16] = 51;
        assign weight[6][17] = 35;
        assign weight[6][18] = -1;
        assign weight[6][19] = 16;
        assign weight[6][20] = -2;
        assign weight[6][21] = -23;
        assign weight[6][22] = -6;
        assign weight[6][23] = 23;
        assign weight[6][24] = -8;
        assign weight[6][25] = 11;
        assign weight[6][26] = -15;
        assign weight[6][27] = 11;
        assign weight[6][28] = -8;
        assign weight[6][29] = -18;
        assign weight[6][30] = 19;
        assign weight[6][31] = -13;
        assign weight[6][32] = 14;
        assign weight[6][33] = -14;
        assign weight[6][34] = 20;
        assign weight[6][35] = -50;
        assign weight[6][36] = 4;
        assign weight[6][37] = 0;
        assign weight[6][38] = 12;
        assign weight[6][39] = -2;
        assign weight[7][0]  = 5;
        assign weight[7][1]  = -1;
        assign weight[7][2]  = -34;
        assign weight[7][3]  = 3;
        assign weight[7][4]  = 41;
        assign weight[7][5]  = 9;
        assign weight[7][6]  = -54;
        assign weight[7][7]  = 22;
        assign weight[7][8]  = -29;
        assign weight[7][9]  = -3;
        assign weight[7][10] = -13;
        assign weight[7][11] = 54;
        assign weight[7][12] = 33;
        assign weight[7][13] = 37;
        assign weight[7][14] = 30;
        assign weight[7][15] = 11;
        assign weight[7][16] = 45;
        assign weight[7][17] = -3;
        assign weight[7][18] = -7;
        assign weight[7][19] = 49;
        assign weight[7][20] = 1;
        assign weight[7][21] = -1;
        assign weight[7][22] = 18;
        assign weight[7][23] = 12;
        assign weight[7][24] = -4;
        assign weight[7][25] = -50;
        assign weight[7][26] = 23;
        assign weight[7][27] = -3;
        assign weight[7][28] = -35;
        assign weight[7][29] = -12;
        assign weight[7][30] = -55;
        assign weight[7][31] = 56;
        assign weight[7][32] = -27;
        assign weight[7][33] = -27;
        assign weight[7][34] = -54;
        assign weight[7][35] = -23;
        assign weight[7][36] = -26;
        assign weight[7][37] = -2;
        assign weight[7][38] = 50;
        assign weight[7][39] = -51;
    end

    else if (LAYER_ID == 1) begin
        assign weight[0][0]  = -19;
        assign weight[0][1]  = 0;
        assign weight[0][2]  = 31;
        assign weight[0][3]  = -5;
        assign weight[0][4]  = 43;
        assign weight[0][5]  = 22;
        assign weight[0][6]  = 68;
        assign weight[0][7]  = 43;
        assign weight[0][8]  = -31;
        assign weight[0][9]  = -7;
        assign weight[0][10] = -51;
        assign weight[0][11] = -23;
        assign weight[0][12] = 49;
        assign weight[0][13] = -1;
        assign weight[0][14] = -35;
        assign weight[0][15] = 69;
        assign weight[0][16] = -58;
        assign weight[0][17] = -10;
        assign weight[0][18] = -33;
        assign weight[0][19] = 49;
        assign weight[0][20] = 58;
        assign weight[0][21] = -29;
        assign weight[0][22] = 26;
        assign weight[0][23] = 2;
        assign weight[0][24] = -62;
        assign weight[0][25] = -13;
        assign weight[0][26] = 29;
        assign weight[0][27] = -43;
        assign weight[0][28] = -38;
        assign weight[0][29] = -31;
        assign weight[0][30] = -64;
        assign weight[0][31] = 34;
        assign weight[0][32] = 56;
        assign weight[0][33] = -41;
        assign weight[0][34] = 28;
        assign weight[0][35] = 31;
        assign weight[0][36] = 25;
        assign weight[0][37] = 70;
        assign weight[0][38] = 8;
        assign weight[0][39] = 19;
        assign weight[1][0]  = -12;
        assign weight[1][1]  = -33;
        assign weight[1][2]  = 14;
        assign weight[1][3]  = 25;
        assign weight[1][4]  = -45;
        assign weight[1][5]  = -39;
        assign weight[1][6]  = -29;
        assign weight[1][7]  = -8;
        assign weight[1][8]  = 62;
        assign weight[1][9]  = 60;
        assign weight[1][10] = 2;
        assign weight[1][11] = 15;
        assign weight[1][12] = 60;
        assign weight[1][13] = 34;
        assign weight[1][14] = -11;
        assign weight[1][15] = 33;
        assign weight[1][16] = -3;
        assign weight[1][17] = 16;
        assign weight[1][18] = 8;
        assign weight[1][19] = 15;
        assign weight[1][20] = 31;
        assign weight[1][21] = -56;
        assign weight[1][22] = 11;
        assign weight[1][23] = 61;
        assign weight[1][24] = -5;
        assign weight[1][25] = -28;
        assign weight[1][26] = 45;
        assign weight[1][27] = 7;
        assign weight[1][28] = 12;
        assign weight[1][29] = 37;
        assign weight[1][30] = -10;
        assign weight[1][31] = 21;
        assign weight[1][32] = -71;
        assign weight[1][33] = -12;
        assign weight[1][34] = -26;
        assign weight[1][35] = -12;
        assign weight[1][36] = -30;
        assign weight[1][37] = -30;
        assign weight[1][38] = -6;
        assign weight[1][39] = -29;
        assign weight[2][0]  = -8;
        assign weight[2][1]  = -6;
        assign weight[2][2]  = 47;
        assign weight[2][3]  = 16;
        assign weight[2][4]  = -40;
        assign weight[2][5]  = -26;
        assign weight[2][6]  = 16;
        assign weight[2][7]  = -5;
        assign weight[2][8]  = 72;
        assign weight[2][9]  = -23;
        assign weight[2][10] = -1;
        assign weight[2][11] = -6;
        assign weight[2][12] = 18;
        assign weight[2][13] = -26;
        assign weight[2][14] = 40;
        assign weight[2][15] = 108;
        assign weight[2][16] = -42;
        assign weight[2][17] = -26;
        assign weight[2][18] = 3;
        assign weight[2][19] = -14;
        assign weight[2][20] = -15;
        assign weight[2][21] = -18;
        assign weight[2][22] = -55;
        assign weight[2][23] = 42;
        assign weight[2][24] = 57;
        assign weight[2][25] = -40;
        assign weight[2][26] = -20;
        assign weight[2][27] = 11;
        assign weight[2][28] = 20;
        assign weight[2][29] = -24;
        assign weight[2][30] = 27;
        assign weight[2][31] = 36;
        assign weight[2][32] = -30;
        assign weight[2][33] = -10;
        assign weight[2][34] = -19;
        assign weight[2][35] = -28;
        assign weight[2][36] = -35;
        assign weight[2][37] = 31;
        assign weight[2][38] = 52;
        assign weight[2][39] = 11;
        assign weight[3][0]  = 55;
        assign weight[3][1]  = -58;
        assign weight[3][2]  = 1;
        assign weight[3][3]  = 8;
        assign weight[3][4]  = 35;
        assign weight[3][5]  = 42;
        assign weight[3][6]  = -29;
        assign weight[3][7]  = -16;
        assign weight[3][8]  = -19;
        assign weight[3][9]  = 27;
        assign weight[3][10] = -10;
        assign weight[3][11] = 1;
        assign weight[3][12] = 33;
        assign weight[3][13] = 18;
        assign weight[3][14] = -23;
        assign weight[3][15] = -61;
        assign weight[3][16] = 34;
        assign weight[3][17] = 34;
        assign weight[3][18] = 5;
        assign weight[3][19] = -54;
        assign weight[3][20] = 33;
        assign weight[3][21] = 36;
        assign weight[3][22] = -13;
        assign weight[3][23] = -1;
        assign weight[3][24] = 21;
        assign weight[3][25] = -15;
        assign weight[3][26] = -5;
        assign weight[3][27] = 79;
        assign weight[3][28] = -11;
        assign weight[3][29] = 12;
        assign weight[3][30] = -8;
        assign weight[3][31] = 11;
        assign weight[3][32] = -50;
        assign weight[3][33] = -23;
        assign weight[3][34] = 4;
        assign weight[3][35] = 1;
        assign weight[3][36] = 7;
        assign weight[3][37] = 15;
        assign weight[3][38] = 54;
        assign weight[3][39] = 25;
        assign weight[4][0]  = -2;
        assign weight[4][1]  = 50;
        assign weight[4][2]  = -4;
        assign weight[4][3]  = 0;
        assign weight[4][4]  = -23;
        assign weight[4][5]  = -34;
        assign weight[4][6]  = 48;
        assign weight[4][7]  = -46;
        assign weight[4][8]  = -32;
        assign weight[4][9]  = -35;
        assign weight[4][10] = 7;
        assign weight[4][11] = -52;
        assign weight[4][12] = 15;
        assign weight[4][13] = -54;
        assign weight[4][14] = -44;
        assign weight[4][15] = -63;
        assign weight[4][16] = -39;
        assign weight[4][17] = 16;
        assign weight[4][18] = 20;
        assign weight[4][19] = -18;
        assign weight[4][20] = 14;
        assign weight[4][21] = 14;
        assign weight[4][22] = 14;
        assign weight[4][23] = -31;
        assign weight[4][24] = -70;
        assign weight[4][25] = 43;
        assign weight[4][26] = 9;
        assign weight[4][27] = -10;
        assign weight[4][28] = 15;
        assign weight[4][29] = 32;
        assign weight[4][30] = 54;
        assign weight[4][31] = -65;
        assign weight[4][32] = 2;
        assign weight[4][33] = 32;
        assign weight[4][34] = 6;
        assign weight[4][35] = -6;
        assign weight[4][36] = 11;
        assign weight[4][37] = 18;
        assign weight[4][38] = -36;
        assign weight[4][39] = 42;
        assign weight[5][0]  = -8;
        assign weight[5][1]  = -41;
        assign weight[5][2]  = -9;
        assign weight[5][3]  = -8;
        assign weight[5][4]  = 26;
        assign weight[5][5]  = 23;
        assign weight[5][6]  = 43;
        assign weight[5][7]  = -5;
        assign weight[5][8]  = 21;
        assign weight[5][9]  = 8;
        assign weight[5][10] = 33;
        assign weight[5][11] = -31;
        assign weight[5][12] = -33;
        assign weight[5][13] = 18;
        assign weight[5][14] = 25;
        assign weight[5][15] = -71;
        assign weight[5][16] = 8;
        assign weight[5][17] = -12;
        assign weight[5][18] = 30;
        assign weight[5][19] = -2;
        assign weight[5][20] = -15;
        assign weight[5][21] = 19;
        assign weight[5][22] = -11;
        assign weight[5][23] = -7;
        assign weight[5][24] = -13;
        assign weight[5][25] = -20;
        assign weight[5][26] = -29;
        assign weight[5][27] = 28;
        assign weight[5][28] = -37;
        assign weight[5][29] = -6;
        assign weight[5][30] = 13;
        assign weight[5][31] = -2;
        assign weight[5][32] = -28;
        assign weight[5][33] = 50;
        assign weight[5][34] = -6;
        assign weight[5][35] = 58;
        assign weight[5][36] = -15;
        assign weight[5][37] = -23;
        assign weight[5][38] = 39;
        assign weight[5][39] = -15;
        assign weight[6][0]  = -9;
        assign weight[6][1]  = -16;
        assign weight[6][2]  = -8;
        assign weight[6][3]  = 17;
        assign weight[6][4]  = 1;
        assign weight[6][5]  = -9;
        assign weight[6][6]  = -33;
        assign weight[6][7]  = -17;
        assign weight[6][8]  = -6;
        assign weight[6][9]  = 27;
        assign weight[6][10] = 4;
        assign weight[6][11] = -5;
        assign weight[6][12] = 39;
        assign weight[6][13] = 8;
        assign weight[6][14] = -13;
        assign weight[6][15] = 36;
        assign weight[6][16] = -31;
        assign weight[6][17] = -6;
        assign weight[6][18] = -20;
        assign weight[6][19] = -14;
        assign weight[6][20] = 28;
        assign weight[6][21] = 18;
        assign weight[6][22] = 7;
        assign weight[6][23] = 15;
        assign weight[6][24] = 40;
        assign weight[6][25] = 37;
        assign weight[6][26] = 22;
        assign weight[6][27] = -12;
        assign weight[6][28] = -4;
        assign weight[6][29] = 20;
        assign weight[6][30] = -67;
        assign weight[6][31] = 13;
        assign weight[6][32] = -29;
        assign weight[6][33] = 62;
        assign weight[6][34] = -18;
        assign weight[6][35] = -14;
        assign weight[6][36] = -37;
        assign weight[6][37] = -14;
        assign weight[6][38] = 38;
        assign weight[6][39] = -19;
        assign weight[7][0]  = -29;
        assign weight[7][1]  = 37;
        assign weight[7][2]  = -43;
        assign weight[7][3]  = -19;
        assign weight[7][4]  = -10;
        assign weight[7][5]  = -5;
        assign weight[7][6]  = -30;
        assign weight[7][7]  = 39;
        assign weight[7][8]  = -16;
        assign weight[7][9]  = 67;
        assign weight[7][10] = -12;
        assign weight[7][11] = -42;
        assign weight[7][12] = 25;
        assign weight[7][13] = 80;
        assign weight[7][14] = 27;
        assign weight[7][15] = 54;
        assign weight[7][16] = -9;
        assign weight[7][17] = -6;
        assign weight[7][18] = 41;
        assign weight[7][19] = 11;
        assign weight[7][20] = -8;
        assign weight[7][21] = 13;
        assign weight[7][22] = -20;
        assign weight[7][23] = 38;
        assign weight[7][24] = 12;
        assign weight[7][25] = -19;
        assign weight[7][26] = 46;
        assign weight[7][27] = 71;
        assign weight[7][28] = -1;
        assign weight[7][29] = -23;
        assign weight[7][30] = -38;
        assign weight[7][31] = -34;
        assign weight[7][32] = -19;
        assign weight[7][33] = 20;
        assign weight[7][34] = -2;
        assign weight[7][35] = -51;
        assign weight[7][36] = 17;
        assign weight[7][37] = -4;
        assign weight[7][38] = 26;
        assign weight[7][39] = 27;
    end

    else if (LAYER_ID == 2) begin
        assign weight[0][0]  = -15;
        assign weight[0][1]  = 54;
        assign weight[0][2]  = 65;
        assign weight[0][3]  = -9;
        assign weight[0][4]  = -5;
        assign weight[0][5]  = 56;
        assign weight[0][6]  = 46;
        assign weight[0][7]  = 59;
        assign weight[0][8]  = -40;
        assign weight[0][9]  = 22;
        assign weight[0][10] = 63;
        assign weight[0][11] = 105;
        assign weight[0][12] = 22;
        assign weight[0][13] = 32;
        assign weight[0][14] = -31;
        assign weight[0][15] = 12;
        assign weight[0][16] = -57;
        assign weight[0][17] = -66;
        assign weight[0][18] = -54;
        assign weight[0][19] = 38;
        assign weight[0][20] = -20;
        assign weight[0][21] = -75;
        assign weight[0][22] = -64;
        assign weight[0][23] = 26;
        assign weight[0][24] = 42;
        assign weight[0][25] = 88;
        assign weight[0][26] = 52;
        assign weight[0][27] = -48;
        assign weight[0][28] = -67;
        assign weight[0][29] = 53;
        assign weight[0][30] = 4;
        assign weight[0][31] = 68;
        assign weight[0][32] = -17;
        assign weight[0][33] = -5;
        assign weight[0][34] = 14;
        assign weight[0][35] = 79;
        assign weight[0][36] = -2;
        assign weight[0][37] = 31;
        assign weight[0][38] = 53;
        assign weight[0][39] = 14;
        assign weight[1][0]  = 16;
        assign weight[1][1]  = -11;
        assign weight[1][2]  = 0;
        assign weight[1][3]  = -5;
        assign weight[1][4]  = 5;
        assign weight[1][5]  = -49;
        assign weight[1][6]  = -32;
        assign weight[1][7]  = -34;
        assign weight[1][8]  = -4;
        assign weight[1][9]  = -25;
        assign weight[1][10] = -40;
        assign weight[1][11] = -52;
        assign weight[1][12] = 93;
        assign weight[1][13] = -35;
        assign weight[1][14] = -32;
        assign weight[1][15] = -49;
        assign weight[1][16] = 45;
        assign weight[1][17] = 3;
        assign weight[1][18] = -29;
        assign weight[1][19] = -51;
        assign weight[1][20] = -22;
        assign weight[1][21] = 36;
        assign weight[1][22] = 22;
        assign weight[1][23] = -33;
        assign weight[1][24] = 15;
        assign weight[1][25] = -65;
        assign weight[1][26] = -30;
        assign weight[1][27] = 56;
        assign weight[1][28] = -20;
        assign weight[1][29] = 13;
        assign weight[1][30] = -36;
        assign weight[1][31] = -12;
        assign weight[1][32] = -13;
        assign weight[1][33] = 33;
        assign weight[1][34] = 5;
        assign weight[1][35] = -43;
        assign weight[1][36] = 8;
        assign weight[1][37] = 58;
        assign weight[1][38] = -60;
        assign weight[1][39] = 39;
        assign weight[2][0]  = -2;
        assign weight[2][1]  = -40;
        assign weight[2][2]  = 1;
        assign weight[2][3]  = 26;
        assign weight[2][4]  = 2;
        assign weight[2][5]  = 8;
        assign weight[2][6]  = -40;
        assign weight[2][7]  = 15;
        assign weight[2][8]  = 42;
        assign weight[2][9]  = -43;
        assign weight[2][10] = -10;
        assign weight[2][11] = -26;
        assign weight[2][12] = 17;
        assign weight[2][13] = -34;
        assign weight[2][14] = 47;
        assign weight[2][15] = -24;
        assign weight[2][16] = 35;
        assign weight[2][17] = 23;
        assign weight[2][18] = 23;
        assign weight[2][19] = -37;
        assign weight[2][20] = 18;
        assign weight[2][21] = 20;
        assign weight[2][22] = -7;
        assign weight[2][23] = 14;
        assign weight[2][24] = -34;
        assign weight[2][25] = 9;
        assign weight[2][26] = -44;
        assign weight[2][27] = 72;
        assign weight[2][28] = 8;
        assign weight[2][29] = -1;
        assign weight[2][30] = -1;
        assign weight[2][31] = -8;
        assign weight[2][32] = 39;
        assign weight[2][33] = -37;
        assign weight[2][34] = -21;
        assign weight[2][35] = -4;
        assign weight[2][36] = -29;
        assign weight[2][37] = -8;
        assign weight[2][38] = -24;
        assign weight[2][39] = -49;
        assign weight[3][0]  = 0;
        assign weight[3][1]  = -25;
        assign weight[3][2]  = 63;
        assign weight[3][3]  = 40;
        assign weight[3][4]  = -27;
        assign weight[3][5]  = 68;
        assign weight[3][6]  = -16;
        assign weight[3][7]  = 56;
        assign weight[3][8]  = 1;
        assign weight[3][9]  = -45;
        assign weight[3][10] = 33;
        assign weight[3][11] = -35;
        assign weight[3][12] = 27;
        assign weight[3][13] = -26;
        assign weight[3][14] = 10;
        assign weight[3][15] = -74;
        assign weight[3][16] = -7;
        assign weight[3][17] = 3;
        assign weight[3][18] = -16;
        assign weight[3][19] = 19;
        assign weight[3][20] = 64;
        assign weight[3][21] = 21;
        assign weight[3][22] = 4;
        assign weight[3][23] = -10;
        assign weight[3][24] = -25;
        assign weight[3][25] = 6;
        assign weight[3][26] = -21;
        assign weight[3][27] = 10;
        assign weight[3][28] = -19;
        assign weight[3][29] = 31;
        assign weight[3][30] = -30;
        assign weight[3][31] = 17;
        assign weight[3][32] = 30;
        assign weight[3][33] = -21;
        assign weight[3][34] = -36;
        assign weight[3][35] = 3;
        assign weight[3][36] = -17;
        assign weight[3][37] = -5;
        assign weight[3][38] = -18;
        assign weight[3][39] = -29;
        assign weight[4][0]  = -10;
        assign weight[4][1]  = 3;
        assign weight[4][2]  = 35;
        assign weight[4][3]  = -10;
        assign weight[4][4]  = -30;
        assign weight[4][5]  = 72;
        assign weight[4][6]  = 2;
        assign weight[4][7]  = 38;
        assign weight[4][8]  = -10;
        assign weight[4][9]  = 7;
        assign weight[4][10] = 46;
        assign weight[4][11] = 44;
        assign weight[4][12] = -1;
        assign weight[4][13] = 33;
        assign weight[4][14] = -9;
        assign weight[4][15] = -6;
        assign weight[4][16] = -56;
        assign weight[4][17] = -18;
        assign weight[4][18] = -23;
        assign weight[4][19] = 30;
        assign weight[4][20] = -14;
        assign weight[4][21] = -56;
        assign weight[4][22] = -10;
        assign weight[4][23] = 24;
        assign weight[4][24] = 17;
        assign weight[4][25] = 22;
        assign weight[4][26] = 27;
        assign weight[4][27] = -45;
        assign weight[4][28] = -42;
        assign weight[4][29] = 50;
        assign weight[4][30] = 2;
        assign weight[4][31] = 28;
        assign weight[4][32] = 12;
        assign weight[4][33] = 4;
        assign weight[4][34] = 20;
        assign weight[4][35] = 31;
        assign weight[4][36] = -17;
        assign weight[4][37] = 22;
        assign weight[4][38] = 19;
        assign weight[4][39] = -2;
        assign weight[5][0]  = -22;
        assign weight[5][1]  = 16;
        assign weight[5][2]  = 5;
        assign weight[5][3]  = 13;
        assign weight[5][4]  = -26;
        assign weight[5][5]  = 36;
        assign weight[5][6]  = 20;
        assign weight[5][7]  = -41;
        assign weight[5][8]  = 28;
        assign weight[5][9]  = 0;
        assign weight[5][10] = -4;
        assign weight[5][11] = -13;
        assign weight[5][12] = 1;
        assign weight[5][13] = 2;
        assign weight[5][14] = 6;
        assign weight[5][15] = 27;
        assign weight[5][16] = 48;
        assign weight[5][17] = -3;
        assign weight[5][18] = 14;
        assign weight[5][19] = 6;
        assign weight[5][20] = 52;
        assign weight[5][21] = 30;
        assign weight[5][22] = 19;
        assign weight[5][23] = -29;
        assign weight[5][24] = 17;
        assign weight[5][25] = -29;
        assign weight[5][26] = -26;
        assign weight[5][27] = -39;
        assign weight[5][28] = 10;
        assign weight[5][29] = -24;
        assign weight[5][30] = 5;
        assign weight[5][31] = 35;
        assign weight[5][32] = -23;
        assign weight[5][33] = 22;
        assign weight[5][34] = -15;
        assign weight[5][35] = -2;
        assign weight[5][36] = -6;
        assign weight[5][37] = -28;
        assign weight[5][38] = 14;
        assign weight[5][39] = -92;
        assign weight[6][0]  = -15;
        assign weight[6][1]  = 11;
        assign weight[6][2]  = 0;
        assign weight[6][3]  = -1;
        assign weight[6][4]  = -39;
        assign weight[6][5]  = 69;
        assign weight[6][6]  = 3;
        assign weight[6][7]  = 10;
        assign weight[6][8]  = 12;
        assign weight[6][9]  = 25;
        assign weight[6][10] = 45;
        assign weight[6][11] = 14;
        assign weight[6][12] = 32;
        assign weight[6][13] = 10;
        assign weight[6][14] = -6;
        assign weight[6][15] = -27;
        assign weight[6][16] = -27;
        assign weight[6][17] = -49;
        assign weight[6][18] = -23;
        assign weight[6][19] = 5;
        assign weight[6][20] = 33;
        assign weight[6][21] = -44;
        assign weight[6][22] = 16;
        assign weight[6][23] = 0;
        assign weight[6][24] = -21;
        assign weight[6][25] = -2;
        assign weight[6][26] = 14;
        assign weight[6][27] = -15;
        assign weight[6][28] = -32;
        assign weight[6][29] = 61;
        assign weight[6][30] = 6;
        assign weight[6][31] = 31;
        assign weight[6][32] = 16;
        assign weight[6][33] = 16;
        assign weight[6][34] = -10;
        assign weight[6][35] = 32;
        assign weight[6][36] = 15;
        assign weight[6][37] = 9;
        assign weight[6][38] = -8;
        assign weight[6][39] = -5;
        assign weight[7][0]  = 22;
        assign weight[7][1]  = -16;
        assign weight[7][2]  = -34;
        assign weight[7][3]  = 23;
        assign weight[7][4]  = -11;
        assign weight[7][5]  = -16;
        assign weight[7][6]  = -18;
        assign weight[7][7]  = -20;
        assign weight[7][8]  = 30;
        assign weight[7][9]  = -49;
        assign weight[7][10] = -14;
        assign weight[7][11] = -31;
        assign weight[7][12] = -16;
        assign weight[7][13] = -32;
        assign weight[7][14] = 22;
        assign weight[7][15] = -50;
        assign weight[7][16] = 29;
        assign weight[7][17] = 17;
        assign weight[7][18] = 30;
        assign weight[7][19] = -35;
        assign weight[7][20] = 31;
        assign weight[7][21] = 14;
        assign weight[7][22] = 36;
        assign weight[7][23] = -8;
        assign weight[7][24] = -12;
        assign weight[7][25] = -32;
        assign weight[7][26] = -30;
        assign weight[7][27] = 8;
        assign weight[7][28] = 15;
        assign weight[7][29] = -35;
        assign weight[7][30] = -27;
        assign weight[7][31] = -42;
        assign weight[7][32] = 11;
        assign weight[7][33] = -37;
        assign weight[7][34] = 5;
        assign weight[7][35] = -11;
        assign weight[7][36] = 9;
        assign weight[7][37] = -15;
        assign weight[7][38] = -42;
        assign weight[7][39] = -19;
    end

    else if (LAYER_ID == 3) begin
        assign weight[0][0]  = 17;
        assign weight[0][1]  = 63;
        assign weight[0][2]  = -1;
        assign weight[0][3]  = -24;
        assign weight[0][4]  = 51;
        assign weight[0][5]  = 6;
        assign weight[0][6]  = 39;
        assign weight[0][7]  = 62;
        assign weight[0][8]  = 1;
        assign weight[0][9]  = 94;
        assign weight[0][10] = 60;
        assign weight[0][11] = 68;
        assign weight[0][12] = 10;
        assign weight[0][13] = 81;
        assign weight[0][14] = -71;
        assign weight[0][15] = 77;
        assign weight[0][16] = -77;
        assign weight[0][17] = -68;
        assign weight[0][18] = -46;
        assign weight[0][19] = 41;
        assign weight[0][20] = -52;
        assign weight[0][21] = -37;
        assign weight[0][22] = -39;
        assign weight[0][23] = 23;
        assign weight[0][24] = 37;
        assign weight[0][25] = -1;
        assign weight[0][26] = 65;
        assign weight[0][27] = -59;
        assign weight[0][28] = -19;
        assign weight[0][29] = 28;
        assign weight[0][30] = 70;
        assign weight[0][31] = 59;
        assign weight[0][32] = -32;
        assign weight[0][33] = 45;
        assign weight[0][34] = 12;
        assign weight[0][35] = 41;
        assign weight[0][36] = -20;
        assign weight[0][37] = 38;
        assign weight[0][38] = 4;
        assign weight[0][39] = 40;
        assign weight[1][0]  = 1;
        assign weight[1][1]  = 28;
        assign weight[1][2]  = -21;
        assign weight[1][3]  = -50;
        assign weight[1][4]  = 39;
        assign weight[1][5]  = -30;
        assign weight[1][6]  = -18;
        assign weight[1][7]  = -6;
        assign weight[1][8]  = -38;
        assign weight[1][9]  = 35;
        assign weight[1][10] = -50;
        assign weight[1][11] = -20;
        assign weight[1][12] = 58;
        assign weight[1][13] = -2;
        assign weight[1][14] = -20;
        assign weight[1][15] = 32;
        assign weight[1][16] = -7;
        assign weight[1][17] = 2;
        assign weight[1][18] = -33;
        assign weight[1][19] = 1;
        assign weight[1][20] = -42;
        assign weight[1][21] = -20;
        assign weight[1][22] = -20;
        assign weight[1][23] = 30;
        assign weight[1][24] = 6;
        assign weight[1][25] = -44;
        assign weight[1][26] = -2;
        assign weight[1][27] = 2;
        assign weight[1][28] = -7;
        assign weight[1][29] = 5;
        assign weight[1][30] = 23;
        assign weight[1][31] = -22;
        assign weight[1][32] = 11;
        assign weight[1][33] = -6;
        assign weight[1][34] = 21;
        assign weight[1][35] = -2;
        assign weight[1][36] = -12;
        assign weight[1][37] = 34;
        assign weight[1][38] = 13;
        assign weight[1][39] = 22;
        assign weight[2][0]  = 31;
        assign weight[2][1]  = 10;
        assign weight[2][2]  = 31;
        assign weight[2][3]  = 61;
        assign weight[2][4]  = 1;
        assign weight[2][5]  = 7;
        assign weight[2][6]  = 32;
        assign weight[2][7]  = 83;
        assign weight[2][8]  = -37;
        assign weight[2][9]  = 21;
        assign weight[2][10] = 12;
        assign weight[2][11] = 1;
        assign weight[2][12] = -1;
        assign weight[2][13] = 21;
        assign weight[2][14] = -39;
        assign weight[2][15] = 5;
        assign weight[2][16] = -19;
        assign weight[2][17] = 2;
        assign weight[2][18] = 4;
        assign weight[2][19] = 29;
        assign weight[2][20] = -11;
        assign weight[2][21] = -3;
        assign weight[2][22] = 26;
        assign weight[2][23] = 6;
        assign weight[2][24] = 16;
        assign weight[2][25] = 21;
        assign weight[2][26] = 36;
        assign weight[2][27] = 40;
        assign weight[2][28] = -8;
        assign weight[2][29] = 25;
        assign weight[2][30] = 40;
        assign weight[2][31] = 18;
        assign weight[2][32] = 28;
        assign weight[2][33] = -24;
        assign weight[2][34] = 3;
        assign weight[2][35] = 29;
        assign weight[2][36] = -22;
        assign weight[2][37] = -9;
        assign weight[2][38] = -12;
        assign weight[2][39] = 17;
        assign weight[3][0]  = -3;
        assign weight[3][1]  = 3;
        assign weight[3][2]  = 7;
        assign weight[3][3]  = 39;
        assign weight[3][4]  = -12;
        assign weight[3][5]  = 29;
        assign weight[3][6]  = -10;
        assign weight[3][7]  = 109;
        assign weight[3][8]  = -22;
        assign weight[3][9]  = 13;
        assign weight[3][10] = 32;
        assign weight[3][11] = -25;
        assign weight[3][12] = 52;
        assign weight[3][13] = 5;
        assign weight[3][14] = 24;
        assign weight[3][15] = -24;
        assign weight[3][16] = -52;
        assign weight[3][17] = -1;
        assign weight[3][18] = -24;
        assign weight[3][19] = 20;
        assign weight[3][20] = -16;
        assign weight[3][21] = -34;
        assign weight[3][22] = -6;
        assign weight[3][23] = 23;
        assign weight[3][24] = 11;
        assign weight[3][25] = 41;
        assign weight[3][26] = -19;
        assign weight[3][27] = 58;
        assign weight[3][28] = -28;
        assign weight[3][29] = 53;
        assign weight[3][30] = 36;
        assign weight[3][31] = 9;
        assign weight[3][32] = 15;
        assign weight[3][33] = -21;
        assign weight[3][34] = -27;
        assign weight[3][35] = 9;
        assign weight[3][36] = -13;
        assign weight[3][37] = -2;
        assign weight[3][38] = -28;
        assign weight[3][39] = 3;
        assign weight[4][0]  = 17;
        assign weight[4][1]  = -38;
        assign weight[4][2]  = -6;
        assign weight[4][3]  = -1;
        assign weight[4][4]  = -50;
        assign weight[4][5]  = 25;
        assign weight[4][6]  = -41;
        assign weight[4][7]  = 5;
        assign weight[4][8]  = 12;
        assign weight[4][9]  = -46;
        assign weight[4][10] = -23;
        assign weight[4][11] = -21;
        assign weight[4][12] = 20;
        assign weight[4][13] = -35;
        assign weight[4][14] = 75;
        assign weight[4][15] = -27;
        assign weight[4][16] = 44;
        assign weight[4][17] = 18;
        assign weight[4][18] = 16;
        assign weight[4][19] = -19;
        assign weight[4][20] = 36;
        assign weight[4][21] = 19;
        assign weight[4][22] = 8;
        assign weight[4][23] = 3;
        assign weight[4][24] = -21;
        assign weight[4][25] = 3;
        assign weight[4][26] = -20;
        assign weight[4][27] = 1;
        assign weight[4][28] = 14;
        assign weight[4][29] = -27;
        assign weight[4][30] = -3;
        assign weight[4][31] = -28;
        assign weight[4][32] = 1;
        assign weight[4][33] = -11;
        assign weight[4][34] = -18;
        assign weight[4][35] = -28;
        assign weight[4][36] = 5;
        assign weight[4][37] = -48;
        assign weight[4][38] = -8;
        assign weight[4][39] = -23;
        assign weight[5][0]  = -62;
        assign weight[5][1]  = -2;
        assign weight[5][2]  = 26;
        assign weight[5][3]  = 50;
        assign weight[5][4]  = 14;
        assign weight[5][5]  = 38;
        assign weight[5][6]  = 0;
        assign weight[5][7]  = -33;
        assign weight[5][8]  = -29;
        assign weight[5][9]  = -32;
        assign weight[5][10] = 25;
        assign weight[5][11] = -15;
        assign weight[5][12] = 27;
        assign weight[5][13] = 18;
        assign weight[5][14] = 27;
        assign weight[5][15] = -8;
        assign weight[5][16] = 10;
        assign weight[5][17] = 13;
        assign weight[5][18] = -19;
        assign weight[5][19] = 17;
        assign weight[5][20] = -1;
        assign weight[5][21] = -12;
        assign weight[5][22] = -47;
        assign weight[5][23] = -33;
        assign weight[5][24] = 22;
        assign weight[5][25] = 16;
        assign weight[5][26] = -5;
        assign weight[5][27] = -19;
        assign weight[5][28] = -23;
        assign weight[5][29] = -10;
        assign weight[5][30] = -2;
        assign weight[5][31] = 28;
        assign weight[5][32] = 19;
        assign weight[5][33] = 14;
        assign weight[5][34] = -46;
        assign weight[5][35] = 38;
        assign weight[5][36] = -8;
        assign weight[5][37] = -44;
        assign weight[5][38] = -30;
        assign weight[5][39] = -18;
        assign weight[6][0]  = -46;
        assign weight[6][1]  = -33;
        assign weight[6][2]  = -12;
        assign weight[6][3]  = -17;
        assign weight[6][4]  = -11;
        assign weight[6][5]  = 47;
        assign weight[6][6]  = -1;
        assign weight[6][7]  = 2;
        assign weight[6][8]  = -12;
        assign weight[6][9]  = -31;
        assign weight[6][10] = -24;
        assign weight[6][11] = -9;
        assign weight[6][12] = 11;
        assign weight[6][13] = -29;
        assign weight[6][14] = 47;
        assign weight[6][15] = -33;
        assign weight[6][16] = -28;
        assign weight[6][17] = 11;
        assign weight[6][18] = 27;
        assign weight[6][19] = -25;
        assign weight[6][20] = 17;
        assign weight[6][21] = -20;
        assign weight[6][22] = 13;
        assign weight[6][23] = -24;
        assign weight[6][24] = -1;
        assign weight[6][25] = 11;
        assign weight[6][26] = -39;
        assign weight[6][27] = -3;
        assign weight[6][28] = 18;
        assign weight[6][29] = -12;
        assign weight[6][30] = -27;
        assign weight[6][31] = -29;
        assign weight[6][32] = 41;
        assign weight[6][33] = -42;
        assign weight[6][34] = -43;
        assign weight[6][35] = 12;
        assign weight[6][36] = 12;
        assign weight[6][37] = -34;
        assign weight[6][38] = 7;
        assign weight[6][39] = -57;
        assign weight[7][0]  = -6;
        assign weight[7][1]  = 16;
        assign weight[7][2]  = -13;
        assign weight[7][3]  = -11;
        assign weight[7][4]  = 43;
        assign weight[7][5]  = 28;
        assign weight[7][6]  = 1;
        assign weight[7][7]  = 49;
        assign weight[7][8]  = 7;
        assign weight[7][9]  = 36;
        assign weight[7][10] = 34;
        assign weight[7][11] = 18;
        assign weight[7][12] = 10;
        assign weight[7][13] = 19;
        assign weight[7][14] = -39;
        assign weight[7][15] = -1;
        assign weight[7][16] = -73;
        assign weight[7][17] = -10;
        assign weight[7][18] = -21;
        assign weight[7][19] = -14;
        assign weight[7][20] = -19;
        assign weight[7][21] = -56;
        assign weight[7][22] = -28;
        assign weight[7][23] = -11;
        assign weight[7][24] = 5;
        assign weight[7][25] = -2;
        assign weight[7][26] = 11;
        assign weight[7][27] = 0;
        assign weight[7][28] = -31;
        assign weight[7][29] = 101;
        assign weight[7][30] = 13;
        assign weight[7][31] = -5;
        assign weight[7][32] = 21;
        assign weight[7][33] = -1;
        assign weight[7][34] = 24;
        assign weight[7][35] = 22;
        assign weight[7][36] = -35;
        assign weight[7][37] = 6;
        assign weight[7][38] = 11;
        assign weight[7][39] = 18;
    end
endgenerate

endmodule