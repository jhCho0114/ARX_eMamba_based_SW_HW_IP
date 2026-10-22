`timescale 1ns / 1ps
// LightNorm : integer LightNorm over the channels of one pixel vector (v002 golden SW.LightNormInt), int8 -> int8
//
//   S = sum_c q[c],  R = max_c q - min_c q (0..255),  inv = INV[R]          INV = ln_recip_table(eps, s_in), F = 20
//   d = C*q[c] - S,  z = trunc0(d*inv / C)  (C = 2^k: shift, rounded toward 0)
//   acc = z*w[c] + (b[c] << (F + NUM_SCALE_W - NUM_SCALE_B))
//   dOut[c] = sat8(rshr(acc, F + NUM_SCALE_W - NUM_SCALE_DOUT))
//
// Datapath: LightNormInt (Anh): NUM_LANE channels per cycle, STAT (registered 4:1
//   reduction tree over the chunks) -> LUT (the INV RAM, registered read) -> NORM (d | d*inv | trunc | z*w | + b |
//   rshr + sat8, one chunk per cycle, every stage registered) -> DONE. Per vector NUM_DIM / NUM_LANE * 2 + 8
//   cycles; the vector waits in a register that rotates by one chunk per cycle. Used for steps 08 / 22 and
//   18 out_norm (SS2D). Handshake: s_valid / s_ready, m_valid / m_ready (dOut held until taken).
// Parameters from the weight / bias broadcast, window at WB_BASE (emy_wb_map_pkg):
//   W  ceil4(C) bytes int8 weight     B  ceil4(C) bytes int8 bias     INV  256 words uint32 reciprocal table
// Shifts: int8_WB quant.json (in / out) and meta.json (s_w, s_b); s_in only enters through the INV table.
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module LightNorm import emy_pkg::*; #(
    parameter integer NUM_DIM        = 32,    // C, power of two
    parameter integer NUM_SCALE_DIN  = 3,     // (through the INV table of the window only)
    parameter integer NUM_SCALE_W    = 4,
    parameter integer NUM_SCALE_B    = 5,
    parameter integer NUM_SCALE_DOUT = 3,
    parameter integer WB_BASE        = 0,
    parameter integer NUM_LANE       = 8      // channels per cycle (divides NUM_DIM, multiple of 4, or = NUM_DIM)
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_DIM-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:NUM_DIM-1],
    input  logic m_ready,
    output logic m_valid
);

// ---------- Local Parameters ---------- //
localparam integer LN_F         = 20;                                   // fraction bits of INV (SW LN_F)
localparam integer LANE         = (NUM_DIM % NUM_LANE == 0 && NUM_LANE % 4 == 0) ? NUM_LANE : NUM_DIM;
localparam integer BIAS_LSH     = LN_F + NUM_SCALE_W - NUM_SCALE_B;
localparam integer NUM_RSH_DOUT = LN_F + NUM_SCALE_W - NUM_SCALE_DOUT;
localparam integer ROW_C        = ceil4(NUM_DIM);
localparam integer WB_BASE_B    = WB_BASE + ROW_C;
localparam integer WB_BASE_INV  = WB_BASE_B + ROW_C;

LightNormInt #(
    .DATA_WIDTH(ACT_W),
    .NUM_DIM(NUM_DIM),
    .NUM_LANE(LANE),
    .NUM_LSH_BIAS(BIAS_LSH),
    .NUM_RSH_DOUT(NUM_RSH_DOUT),
    .WB_ADDR_W(WB_ADDR_W),
    .WB_BASE_W(WB_BASE),
    .WB_BASE_B(WB_BASE_B),
    .WB_BASE_L(WB_BASE_INV)
) ln (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .dOut(dOut),

    .s_valid(s_valid),
    .s_ready(s_ready),
    .m_valid(m_valid),
    .m_ready(m_ready)
);

// synthesis translate_off
initial begin
    if ((1 << $clog2(NUM_DIM)) != NUM_DIM) $fatal(1, "LightNorm: NUM_DIM must be a power of two");
    if (BIAS_LSH < 0) $fatal(1, "LightNorm: F + s_w - s_b < 0 not supported");
end
// synthesis translate_on

endmodule
