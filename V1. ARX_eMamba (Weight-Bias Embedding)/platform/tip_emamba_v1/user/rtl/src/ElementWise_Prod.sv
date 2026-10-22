`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UW-Madison eLab, U.S. & UOU SOLAB, Korea
// Engineer: Jiyong Kim
// 
// Create Date: 09/05/2024 11:40:44 AM
// Design Name: 
// Module Name: ElementWise_Prod
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


module ElementWise_Prod #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_DIM    = 40,

    parameter integer NUM_SCALE_DIN_1 = 3,
    parameter integer NUM_SCALE_DIN_2 = 6,
    parameter integer NUM_SCALE_DOUT  = 5
)(
    dIn_1, // SSM
    dIn_2, // SiLU

    dOut
);

// ---------- Parameters ---------- //
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH * 2;
localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN_1 + NUM_SCALE_DIN_2 - NUM_SCALE_DOUT;

localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

// ---------- Inputs / Outputs ---------- //
input logic signed [DATA_WIDTH-1:0] dIn_1 [0:NUM_DIM-1]; // 1x40
input logic signed [DATA_WIDTH-1:0] dIn_2 [0:NUM_DIM-1]; // 1x40

output logic signed [DATA_WIDTH-1:0] dOut [0:NUM_DIM-1]; // 1x40

// ---------- Internal Variables ---------- //
logic signed [DATA_WIDTH_DOUT-1:0] dOut_ori [0:NUM_DIM-1]; // 1x40
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_shifted [0:NUM_DIM-1]; // 1x40

genvar i;

// ---------- Submodules ---------- //
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin: dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
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
    for (i = 0; i < NUM_DIM; i = i + 1) begin: computation
        assign dOut_ori[i] = dIn_1[i] * dIn_2[i];
    end
endgenerate

endmodule