`timescale 1ns / 1ps
// MaxPool5x5 : MaxPool 5x5, stride 1, pad 2 (outside taps excluded, output H x W) on an int8 [C, H, W] pixel stream
//
//   dOut[c, h, w] = max over the window of x[c, ...]   (INT8 reference model, SW.MaxPool2d)
//
// Window: emy_im2col (K 5, stride 1, pad 2 = (K-1)/2) with PAD_MIN (outside taps = -128). Excluding the outside taps and padding them with
// -128 give the same max, because the window always holds its centre tap (a real value >= -128).
// Reduce: per channel max of the K*K taps in two registered stages, with the Linear_Transform_Dynamic_WB handshake
//   (dIn_mem, s_ready = EMPTY | last_cycle, INIT -> ROWMAX -> COLMAX -> DONE, m_valid = DONE):
//     ROWMAX  row_max[c][kh] = max of the K taps of window row kh        (reads dIn_mem: last_cycle, a new patch may land)
//     COLMAX  dOut[c]        = max of the K row maxima                   (reads row_max only)
//   [timing, 2026-10-06] was one COMPUTE cycle over all K*K taps (a chain of 24 compares, ~100 MHz after route);
//   max is associative and commutative, so the result is the same. One more cycle per output pixel.
// Input / output: pixel vectors [C], raster (h, w). Output row h starts once input rows up to h + P are in.
// Output shift = input shift (max does not change values; the SPPF pools have s_in = s_out, so no requant).
// Contract (every module with ps_start): no s_valid in the cycle ps_start is 1 (the input status is cleared then).
module MaxPool5x5 import emy_pkg::*; #(
    parameter integer NUM_CH     = 128,
    parameter integer NUM_HEIGHT = 20,
    parameter integer NUM_WIDTH  = 20
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic signed [ACT_W-1:0] dIn  [0:NUM_CH-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:NUM_CH-1],
    input  logic m_ready,
    output logic m_valid
);

localparam integer KERNEL    = 5;
localparam integer PAD       = (KERNEL - 1) / 2;
localparam integer NUM_TAP   = KERNEL * KERNEL;
localparam integer PATCH_LEN = NUM_CH * NUM_TAP;

// ---------- window ---------- //
logic signed [ACT_W-1:0] patch [0:PATCH_LEN-1];
logic patch_valid, patch_ready;

emy_im2col #(
    .NUM_CH(NUM_CH),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .KERNEL(KERNEL),
    .STRIDE(1),
    .PAD(PAD),
    .PAD_MIN(1'b1)
) im2col (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(patch),
    .m_ready(patch_ready),
    .m_valid(patch_valid)
);

// ---------- Local Parameters ---------- //
localparam INIT    = 2'd0,
           ROWMAX  = 2'd1,
           COLMAX  = 2'd2,
           DONE    = 2'd3;

localparam  EMPTY = 1'b0,
            LOAD  = 1'b1;

// ---------- Internal Variables ---------- //
logic [1:0] curr_state,
            next_state;

logic signed [ACT_W-1:0] dIn_mem [0:PATCH_LEN-1];
logic signed [ACT_W-1:0] row_max [0:NUM_CH-1][0:KERNEL-1];

logic dIn_stat;
logic last_cycle;

logic s_handshaking, m_handshaking;

assign s_handshaking = patch_valid & patch_ready;
assign m_handshaking = m_valid & m_ready;

assign patch_ready = (dIn_stat == EMPTY) | last_cycle;
assign m_valid     = (curr_state == DONE);

assign last_cycle = (curr_state == ROWMAX);       // the last cycle dIn_mem is read

// ---------- get input data ---------- //
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        dIn_stat <= #1 EMPTY;
    end else begin
        if (s_handshaking)   dIn_stat <= #1 LOAD;
        else if (last_cycle) dIn_stat <= #1 EMPTY;
        else                 dIn_stat <= #1 dIn_stat;
    end
end

always @(posedge clk) begin
    if (!nRst) begin
        dIn_mem <= #1 '{default:'0};
    end else if (s_handshaking) begin
        dIn_mem <= #1 patch;
    end else begin
        dIn_mem <= #1 dIn_mem;
    end
end

// ---------- Data Processing Logic: per channel max of its K*K taps (patch index c*K*K + kh*K + kw) ---------- //
function automatic logic signed [ACT_W-1:0] max2(input logic signed [ACT_W-1:0] a, input logic signed [ACT_W-1:0] b);
    return (b > a) ? b : a;
endfunction

// max of K = 5 values as a tree of three compare levels
function automatic logic signed [ACT_W-1:0] max5(input logic signed [ACT_W-1:0] a, input logic signed [ACT_W-1:0] b,
                                                 input logic signed [ACT_W-1:0] c, input logic signed [ACT_W-1:0] d,
                                                 input logic signed [ACT_W-1:0] e);
    return max2(max2(max2(a, b), max2(c, d)), e);
endfunction

// ROWMAX: max of each window row
always @(posedge clk) begin
    if (curr_state == ROWMAX) begin
        for (int c = 0; c < NUM_CH; c++)
            for (int kh = 0; kh < KERNEL; kh++)
                row_max[c][kh] <= #1 max5(dIn_mem[c*NUM_TAP + kh*KERNEL + 0], dIn_mem[c*NUM_TAP + kh*KERNEL + 1],
                                          dIn_mem[c*NUM_TAP + kh*KERNEL + 2], dIn_mem[c*NUM_TAP + kh*KERNEL + 3],
                                          dIn_mem[c*NUM_TAP + kh*KERNEL + 4]);
    end
end

// ---------- Final output ---------- //
// COLMAX: max of the row maxima
always @(posedge clk) begin
    if (!nRst) begin
        dOut <= #1 '{default:'0};
    end else begin
        if (curr_state == COLMAX)
            for (int c = 0; c < NUM_CH; c++)
                dOut[c] <= #1 max5(row_max[c][0], row_max[c][1], row_max[c][2], row_max[c][3], row_max[c][4]);
        else
            dOut <= #1 dOut;
    end
end

// ---------- FSM ---------- //
always @(posedge clk) begin
    if (!nRst || ps_start)
        curr_state <= #1 INIT;
    else
        curr_state <= #1 next_state;
end

always @(*) begin
    next_state = curr_state;

    case (curr_state)
        INIT: begin
            if (dIn_stat == LOAD)
                next_state = ROWMAX;
        end

        ROWMAX: next_state = COLMAX;

        COLMAX: next_state = DONE;

        DONE: begin
            if (m_handshaking) begin
                if (dIn_stat == LOAD)
                    next_state = ROWMAX;
                else
                    next_state = INIT;
            end
        end

        default: next_state = INIT;
    endcase
end

endmodule
