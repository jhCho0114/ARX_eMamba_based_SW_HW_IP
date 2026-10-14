`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: new_U_Exp_piecewise_compute
// Description: exp(delta*A), 8-chord piecewise linear.  Drop-in for Exp_piecewise_compute (same ports and parameters)
//
//   Generated from the exp PWL table of the INT8 reference model  (do not edit the constants by hand)
//   Technique : recursive maximum-distance chord split, depth 3 -> 8 chords
//               (v003/EXP_new_piecewise.ipynb)
//   Range     : [-5.5, 0] = delta*A range of the whole model (10 SS2D, measured min -5.33; always <= 0).  x < -5.5 -> 0,  x > 0 -> 1.0
//
// Dependencies: shifter_right.sv, saturator.sv  (RTL/)
//////////////////////////////////////////////////////////////////////////////////

// x = dIn * 2^-NUM_SCALE_DIN (16 bit, delta * A),  y = dOut_8bit * 2^-NUM_SCALE_DOUT
//   chord k (VALUE_IF_{k-1} < dIn <= VALUE_IF_k,  chord 1 includes VALUE_IF_0):
//       acc       = VALUE_MULT_k * dIn + VALUE_ADD_k        scale 2^-(2 * NUM_SCALE_DIN)
//       dOut_8bit = saturate8( round_half_up( acc >> (2 * NUM_SCALE_DIN - NUM_SCALE_DOUT) ) )

module new_U_Exp_piecewise_compute #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_N      = 8,  // N(8)

    parameter integer NUM_SCALE_DIN  = 7,  // 2^N
    parameter integer NUM_SCALE_DOUT = 7
)(
    dIn,
    dOut_8bit
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DATA_WIDTH_DIN  = DATA_WIDTH * 2;
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_DIN * 2 + 1;

localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN * 2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;

localparam integer VALUE_SCALE_DIN = 2 ** NUM_SCALE_DIN;
localparam integer VALUE_SCALE_DIN_SQUARE = VALUE_SCALE_DIN ** 2;

// breakpoints (real x), 9 points = 8 chords
localparam integer VALUE_IF_0 = VALUE_SCALE_DIN * (-5.5000000000);
localparam integer VALUE_IF_1 = VALUE_SCALE_DIN * (-4.0461704523);
localparam integer VALUE_IF_2 = VALUE_SCALE_DIN * (-3.0643424924);
localparam integer VALUE_IF_3 = VALUE_SCALE_DIN * (-2.3111745951);
localparam integer VALUE_IF_4 = VALUE_SCALE_DIN * (-1.7088432373);
localparam integer VALUE_IF_5 = VALUE_SCALE_DIN * (-1.1830499509);
localparam integer VALUE_IF_6 = VALUE_SCALE_DIN * (-0.7355796084);
localparam integer VALUE_IF_7 = VALUE_SCALE_DIN * (-0.3453457043);
localparam integer VALUE_IF_8 = VALUE_SCALE_DIN * (0.0000000000);

// chord slopes
localparam integer VALUE_MULT_1 = VALUE_SCALE_DIN * (0.0092187223);
localparam integer VALUE_MULT_2 = VALUE_SCALE_DIN * (0.0297356625);
localparam integer VALUE_MULT_3 = VALUE_SCALE_DIN * (0.0696527311);
localparam integer VALUE_MULT_4 = VALUE_SCALE_DIN * (0.1360221466);
localparam integer VALUE_MULT_5 = VALUE_SCALE_DIN * (0.2382454323);
localparam integer VALUE_MULT_6 = VALUE_SCALE_DIN * (0.3863599806);
localparam integer VALUE_MULT_7 = VALUE_SCALE_DIN * (0.5861816322);
localparam integer VALUE_MULT_8 = VALUE_SCALE_DIN * (0.8456003228);

// chord intercepts
localparam integer VALUE_ADD_1 = VALUE_SCALE_DIN_SQUARE * (0.0547897443);
localparam integer VALUE_ADD_2 = VALUE_SCALE_DIN_SQUARE * (0.1378047813);
localparam integer VALUE_ADD_3 = VALUE_SCALE_DIN_SQUARE * (0.2601243508);
localparam integer VALUE_ADD_4 = VALUE_SCALE_DIN_SQUARE * (0.4135156578);
localparam integer VALUE_ADD_5 = VALUE_SCALE_DIN_SQUARE * (0.5881992282);
localparam integer VALUE_ADD_6 = VALUE_SCALE_DIN_SQUARE * (0.7634261373);
localparam integer VALUE_ADD_7 = VALUE_SCALE_DIN_SQUARE * (0.9104108696);
localparam integer VALUE_ADD_8 = VALUE_SCALE_DIN_SQUARE * (1.0000000000);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input logic signed [DATA_WIDTH_DIN-1:0] dIn [0:NUM_N-1];

output logic signed [DATA_WIDTH-1:0] dOut_8bit [0:NUM_N-1];

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [3:0] seg [0:NUM_N-1];   // 0: below range, 1..8: chord, 9: above range

logic signed [DATA_WIDTH_DOUT-1:0] dOut [0:NUM_N-1];
logic signed [DATA_WIDTH_DOUT_RSH-1:0] dOut_right_shifted [0:NUM_N-1];

genvar n;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
generate
    for (n = 0; n < NUM_N; n = n + 1) begin : dOut_downScaling
        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(dOut[n]),
            .dOut(dOut_right_shifted[n])
        );
    end

    for (n = 0; n < NUM_N; n = n + 1) begin : dOut_saturation
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator_dOut (
            .dIn(dOut_right_shifted[n]),
            .dOut(dOut_8bit[n])
        );
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Segment select: 3-level comparator tree (the split order of the recursion), then one multiply-add.
generate
    for (n = 0; n < NUM_N; n = n + 1) begin : pExp_computation
        always @(*) begin
            if (dIn[n] <= VALUE_IF_4) begin
                if (dIn[n] <= VALUE_IF_2)
                    seg[n] = (dIn[n] <  VALUE_IF_0) ? 4'd0 :
                             (dIn[n] <= VALUE_IF_1) ? 4'd1 : 4'd2;
                else
                    seg[n] = (dIn[n] <= VALUE_IF_3) ? 4'd3 : 4'd4;
            end else begin
                if (dIn[n] <= VALUE_IF_6)
                    seg[n] = (dIn[n] <= VALUE_IF_5) ? 4'd5 : 4'd6;
                else
                    seg[n] = (dIn[n] <= VALUE_IF_7) ? 4'd7 :
                             (dIn[n] <= VALUE_IF_8) ? 4'd8 : 4'd9;
            end
        end

        always @(*) begin
            case (seg[n])
                4'd0:    dOut[n] = '0;
                4'd1:    dOut[n] = VALUE_MULT_1 * dIn[n] + VALUE_ADD_1;
                4'd2:    dOut[n] = VALUE_MULT_2 * dIn[n] + VALUE_ADD_2;
                4'd3:    dOut[n] = VALUE_MULT_3 * dIn[n] + VALUE_ADD_3;
                4'd4:    dOut[n] = VALUE_MULT_4 * dIn[n] + VALUE_ADD_4;
                4'd5:    dOut[n] = VALUE_MULT_5 * dIn[n] + VALUE_ADD_5;
                4'd6:    dOut[n] = VALUE_MULT_6 * dIn[n] + VALUE_ADD_6;
                4'd7:    dOut[n] = VALUE_MULT_7 * dIn[n] + VALUE_ADD_7;
                4'd8:    dOut[n] = VALUE_MULT_8 * dIn[n] + VALUE_ADD_8;
                default: dOut[n] = VALUE_SCALE_DIN_SQUARE;   // exp(0) = 1.0 (saturates to 127)
            endcase
        end
    end
endgenerate

endmodule

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Reference (real domain)
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// x < -5.5000000000 : y = 0
// -5.5000000000 <= x <= -4.0461704523 : y = 0.0092187223 * x + (0.0547897443)
// -4.0461704523 <  x <= -3.0643424924 : y = 0.0297356625 * x + (0.1378047813)
// -3.0643424924 <  x <= -2.3111745951 : y = 0.0696527311 * x + (0.2601243508)
// -2.3111745951 <  x <= -1.7088432373 : y = 0.1360221466 * x + (0.4135156578)
// -1.7088432373 <  x <= -1.1830499509 : y = 0.2382454323 * x + (0.5881992282)
// -1.1830499509 <  x <= -0.7355796084 : y = 0.3863599806 * x + (0.7634261373)
// -0.7355796084 <  x <= -0.3453457043 : y = 0.5861816322 * x + (0.9104108696)
// -0.3453457043 <  x <= 0.0000000000 : y = 0.8456003228 * x + (1.0000000000)
// x > 0.0000000000 : y = 1
