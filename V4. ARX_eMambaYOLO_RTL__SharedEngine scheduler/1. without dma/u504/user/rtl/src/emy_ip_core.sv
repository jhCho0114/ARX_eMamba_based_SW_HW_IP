`timescale 1ns / 1ps
// emy_ip_core : the shared-engine core (eMambaYOLO_engine) behind flat ports for eMambaYOLO_IP.v (Verilog BD module).
//
//   v2 (2026-10-15): the U_106 pipeline (eMambaYOLO + slot readers + IN gearbox + OUT row writer) is replaced by
//   eMambaYOLO_engine (ENGINE_SPEC §10), which contains the slot readers, the input ring, the boot loader and the output adapter.
//   The slot conventions of v1 are unchanged (see eMambaYOLO_IP.v / S_AXI.sv headers):
//     BRAM_IN  (IN_AW)  : slot k = byte [k*2^(IN_AW-1), +2^(IN_AW-1)); HWC pixels, 3 B/pixel, little-endian words; any 4 B chunking.
//     BRAM_WB  (WB_AW)  : the boot stream = program.mem (PROG_DEPTH x 32 B) followed by engine_image.mem (IMG_LINES x 32 B);
//                         wb_done when PROG_DEPTH*32 + IMG_LINES*32 bytes have arrived (sticky until WB_LOAD).
//     BRAM_OUT (OUT_AW) : 64 B rows, P3 1 row / pixel, P4 2, P5 4; P3 = first half, P4 next quarter, P5 last quarter, 2 slots each.
//   Removed: layer_done[22:0] (there are no layer modules). Added (debug registers): busy, pc_dbg, cmd_dbg, active_dbg, in_rows,
//   buf_fault, out_fifo_overflow, wb_overflow, out_rows.
module emy_ip_core import emy_engine_pkg::*; #(
    parameter integer IN_AW     = 15,         // BRAM_IN  byte address bits (32 KB)
    parameter integer WB_AW     = 15,         // BRAM_WB  byte address bits (32 KB)
    parameter integer OUT_AW    = 13,         // BRAM_OUT byte address bits (8 KB, 512-bit rows)
    parameter integer IMG_LINES = 198992,     // engine_image.mem lines (tools/engine_image.py total_lines; L00 .. L21 since 2026-10-19 default switch)
    parameter integer IMG_URAM_LINES = 184320, // [Jae 2026-10-19] IMG ext: lines in URAM; lines beyond go to the block-RAM extension (184320 = 45 URAM/bank; 192512 did not place, URAM 100 %)
    parameter string  PROG_INIT = "",         // simulation only: program RAM initial contents
    parameter integer OUT_P3_ROWS = 19200,     // BRAM_OUT rows per frame and head (neck outputs; L21 head on the engine: 19200 / 4800 / 1200)
    parameter integer OUT_P4_ROWS = 4800,
    parameter integer OUT_P5_ROWS = 1200
)(
    input  logic clk,
    input  logic nRst,

    // ---------- from / to S_AXI ---------- //
    input  logic ps_start,                    // 1-clk pulse : run one frame (program from PC 0; IN ring / OUT adapter restart)
    input  logic wb_restart,                  // 1-clk pulse : boot stream restarts at byte 0

    input  logic [IN_AW-1:0] in_len0,         // bytes in IN slot 0 / 1 (valid while in_full[k])
    input  logic [IN_AW-1:0] in_len1,
    input  logic [1:0] in_full,
    output logic [1:0] in_take,               // slot k read out (the CPU may refill it)

    input  logic [WB_AW-1:0] wb_len0,
    input  logic [WB_AW-1:0] wb_len1,
    input  logic [1:0] wb_full,
    output logic [1:0] wb_take,

    input  logic [5:0] out_full,              // {P5 s1, P5 s0, P4 s1, P4 s0, P3 s1, P3 s0}
    output logic [5:0] out_fill,              // slot written (the CPU reads it, then releases it)

    output logic wb_done,
    output logic [31:0] wb_count,             // bytes received since wb_restart
    output logic pix_fire,                    // one input pixel written into the ring
    output logic frame_done,

    // debug / status (S_AXI registers)
    output logic busy,
    output logic [PROG_AW-1:0] pc_dbg,
    output logic [CMD_W-1:0] cmd_dbg,
    output logic [1:0] active_dbg,
    output logic active_v_dbg,
    output logic [15:0] in_rows,
    output logic [7:0] buf_fault,
    output logic out_fifo_overflow,
    output logic wb_overflow,
    output logic [31:0] out_rows,
    input  logic filt_en,                     // [Jae 2026-10-21] FILTER register -> output adapter candidate filter
    input  logic [7:0] qthr0,
    input  logic [7:0] qthr1,
    input  logic [7:0] qthr2,
    input  logic det_en,                      // FILTER[1] -> DET mode (one DET row per candidate)
    input  logic nms_en,                      // FILTER[2] -> NMS mode (with DET: NMS in the adapter)

    // ---------- BRAM ports (read latency 1) ---------- //
    output logic in_bram_en,
    output logic [IN_AW-1:0] in_bram_addr,
    input  logic [31:0] in_bram_dout,

    output logic wb_bram_en,
    output logic [WB_AW-1:0] wb_bram_addr,
    input  logic [31:0] wb_bram_dout,

    output logic out_bram_en,
    output logic [63:0] out_bram_we,
    output logic [OUT_AW-1:0] out_bram_addr,
    output logic [511:0] out_bram_din
);

cmd_t cmd_q;
assign cmd_dbg = cmd_q;

eMambaYOLO_engine #(
    .IMG_LINES(IMG_LINES), .IMG_URAM_LINES(IMG_URAM_LINES), .IN_AW(IN_AW), .WB_AW(WB_AW), .OUT_AW(OUT_AW), .PROG_INIT(PROG_INIT),
    .OUT_P3_ROWS(OUT_P3_ROWS), .OUT_P4_ROWS(OUT_P4_ROWS), .OUT_P5_ROWS(OUT_P5_ROWS)
) engine (
    .clk, .nRst, .ps_start, .wb_restart,
    .wb_len0, .wb_len1, .wb_full, .wb_take, .wb_bram_en, .wb_bram_addr, .wb_bram_dout,
    .in_len0, .in_len1, .in_full, .in_take, .in_bram_en, .in_bram_addr, .in_bram_dout,
    .out_full, .out_fill, .out_bram_en, .out_bram_we, .out_bram_addr, .out_bram_din,
    .ring_base('0),
    .busy, .frame_done, .wb_done, .wb_count, .wb_overflow, .pc_dbg, .cmd_dbg(cmd_q), .active_dbg, .active_v_dbg,
    .in_rows, .in_frame_done(), .in_pixel_fire(pix_fire), .buf_fault, .out_fifo_overflow, .out_rows,
    .filt_en, .qthr0(qthr0), .qthr1(qthr1), .qthr2(qthr2), .det_en, .nms_en);

endmodule
