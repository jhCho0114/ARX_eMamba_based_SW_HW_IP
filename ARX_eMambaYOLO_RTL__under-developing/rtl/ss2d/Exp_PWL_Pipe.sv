`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Exp_PWL_Pipe
// Description: new_U_Exp_piecewise_compute (U_eMamba, the v002 golden's exp: 8 chords on
//              [-5.5, 0], 0 below, 1.0 above) in two registered stages.  Same constants (copied
//              verbatim) and the same arithmetic:
//                  y = MULT_s * x + ADD_s  (segment s of x),  dOut = sat8(rshr(y, NUM_RSH_DOUT))
//              A (en1): the segment of x and its two constants, registered with x
//              B (en2): MULT * x + ADD, registered;  rshr + sat8 combinational to dOut_8bit
//              (segment 0: 0 * x + 0;  above the range: 0 * x + SCALE^2, as the original's cases).
//
// Dependencies: shifter_right.sv, saturator.sv (U_eMamba/RTL)
//////////////////////////////////////////////////////////////////////////////////
module Exp_PWL_Pipe #(
    parameter integer DATA_WIDTH = 8,
    parameter integer NUM_N      = 8,
    parameter integer NUM_SCALE_DIN  = 7,
    parameter integer NUM_SCALE_DOUT = 7
)(
    clk,
    en1,
    en2,
    dIn,
    dOut_8bit
);

// ---------- constants of new_U_Exp_piecewise_compute, verbatim ---------- //
localparam integer DATA_WIDTH_DIN  = DATA_WIDTH * 2;
localparam integer DATA_WIDTH_DOUT = DATA_WIDTH_DIN * 2 + 1;
localparam integer NUM_RSH_DOUT = NUM_SCALE_DIN * 2 - NUM_SCALE_DOUT;
localparam integer DATA_WIDTH_DOUT_RSH = DATA_WIDTH_DOUT - NUM_RSH_DOUT;
localparam integer VALUE_SCALE_DIN = 2 ** NUM_SCALE_DIN;
localparam integer VALUE_SCALE_DIN_SQUARE = VALUE_SCALE_DIN ** 2;
localparam integer VALUE_IF_0 = VALUE_SCALE_DIN * (-5.5000000000);
localparam integer VALUE_IF_1 = VALUE_SCALE_DIN * (-4.0461704523);
localparam integer VALUE_IF_2 = VALUE_SCALE_DIN * (-3.0643424924);
localparam integer VALUE_IF_3 = VALUE_SCALE_DIN * (-2.3111745951);
localparam integer VALUE_IF_4 = VALUE_SCALE_DIN * (-1.7088432373);
localparam integer VALUE_IF_5 = VALUE_SCALE_DIN * (-1.1830499509);
localparam integer VALUE_IF_6 = VALUE_SCALE_DIN * (-0.7355796084);
localparam integer VALUE_IF_7 = VALUE_SCALE_DIN * (-0.3453457043);
localparam integer VALUE_IF_8 = VALUE_SCALE_DIN * (0.0000000000);
localparam integer VALUE_MULT_1 = VALUE_SCALE_DIN * (0.0092187223);
localparam integer VALUE_MULT_2 = VALUE_SCALE_DIN * (0.0297356625);
localparam integer VALUE_MULT_3 = VALUE_SCALE_DIN * (0.0696527311);
localparam integer VALUE_MULT_4 = VALUE_SCALE_DIN * (0.1360221466);
localparam integer VALUE_MULT_5 = VALUE_SCALE_DIN * (0.2382454323);
localparam integer VALUE_MULT_6 = VALUE_SCALE_DIN * (0.3863599806);
localparam integer VALUE_MULT_7 = VALUE_SCALE_DIN * (0.5861816322);
localparam integer VALUE_MULT_8 = VALUE_SCALE_DIN * (0.8456003228);
localparam integer VALUE_ADD_1 = VALUE_SCALE_DIN_SQUARE * (0.0547897443);
localparam integer VALUE_ADD_2 = VALUE_SCALE_DIN_SQUARE * (0.1378047813);
localparam integer VALUE_ADD_3 = VALUE_SCALE_DIN_SQUARE * (0.2601243508);
localparam integer VALUE_ADD_4 = VALUE_SCALE_DIN_SQUARE * (0.4135156578);
localparam integer VALUE_ADD_5 = VALUE_SCALE_DIN_SQUARE * (0.5881992282);
localparam integer VALUE_ADD_6 = VALUE_SCALE_DIN_SQUARE * (0.7634261373);
localparam integer VALUE_ADD_7 = VALUE_SCALE_DIN_SQUARE * (0.9104108696);
localparam integer VALUE_ADD_8 = VALUE_SCALE_DIN_SQUARE * (1.0000000000);

input  logic clk, en1, en2;
input  logic signed [DATA_WIDTH_DIN-1:0] dIn       [0:NUM_N-1];
output logic signed [DATA_WIDTH-1:0]     dOut_8bit [0:NUM_N-1];

logic signed [DATA_WIDTH_DIN-1:0]      x_a   [0:NUM_N-1];
integer                                mul_a [0:NUM_N-1];
integer                                add_a [0:NUM_N-1];
logic signed [DATA_WIDTH_DOUT-1:0]     y_b   [0:NUM_N-1];
logic signed [DATA_WIDTH_DOUT_RSH-1:0] y_rsh [0:NUM_N-1];

genvar n;
generate
    for (n = 0; n < NUM_N; n = n + 1) begin: Lane
        // A: the segment, as the original's comparisons, and its constants
        always @(posedge clk) if (en1) begin
            x_a[n] <= #1 dIn[n];
            if (dIn[n] <= VALUE_IF_4) begin
                if (dIn[n] <= VALUE_IF_2) begin
                    if (dIn[n] < VALUE_IF_0)       begin mul_a[n] <= #1 0;            add_a[n] <= #1 0;           end
                    else if (dIn[n] <= VALUE_IF_1) begin mul_a[n] <= #1 VALUE_MULT_1; add_a[n] <= #1 VALUE_ADD_1; end
                    else                           begin mul_a[n] <= #1 VALUE_MULT_2; add_a[n] <= #1 VALUE_ADD_2; end
                end else begin
                    if (dIn[n] <= VALUE_IF_3)      begin mul_a[n] <= #1 VALUE_MULT_3; add_a[n] <= #1 VALUE_ADD_3; end
                    else                           begin mul_a[n] <= #1 VALUE_MULT_4; add_a[n] <= #1 VALUE_ADD_4; end
                end
            end else begin
                if (dIn[n] <= VALUE_IF_6) begin
                    if (dIn[n] <= VALUE_IF_5)      begin mul_a[n] <= #1 VALUE_MULT_5; add_a[n] <= #1 VALUE_ADD_5; end
                    else                           begin mul_a[n] <= #1 VALUE_MULT_6; add_a[n] <= #1 VALUE_ADD_6; end
                end else begin
                    if (dIn[n] <= VALUE_IF_7)      begin mul_a[n] <= #1 VALUE_MULT_7; add_a[n] <= #1 VALUE_ADD_7; end
                    else if (dIn[n] <= VALUE_IF_8) begin mul_a[n] <= #1 VALUE_MULT_8; add_a[n] <= #1 VALUE_ADD_8; end
                    else                           begin mul_a[n] <= #1 0;            add_a[n] <= #1 VALUE_SCALE_DIN_SQUARE; end
                end
            end
        end

        // B: the chord
        always @(posedge clk) if (en2) y_b[n] <= #1 mul_a[n] * x_a[n] + add_a[n];

        shifter_right #(
            .DATA_WIDTH(DATA_WIDTH_DOUT),
            .NUM_SHIFT(NUM_RSH_DOUT)
        ) shifter_dOut (
            .dIn(y_b[n]),
            .dOut(y_rsh[n])
        );
        saturator #(
            .DATA_WIDTH(DATA_WIDTH_DOUT_RSH)
        ) saturator_dOut (
            .dIn(y_rsh[n]),
            .dOut(dOut_8bit[n])
        );
    end
endgenerate

endmodule
