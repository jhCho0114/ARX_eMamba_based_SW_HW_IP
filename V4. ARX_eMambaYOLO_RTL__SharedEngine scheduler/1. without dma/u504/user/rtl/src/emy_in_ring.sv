`timescale 1ns/1ps
// U_201 input converter: HWC RGB byte stream -> 64-bit WORK row ring.
module emy_in_ring #(
    parameter integer SLOT_AW     = 15,
    parameter integer FRAME_W     = 640,
    parameter integer FRAME_H     = 640,
    parameter integer RING_ROWS   = 38,
    parameter integer BUF_ADDR_W  = 20
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

    input  logic [BUF_ADDR_W-1:0] ring_base,
    input  logic [15:0] rows_consumed,
    output logic [15:0] rows_received,

    output logic ring_wr_valid,
    input  logic ring_wr_ready,
    output logic [BUF_ADDR_W-1:0] ring_wr_addr,
    output logic [63:0] ring_wr_data,
    output logic [7:0] ring_wr_be,
    output logic frame_done,
    output logic pixel_fire
);
    logic [31:0] s_data;
    logic s_valid, s_ready;
    logic [55:0] byte_acc;
    logic [2:0] byte_count;
    logic [15:0] col;
    logic [((RING_ROWS <= 1) ? 1 : $clog2(RING_ROWS))-1:0] ring_row;
    logic frame_complete;
    logic row_space;
    logic px_valid;
    logic [16:0] occupied;

    emy_bao_slot_reader #(.AW(SLOT_AW)) slots (
        .clk(clk), .nRst(nRst), .restart(restart),
        .len0(len0), .len1(len1), .full(full), .take(take),
        .bram_en(bram_en), .bram_addr(bram_addr), .bram_dout(bram_dout),
        .m_data(s_data), .m_valid(s_valid), .m_ready(s_ready)
    );

    assign occupied     = (rows_consumed <= rows_received) ? rows_received - rows_consumed : 0;
    assign row_space    = (occupied < RING_ROWS);
    assign px_valid     = (byte_count >= 3);
    assign ring_wr_valid= px_valid && row_space && !frame_complete && !restart;
    assign pixel_fire   = ring_wr_valid && ring_wr_ready;
    // Track the physical row explicitly.  This is equivalent to
    // rows_received % RING_ROWS but avoids synthesising a modulo-by-38 unit.
    assign ring_wr_addr = ring_base + ring_row * FRAME_W + col;
    assign ring_wr_data = {40'd0, byte_acc[23:0]};
    assign ring_wr_be   = 8'hff;
    assign s_ready      = (byte_count <= 3) && !frame_complete && !restart;

    initial begin
        if (FRAME_W <= 0 || FRAME_H <= 0 || RING_ROWS <= 0) $error("emy_in_ring geometry must be positive");
    end

    always @(posedge clk) begin
        if (!nRst || restart) begin
            byte_acc      <= #1 '0;
            byte_count    <= #1 '0;
            col           <= #1 '0;
            ring_row      <= #1 '0;
            rows_received <= #1 '0;
            frame_complete<= #1 1'b0;
            frame_done    <= #1 1'b0;
        end else begin
            logic [55:0] a;
            logic [2:0] c;
            a = pixel_fire ? (byte_acc >> 24) : byte_acc;
            c = pixel_fire ? (byte_count - 3) : byte_count;
            frame_done <= #1 1'b0;

            if (s_valid && s_ready) begin
                a = a | ({24'd0, s_data} << (8 * c));
                c = c + 4;
            end
            byte_acc   <= #1 a;
            byte_count <= #1 c;

            if (pixel_fire) begin
                if (col == FRAME_W - 1) begin
                    col <= #1 '0;
                    if (ring_row == RING_ROWS - 1) ring_row <= #1 '0;
                    else                           ring_row <= #1 ring_row + 1'b1;
                    rows_received <= #1 rows_received + 1'b1;
                    if (rows_received == FRAME_H - 1) begin
                        frame_complete <= #1 1'b1;
                        frame_done <= #1 1'b1;
                    end
                end else begin
                    col <= #1 col + 1'b1;
                end
            end
        end
    end
endmodule
