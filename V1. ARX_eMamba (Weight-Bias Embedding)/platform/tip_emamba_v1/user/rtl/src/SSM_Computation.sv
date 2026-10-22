`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 04:25:17 PM
// Design Name: 
// Module Name: SSM_Computation
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


module SSM_Computation #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_SEQLEN = 16, // L
    parameter integer NUM_DIM_1  = 40, // ED
    parameter integer NUM_DIM_2  = 8,  // N

    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_C       = 5,
    parameter integer NUM_SCALE_D       = 6,
    parameter integer NUM_SCALE_DOUT    = 3,

    // 0: 1st MAMBA, 1: 2nd MAMBA
    parameter integer LAYER_ID = 0,
    parameter integer DEBUG_SWITCH = 0
)(
    clk,
    nRst,

    ps_start,

    dIn,
    dOut,

    delta_A,
    delta_B,
    matrix_C,

    prev_layer_ready,
    next_layer_ready,
    layer_ready,
    dOut_ready
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam INIT         = 'd0,
           IDLE         = 'd1,
           COMPUTING    = 'd2,
           WAIT         = 'd3;

localparam integer DATA_WIDTH_BU = DATA_WIDTH * 2; // 16-bit: delta_B(8-bit) * dIn(8-bit)
localparam integer DATA_WIDTH_BU_LSH = DATA_WIDTH_BU + NUM_SCALE_DELTA_A; // Bu(16-bit) <<< delta_A scale
localparam integer DATA_WIDTH_AX = DATA_WIDTH_BU_LSH; // Fit to BU_LSH for addition
localparam integer DATA_WIDTH_XKP1 = DATA_WIDTH_AX + 1;
localparam integer DATA_WIDTH_XKP1_RSH = DATA_WIDTH_XKP1 - NUM_SCALE_DELTA_A;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;

input ps_start;

input   logic signed [DATA_WIDTH-1:0] dIn   [0:NUM_DIM_1-1];
output  logic signed [DATA_WIDTH-1:0] dOut  [0:NUM_DIM_1-1];

input logic signed [DATA_WIDTH-1:0] delta_A     [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
input logic signed [DATA_WIDTH-1:0] delta_B     [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
input logic signed [DATA_WIDTH-1:0] matrix_C    [0:NUM_DIM_2-1];

input   prev_layer_ready, next_layer_ready;
output  layer_ready, dOut_ready;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic signed [DATA_WIDTH-1:0] matrix_D [0:NUM_DIM_1-1];

logic [2:0] curr_state,
            next_state;

logic [3:0] curr_dIn_row,
            next_dIn_row;

logic [5:0] curr_dIn_column,
            next_dIn_column;

logic [5:0] curr_dIn_column_FF;

logic signed [DATA_WIDTH-1:0] xP1_compute_dIn;
logic signed [DATA_WIDTH-1:0] xP1_compute_delta_A [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] xP1_compute_delta_B [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH_XKP1-1:0] xkP1_compute_dOut [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH_XKP1_RSH-1:0] xkP1_right_shifted [0:NUM_DIM_2-1];

logic signed [DATA_WIDTH-1:0] output_compute_dIn;
logic signed [DATA_WIDTH-1:0] output_compute_D;
logic signed [DATA_WIDTH_XKP1-1:0] output_compute_xkP1 [0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] output_y;

logic signed [DATA_WIDTH_XKP1_RSH-1:0] prev_xP1_status [0:NUM_DIM_1-1][0:NUM_DIM_2-1];

logic signed [DATA_WIDTH-1:0] dIn_mem [0:NUM_DIM_1-1];
logic signed [DATA_WIDTH-1:0] delta_A_mem [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] delta_B_mem [0:NUM_DIM_1-1][0:NUM_DIM_2-1];
logic signed [DATA_WIDTH-1:0] matrix_C_mem [0:NUM_DIM_2-1];

integer i;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
SSM_xkP1_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(NUM_SCALE_DELTA_B),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .DATA_WIDTH_BU(DATA_WIDTH_BU),
    .DATA_WIDTH_BU_LSH(DATA_WIDTH_BU_LSH),
    .DATA_WIDTH_AX(DATA_WIDTH_AX),
    .DATA_WIDTH_XKP1(DATA_WIDTH_XKP1),
    .DATA_WIDTH_XKP1_RSH(DATA_WIDTH_XKP1_RSH)
) SSM_xkP1_compute (
    .dIn(xP1_compute_dIn),
    .delta_A(xP1_compute_delta_A),
    .delta_B(xP1_compute_delta_B),
    .xk(prev_xP1_status[curr_dIn_column]),

    .xkP1(xkP1_compute_dOut),
    .xkP1_right_shifted(xkP1_right_shifted)
);

SSM_y_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_DIM_2),

    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DELTA_A(NUM_SCALE_DELTA_A),
    .NUM_SCALE_DELTA_B(NUM_SCALE_DELTA_B),
    .NUM_SCALE_C(NUM_SCALE_C),
    .NUM_SCALE_D(NUM_SCALE_D),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT),

    .DATA_WIDTH_XKP1(DATA_WIDTH_XKP1)
) SSM_y_compute (
    .dIn(output_compute_dIn),
    .matrix_C(matrix_C_mem),
    .matrix_D(output_compute_D),
    .xkP1(output_compute_xkP1),
    
    .dOut_8bit(output_y)
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
                next_state = WAIT;
            else
                next_state = curr_state;
        end

        WAIT: next_state = IDLE;

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

//  data
always @(*) begin
    xP1_compute_dIn     = dIn_mem[curr_dIn_column];
    xP1_compute_delta_A = delta_A_mem[curr_dIn_column];
    xP1_compute_delta_B = delta_B_mem[curr_dIn_column];
    
    output_compute_dIn  = dIn_mem[curr_dIn_column_FF];
    output_compute_D    = matrix_D[curr_dIn_column_FF];
end

always @(posedge clk) begin
    if (!nRst)
        for (i = 0; i < NUM_DIM_2; i = i + 1)
            output_compute_xkP1[i] <= #1 'd0;
    else
        output_compute_xkP1 <= #1 xkP1_compute_dOut;
end

// Previous x+1 status vector update
always @(posedge clk) begin
    if (!nRst || ps_start)
        for (int i = 0; i < NUM_DIM_1; i++)
            for (int j = 0; j < NUM_DIM_2; j++)
                prev_xP1_status[i][j] <= #1 'd0;
    else
        case (curr_state)
            IDLE: begin
                if (curr_dIn_row == 0)
                    for (int i = 0; i < NUM_DIM_1; i++)
                        for (int j = 0; j < NUM_DIM_2; j++)
                            prev_xP1_status[i][j] <= #1 'd0;
                else
                    prev_xP1_status <= #1 prev_xP1_status;
            end
            
            COMPUTING : prev_xP1_status[curr_dIn_column] <= #1 xkP1_right_shifted;

            default: prev_xP1_status <= #1 prev_xP1_status;
        endcase
end

// Final output
always @(posedge clk) begin
    if (!nRst)
        for (i = 0; i < NUM_DIM_1; i = i + 1)
            dOut[i] <= #1 'd0;
    else
        if (curr_state == COMPUTING || curr_state == WAIT)
            dOut[curr_dIn_column_FF] <= #1 output_y;
        else
            dOut <= #1 dOut;
end

// Input FF
always @(posedge clk) begin
    if (prev_layer_ready & next_layer_ready) begin
        dIn_mem         <= #1 dIn;
        delta_A_mem     <= #1 delta_A;
        delta_B_mem     <= #1 delta_B;
        matrix_C_mem    <= #1 matrix_C;
    end else begin
        dIn_mem <= #1 dIn_mem;
        delta_A_mem     <= #1 delta_A_mem;
        delta_B_mem     <= #1 delta_B_mem;
        matrix_C_mem    <= #1 matrix_C_mem;
    end
end

always @(posedge clk) begin
    curr_dIn_column_FF <= #1 curr_dIn_column;
end

// Ready signal
assign layer_ready = ((curr_state == INIT || curr_state == IDLE) && next_layer_ready) ? 1'b1 : 1'b0;
assign dOut_ready = ((curr_state == IDLE) && prev_layer_ready) ? 1'b1 : 1'b0;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Hard Coding
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    if (LAYER_ID == 0) begin
        assign matrix_D[0]  = 39;
        assign matrix_D[1]  = 63;
        assign matrix_D[2]  = 60;
        assign matrix_D[3]  = 83;
        assign matrix_D[4]  = 63;
        assign matrix_D[5]  = 61;
        assign matrix_D[6]  = 57;
        assign matrix_D[7]  = 65;
        assign matrix_D[8]  = 83;
        assign matrix_D[9]  = 70;
        assign matrix_D[10] = 70;
        assign matrix_D[11] = 81;
        assign matrix_D[12] = 51;
        assign matrix_D[13] = 64;
        assign matrix_D[14] = 54;
        assign matrix_D[15] = 89;
        assign matrix_D[16] = 60;
        assign matrix_D[17] = 59;
        assign matrix_D[18] = 55;
        assign matrix_D[19] = 72;
        assign matrix_D[20] = 91;
        assign matrix_D[21] = 56;
        assign matrix_D[22] = 73;
        assign matrix_D[23] = 54;
        assign matrix_D[24] = 68;
        assign matrix_D[25] = 56;
        assign matrix_D[26] = 71;
        assign matrix_D[27] = 67;
        assign matrix_D[28] = 48;
        assign matrix_D[29] = 48;
        assign matrix_D[30] = 80;
        assign matrix_D[31] = 43;
        assign matrix_D[32] = 50;
        assign matrix_D[33] = 81;
        assign matrix_D[34] = 87;
        assign matrix_D[35] = 71;
        assign matrix_D[36] = 56;
        assign matrix_D[37] = 49;
        assign matrix_D[38] = 80;
        assign matrix_D[39] = 58;
    end

    else if (LAYER_ID == 1) begin
        assign matrix_D[0]  = 107;
        assign matrix_D[1]  = 77;
        assign matrix_D[2]  = 73;
        assign matrix_D[3]  = 110;
        assign matrix_D[4]  = 48;
        assign matrix_D[5]  = 34;
        assign matrix_D[6]  = 65;
        assign matrix_D[7]  = 100;
        assign matrix_D[8]  = 65;
        assign matrix_D[9]  = 63;
        assign matrix_D[10] = 63;
        assign matrix_D[11] = 51;
        assign matrix_D[12] = 100;
        assign matrix_D[13] = 73;
        assign matrix_D[14] = 61;
        assign matrix_D[15] = 67;
        assign matrix_D[16] = 73;
        assign matrix_D[17] = 79;
        assign matrix_D[18] = 111;
        assign matrix_D[19] = 64;
        assign matrix_D[20] = 57;
        assign matrix_D[21] = 91;
        assign matrix_D[22] = 44;
        assign matrix_D[23] = 95;
        assign matrix_D[24] = 71;
        assign matrix_D[25] = 116;
        assign matrix_D[26] = 120;
        assign matrix_D[27] = 57;
        assign matrix_D[28] = 75;
        assign matrix_D[29] = 77;
        assign matrix_D[30] = 46;
        assign matrix_D[31] = 85;
        assign matrix_D[32] = 64;
        assign matrix_D[33] = 49;
        assign matrix_D[34] = 81;
        assign matrix_D[35] = 110;
        assign matrix_D[36] = 69;
        assign matrix_D[37] = 68;
        assign matrix_D[38] = 68;
        assign matrix_D[39] = 84;
    end

endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Print Result Logs
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// integer index_SSM_y = 0;
// integer file_SSM_y;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_SSM_y = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_y.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_SSM_y = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_y.txt", "w");

//     if (file_SSM_y == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_SSM_y);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_SSM_y < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_SSM_y = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_y.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_SSM_y = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_y.txt", "a");

//             if (file_SSM_y == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_SSM_y, "%0d,", dOut[i]);
//                 else
//                     $fwrite(file_SSM_y, "%0d\n", dOut[i]);
//             end
//             index_SSM_y = index_SSM_y + 1;

//         $fclose(file_SSM_y);
//         end
//     end
// end

// // SSM dIn
// integer index_SSM_dIn = 0;
// integer file_dIn;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_dIn = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_dIn.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_dIn = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_dIn.txt", "w");

//     if (file_dIn == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_dIn);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_SSM_dIn < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_dIn = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_dIn.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_dIn = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_dIn.txt", "a");

//             if (file_dIn == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_dIn, "%0d,", dIn_mem[i]);
//                 else
//                     $fwrite(file_dIn, "%0d\n", dIn_mem[i]);
//             end
//             index_SSM_dIn = index_SSM_dIn + 1;

//         $fclose(file_dIn);
//         end
//     end
// end

// // SSM delta A
// integer index_SSM_delta_A = 0;
// integer file_delta_A;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_delta_A = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_delta_A.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_delta_A = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_delta_A.txt", "w");

//     if (file_delta_A == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_delta_A);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_SSM_delta_A < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_delta_A = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_delta_A.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_delta_A = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_delta_A.txt", "a");

//             if (file_delta_A == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 for (int j = 0; j < 8; j++) begin
//                     if (j < 7)
//                         $fwrite(file_delta_A, "%0d,", delta_A_mem[i][j]);
//                     else
//                         $fwrite(file_delta_A, "%0d\n", delta_A_mem[i][j]);
//                 end
//             end
//             index_SSM_delta_A = index_SSM_delta_A + 1;

//         $fclose(file_delta_A);
//         end
//     end
// end

// // SSM delta B
// integer index_SSM_delta_B = 0;
// integer file_delta_B;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_delta_B = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_delta_B.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_delta_B = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_delta_B.txt", "w");

//     if (file_delta_B == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_delta_B);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_SSM_delta_B < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_delta_B = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_delta_B.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_delta_B = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_delta_B.txt", "a");
            
//             if (file_delta_B == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 for (int j = 0; j < 8; j++) begin
//                     if (j < 7)
//                         $fwrite(file_delta_B, "%0d,", delta_B_mem[i][j]);
//                     else
//                         $fwrite(file_delta_B, "%0d\n", delta_B_mem[i][j]);
//                 end
//             end
//             index_SSM_delta_B = index_SSM_delta_B + 1;

//         $fclose(file_delta_B);
//         end
//     end
// end

// // SSM matrix C
// integer index_SSM_C = 0;
// integer file_SSM_C;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_SSM_C = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_C.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_SSM_C = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_C.txt", "w");

//     if (file_SSM_C == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_SSM_C);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_SSM_C < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_SSM_C = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_C.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_SSM_C = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_C.txt", "a");

//             if (file_SSM_C == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 8; i++) begin
//                 if (i < 7)
//                     $fwrite(file_SSM_C, "%0d,", matrix_C_mem[i]);
//                 else
//                     $fwrite(file_SSM_C, "%0d\n", matrix_C_mem[i]);
//             end
//             index_SSM_C = index_SSM_C + 1;

//         $fclose(file_SSM_C);
//         end
//     end
// end

// // SSM matrix D
// integer index_SSM_D = 0;
// integer file_SSM_D;
// initial begin
//     if (DEBUG_SWITCH == 1)
//         file_SSM_D = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_D.txt", "w");
//     else if (DEBUG_SWITCH == 2)
//         file_SSM_D = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_D.txt", "w");

//     if (file_SSM_D == 0) begin
//         $display("Error: Cannot open file.");
//         $finish;
//     end
//     $fclose(file_SSM_D);
// end

// always @(posedge dOut_ready) begin
//     if (DEBUG_SWITCH) begin
//         if (index_SSM_D < 16) begin
//             if (DEBUG_SWITCH == 1)
//                 file_SSM_D = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/1st_SSM_D.txt", "a");
//             else if (DEBUG_SWITCH == 2)
//                 file_SSM_D = $fopen("/home/jkim2368/vivado_workspace/Sim_results/eMamba_DAC/2nd_SSM_D.txt", "a");

//             if (file_SSM_D == 0) begin
//                 $display("Error: Cannot open file.");
//                 $finish;
//             end
//             for (int i = 0; i < 40; i++) begin
//                 if (i < 39)
//                     $fwrite(file_SSM_D, "%0d,", matrix_D[i]);
//                 else
//                     $fwrite(file_SSM_D, "%0d\n", matrix_D[i]);
//             end
//             index_SSM_D = index_SSM_D + 1;

//         $fclose(file_SSM_D);
//         end
//     end
// end

endmodule