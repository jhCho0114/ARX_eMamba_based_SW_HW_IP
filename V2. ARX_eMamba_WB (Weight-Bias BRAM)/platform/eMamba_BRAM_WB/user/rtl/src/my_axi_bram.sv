`timescale 1ns / 1ps

// RVX AXI controller + inferred true-dual-port block RAM.
// Requires ERVP_SPSRAM_CONTROLLER_AXI and its RVX library dependencies.
// Port A: RVX AXI. Port B: connect directly to eMamba's BRAM_IN_* pins.
// Both ports use DATA_WIDTH bits. Insert an AXI width adapter upstream
// when connecting a wider bus (the test_video system SRAM bus is 128-bit).
// Addresses presented to the controller must be local to this memory window.
// BRAM_IN_addr is a local BYTE address; low byte-offset bits are ignored.
// Default storage: 32 KiB = 8192 x 32-bit words, matching a 15-bit byte address.
// BRAM inference must be checked in Vivado; this is not a Xilinx IP instance.
//
// Ownership: finish AXI writes before starting Mamba, and wait for Mamba
// completion before reading its results. Concurrent writes to the same word,
// or reading a word while the other port writes it, have undefined results.
// Independent clocks are permitted by the RAM template, but ownership/control
// crossings still require synchronization. Initially use the same clock.
module my_axi_bram #(
    parameter integer AXI_ADDR_WIDTH = 32,
    parameter integer AXI_ID_WIDTH   = 4,
    parameter integer DATA_WIDTH     = 32,
    parameter integer BRAM_ADDR_WIDTH = 15
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
    input  wire [DATA_WIDTH-1:0]         BRAM_IN_din,
    input  wire [DATA_WIDTH/8-1:0]       BRAM_IN_we,
    output reg  [DATA_WIDTH-1:0]         BRAM_IN_dout
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
    reg  [DATA_WIDTH-1:0] cell_rdata;
    wire [INDEX_WIDTH-1:0] bram_index = BRAM_IN_addr >> BYTE_SHIFT;

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

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Read-first, synchronous output; no reset of the memory array.
    // Separate always blocks are intentional for true-dual-port RAM inference.
    always @(posedge clk) begin : port_a
        integer lane;
        if (rstnn) begin
            for (lane = 0; lane < BYTE_LANES; lane = lane + 1)
                if (cell_wenable && cell_wenable_byte[lane])
                    mem[cell_index][8*lane +: 8] <= cell_wdata[8*lane +: 8];
            if (cell_renable)
                cell_rdata <= mem[cell_index];
        end
    end

    // Reset clears only the output register, not memory contents.
    // Writes remain controlled by EN/WE even when the output is being reset.
    always @(posedge BRAM_IN_clk) begin : port_b
        integer lane;
        if (BRAM_IN_en) begin
            for (lane = 0; lane < BYTE_LANES; lane = lane + 1)
                if (BRAM_IN_we[lane])
                    mem[bram_index][8*lane +: 8] <= BRAM_IN_din[8*lane +: 8];
            if (BRAM_IN_rst)
                BRAM_IN_dout <= {DATA_WIDTH{1'b0}};
            else
                BRAM_IN_dout <= mem[bram_index];
        end
    end

    // synthesis translate_off
    initial begin
        if (DATA_WIDTH < 32 || DATA_WIDTH > 1024 ||
            (DATA_WIDTH & (DATA_WIDTH - 1)) != 0)
            $fatal(1, "DATA_WIDTH must be a power of two from 32 to 1024");
        if (BRAM_ADDR_WIDTH <= BYTE_SHIFT || BRAM_ADDR_WIDTH > 30)
            $fatal(1, "Invalid BRAM_ADDR_WIDTH");
        if (AXI_ADDR_WIDTH < BRAM_ADDR_WIDTH || AXI_ID_WIDTH < 1)
            $fatal(1, "Invalid AXI address or ID width");
    end
    // synthesis translate_on
endmodule
