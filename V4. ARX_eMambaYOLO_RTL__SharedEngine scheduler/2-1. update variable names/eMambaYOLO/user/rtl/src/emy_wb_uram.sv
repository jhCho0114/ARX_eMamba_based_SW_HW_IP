`timescale 1ns/1ps
// U_201 boot stream loader: ping-pong BRAM slots -> program RAM then IMG banks.
// Contract assumptions are documented in docs/REPORT_emy_wb_uram.md.
module emy_wb_uram #(
    parameter integer SLOT_AW      = 15,
    parameter integer PROG_LINES   = 1024,
    parameter integer IMG_BYTES    = 0,
    parameter integer IMG_ADDR_W   = 24,
    parameter integer PROG_ADDR_W  = (PROG_LINES <= 1) ? 1 : $clog2(PROG_LINES)
)(
    input  logic clk,
    input  logic nRst,
    input  logic restart,

    input  logic [SLOT_AW-1:0] len0,
    input  logic [SLOT_AW-1:0] len1,
    input  logic [1:0] full,
    output logic [1:0] take,
    output logic bram_en,
    output logic [SLOT_AW-1:0] bram_addr,
    input  logic [31:0] bram_dout,

    output logic prog_we,
    output logic [PROG_ADDR_W-1:0] prog_addr,
    output logic [255:0] prog_wdata,
    output logic img_we,
    output logic [1:0] img_bank,
    output logic [IMG_ADDR_W-1:0] img_addr,
    output logic [63:0] img_wdata,

    output logic wb_done,
    output logic [31:0] wb_count,
    output logic overflow_seen
);
    localparam integer PROG_BYTES  = PROG_LINES * 32;
    localparam integer TOTAL_BYTES = PROG_BYTES + IMG_BYTES;

    logic [31:0] s_data;
    logic s_valid, s_ready;
    logic [255:0] prog_acc, prog_next;
    logic [31:0] img_lo;
    logic done_pending;
    logic accept;
    logic [31:0] img_off;

    emy_bao_slot_reader #(.AW(SLOT_AW)) slots (
        .clk(clk), .nRst(nRst), .restart(restart),
        .len0(len0), .len1(len1), .full(full), .take(take),
        .bram_en(bram_en), .bram_addr(bram_addr), .bram_dout(bram_dout),
        .m_data(s_data), .m_valid(s_valid), .m_ready(s_ready)
    );

    assign s_ready = (wb_count < TOTAL_BYTES) && !done_pending && !wb_done;
    assign accept  = s_valid && s_ready;
    assign img_off = wb_count - PROG_BYTES;

    always @(*) begin
        prog_next = prog_acc;
        prog_next[32 * wb_count[4:2] +: 32] = s_data;
    end

    initial begin
        if ((IMG_BYTES % 8) != 0) $error("emy_wb_uram IMG_BYTES must be a multiple of 8");
        if ((PROG_BYTES % 32) != 0) $error("emy_wb_uram program prefix must be line aligned");
    end

    always @(posedge clk) begin
        if (!nRst || restart) begin
            prog_we      <= #1 1'b0;
            prog_addr    <= #1 '0;
            prog_wdata   <= #1 '0;
            img_we       <= #1 1'b0;
            img_bank     <= #1 '0;
            img_addr     <= #1 '0;
            img_wdata    <= #1 '0;
            wb_done      <= #1 1'b0;
            wb_count     <= #1 '0;
            overflow_seen<= #1 1'b0;
            prog_acc     <= #1 '0;
            img_lo       <= #1 '0;
            done_pending <= #1 1'b0;
        end else begin
            prog_we <= #1 1'b0;
            img_we  <= #1 1'b0;

            // The sink commits the previous cycle's registered write on this edge.
            if (done_pending) begin
                wb_done      <= #1 1'b1;
                done_pending <= #1 1'b0;
            end

            if (accept) begin
                if (wb_count < PROG_BYTES) begin
                    prog_acc <= #1 prog_next;
                    if (wb_count[4:2] == 3'd7) begin
                        prog_we    <= #1 1'b1;
                        prog_addr  <= #1 wb_count[31:5];
                        prog_wdata <= #1 prog_next;
                    end
                end else begin
                    if (!img_off[2]) begin
                        img_lo <= #1 s_data;
                    end else begin
                        img_we    <= #1 1'b1;
                        img_bank  <= #1 img_off[4:3];
                        img_addr  <= #1 img_off[31:5];
                        img_wdata <= #1 {s_data, img_lo};
                    end
                end
                wb_count <= #1 wb_count + 4;
                if (wb_count + 4 == TOTAL_BYTES) done_pending <= #1 1'b1;
            end

            if ((wb_done || done_pending) && s_valid) overflow_seen <= #1 1'b1;
        end
    end
endmodule
