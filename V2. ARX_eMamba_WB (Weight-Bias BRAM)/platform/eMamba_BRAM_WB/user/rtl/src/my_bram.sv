`timescale 1ns / 1ps

module my_bram #(
    parameter integer WIDTH = 32,
    parameter integer DEPTH = 128,
    parameter integer AW    = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic             clk,
    input  logic             nRst,     // [J-unopt-reset] dout_a/dout_b 리셋용 (mem 자체는 BRAM 이라 리셋 안 함)

    // ---------- port A : 넣는 문 (S_AXI) ----------
    input  logic             we_a,
    input  logic [AW-1:0]    addr_a,
    input  logic [WIDTH-1:0] din_a,
    input  logic             en_a,     // AXI readback 읽기 인에이블
    output logic [WIDTH-1:0] dout_a,

    // ---------- port B : 빼는 문 (코어) ----------
    input  logic             en_b,
    input  logic [AW-1:0]    addr_b,
    output logic [WIDTH-1:0] dout_b
);

    (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

    // port A : 쓰기 + 동기 읽기 (write 와 read 가 같은 주소면 read-first)
    always_ff @(posedge clk) begin
        if (we_a) mem[addr_a] <= din_a;
        if (!nRst)     dout_a <= '0;                // [J-unopt-reset]
        else if (en_a) dout_a <= mem[addr_a];       // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
        // if (en_a) dout_a      <= mem[addr_a];
        // ↑ 삭제 : [J-unopt-reset] 위 if/else 로 교체
    end

    // port B : 동기 읽기 전용. "빼는 것" 은 이 두 줄이 전부.
    always_ff @(posedge clk) begin
        if (!nRst)     dout_b <= '0;                // [J-unopt-reset]
        else if (en_b) dout_b <= mem[addr_b];       // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
    end

endmodule
