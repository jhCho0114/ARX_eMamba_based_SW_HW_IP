`timescale 1ns / 1ps
// emy_seq : the sequencer of the shared-engine eMambaYOLO (docs/ENGINE_SPEC.md §9) -- runs the program line by line
//
//   Program RAM PROG_DEPTH x 256 bit (loaded through prog_we / prog_addr / prog_data, or PROG_INIT for simulation).
//   ps_start -> PC = 0. Each line (cmd_t, emy_engine_pkg):
//     OP_LOOP     push a loop level: kind misc[1:0] (LP_TILE / LP_DIR / LP_GROUP), count c_in (LP_TILE with 0 = ceil(h / TILE_ROWS)),
//                 body length c_out. Count 0 skips the body. 3 levels (tile > dir > group).
//     OP_WAIT_IN  wait until in_rows >= min(c_in + (tile_r0 << misc[3:0]), h); then, unless misc[4] (wait only),
//                 in_release = min(c_out + (tile_r0 << misc[3:0]), h)  (h = 0: no clamp). A line with c_in = 0 passes at once
//                 (release only). The generator uses one wait-only line before and one release-only line after a tile body.
//     OP_SETK     dir_k = c_in[1:0] until the next SETK / ps_start (the program unrolls the four directions, one group
//                 loop each, because their prm and shifts differ; AM_PERM engines take the direction from dir_k).
//     OP_END      frame_done pulse, PC = 0, idle until the next ps_start.
//     other       engine op[7:4] - 1 (0 vec, 1 GEMM, 2 DW, 3 scan): eng_valid until eng_ready, then wait for eng_done.
//   Loop counters to the engines: tile_r0 = TILE_ROWS * tile iteration, dir_k = dir iteration, group_g = group iteration
//   (0 outside the loop). When the last line of a body completes, the innermost loop iterates or pops; a pop re-checks the
//   enclosing loop (one level per cycle).
//   Flags (clear-only): the generator writes the template flags, this module clears F_TOP_PAD when tile_r0 + row_lo > 0,
//   F_BOT_PAD when row_hi > 0 and tile_r0 + row_hi < h (ceil(h / 2) for a stride-2 GEMM, whose rows are output rows),
//   F_ACC_INIT when dir_k != 0 inside a dir loop, F_SEQ_START when
//   group_g != 0 inside a group loop.
//   active / active_v: the engine holding the command (for the buffer switch). busy: a frame is running.
//   ps_start is honoured only while idle (v1: no abort of a running command).
module emy_seq import emy_engine_pkg::*; #(
    parameter string PROG_INIT = "",          // $readmemh file (simulation / initial contents)
    parameter bit    TRACE     = 1'b0         // $display one line per issued command (simulation)
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    // program load
    input  logic               prog_we,
    input  logic [PROG_AW-1:0] prog_addr,
    input  logic [CMD_W-1:0]   prog_data,

    // engines (index ENG_VEC .. ENG_SCAN)
    output cmd_t        cmd,
    output logic [15:0] tile_r0,
    output logic [1:0]  dir_k,
    output logic [15:0] group_g,
    output logic [3:0]  eng_valid,
    input  logic [3:0]  eng_ready,
    input  logic [3:0]  eng_done,
    output logic [1:0]  active,
    output logic        active_v,

    // L00 input ring
    input  logic [15:0] in_rows,
    output logic [15:0] in_release,

    // status
    output logic               busy,
    output logic               frame_done,
    output logic [PROG_AW-1:0] pc_dbg
);

// ---------- Program RAM ---------- //
logic [CMD_W-1:0] prog [0:PROG_DEPTH-1];
logic [CMD_W-1:0] prog_q;
initial if (PROG_INIT != "") $readmemh(PROG_INIT, prog);
always @(posedge clk) if (prog_we) prog[prog_addr] <= #1 prog_data;

// ---------- Loop stack ---------- //
logic [1:0]         lp_kind  [0:2];
logic [PROG_AW-1:0] lp_start [0:2], lp_end [0:2];
logic [15:0]        lp_cnt   [0:2], lp_iter [0:2];
logic [1:0]         sp;

logic [1:0]  dir_set;              // OP_SETK value, used when no dir loop is active

// counters from the stack (combinational: 3 levels)
logic        in_tile, in_dir, in_grp;
logic [15:0] tile_iter, grp_iter;
logic [1:0]  dir_iter;
always @(*) begin
    in_tile = 0; in_dir = 0; in_grp = 0; tile_iter = '0; dir_iter = '0; grp_iter = '0;
    for (int i = 0; i < 3; i++) begin
        if (i < sp) begin
            case (lp_kind[i])
                LP_TILE:  begin in_tile = 1; tile_iter = lp_iter[i]; end
                LP_DIR:   begin in_dir = 1;  dir_iter  = lp_iter[i][1:0]; end
                LP_GROUP: begin in_grp = 1;  grp_iter  = lp_iter[i]; end
                default: ;
            endcase
        end
    end
end
assign tile_r0 = tile_iter * TILE_ROWS;
assign dir_k   = in_dir ? dir_iter : dir_set;
assign group_g = grp_iter;

// ---------- FSM ---------- //
typedef enum logic [2:0] {S_IDLE, S_FETCH, S_DEC, S_ISSUE, S_WAIT, S_WAITIN, S_NEXT} state_t;
state_t state;
logic [PROG_AW-1:0] pc, pc_next;
cmd_t  line;                       // the fetched line as written by the generator
cmd_t  cmd_r;                      // the line with the flags cleared, as issued
logic [1:0] eng;
logic [15:0] wait_need, wait_rel;
logic        wait_norel;
logic [31:0] t_issue;              // trace

assign line = prog_q;
assign eng  = line.op[7:4] - 2'd1;

// flag override (clear-only)
wire signed [17:0] r_lo = $signed({2'b0, tile_r0}) + 18'(line.row_lo);
wire signed [17:0] r_hi = $signed({2'b0, tile_r0}) + 18'(line.row_hi);
// the row window of a stride-2 GEMM is in output rows (SPEC §7.1): compare against ceil(h / 2)
wire        s2_gemm = (line.op == OP_GEMM) && (line.misc[M_KERNEL_LO +: 3] == KN_3X3_S2 || line.misc[M_KERNEL_LO +: 3] == KN_2X2_S2);
wire [15:0] h_out   = s2_gemm ? 16'((line.h + 1) >> 1) : line.h;
always @(*) begin
    cmd_r = line;
    if (r_lo > 0)                                              cmd_r.flags[F_TOP_PAD]   = 1'b0;
    if (line.row_hi > 0 && r_hi < $signed({2'b0, h_out}))      cmd_r.flags[F_BOT_PAD]   = 1'b0;
    if (in_dir && dir_k != 2'd0)                               cmd_r.flags[F_ACC_INIT]  = 1'b0;
    if (in_grp && group_g != 16'd0)                            cmd_r.flags[F_SEQ_START] = 1'b0;
end
assign cmd = cmd_r;

assign active   = eng;
assign active_v = (state == S_ISSUE) || (state == S_WAIT);
assign busy     = (state != S_IDLE);
assign pc_dbg   = pc;

wire [15:0] tile_shift = tile_r0 << line.misc[3:0];
wire [16:0] need_raw   = {1'b0, line.c_in}  + {1'b0, tile_shift};
wire [16:0] rel_raw    = {1'b0, line.c_out} + {1'b0, tile_shift};
wire [15:0] need_clp   = (line.h != 16'd0 && need_raw > {1'b0, line.h}) ? line.h : need_raw[15:0];
wire [15:0] rel_clp    = (line.h != 16'd0 && rel_raw  > {1'b0, line.h}) ? line.h : rel_raw[15:0];
wire [15:0] lp_count   = (line.misc[1:0] == LP_TILE && line.c_in == 16'd0) ? 16'((line.h + TILE_ROWS - 1) / TILE_ROWS) : line.c_in;

always @(posedge clk) begin
    if (!nRst) begin
        state <= #1 S_IDLE; pc <= #1 '0; pc_next <= #1 '0; sp <= #1 '0; eng_valid <= #1 '0; frame_done <= #1 1'b0;
        in_release <= #1 '0; prog_q <= #1 '0; wait_need <= #1 '0; wait_rel <= #1 '0; wait_norel <= #1 1'b0; t_issue <= #1 '0; dir_set <= #1 '0;
        for (int i = 0; i < 3; i++) begin lp_kind[i] <= #1 '0; lp_start[i] <= #1 '0; lp_end[i] <= #1 '0; lp_cnt[i] <= #1 '0; lp_iter[i] <= #1 '0; end
    end else begin
        frame_done <= #1 1'b0;
        eng_valid  <= #1 '0;
        case (state)
            S_IDLE: if (ps_start) begin
                pc <= #1 '0; sp <= #1 '0; in_release <= #1 '0; dir_set <= #1 '0; state <= #1 S_FETCH;
            end
            S_FETCH: begin
                prog_q <= #1 prog[pc]; state <= #1 S_DEC;
            end
            S_DEC: begin
                pc_next <= #1 pc + 1'b1;
                case (line.op)
                    OP_END: begin
                        frame_done <= #1 1'b1; pc <= #1 '0; sp <= #1 '0; state <= #1 S_IDLE;
                        if (TRACE) $display("[seq %0t] END (frame_done)", $time);
                    end
                    OP_LOOP: begin
                        if (lp_count == 16'd0) begin
                            pc <= #1 pc + 1'b1 + line.c_out[PROG_AW-1:0]; state <= #1 S_FETCH;   // empty loop: skip the body
                        end else begin
                            lp_kind[sp]  <= #1 line.misc[1:0];
                            lp_start[sp] <= #1 pc + 1'b1;
                            lp_end[sp]   <= #1 pc + 1'b1 + line.c_out[PROG_AW-1:0];
                            lp_cnt[sp]   <= #1 lp_count;
                            lp_iter[sp]  <= #1 '0;
                            sp <= #1 sp + 1'b1;
                            pc <= #1 pc + 1'b1; state <= #1 S_FETCH;
                            if (TRACE) $display("[seq %0t] pc %0d LOOP kind %0d count %0d body %0d (level %0d)", $time, pc, line.misc[1:0], lp_count, line.c_out, sp);
                        end
                    end
                    OP_SETK: begin
                        dir_set <= #1 line.c_in[1:0]; pc <= #1 pc + 1'b1; state <= #1 S_FETCH;
                        if (TRACE) $display("[seq %0t] pc %0d SETK %0d", $time, pc, line.c_in[1:0]);
                    end
                    OP_WAIT_IN: begin
                        wait_need  <= #1 need_clp;
                        wait_rel   <= #1 rel_clp;
                        wait_norel <= #1 line.misc[4];
                        state <= #1 S_WAITIN;
                    end
                    default: begin
                        state <= #1 S_ISSUE;
                        t_issue <= #1 32'($time / 10);
                    end
                endcase
            end
            S_ISSUE: begin
                eng_valid[eng] <= #1 1'b1;
                if (eng_valid[eng] && eng_ready[eng]) begin         // taken at this edge
                    eng_valid <= #1 '0; state <= #1 S_WAIT;
                    if (TRACE) $display("[seq %0t] pc %0d issue op %02h eng %0d r0 %0d k %0d g %0d flags %02h src0 %0d:%0d src1 %0d:%0d dst %0d:%0d",
                                        $time, pc, line.op, eng, tile_r0, dir_k, group_g, cmd_r.flags,
                                        cmd_r.src0.buf_id, cmd_r.src0.addr, cmd_r.src1.buf_id, cmd_r.src1.addr, cmd_r.dst.buf_id, cmd_r.dst.addr);
                end
            end
            S_WAIT: if (eng_done[eng]) begin
                state <= #1 S_NEXT;
                if (TRACE) $display("[seq %0t] pc %0d done (%0d cycles)", $time, pc, 32'($time / 10) - t_issue);
            end
            S_WAITIN: if (in_rows >= wait_need) begin
                if (!wait_norel) in_release <= #1 wait_rel;
                state <= #1 S_NEXT;
                if (TRACE) $display("[seq %0t] pc %0d WAIT_IN need %0d (in_rows %0d)%s", $time, pc, wait_need, in_rows,
                                    wait_norel ? "" : $sformatf(" release %0d", wait_rel));
            end
            S_NEXT: begin
                // the completed line was pc; pc_next = pc + 1. Loop end: the innermost loop whose body ends at pc_next
                if (sp != 2'd0 && pc_next == lp_end[sp-1]) begin
                    if (lp_iter[sp-1] + 1'b1 < lp_cnt[sp-1]) begin
                        lp_iter[sp-1] <= #1 lp_iter[sp-1] + 1'b1;
                        pc <= #1 lp_start[sp-1]; state <= #1 S_FETCH;
                    end else begin
                        sp <= #1 sp - 1'b1;                    // pop, then re-check the enclosing loop next cycle
                    end
                end else begin
                    pc <= #1 pc_next; state <= #1 S_FETCH;
                end
            end
            default: state <= #1 S_IDLE;
        endcase
    end
end

endmodule
