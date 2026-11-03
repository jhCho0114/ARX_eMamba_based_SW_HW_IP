/*****************/
/* Custom Region */
/*****************/

// wire clk_core;
// wire clk_system;
// wire clk_system_external;
// wire clk_system_debug;
// wire clk_local_access;
// wire clk_process_000;
// wire clk_dram_if;
// wire clk_dram_sys;
// wire clk_dram_ref;
// wire clk_noc;
// wire clk_25M;
// wire clk_50M;
// wire clk_150M;
// wire clk_200M;
// wire clk_300M;
// wire gclk_core;
// wire gclk_system;
// wire gclk_system_external;
// wire gclk_system_debug;
// wire gclk_local_access;
// wire gclk_process_000;
// wire gclk_noc;
// wire gclk_25M;
// wire gclk_50M;
// wire gclk_150M;
// wire gclk_200M;
// wire gclk_300M;
// wire tick_1us;
// wire tick_62d5ms;
// wire tick_gpio;
// wire spi_common_sclk;
// wire spi_common_sdq0;
// wire global_rstnn;
// wire global_rstpp;
// wire [(7)-1:0] rstnn_seqeunce;
// wire [(7)-1:0] rstpp_seqeunce;
// wire rstnn_user;
// wire rstpp_user;
// wire eMamba_IP_clk;
// wire eMamba_IP_rstnn;
// wire eMamba_IP_rx4awready;
// wire eMamba_IP_rx4awvalid;
// wire [(32)-1:0] eMamba_IP_rx4awaddr;
// wire [(1)-1:0] eMamba_IP_rx4awid;
// wire [(8)-1:0] eMamba_IP_rx4awlen;
// wire [(3)-1:0] eMamba_IP_rx4awsize;
// wire [(2)-1:0] eMamba_IP_rx4awburst;
// wire eMamba_IP_rx4wready;
// wire eMamba_IP_rx4wvalid;
// wire [(32)-1:0] eMamba_IP_rx4wdata;
// wire [(32/8)-1:0] eMamba_IP_rx4wstrb;
// wire eMamba_IP_rx4wlast;
// wire eMamba_IP_rx4bready;
// wire eMamba_IP_rx4bvalid;
// wire [(1)-1:0] eMamba_IP_rx4bid;
// wire [(2)-1:0] eMamba_IP_rx4bresp;
// wire eMamba_IP_rx4arready;
// wire eMamba_IP_rx4arvalid;
// wire [(32)-1:0] eMamba_IP_rx4araddr;
// wire [(1)-1:0] eMamba_IP_rx4arid;
// wire [(8)-1:0] eMamba_IP_rx4arlen;
// wire [(3)-1:0] eMamba_IP_rx4arsize;
// wire [(2)-1:0] eMamba_IP_rx4arburst;
// wire eMamba_IP_rx4rready;
// wire eMamba_IP_rx4rvalid;
// wire [(1)-1:0] eMamba_IP_rx4rid;
// wire [(32)-1:0] eMamba_IP_rx4rdata;
// wire eMamba_IP_rx4rlast;
// wire [(2)-1:0] eMamba_IP_rx4rresp;
// wire input_bram_clk;
// wire input_bram_rstnn;
// wire input_bram_rxawready;
// wire input_bram_rxawvalid;
// wire [(32)-1:0] input_bram_rxawaddr;
// wire [(1)-1:0] input_bram_rxawid;
// wire [(8)-1:0] input_bram_rxawlen;
// wire [(3)-1:0] input_bram_rxawsize;
// wire [(2)-1:0] input_bram_rxawburst;
// wire input_bram_rxwready;
// wire input_bram_rxwvalid;
// wire [(1)-1:0] input_bram_rxwid;
// wire [(32)-1:0] input_bram_rxwdata;
// wire [(32/8)-1:0] input_bram_rxwstrb;
// wire input_bram_rxwlast;
// wire input_bram_rxbready;
// wire input_bram_rxbvalid;
// wire [(1)-1:0] input_bram_rxbid;
// wire [(2)-1:0] input_bram_rxbresp;
// wire input_bram_rxarready;
// wire input_bram_rxarvalid;
// wire [(32)-1:0] input_bram_rxaraddr;
// wire [(1)-1:0] input_bram_rxarid;
// wire [(8)-1:0] input_bram_rxarlen;
// wire [(3)-1:0] input_bram_rxarsize;
// wire [(2)-1:0] input_bram_rxarburst;
// wire input_bram_rxrready;
// wire input_bram_rxrvalid;
// wire [(1)-1:0] input_bram_rxrid;
// wire [(32)-1:0] input_bram_rxrdata;
// wire input_bram_rxrlast;
// wire [(2)-1:0] input_bram_rxrresp;
// wire wb_bram_clk;
// wire wb_bram_rstnn;
// wire wb_bram_rxawready;
// wire wb_bram_rxawvalid;
// wire [(32)-1:0] wb_bram_rxawaddr;
// wire [(1)-1:0] wb_bram_rxawid;
// wire [(8)-1:0] wb_bram_rxawlen;
// wire [(3)-1:0] wb_bram_rxawsize;
// wire [(2)-1:0] wb_bram_rxawburst;
// wire wb_bram_rxwready;
// wire wb_bram_rxwvalid;
// wire [(1)-1:0] wb_bram_rxwid;
// wire [(32)-1:0] wb_bram_rxwdata;
// wire [(32/8)-1:0] wb_bram_rxwstrb;
// wire wb_bram_rxwlast;
// wire wb_bram_rxbready;
// wire wb_bram_rxbvalid;
// wire [(1)-1:0] wb_bram_rxbid;
// wire [(2)-1:0] wb_bram_rxbresp;
// wire wb_bram_rxarready;
// wire wb_bram_rxarvalid;
// wire [(32)-1:0] wb_bram_rxaraddr;
// wire [(1)-1:0] wb_bram_rxarid;
// wire [(8)-1:0] wb_bram_rxarlen;
// wire [(3)-1:0] wb_bram_rxarsize;
// wire [(2)-1:0] wb_bram_rxarburst;
// wire wb_bram_rxrready;
// wire wb_bram_rxrvalid;
// wire [(1)-1:0] wb_bram_rxrid;
// wire [(32)-1:0] wb_bram_rxrdata;
// wire wb_bram_rxrlast;
// wire [(2)-1:0] wb_bram_rxrresp;
// wire output_bram_clk;
// wire output_bram_rstnn;
// wire output_bram_rxawready;
// wire output_bram_rxawvalid;
// wire [(32)-1:0] output_bram_rxawaddr;
// wire [(1)-1:0] output_bram_rxawid;
// wire [(8)-1:0] output_bram_rxawlen;
// wire [(3)-1:0] output_bram_rxawsize;
// wire [(2)-1:0] output_bram_rxawburst;
// wire output_bram_rxwready;
// wire output_bram_rxwvalid;
// wire [(1)-1:0] output_bram_rxwid;
// wire [(32)-1:0] output_bram_rxwdata;
// wire [(32/8)-1:0] output_bram_rxwstrb;
// wire output_bram_rxwlast;
// wire output_bram_rxbready;
// wire output_bram_rxbvalid;
// wire [(1)-1:0] output_bram_rxbid;
// wire [(2)-1:0] output_bram_rxbresp;
// wire output_bram_rxarready;
// wire output_bram_rxarvalid;
// wire [(32)-1:0] output_bram_rxaraddr;
// wire [(1)-1:0] output_bram_rxarid;
// wire [(8)-1:0] output_bram_rxarlen;
// wire [(3)-1:0] output_bram_rxarsize;
// wire [(2)-1:0] output_bram_rxarburst;
// wire output_bram_rxrready;
// wire output_bram_rxrvalid;
// wire [(1)-1:0] output_bram_rxrid;
// wire [(32)-1:0] output_bram_rxrdata;
// wire output_bram_rxrlast;
// wire [(2)-1:0] output_bram_rxrresp;

