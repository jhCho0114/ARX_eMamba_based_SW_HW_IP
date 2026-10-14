`timescale 1ns / 1ps

module wb_broadcast_loader #(
    parameter integer AXI_WIDTH = 32,
    parameter integer BRAM_WB_SIZE = 32'd19440,
    parameter integer WB_BRAM_ADDR_W = 15
)(
    clk,
    nRst,

    wb_load,

    bram_en,
    bram_rd_addr,
    bram_rd_data,

    wb_valid,
    wb_addr,
    wb_data,

    wb_done
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input  logic              clk, nRst;
input  logic              wb_load;

output logic              bram_en;
output logic [WB_BRAM_ADDR_W-1:0] bram_rd_addr;
input  logic [AXI_WIDTH-1:0] bram_rd_data;

output logic              wb_valid;
output logic [WB_BRAM_ADDR_W-1:0] wb_addr;
output logic [AXI_WIDTH-1:0] wb_data;

output logic              wb_done;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// 
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// axi bram 에 wb 가 준비 되어있으니까 모델에 읽어들이기 시작하는 posedge 디텍터
logic wb_load_d;
logic start;

always @(posedge clk) begin
    if (!nRst) wb_load_d <= #1 1'b0;
    else       wb_load_d <= #1 wb_load;
end
assign start = wb_load & ~wb_load_d;
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// 
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
logic busy;
logic last_word;
logic [WB_BRAM_ADDR_W-1:0] addr_counter; //8192 - 13bit

assign bram_en = busy;
assign last_word = busy & (addr_counter == BRAM_WB_SIZE - 'd4);

always @(posedge clk) begin
    if (!nRst) busy <= #1 1'b0;
    else begin 
        if (start) busy <= #1 1'b1; 
        else if (last_word) busy <= #1 1'b0;
        else busy <= #1 busy;
    end
end

always @(posedge clk) begin
    if (!nRst )         addr_counter <= #1 'd0;
    else begin 
        if (start)     addr_counter <= #1 'd0;
        else if (busy)  addr_counter <= #1 addr_counter + 'd4;
        else  addr_counter <= #1 addr_counter;
    end
end

assign bram_rd_addr = addr_counter;

// ========== ========== ========== ========== ========== ========== ========== 
// 
// ========== ========== ========== ========== ========== ========== ========== 

logic en_d1;
logic [WB_BRAM_ADDR_W-1:0] addr_d1;

// 여기서 bram latency 1 딜레이줘
always @(posedge clk) begin
    if (!nRst ) begin
        en_d1 <= #1 'd0;
        addr_d1 <= #1 'd0;
    end else begin
        en_d1 <= #1 busy;
        addr_d1 <= #1 addr_counter;
    end
end

//딜레이 준 addr과 막 나온 data 함께 내려보내
always @(posedge clk) begin
    if (!nRst) begin
        wb_valid <= #1 'd0;
        wb_addr <= #1 'd0;
        wb_data <= #1 'd0;
    end else begin
        wb_valid <= #1 en_d1;
        wb_addr <= #1 addr_d1;
        wb_data <= #1 bram_rd_data;
    end
end

// ========== ========== ========== ========== ========== ========== ========== 
// 
// ========== ========== ========== ========== ========== ========== ========== 

// riscv 가 axi로 읽어갈 때 wb가 준비 되었는 지 알 방법이야
// [J-WBPIPE] 수신기마다 stage0/stage1 FF 가 들어가서 실제 쓰기가 2클럭 늦게 끝나.
//            wb_done 도 2클럭 지연시켜 마지막 수신기의 쓰기 완료 이후에 뜨게 맞춤.
logic wb_done_i, wb_done_d1;

always @(posedge clk) begin
    if (!nRst) wb_done_i <= #1 'd0;
    else begin
        if (start) wb_done_i <= #1 'd0;
        else if (wb_valid && (wb_addr == BRAM_WB_SIZE - 'd4) ) wb_done_i <= #1 'd1;
        else wb_done_i <= #1 wb_done_i;
    end
end

always @(posedge clk) begin
    if (!nRst || start) begin                 // start 에서 즉시 내려서 이전 done 이 2클럭 더 보이지 않게
        wb_done_d1 <= #1 'd0;
        wb_done    <= #1 'd0;
    end else begin
        wb_done_d1 <= #1 wb_done_i;
        wb_done    <= #1 wb_done_d1;
    end
end
endmodule