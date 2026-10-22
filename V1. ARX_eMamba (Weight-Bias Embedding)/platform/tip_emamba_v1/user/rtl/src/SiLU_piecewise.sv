`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/04/2024 01:36:27 PM
// Design Name: 
// Module Name: SiLU_piecewise
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


module SiLU_piecewise #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM    = 40,
    parameter integer NUM_SCALE_DIN = 5,  // 2^N
    parameter integer NUM_SCALE_DOUT = 5
)(
    dIn,
    dOut
);

// ---------- Parameters ---------- //
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH * 2 + 1;
localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN * 2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

localparam integer VALUE_SCALE_DIN = 2 ** NUM_SCALE_DIN;
localparam integer VALUE_SCALE_DIN_SQUARE = VALUE_SCALE_DIN ** 2;

localparam integer VALUE_IF_1  = VALUE_SCALE_DIN * (-7);
localparam integer VALUE_IF_2  = VALUE_SCALE_DIN * (-6.417);
localparam integer VALUE_IF_3  = VALUE_SCALE_DIN * (-5.821);
localparam integer VALUE_IF_4  = VALUE_SCALE_DIN * (-5.205);
localparam integer VALUE_IF_5  = VALUE_SCALE_DIN * (-4.560);
localparam integer VALUE_IF_6  = VALUE_SCALE_DIN * (-3.862);
localparam integer VALUE_IF_7  = VALUE_SCALE_DIN * (-3.033);
localparam integer VALUE_IF_8  = VALUE_SCALE_DIN * (-1.547);
localparam integer VALUE_IF_9  = VALUE_SCALE_DIN * (-0.998);
localparam integer VALUE_IF_10 = VALUE_SCALE_DIN * (-0.594);
localparam integer VALUE_IF_11 = VALUE_SCALE_DIN * (-0.294);
localparam integer VALUE_IF_12 = VALUE_SCALE_DIN * (-0.093);
localparam integer VALUE_IF_13 = VALUE_SCALE_DIN * (-0.004);
localparam integer VALUE_IF_14 = VALUE_SCALE_DIN * (0.004);
localparam integer VALUE_IF_15 = VALUE_SCALE_DIN * (0.098);
localparam integer VALUE_IF_16 = VALUE_SCALE_DIN * (0.327);
localparam integer VALUE_IF_17 = VALUE_SCALE_DIN * (1.085);
localparam integer VALUE_IF_18 = VALUE_SCALE_DIN * (7.000);
// VALUE_IF_19 is else

localparam integer VALUE_MULT_1  = VALUE_SCALE_DIN * (0);
localparam integer VALUE_MULT_2  = VALUE_SCALE_DIN * (-0.007);
localparam integer VALUE_MULT_3  = VALUE_SCALE_DIN * (-0.011);
localparam integer VALUE_MULT_4  = VALUE_SCALE_DIN * (-0.018);
localparam integer VALUE_MULT_5  = VALUE_SCALE_DIN * (-0.029);
localparam integer VALUE_MULT_6  = VALUE_SCALE_DIN * (-0.046);
localparam integer VALUE_MULT_7  = VALUE_SCALE_DIN * (-0.072);
localparam integer VALUE_MULT_8  = VALUE_SCALE_DIN * (-0.089);
localparam integer VALUE_MULT_9  = VALUE_SCALE_DIN * (0.005);
localparam integer VALUE_MULT_10 = VALUE_SCALE_DIN * (0.142);
localparam integer VALUE_MULT_11 = VALUE_SCALE_DIN * (0.287);
localparam integer VALUE_MULT_12 = VALUE_SCALE_DIN * (0.406);
localparam integer VALUE_MULT_13 = VALUE_SCALE_DIN * (0.476);
localparam integer VALUE_MULT_14 = VALUE_SCALE_DIN * (0.500);
localparam integer VALUE_MULT_15 = VALUE_SCALE_DIN * (0.526);
localparam integer VALUE_MULT_16 = VALUE_SCALE_DIN * (0.605);
localparam integer VALUE_MULT_17 = VALUE_SCALE_DIN * (0.856);
localparam integer VALUE_MULT_18 = VALUE_SCALE_DIN * (1.045);

localparam integer VALUE_ADD_1  = VALUE_SCALE_DIN_SQUARE * (0);
localparam integer VALUE_ADD_2  = VALUE_SCALE_DIN_SQUARE * (-0.055);
localparam integer VALUE_ADD_3  = VALUE_SCALE_DIN_SQUARE * (-0.083);
localparam integer VALUE_ADD_4  = VALUE_SCALE_DIN_SQUARE * (-0.123);
localparam integer VALUE_ADD_5  = VALUE_SCALE_DIN_SQUARE * (-0.180);
localparam integer VALUE_ADD_6  = VALUE_SCALE_DIN_SQUARE * (-0.258);
localparam integer VALUE_ADD_7  = VALUE_SCALE_DIN_SQUARE * (-0.358);
localparam integer VALUE_ADD_8  = VALUE_SCALE_DIN_SQUARE * (-0.409);
localparam integer VALUE_ADD_9  = VALUE_SCALE_DIN_SQUARE * (-0.265);
localparam integer VALUE_ADD_10 = VALUE_SCALE_DIN_SQUARE * (-0.127);
localparam integer VALUE_ADD_11 = VALUE_SCALE_DIN_SQUARE * (-0.041);
localparam integer VALUE_ADD_12 = VALUE_SCALE_DIN_SQUARE * (-0.006);
localparam integer VALUE_ADD_13 = VALUE_SCALE_DIN_SQUARE * (0);
localparam integer VALUE_ADD_14 = VALUE_SCALE_DIN_SQUARE * (0);
localparam integer VALUE_ADD_15 = VALUE_SCALE_DIN_SQUARE * (0);
localparam integer VALUE_ADD_16 = VALUE_SCALE_DIN_SQUARE * (-0.008);
localparam integer VALUE_ADD_17 = VALUE_SCALE_DIN_SQUARE * (-0.117);
localparam integer VALUE_ADD_18 = VALUE_SCALE_DIN_SQUARE * (-0.324);

// ---------- Inputs / Outputs ---------- //
input logic signed [DATA_WIDTH-1:0] dIn [0:NUM_DIM-1]; // 1x40

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1]; // 1x40

// ---------- Internal variables ---------- //
logic signed [DATA_WIDTH_DOUT-1:0] dOut_ori [0:NUM_DIM-1]; // 1x40

logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_shifted [0:NUM_DIM-1];

genvar i;

// ---------- Submodules ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin: dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_right (
            .dIn(dOut_ori[i]),
            .dOut(dOut_shifted[i])
        );
    end

    for (i = 0; i < NUM_DIM; i = i + 1) begin: dOut_saturation
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator_dOut (
            .dIn(dOut_shifted[i]),
            .dOut(dOut[i])
        );
    end
endgenerate

// ---------- Main Code ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin: pSiLU_computation
        always @(*) begin
            if (dIn[i] < VALUE_IF_1)
                dOut_ori[i] = 0; // dIn[i] * VALUE_MULT_1 + VALUE_ADD_1
                
            else if (dIn[i] < VALUE_IF_2)
                dOut_ori[i] = dIn[i] * VALUE_MULT_2 + VALUE_ADD_2;
                
            else if (dIn[i] < VALUE_IF_3)
                dOut_ori[i] = dIn[i] * VALUE_MULT_3 + VALUE_ADD_3;
                
            else if (dIn[i] < VALUE_IF_4)
                dOut_ori[i] = dIn[i] * VALUE_MULT_4 + VALUE_ADD_4;
                
            else if (dIn[i] < VALUE_IF_5)
                dOut_ori[i] = dIn[i] * VALUE_MULT_5 + VALUE_ADD_5;
                
            else if (dIn[i] < VALUE_IF_6)
                dOut_ori[i] = dIn[i] * VALUE_MULT_6 + VALUE_ADD_6;
                
            else if (dIn[i] < VALUE_IF_7)
                dOut_ori[i] = dIn[i] * VALUE_MULT_7 + VALUE_ADD_7;
                
            else if (dIn[i] < VALUE_IF_8)
                dOut_ori[i] = dIn[i] * VALUE_MULT_8 + VALUE_ADD_8;
                
            else if (dIn[i] < VALUE_IF_9)
                dOut_ori[i] = dIn[i] * VALUE_MULT_9 + VALUE_ADD_9;
                
            else if (dIn[i] < VALUE_IF_10)
                dOut_ori[i] = dIn[i] * VALUE_MULT_10 + VALUE_ADD_10;
                
            else if (dIn[i] < VALUE_IF_11)
                dOut_ori[i] = dIn[i] * VALUE_MULT_11 + VALUE_ADD_11;
                
            else if (dIn[i] < VALUE_IF_12)
                dOut_ori[i] = dIn[i] * VALUE_MULT_12 + VALUE_ADD_12;
                
            else if (dIn[i] < VALUE_IF_13)
                dOut_ori[i] = dIn[i] * VALUE_MULT_13 + VALUE_ADD_13;
                
            else if (dIn[i] < VALUE_IF_14)
                dOut_ori[i] = dIn[i] * VALUE_MULT_14 + VALUE_ADD_14;
                
            else if (dIn[i] < VALUE_IF_15)
                dOut_ori[i] = dIn[i] * VALUE_MULT_15 + VALUE_ADD_15;
                
            else if (dIn[i] < VALUE_IF_16)
                dOut_ori[i] = dIn[i] * VALUE_MULT_16 + VALUE_ADD_16;
                
            else if (dIn[i] < VALUE_IF_17)
                dOut_ori[i] = dIn[i] * VALUE_MULT_17 + VALUE_ADD_17;
                
            else if (dIn[i] < VALUE_IF_18)
                dOut_ori[i] = dIn[i] * VALUE_MULT_18 + VALUE_ADD_18;
                
            else
                dOut_ori[i] = dIn[i] * VALUE_SCALE_DIN;
        end
    end
endgenerate

endmodule

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Refference Python Base Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// if x < -7:
//         return 0

//     elif x<-6.417:
//         return -0.007 * x -0.055

//     elif x<-5.821:
//         return -0.011 * x -0.083

//     elif x<-5.205:
//         return -0.018 * x -0.123

//     elif x<-4.560:
//         return -0.029 * x -0.180

//     elif x<-3.862:
//         return -0.046 * x -0.258

//     elif x<-3.033:
//         return -0.072 * x -0.358

//     elif x<-1.547:
//         return -0.089 * x -0.409

//     elif x<-0.998:
//         return 0.005 * x -0.265

//     elif x<-0.594:
//         return 0.142 * x -0.127

//     elif x<-0.294:
//         return 0.287 * x -0.041

//     elif x<-0.093:
//         return 0.406 * x -0.006

//     elif x<-0.004:
//         return 0.476 * x 

//     elif x<0.004:
//         return 0.500 * x 

//     elif x<0.098:
//         return 0.526 * x 

//     elif x<0.327:
//         return 0.605 * x -0.008

//     elif x<1.085:
//         return 0.856 * x -0.117

//     elif x<7.000:
//         return 1.045 * x -0.324

//     else: 
//         return x