/* DO NOT MODIFY THE ABOVE */
/* MUST MODIFY THE BELOW   */


// eMambaYOLO cluster (U_504, 2026-10-21; RTL = ../src, copied from U_504/u504_host/sources_1/new — keep them identical):
// AXI BRAM slaves (input / wb / output) + eMambaYOLO_IP (shared engine v2, L00-L21 with the Detect head (a) on the engine,
// output-adapter candidate filter (U_403, A-plan) and the DET-mode head math (U_504, B-plan: emy_head_math + emy_dfl_side x 4,
// sigmoid / DFL / box corners in the adapter)). Same pins, parameters and wiring as U_403 (u301_user_region.vh) and U_203_npx
// (u202_emambayolo_user_region.vh); the IP's external ports did not change, only its contents (S_AXI FILTER register 0x38).
// IP parameters: IMG 198,992 lines = 184,320 in URAM (45 x 4) + 14,672 in the emy_buf BRAM extension (192,512 / URAM 288 =
// 100 % failed placement on 2026-10-19, Place 30-365, URAM cascades); BRAM_OUT 3 rows / pixel = 19,200 / 4,800 / 1,200 rows
// per frame when the filter is off.
// Port B of the three BRAMs is wired straight into eMambaYOLO_IP, so all four share one clock. The four IPs are
// *_clkout in the xml, so the user region drives their clk; RVX puts asynchronous NIs between them and gclk_noc.
//   clk_core = 100 MHz (PLL), same as i_main_core.
// CPU side (U_504/u504_host/docs/CPU_SEQUENCE.md): boot stream boot.bin 6,400,512 B (program 32 KB + engine image) through
// wb_bram in 16 KB slots (391 chunks), then FILTER once, then START per frame; frame 1,228,800 B through input_bram
// (75 chunks); output rows 64 B through output_bram slots (P3 0x0000 / 0x0800, P4 0x1000 / 0x1400, P5 0x1800 / 0x1C00).
//   FILTER = 0xFCFEFC00 (reset, off)      : all 25,200 rows per frame (app u301 / u301_Gamma style)
//   FILTER = 0xFCFEFC01 (EN)              : (META, box) row pair per candidate + 1 END row per head -> 201 rows (app u504_alpha = u301_Delta)
//   FILTER = 0xFCFEFC03 (EN | DET_EN)     : one DET row per candidate (conf, x1 y1 x2 y2 in 1/16 px) + END rows -> 102 rows (app u504_epsilon)
//   FILTER = 0xFCFEFC07 (EN|DET_EN|NMS_EN): NMS in the adapter (emy_nms), detection rows (fmt 0x03) through head 0 + END rows -> 23 rows (app u504_zeta)
// Row formats: CPU_SEQUENCE.md section 5; the CPU reads a slot only up to its END row.

