// emy_requant : dout = sat_OUT_W(rshr(din, shift))      combinational
//
//   shift > 0  : round-half-up arithmetic right shift  (x + 2^(shift-1)) >>> shift
//   shift <= 0 : exact left shift by -shift (up to MAX_LSH), then saturate
//
// Used at Conv outputs (per-channel out_rshift), SiLU outputs and Concat inputs. shift is a signed 8-bit port so one
// instance serves different shifts. IN_W / OUT_W are the only parameters: the operand widths of the caller.
module emy_requant #(
    parameter int IN_W  = 32,
    parameter int OUT_W = 8
) (
    input  logic signed [IN_W-1:0]  din,
    input  logic signed [7:0]       shift,
    output logic signed [OUT_W-1:0] dout
);
    localparam int MAX_RSH = 40;     // larger than any shift of the model (conv out_rshift <= 15, SiLU <= 21)
    localparam int MAX_LSH = 8;      // model left shifts are <= 1 (Concat L16)
    localparam int EXT_W   = IN_W + MAX_LSH + 1;
    localparam logic signed [EXT_W-1:0] OUT_MAX = (EXT_W'(1) <<< (OUT_W - 1)) - 1;
    localparam logic signed [EXT_W-1:0] OUT_MIN = -(EXT_W'(1) <<< (OUT_W - 1));

    logic signed [EXT_W-1:0] x, rnd, shifted;
    int unsigned rs, ls;

    always_comb begin
        x   = EXT_W'(din);
        rs  = (shift > 0) ? ((shift > MAX_RSH) ? MAX_RSH : shift) : 0;
        ls  = (shift < 0) ? ((-shift > MAX_LSH) ? MAX_LSH : -shift) : 0;
        rnd = (rs > 0) ? (EXT_W'(1) <<< (rs - 1)) : '0;
        shifted = (rs > 0) ? ((x + rnd) >>> rs) : (x <<< ls);
        if (shifted > OUT_MAX)      dout = OUT_MAX[OUT_W-1:0];
        else if (shifted < OUT_MIN) dout = OUT_MIN[OUT_W-1:0];
        else                        dout = shifted[OUT_W-1:0];
    end
endmodule
