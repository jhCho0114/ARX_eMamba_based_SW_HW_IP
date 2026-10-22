`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Requant_Lane (single-lane Requant, renamed: the vector Requant of rtl/ops has the name)
// Description: change the shift of a value and saturate to int8 -- the input stage of every
//              module step (layers_int8_emamba.SW.Requant):
//                  dOut = sat8(rshr(dIn, NUM_SHIFT)),   NUM_SHIFT = s_from - s_to
//              NUM_SHIFT > 0 : round-half-up right shift (shifter_right)
//              NUM_SHIFT < 0 : exact left shift (shifter_left)
//              NUM_SHIFT = 0 : saturate only
//              NUM_SHIFT >= DATA_WIDTH_DIN : 0 -- (x + 2^(s-1)) >> s is 0 for every x of that width
//
//   One guard bit before shifter_right: rounding can carry past the input's top bit
//   (rshr(127, 1) = 64 does not fit the 7 bits shifter_right returns for an 8-bit input).
//
//   The int8 saturation is the function sat8 below, not an instance of U_eMamba/RTL/saturator.sv.
//   Vivado xsim 2024.2 (xelab without -debug) mis-connected the output of LightNormInt (an array of
//   Requant) when a saturator #(DATA_WIDTH = W) here had the same W as the one inside the eMamba
//   SSM_y_compute: the consumer read X.  The same design elaborated with -debug typical, or with
//   no shared saturator width, was correct.  Arithmetic unchanged.
//
// Dependencies: shifter_right.sv, shifter_left.sv (U_eMamba/RTL)
//////////////////////////////////////////////////////////////////////////////////
module Requant_Lane #(
    parameter integer DATA_WIDTH_DIN = 8,
    parameter integer NUM_SHIFT      = 0
)(
    dIn,
    dOut
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic signed [DATA_WIDTH_DIN-1:0] dIn;
output logic signed [7:0]                dOut;

// int8 saturation, written here instead of instantiating U_eMamba/RTL/saturator.sv (see the header)
// (if / else in the same order as saturator.sv, so an X input behaves the same way too)
function automatic logic signed [7:0] sat8(input logic signed [63:0] x);
    if (x >= 127)       sat8 = 8'sh7f;
    else if (x <= -128) sat8 = 8'sh80;
    else                sat8 = x[7:0];
endfunction

generate
    if (NUM_SHIFT > 0 && NUM_SHIFT < DATA_WIDTH_DIN && DATA_WIDTH_DIN + 1 > 64)
        $error("Requant: DATA_WIDTH_DIN + 1 guard bit must fit the 64-bit input of sat8");
    if (NUM_SHIFT < 0 && DATA_WIDTH_DIN - NUM_SHIFT > 64)
        $error("Requant: the left-shifted value must fit the 64-bit input of sat8");
    if (NUM_SHIFT == 0 && DATA_WIDTH_DIN > 64)
        $error("Requant: DATA_WIDTH_DIN must fit the 64-bit input of sat8");
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    if (NUM_SHIFT >= DATA_WIDTH_DIN) begin: Zero
        assign dOut = '0;
    end else if (NUM_SHIFT > 0) begin: Right
        logic signed [DATA_WIDTH_DIN:0]             dIn_ext;
        logic signed [DATA_WIDTH_DIN-NUM_SHIFT:0]   dIn_rsh;

        assign dIn_ext = dIn;

        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DIN + 1),
            .NUM_SHIFT(NUM_SHIFT)
        ) shifter_right (
            .dIn(dIn_ext),
            .dOut(dIn_rsh)
        );

        assign dOut = sat8(dIn_rsh);
    end else if (NUM_SHIFT < 0) begin: Left
        logic signed [DATA_WIDTH_DIN-NUM_SHIFT-1:0] dIn_lsh;

        shifter_left #(
            .DATA_WIDTH(DATA_WIDTH_DIN),
            .NUM_SHIFT(-NUM_SHIFT)
        ) shifter_left (
            .dIn(dIn),
            .dOut(dIn_lsh)
        );

        assign dOut = sat8(dIn_lsh);
    end else begin: Pass
        assign dOut = sat8(dIn);
    end
endgenerate

endmodule
