`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Exp_piecewise_compute   (file: Exp_piecewise_compute_chord8.sv)
// Description: exp(delta*A) of the v002 golden: the 8-chord PWL of U_eMamba/new_U_Exp_piecewise_compute.sv.
//              U_eMamba/RTL/Exp_piecewise_WB.sv instantiates a module named Exp_piecewise_compute; this
//              file gives it that name, so the eMamba scan core is used unchanged with the new exp.
//              Compile this file INSTEAD of U_eMamba/RTL/Exp_piecewise_compute.sv (12-segment, v001).
//
// Dependencies: new_U_Exp_piecewise_compute.sv (U_eMamba/), shifter_right.sv, saturator.sv (U_eMamba/RTL/)
//////////////////////////////////////////////////////////////////////////////////
module Exp_piecewise_compute #(
    parameter integer DATA_WIDTH     = 8,
    parameter integer NUM_N          = 8,

    parameter integer NUM_SCALE_DIN  = 7,
    parameter integer NUM_SCALE_DOUT = 7
)(
    input  logic signed [DATA_WIDTH*2-1:0] dIn [0:NUM_N-1],

    output logic signed [DATA_WIDTH-1:0] dOut_8bit [0:NUM_N-1]
);


new_U_Exp_piecewise_compute #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_N(NUM_N),
    .NUM_SCALE_DIN(NUM_SCALE_DIN),
    .NUM_SCALE_DOUT(NUM_SCALE_DOUT)
) chord8 (
    .dIn(dIn),

    .dOut_8bit(dOut_8bit)
);

endmodule
