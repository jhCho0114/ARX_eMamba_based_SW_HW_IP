`timescale 1ns / 1ps
// emy_dfl_side : DFL expectation of one box side (16 int8 bins) — bit-exact port of the C hp_dfl_side_q8 (emy_head_post.c):
//     m   = max(q_b)                                  (signed int8)
//     k_b = m - q_b  (0 .. 255)                       e_b = EXP_ROM[k_b] = round(65536 * exp(-k_b / 8)), k_b >= 128 -> 0
//     S   = sum e_b  (<= 16 * 65536 = 2^20)          E   = sum b * e_b  (<= 15 * 2^20 < 2^24)
//     d   = (E << 8) / S                              expectation in 1/256 grid units, d <= 15 * 256 = 3840 < 2^12
//   The division is a 12-step restoring divider (the quotient has 12 bits because d <= 3840): N = E << 8 (32 bit), D = S (21 bit).
//   Pipeline: start -> max (1) -> ROM (1) -> partial sums (1) -> S, E (1) -> divide (12) -> done: 16 clocks after start, one side at a time.
//   Rhythm: all registers are stage boundaries (no path crosses more than one stage), aimed at the 10 ns clock of the IP (WNS +0.022 ns at
//   the last impl — nothing here touches the engine's paths).
module emy_dfl_side import emy_head_rom_pkg::*; (
    input  logic         clk,
    input  logic         nRst,
    input  logic         start,        // q valid this clock; ignored while busy
    input  logic [127:0] q,            // 16 int8 bins, bin b = q[8b +: 8]
    output logic [11:0]  d,            // valid with done, held until the next start
    output logic         done,         // one-clock pulse
    output logic         busy
);

// ---------- stage 0: capture ---------- //
logic signed [7:0] qr [0:15];
logic s0_v;
always @(posedge clk) begin
    if (!nRst) begin s0_v <= #1 1'b0; end
    else begin
        s0_v <= #1 start && !busy;
        if (start && !busy) for (int b = 0; b < 16; b++) qr[b] <= #1 q[8 * b +: 8];
    end
end

// ---------- stage 1: max of 16 (tree 16 -> 8 -> 4 -> 2 -> 1) ---------- //
function automatic logic signed [7:0] smax(input logic signed [7:0] a, input logic signed [7:0] b); return (a > b) ? a : b; endfunction
logic signed [7:0] m8 [0:7], m4 [0:3], m2 [0:1], m1;
always_comb begin
    for (int i = 0; i < 8; i++) m8[i] = smax(qr[2 * i], qr[2 * i + 1]);
    for (int i = 0; i < 4; i++) m4[i] = smax(m8[2 * i], m8[2 * i + 1]);
    for (int i = 0; i < 2; i++) m2[i] = smax(m4[2 * i], m4[2 * i + 1]);
    m1 = smax(m2[0], m2[1]);
end
logic signed [7:0] m_r;
logic s1_v;
always @(posedge clk) begin
    if (!nRst) s1_v <= #1 1'b0;
    else begin s1_v <= #1 s0_v; if (s0_v) m_r <= #1 m1; end
end

// ---------- stage 2: k_b = m - q_b, e_b = EXP_ROM[k_b] (k_b >= 128 -> 0) ---------- //
logic [16:0] e_r [0:15];
logic [8:0]  k   [0:15];                          // m - q_b: 0 .. 255 (m >= q_b; both sign-extended to 9 bits)
logic s2_v;
always_comb for (int b = 0; b < 16; b++) k[b] = {m_r[7], m_r} - {qr[b][7], qr[b]};
always @(posedge clk) begin
    if (!nRst) s2_v <= #1 1'b0;
    else begin
        s2_v <= #1 s1_v;
        if (s1_v) for (int b = 0; b < 16; b++) e_r[b] <= #1 k[b][7] ? 17'd0 : EXP_ROM[k[b][6:0]];
    end
end

// ---------- stage 3: partial sums (4 groups of 4) ---------- //
logic [18:0] sp [0:3];                            // 4 * 65536 < 2^19
logic [22:0] ep [0:3];                            // 4 * 15 * 65536 < 2^23
logic s3_v;
always @(posedge clk) begin
    if (!nRst) s3_v <= #1 1'b0;
    else begin
        s3_v <= #1 s2_v;
        if (s2_v) for (int g = 0; g < 4; g++) begin
            sp[g] <= #1 19'(e_r[4 * g]) + 19'(e_r[4 * g + 1]) + 19'(e_r[4 * g + 2]) + 19'(e_r[4 * g + 3]);
            ep[g] <= #1 23'(e_r[4 * g]) * (4 * g) + 23'(e_r[4 * g + 1]) * (4 * g + 1) + 23'(e_r[4 * g + 2]) * (4 * g + 2) + 23'(e_r[4 * g + 3]) * (4 * g + 3);
        end
    end
end

// ---------- stage 4: S, E; load the divider ---------- //
logic [20:0] S_r;                                 // divisor
logic [31:0] rem;                                 // remainder (N = E << 8 < 2^32)
logic [11:0] quo;
logic [3:0]  step;                                // 12 .. 1 while dividing, 0 idle
logic        div_v;
wire  [20:0] S_sum = 21'(sp[0]) + 21'(sp[1]) + 21'(sp[2]) + 21'(sp[3]);
wire  [23:0] E_sum = 24'(ep[0]) + 24'(ep[1]) + 24'(ep[2]) + 24'(ep[3]);
// one restoring step: bit i = step - 1; subtract D << i when it fits
wire  [32:0] d_sh  = 33'(S_r) << (step - 4'd1);
wire  [32:0] diff  = {1'b0, rem} - d_sh;
always @(posedge clk) begin
    if (!nRst) begin step <= #1 '0; div_v <= #1 1'b0; done <= #1 1'b0; end
    else begin
        done <= #1 1'b0;
        if (s3_v) begin
            S_r <= #1 S_sum; rem <= #1 {E_sum, 8'd0}; quo <= #1 '0; step <= #1 4'd12; div_v <= #1 1'b1;
        end else if (div_v) begin
            if (!diff[32]) begin rem <= #1 diff[31:0]; quo[step - 4'd1] <= #1 1'b1; end
            if (step == 4'd1) begin div_v <= #1 1'b0; done <= #1 1'b1; d <= #1 {quo[11:1], ~diff[32]}; end
            step <= #1 step - 4'd1;
        end
    end
end
assign busy = s0_v || s1_v || s2_v || s3_v || div_v;

endmodule
