`timescale 1ns / 1ps
// Requant : one pixel vector from (q, NUM_SCALE_DIN) to int8 at NUM_SCALE_DOUT, combinational (no handshake)
//
//   dOut[c] = sat8(rshr(dIn[c], NUM_SCALE_DIN - NUM_SCALE_DOUT))          (<= 0: exact left shift)
//
// Placed on a stream wire between a producer and a consumer whose input shift differs (graph boundary, quant.json
// pass 'wide' -> consumer s_in, e.g. Add 07 wide -> LightNorm 08): valid / ready pass straight through.
// The shift is computed here from the two shifts of the int8_WB / LOG quant.json, never by hand.
module Requant import emy_pkg::*; #(
    parameter integer NUM_DIM        = 32,
    parameter integer DIN_W          = WIDE_W,
    parameter integer NUM_SCALE_DIN  = 4,
    parameter integer NUM_SCALE_DOUT = 3
)(
    input  logic signed [DIN_W-1:0] dIn  [0:NUM_DIM-1],
    output logic signed [ACT_W-1:0] dOut [0:NUM_DIM-1]
);

localparam integer SHIFT = NUM_SCALE_DIN - NUM_SCALE_DOUT;

genvar i;
generate
    for (i = 0; i < NUM_DIM; i = i + 1) begin : rq
        emy_requant #(
            .IN_W(DIN_W),
            .OUT_W(ACT_W)
        ) requant (
            .din(dIn[i]),
            .shift(8'(SHIFT)),
            .dout(dOut[i])
        );
    end
endgenerate

endmodule
