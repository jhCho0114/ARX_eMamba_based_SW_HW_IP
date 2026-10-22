`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Wb_Row_Loader
// Description: turns the weight broadcast of one window into whole-row writes, so the caller can
//              keep the window in a RAM of ROWS rows (one write port, the row as the word):
//                  if (we) mem[row] <= data;
//              The window is ROWS rows of ROW_WORDS words from byte address BASE; a row's bytes
//              are in ascending address order (lowest byte = lowest index), and data holds the
//              first ROW_BITS bits of the row.
//
//   Like the eMamba loaders, the words are counted, not decoded from the address: the broadcast
//   sends the window in ascending word order, and a write to BASE restarts the count (so a second
//   broadcast reloads it).  The first ROW_WORDS - 1 words of a row wait in a register; the last
//   one goes straight into data with them.
//////////////////////////////////////////////////////////////////////////////////
module Wb_Row_Loader #(
    parameter integer WB_ADDR_W = 24,
    parameter integer BASE      = 0,
    parameter integer ROWS      = 1,
    parameter integer ROW_WORDS = 1,
    parameter integer ROW_BITS  = 32       // <= 32 * ROW_WORDS
)(
    clk,
    nRst,

    wb_valid,
    wb_addr,
    wb_data,

    we,
    row,
    data
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer ROW_W  = ($clog2(ROWS) > 0) ? $clog2(ROWS) : 1;
localparam integer WORD_W = ($clog2(ROW_WORDS) > 0) ? $clog2(ROW_WORDS) : 1;
localparam integer BUF_W  = (ROW_WORDS > 1) ? 32 * (ROW_WORDS - 1) : 1;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic                 clk, nRst;
input  logic                 wb_valid;
input  logic [WB_ADDR_W-1:0] wb_addr;
input  logic [31:0]          wb_data;
output logic                 we;
output logic [ROW_W-1:0]     row;
output logic [ROW_BITS-1:0]  data;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic [ROW_W-1:0]  row_cnt;
logic [WORD_W-1:0] word_cnt, word_now;
logic              hit, first, last;

generate
    if (ROW_BITS > 32 * ROW_WORDS)
        $error("Wb_Row_Loader: ROW_BITS = %0d is more than the %0d words of a row", ROW_BITS, ROW_WORDS);
    if (64'(BASE) + 64'(ROWS) * ROW_WORDS * 4 > (64'd1 << WB_ADDR_W))
        $error("Wb_Row_Loader: the window does not fit the %0d-bit WB address", WB_ADDR_W);
endgenerate

assign hit      = wb_valid && (wb_addr >= BASE) && (64'(wb_addr) < 64'(BASE) + 64'(ROWS) * ROW_WORDS * 4);
assign first    = hit && (wb_addr == BASE);
assign word_now = first ? '0 : word_cnt;
assign row      = first ? '0 : row_cnt;
assign last     = (word_now == ROW_WORDS - 1);
assign we       = hit && last;

// [xsim] the waiting words as a word array, and data assembled word by word: xsim (2025.2, Windows) garbled a
// 1535-word row written as row_buf[word_now * 32 +: 32] and returned garbage for full[ROW_BITS-1:0] of the
// 49k-bit vector. The array form is also the shape synthesis maps to distributed RAM.
generate
    if (ROW_WORDS > 1) begin: Multi
        localparam integer TAIL = ROW_BITS - 32 * (ROW_WORDS - 1);     // bits of the last word that belong to the row
        logic [31:0] row_words [0:ROW_WORDS-2];
        for (genvar gw = 0; gw < ROW_WORDS - 1; gw = gw + 1) begin: Word
            assign data[gw * 32 +: 32] = row_words[gw];
        end
        assign data[ROW_BITS-1:32 * (ROW_WORDS - 1)] = wb_data[TAIL-1:0];
        always @(posedge clk) if (hit && !last) row_words[word_now] <= #1 wb_data;
        if (TAIL < 1)
            $error("Wb_Row_Loader: ROW_BITS = %0d fits in fewer than %0d words", ROW_BITS, ROW_WORDS);
    end else begin: Single
        assign data = wb_data[ROW_BITS-1:0];
    end
endgenerate

always @(posedge clk) begin
    if (!nRst) begin
        row_cnt  <= #1 '0;
        word_cnt <= #1 '0;
    end else if (hit) begin
        word_cnt <= #1 last ? '0 : word_now + 1'b1;
        row_cnt  <= #1 last ? row + 1'b1 : row;
    end
end

endmodule
