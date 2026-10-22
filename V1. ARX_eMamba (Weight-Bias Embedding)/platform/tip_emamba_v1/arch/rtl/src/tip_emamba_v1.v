// ****************************************************************************
// ****************************************************************************
// Copyright SoC Design Research Group, All rights reserved.
// Electronics and Telecommunications Research Institute (ETRI)
// 
// THESE DOCUMENTS CONTAIN CONFIDENTIAL INFORMATION AND KNOWLEDGE
// WHICH IS THE PROPERTY OF ETRI. NO PART OF THIS PUBLICATION IS
// TO BE USED FOR ANY OTHER PURPOSE, AND THESE ARE NOT TO BE
// REPRODUCED, COPIED, DISCLOSED, TRANSMITTED, STORED IN A RETRIEVAL
// SYSTEM OR TRANSLATED INTO ANY OTHER HUMAN OR COMPUTER LANGUAGE,
// IN ANY FORM, BY ANY MEANS, IN WHOLE OR IN PART, WITHOUT THE
// COMPLETE PRIOR WRITTEN PERMISSION OF ETRI.
// ****************************************************************************
// 2026-07-03
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_platform_controller_memorymap_offset.vh"
`include "ervp_external_peri_group_memorymap_offset.vh"
`include "memorymap_info.vh"
`include "ervp_global.vh"
`include "platform_info.vh"
`include "munoc_network_include.vh"

module TIP_EMAMBA_V1
(
	external_clk_0,
	external_clk_0_pair,
	external_rstnn,
	pjtag_rtck,
	pjtag_rtrstnn,
	pjtag_rtms,
	pjtag_rtdi,
	pjtag_rtdo,
	printf_tx,
	printf_rx
);


input wire external_clk_0;
input wire external_clk_0_pair;
input wire external_rstnn;
input wire pjtag_rtck;
input wire pjtag_rtrstnn;
input wire pjtag_rtms;
input wire pjtag_rtdi;
output wire pjtag_rtdo;
output wire printf_tx;
input wire printf_rx;



wire clk_system;
wire clk_core;
wire clk_system_external;
wire clk_system_debug;
wire clk_local_access;
wire clk_process_000;
wire clk_noc;
wire gclk_system;
wire gclk_core;
wire gclk_system_external;
wire gclk_system_debug;
wire gclk_local_access;
wire gclk_process_000;
wire gclk_noc;
wire tick_1us;
wire tick_62d5ms;
wire tick_gpio;
wire spi_common_sclk;
wire spi_common_sdq0;
wire global_rstnn;
wire global_rstpp;
wire [(6)-1:0] rstnn_seqeunce;
wire [(6)-1:0] rstpp_seqeunce;
wire rstnn_user;
wire rstpp_user;
wire i_rtl_clk_system;
wire i_rtl_clk_core;
wire i_rtl_clk_system_external;
wire i_rtl_clk_system_debug;
wire i_rtl_clk_local_access;
wire i_rtl_clk_process_000;
wire i_rtl_clk_noc;
wire i_rtl_gclk_system;
wire i_rtl_gclk_core;
wire i_rtl_gclk_system_external;
wire i_rtl_gclk_system_debug;
wire i_rtl_gclk_local_access;
wire i_rtl_gclk_process_000;
wire i_rtl_gclk_noc;
wire i_rtl_tick_1us;
wire i_rtl_tick_62d5ms;
wire i_rtl_tick_gpio;
wire i_rtl_spi_common_sclk;
wire i_rtl_spi_common_sdq0;
wire i_rtl_external_rstnn;
wire i_rtl_global_rstnn;
wire i_rtl_global_rstpp;
wire [(6)-1:0] i_rtl_rstnn_seqeunce;
wire [(6)-1:0] i_rtl_rstpp_seqeunce;
wire i_rtl_rstnn_user;
wire i_rtl_rstpp_user;
wire i_rtl_eMamba_IP_clk;
wire i_rtl_eMamba_IP_rstnn;
wire i_rtl_i_pll0_external_rstnn;
wire i_rtl_i_pll0_clk_system;
wire i_rtl_i_system_sram_clk;
wire i_rtl_i_system_sram_rstnn;
wire i_rtl_pjtag_rtck;
wire i_rtl_pjtag_rtrstnn;
wire i_rtl_pjtag_rtms;
wire i_rtl_pjtag_rtdi;
wire i_rtl_pjtag_rtdo;
wire i_rtl_printf_tx;
wire i_rtl_printf_rx;
wire i_rtl_eMamba_IP_sx4awready;
wire i_rtl_eMamba_IP_sx4awvalid;
wire [(32)-1:0] i_rtl_eMamba_IP_sx4awaddr;
wire [(1)-1:0] i_rtl_eMamba_IP_sx4awid;
wire [(8)-1:0] i_rtl_eMamba_IP_sx4awlen;
wire [(3)-1:0] i_rtl_eMamba_IP_sx4awsize;
wire [(2)-1:0] i_rtl_eMamba_IP_sx4awburst;
wire i_rtl_eMamba_IP_sx4wready;
wire i_rtl_eMamba_IP_sx4wvalid;
wire [(32)-1:0] i_rtl_eMamba_IP_sx4wdata;
wire [(32/8)-1:0] i_rtl_eMamba_IP_sx4wstrb;
wire i_rtl_eMamba_IP_sx4wlast;
wire i_rtl_eMamba_IP_sx4bready;
wire i_rtl_eMamba_IP_sx4bvalid;
wire [(1)-1:0] i_rtl_eMamba_IP_sx4bid;
wire [(2)-1:0] i_rtl_eMamba_IP_sx4bresp;
wire i_rtl_eMamba_IP_sx4arready;
wire i_rtl_eMamba_IP_sx4arvalid;
wire [(32)-1:0] i_rtl_eMamba_IP_sx4araddr;
wire [(1)-1:0] i_rtl_eMamba_IP_sx4arid;
wire [(8)-1:0] i_rtl_eMamba_IP_sx4arlen;
wire [(3)-1:0] i_rtl_eMamba_IP_sx4arsize;
wire [(2)-1:0] i_rtl_eMamba_IP_sx4arburst;
wire i_rtl_eMamba_IP_sx4rready;
wire i_rtl_eMamba_IP_sx4rvalid;
wire [(1)-1:0] i_rtl_eMamba_IP_sx4rid;
wire [(32)-1:0] i_rtl_eMamba_IP_sx4rdata;
wire i_rtl_eMamba_IP_sx4rlast;
wire [(2)-1:0] i_rtl_eMamba_IP_sx4rresp;
wire i_rtl_i_system_sram_sxawready;
wire i_rtl_i_system_sram_sxawvalid;
wire [(32)-1:0] i_rtl_i_system_sram_sxawaddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxawid;
wire [(8)-1:0] i_rtl_i_system_sram_sxawlen;
wire [(3)-1:0] i_rtl_i_system_sram_sxawsize;
wire [(2)-1:0] i_rtl_i_system_sram_sxawburst;
wire i_rtl_i_system_sram_sxwready;
wire i_rtl_i_system_sram_sxwvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxwid;
wire [(32)-1:0] i_rtl_i_system_sram_sxwdata;
wire [(32/8)-1:0] i_rtl_i_system_sram_sxwstrb;
wire i_rtl_i_system_sram_sxwlast;
wire i_rtl_i_system_sram_sxbready;
wire i_rtl_i_system_sram_sxbvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxbid;
wire [(2)-1:0] i_rtl_i_system_sram_sxbresp;
wire i_rtl_i_system_sram_sxarready;
wire i_rtl_i_system_sram_sxarvalid;
wire [(32)-1:0] i_rtl_i_system_sram_sxaraddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxarid;
wire [(8)-1:0] i_rtl_i_system_sram_sxarlen;
wire [(3)-1:0] i_rtl_i_system_sram_sxarsize;
wire [(2)-1:0] i_rtl_i_system_sram_sxarburst;
wire i_rtl_i_system_sram_sxrready;
wire i_rtl_i_system_sram_sxrvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_rtl_i_system_sram_sxrid;
wire [(32)-1:0] i_rtl_i_system_sram_sxrdata;
wire i_rtl_i_system_sram_sxrlast;
wire [(2)-1:0] i_rtl_i_system_sram_sxrresp;
wire eMamba_IP_clk;
wire eMamba_IP_rstnn;
wire eMamba_IP_rx4awready;
wire eMamba_IP_rx4awvalid;
wire [(32)-1:0] eMamba_IP_rx4awaddr;
wire [(1)-1:0] eMamba_IP_rx4awid;
wire [(8)-1:0] eMamba_IP_rx4awlen;
wire [(3)-1:0] eMamba_IP_rx4awsize;
wire [(2)-1:0] eMamba_IP_rx4awburst;
wire eMamba_IP_rx4wready;
wire eMamba_IP_rx4wvalid;
wire [(32)-1:0] eMamba_IP_rx4wdata;
wire [(32/8)-1:0] eMamba_IP_rx4wstrb;
wire eMamba_IP_rx4wlast;
wire eMamba_IP_rx4bready;
wire eMamba_IP_rx4bvalid;
wire [(1)-1:0] eMamba_IP_rx4bid;
wire [(2)-1:0] eMamba_IP_rx4bresp;
wire eMamba_IP_rx4arready;
wire eMamba_IP_rx4arvalid;
wire [(32)-1:0] eMamba_IP_rx4araddr;
wire [(1)-1:0] eMamba_IP_rx4arid;
wire [(8)-1:0] eMamba_IP_rx4arlen;
wire [(3)-1:0] eMamba_IP_rx4arsize;
wire [(2)-1:0] eMamba_IP_rx4arburst;
wire eMamba_IP_rx4rready;
wire eMamba_IP_rx4rvalid;
wire [(1)-1:0] eMamba_IP_rx4rid;
wire [(32)-1:0] eMamba_IP_rx4rdata;
wire eMamba_IP_rx4rlast;
wire [(2)-1:0] eMamba_IP_rx4rresp;
wire i_pll0_external_clk;
wire i_pll0_external_clk_pair;
wire i_pll0_external_rstnn;
wire i_pll0_clk_system;
wire i_system_sram_clk;
wire i_system_sram_rstnn;
wire i_system_sram_rxawready;
wire i_system_sram_rxawvalid;
wire [(32)-1:0] i_system_sram_rxawaddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxawid;
wire [(8)-1:0] i_system_sram_rxawlen;
wire [(3)-1:0] i_system_sram_rxawsize;
wire [(2)-1:0] i_system_sram_rxawburst;
wire i_system_sram_rxwready;
wire i_system_sram_rxwvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxwid;
wire [(32)-1:0] i_system_sram_rxwdata;
wire [(32/8)-1:0] i_system_sram_rxwstrb;
wire i_system_sram_rxwlast;
wire i_system_sram_rxbready;
wire i_system_sram_rxbvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxbid;
wire [(2)-1:0] i_system_sram_rxbresp;
wire i_system_sram_rxarready;
wire i_system_sram_rxarvalid;
wire [(32)-1:0] i_system_sram_rxaraddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxarid;
wire [(8)-1:0] i_system_sram_rxarlen;
wire [(3)-1:0] i_system_sram_rxarsize;
wire [(2)-1:0] i_system_sram_rxarburst;
wire i_system_sram_rxrready;
wire i_system_sram_rxrvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_rxrid;
wire [(32)-1:0] i_system_sram_rxrdata;
wire i_system_sram_rxrlast;
wire [(2)-1:0] i_system_sram_rxrresp;

TIP_EMAMBA_V1_RTL
i_rtl
(
	.clk_system(i_rtl_clk_system),
	.clk_core(i_rtl_clk_core),
	.clk_system_external(i_rtl_clk_system_external),
	.clk_system_debug(i_rtl_clk_system_debug),
	.clk_local_access(i_rtl_clk_local_access),
	.clk_process_000(i_rtl_clk_process_000),
	.clk_noc(i_rtl_clk_noc),
	.gclk_system(i_rtl_gclk_system),
	.gclk_core(i_rtl_gclk_core),
	.gclk_system_external(i_rtl_gclk_system_external),
	.gclk_system_debug(i_rtl_gclk_system_debug),
	.gclk_local_access(i_rtl_gclk_local_access),
	.gclk_process_000(i_rtl_gclk_process_000),
	.gclk_noc(i_rtl_gclk_noc),
	.tick_1us(i_rtl_tick_1us),
	.tick_62d5ms(i_rtl_tick_62d5ms),
	.tick_gpio(i_rtl_tick_gpio),
	.spi_common_sclk(i_rtl_spi_common_sclk),
	.spi_common_sdq0(i_rtl_spi_common_sdq0),
	.external_rstnn(i_rtl_external_rstnn),
	.global_rstnn(i_rtl_global_rstnn),
	.global_rstpp(i_rtl_global_rstpp),
	.rstnn_seqeunce(i_rtl_rstnn_seqeunce),
	.rstpp_seqeunce(i_rtl_rstpp_seqeunce),
	.rstnn_user(i_rtl_rstnn_user),
	.rstpp_user(i_rtl_rstpp_user),
	.eMamba_IP_clk(i_rtl_eMamba_IP_clk),
	.eMamba_IP_rstnn(i_rtl_eMamba_IP_rstnn),
	.i_pll0_external_rstnn(i_rtl_i_pll0_external_rstnn),
	.i_pll0_clk_system(i_rtl_i_pll0_clk_system),
	.i_system_sram_clk(i_rtl_i_system_sram_clk),
	.i_system_sram_rstnn(i_rtl_i_system_sram_rstnn),
	.pjtag_rtck(i_rtl_pjtag_rtck),
	.pjtag_rtrstnn(i_rtl_pjtag_rtrstnn),
	.pjtag_rtms(i_rtl_pjtag_rtms),
	.pjtag_rtdi(i_rtl_pjtag_rtdi),
	.pjtag_rtdo(i_rtl_pjtag_rtdo),
	.printf_tx(i_rtl_printf_tx),
	.printf_rx(i_rtl_printf_rx),
	.eMamba_IP_sx4awready(i_rtl_eMamba_IP_sx4awready),
	.eMamba_IP_sx4awvalid(i_rtl_eMamba_IP_sx4awvalid),
	.eMamba_IP_sx4awaddr(i_rtl_eMamba_IP_sx4awaddr),
	.eMamba_IP_sx4awid(i_rtl_eMamba_IP_sx4awid),
	.eMamba_IP_sx4awlen(i_rtl_eMamba_IP_sx4awlen),
	.eMamba_IP_sx4awsize(i_rtl_eMamba_IP_sx4awsize),
	.eMamba_IP_sx4awburst(i_rtl_eMamba_IP_sx4awburst),
	.eMamba_IP_sx4wready(i_rtl_eMamba_IP_sx4wready),
	.eMamba_IP_sx4wvalid(i_rtl_eMamba_IP_sx4wvalid),
	.eMamba_IP_sx4wdata(i_rtl_eMamba_IP_sx4wdata),
	.eMamba_IP_sx4wstrb(i_rtl_eMamba_IP_sx4wstrb),
	.eMamba_IP_sx4wlast(i_rtl_eMamba_IP_sx4wlast),
	.eMamba_IP_sx4bready(i_rtl_eMamba_IP_sx4bready),
	.eMamba_IP_sx4bvalid(i_rtl_eMamba_IP_sx4bvalid),
	.eMamba_IP_sx4bid(i_rtl_eMamba_IP_sx4bid),
	.eMamba_IP_sx4bresp(i_rtl_eMamba_IP_sx4bresp),
	.eMamba_IP_sx4arready(i_rtl_eMamba_IP_sx4arready),
	.eMamba_IP_sx4arvalid(i_rtl_eMamba_IP_sx4arvalid),
	.eMamba_IP_sx4araddr(i_rtl_eMamba_IP_sx4araddr),
	.eMamba_IP_sx4arid(i_rtl_eMamba_IP_sx4arid),
	.eMamba_IP_sx4arlen(i_rtl_eMamba_IP_sx4arlen),
	.eMamba_IP_sx4arsize(i_rtl_eMamba_IP_sx4arsize),
	.eMamba_IP_sx4arburst(i_rtl_eMamba_IP_sx4arburst),
	.eMamba_IP_sx4rready(i_rtl_eMamba_IP_sx4rready),
	.eMamba_IP_sx4rvalid(i_rtl_eMamba_IP_sx4rvalid),
	.eMamba_IP_sx4rid(i_rtl_eMamba_IP_sx4rid),
	.eMamba_IP_sx4rdata(i_rtl_eMamba_IP_sx4rdata),
	.eMamba_IP_sx4rlast(i_rtl_eMamba_IP_sx4rlast),
	.eMamba_IP_sx4rresp(i_rtl_eMamba_IP_sx4rresp),
	.i_system_sram_sxawready(i_rtl_i_system_sram_sxawready),
	.i_system_sram_sxawvalid(i_rtl_i_system_sram_sxawvalid),
	.i_system_sram_sxawaddr(i_rtl_i_system_sram_sxawaddr),
	.i_system_sram_sxawid(i_rtl_i_system_sram_sxawid),
	.i_system_sram_sxawlen(i_rtl_i_system_sram_sxawlen),
	.i_system_sram_sxawsize(i_rtl_i_system_sram_sxawsize),
	.i_system_sram_sxawburst(i_rtl_i_system_sram_sxawburst),
	.i_system_sram_sxwready(i_rtl_i_system_sram_sxwready),
	.i_system_sram_sxwvalid(i_rtl_i_system_sram_sxwvalid),
	.i_system_sram_sxwid(i_rtl_i_system_sram_sxwid),
	.i_system_sram_sxwdata(i_rtl_i_system_sram_sxwdata),
	.i_system_sram_sxwstrb(i_rtl_i_system_sram_sxwstrb),
	.i_system_sram_sxwlast(i_rtl_i_system_sram_sxwlast),
	.i_system_sram_sxbready(i_rtl_i_system_sram_sxbready),
	.i_system_sram_sxbvalid(i_rtl_i_system_sram_sxbvalid),
	.i_system_sram_sxbid(i_rtl_i_system_sram_sxbid),
	.i_system_sram_sxbresp(i_rtl_i_system_sram_sxbresp),
	.i_system_sram_sxarready(i_rtl_i_system_sram_sxarready),
	.i_system_sram_sxarvalid(i_rtl_i_system_sram_sxarvalid),
	.i_system_sram_sxaraddr(i_rtl_i_system_sram_sxaraddr),
	.i_system_sram_sxarid(i_rtl_i_system_sram_sxarid),
	.i_system_sram_sxarlen(i_rtl_i_system_sram_sxarlen),
	.i_system_sram_sxarsize(i_rtl_i_system_sram_sxarsize),
	.i_system_sram_sxarburst(i_rtl_i_system_sram_sxarburst),
	.i_system_sram_sxrready(i_rtl_i_system_sram_sxrready),
	.i_system_sram_sxrvalid(i_rtl_i_system_sram_sxrvalid),
	.i_system_sram_sxrid(i_rtl_i_system_sram_sxrid),
	.i_system_sram_sxrdata(i_rtl_i_system_sram_sxrdata),
	.i_system_sram_sxrlast(i_rtl_i_system_sram_sxrlast),
	.i_system_sram_sxrresp(i_rtl_i_system_sram_sxrresp)
);

TIP_EMAMBA_V1_CLOCK_PLL_0_00
i_pll0
(
	.external_clk(i_pll0_external_clk),
	.external_clk_pair(i_pll0_external_clk_pair),
	.external_rstnn(i_pll0_external_rstnn),
	.clk_system(i_pll0_clk_system)
);

TIP_EMAMBA_V1_SRAM_AXI_01
i_system_sram
(
	.clk(i_system_sram_clk),
	.rstnn(i_system_sram_rstnn),
	.rxawready(i_system_sram_rxawready),
	.rxawvalid(i_system_sram_rxawvalid),
	.rxawaddr(i_system_sram_rxawaddr),
	.rxawid(i_system_sram_rxawid),
	.rxawlen(i_system_sram_rxawlen),
	.rxawsize(i_system_sram_rxawsize),
	.rxawburst(i_system_sram_rxawburst),
	.rxwready(i_system_sram_rxwready),
	.rxwvalid(i_system_sram_rxwvalid),
	.rxwid(i_system_sram_rxwid),
	.rxwdata(i_system_sram_rxwdata),
	.rxwstrb(i_system_sram_rxwstrb),
	.rxwlast(i_system_sram_rxwlast),
	.rxbready(i_system_sram_rxbready),
	.rxbvalid(i_system_sram_rxbvalid),
	.rxbid(i_system_sram_rxbid),
	.rxbresp(i_system_sram_rxbresp),
	.rxarready(i_system_sram_rxarready),
	.rxarvalid(i_system_sram_rxarvalid),
	.rxaraddr(i_system_sram_rxaraddr),
	.rxarid(i_system_sram_rxarid),
	.rxarlen(i_system_sram_rxarlen),
	.rxarsize(i_system_sram_rxarsize),
	.rxarburst(i_system_sram_rxarburst),
	.rxrready(i_system_sram_rxrready),
	.rxrvalid(i_system_sram_rxrvalid),
	.rxrid(i_system_sram_rxrid),
	.rxrdata(i_system_sram_rxrdata),
	.rxrlast(i_system_sram_rxrlast),
	.rxrresp(i_system_sram_rxrresp)
);

assign i_rtl_external_rstnn = external_rstnn;
assign eMamba_IP_clk = i_rtl_eMamba_IP_clk;
assign eMamba_IP_rstnn = i_rtl_eMamba_IP_rstnn;
assign i_pll0_external_clk = external_clk_0;
assign i_pll0_external_clk_pair = external_clk_0_pair;
assign i_pll0_external_rstnn = i_rtl_i_pll0_external_rstnn;
assign i_rtl_i_pll0_clk_system = i_pll0_clk_system;
assign i_system_sram_clk = i_rtl_i_system_sram_clk;
assign i_system_sram_rstnn = i_rtl_i_system_sram_rstnn;
assign clk_system = i_rtl_clk_system;
assign clk_core = i_rtl_clk_core;
assign clk_system_external = i_rtl_clk_system_external;
assign clk_system_debug = i_rtl_clk_system_debug;
assign clk_local_access = i_rtl_clk_local_access;
assign clk_process_000 = i_rtl_clk_process_000;
assign clk_noc = i_rtl_clk_noc;
assign gclk_system = i_rtl_gclk_system;
assign gclk_core = i_rtl_gclk_core;
assign gclk_system_external = i_rtl_gclk_system_external;
assign gclk_system_debug = i_rtl_gclk_system_debug;
assign gclk_local_access = i_rtl_gclk_local_access;
assign gclk_process_000 = i_rtl_gclk_process_000;
assign gclk_noc = i_rtl_gclk_noc;
assign tick_1us = i_rtl_tick_1us;
assign tick_62d5ms = i_rtl_tick_62d5ms;
assign tick_gpio = i_rtl_tick_gpio;
assign spi_common_sclk = i_rtl_spi_common_sclk;
assign spi_common_sdq0 = i_rtl_spi_common_sdq0;
assign global_rstnn = i_rtl_global_rstnn;
assign global_rstpp = i_rtl_global_rstpp;
assign rstnn_seqeunce = i_rtl_rstnn_seqeunce;
assign rstpp_seqeunce = i_rtl_rstpp_seqeunce;
assign rstnn_user = i_rtl_rstnn_user;
assign rstpp_user = i_rtl_rstpp_user;
assign i_rtl_pjtag_rtck = pjtag_rtck;
assign i_rtl_pjtag_rtrstnn = pjtag_rtrstnn;
assign i_rtl_pjtag_rtms = pjtag_rtms;
assign i_rtl_pjtag_rtdi = pjtag_rtdi;
assign pjtag_rtdo = i_rtl_pjtag_rtdo;
assign printf_tx = i_rtl_printf_tx;
assign i_rtl_printf_rx = printf_rx;
assign i_rtl_eMamba_IP_sx4awready = eMamba_IP_rx4awready;
assign eMamba_IP_rx4awvalid = i_rtl_eMamba_IP_sx4awvalid;
assign eMamba_IP_rx4awaddr = i_rtl_eMamba_IP_sx4awaddr;
assign eMamba_IP_rx4awid = i_rtl_eMamba_IP_sx4awid;
assign eMamba_IP_rx4awlen = i_rtl_eMamba_IP_sx4awlen;
assign eMamba_IP_rx4awsize = i_rtl_eMamba_IP_sx4awsize;
assign eMamba_IP_rx4awburst = i_rtl_eMamba_IP_sx4awburst;
assign i_rtl_eMamba_IP_sx4wready = eMamba_IP_rx4wready;
assign eMamba_IP_rx4wvalid = i_rtl_eMamba_IP_sx4wvalid;
assign eMamba_IP_rx4wdata = i_rtl_eMamba_IP_sx4wdata;
assign eMamba_IP_rx4wstrb = i_rtl_eMamba_IP_sx4wstrb;
assign eMamba_IP_rx4wlast = i_rtl_eMamba_IP_sx4wlast;
assign eMamba_IP_rx4bready = i_rtl_eMamba_IP_sx4bready;
assign i_rtl_eMamba_IP_sx4bvalid = eMamba_IP_rx4bvalid;
assign i_rtl_eMamba_IP_sx4bid = eMamba_IP_rx4bid;
assign i_rtl_eMamba_IP_sx4bresp = eMamba_IP_rx4bresp;
assign i_rtl_eMamba_IP_sx4arready = eMamba_IP_rx4arready;
assign eMamba_IP_rx4arvalid = i_rtl_eMamba_IP_sx4arvalid;
assign eMamba_IP_rx4araddr = i_rtl_eMamba_IP_sx4araddr;
assign eMamba_IP_rx4arid = i_rtl_eMamba_IP_sx4arid;
assign eMamba_IP_rx4arlen = i_rtl_eMamba_IP_sx4arlen;
assign eMamba_IP_rx4arsize = i_rtl_eMamba_IP_sx4arsize;
assign eMamba_IP_rx4arburst = i_rtl_eMamba_IP_sx4arburst;
assign eMamba_IP_rx4rready = i_rtl_eMamba_IP_sx4rready;
assign i_rtl_eMamba_IP_sx4rvalid = eMamba_IP_rx4rvalid;
assign i_rtl_eMamba_IP_sx4rid = eMamba_IP_rx4rid;
assign i_rtl_eMamba_IP_sx4rdata = eMamba_IP_rx4rdata;
assign i_rtl_eMamba_IP_sx4rlast = eMamba_IP_rx4rlast;
assign i_rtl_eMamba_IP_sx4rresp = eMamba_IP_rx4rresp;
assign i_rtl_i_system_sram_sxawready = i_system_sram_rxawready;
assign i_system_sram_rxawvalid = i_rtl_i_system_sram_sxawvalid;
assign i_system_sram_rxawaddr = i_rtl_i_system_sram_sxawaddr;
assign i_system_sram_rxawid = i_rtl_i_system_sram_sxawid;
assign i_system_sram_rxawlen = i_rtl_i_system_sram_sxawlen;
assign i_system_sram_rxawsize = i_rtl_i_system_sram_sxawsize;
assign i_system_sram_rxawburst = i_rtl_i_system_sram_sxawburst;
assign i_rtl_i_system_sram_sxwready = i_system_sram_rxwready;
assign i_system_sram_rxwvalid = i_rtl_i_system_sram_sxwvalid;
assign i_system_sram_rxwid = i_rtl_i_system_sram_sxwid;
assign i_system_sram_rxwdata = i_rtl_i_system_sram_sxwdata;
assign i_system_sram_rxwstrb = i_rtl_i_system_sram_sxwstrb;
assign i_system_sram_rxwlast = i_rtl_i_system_sram_sxwlast;
assign i_system_sram_rxbready = i_rtl_i_system_sram_sxbready;
assign i_rtl_i_system_sram_sxbvalid = i_system_sram_rxbvalid;
assign i_rtl_i_system_sram_sxbid = i_system_sram_rxbid;
assign i_rtl_i_system_sram_sxbresp = i_system_sram_rxbresp;
assign i_rtl_i_system_sram_sxarready = i_system_sram_rxarready;
assign i_system_sram_rxarvalid = i_rtl_i_system_sram_sxarvalid;
assign i_system_sram_rxaraddr = i_rtl_i_system_sram_sxaraddr;
assign i_system_sram_rxarid = i_rtl_i_system_sram_sxarid;
assign i_system_sram_rxarlen = i_rtl_i_system_sram_sxarlen;
assign i_system_sram_rxarsize = i_rtl_i_system_sram_sxarsize;
assign i_system_sram_rxarburst = i_rtl_i_system_sram_sxarburst;
assign i_system_sram_rxrready = i_rtl_i_system_sram_sxrready;
assign i_rtl_i_system_sram_sxrvalid = i_system_sram_rxrvalid;
assign i_rtl_i_system_sram_sxrid = i_system_sram_rxrid;
assign i_rtl_i_system_sram_sxrdata = i_system_sram_rxrdata;
assign i_rtl_i_system_sram_sxrlast = i_system_sram_rxrlast;
assign i_rtl_i_system_sram_sxrresp = i_system_sram_rxrresp;

`include "tip_emamba_v1_user_region.vh"

`ifdef USE_ILA
`include "ila_description.vh"
`endif

endmodule