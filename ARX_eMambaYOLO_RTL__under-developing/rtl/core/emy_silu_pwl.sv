`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: emy_silu_pwl
// Description: SiLU, 8-chord piecewise linear = U_eMamba new_U_SiLU_piecewise.sv (v002 golden, SW.SILU_MODE =
//              'chord8'), as one 256-entry table per lane. Same breakpoints / slopes / intercepts / NUM_FRAC_COEF = 10;
//              the input is 8 bits, so the table holds every value the chord arithmetic produces, exactly:
//
//   x = dIn * 2^-NUM_SCALE_DIN,  y = dOut * 2^-NUM_SCALE_DOUT
//   chord k (VALUE_IF_{k-1} <= dIn < VALUE_IF_k, k = 1..8):
//       acc  = dIn * VALUE_MULT_k + VALUE_ADD_k                 scale 2^-(NUM_SCALE_DIN + NUM_FRAC_COEF)
//       dOut = sat8( rshr( acc, NUM_SCALE_DIN + NUM_FRAC_COEF - NUM_SCALE_DOUT ) )    round half up
//   x < -67 -> 0,   x >= 65 -> y = x
//   VALUE_IF / MULT / ADD = real constant * 2^n, rounded to the nearest integer (ties away from zero, the Verilog
//   real -> integer conversion) = layers_int8_emamba.py _silu_chord8_int.
//
//   The table is built at elaboration by a constant function (no file, no parameter besides the two shifts); a lane
//   is a 256:1 lookup of constants (synthesis: a LUT ROM of about 20 LUTs per lane, same size as a SiLU_LUT), instead of
//   the comparator tree + multiply + adder + requant of the arithmetic form.
//   Exhaustively checked (all 256 inputs) against the SiLU table of the INT8 reference model.
//////////////////////////////////////////////////////////////////////////////////

module emy_silu_pwl import emy_pkg::*; #(
    parameter integer NUM_DIM        = 16,
    parameter integer NUM_SCALE_DIN  = 2,   // 2^N
    parameter integer NUM_SCALE_DOUT = 2
)(
    input  logic signed [ACT_W-1:0] dIn  [0:NUM_DIM-1],
    output logic signed [ACT_W-1:0] dOut [0:NUM_DIM-1]
);

// ---------- Parameters ---------- //
localparam integer NUM_FRAC_COEF = 10;   // fixed by the golden (SILU8_FRAC)
localparam integer NUM_RSH_DOUT  = NUM_SCALE_DIN + NUM_FRAC_COEF - NUM_SCALE_DOUT;

localparam real VALUE_SCALE_DIN  = 2.0 ** NUM_SCALE_DIN;
localparam real VALUE_SCALE_COEF = 2.0 ** NUM_FRAC_COEF;
localparam real VALUE_SCALE_ADD  = VALUE_SCALE_DIN * VALUE_SCALE_COEF;

// breakpoints (real x), 9 points = 8 chords
localparam longint VALUE_IF_0 = longint'(VALUE_SCALE_DIN * (-67.0000000000));
localparam longint VALUE_IF_1 = longint'(VALUE_SCALE_DIN * (-7.3035426126));
localparam longint VALUE_IF_2 = longint'(VALUE_SCALE_DIN * (-1.2789800478));
localparam longint VALUE_IF_3 = longint'(VALUE_SCALE_DIN * (-0.6064497860));
localparam longint VALUE_IF_4 = longint'(VALUE_SCALE_DIN * (-0.0151520949));
localparam longint VALUE_IF_5 = longint'(VALUE_SCALE_DIN * (0.5900190033));
localparam longint VALUE_IF_6 = longint'(VALUE_SCALE_DIN * (1.2779256937));
localparam longint VALUE_IF_7 = longint'(VALUE_SCALE_DIN * (7.2667450610));
localparam longint VALUE_IF_8 = longint'(VALUE_SCALE_DIN * (65.0000000000));

// chord slopes, NUM_FRAC_COEF fraction bits
localparam longint VALUE_MULT_1 = longint'(VALUE_SCALE_COEF * (-0.0000823009));
localparam longint VALUE_MULT_2 = longint'(VALUE_SCALE_COEF * (-0.0454060257));
localparam longint VALUE_MULT_3 = longint'(VALUE_SCALE_COEF * (0.0958572427));
localparam longint VALUE_MULT_4 = longint'(VALUE_SCALE_COEF * (0.3491962988));
localparam longint VALUE_MULT_5 = longint'(VALUE_SCALE_COEF * (0.6396850210));
localparam longint VALUE_MULT_6 = longint'(VALUE_SCALE_COEF * (0.9010828890));
localparam longint VALUE_MULT_7 = longint'(VALUE_SCALE_COEF * (1.0456505825));
localparam longint VALUE_MULT_8 = longint'(VALUE_SCALE_COEF * (1.0000878422));

// chord intercepts, NUM_SCALE_DIN + NUM_FRAC_COEF fraction bits
localparam longint VALUE_ADD_1 = longint'(VALUE_SCALE_ADD * (-0.0055141593));
localparam longint VALUE_ADD_2 = longint'(VALUE_SCALE_ADD * (-0.3365379147));
localparam longint VALUE_ADD_3 = longint'(VALUE_SCALE_ADD * (-0.1558650129));
localparam longint VALUE_ADD_4 = longint'(VALUE_SCALE_ADD * (-0.0022275966));
localparam longint VALUE_ADD_5 = longint'(VALUE_SCALE_ADD * (0.0021739161));
localparam longint VALUE_ADD_6 = longint'(VALUE_SCALE_ADD * (-0.1520557934));
localparam longint VALUE_ADD_7 = longint'(VALUE_SCALE_ADD * (-0.3368025635));
localparam longint VALUE_ADD_8 = longint'(VALUE_SCALE_ADD * (-0.0057097456));

// ---------- The table: one entry per int8 input, the chord arithmetic evaluated at elaboration ---------- //
function automatic logic signed [ACT_W-1:0] silu_entry(input longint x);
    longint acc, rnd;
    if      (x < VALUE_IF_0) acc = 0;
    else if (x < VALUE_IF_1) acc = x * VALUE_MULT_1 + VALUE_ADD_1;
    else if (x < VALUE_IF_2) acc = x * VALUE_MULT_2 + VALUE_ADD_2;
    else if (x < VALUE_IF_3) acc = x * VALUE_MULT_3 + VALUE_ADD_3;
    else if (x < VALUE_IF_4) acc = x * VALUE_MULT_4 + VALUE_ADD_4;
    else if (x < VALUE_IF_5) acc = x * VALUE_MULT_5 + VALUE_ADD_5;
    else if (x < VALUE_IF_6) acc = x * VALUE_MULT_6 + VALUE_ADD_6;
    else if (x < VALUE_IF_7) acc = x * VALUE_MULT_7 + VALUE_ADD_7;
    else if (x < VALUE_IF_8) acc = x * VALUE_MULT_8 + VALUE_ADD_8;
    else                     acc = x <<< NUM_FRAC_COEF;          // y = x  (x * 2^F at scale 2^-(DIN+F))
    // = emy_requant: round-half-up right shift (shift > 0) or exact left shift, then sat8
    if (NUM_RSH_DOUT > 0) begin
        rnd = 64'sd1 <<< (NUM_RSH_DOUT - 1);
        acc = (acc + rnd) >>> NUM_RSH_DOUT;
    end else begin
        acc = acc <<< (-NUM_RSH_DOUT);
    end
    if (acc > 127)       return 8'sd127;
    else if (acc < -128) return -8'sd128;
    else                 return acc[ACT_W-1:0];
endfunction

logic signed [ACT_W-1:0] tab [0:(1 << ACT_W)-1];     // index = dIn + 128 (sign bit inverted)

genvar e, i;
generate
    for (e = 0; e < (1 << ACT_W); e = e + 1) begin : Entry
        assign tab[e] = silu_entry(longint'(e - (1 << (ACT_W - 1))));
    end
    for (i = 0; i < NUM_DIM; i = i + 1) begin : Lane
        assign dOut[i] = tab[{~dIn[i][ACT_W-1], dIn[i][ACT_W-2:0]}];
    end
endgenerate

endmodule
