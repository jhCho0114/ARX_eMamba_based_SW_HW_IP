`timescale 1ns / 1ps
// eMambaYOLO_engine : the shared-engine core (ENGINE_SPEC §10) — replaces the `eMambaYOLO` instance inside emy_ip_core.
//
//   sequencer emy_seq -> 4 engines (0 vec, 1 GEMM, 2 DW, 3 scan) -> buffer switch emy_buf (A/B/X/SKIP/WORK BRAM, ACC/IMG URAM)
//   boot:   BRAM_WB slots -> emy_wb_uram -> program RAM (emy_seq) + IMG banks (emy_buf)      (WB_LOAD, then wb_done)
//   input:  BRAM_IN slots -> emy_in_ring -> WORK input ring (rows_received -> in_rows, in_release -> rows_consumed)
//   output: engine BUF_OUT writes -> emy_buf out_wr_* -> emy_out_adapter -> BRAM_OUT rows (slot ping-pong / fill, as today)
//   The engine modules emy_gemm / emy_dw / emy_scan have the common interface of §6 (the same ports as emy_vec without out_room);
//   until Anh's engines arrive, sim_1/new/lib/emy_engine_stub.sv provides vector-backed stand-ins with these names.
module eMambaYOLO_engine import emy_engine_pkg::*; #(
    parameter int    IMG_LINES = 198992,      // lines of engine_image.mem (tools/engine_image.py total_lines; L00 .. L21 since 2026-10-19 default switch)
    parameter int    IMG_URAM_LINES = 184320, // [Jae 2026-10-19] IMG ext: lines kept in URAM, the rest in emy_buf's block-RAM extension (= IMG_LINES: none)
    parameter int    IN_AW     = 15,          // BRAM_IN  byte address bits (32 KB, two 16 KB slots)
    parameter int    WB_AW     = 15,          // BRAM_WB  byte address bits
    parameter int    OUT_AW    = 13,          // BRAM_OUT byte address bits (8 KB)
    parameter string PROG_INIT = "",          // simulation: program RAM initial contents instead of the boot stream
    parameter bit    TRACE     = 1'b0,
    parameter int    OUT_P3_ROWS = 19200,      // BRAM_OUT rows per frame and head (emy_out_adapter): neck outputs 6400 / 3200 / 1600,
    parameter int    OUT_P4_ROWS = 4800,      //   with the L21 Detect head (gen_program --layers 21) 19200 / 4800 / 1200
    parameter int    OUT_P5_ROWS = 1200       //   ([Jae 2026-10-19]; program.json out_rows / <program>/out_cfg.svh)
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,                    // START: run one frame (program RAM from PC 0)
    input  logic wb_restart,                  // WB_LOAD: restart the boot stream (program, then IMG)

    // BRAM_WB slots (boot stream)
    input  logic [WB_AW-1:0] wb_len0,
    input  logic [WB_AW-1:0] wb_len1,
    input  logic [1:0]       wb_full,
    output logic [1:0]       wb_take,
    output logic             wb_bram_en,
    output logic [WB_AW-1:0] wb_bram_addr,
    input  logic [31:0]      wb_bram_dout,

    // BRAM_IN slots (HWC frame, 3 B / pixel)
    input  logic [IN_AW-1:0] in_len0,
    input  logic [IN_AW-1:0] in_len1,
    input  logic [1:0]       in_full,
    output logic [1:0]       in_take,
    output logic             in_bram_en,
    output logic [IN_AW-1:0] in_bram_addr,
    input  logic [31:0]      in_bram_dout,

    // BRAM_OUT (P3 / P4 / P5 rows, slot convention of emy_ip_core)
    input  logic [5:0]        out_full,       // {P5 s1, P5 s0, P4 s1, P4 s0, P3 s1, P3 s0}
    output logic [5:0]        out_fill,
    output logic              out_bram_en,
    output logic [63:0]       out_bram_we,
    output logic [OUT_AW-1:0] out_bram_addr,
    output logic [511:0]      out_bram_din,

    // configuration / status (S_AXI registers)
    input  logic [BUF_ADDR_W-1:0] ring_base,  // WORK word address of the input ring (program.json, 0)
    output logic              busy,
    output logic              frame_done,
    output logic              wb_done,
    output logic [31:0]       wb_count,
    output logic              wb_overflow,
    output logic [PROG_AW-1:0] pc_dbg,
    output cmd_t              cmd_dbg,        // the command being executed
    output logic [1:0]        active_dbg,
    output logic              active_v_dbg,
    output logic [15:0]       in_rows,        // input ring rows received this frame
    output logic              in_frame_done,  // the whole input frame is in (pulse)
    output logic              in_pixel_fire,  // one input pixel written into the ring (PIX_COUNT)
    output logic [7:0]        buf_fault,      // emy_buf diagnostics (sticky in the register block)
    output logic              out_fifo_overflow,
    output logic [31:0]       out_rows,       // BRAM_OUT rows written this frame
    // [Jae 2026-10-21] candidate filter (S_AXI FILTER register) — emy_out_adapter header
    input  logic              filt_en,
    input  logic signed [7:0] qthr0,
    input  logic signed [7:0] qthr1,
    input  logic signed [7:0] qthr2,
    input  logic              det_en,         // DET mode (FILTER[1]): one DET row per candidate (emy_head_math)
    input  logic              nms_en          // NMS mode (FILTER[2], with det_en): NMS in the adapter (emy_nms), detection rows + END
);

// ---------- sequencer <-> engines ---------- //
cmd_t        cmd;
logic [15:0] tile_r0, group_g;
logic [1:0]  dir_k;
logic [3:0]  eng_valid, eng_ready, eng_done;
logic [1:0]  active;
logic        active_v;
logic        prog_we;
logic [PROG_AW-1:0] prog_addr;
logic [CMD_W-1:0]   prog_wdata;
logic [15:0] in_release;

// [Jae 2026-10-21] frame_done to the registers is held until the output adapter has written everything (and, with the
// candidate filter, the END rows): FRAME_DONE then never precedes the last out_fill.
logic seq_frame_done, fd_pend, out_drained;
emy_seq #(.PROG_INIT(PROG_INIT), .TRACE(TRACE)) u_seq (
    .clk, .nRst, .ps_start, .prog_we, .prog_addr, .prog_data(prog_wdata),
    .cmd, .tile_r0, .dir_k, .group_g, .eng_valid, .eng_ready, .eng_done, .active, .active_v,
    .in_rows, .in_release, .busy, .frame_done(seq_frame_done), .pc_dbg);
always @(posedge clk) begin
    if (!nRst || ps_start) begin fd_pend <= #1 1'b0; frame_done <= #1 1'b0; end
    else begin
        frame_done <= #1 1'b0;
        if (seq_frame_done) fd_pend <= #1 1'b1;
        else if (fd_pend && out_drained) begin fd_pend <= #1 1'b0; frame_done <= #1 1'b1; end
    end
end
assign cmd_dbg = cmd; assign active_dbg = active; assign active_v_dbg = active_v;

// ---------- engine buffer ports (index = engine) ---------- //
logic [3:0]                    e_rd0_en, e_rd1_en, e_wr_en, e_img_en;
logic [3:0][BUF_ID_W-1:0]      e_rd0_buf, e_rd1_buf, e_wr_buf;
logic [3:0][BUF_ADDR_W-1:0]    e_rd0_addr, e_rd1_addr, e_wr_addr;
logic [3:0][WORD_W-1:0]        e_rd0_data, e_rd1_data, e_wr_data;
logic [3:0][7:0]               e_wr_be;
logic [3:0][IMG_ADDR_W-1:0]    e_img_addr;
logic [3:0][IMG_LINE_W-1:0]    e_img_data;
logic                          out_room;

emy_vec u_vec (
    .clk, .nRst, .cmd_valid(eng_valid[ENG_VEC]), .cmd_ready(eng_ready[ENG_VEC]), .cmd, .tile_r0, .dir_k, .group_g, .done(eng_done[ENG_VEC]),
    .rd0_en(e_rd0_en[ENG_VEC]), .rd0_buf(e_rd0_buf[ENG_VEC]), .rd0_addr(e_rd0_addr[ENG_VEC]), .rd0_data(e_rd0_data[ENG_VEC]),
    .rd1_en(e_rd1_en[ENG_VEC]), .rd1_buf(e_rd1_buf[ENG_VEC]), .rd1_addr(e_rd1_addr[ENG_VEC]), .rd1_data(e_rd1_data[ENG_VEC]),
    .wr_en(e_wr_en[ENG_VEC]), .wr_buf(e_wr_buf[ENG_VEC]), .wr_addr(e_wr_addr[ENG_VEC]), .wr_data(e_wr_data[ENG_VEC]), .wr_be(e_wr_be[ENG_VEC]),
    .img_en(e_img_en[ENG_VEC]), .img_addr(e_img_addr[ENG_VEC]), .img_data(e_img_data[ENG_VEC]), .out_room);

emy_gemm u_gemm (
    .clk, .nRst, .cmd_valid(eng_valid[ENG_GEMM]), .cmd_ready(eng_ready[ENG_GEMM]), .cmd, .tile_r0, .dir_k, .group_g, .done(eng_done[ENG_GEMM]),
    .rd0_en(e_rd0_en[ENG_GEMM]), .rd0_buf(e_rd0_buf[ENG_GEMM]), .rd0_addr(e_rd0_addr[ENG_GEMM]), .rd0_data(e_rd0_data[ENG_GEMM]),
    .rd1_en(e_rd1_en[ENG_GEMM]), .rd1_buf(e_rd1_buf[ENG_GEMM]), .rd1_addr(e_rd1_addr[ENG_GEMM]), .rd1_data(e_rd1_data[ENG_GEMM]),
    .wr_en(e_wr_en[ENG_GEMM]), .wr_buf(e_wr_buf[ENG_GEMM]), .wr_addr(e_wr_addr[ENG_GEMM]), .wr_data(e_wr_data[ENG_GEMM]), .wr_be(e_wr_be[ENG_GEMM]),
    .img_en(e_img_en[ENG_GEMM]), .img_addr(e_img_addr[ENG_GEMM]), .img_data(e_img_data[ENG_GEMM]));

emy_dw u_dw (
    .clk, .nRst, .cmd_valid(eng_valid[ENG_DW]), .cmd_ready(eng_ready[ENG_DW]), .cmd, .tile_r0, .dir_k, .group_g, .done(eng_done[ENG_DW]),
    .rd0_en(e_rd0_en[ENG_DW]), .rd0_buf(e_rd0_buf[ENG_DW]), .rd0_addr(e_rd0_addr[ENG_DW]), .rd0_data(e_rd0_data[ENG_DW]),
    .rd1_en(e_rd1_en[ENG_DW]), .rd1_buf(e_rd1_buf[ENG_DW]), .rd1_addr(e_rd1_addr[ENG_DW]), .rd1_data(e_rd1_data[ENG_DW]),
    .wr_en(e_wr_en[ENG_DW]), .wr_buf(e_wr_buf[ENG_DW]), .wr_addr(e_wr_addr[ENG_DW]), .wr_data(e_wr_data[ENG_DW]), .wr_be(e_wr_be[ENG_DW]),
    .img_en(e_img_en[ENG_DW]), .img_addr(e_img_addr[ENG_DW]), .img_data(e_img_data[ENG_DW]));

emy_scan u_scan (
    .clk, .nRst, .cmd_valid(eng_valid[ENG_SCAN]), .cmd_ready(eng_ready[ENG_SCAN]), .cmd, .tile_r0, .dir_k, .group_g, .done(eng_done[ENG_SCAN]),
    .rd0_en(e_rd0_en[ENG_SCAN]), .rd0_buf(e_rd0_buf[ENG_SCAN]), .rd0_addr(e_rd0_addr[ENG_SCAN]), .rd0_data(e_rd0_data[ENG_SCAN]),
    .rd1_en(e_rd1_en[ENG_SCAN]), .rd1_buf(e_rd1_buf[ENG_SCAN]), .rd1_addr(e_rd1_addr[ENG_SCAN]), .rd1_data(e_rd1_data[ENG_SCAN]),
    .wr_en(e_wr_en[ENG_SCAN]), .wr_buf(e_wr_buf[ENG_SCAN]), .wr_addr(e_wr_addr[ENG_SCAN]), .wr_data(e_wr_data[ENG_SCAN]), .wr_be(e_wr_be[ENG_SCAN]),
    .img_en(e_img_en[ENG_SCAN]), .img_addr(e_img_addr[ENG_SCAN]), .img_data(e_img_data[ENG_SCAN]));

// ---------- buffers ---------- //
logic        img_we;
logic [1:0]  img_bank;
logic [IMG_ADDR_W-1:0] img_addr;
logic [WORD_W-1:0]     img_wdata;
logic        img_load_ready;                  // constant 1 while no engine reads IMG (boot happens while idle)
logic        ring_valid, ring_ready;
logic [BUF_ADDR_W-1:0] ring_addr;
logic [WORD_W-1:0]     ring_data;
logic [7:0]  ring_be;
logic        out_wr_en;
logic [BUF_ADDR_W-1:0] out_wr_addr;
logic [WORD_W-1:0]     out_wr_data;
logic [7:0]  out_wr_be;

emy_buf #(.IMG_LINES(IMG_LINES), .IMG_URAM_LINES(IMG_URAM_LINES)) u_buf (
    .clk, .nRst, .active_valid(active_v), .active_engine(active),
    .eng_rd0_en(e_rd0_en), .eng_rd0_buf(e_rd0_buf), .eng_rd0_addr(e_rd0_addr), .eng_rd0_data(e_rd0_data),
    .eng_rd1_en(e_rd1_en), .eng_rd1_buf(e_rd1_buf), .eng_rd1_addr(e_rd1_addr), .eng_rd1_data(e_rd1_data),
    .eng_wr_en(e_wr_en), .eng_wr_buf(e_wr_buf), .eng_wr_addr(e_wr_addr), .eng_wr_data(e_wr_data), .eng_wr_be(e_wr_be),
    .eng_img_en(e_img_en), .eng_img_addr(e_img_addr), .eng_img_data(e_img_data),
    .img_load_valid(img_we), .img_load_ready, .img_load_bank(img_bank), .img_load_addr(img_addr), .img_load_data(img_wdata), .img_load_be(8'hff),
    .ring_valid, .ring_ready, .ring_addr, .ring_data, .ring_be,
    .out_wr_en, .out_wr_addr, .out_wr_data, .out_wr_be, .fault(buf_fault));

// ---------- boot loader ---------- //
emy_wb_uram #(.SLOT_AW(WB_AW), .PROG_LINES(PROG_DEPTH), .IMG_BYTES(IMG_LINES * 32), .IMG_ADDR_W(IMG_ADDR_W)) u_wb (
    .clk, .nRst, .restart(wb_restart),
    .len0(wb_len0), .len1(wb_len1), .full(wb_full), .take(wb_take), .bram_en(wb_bram_en), .bram_addr(wb_bram_addr), .bram_dout(wb_bram_dout),
    .prog_we, .prog_addr, .prog_wdata, .img_we, .img_bank, .img_addr, .img_wdata,
    .wb_done, .wb_count, .overflow_seen(wb_overflow));

// ---------- input ring ---------- //
emy_in_ring #(.SLOT_AW(IN_AW), .FRAME_W(640), .FRAME_H(640), .RING_ROWS(IN_RING_ROWS), .BUF_ADDR_W(BUF_ADDR_W)) u_ring (
    .clk, .nRst, .restart(ps_start),
    .len0(in_len0), .len1(in_len1), .full(in_full), .take(in_take), .bram_en(in_bram_en), .bram_addr(in_bram_addr), .bram_dout(in_bram_dout),
    .ring_base, .rows_consumed(in_release), .rows_received(in_rows),
    .ring_wr_valid(ring_valid), .ring_wr_ready(ring_ready), .ring_wr_addr(ring_addr), .ring_wr_data(ring_data), .ring_wr_be(ring_be),
    .frame_done(in_frame_done), .pixel_fire(in_pixel_fire));

// ---------- output adapter ---------- //
emy_out_adapter #(.OUT_AW(OUT_AW), .P3_ROWS(OUT_P3_ROWS), .P4_ROWS(OUT_P4_ROWS), .P5_ROWS(OUT_P5_ROWS)) u_out (
    .clk, .nRst, .restart(ps_start),
    .wr_en(out_wr_en), .wr_addr(out_wr_addr), .wr_data(out_wr_data), .out_room,
    .filt_en, .qthr0, .qthr1, .qthr2, .det_en, .nms_en, .frame_end(seq_frame_done), .drained(out_drained),
    .out_full, .out_fill, .out_bram_en, .out_bram_we, .out_bram_addr, .out_bram_din,
    .fifo_overflow(out_fifo_overflow), .rows_written(out_rows));

endmodule
