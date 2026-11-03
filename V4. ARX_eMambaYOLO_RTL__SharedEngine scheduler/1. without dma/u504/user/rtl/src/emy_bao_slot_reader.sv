`timescale 1ns/1ps
// Private U_201 Bao helper.  Kept under a unique name so it can coexist with
// the legacy emy_slot_reader in emy_ip_core.sv.
module emy_bao_slot_reader #(
    parameter integer AW = 15
)(
    input  logic clk,
    input  logic nRst,
    input  logic restart,
    input  logic [AW-1:0] len0,
    input  logic [AW-1:0] len1,
    input  logic [1:0] full,
    output logic [1:0] take,
    output logic bram_en,
    output logic [AW-1:0] bram_addr,
    input  logic [31:0] bram_dout,
    output logic [31:0] m_data,
    output logic m_valid,
    input  logic m_ready
);
    logic cur;
    logic [AW-3:0] idx;
    logic [AW-2:0] nwords;
    logic inflight;
    logic [31:0] d0, d1;
    logic [1:0] cnt;
    logic pop, room, issue, last, skip;

    assign nwords    = cur ? len1[AW-1:2] : len0[AW-1:2];
    assign m_valid   = (cnt != 0);
    assign m_data    = d0;
    assign pop       = m_valid && m_ready;
    assign room      = ({1'b0, cnt} + inflight - pop) <= 3'd1;
    assign skip      = full[cur] && (nwords == 0) && !restart;
    assign issue     = full[cur] && (nwords != 0) && room && !restart;
    assign last      = issue && ({1'b0, idx} == nwords - 1'b1);
    assign bram_en   = issue;
    assign bram_addr = {cur, idx[AW-4:0], 2'b00};
    assign take      = (last || skip) ? (cur ? 2'b10 : 2'b01) : 2'b00;

    always @(posedge clk) begin
        if (!nRst || restart) begin
            cur      <= #1 1'b0;
            idx      <= #1 '0;
            inflight <= #1 1'b0;
        end else begin
            inflight <= #1 issue;
            if (last || skip) begin
                cur <= #1 ~cur;
                idx <= #1 '0;
            end else if (issue) begin
                idx <= #1 idx + 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (!nRst || restart) begin
            cnt <= #1 '0;
            d0  <= #1 '0;
            d1  <= #1 '0;
        end else begin
            case ({inflight, pop})
                2'b10: begin
                    if (cnt == 0) d0 <= #1 bram_dout;
                    else          d1 <= #1 bram_dout;
                    cnt <= #1 cnt + 1'b1;
                end
                2'b01: begin
                    d0  <= #1 d1;
                    cnt <= #1 cnt - 1'b1;
                end
                2'b11: begin
                    if (cnt == 1) d0 <= #1 bram_dout;
                    else begin d0 <= #1 d1; d1 <= #1 bram_dout; end
                end
                default: ;
            endcase
        end
    end
endmodule
