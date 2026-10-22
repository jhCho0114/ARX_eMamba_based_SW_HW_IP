`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: SSM_y_compute_Pipe
// Description: SSM_y_compute of U_eMamba with the adder tree registered at every level.  Same
//              arithmetic:
//                  y = sat8(rshr(sum_n C[n] * x'[n] + (D * u << NUM_LSH_DU), NUM_RSH_DOUT))
//              The original registers the products (prod_q, Du_q) and then does the whole tree,
//              + Du, rshr and sat8 in one cycle; synthesised at N = 16 the tree became a cascade of
//              15 DSP adders (PCIN -> PCOUT) and the path had 41 logic levels (~76 MHz).
//
//   Latency, inputs to the registered sum dOut_q: Y_LAT = Y_STAGE + 2 cycles (prod_q, one register
//   per tree level, the final + Du); the original's is 1.  rshr + sat8 stay combinational to
//   dOut_8bit, which the caller registers as before.  SSM_Computation_Pipe counts the same Y_LAT.
//
// Dependencies: shifter_left.sv, shifter_right.sv, saturator.sv (U_eMamba/RTL)
//////////////////////////////////////////////////////////////////////////////////
module SSM_y_compute_Pipe #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_N      = 8,

    parameter integer NUM_SCALE_DIN     = 5,
    parameter integer NUM_SCALE_DELTA_A = 7,
    parameter integer NUM_SCALE_DELTA_B = 3,
    parameter integer NUM_SCALE_C       = 5,
    parameter integer NUM_SCALE_D       = 6,
    parameter integer NUM_SCALE_DOUT    = 3,

    parameter integer DATA_WIDTH_XKP1 = 8
)(
    clk,
    dIn,      // u
    matrix_C,
    matrix_D,
    xkP1,     // x[k+1]

    dOut_8bit // y
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer NUM_LSH_DU   = NUM_SCALE_DELTA_A + NUM_SCALE_DELTA_B + NUM_SCALE_C - NUM_SCALE_D;
localparam integer NUM_RSH_DOUT = (NUM_SCALE_DIN + NUM_SCALE_DELTA_A + NUM_SCALE_DELTA_B + NUM_SCALE_C) - NUM_SCALE_DOUT;

localparam integer DATA_WIDTH_DU     = DATA_WIDTH * 2;
localparam integer DATA_WIDTH_DU_LSH = DATA_WIDTH_DU + NUM_LSH_DU;

localparam integer N_SUM_WIDTH      = ($clog2(NUM_N) > 0) ? $clog2(NUM_N) : 1;
localparam integer DATA_WIDTH_CXKP1 = (DATA_WIDTH + DATA_WIDTH_XKP1) + N_SUM_WIDTH;

localparam integer DATA_WIDTH_DOUT     = DATA_WIDTH_CXKP1 + 1;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

localparam integer Y_STAGE = N_SUM_WIDTH;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk;
input logic signed [DATA_WIDTH-1:0]      dIn;
input logic signed [DATA_WIDTH-1:0]      matrix_C [0:NUM_N-1];
input logic signed [DATA_WIDTH-1:0]      matrix_D;
input logic signed [DATA_WIDTH_XKP1-1:0] xkP1     [0:NUM_N-1];

output logic signed [DATA_WIDTH-1:0] dOut_8bit;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// ytree[0] = prod_q; ytree[s + 1] is the registered sum of pairs of ytree[s] (an odd leaf passes)
logic signed [DATA_WIDTH_CXKP1-1:0]  ytree [0:Y_STAGE][0:NUM_N-1];
logic signed [DATA_WIDTH_DU-1:0]     du_d  [0:Y_STAGE];          // Du_q, delayed along the tree
logic signed [DATA_WIDTH_DU_LSH-1:0] Du_left_shifted;
logic signed [DATA_WIDTH_DOUT-1:0]   dOut_q;
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_right_shifted;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// products: no reset, so they can sit in the DSP's M/P register
genvar yn, ys, yk;
generate
    for (yn = 0; yn < NUM_N; yn = yn + 1) begin : Y1
        always @(posedge clk) ytree[0][yn] <= #1 matrix_C[yn] * xkP1[yn];
    end
endgenerate
always @(posedge clk) du_d[0] <= #1 matrix_D * dIn;

generate
    for (ys = 0; ys < Y_STAGE; ys = ys + 1) begin : Y2
        localparam integer N_IN = (NUM_N + (1 << ys) - 1) >> ys;
        for (yk = 0; yk < N_IN / 2; yk = yk + 1) begin : Add
            always @(posedge clk) ytree[ys+1][yk] <= #1 ytree[ys][2*yk] + ytree[ys][2*yk+1];
        end
        if (N_IN % 2 == 1) begin : Pass
            always @(posedge clk) ytree[ys+1][N_IN/2] <= #1 ytree[ys][N_IN-1];
        end
        always @(posedge clk) du_d[ys+1] <= #1 du_d[ys];
    end
endgenerate

shifter_left #(
    .DATA_WIDTH(DATA_WIDTH_DU),
    .NUM_SHIFT(NUM_LSH_DU)
) shifter_Du (
    .dIn(du_d[Y_STAGE]),
    .dOut(Du_left_shifted)
);

always @(posedge clk) dOut_q <= #1 ytree[Y_STAGE][0] + Du_left_shifted;

shifter_right #(
    .DATA_WIDTH(DATA_WIDTH_DOUT),
    .NUM_SHIFT(NUM_RSH_DOUT)
) shifter_dOut (
    .dIn(dOut_q),
    .dOut(dOut_right_shifted)
);

saturator #(
    .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
) saturator_dOut (
    .dIn(dOut_right_shifted),
    .dOut(dOut_8bit)
);

endmodule
