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
// 2026-10-21
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_platform_controller_memorymap_offset.vh"
`include "ervp_external_peri_group_memorymap_offset.vh"
`include "memorymap_info.vh"
`include "ervp_global.vh"
`include "platform_info.vh"
`include "munoc_network_include.vh"

module U504
(
	external_clk_0,
	external_clk_0_pair,
	external_rstnn,
	led_list,
	pjtag_rtck,
	pjtag_rtrstnn,
	pjtag_rtms,
	pjtag_rtdi,
	pjtag_rtdo,
	printf_tx,
	printf_rx
	`include "video_module_port_dec.vh"
	`include "fast_dram_cell_port_dec.vh"
);


input wire external_clk_0;
input wire external_clk_0_pair;
input wire external_rstnn;
output wire [((1)*(1))-1:0] led_list;
input wire pjtag_rtck;
input wire pjtag_rtrstnn;
input wire pjtag_rtms;
input wire pjtag_rtdi;
output wire pjtag_rtdo;
output wire printf_tx;
input wire printf_rx;

`include "video_module_port_def.vh"
`include "fast_dram_cell_port_def.vh"


wire clk_core;
wire clk_system;
wire clk_system_external;
wire clk_system_debug;
wire clk_local_access;
wire clk_process_000;
wire clk_dram_if;
wire clk_dram_sys;
wire clk_dram_ref;
wire clk_noc;
wire clk_25M;
wire clk_50M;
wire clk_150M;
wire clk_200M;
wire clk_300M;
wire gclk_core;
wire gclk_system;
wire gclk_system_external;
wire gclk_system_debug;
wire gclk_local_access;
wire gclk_process_000;
wire gclk_noc;
wire gclk_25M;
wire gclk_50M;
wire gclk_150M;
wire gclk_200M;
wire gclk_300M;
wire tick_1us;
wire tick_62d5ms;
wire tick_gpio;
wire spi_common_sclk;
wire spi_common_sdq0;
wire global_rstnn;
wire global_rstpp;
wire [(7)-1:0] rstnn_seqeunce;
wire [(7)-1:0] rstpp_seqeunce;
wire rstnn_user;
wire rstpp_user;
wire i_rtl_clk_core;
wire i_rtl_clk_system;
wire i_rtl_clk_system_external;
wire i_rtl_clk_system_debug;
wire i_rtl_clk_local_access;
wire i_rtl_clk_process_000;
wire i_rtl_clk_dram_if;
wire i_rtl_clk_dram_sys;
wire i_rtl_clk_dram_ref;
wire i_rtl_clk_noc;
wire i_rtl_clk_25M;
wire i_rtl_clk_50M;
wire i_rtl_clk_150M;
wire i_rtl_clk_200M;
wire i_rtl_clk_300M;
wire i_rtl_gclk_core;
wire i_rtl_gclk_system;
wire i_rtl_gclk_system_external;
wire i_rtl_gclk_system_debug;
wire i_rtl_gclk_local_access;
wire i_rtl_gclk_process_000;
wire i_rtl_gclk_noc;
wire i_rtl_gclk_25M;
wire i_rtl_gclk_50M;
wire i_rtl_gclk_150M;
wire i_rtl_gclk_200M;
wire i_rtl_gclk_300M;
wire i_rtl_tick_1us;
wire i_rtl_tick_62d5ms;
wire i_rtl_tick_gpio;
wire i_rtl_spi_common_sclk;
wire i_rtl_spi_common_sdq0;
wire i_rtl_external_rstnn;
wire i_rtl_global_rstnn;
wire i_rtl_global_rstpp;
wire [(7)-1:0] i_rtl_rstnn_seqeunce;
wire [(7)-1:0] i_rtl_rstpp_seqeunce;
wire i_rtl_rstnn_user;
wire i_rtl_rstpp_user;
wire [((1)*(1))-1:0] i_rtl_led_list;
wire i_rtl_eMamba_IP_clk;
wire i_rtl_eMamba_IP_rstnn;
wire i_rtl_input_bram_clk;
wire i_rtl_input_bram_rstnn;
wire i_rtl_wb_bram_clk;
wire i_rtl_wb_bram_rstnn;
wire i_rtl_output_bram_clk;
wire i_rtl_output_bram_rstnn;
wire i_rtl_i_system_ddr_clk_ref;
wire i_rtl_i_system_ddr_clk_sys;
wire i_rtl_i_system_ddr_rstnn_sys;
wire i_rtl_i_system_ddr_clk_dram_if;
wire i_rtl_i_system_ddr_rstnn_dram_if;
wire i_rtl_i_system_ddr_initialized;
wire i_rtl_i_pll0_external_rstnn;
wire i_rtl_i_pll0_clk_25M;
wire i_rtl_i_pll0_clk_system;
wire i_rtl_i_pll0_clk_core;
wire i_rtl_i_pll0_clk_150M;
wire i_rtl_i_pll0_clk_200M;
wire i_rtl_i_pll0_clk_300M;
wire i_rtl_i_pll0_clk_dram_sys;
wire i_rtl_i_pll0_clk_dram_ref;
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
wire i_rtl_input_bram_sxawready;
wire i_rtl_input_bram_sxawvalid;
wire [(32)-1:0] i_rtl_input_bram_sxawaddr;
wire [(1)-1:0] i_rtl_input_bram_sxawid;
wire [(8)-1:0] i_rtl_input_bram_sxawlen;
wire [(3)-1:0] i_rtl_input_bram_sxawsize;
wire [(2)-1:0] i_rtl_input_bram_sxawburst;
wire i_rtl_input_bram_sxwready;
wire i_rtl_input_bram_sxwvalid;
wire [(1)-1:0] i_rtl_input_bram_sxwid;
wire [(32)-1:0] i_rtl_input_bram_sxwdata;
wire [(32/8)-1:0] i_rtl_input_bram_sxwstrb;
wire i_rtl_input_bram_sxwlast;
wire i_rtl_input_bram_sxbready;
wire i_rtl_input_bram_sxbvalid;
wire [(1)-1:0] i_rtl_input_bram_sxbid;
wire [(2)-1:0] i_rtl_input_bram_sxbresp;
wire i_rtl_input_bram_sxarready;
wire i_rtl_input_bram_sxarvalid;
wire [(32)-1:0] i_rtl_input_bram_sxaraddr;
wire [(1)-1:0] i_rtl_input_bram_sxarid;
wire [(8)-1:0] i_rtl_input_bram_sxarlen;
wire [(3)-1:0] i_rtl_input_bram_sxarsize;
wire [(2)-1:0] i_rtl_input_bram_sxarburst;
wire i_rtl_input_bram_sxrready;
wire i_rtl_input_bram_sxrvalid;
wire [(1)-1:0] i_rtl_input_bram_sxrid;
wire [(32)-1:0] i_rtl_input_bram_sxrdata;
wire i_rtl_input_bram_sxrlast;
wire [(2)-1:0] i_rtl_input_bram_sxrresp;
wire i_rtl_wb_bram_sxawready;
wire i_rtl_wb_bram_sxawvalid;
wire [(32)-1:0] i_rtl_wb_bram_sxawaddr;
wire [(1)-1:0] i_rtl_wb_bram_sxawid;
wire [(8)-1:0] i_rtl_wb_bram_sxawlen;
wire [(3)-1:0] i_rtl_wb_bram_sxawsize;
wire [(2)-1:0] i_rtl_wb_bram_sxawburst;
wire i_rtl_wb_bram_sxwready;
wire i_rtl_wb_bram_sxwvalid;
wire [(1)-1:0] i_rtl_wb_bram_sxwid;
wire [(32)-1:0] i_rtl_wb_bram_sxwdata;
wire [(32/8)-1:0] i_rtl_wb_bram_sxwstrb;
wire i_rtl_wb_bram_sxwlast;
wire i_rtl_wb_bram_sxbready;
wire i_rtl_wb_bram_sxbvalid;
wire [(1)-1:0] i_rtl_wb_bram_sxbid;
wire [(2)-1:0] i_rtl_wb_bram_sxbresp;
wire i_rtl_wb_bram_sxarready;
wire i_rtl_wb_bram_sxarvalid;
wire [(32)-1:0] i_rtl_wb_bram_sxaraddr;
wire [(1)-1:0] i_rtl_wb_bram_sxarid;
wire [(8)-1:0] i_rtl_wb_bram_sxarlen;
wire [(3)-1:0] i_rtl_wb_bram_sxarsize;
wire [(2)-1:0] i_rtl_wb_bram_sxarburst;
wire i_rtl_wb_bram_sxrready;
wire i_rtl_wb_bram_sxrvalid;
wire [(1)-1:0] i_rtl_wb_bram_sxrid;
wire [(32)-1:0] i_rtl_wb_bram_sxrdata;
wire i_rtl_wb_bram_sxrlast;
wire [(2)-1:0] i_rtl_wb_bram_sxrresp;
wire i_rtl_output_bram_sxawready;
wire i_rtl_output_bram_sxawvalid;
wire [(32)-1:0] i_rtl_output_bram_sxawaddr;
wire [(1)-1:0] i_rtl_output_bram_sxawid;
wire [(8)-1:0] i_rtl_output_bram_sxawlen;
wire [(3)-1:0] i_rtl_output_bram_sxawsize;
wire [(2)-1:0] i_rtl_output_bram_sxawburst;
wire i_rtl_output_bram_sxwready;
wire i_rtl_output_bram_sxwvalid;
wire [(1)-1:0] i_rtl_output_bram_sxwid;
wire [(32)-1:0] i_rtl_output_bram_sxwdata;
wire [(32/8)-1:0] i_rtl_output_bram_sxwstrb;
wire i_rtl_output_bram_sxwlast;
wire i_rtl_output_bram_sxbready;
wire i_rtl_output_bram_sxbvalid;
wire [(1)-1:0] i_rtl_output_bram_sxbid;
wire [(2)-1:0] i_rtl_output_bram_sxbresp;
wire i_rtl_output_bram_sxarready;
wire i_rtl_output_bram_sxarvalid;
wire [(32)-1:0] i_rtl_output_bram_sxaraddr;
wire [(1)-1:0] i_rtl_output_bram_sxarid;
wire [(8)-1:0] i_rtl_output_bram_sxarlen;
wire [(3)-1:0] i_rtl_output_bram_sxarsize;
wire [(2)-1:0] i_rtl_output_bram_sxarburst;
wire i_rtl_output_bram_sxrready;
wire i_rtl_output_bram_sxrvalid;
wire [(1)-1:0] i_rtl_output_bram_sxrid;
wire [(32)-1:0] i_rtl_output_bram_sxrdata;
wire i_rtl_output_bram_sxrlast;
wire [(2)-1:0] i_rtl_output_bram_sxrresp;
wire i_rtl_i_system_ddr_sxawready;
wire i_rtl_i_system_ddr_sxawvalid;
wire [(32)-1:0] i_rtl_i_system_ddr_sxawaddr;
wire [(16)-1:0] i_rtl_i_system_ddr_sxawid;
wire [(8)-1:0] i_rtl_i_system_ddr_sxawlen;
wire [(3)-1:0] i_rtl_i_system_ddr_sxawsize;
wire [(2)-1:0] i_rtl_i_system_ddr_sxawburst;
wire i_rtl_i_system_ddr_sxwready;
wire i_rtl_i_system_ddr_sxwvalid;
wire [(16)-1:0] i_rtl_i_system_ddr_sxwid;
wire [(128)-1:0] i_rtl_i_system_ddr_sxwdata;
wire [(128/8)-1:0] i_rtl_i_system_ddr_sxwstrb;
wire i_rtl_i_system_ddr_sxwlast;
wire i_rtl_i_system_ddr_sxbready;
wire i_rtl_i_system_ddr_sxbvalid;
wire [(16)-1:0] i_rtl_i_system_ddr_sxbid;
wire [(2)-1:0] i_rtl_i_system_ddr_sxbresp;
wire i_rtl_i_system_ddr_sxarready;
wire i_rtl_i_system_ddr_sxarvalid;
wire [(32)-1:0] i_rtl_i_system_ddr_sxaraddr;
wire [(16)-1:0] i_rtl_i_system_ddr_sxarid;
wire [(8)-1:0] i_rtl_i_system_ddr_sxarlen;
wire [(3)-1:0] i_rtl_i_system_ddr_sxarsize;
wire [(2)-1:0] i_rtl_i_system_ddr_sxarburst;
wire i_rtl_i_system_ddr_sxrready;
wire i_rtl_i_system_ddr_sxrvalid;
wire [(16)-1:0] i_rtl_i_system_ddr_sxrid;
wire [(128)-1:0] i_rtl_i_system_ddr_sxrdata;
wire i_rtl_i_system_ddr_sxrlast;
wire [(2)-1:0] i_rtl_i_system_ddr_sxrresp;
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
wire [(128)-1:0] i_rtl_i_system_sram_sxwdata;
wire [(128/8)-1:0] i_rtl_i_system_sram_sxwstrb;
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
wire [(128)-1:0] i_rtl_i_system_sram_sxrdata;
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
wire input_bram_clk;
wire input_bram_rstnn;
wire input_bram_rxawready;
wire input_bram_rxawvalid;
wire [(32)-1:0] input_bram_rxawaddr;
wire [(1)-1:0] input_bram_rxawid;
wire [(8)-1:0] input_bram_rxawlen;
wire [(3)-1:0] input_bram_rxawsize;
wire [(2)-1:0] input_bram_rxawburst;
wire input_bram_rxwready;
wire input_bram_rxwvalid;
wire [(1)-1:0] input_bram_rxwid;
wire [(32)-1:0] input_bram_rxwdata;
wire [(32/8)-1:0] input_bram_rxwstrb;
wire input_bram_rxwlast;
wire input_bram_rxbready;
wire input_bram_rxbvalid;
wire [(1)-1:0] input_bram_rxbid;
wire [(2)-1:0] input_bram_rxbresp;
wire input_bram_rxarready;
wire input_bram_rxarvalid;
wire [(32)-1:0] input_bram_rxaraddr;
wire [(1)-1:0] input_bram_rxarid;
wire [(8)-1:0] input_bram_rxarlen;
wire [(3)-1:0] input_bram_rxarsize;
wire [(2)-1:0] input_bram_rxarburst;
wire input_bram_rxrready;
wire input_bram_rxrvalid;
wire [(1)-1:0] input_bram_rxrid;
wire [(32)-1:0] input_bram_rxrdata;
wire input_bram_rxrlast;
wire [(2)-1:0] input_bram_rxrresp;
wire wb_bram_clk;
wire wb_bram_rstnn;
wire wb_bram_rxawready;
wire wb_bram_rxawvalid;
wire [(32)-1:0] wb_bram_rxawaddr;
wire [(1)-1:0] wb_bram_rxawid;
wire [(8)-1:0] wb_bram_rxawlen;
wire [(3)-1:0] wb_bram_rxawsize;
wire [(2)-1:0] wb_bram_rxawburst;
wire wb_bram_rxwready;
wire wb_bram_rxwvalid;
wire [(1)-1:0] wb_bram_rxwid;
wire [(32)-1:0] wb_bram_rxwdata;
wire [(32/8)-1:0] wb_bram_rxwstrb;
wire wb_bram_rxwlast;
wire wb_bram_rxbready;
wire wb_bram_rxbvalid;
wire [(1)-1:0] wb_bram_rxbid;
wire [(2)-1:0] wb_bram_rxbresp;
wire wb_bram_rxarready;
wire wb_bram_rxarvalid;
wire [(32)-1:0] wb_bram_rxaraddr;
wire [(1)-1:0] wb_bram_rxarid;
wire [(8)-1:0] wb_bram_rxarlen;
wire [(3)-1:0] wb_bram_rxarsize;
wire [(2)-1:0] wb_bram_rxarburst;
wire wb_bram_rxrready;
wire wb_bram_rxrvalid;
wire [(1)-1:0] wb_bram_rxrid;
wire [(32)-1:0] wb_bram_rxrdata;
wire wb_bram_rxrlast;
wire [(2)-1:0] wb_bram_rxrresp;
wire output_bram_clk;
wire output_bram_rstnn;
wire output_bram_rxawready;
wire output_bram_rxawvalid;
wire [(32)-1:0] output_bram_rxawaddr;
wire [(1)-1:0] output_bram_rxawid;
wire [(8)-1:0] output_bram_rxawlen;
wire [(3)-1:0] output_bram_rxawsize;
wire [(2)-1:0] output_bram_rxawburst;
wire output_bram_rxwready;
wire output_bram_rxwvalid;
wire [(1)-1:0] output_bram_rxwid;
wire [(32)-1:0] output_bram_rxwdata;
wire [(32/8)-1:0] output_bram_rxwstrb;
wire output_bram_rxwlast;
wire output_bram_rxbready;
wire output_bram_rxbvalid;
wire [(1)-1:0] output_bram_rxbid;
wire [(2)-1:0] output_bram_rxbresp;
wire output_bram_rxarready;
wire output_bram_rxarvalid;
wire [(32)-1:0] output_bram_rxaraddr;
wire [(1)-1:0] output_bram_rxarid;
wire [(8)-1:0] output_bram_rxarlen;
wire [(3)-1:0] output_bram_rxarsize;
wire [(2)-1:0] output_bram_rxarburst;
wire output_bram_rxrready;
wire output_bram_rxrvalid;
wire [(1)-1:0] output_bram_rxrid;
wire [(32)-1:0] output_bram_rxrdata;
wire output_bram_rxrlast;
wire [(2)-1:0] output_bram_rxrresp;
wire i_system_ddr_clk_ref;
wire i_system_ddr_clk_sys;
wire i_system_ddr_rstnn_sys;
wire i_system_ddr_clk_dram_if;
wire i_system_ddr_rstnn_dram_if;
wire i_system_ddr_initialized;
wire i_system_ddr_rxawready;
wire i_system_ddr_rxawvalid;
wire [(32)-1:0] i_system_ddr_rxawaddr;
wire [(16)-1:0] i_system_ddr_rxawid;
wire [(8)-1:0] i_system_ddr_rxawlen;
wire [(3)-1:0] i_system_ddr_rxawsize;
wire [(2)-1:0] i_system_ddr_rxawburst;
wire i_system_ddr_rxwready;
wire i_system_ddr_rxwvalid;
wire [(16)-1:0] i_system_ddr_rxwid;
wire [(128)-1:0] i_system_ddr_rxwdata;
wire [(128/8)-1:0] i_system_ddr_rxwstrb;
wire i_system_ddr_rxwlast;
wire i_system_ddr_rxbready;
wire i_system_ddr_rxbvalid;
wire [(16)-1:0] i_system_ddr_rxbid;
wire [(2)-1:0] i_system_ddr_rxbresp;
wire i_system_ddr_rxarready;
wire i_system_ddr_rxarvalid;
wire [(32)-1:0] i_system_ddr_rxaraddr;
wire [(16)-1:0] i_system_ddr_rxarid;
wire [(8)-1:0] i_system_ddr_rxarlen;
wire [(3)-1:0] i_system_ddr_rxarsize;
wire [(2)-1:0] i_system_ddr_rxarburst;
wire i_system_ddr_rxrready;
wire i_system_ddr_rxrvalid;
wire [(16)-1:0] i_system_ddr_rxrid;
wire [(128)-1:0] i_system_ddr_rxrdata;
wire i_system_ddr_rxrlast;
wire [(2)-1:0] i_system_ddr_rxrresp;
wire i_pll0_external_clk;
wire i_pll0_external_clk_pair;
wire i_pll0_external_rstnn;
wire i_pll0_clk_25M;
wire i_pll0_clk_system;
wire i_pll0_clk_core;
wire i_pll0_clk_150M;
wire i_pll0_clk_200M;
wire i_pll0_clk_300M;
wire i_pll0_clk_dram_sys;
wire i_pll0_clk_dram_ref;
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
wire [(128)-1:0] i_system_sram_rxwdata;
wire [(128/8)-1:0] i_system_sram_rxwstrb;
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
wire [(128)-1:0] i_system_sram_rxrdata;
wire i_system_sram_rxrlast;
wire [(2)-1:0] i_system_sram_rxrresp;

U504_RTL
i_rtl
(
	.clk_core(i_rtl_clk_core),
	.clk_system(i_rtl_clk_system),
	.clk_system_external(i_rtl_clk_system_external),
	.clk_system_debug(i_rtl_clk_system_debug),
	.clk_local_access(i_rtl_clk_local_access),
	.clk_process_000(i_rtl_clk_process_000),
	.clk_dram_if(i_rtl_clk_dram_if),
	.clk_dram_sys(i_rtl_clk_dram_sys),
	.clk_dram_ref(i_rtl_clk_dram_ref),
	.clk_noc(i_rtl_clk_noc),
	.clk_25M(i_rtl_clk_25M),
	.clk_50M(i_rtl_clk_50M),
	.clk_150M(i_rtl_clk_150M),
	.clk_200M(i_rtl_clk_200M),
	.clk_300M(i_rtl_clk_300M),
	.gclk_core(i_rtl_gclk_core),
	.gclk_system(i_rtl_gclk_system),
	.gclk_system_external(i_rtl_gclk_system_external),
	.gclk_system_debug(i_rtl_gclk_system_debug),
	.gclk_local_access(i_rtl_gclk_local_access),
	.gclk_process_000(i_rtl_gclk_process_000),
	.gclk_noc(i_rtl_gclk_noc),
	.gclk_25M(i_rtl_gclk_25M),
	.gclk_50M(i_rtl_gclk_50M),
	.gclk_150M(i_rtl_gclk_150M),
	.gclk_200M(i_rtl_gclk_200M),
	.gclk_300M(i_rtl_gclk_300M),
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
	.led_list(i_rtl_led_list),
	.eMamba_IP_clk(i_rtl_eMamba_IP_clk),
	.eMamba_IP_rstnn(i_rtl_eMamba_IP_rstnn),
	.input_bram_clk(i_rtl_input_bram_clk),
	.input_bram_rstnn(i_rtl_input_bram_rstnn),
	.wb_bram_clk(i_rtl_wb_bram_clk),
	.wb_bram_rstnn(i_rtl_wb_bram_rstnn),
	.output_bram_clk(i_rtl_output_bram_clk),
	.output_bram_rstnn(i_rtl_output_bram_rstnn),
	.i_system_ddr_clk_ref(i_rtl_i_system_ddr_clk_ref),
	.i_system_ddr_clk_sys(i_rtl_i_system_ddr_clk_sys),
	.i_system_ddr_rstnn_sys(i_rtl_i_system_ddr_rstnn_sys),
	.i_system_ddr_clk_dram_if(i_rtl_i_system_ddr_clk_dram_if),
	.i_system_ddr_rstnn_dram_if(i_rtl_i_system_ddr_rstnn_dram_if),
	.i_system_ddr_initialized(i_rtl_i_system_ddr_initialized),
	.i_pll0_external_rstnn(i_rtl_i_pll0_external_rstnn),
	.i_pll0_clk_25M(i_rtl_i_pll0_clk_25M),
	.i_pll0_clk_system(i_rtl_i_pll0_clk_system),
	.i_pll0_clk_core(i_rtl_i_pll0_clk_core),
	.i_pll0_clk_150M(i_rtl_i_pll0_clk_150M),
	.i_pll0_clk_200M(i_rtl_i_pll0_clk_200M),
	.i_pll0_clk_300M(i_rtl_i_pll0_clk_300M),
	.i_pll0_clk_dram_sys(i_rtl_i_pll0_clk_dram_sys),
	.i_pll0_clk_dram_ref(i_rtl_i_pll0_clk_dram_ref),
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
	.input_bram_sxawready(i_rtl_input_bram_sxawready),
	.input_bram_sxawvalid(i_rtl_input_bram_sxawvalid),
	.input_bram_sxawaddr(i_rtl_input_bram_sxawaddr),
	.input_bram_sxawid(i_rtl_input_bram_sxawid),
	.input_bram_sxawlen(i_rtl_input_bram_sxawlen),
	.input_bram_sxawsize(i_rtl_input_bram_sxawsize),
	.input_bram_sxawburst(i_rtl_input_bram_sxawburst),
	.input_bram_sxwready(i_rtl_input_bram_sxwready),
	.input_bram_sxwvalid(i_rtl_input_bram_sxwvalid),
	.input_bram_sxwid(i_rtl_input_bram_sxwid),
	.input_bram_sxwdata(i_rtl_input_bram_sxwdata),
	.input_bram_sxwstrb(i_rtl_input_bram_sxwstrb),
	.input_bram_sxwlast(i_rtl_input_bram_sxwlast),
	.input_bram_sxbready(i_rtl_input_bram_sxbready),
	.input_bram_sxbvalid(i_rtl_input_bram_sxbvalid),
	.input_bram_sxbid(i_rtl_input_bram_sxbid),
	.input_bram_sxbresp(i_rtl_input_bram_sxbresp),
	.input_bram_sxarready(i_rtl_input_bram_sxarready),
	.input_bram_sxarvalid(i_rtl_input_bram_sxarvalid),
	.input_bram_sxaraddr(i_rtl_input_bram_sxaraddr),
	.input_bram_sxarid(i_rtl_input_bram_sxarid),
	.input_bram_sxarlen(i_rtl_input_bram_sxarlen),
	.input_bram_sxarsize(i_rtl_input_bram_sxarsize),
	.input_bram_sxarburst(i_rtl_input_bram_sxarburst),
	.input_bram_sxrready(i_rtl_input_bram_sxrready),
	.input_bram_sxrvalid(i_rtl_input_bram_sxrvalid),
	.input_bram_sxrid(i_rtl_input_bram_sxrid),
	.input_bram_sxrdata(i_rtl_input_bram_sxrdata),
	.input_bram_sxrlast(i_rtl_input_bram_sxrlast),
	.input_bram_sxrresp(i_rtl_input_bram_sxrresp),
	.wb_bram_sxawready(i_rtl_wb_bram_sxawready),
	.wb_bram_sxawvalid(i_rtl_wb_bram_sxawvalid),
	.wb_bram_sxawaddr(i_rtl_wb_bram_sxawaddr),
	.wb_bram_sxawid(i_rtl_wb_bram_sxawid),
	.wb_bram_sxawlen(i_rtl_wb_bram_sxawlen),
	.wb_bram_sxawsize(i_rtl_wb_bram_sxawsize),
	.wb_bram_sxawburst(i_rtl_wb_bram_sxawburst),
	.wb_bram_sxwready(i_rtl_wb_bram_sxwready),
	.wb_bram_sxwvalid(i_rtl_wb_bram_sxwvalid),
	.wb_bram_sxwid(i_rtl_wb_bram_sxwid),
	.wb_bram_sxwdata(i_rtl_wb_bram_sxwdata),
	.wb_bram_sxwstrb(i_rtl_wb_bram_sxwstrb),
	.wb_bram_sxwlast(i_rtl_wb_bram_sxwlast),
	.wb_bram_sxbready(i_rtl_wb_bram_sxbready),
	.wb_bram_sxbvalid(i_rtl_wb_bram_sxbvalid),
	.wb_bram_sxbid(i_rtl_wb_bram_sxbid),
	.wb_bram_sxbresp(i_rtl_wb_bram_sxbresp),
	.wb_bram_sxarready(i_rtl_wb_bram_sxarready),
	.wb_bram_sxarvalid(i_rtl_wb_bram_sxarvalid),
	.wb_bram_sxaraddr(i_rtl_wb_bram_sxaraddr),
	.wb_bram_sxarid(i_rtl_wb_bram_sxarid),
	.wb_bram_sxarlen(i_rtl_wb_bram_sxarlen),
	.wb_bram_sxarsize(i_rtl_wb_bram_sxarsize),
	.wb_bram_sxarburst(i_rtl_wb_bram_sxarburst),
	.wb_bram_sxrready(i_rtl_wb_bram_sxrready),
	.wb_bram_sxrvalid(i_rtl_wb_bram_sxrvalid),
	.wb_bram_sxrid(i_rtl_wb_bram_sxrid),
	.wb_bram_sxrdata(i_rtl_wb_bram_sxrdata),
	.wb_bram_sxrlast(i_rtl_wb_bram_sxrlast),
	.wb_bram_sxrresp(i_rtl_wb_bram_sxrresp),
	.output_bram_sxawready(i_rtl_output_bram_sxawready),
	.output_bram_sxawvalid(i_rtl_output_bram_sxawvalid),
	.output_bram_sxawaddr(i_rtl_output_bram_sxawaddr),
	.output_bram_sxawid(i_rtl_output_bram_sxawid),
	.output_bram_sxawlen(i_rtl_output_bram_sxawlen),
	.output_bram_sxawsize(i_rtl_output_bram_sxawsize),
	.output_bram_sxawburst(i_rtl_output_bram_sxawburst),
	.output_bram_sxwready(i_rtl_output_bram_sxwready),
	.output_bram_sxwvalid(i_rtl_output_bram_sxwvalid),
	.output_bram_sxwid(i_rtl_output_bram_sxwid),
	.output_bram_sxwdata(i_rtl_output_bram_sxwdata),
	.output_bram_sxwstrb(i_rtl_output_bram_sxwstrb),
	.output_bram_sxwlast(i_rtl_output_bram_sxwlast),
	.output_bram_sxbready(i_rtl_output_bram_sxbready),
	.output_bram_sxbvalid(i_rtl_output_bram_sxbvalid),
	.output_bram_sxbid(i_rtl_output_bram_sxbid),
	.output_bram_sxbresp(i_rtl_output_bram_sxbresp),
	.output_bram_sxarready(i_rtl_output_bram_sxarready),
	.output_bram_sxarvalid(i_rtl_output_bram_sxarvalid),
	.output_bram_sxaraddr(i_rtl_output_bram_sxaraddr),
	.output_bram_sxarid(i_rtl_output_bram_sxarid),
	.output_bram_sxarlen(i_rtl_output_bram_sxarlen),
	.output_bram_sxarsize(i_rtl_output_bram_sxarsize),
	.output_bram_sxarburst(i_rtl_output_bram_sxarburst),
	.output_bram_sxrready(i_rtl_output_bram_sxrready),
	.output_bram_sxrvalid(i_rtl_output_bram_sxrvalid),
	.output_bram_sxrid(i_rtl_output_bram_sxrid),
	.output_bram_sxrdata(i_rtl_output_bram_sxrdata),
	.output_bram_sxrlast(i_rtl_output_bram_sxrlast),
	.output_bram_sxrresp(i_rtl_output_bram_sxrresp),
	.i_system_ddr_sxawready(i_rtl_i_system_ddr_sxawready),
	.i_system_ddr_sxawvalid(i_rtl_i_system_ddr_sxawvalid),
	.i_system_ddr_sxawaddr(i_rtl_i_system_ddr_sxawaddr),
	.i_system_ddr_sxawid(i_rtl_i_system_ddr_sxawid),
	.i_system_ddr_sxawlen(i_rtl_i_system_ddr_sxawlen),
	.i_system_ddr_sxawsize(i_rtl_i_system_ddr_sxawsize),
	.i_system_ddr_sxawburst(i_rtl_i_system_ddr_sxawburst),
	.i_system_ddr_sxwready(i_rtl_i_system_ddr_sxwready),
	.i_system_ddr_sxwvalid(i_rtl_i_system_ddr_sxwvalid),
	.i_system_ddr_sxwid(i_rtl_i_system_ddr_sxwid),
	.i_system_ddr_sxwdata(i_rtl_i_system_ddr_sxwdata),
	.i_system_ddr_sxwstrb(i_rtl_i_system_ddr_sxwstrb),
	.i_system_ddr_sxwlast(i_rtl_i_system_ddr_sxwlast),
	.i_system_ddr_sxbready(i_rtl_i_system_ddr_sxbready),
	.i_system_ddr_sxbvalid(i_rtl_i_system_ddr_sxbvalid),
	.i_system_ddr_sxbid(i_rtl_i_system_ddr_sxbid),
	.i_system_ddr_sxbresp(i_rtl_i_system_ddr_sxbresp),
	.i_system_ddr_sxarready(i_rtl_i_system_ddr_sxarready),
	.i_system_ddr_sxarvalid(i_rtl_i_system_ddr_sxarvalid),
	.i_system_ddr_sxaraddr(i_rtl_i_system_ddr_sxaraddr),
	.i_system_ddr_sxarid(i_rtl_i_system_ddr_sxarid),
	.i_system_ddr_sxarlen(i_rtl_i_system_ddr_sxarlen),
	.i_system_ddr_sxarsize(i_rtl_i_system_ddr_sxarsize),
	.i_system_ddr_sxarburst(i_rtl_i_system_ddr_sxarburst),
	.i_system_ddr_sxrready(i_rtl_i_system_ddr_sxrready),
	.i_system_ddr_sxrvalid(i_rtl_i_system_ddr_sxrvalid),
	.i_system_ddr_sxrid(i_rtl_i_system_ddr_sxrid),
	.i_system_ddr_sxrdata(i_rtl_i_system_ddr_sxrdata),
	.i_system_ddr_sxrlast(i_rtl_i_system_ddr_sxrlast),
	.i_system_ddr_sxrresp(i_rtl_i_system_ddr_sxrresp),
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
	`include "video_module_port_mapping.vh"
);