wire        in_clk, in_rst, in_en;
wire [14:0] in_addr;
wire [31:0] in_din, in_dout;
wire [3:0]  in_we;

wire        wb_clk, wb_rst, wb_en;
wire [14:0] wb_addr;
wire [31:0] wb_din, wb_dout;
wire [3:0]  wb_we;

wire         out_clk, out_rst, out_en;
wire [12:0]  out_addr;
wire [511:0] out_din, out_dout;
wire [63:0]  out_we;

assign eMamba_IP_clk   = clk_core;
assign input_bram_clk  = clk_core;
assign wb_bram_clk     = clk_core;
assign output_bram_clk = clk_core;

// input_bram : 0x8000 (32 KB), CPU writes frame chunks, IP reads (slot 0 / 1 = 16 KB each)
my_axi_bram #(
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(1),
    .DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(15)
) u_input_bram (
    .clk(input_bram_clk),
    .rstnn(input_bram_rstnn),
    .rxawid(input_bram_rxawid),
    .rxawaddr({17'b0, input_bram_rxawaddr[14:0]}),
    .rxawlen(input_bram_rxawlen),
    .rxawsize(input_bram_rxawsize),
    .rxawburst(input_bram_rxawburst),
    .rxawvalid(input_bram_rxawvalid),
    .rxawready(input_bram_rxawready),
    .rxwid(input_bram_rxwid),
    .rxwdata(input_bram_rxwdata),
    .rxwstrb(input_bram_rxwstrb),
    .rxwlast(input_bram_rxwlast),
    .rxwvalid(input_bram_rxwvalid),
    .rxwready(input_bram_rxwready),
    .rxbid(input_bram_rxbid),
    .rxbresp(input_bram_rxbresp),
    .rxbvalid(input_bram_rxbvalid),
    .rxbready(input_bram_rxbready),
    .rxarid(input_bram_rxarid),
    .rxaraddr({17'b0, input_bram_rxaraddr[14:0]}),
    .rxarlen(input_bram_rxarlen),
    .rxarsize(input_bram_rxarsize),
    .rxarburst(input_bram_rxarburst),
    .rxarvalid(input_bram_rxarvalid),
    .rxarready(input_bram_rxarready),
    .rxrid(input_bram_rxrid),
    .rxrdata(input_bram_rxrdata),
    .rxrresp(input_bram_rxrresp),
    .rxrlast(input_bram_rxrlast),
    .rxrvalid(input_bram_rxrvalid),
    .rxrready(input_bram_rxrready),

    .BRAM_IN_clk(in_clk),
    .BRAM_IN_rst(in_rst),
    .BRAM_IN_en(in_en),
    .BRAM_IN_addr(in_addr),
    .BRAM_IN_din(in_din),
    .BRAM_IN_we(in_we),
    .BRAM_IN_dout(in_dout)
);

// wb_bram : 0x8000 (32 KB), CPU writes boot-stream chunks (program + weight image), IP loads them into URAM / BRAM (same slot layout as input)
my_axi_bram #(
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(1),
    .DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(15)
) u_wb_bram (
    .clk(wb_bram_clk),
    .rstnn(wb_bram_rstnn),
    .rxawid(wb_bram_rxawid),
    .rxawaddr({17'b0, wb_bram_rxawaddr[14:0]}),
    .rxawlen(wb_bram_rxawlen),
    .rxawsize(wb_bram_rxawsize),
    .rxawburst(wb_bram_rxawburst),
    .rxawvalid(wb_bram_rxawvalid),
    .rxawready(wb_bram_rxawready),
    .rxwid(wb_bram_rxwid),
    .rxwdata(wb_bram_rxwdata),
    .rxwstrb(wb_bram_rxwstrb),
    .rxwlast(wb_bram_rxwlast),
    .rxwvalid(wb_bram_rxwvalid),
    .rxwready(wb_bram_rxwready),
    .rxbid(wb_bram_rxbid),
    .rxbresp(wb_bram_rxbresp),
    .rxbvalid(wb_bram_rxbvalid),
    .rxbready(wb_bram_rxbready),
    .rxarid(wb_bram_rxarid),
    .rxaraddr({17'b0, wb_bram_rxaraddr[14:0]}),
    .rxarlen(wb_bram_rxarlen),
    .rxarsize(wb_bram_rxarsize),
    .rxarburst(wb_bram_rxarburst),
    .rxarvalid(wb_bram_rxarvalid),
    .rxarready(wb_bram_rxarready),
    .rxrid(wb_bram_rxrid),
    .rxrdata(wb_bram_rxrdata),
    .rxrresp(wb_bram_rxrresp),
    .rxrlast(wb_bram_rxrlast),
    .rxrvalid(wb_bram_rxrvalid),
    .rxrready(wb_bram_rxrready),

    .BRAM_IN_clk(wb_clk),
    .BRAM_IN_rst(wb_rst),
    .BRAM_IN_en(wb_en),
    .BRAM_IN_addr(wb_addr),
    .BRAM_IN_din(wb_din),
    .BRAM_IN_we(wb_we),
    .BRAM_IN_dout(wb_dout)
);

// output_bram : 0x2000 (8 KB), IP writes 512-bit rows (P3 / P4 / P5 slots; 3 rows per pixel = box | cls 0-63 | cls 64-79 + 0), CPU reads
my_axi_bram_output #(
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(1),
    .DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(13)
) u_output_bram (
    .clk(output_bram_clk),
    .rstnn(output_bram_rstnn),
    .rxawid(output_bram_rxawid),
    .rxawaddr({19'b0, output_bram_rxawaddr[12:0]}),
    .rxawlen(output_bram_rxawlen),
    .rxawsize(output_bram_rxawsize),
    .rxawburst(output_bram_rxawburst),
    .rxawvalid(output_bram_rxawvalid),
    .rxawready(output_bram_rxawready),
    .rxwid(output_bram_rxwid),
    .rxwdata(output_bram_rxwdata),
    .rxwstrb(output_bram_rxwstrb),
    .rxwlast(output_bram_rxwlast),
    .rxwvalid(output_bram_rxwvalid),
    .rxwready(output_bram_rxwready),
    .rxbid(output_bram_rxbid),
    .rxbresp(output_bram_rxbresp),
    .rxbvalid(output_bram_rxbvalid),
    .rxbready(output_bram_rxbready),
    .rxarid(output_bram_rxarid),
    .rxaraddr({19'b0, output_bram_rxaraddr[12:0]}),
    .rxarlen(output_bram_rxarlen),
    .rxarsize(output_bram_rxarsize),
    .rxarburst(output_bram_rxarburst),
    .rxarvalid(output_bram_rxarvalid),
    .rxarready(output_bram_rxarready),
    .rxrid(output_bram_rxrid),
    .rxrdata(output_bram_rxrdata),
    .rxrresp(output_bram_rxrresp),
    .rxrlast(output_bram_rxrlast),
    .rxrvalid(output_bram_rxrvalid),
    .rxrready(output_bram_rxrready),

    .BRAM_IN_clk(out_clk),
    .BRAM_IN_rst(out_rst),
    .BRAM_IN_en(out_en),
    .BRAM_IN_addr(out_addr),
    .BRAM_IN_din(out_din),
    .BRAM_IN_we(out_we),
    .BRAM_IN_dout(out_dout)
);

// eMamba_IP slave : 0x800 register window (CTRL .. FILTER 0x38 .. CMD7, see S_AXI.sv header), upper address bits zeroed.
// Image / output parameters are the U_504 (= U_303) defaults, written out explicitly so the board build cannot drift from
// vectors/img (198,992 lines) and vectors/program (681 lines, out_cfg 19200 / 4800 / 1200). The adapter's head-grid widths
// (P3_W / P4_W / P5_W = 80 / 40 / 20, DET-mode corners) are its parameter defaults and are not passed through the IP.
eMambaYOLO_IP #(
    .BRAM_IN_ADDR_W(15),
    .BRAM_WB_ADDR_W(15),
    .BRAM_OUT_ADDR_W(13),
    .IMG_LINES(198992),
    .IMG_URAM_LINES(184320),
    .OUT_P3_ROWS(19200),
    .OUT_P4_ROWS(4800),
    .OUT_P5_ROWS(1200),
    .C_S_AXI_ID_WIDTH(1),
    .C_S_AXI_DATA_WIDTH(32),
    .C_S_AXI_ADDR_WIDTH(15)
) my_emambayolo_ip (
    .BRAM_IN_clk(in_clk),
    .BRAM_IN_rst(in_rst),
    .BRAM_IN_en(in_en),
    .BRAM_IN_addr(in_addr),
    .BRAM_IN_din(in_din),
    .BRAM_IN_we(in_we),
    .BRAM_IN_dout(in_dout),

    .BRAM_OUT_clk(out_clk),
    .BRAM_OUT_rst(out_rst),
    .BRAM_OUT_en(out_en),
    .BRAM_OUT_addr(out_addr),
    .BRAM_OUT_din(out_din),
    .BRAM_OUT_we(out_we),
    .BRAM_OUT_dout(out_dout),

    .BRAM_WB_clk(wb_clk),
    .BRAM_WB_rst(wb_rst),
    .BRAM_WB_en(wb_en),
    .BRAM_WB_addr(wb_addr),
    .BRAM_WB_din(wb_din),
    .BRAM_WB_we(wb_we),
    .BRAM_WB_dout(wb_dout),

    .s_axi_aclk(eMamba_IP_clk),
    .s_axi_aresetn(eMamba_IP_rstnn),
    .s_axi_awid(eMamba_IP_rx4awid),
    .s_axi_awaddr({4'b0, eMamba_IP_rx4awaddr[10:0]}),
    .s_axi_awlen(eMamba_IP_rx4awlen),
    .s_axi_awsize(eMamba_IP_rx4awsize),
    .s_axi_awburst(eMamba_IP_rx4awburst),
    .s_axi_awlock(1'b0),
    .s_axi_awcache(4'b0),
    .s_axi_awprot(3'b0),
    .s_axi_awqos(4'b0),
    .s_axi_awregion(4'b0),
    .s_axi_awuser(0),
    .s_axi_awvalid(eMamba_IP_rx4awvalid),
    .s_axi_awready(eMamba_IP_rx4awready),
    .s_axi_wdata(eMamba_IP_rx4wdata),
    .s_axi_wstrb(eMamba_IP_rx4wstrb),
    .s_axi_wlast(eMamba_IP_rx4wlast),
    .s_axi_wuser(0),
    .s_axi_wvalid(eMamba_IP_rx4wvalid),
    .s_axi_wready(eMamba_IP_rx4wready),
    .s_axi_bid(eMamba_IP_rx4bid),
    .s_axi_bresp(eMamba_IP_rx4bresp),
    .s_axi_buser(),
    .s_axi_bvalid(eMamba_IP_rx4bvalid),
    .s_axi_bready(eMamba_IP_rx4bready),
    .s_axi_arid(eMamba_IP_rx4arid),
    .s_axi_araddr({4'b0, eMamba_IP_rx4araddr[10:0]}),
    .s_axi_arlen(eMamba_IP_rx4arlen),
    .s_axi_arsize(eMamba_IP_rx4arsize),
    .s_axi_arburst(eMamba_IP_rx4arburst),
    .s_axi_arlock(1'b0),
    .s_axi_arcache(4'b0),
    .s_axi_arprot(3'b0),
    .s_axi_arqos(4'b0),
    .s_axi_arregion(4'b0),
    .s_axi_aruser(0),
    .s_axi_arvalid(eMamba_IP_rx4arvalid),
    .s_axi_arready(eMamba_IP_rx4arready),
    .s_axi_rid(eMamba_IP_rx4rid),
    .s_axi_rdata(eMamba_IP_rx4rdata),
    .s_axi_rresp(eMamba_IP_rx4rresp),
    .s_axi_rlast(eMamba_IP_rx4rlast),
    .s_axi_ruser(),
    .s_axi_rvalid(eMamba_IP_rx4rvalid),
    .s_axi_rready(eMamba_IP_rx4rready)
);
