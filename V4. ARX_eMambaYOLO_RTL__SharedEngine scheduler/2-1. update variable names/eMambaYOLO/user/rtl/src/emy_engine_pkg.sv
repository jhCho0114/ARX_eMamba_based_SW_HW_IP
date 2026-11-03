`timescale 1ns / 1ps
// emy_engine_pkg : the shared-engine eMambaYOLO (U_201) -- command format, buffer ids, op codes, sizes (docs/ENGINE_SPEC.md §5, §12)
//
//   word   = 64 bit: 8 int8 channels (byte c = channel c, LSB side = lowest channel) or 4 wide (16 bit) channels
//   tensor = pixel-major: word(pix, cw) = base + pix * CW + cw,  CW = ceil(C / 8) (int8) or 2 * ceil(C / 8) (wide)
//   command = 256 bit (cmd_t below, first member = MSB); shifts are signed 8 bit with the emy_requant convention
//            (shift > 0: round-half-up right shift, shift <= 0: exact left shift)
package emy_engine_pkg;

    localparam int WORD_W     = 64;
    localparam int LANES      = 8;          // channels per word / vector-engine lanes
    localparam int CMD_W      = 256;
    localparam int BUF_ID_W   = 4;
    localparam int BUF_ADDR_W = 20;         // words (largest buffer 409,600 words)
    localparam int IMG_ADDR_W = 24;         // 32-byte lines
    localparam int IMG_LINE_W = 256;
    localparam int TILE_ROWS  = 8;
    localparam int HALO_ROWS  = 2;
    localparam int LN_F       = 20;         // fraction bits of the LightNorm reciprocal table (SW LN_F)

    // buffer ids
    localparam logic [3:0] BUF_A = 4'd0, BUF_B = 4'd1, BUF_X = 4'd2, BUF_SKIP = 4'd3, BUF_WORK = 4'd4, BUF_ACC = 4'd5,
                           BUF_OUT = 4'd6, BUF_IN = 4'd7;
    // BUF_OUT (VEC_OUTROWS): word address = head << OUT_HEAD_SHIFT | pixel * ceil(C/8) + j; the adapter takes row = addr[17:3]
    // (64-byte BRAM_OUT row: P3 1 per pixel, P4 2, P5 4), word in row = addr[2:0], head 0 P3 / 1 P4 / 2 P5.
    localparam int OUT_HEAD_SHIFT = 18;

    // op codes (bits [7:4] = engine: 0 sequencer, 1 vector, 2 GEMM, 3 DW, 4 scan)
    localparam logic [7:0] OP_END = 8'h00, OP_LOOP = 8'h01, OP_WAIT_IN = 8'h02, OP_SETK = 8'h03,   // SETK: dir_k = c_in[1:0] (outside a dir loop)
                           OP_VEC_RQ = 8'h10, OP_VEC_SILU = 8'h11, OP_VEC_ADD = 8'h12, OP_VEC_MUL = 8'h13, OP_VEC_LN = 8'h14,
                           OP_VEC_MAXPOOL = 8'h15, OP_VEC_OUTROWS = 8'h17,
                           OP_GEMM = 8'h20, OP_DW = 8'h30, OP_SCAN = 8'h40;

    // flags (cmd.flags bit numbers)
    localparam int F_RELU = 0, F_OUT_WIDE = 1, F_SEQ_START = 2, F_ACC_INIT = 3, F_TOP_PAD = 4, F_BOT_PAD = 5, F_SRC1_EN = 6, F_SILU = 7;

    // misc (cmd.misc bit numbers): kernel [2:0], address mode of src0 [4:3], src1 [6:5], dst [8:7], wide sources, upsample flags
    localparam int M_KERNEL_LO = 0, M_AM0_LO = 3, M_AM1_LO = 5, M_AMD_LO = 7, M_SRC0_WIDE = 9, M_SRC1_WIDE = 10, M_UP0 = 11, M_UP1 = 12;
    // tile-relative operands (phases 1 / 3): the region holds rows [tile_r0 - HALO_ROWS, tile_r0 + TILE_ROWS + HALO_ROWS) of the
    // frame, so the engine uses pixel p - (tile_r0 - HALO_ROWS) * w for that operand.  Frame operands (A/B/X/SKIP/ACC) are absolute.
    localparam int M_SRC0_REL = 13, M_SRC1_REL = 14, M_DST_REL = 15;
    // destination pitch: words per pixel of dst = ceil(c_out / 8) (x2 wide); a command writes only ceil(c_in / 8) words of each
    // pixel, so a copy with c_out > c_in lands in a channel sub-range of a wider tensor (Concat by copy).
    localparam logic [1:0] AM_RASTER = 2'd0,    // pixel = raster pixel of the row window [r0 + row_lo, r0 + row_hi)
                           AM_GROUP  = 2'd1,    // pixel = token index inside the group (0..7)  (phase 2 working set)
                           AM_PERM   = 2'd2;    // pixel = p_k(8 g + token)  (CrossScan order of direction k)
    localparam logic [2:0] KN_1X1 = 3'd0, KN_3X3_S1 = 3'd1, KN_3X3_S2 = 3'd2, KN_2X2_S2 = 3'd3, KN_5X5_S1 = 3'd4;

    // sequencer (emy_seq, SPEC §9): engine index = op[7:4] - 1 (0 vec, 1 GEMM, 2 DW, 3 scan); program RAM PROG_DEPTH x 256 bit
    localparam int PROG_DEPTH = 1024, PROG_AW = 10;
    localparam int ENG_VEC = 0, ENG_GEMM = 1, ENG_DW = 2, ENG_SCAN = 3;
    // OP_LOOP  : misc[1:0] = kind (LP_TILE / LP_DIR / LP_GROUP), c_in = iteration count (LP_TILE with c_in = 0: ceil(h / TILE_ROWS)),
    //            c_out = body length in lines (the body follows the LOOP line). Nested as tile > dir > group, 3 levels.
    //            The sequencer gives the engines tile_r0 = TILE_ROWS * tile iteration, dir_k = dir iteration, group_g = group iteration.
    // OP_WAIT_IN: wait until in_rows >= min(c_in + (tile_r0 << misc[3:0]), h) (h = frame rows of the ring, 0 = no clamp); then,
    //            unless misc[M_WAIT_NOREL], in_release = min(c_out + (tile_r0 << misc[3:0]), h) = rows [0, in_release) the input
    //            ring may overwrite. c_in = 0 passes at once (release-only line). L00: wait-only line (c_in 17, shift 1) before
    //            the tile body, release-only line (c_out 15, shift 1) after it (SPEC §4.4).
    // Flag override (clear-only): the generator writes the template flags, the sequencer clears
    //   F_TOP_PAD   when tile_r0 + row_lo > 0,          F_BOT_PAD   when row_hi > 0 and tile_r0 + row_hi < h,
    //   F_ACC_INIT  when dir_k != 0 (inside a dir loop), F_SEQ_START when group_g != 0 (inside a group loop).
    localparam logic [1:0] LP_TILE = 2'd0, LP_DIR = 2'd1, LP_GROUP = 2'd2;
    localparam int M_WAIT_NOREL = 4;            // OP_WAIT_IN misc bit: do not update in_release
    // L00 input ring (emy_in_ring -> WORK): a source with buf_id BUF_IN is the ring: physical buffer WORK, word address =
    // src.addr (ring base) + (row mod IN_RING_ROWS) * w + col for rows [0, h); rows outside are padding (zero) as usual.
    localparam int IN_RING_ROWS = 38;

    typedef struct packed {
        logic [BUF_ID_W-1:0]   buf_id;
        logic [BUF_ADDR_W-1:0] addr;
    } ref_t;

    typedef struct packed {
        logic [15:0]       misc;       // [255:240]
        logic [15:0]       prm2;       // [239:224]
        logic [23:0]       prm;        // [223:200]  IMG line address of the parameters / table
        ref_t              dst;        // [199:176]
        ref_t              src1;       // [175:152]
        ref_t              src0;       // [151:128]
        logic signed [7:0] row_hi;     // [127:120]  row window relative to tile_r0: rows [r0 + row_lo, r0 + row_hi); row_hi <= 0 means "to H"
        logic signed [7:0] row_lo;     // [119:112]
        logic [15:0]       h;          // [111:96]
        logic [15:0]       w;          // [95:80]
        logic [15:0]       c_out;      // [79:64]
        logic [15:0]       c_in;       // [63:48]
        logic signed [7:0] shift_aux;  // [47:40]  LN / scan auxiliary shift; GEMM: source-0 pixel pitch in words, 0 = ceil(c_in/8) ([Jae 2026-10-18] src0 pitch)
        logic signed [7:0] shift_out;  // [39:32]
        logic signed [7:0] shift1;     // [31:24]
        logic signed [7:0] shift0;     // [23:16]
        logic [7:0]        flags;      // [15:8]
        logic [7:0]        op;         // [7:0]
    } cmd_t;

endpackage