U504_FAST_DRAM_00
i_system_ddr
(
	.clk_ref(i_system_ddr_clk_ref),
	.clk_sys(i_system_ddr_clk_sys),
	.rstnn_sys(i_system_ddr_rstnn_sys),
	.clk_dram_if(i_system_ddr_clk_dram_if),
	.rstnn_dram_if(i_system_ddr_rstnn_dram_if),
	.initialized(i_system_ddr_initialized),
	.rxawready(i_system_ddr_rxawready),
	.rxawvalid(i_system_ddr_rxawvalid),
	.rxawaddr(i_system_ddr_rxawaddr),
	.rxawid(i_system_ddr_rxawid),
	.rxawlen(i_system_ddr_rxawlen),
	.rxawsize(i_system_ddr_rxawsize),
	.rxawburst(i_system_ddr_rxawburst),
	.rxwready(i_system_ddr_rxwready),
	.rxwvalid(i_system_ddr_rxwvalid),
	.rxwid(i_system_ddr_rxwid),
	.rxwdata(i_system_ddr_rxwdata),
	.rxwstrb(i_system_ddr_rxwstrb),
	.rxwlast(i_system_ddr_rxwlast),
	.rxbready(i_system_ddr_rxbready),
	.rxbvalid(i_system_ddr_rxbvalid),
	.rxbid(i_system_ddr_rxbid),
	.rxbresp(i_system_ddr_rxbresp),
	.rxarready(i_system_ddr_rxarready),
	.rxarvalid(i_system_ddr_rxarvalid),
	.rxaraddr(i_system_ddr_rxaraddr),
	.rxarid(i_system_ddr_rxarid),
	.rxarlen(i_system_ddr_rxarlen),
	.rxarsize(i_system_ddr_rxarsize),
	.rxarburst(i_system_ddr_rxarburst),
	.rxrready(i_system_ddr_rxrready),
	.rxrvalid(i_system_ddr_rxrvalid),
	.rxrid(i_system_ddr_rxrid),
	.rxrdata(i_system_ddr_rxrdata),
	.rxrlast(i_system_ddr_rxrlast),
	.rxrresp(i_system_ddr_rxrresp)
	`include "fast_dram_cell_port_mapping.vh"
);

U504_CLOCK_PLL_0_01
i_pll0
(
	.external_clk(i_pll0_external_clk),
	.external_clk_pair(i_pll0_external_clk_pair),
	.external_rstnn(i_pll0_external_rstnn),
	.clk_25M(i_pll0_clk_25M),
	.clk_system(i_pll0_clk_system),
	.clk_core(i_pll0_clk_core),
	.clk_150M(i_pll0_clk_150M),
	.clk_200M(i_pll0_clk_200M),
	.clk_300M(i_pll0_clk_300M),
	.clk_dram_sys(i_pll0_clk_dram_sys),
	.clk_dram_ref(i_pll0_clk_dram_ref)
);

U504_SRAM_AXI_02
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
assign i_rtl_eMamba_IP_clk = eMamba_IP_clk;
assign eMamba_IP_rstnn = i_rtl_eMamba_IP_rstnn;
assign i_rtl_input_bram_clk = input_bram_clk;
assign input_bram_rstnn = i_rtl_input_bram_rstnn;
assign i_rtl_wb_bram_clk = wb_bram_clk;
assign wb_bram_rstnn = i_rtl_wb_bram_rstnn;
assign i_rtl_output_bram_clk = output_bram_clk;
assign output_bram_rstnn = i_rtl_output_bram_rstnn;
assign i_system_ddr_clk_ref = i_rtl_i_system_ddr_clk_ref;
assign i_system_ddr_clk_sys = i_rtl_i_system_ddr_clk_sys;
assign i_system_ddr_rstnn_sys = i_rtl_i_system_ddr_rstnn_sys;
assign i_rtl_i_system_ddr_clk_dram_if = i_system_ddr_clk_dram_if;
assign i_system_ddr_rstnn_dram_if = i_rtl_i_system_ddr_rstnn_dram_if;
assign i_rtl_i_system_ddr_initialized = i_system_ddr_initialized;
assign i_pll0_external_clk = external_clk_0;
assign i_pll0_external_clk_pair = external_clk_0_pair;
assign i_pll0_external_rstnn = i_rtl_i_pll0_external_rstnn;
assign i_rtl_i_pll0_clk_25M = i_pll0_clk_25M;
assign i_rtl_i_pll0_clk_system = i_pll0_clk_system;
assign i_rtl_i_pll0_clk_core = i_pll0_clk_core;
assign i_rtl_i_pll0_clk_150M = i_pll0_clk_150M;
assign i_rtl_i_pll0_clk_200M = i_pll0_clk_200M;
assign i_rtl_i_pll0_clk_300M = i_pll0_clk_300M;
assign i_rtl_i_pll0_clk_dram_sys = i_pll0_clk_dram_sys;
assign i_rtl_i_pll0_clk_dram_ref = i_pll0_clk_dram_ref;
assign i_system_sram_clk = i_rtl_i_system_sram_clk;
assign i_system_sram_rstnn = i_rtl_i_system_sram_rstnn;
assign clk_core = i_rtl_clk_core;
assign clk_system = i_rtl_clk_system;
assign clk_system_external = i_rtl_clk_system_external;
assign clk_system_debug = i_rtl_clk_system_debug;
assign clk_local_access = i_rtl_clk_local_access;
assign clk_process_000 = i_rtl_clk_process_000;
assign clk_dram_if = i_rtl_clk_dram_if;
assign clk_dram_sys = i_rtl_clk_dram_sys;
assign clk_dram_ref = i_rtl_clk_dram_ref;
assign clk_noc = i_rtl_clk_noc;
assign clk_25M = i_rtl_clk_25M;
assign clk_50M = i_rtl_clk_50M;
assign clk_150M = i_rtl_clk_150M;
assign clk_200M = i_rtl_clk_200M;
assign clk_300M = i_rtl_clk_300M;
assign gclk_core = i_rtl_gclk_core;
assign gclk_system = i_rtl_gclk_system;
assign gclk_system_external = i_rtl_gclk_system_external;
assign gclk_system_debug = i_rtl_gclk_system_debug;
assign gclk_local_access = i_rtl_gclk_local_access;
assign gclk_process_000 = i_rtl_gclk_process_000;
assign gclk_noc = i_rtl_gclk_noc;
assign gclk_25M = i_rtl_gclk_25M;
assign gclk_50M = i_rtl_gclk_50M;
assign gclk_150M = i_rtl_gclk_150M;
assign gclk_200M = i_rtl_gclk_200M;
assign gclk_300M = i_rtl_gclk_300M;
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
assign led_list[1*(0+1)-1 -:1] = i_rtl_led_list[1*(0+1)-1 -:1];
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
assign i_rtl_input_bram_sxawready = input_bram_rxawready;
assign input_bram_rxawvalid = i_rtl_input_bram_sxawvalid;
assign input_bram_rxawaddr = i_rtl_input_bram_sxawaddr;
assign input_bram_rxawid = i_rtl_input_bram_sxawid;
assign input_bram_rxawlen = i_rtl_input_bram_sxawlen;
assign input_bram_rxawsize = i_rtl_input_bram_sxawsize;
assign input_bram_rxawburst = i_rtl_input_bram_sxawburst;
assign i_rtl_input_bram_sxwready = input_bram_rxwready;
assign input_bram_rxwvalid = i_rtl_input_bram_sxwvalid;
assign input_bram_rxwid = i_rtl_input_bram_sxwid;
assign input_bram_rxwdata = i_rtl_input_bram_sxwdata;
assign input_bram_rxwstrb = i_rtl_input_bram_sxwstrb;
assign input_bram_rxwlast = i_rtl_input_bram_sxwlast;
assign input_bram_rxbready = i_rtl_input_bram_sxbready;
assign i_rtl_input_bram_sxbvalid = input_bram_rxbvalid;
assign i_rtl_input_bram_sxbid = input_bram_rxbid;
assign i_rtl_input_bram_sxbresp = input_bram_rxbresp;
assign i_rtl_input_bram_sxarready = input_bram_rxarready;
assign input_bram_rxarvalid = i_rtl_input_bram_sxarvalid;
assign input_bram_rxaraddr = i_rtl_input_bram_sxaraddr;
assign input_bram_rxarid = i_rtl_input_bram_sxarid;
assign input_bram_rxarlen = i_rtl_input_bram_sxarlen;
assign input_bram_rxarsize = i_rtl_input_bram_sxarsize;
assign input_bram_rxarburst = i_rtl_input_bram_sxarburst;
assign input_bram_rxrready = i_rtl_input_bram_sxrready;
assign i_rtl_input_bram_sxrvalid = input_bram_rxrvalid;
assign i_rtl_input_bram_sxrid = input_bram_rxrid;
assign i_rtl_input_bram_sxrdata = input_bram_rxrdata;
assign i_rtl_input_bram_sxrlast = input_bram_rxrlast;
assign i_rtl_input_bram_sxrresp = input_bram_rxrresp;
assign i_rtl_wb_bram_sxawready = wb_bram_rxawready;
assign wb_bram_rxawvalid = i_rtl_wb_bram_sxawvalid;
assign wb_bram_rxawaddr = i_rtl_wb_bram_sxawaddr;
assign wb_bram_rxawid = i_rtl_wb_bram_sxawid;
assign wb_bram_rxawlen = i_rtl_wb_bram_sxawlen;
assign wb_bram_rxawsize = i_rtl_wb_bram_sxawsize;
assign wb_bram_rxawburst = i_rtl_wb_bram_sxawburst;
assign i_rtl_wb_bram_sxwready = wb_bram_rxwready;
assign wb_bram_rxwvalid = i_rtl_wb_bram_sxwvalid;
assign wb_bram_rxwid = i_rtl_wb_bram_sxwid;
assign wb_bram_rxwdata = i_rtl_wb_bram_sxwdata;
assign wb_bram_rxwstrb = i_rtl_wb_bram_sxwstrb;
assign wb_bram_rxwlast = i_rtl_wb_bram_sxwlast;
assign wb_bram_rxbready = i_rtl_wb_bram_sxbready;
assign i_rtl_wb_bram_sxbvalid = wb_bram_rxbvalid;
assign i_rtl_wb_bram_sxbid = wb_bram_rxbid;
assign i_rtl_wb_bram_sxbresp = wb_bram_rxbresp;
assign i_rtl_wb_bram_sxarready = wb_bram_rxarready;
assign wb_bram_rxarvalid = i_rtl_wb_bram_sxarvalid;
assign wb_bram_rxaraddr = i_rtl_wb_bram_sxaraddr;
assign wb_bram_rxarid = i_rtl_wb_bram_sxarid;
assign wb_bram_rxarlen = i_rtl_wb_bram_sxarlen;
assign wb_bram_rxarsize = i_rtl_wb_bram_sxarsize;
assign wb_bram_rxarburst = i_rtl_wb_bram_sxarburst;
assign wb_bram_rxrready = i_rtl_wb_bram_sxrready;
assign i_rtl_wb_bram_sxrvalid = wb_bram_rxrvalid;
assign i_rtl_wb_bram_sxrid = wb_bram_rxrid;
assign i_rtl_wb_bram_sxrdata = wb_bram_rxrdata;
assign i_rtl_wb_bram_sxrlast = wb_bram_rxrlast;
assign i_rtl_wb_bram_sxrresp = wb_bram_rxrresp;
assign i_rtl_output_bram_sxawready = output_bram_rxawready;
assign output_bram_rxawvalid = i_rtl_output_bram_sxawvalid;
assign output_bram_rxawaddr = i_rtl_output_bram_sxawaddr;
assign output_bram_rxawid = i_rtl_output_bram_sxawid;
assign output_bram_rxawlen = i_rtl_output_bram_sxawlen;
assign output_bram_rxawsize = i_rtl_output_bram_sxawsize;
assign output_bram_rxawburst = i_rtl_output_bram_sxawburst;
assign i_rtl_output_bram_sxwready = output_bram_rxwready;
assign output_bram_rxwvalid = i_rtl_output_bram_sxwvalid;
assign output_bram_rxwid = i_rtl_output_bram_sxwid;
assign output_bram_rxwdata = i_rtl_output_bram_sxwdata;
assign output_bram_rxwstrb = i_rtl_output_bram_sxwstrb;
assign output_bram_rxwlast = i_rtl_output_bram_sxwlast;
assign output_bram_rxbready = i_rtl_output_bram_sxbready;
assign i_rtl_output_bram_sxbvalid = output_bram_rxbvalid;
assign i_rtl_output_bram_sxbid = output_bram_rxbid;
assign i_rtl_output_bram_sxbresp = output_bram_rxbresp;
assign i_rtl_output_bram_sxarready = output_bram_rxarready;
assign output_bram_rxarvalid = i_rtl_output_bram_sxarvalid;
assign output_bram_rxaraddr = i_rtl_output_bram_sxaraddr;
assign output_bram_rxarid = i_rtl_output_bram_sxarid;
assign output_bram_rxarlen = i_rtl_output_bram_sxarlen;
assign output_bram_rxarsize = i_rtl_output_bram_sxarsize;
assign output_bram_rxarburst = i_rtl_output_bram_sxarburst;
assign output_bram_rxrready = i_rtl_output_bram_sxrready;
assign i_rtl_output_bram_sxrvalid = output_bram_rxrvalid;
assign i_rtl_output_bram_sxrid = output_bram_rxrid;
assign i_rtl_output_bram_sxrdata = output_bram_rxrdata;
assign i_rtl_output_bram_sxrlast = output_bram_rxrlast;
assign i_rtl_output_bram_sxrresp = output_bram_rxrresp;
assign i_rtl_i_system_ddr_sxawready = i_system_ddr_rxawready;
assign i_system_ddr_rxawvalid = i_rtl_i_system_ddr_sxawvalid;
assign i_system_ddr_rxawaddr = i_rtl_i_system_ddr_sxawaddr;
assign i_system_ddr_rxawid = i_rtl_i_system_ddr_sxawid;
assign i_system_ddr_rxawlen = i_rtl_i_system_ddr_sxawlen;
assign i_system_ddr_rxawsize = i_rtl_i_system_ddr_sxawsize;
assign i_system_ddr_rxawburst = i_rtl_i_system_ddr_sxawburst;
assign i_rtl_i_system_ddr_sxwready = i_system_ddr_rxwready;
assign i_system_ddr_rxwvalid = i_rtl_i_system_ddr_sxwvalid;
assign i_system_ddr_rxwid = i_rtl_i_system_ddr_sxwid;
assign i_system_ddr_rxwdata = i_rtl_i_system_ddr_sxwdata;
assign i_system_ddr_rxwstrb = i_rtl_i_system_ddr_sxwstrb;
assign i_system_ddr_rxwlast = i_rtl_i_system_ddr_sxwlast;
assign i_system_ddr_rxbready = i_rtl_i_system_ddr_sxbready;
assign i_rtl_i_system_ddr_sxbvalid = i_system_ddr_rxbvalid;
assign i_rtl_i_system_ddr_sxbid = i_system_ddr_rxbid;
assign i_rtl_i_system_ddr_sxbresp = i_system_ddr_rxbresp;
assign i_rtl_i_system_ddr_sxarready = i_system_ddr_rxarready;
assign i_system_ddr_rxarvalid = i_rtl_i_system_ddr_sxarvalid;
assign i_system_ddr_rxaraddr = i_rtl_i_system_ddr_sxaraddr;
assign i_system_ddr_rxarid = i_rtl_i_system_ddr_sxarid;
assign i_system_ddr_rxarlen = i_rtl_i_system_ddr_sxarlen;
assign i_system_ddr_rxarsize = i_rtl_i_system_ddr_sxarsize;
assign i_system_ddr_rxarburst = i_rtl_i_system_ddr_sxarburst;
assign i_system_ddr_rxrready = i_rtl_i_system_ddr_sxrready;
assign i_rtl_i_system_ddr_sxrvalid = i_system_ddr_rxrvalid;
assign i_rtl_i_system_ddr_sxrid = i_system_ddr_rxrid;
assign i_rtl_i_system_ddr_sxrdata = i_system_ddr_rxrdata;
assign i_rtl_i_system_ddr_sxrlast = i_system_ddr_rxrlast;
assign i_rtl_i_system_ddr_sxrresp = i_system_ddr_rxrresp;
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

`include "u504_user_region.vh"

`ifdef USE_ILA
`include "ila_description.vh"
`endif

endmodule