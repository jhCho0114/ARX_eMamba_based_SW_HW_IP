`timescale 1ns / 1ps
// 32-bit RVX AXI / 512-bit native BRAM memory, default capacity 8 KiB.
// Requires ERVP_SPSRAM_CONTROLLER_AXI. DATA_WIDTH is fixed to 32.
// Sixteen 32-bit banks accept one complete Mamba output row per clock.
// Byte layout: native DIN[31:0] is CPU word 0, DIN[63:32] is word 1, etc.
// CPU byte offset = 64 * row + 4 * bank + byte_in_word.
// AXI and native accesses must not race on a word being written.
// Native reset clears read outputs only, when EN is asserted; not storage.
// RAMB inference and the external RVX controller still require verification.
module my_axi_bram_output #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_ID_WIDTH   = 4,
    parameter integer DATA_WIDTH     = 32,
    parameter integer BRAM_ADDR_WIDTH = 13
) (
    input  wire                         clk,
    input  wire                         rstnn,

    input  wire [AXI_ID_WIDTH-1:0]       rxawid,
    input  wire [AXI_ADDR_WIDTH-1:0]     rxawaddr,
    input  wire [7:0]                    rxawlen,
    input  wire [2:0]                    rxawsize,
    input  wire [1:0]                    rxawburst,
    input  wire                         rxawvalid,
    output wire                         rxawready,

    // RVX's axi interface includes WID; do not confuse it with plain AXI4.
    input  wire [AXI_ID_WIDTH-1:0]       rxwid,
    input  wire [DATA_WIDTH-1:0]         rxwdata,
    input  wire [DATA_WIDTH/8-1:0]       rxwstrb,
    input  wire                         rxwlast,
    input  wire                         rxwvalid,
    output wire                         rxwready,

    output wire [AXI_ID_WIDTH-1:0]       rxbid,
    output wire [1:0]                    rxbresp,
    output wire                         rxbvalid,
    input  wire                         rxbready,

    input  wire [AXI_ID_WIDTH-1:0]       rxarid,
    input  wire [AXI_ADDR_WIDTH-1:0]     rxaraddr,
    input  wire [7:0]                    rxarlen,
    input  wire [2:0]                    rxarsize,
    input  wire [1:0]                    rxarburst,
    input  wire                         rxarvalid,
    output wire                         rxarready,

    output wire [AXI_ID_WIDTH-1:0]       rxrid,
    output wire [DATA_WIDTH-1:0]         rxrdata,
    output wire [1:0]                    rxrresp,
    output wire                         rxrlast,
    output wire                         rxrvalid,
    input  wire                         rxrready,

    // Directions are opposite to the corresponding eMamba master pins.
    input  wire                         BRAM_IN_clk,
    input  wire                         BRAM_IN_rst,
    input  wire                         BRAM_IN_en,
    input  wire [BRAM_ADDR_WIDTH-1:0]    BRAM_IN_addr,
    input  wire [511:0]                  BRAM_IN_din,
    input  wire [63:0]                   BRAM_IN_we,
    output wire [511:0]                  BRAM_IN_dout
);
    localparam integer BYTE_LANES = DATA_WIDTH / 8;
    localparam integer BYTE_SHIFT = $clog2(BYTE_LANES);
    localparam integer INDEX_WIDTH = BRAM_ADDR_WIDTH - BYTE_SHIFT;
    localparam integer DEPTH = 2 ** INDEX_WIDTH;
    localparam integer CAPACITY_BYTES = 2 ** BRAM_ADDR_WIDTH;

    wire [INDEX_WIDTH-1:0] cell_index;
    wire cell_wenable;
    wire [BYTE_LANES-1:0] cell_wenable_byte;
    wire [DATA_WIDTH-1:0] cell_wdata;
    wire cell_renable;
    wire [DATA_WIDTH-1:0] cell_rdata;

    ERVP_SPSRAM_CONTROLLER_AXI #(
        .BW_ADDR(AXI_ADDR_WIDTH),
        .BW_DATA(DATA_WIDTH),
        .BW_AXI_TID(AXI_ID_WIDTH),
        .BASEADDR(0),
        .CELL_SIZE(CAPACITY_BYTES),
        .CELL_WIDTH(DATA_WIDTH),
        .NUM_CELL(1)
    ) i_controller (
        .clk(clk),
        .rstnn(rstnn),
        .enable(1'b1),
        .rxawid(rxawid), .rxawaddr(rxawaddr),
        .rxawlen(rxawlen), .rxawsize(rxawsize),
        .rxawburst(rxawburst), .rxawvalid(rxawvalid), .rxawready(rxawready),
        .rxwid(rxwid), .rxwdata(rxwdata), .rxwstrb(rxwstrb),
        .rxwlast(rxwlast), .rxwvalid(rxwvalid), .rxwready(rxwready),
        .rxbid(rxbid), .rxbresp(rxbresp),
        .rxbvalid(rxbvalid), .rxbready(rxbready),
        .rxarid(rxarid), .rxaraddr(rxaraddr),
        .rxarlen(rxarlen), .rxarsize(rxarsize),
        .rxarburst(rxarburst), .rxarvalid(rxarvalid), .rxarready(rxarready),
        .rxrid(rxrid), .rxrdata(rxrdata), .rxrresp(rxrresp),
        .rxrlast(rxrlast), .rxrvalid(rxrvalid), .rxrready(rxrready),
        .sscell_select_list(),
        .sscell_index_list(cell_index),
        .sscell_enable_list(),
        .sscell_wenable_list(cell_wenable),
        .sscell_wenable_byte_list(cell_wenable_byte),
        .sscell_wenable_bit_list(),
        .sscell_wdata_list(cell_wdata),
        .sscell_renable_list(cell_renable),
        .sscell_rdata_list(cell_rdata),
        .sscell_stall_list(1'b0)
    );


    localparam integer ROW_WIDTH = BRAM_ADDR_WIDTH - 6;
    localparam integer ROWS = 2 ** ROW_WIDTH;
    wire [ROW_WIDTH-1:0] native_row = BRAM_IN_addr[BRAM_ADDR_WIDTH-1:6];
    wire [ROW_WIDTH-1:0] axi_row = cell_index[INDEX_WIDTH-1:4];
    wire [3:0] axi_bank = cell_index[3:0];
    wire [31:0] bank_rdata [0:15];
    reg [3:0] read_bank;

    // Register the bank together with its synchronous read, adding no
    // extra latency relative to the controller's original memory cell.
    always @(posedge clk) begin
        if (!rstnn)
            read_bank <= 4'b0;
        else if (cell_renable)
            read_bank <= axi_bank;
    end
    assign cell_rdata = bank_rdata[read_bank];

    genvar bank;
    generate
        for (bank = 0; bank < 16; bank = bank + 1) begin : banks
            (* ram_style = "block" *) reg [31:0] mem [0:ROWS-1];
            reg [31:0] a_read;
            reg [31:0] b_read;
            assign bank_rdata[bank] = a_read;
            assign BRAM_IN_dout[32*bank +: 32] = b_read;

            always @(posedge clk) begin : port_a
                integer lane;
                if (rstnn && axi_bank == bank) begin
                    for (lane = 0; lane < 4; lane = lane + 1)
                        if (cell_wenable && cell_wenable_byte[lane])
                            mem[axi_row][8*lane +: 8] <= cell_wdata[8*lane +: 8];
                    if (cell_renable)
                        a_read <= mem[axi_row];
                end
            end

            always @(posedge BRAM_IN_clk) begin : port_b
                integer lane;
                if (BRAM_IN_en) begin
                    for (lane = 0; lane < 4; lane = lane + 1)
                        if (BRAM_IN_we[4*bank + lane])
                            mem[native_row][8*lane +: 8] <=
                                BRAM_IN_din[32*bank + 8*lane +: 8];
                    if (BRAM_IN_rst)
                        b_read <= 32'b0;
                    else
                        b_read <= mem[native_row];
                end
            end
        end
    endgenerate

endmodule

