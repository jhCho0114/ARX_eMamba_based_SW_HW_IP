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

module U504_RTL
(
	clk_core,
	clk_system,
	clk_system_external,
	clk_system_debug,
	clk_local_access,
	clk_process_000,
	clk_dram_if,
	clk_dram_sys,
	clk_dram_ref,
	clk_noc,
	clk_25M,
	clk_50M,
	clk_150M,
	clk_200M,
	clk_300M,
	gclk_core,
	gclk_system,
	gclk_system_external,
	gclk_system_debug,
	gclk_local_access,
	gclk_process_000,
	gclk_noc,
	gclk_25M,
	gclk_50M,
	gclk_150M,
	gclk_200M,
	gclk_300M,
	tick_1us,
	tick_62d5ms,
	tick_gpio,
	spi_common_sclk,
	spi_common_sdq0,
	external_rstnn,
	global_rstnn,
	global_rstpp,
	rstnn_seqeunce,
	rstpp_seqeunce,
	rstnn_user,
	rstpp_user,
	led_list,
	eMamba_IP_clk,
	eMamba_IP_rstnn,
	input_bram_clk,
	input_bram_rstnn,
	wb_bram_clk,
	wb_bram_rstnn,
	output_bram_clk,
	output_bram_rstnn,
	i_system_ddr_clk_ref,
	i_system_ddr_clk_sys,
	i_system_ddr_rstnn_sys,
	i_system_ddr_clk_dram_if,
	i_system_ddr_rstnn_dram_if,
	i_system_ddr_initialized,
	i_pll0_external_rstnn,
	i_pll0_clk_25M,
	i_pll0_clk_system,
	i_pll0_clk_core,
	i_pll0_clk_150M,
	i_pll0_clk_200M,
	i_pll0_clk_300M,
	i_pll0_clk_dram_sys,
	i_pll0_clk_dram_ref,
	i_system_sram_clk,
	i_system_sram_rstnn,
	pjtag_rtck,
	pjtag_rtrstnn,
	pjtag_rtms,
	pjtag_rtdi,
	pjtag_rtdo,
	printf_tx,
	printf_rx,
	eMamba_IP_sx4awready,
	eMamba_IP_sx4awvalid,
	eMamba_IP_sx4awaddr,
	eMamba_IP_sx4awid,
	eMamba_IP_sx4awlen,
	eMamba_IP_sx4awsize,
	eMamba_IP_sx4awburst,
	eMamba_IP_sx4wready,
	eMamba_IP_sx4wvalid,
	eMamba_IP_sx4wdata,
	eMamba_IP_sx4wstrb,
	eMamba_IP_sx4wlast,
	eMamba_IP_sx4bready,
	eMamba_IP_sx4bvalid,
	eMamba_IP_sx4bid,
	eMamba_IP_sx4bresp,
	eMamba_IP_sx4arready,
	eMamba_IP_sx4arvalid,
	eMamba_IP_sx4araddr,
	eMamba_IP_sx4arid,
	eMamba_IP_sx4arlen,
	eMamba_IP_sx4arsize,
	eMamba_IP_sx4arburst,
	eMamba_IP_sx4rready,
	eMamba_IP_sx4rvalid,
	eMamba_IP_sx4rid,
	eMamba_IP_sx4rdata,
	eMamba_IP_sx4rlast,
	eMamba_IP_sx4rresp,
	input_bram_sxawready,
	input_bram_sxawvalid,
	input_bram_sxawaddr,
	input_bram_sxawid,
	input_bram_sxawlen,
	input_bram_sxawsize,
	input_bram_sxawburst,
	input_bram_sxwready,
	input_bram_sxwvalid,
	input_bram_sxwid,
	input_bram_sxwdata,
	input_bram_sxwstrb,
	input_bram_sxwlast,
	input_bram_sxbready,
	input_bram_sxbvalid,
	input_bram_sxbid,
	input_bram_sxbresp,
	input_bram_sxarready,
	input_bram_sxarvalid,
	input_bram_sxaraddr,
	input_bram_sxarid,
	input_bram_sxarlen,
	input_bram_sxarsize,
	input_bram_sxarburst,
	input_bram_sxrready,
	input_bram_sxrvalid,
	input_bram_sxrid,
	input_bram_sxrdata,
	input_bram_sxrlast,
	input_bram_sxrresp,
	wb_bram_sxawready,
	wb_bram_sxawvalid,
	wb_bram_sxawaddr,
	wb_bram_sxawid,
	wb_bram_sxawlen,
	wb_bram_sxawsize,
	wb_bram_sxawburst,
	wb_bram_sxwready,
	wb_bram_sxwvalid,
	wb_bram_sxwid,
	wb_bram_sxwdata,
	wb_bram_sxwstrb,
	wb_bram_sxwlast,
	wb_bram_sxbready,
	wb_bram_sxbvalid,
	wb_bram_sxbid,
	wb_bram_sxbresp,
	wb_bram_sxarready,
	wb_bram_sxarvalid,
	wb_bram_sxaraddr,
	wb_bram_sxarid,
	wb_bram_sxarlen,
	wb_bram_sxarsize,
	wb_bram_sxarburst,
	wb_bram_sxrready,
	wb_bram_sxrvalid,
	wb_bram_sxrid,
	wb_bram_sxrdata,
	wb_bram_sxrlast,
	wb_bram_sxrresp,
	output_bram_sxawready,
	output_bram_sxawvalid,
	output_bram_sxawaddr,
	output_bram_sxawid,
	output_bram_sxawlen,
	output_bram_sxawsize,
	output_bram_sxawburst,
	output_bram_sxwready,
	output_bram_sxwvalid,
	output_bram_sxwid,
	output_bram_sxwdata,
	output_bram_sxwstrb,
	output_bram_sxwlast,
	output_bram_sxbready,
	output_bram_sxbvalid,
	output_bram_sxbid,
	output_bram_sxbresp,
	output_bram_sxarready,
	output_bram_sxarvalid,
	output_bram_sxaraddr,
	output_bram_sxarid,
	output_bram_sxarlen,
	output_bram_sxarsize,
	output_bram_sxarburst,
	output_bram_sxrready,
	output_bram_sxrvalid,
	output_bram_sxrid,
	output_bram_sxrdata,
	output_bram_sxrlast,
	output_bram_sxrresp,
	i_system_ddr_sxawready,
	i_system_ddr_sxawvalid,
	i_system_ddr_sxawaddr,
	i_system_ddr_sxawid,
	i_system_ddr_sxawlen,
	i_system_ddr_sxawsize,
	i_system_ddr_sxawburst,
	i_system_ddr_sxwready,
	i_system_ddr_sxwvalid,
	i_system_ddr_sxwid,
	i_system_ddr_sxwdata,
	i_system_ddr_sxwstrb,
	i_system_ddr_sxwlast,
	i_system_ddr_sxbready,
	i_system_ddr_sxbvalid,
	i_system_ddr_sxbid,
	i_system_ddr_sxbresp,
	i_system_ddr_sxarready,
	i_system_ddr_sxarvalid,
	i_system_ddr_sxaraddr,
	i_system_ddr_sxarid,
	i_system_ddr_sxarlen,
	i_system_ddr_sxarsize,
	i_system_ddr_sxarburst,
	i_system_ddr_sxrready,
	i_system_ddr_sxrvalid,
	i_system_ddr_sxrid,
	i_system_ddr_sxrdata,
	i_system_ddr_sxrlast,
	i_system_ddr_sxrresp,
	i_system_sram_sxawready,
	i_system_sram_sxawvalid,
	i_system_sram_sxawaddr,
	i_system_sram_sxawid,
	i_system_sram_sxawlen,
	i_system_sram_sxawsize,
	i_system_sram_sxawburst,
	i_system_sram_sxwready,
	i_system_sram_sxwvalid,
	i_system_sram_sxwid,
	i_system_sram_sxwdata,
	i_system_sram_sxwstrb,
	i_system_sram_sxwlast,
	i_system_sram_sxbready,
	i_system_sram_sxbvalid,
	i_system_sram_sxbid,
	i_system_sram_sxbresp,
	i_system_sram_sxarready,
	i_system_sram_sxarvalid,
	i_system_sram_sxaraddr,
	i_system_sram_sxarid,
	i_system_sram_sxarlen,
	i_system_sram_sxarsize,
	i_system_sram_sxarburst,
	i_system_sram_sxrready,
	i_system_sram_sxrvalid,
	i_system_sram_sxrid,
	i_system_sram_sxrdata,
	i_system_sram_sxrlast,
	i_system_sram_sxrresp
	`include "video_module_port_dec.vh"
);

parameter BW_FNI_PHIT = `MAX_BW_FNI_PHIT;
parameter BW_BNI_PHIT = `MAX_BW_BNI_PHIT;

output wire clk_core;
output wire clk_system;
output wire clk_system_external;
output wire clk_system_debug;
output wire clk_local_access;
output wire clk_process_000;
output wire clk_dram_if;
output wire clk_dram_sys;
output wire clk_dram_ref;
output wire clk_noc;
output wire clk_25M;
output wire clk_50M;
output wire clk_150M;
output wire clk_200M;
output wire clk_300M;
output wire gclk_core;
output wire gclk_system;
output wire gclk_system_external;
output wire gclk_system_debug;
output wire gclk_local_access;
output wire gclk_process_000;
output wire gclk_noc;
output wire gclk_25M;
output wire gclk_50M;
output wire gclk_150M;
output wire gclk_200M;
output wire gclk_300M;
output wire tick_1us;
output wire tick_62d5ms;
output wire tick_gpio;
output wire spi_common_sclk;
output wire spi_common_sdq0;
input wire external_rstnn;
output wire global_rstnn;
output wire global_rstpp;
output wire [(7)-1:0] rstnn_seqeunce;
output wire [(7)-1:0] rstpp_seqeunce;
output wire rstnn_user;
output wire rstpp_user;
output wire [((1)*(1))-1:0] led_list;
input wire eMamba_IP_clk;
output wire eMamba_IP_rstnn;
input wire input_bram_clk;
output wire input_bram_rstnn;
input wire wb_bram_clk;
output wire wb_bram_rstnn;
input wire output_bram_clk;
output wire output_bram_rstnn;
output wire i_system_ddr_clk_ref;
output wire i_system_ddr_clk_sys;
output wire i_system_ddr_rstnn_sys;
input wire i_system_ddr_clk_dram_if;
output wire i_system_ddr_rstnn_dram_if;
input wire i_system_ddr_initialized;
output wire i_pll0_external_rstnn;
input wire i_pll0_clk_25M;
input wire i_pll0_clk_system;
input wire i_pll0_clk_core;
input wire i_pll0_clk_150M;
input wire i_pll0_clk_200M;
input wire i_pll0_clk_300M;
input wire i_pll0_clk_dram_sys;
input wire i_pll0_clk_dram_ref;
output wire i_system_sram_clk;
output wire i_system_sram_rstnn;
input wire pjtag_rtck;
input wire pjtag_rtrstnn;
input wire pjtag_rtms;
input wire pjtag_rtdi;
output wire pjtag_rtdo;
output wire printf_tx;
input wire printf_rx;
input wire eMamba_IP_sx4awready;
output wire eMamba_IP_sx4awvalid;
output wire [(32)-1:0] eMamba_IP_sx4awaddr;
output wire [(1)-1:0] eMamba_IP_sx4awid;
output wire [(8)-1:0] eMamba_IP_sx4awlen;
output wire [(3)-1:0] eMamba_IP_sx4awsize;
output wire [(2)-1:0] eMamba_IP_sx4awburst;
input wire eMamba_IP_sx4wready;
output wire eMamba_IP_sx4wvalid;
output wire [(32)-1:0] eMamba_IP_sx4wdata;
output wire [(32/8)-1:0] eMamba_IP_sx4wstrb;
output wire eMamba_IP_sx4wlast;
output wire eMamba_IP_sx4bready;
input wire eMamba_IP_sx4bvalid;
input wire [(1)-1:0] eMamba_IP_sx4bid;
input wire [(2)-1:0] eMamba_IP_sx4bresp;
input wire eMamba_IP_sx4arready;
output wire eMamba_IP_sx4arvalid;
output wire [(32)-1:0] eMamba_IP_sx4araddr;
output wire [(1)-1:0] eMamba_IP_sx4arid;
output wire [(8)-1:0] eMamba_IP_sx4arlen;
output wire [(3)-1:0] eMamba_IP_sx4arsize;
output wire [(2)-1:0] eMamba_IP_sx4arburst;
output wire eMamba_IP_sx4rready;
input wire eMamba_IP_sx4rvalid;
input wire [(1)-1:0] eMamba_IP_sx4rid;
input wire [(32)-1:0] eMamba_IP_sx4rdata;
input wire eMamba_IP_sx4rlast;
input wire [(2)-1:0] eMamba_IP_sx4rresp;
input wire input_bram_sxawready;
output wire input_bram_sxawvalid;
output wire [(32)-1:0] input_bram_sxawaddr;
output wire [(1)-1:0] input_bram_sxawid;
output wire [(8)-1:0] input_bram_sxawlen;
output wire [(3)-1:0] input_bram_sxawsize;
output wire [(2)-1:0] input_bram_sxawburst;
input wire input_bram_sxwready;
output wire input_bram_sxwvalid;
output wire [(1)-1:0] input_bram_sxwid;
output wire [(32)-1:0] input_bram_sxwdata;
output wire [(32/8)-1:0] input_bram_sxwstrb;
output wire input_bram_sxwlast;
output wire input_bram_sxbready;
input wire input_bram_sxbvalid;
input wire [(1)-1:0] input_bram_sxbid;
input wire [(2)-1:0] input_bram_sxbresp;
input wire input_bram_sxarready;
output wire input_bram_sxarvalid;
output wire [(32)-1:0] input_bram_sxaraddr;
output wire [(1)-1:0] input_bram_sxarid;
output wire [(8)-1:0] input_bram_sxarlen;
output wire [(3)-1:0] input_bram_sxarsize;
output wire [(2)-1:0] input_bram_sxarburst;
output wire input_bram_sxrready;
input wire input_bram_sxrvalid;
input wire [(1)-1:0] input_bram_sxrid;
input wire [(32)-1:0] input_bram_sxrdata;
input wire input_bram_sxrlast;
input wire [(2)-1:0] input_bram_sxrresp;
input wire wb_bram_sxawready;
output wire wb_bram_sxawvalid;
output wire [(32)-1:0] wb_bram_sxawaddr;
output wire [(1)-1:0] wb_bram_sxawid;
output wire [(8)-1:0] wb_bram_sxawlen;
output wire [(3)-1:0] wb_bram_sxawsize;
output wire [(2)-1:0] wb_bram_sxawburst;
input wire wb_bram_sxwready;
output wire wb_bram_sxwvalid;
output wire [(1)-1:0] wb_bram_sxwid;
output wire [(32)-1:0] wb_bram_sxwdata;
output wire [(32/8)-1:0] wb_bram_sxwstrb;
output wire wb_bram_sxwlast;
output wire wb_bram_sxbready;
input wire wb_bram_sxbvalid;
input wire [(1)-1:0] wb_bram_sxbid;
input wire [(2)-1:0] wb_bram_sxbresp;
input wire wb_bram_sxarready;
output wire wb_bram_sxarvalid;
output wire [(32)-1:0] wb_bram_sxaraddr;
output wire [(1)-1:0] wb_bram_sxarid;
output wire [(8)-1:0] wb_bram_sxarlen;
output wire [(3)-1:0] wb_bram_sxarsize;
output wire [(2)-1:0] wb_bram_sxarburst;
output wire wb_bram_sxrready;
input wire wb_bram_sxrvalid;
input wire [(1)-1:0] wb_bram_sxrid;
input wire [(32)-1:0] wb_bram_sxrdata;
input wire wb_bram_sxrlast;
input wire [(2)-1:0] wb_bram_sxrresp;
input wire output_bram_sxawready;
output wire output_bram_sxawvalid;
output wire [(32)-1:0] output_bram_sxawaddr;
output wire [(1)-1:0] output_bram_sxawid;
output wire [(8)-1:0] output_bram_sxawlen;
output wire [(3)-1:0] output_bram_sxawsize;
output wire [(2)-1:0] output_bram_sxawburst;
input wire output_bram_sxwready;
output wire output_bram_sxwvalid;
output wire [(1)-1:0] output_bram_sxwid;
output wire [(32)-1:0] output_bram_sxwdata;
output wire [(32/8)-1:0] output_bram_sxwstrb;
output wire output_bram_sxwlast;
output wire output_bram_sxbready;
input wire output_bram_sxbvalid;
input wire [(1)-1:0] output_bram_sxbid;
input wire [(2)-1:0] output_bram_sxbresp;
input wire output_bram_sxarready;
output wire output_bram_sxarvalid;
output wire [(32)-1:0] output_bram_sxaraddr;
output wire [(1)-1:0] output_bram_sxarid;
output wire [(8)-1:0] output_bram_sxarlen;
output wire [(3)-1:0] output_bram_sxarsize;
output wire [(2)-1:0] output_bram_sxarburst;
output wire output_bram_sxrready;
input wire output_bram_sxrvalid;
input wire [(1)-1:0] output_bram_sxrid;
input wire [(32)-1:0] output_bram_sxrdata;
input wire output_bram_sxrlast;
input wire [(2)-1:0] output_bram_sxrresp;
input wire i_system_ddr_sxawready;
output wire i_system_ddr_sxawvalid;
output wire [(32)-1:0] i_system_ddr_sxawaddr;
output wire [(16)-1:0] i_system_ddr_sxawid;
output wire [(8)-1:0] i_system_ddr_sxawlen;
output wire [(3)-1:0] i_system_ddr_sxawsize;
output wire [(2)-1:0] i_system_ddr_sxawburst;
input wire i_system_ddr_sxwready;
output wire i_system_ddr_sxwvalid;
output wire [(16)-1:0] i_system_ddr_sxwid;
output wire [(128)-1:0] i_system_ddr_sxwdata;
output wire [(128/8)-1:0] i_system_ddr_sxwstrb;
output wire i_system_ddr_sxwlast;
output wire i_system_ddr_sxbready;
input wire i_system_ddr_sxbvalid;
input wire [(16)-1:0] i_system_ddr_sxbid;
input wire [(2)-1:0] i_system_ddr_sxbresp;
input wire i_system_ddr_sxarready;
output wire i_system_ddr_sxarvalid;
output wire [(32)-1:0] i_system_ddr_sxaraddr;
output wire [(16)-1:0] i_system_ddr_sxarid;
output wire [(8)-1:0] i_system_ddr_sxarlen;
output wire [(3)-1:0] i_system_ddr_sxarsize;
output wire [(2)-1:0] i_system_ddr_sxarburst;
output wire i_system_ddr_sxrready;
input wire i_system_ddr_sxrvalid;
input wire [(16)-1:0] i_system_ddr_sxrid;
input wire [(128)-1:0] i_system_ddr_sxrdata;
input wire i_system_ddr_sxrlast;
input wire [(2)-1:0] i_system_ddr_sxrresp;
input wire i_system_sram_sxawready;
output wire i_system_sram_sxawvalid;
output wire [(32)-1:0] i_system_sram_sxawaddr;
output wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_sxawid;
output wire [(8)-1:0] i_system_sram_sxawlen;
output wire [(3)-1:0] i_system_sram_sxawsize;
output wire [(2)-1:0] i_system_sram_sxawburst;
input wire i_system_sram_sxwready;
output wire i_system_sram_sxwvalid;
output wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_sxwid;
output wire [(128)-1:0] i_system_sram_sxwdata;
output wire [(128/8)-1:0] i_system_sram_sxwstrb;
output wire i_system_sram_sxwlast;
output wire i_system_sram_sxbready;
input wire i_system_sram_sxbvalid;
input wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_sxbid;
input wire [(2)-1:0] i_system_sram_sxbresp;
input wire i_system_sram_sxarready;
output wire i_system_sram_sxarvalid;
output wire [(32)-1:0] i_system_sram_sxaraddr;
output wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_sxarid;
output wire [(8)-1:0] i_system_sram_sxarlen;
output wire [(3)-1:0] i_system_sram_sxarsize;
output wire [(2)-1:0] i_system_sram_sxarburst;
output wire i_system_sram_sxrready;
input wire i_system_sram_sxrvalid;
input wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_system_sram_sxrid;
input wire [(128)-1:0] i_system_sram_sxrdata;
input wire i_system_sram_sxrlast;
input wire [(2)-1:0] i_system_sram_sxrresp;

`include "video_module_port_def.vh"


wire rstnn_noc;
wire i_main_core_clk;
wire i_main_core_rstnn;
wire [(32)-1:0] i_main_core_interrupt_vector;
wire i_main_core_interrupt_out;
wire i_main_core_inst_sxawready;
wire i_main_core_inst_sxawvalid;
wire [(32)-1:0] i_main_core_inst_sxawaddr;
wire [(4)-1:0] i_main_core_inst_sxawid;
wire [(8)-1:0] i_main_core_inst_sxawlen;
wire [(3)-1:0] i_main_core_inst_sxawsize;
wire [(2)-1:0] i_main_core_inst_sxawburst;
wire i_main_core_inst_sxwready;
wire i_main_core_inst_sxwvalid;
wire [(4)-1:0] i_main_core_inst_sxwid;
wire [(32)-1:0] i_main_core_inst_sxwdata;
wire [(32/8)-1:0] i_main_core_inst_sxwstrb;
wire i_main_core_inst_sxwlast;
wire i_main_core_inst_sxbready;
wire i_main_core_inst_sxbvalid;
wire [(4)-1:0] i_main_core_inst_sxbid;
wire [(2)-1:0] i_main_core_inst_sxbresp;
wire i_main_core_inst_sxarready;
wire i_main_core_inst_sxarvalid;
wire [(32)-1:0] i_main_core_inst_sxaraddr;
wire [(4)-1:0] i_main_core_inst_sxarid;
wire [(8)-1:0] i_main_core_inst_sxarlen;
wire [(3)-1:0] i_main_core_inst_sxarsize;
wire [(2)-1:0] i_main_core_inst_sxarburst;
wire i_main_core_inst_sxrready;
wire i_main_core_inst_sxrvalid;
wire [(4)-1:0] i_main_core_inst_sxrid;
wire [(32)-1:0] i_main_core_inst_sxrdata;
wire i_main_core_inst_sxrlast;
wire [(2)-1:0] i_main_core_inst_sxrresp;
wire i_main_core_data_sxawready;
wire i_main_core_data_sxawvalid;
wire [(32)-1:0] i_main_core_data_sxawaddr;
wire [(4)-1:0] i_main_core_data_sxawid;
wire [(8)-1:0] i_main_core_data_sxawlen;
wire [(3)-1:0] i_main_core_data_sxawsize;
wire [(2)-1:0] i_main_core_data_sxawburst;
wire i_main_core_data_sxwready;
wire i_main_core_data_sxwvalid;
wire [(4)-1:0] i_main_core_data_sxwid;
wire [(32)-1:0] i_main_core_data_sxwdata;
wire [(32/8)-1:0] i_main_core_data_sxwstrb;
wire i_main_core_data_sxwlast;
wire i_main_core_data_sxbready;
wire i_main_core_data_sxbvalid;
wire [(4)-1:0] i_main_core_data_sxbid;
wire [(2)-1:0] i_main_core_data_sxbresp;
wire i_main_core_data_sxarready;
wire i_main_core_data_sxarvalid;
wire [(32)-1:0] i_main_core_data_sxaraddr;
wire [(4)-1:0] i_main_core_data_sxarid;
wire [(8)-1:0] i_main_core_data_sxarlen;
wire [(3)-1:0] i_main_core_data_sxarsize;
wire [(2)-1:0] i_main_core_data_sxarburst;
wire i_main_core_data_sxrready;
wire i_main_core_data_sxrvalid;
wire [(4)-1:0] i_main_core_data_sxrid;
wire [(32)-1:0] i_main_core_data_sxrdata;
wire i_main_core_data_sxrlast;
wire [(2)-1:0] i_main_core_data_sxrresp;
wire [(32)-1:0] i_main_core_spc;
wire [(32)-1:0] i_main_core_sinst;
wire i_led_clk;
wire i_led_tick_62d5ms;
wire i_led_rstnn;
wire i_led_app_finished;
wire [((1)*(1))-1:0] i_led_led_list;
wire i_florian_000_clk;
wire i_florian_000_rstnn;
wire i_florian_000_rpsel;
wire i_florian_000_rpenable;
wire i_florian_000_rpwrite;
wire [(32)-1:0] i_florian_000_rpaddr;
wire [(32)-1:0] i_florian_000_rpwdata;
wire i_florian_000_rpready;
wire [(32)-1:0] i_florian_000_rprdata;
wire i_florian_000_rpslverr;
wire i_edge_video_system_global_rstnn;
wire i_edge_video_system_rstnn_noc;
wire i_edge_video_system_rstnn_video;
wire i_edge_video_system_tick_1us;
wire i_edge_video_system_clk_apb;
wire i_edge_video_system_clk_vdma;
wire i_edge_video_system_clk_vimif;
wire i_edge_video_system_clk_vomif;
wire i_edge_video_system_clk_25M;
wire i_edge_video_system_clk_50M;
wire i_edge_video_system_clk_150M;
wire i_edge_video_system_clk_200M;
wire i_edge_video_system_clk_300M;
wire i_edge_video_system_vdma_sxawready;
wire i_edge_video_system_vdma_sxawvalid;
wire [(32)-1:0] i_edge_video_system_vdma_sxawaddr;
wire [(4)-1:0] i_edge_video_system_vdma_sxawid;
wire [(8)-1:0] i_edge_video_system_vdma_sxawlen;
wire [(3)-1:0] i_edge_video_system_vdma_sxawsize;
wire [(2)-1:0] i_edge_video_system_vdma_sxawburst;
wire i_edge_video_system_vdma_sxwready;
wire i_edge_video_system_vdma_sxwvalid;
wire [(4)-1:0] i_edge_video_system_vdma_sxwid;
wire [(128)-1:0] i_edge_video_system_vdma_sxwdata;
wire [(128/8)-1:0] i_edge_video_system_vdma_sxwstrb;
wire i_edge_video_system_vdma_sxwlast;
wire i_edge_video_system_vdma_sxbready;
wire i_edge_video_system_vdma_sxbvalid;
wire [(4)-1:0] i_edge_video_system_vdma_sxbid;
wire [(2)-1:0] i_edge_video_system_vdma_sxbresp;
wire i_edge_video_system_vdma_sxarready;
wire i_edge_video_system_vdma_sxarvalid;
wire [(32)-1:0] i_edge_video_system_vdma_sxaraddr;
wire [(4)-1:0] i_edge_video_system_vdma_sxarid;
wire [(8)-1:0] i_edge_video_system_vdma_sxarlen;
wire [(3)-1:0] i_edge_video_system_vdma_sxarsize;
wire [(2)-1:0] i_edge_video_system_vdma_sxarburst;
wire i_edge_video_system_vdma_sxrready;
wire i_edge_video_system_vdma_sxrvalid;
wire [(4)-1:0] i_edge_video_system_vdma_sxrid;
wire [(128)-1:0] i_edge_video_system_vdma_sxrdata;
wire i_edge_video_system_vdma_sxrlast;
wire [(2)-1:0] i_edge_video_system_vdma_sxrresp;
wire i_edge_video_system_vdma_ctrl_rpsel;
wire i_edge_video_system_vdma_ctrl_rpenable;
wire i_edge_video_system_vdma_ctrl_rpwrite;
wire [(32)-1:0] i_edge_video_system_vdma_ctrl_rpaddr;
wire [(32)-1:0] i_edge_video_system_vdma_ctrl_rpwdata;
wire i_edge_video_system_vdma_ctrl_rpready;
wire [(32)-1:0] i_edge_video_system_vdma_ctrl_rprdata;
wire i_edge_video_system_vdma_ctrl_rpslverr;
wire i_edge_video_system_vim_sxawready;
wire i_edge_video_system_vim_sxawvalid;
wire [(32)-1:0] i_edge_video_system_vim_sxawaddr;
wire [(4)-1:0] i_edge_video_system_vim_sxawid;
wire [(8)-1:0] i_edge_video_system_vim_sxawlen;
wire [(3)-1:0] i_edge_video_system_vim_sxawsize;
wire [(2)-1:0] i_edge_video_system_vim_sxawburst;
wire i_edge_video_system_vim_sxwready;
wire i_edge_video_system_vim_sxwvalid;
wire [(4)-1:0] i_edge_video_system_vim_sxwid;
wire [(128)-1:0] i_edge_video_system_vim_sxwdata;
wire [(128/8)-1:0] i_edge_video_system_vim_sxwstrb;
wire i_edge_video_system_vim_sxwlast;
wire i_edge_video_system_vim_sxbready;
wire i_edge_video_system_vim_sxbvalid;
wire [(4)-1:0] i_edge_video_system_vim_sxbid;
wire [(2)-1:0] i_edge_video_system_vim_sxbresp;
wire i_edge_video_system_vim_sxarready;
wire i_edge_video_system_vim_sxarvalid;
wire [(32)-1:0] i_edge_video_system_vim_sxaraddr;
wire [(4)-1:0] i_edge_video_system_vim_sxarid;
wire [(8)-1:0] i_edge_video_system_vim_sxarlen;
wire [(3)-1:0] i_edge_video_system_vim_sxarsize;
wire [(2)-1:0] i_edge_video_system_vim_sxarburst;
wire i_edge_video_system_vim_sxrready;
wire i_edge_video_system_vim_sxrvalid;
wire [(4)-1:0] i_edge_video_system_vim_sxrid;
wire [(128)-1:0] i_edge_video_system_vim_sxrdata;
wire i_edge_video_system_vim_sxrlast;
wire [(2)-1:0] i_edge_video_system_vim_sxrresp;
wire i_edge_video_system_vom_sxawready;
wire i_edge_video_system_vom_sxawvalid;
wire [(32)-1:0] i_edge_video_system_vom_sxawaddr;
wire [(4)-1:0] i_edge_video_system_vom_sxawid;
wire [(8)-1:0] i_edge_video_system_vom_sxawlen;
wire [(3)-1:0] i_edge_video_system_vom_sxawsize;
wire [(2)-1:0] i_edge_video_system_vom_sxawburst;
wire i_edge_video_system_vom_sxwready;
wire i_edge_video_system_vom_sxwvalid;
wire [(4)-1:0] i_edge_video_system_vom_sxwid;
wire [(128)-1:0] i_edge_video_system_vom_sxwdata;
wire [(128/8)-1:0] i_edge_video_system_vom_sxwstrb;
wire i_edge_video_system_vom_sxwlast;
wire i_edge_video_system_vom_sxbready;
wire i_edge_video_system_vom_sxbvalid;
wire [(4)-1:0] i_edge_video_system_vom_sxbid;
wire [(2)-1:0] i_edge_video_system_vom_sxbresp;
wire i_edge_video_system_vom_sxarready;
wire i_edge_video_system_vom_sxarvalid;
wire [(32)-1:0] i_edge_video_system_vom_sxaraddr;
wire [(4)-1:0] i_edge_video_system_vom_sxarid;
wire [(8)-1:0] i_edge_video_system_vom_sxarlen;
wire [(3)-1:0] i_edge_video_system_vom_sxarsize;
wire [(2)-1:0] i_edge_video_system_vom_sxarburst;
wire i_edge_video_system_vom_sxrready;
wire i_edge_video_system_vom_sxrvalid;
wire [(4)-1:0] i_edge_video_system_vom_sxrid;
wire [(128)-1:0] i_edge_video_system_vom_sxrdata;
wire i_edge_video_system_vom_sxrlast;
wire [(2)-1:0] i_edge_video_system_vom_sxrresp;
wire i_edge_video_system_video_ctrl_rpsel;
wire i_edge_video_system_video_ctrl_rpenable;
wire i_edge_video_system_video_ctrl_rpwrite;
wire [(32)-1:0] i_edge_video_system_video_ctrl_rpaddr;
wire [(32)-1:0] i_edge_video_system_video_ctrl_rpwdata;
wire i_edge_video_system_video_ctrl_rpready;
wire [(32)-1:0] i_edge_video_system_video_ctrl_rprdata;
wire i_edge_video_system_video_ctrl_rpslverr;
wire [(1)-1:0] i_edge_video_system_cis_rclk_od;
wire [(1)-1:0] i_edge_video_system_cis_rclk_oval;
wire [(1)-1:0] i_edge_video_system_cis_rclk_ival;
wire [(1)-1:0] i_edge_video_system_cis_rdata_od;
wire [(1)-1:0] i_edge_video_system_cis_rdata_oval;
wire [(1)-1:0] i_edge_video_system_cis_rdata_ival;
wire [(1)-1:0] i_edge_video_system_hdmi_rclk_od;
wire [(1)-1:0] i_edge_video_system_hdmi_rclk_oval;
wire [(1)-1:0] i_edge_video_system_hdmi_rclk_ival;
wire [(1)-1:0] i_edge_video_system_hdmi_rdata_od;
wire [(1)-1:0] i_edge_video_system_hdmi_rdata_oval;
wire [(1)-1:0] i_edge_video_system_hdmi_rdata_ival;
wire common_peri_group_clk;
wire common_peri_group_rstnn;
wire [(1)-1:0] common_peri_group_lock_status_list;
wire [(32)-1:0] common_peri_group_thread_status_list;
wire [(64)-1:0] common_peri_group_real_clock;
wire [(1)-1:0] common_peri_group_global_tag_list;
wire [(11)-1:0] common_peri_group_system_tick_config;
wire [(11)-1:0] common_peri_group_core_tick_config;
wire common_peri_group_rpsel;
wire common_peri_group_rpenable;
wire common_peri_group_rpwrite;
wire [(32)-1:0] common_peri_group_rpaddr;
wire [(32)-1:0] common_peri_group_rpwdata;
wire common_peri_group_rpready;
wire [(32)-1:0] common_peri_group_rprdata;
wire common_peri_group_rpslverr;
wire autoname_104_clk;
wire autoname_104_rstnn;
wire [(11)-1:0] autoname_104_tick_config;
wire autoname_104_tick_1us;
wire autoname_104_tick_62d5ms;
wire autoname_105_clk;
wire autoname_105_rstnn;
wire [(11)-1:0] autoname_105_tick_config;
wire autoname_105_tick_1us;
wire autoname_105_tick_62d5ms;
wire autoname_106_clk;
wire autoname_106_rstnn;
wire autoname_106_tick_1us;
wire [(64)-1:0] autoname_106_real_clock;
wire external_peri_group_clk;
wire external_peri_group_rstnn;
wire external_peri_group_tick_1us;
wire external_peri_group_tick_gpio;
wire [(32)-1:0] external_peri_group_uart_interrupts;
wire external_peri_group_spi_interrupt;
wire [(32)-1:0] external_peri_group_i2c_interrupts;
wire [(32)-1:0] external_peri_group_gpio_interrupts;
wire external_peri_group_wifi_interrupt;
wire external_peri_group_spi_common_sclk;
wire external_peri_group_spi_common_sdq0;
wire external_peri_group_rpsel;
wire external_peri_group_rpenable;
wire external_peri_group_rpwrite;
wire [(32)-1:0] external_peri_group_rpaddr;
wire [(32)-1:0] external_peri_group_rpwdata;
wire external_peri_group_rpready;
wire [(32)-1:0] external_peri_group_rprdata;
wire external_peri_group_rpslverr;
wire [((1)*(1))-1:0] external_peri_group_uart_stx_list;
wire [((1)*(1))-1:0] external_peri_group_uart_srx_list;
wire [((1)*(2))-1:0] external_peri_group_i2c_sclk_od_list;
wire [((1)*(2))-1:0] external_peri_group_i2c_sclk_oval_list;
wire [((1)*(2))-1:0] external_peri_group_i2c_sclk_ival_list;
wire [((1)*(2))-1:0] external_peri_group_i2c_sdata_od_list;
wire [((1)*(2))-1:0] external_peri_group_i2c_sdata_oval_list;
wire [((1)*(2))-1:0] external_peri_group_i2c_sdata_ival_list;
wire [(1)-1:0] external_peri_group_oled_sdcsel_oe;
wire [(1)-1:0] external_peri_group_oled_sdcsel_oval;
wire [(1)-1:0] external_peri_group_oled_sdcsel_ival;
wire [(1)-1:0] external_peri_group_oled_srstnn_oe;
wire [(1)-1:0] external_peri_group_oled_srstnn_oval;
wire [(1)-1:0] external_peri_group_oled_srstnn_ival;
wire [(1)-1:0] external_peri_group_oled_svbat_oe;
wire [(1)-1:0] external_peri_group_oled_svbat_oval;
wire [(1)-1:0] external_peri_group_oled_svbat_ival;
wire [(1)-1:0] external_peri_group_oled_svdd_oe;
wire [(1)-1:0] external_peri_group_oled_svdd_oval;
wire [(1)-1:0] external_peri_group_oled_svdd_ival;
wire external_peri_group_wifi_sitr;
wire external_peri_group_wifi_srstnn;
wire external_peri_group_wifi_swp;
wire external_peri_group_wifi_shibernate;
wire core_peri_group_clk;
wire core_peri_group_rstnn;
wire core_peri_group_tick_1us;
wire core_peri_group_delay_notice;
wire core_peri_group_plic_interrupt;
wire [(1)-1:0] core_peri_group_lock_status_list;
wire [(1)-1:0] core_peri_group_global_tag_list;
wire [(32)-1:0] core_peri_group_thread_status_list;
wire [(32)-1:0] core_peri_group_core_interrupt_vector;
wire core_peri_group_allows_holds;
wire core_peri_group_rpsel;
wire core_peri_group_rpenable;
wire core_peri_group_rpwrite;
wire [(32)-1:0] core_peri_group_rpaddr;
wire [(32)-1:0] core_peri_group_rpwdata;
wire core_peri_group_rpready;
wire [(32)-1:0] core_peri_group_rprdata;
wire core_peri_group_rpslverr;
wire core_peri_group_tcu_spsel;
wire core_peri_group_tcu_spenable;
wire core_peri_group_tcu_spwrite;
wire [(32)-1:0] core_peri_group_tcu_spaddr;
wire [(32)-1:0] core_peri_group_tcu_spwdata;
wire core_peri_group_tcu_spready;
wire [(32)-1:0] core_peri_group_tcu_sprdata;
wire core_peri_group_tcu_spslverr;
wire core_peri_group_florian_spsel;
wire core_peri_group_florian_spenable;
wire core_peri_group_florian_spwrite;
wire [(32)-1:0] core_peri_group_florian_spaddr;
wire [(32)-1:0] core_peri_group_florian_spwdata;
wire core_peri_group_florian_spready;
wire [(32)-1:0] core_peri_group_florian_sprdata;
wire core_peri_group_florian_spslverr;
wire platform_controller_clk;
wire platform_controller_external_rstnn;
wire platform_controller_global_rstnn;
wire platform_controller_global_rstpp;
wire [(7)-1:0] platform_controller_rstnn_seqeunce;
wire [(7)-1:0] platform_controller_rstpp_seqeunce;
wire [(`BW_BOOT_MODE)-1:0] platform_controller_boot_mode;
wire platform_controller_jtag_select;
wire platform_controller_initialized;
wire platform_controller_app_finished;
wire platform_controller_rstnn;
wire platform_controller_shready;
wire [(32)-1:0] platform_controller_shaddr;
wire [(3)-1:0] platform_controller_shburst;
wire platform_controller_shmasterlock;
wire [(4)-1:0] platform_controller_shprot;
wire [(3)-1:0] platform_controller_shsize;
wire [(2)-1:0] platform_controller_shtrans;
wire platform_controller_shwrite;
wire [(32)-1:0] platform_controller_shwdata;
wire [(32)-1:0] platform_controller_shrdata;
wire platform_controller_shresp;
wire platform_controller_rpsel;
wire platform_controller_rpenable;
wire platform_controller_rpwrite;
wire [(32)-1:0] platform_controller_rpaddr;
wire [(32)-1:0] platform_controller_rpwdata;
wire platform_controller_rpready;
wire [(32)-1:0] platform_controller_rprdata;
wire platform_controller_rpslverr;
wire platform_controller_pjtag_rtck;
wire platform_controller_pjtag_rtrstnn;
wire platform_controller_pjtag_rtms;
wire platform_controller_pjtag_rtdi;
wire platform_controller_pjtag_rtdo;
wire platform_controller_noc_debug_spsel;
wire platform_controller_noc_debug_spenable;
wire platform_controller_noc_debug_spwrite;
wire [(32)-1:0] platform_controller_noc_debug_spaddr;
wire [(32)-1:0] platform_controller_noc_debug_spwdata;
wire platform_controller_noc_debug_spready;
wire [(32)-1:0] platform_controller_noc_debug_sprdata;
wire platform_controller_noc_debug_spslverr;
wire [((32)*(1))-1:0] platform_controller_rpc_list;
wire [((32)*(1))-1:0] platform_controller_rinst_list;
wire default_slave_clk_network;
wire default_slave_rstnn_network;
wire default_slave_clk_debug;
wire default_slave_rstnn_debug;
wire default_slave_comm_disable;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] default_slave_rfni_link;
wire default_slave_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] default_slave_rbni_link;
wire default_slave_rbni_ready;
wire default_slave_debug_rpsel;
wire default_slave_debug_rpenable;
wire default_slave_debug_rpwrite;
wire [(32)-1:0] default_slave_debug_rpaddr;
wire [(32)-1:0] default_slave_debug_rpwdata;
wire default_slave_debug_rpready;
wire [(32)-1:0] default_slave_debug_rprdata;
wire default_slave_debug_rpslverr;
wire [(`BW_SVRING_LINK)-1:0] default_slave_svri_rlink;
wire default_slave_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] default_slave_svri_slink;
wire default_slave_svri_sack;
wire i_inter_router_fifo00_clk;
wire i_inter_router_fifo00_rstnn;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_inter_router_fifo00_rfni_link;
wire i_inter_router_fifo00_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_inter_router_fifo00_rbni_link;
wire i_inter_router_fifo00_rbni_ready;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_inter_router_fifo00_sfni_link;
wire i_inter_router_fifo00_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_inter_router_fifo00_sbni_link;
wire i_inter_router_fifo00_sbni_ready;
wire i_snim_i_edge_video_system_vdma_ctrl_clk_network;
wire i_snim_i_edge_video_system_vdma_ctrl_rstnn_network;
wire i_snim_i_edge_video_system_vdma_ctrl_clk_slave;
wire i_snim_i_edge_video_system_vdma_ctrl_rstnn_slave;
wire i_snim_i_edge_video_system_vdma_ctrl_comm_disable;
wire i_snim_i_edge_video_system_vdma_ctrl_spsel;
wire i_snim_i_edge_video_system_vdma_ctrl_spenable;
wire i_snim_i_edge_video_system_vdma_ctrl_spwrite;
wire [(32)-1:0] i_snim_i_edge_video_system_vdma_ctrl_spaddr;
wire [(32)-1:0] i_snim_i_edge_video_system_vdma_ctrl_spwdata;
wire i_snim_i_edge_video_system_vdma_ctrl_spready;
wire [(32)-1:0] i_snim_i_edge_video_system_vdma_ctrl_sprdata;
wire i_snim_i_edge_video_system_vdma_ctrl_spslverr;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_i_edge_video_system_vdma_ctrl_rfni_link;
wire i_snim_i_edge_video_system_vdma_ctrl_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_i_edge_video_system_vdma_ctrl_rbni_link;
wire i_snim_i_edge_video_system_vdma_ctrl_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_edge_video_system_vdma_ctrl_svri_rlink;
wire i_snim_i_edge_video_system_vdma_ctrl_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_edge_video_system_vdma_ctrl_svri_slink;
wire i_snim_i_edge_video_system_vdma_ctrl_svri_sack;
wire i_snim_i_edge_video_system_video_ctrl_clk_network;
wire i_snim_i_edge_video_system_video_ctrl_rstnn_network;
wire i_snim_i_edge_video_system_video_ctrl_clk_slave;
wire i_snim_i_edge_video_system_video_ctrl_rstnn_slave;
wire i_snim_i_edge_video_system_video_ctrl_comm_disable;
wire i_snim_i_edge_video_system_video_ctrl_spsel;
wire i_snim_i_edge_video_system_video_ctrl_spenable;
wire i_snim_i_edge_video_system_video_ctrl_spwrite;
wire [(32)-1:0] i_snim_i_edge_video_system_video_ctrl_spaddr;
wire [(32)-1:0] i_snim_i_edge_video_system_video_ctrl_spwdata;
wire i_snim_i_edge_video_system_video_ctrl_spready;
wire [(32)-1:0] i_snim_i_edge_video_system_video_ctrl_sprdata;
wire i_snim_i_edge_video_system_video_ctrl_spslverr;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_i_edge_video_system_video_ctrl_rfni_link;
wire i_snim_i_edge_video_system_video_ctrl_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_i_edge_video_system_video_ctrl_rbni_link;
wire i_snim_i_edge_video_system_video_ctrl_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_edge_video_system_video_ctrl_svri_rlink;
wire i_snim_i_edge_video_system_video_ctrl_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_edge_video_system_video_ctrl_svri_slink;
wire i_snim_i_edge_video_system_video_ctrl_svri_sack;
wire i_snim_i_system_sram_no_name_clk;
wire i_snim_i_system_sram_no_name_rstnn;
wire i_snim_i_system_sram_no_name_comm_disable;
wire i_snim_i_system_sram_no_name_sxawready;
wire i_snim_i_system_sram_no_name_sxawvalid;
wire [(32)-1:0] i_snim_i_system_sram_no_name_sxawaddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_snim_i_system_sram_no_name_sxawid;
wire [(8)-1:0] i_snim_i_system_sram_no_name_sxawlen;
wire [(3)-1:0] i_snim_i_system_sram_no_name_sxawsize;
wire [(2)-1:0] i_snim_i_system_sram_no_name_sxawburst;
wire i_snim_i_system_sram_no_name_sxwready;
wire i_snim_i_system_sram_no_name_sxwvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_snim_i_system_sram_no_name_sxwid;
wire [(128)-1:0] i_snim_i_system_sram_no_name_sxwdata;
wire [(128/8)-1:0] i_snim_i_system_sram_no_name_sxwstrb;
wire i_snim_i_system_sram_no_name_sxwlast;
wire i_snim_i_system_sram_no_name_sxbready;
wire i_snim_i_system_sram_no_name_sxbvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_snim_i_system_sram_no_name_sxbid;
wire [(2)-1:0] i_snim_i_system_sram_no_name_sxbresp;
wire i_snim_i_system_sram_no_name_sxarready;
wire i_snim_i_system_sram_no_name_sxarvalid;
wire [(32)-1:0] i_snim_i_system_sram_no_name_sxaraddr;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_snim_i_system_sram_no_name_sxarid;
wire [(8)-1:0] i_snim_i_system_sram_no_name_sxarlen;
wire [(3)-1:0] i_snim_i_system_sram_no_name_sxarsize;
wire [(2)-1:0] i_snim_i_system_sram_no_name_sxarburst;
wire i_snim_i_system_sram_no_name_sxrready;
wire i_snim_i_system_sram_no_name_sxrvalid;
wire [(`REQUIRED_BW_OF_SLAVE_TID)-1:0] i_snim_i_system_sram_no_name_sxrid;
wire [(128)-1:0] i_snim_i_system_sram_no_name_sxrdata;
wire i_snim_i_system_sram_no_name_sxrlast;
wire [(2)-1:0] i_snim_i_system_sram_no_name_sxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_i_system_sram_no_name_rfni_link;
wire i_snim_i_system_sram_no_name_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_i_system_sram_no_name_rbni_link;
wire i_snim_i_system_sram_no_name_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_system_sram_no_name_svri_rlink;
wire i_snim_i_system_sram_no_name_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_system_sram_no_name_svri_slink;
wire i_snim_i_system_sram_no_name_svri_sack;
wire i_snim_common_peri_group_no_name_clk_network;
wire i_snim_common_peri_group_no_name_rstnn_network;
wire i_snim_common_peri_group_no_name_clk_slave;
wire i_snim_common_peri_group_no_name_rstnn_slave;
wire i_snim_common_peri_group_no_name_comm_disable;
wire i_snim_common_peri_group_no_name_spsel;
wire i_snim_common_peri_group_no_name_spenable;
wire i_snim_common_peri_group_no_name_spwrite;
wire [(32)-1:0] i_snim_common_peri_group_no_name_spaddr;
wire [(32)-1:0] i_snim_common_peri_group_no_name_spwdata;
wire i_snim_common_peri_group_no_name_spready;
wire [(32)-1:0] i_snim_common_peri_group_no_name_sprdata;
wire i_snim_common_peri_group_no_name_spslverr;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_common_peri_group_no_name_rfni_link;
wire i_snim_common_peri_group_no_name_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_common_peri_group_no_name_rbni_link;
wire i_snim_common_peri_group_no_name_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_common_peri_group_no_name_svri_rlink;
wire i_snim_common_peri_group_no_name_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_common_peri_group_no_name_svri_slink;
wire i_snim_common_peri_group_no_name_svri_sack;
wire i_snim_external_peri_group_no_name_clk_network;
wire i_snim_external_peri_group_no_name_rstnn_network;
wire i_snim_external_peri_group_no_name_clk_slave;
wire i_snim_external_peri_group_no_name_rstnn_slave;
wire i_snim_external_peri_group_no_name_comm_disable;
wire i_snim_external_peri_group_no_name_spsel;
wire i_snim_external_peri_group_no_name_spenable;
wire i_snim_external_peri_group_no_name_spwrite;
wire [(32)-1:0] i_snim_external_peri_group_no_name_spaddr;
wire [(32)-1:0] i_snim_external_peri_group_no_name_spwdata;
wire i_snim_external_peri_group_no_name_spready;
wire [(32)-1:0] i_snim_external_peri_group_no_name_sprdata;
wire i_snim_external_peri_group_no_name_spslverr;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_external_peri_group_no_name_rfni_link;
wire i_snim_external_peri_group_no_name_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_external_peri_group_no_name_rbni_link;
wire i_snim_external_peri_group_no_name_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_external_peri_group_no_name_svri_rlink;
wire i_snim_external_peri_group_no_name_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_external_peri_group_no_name_svri_slink;
wire i_snim_external_peri_group_no_name_svri_sack;
wire i_snim_platform_controller_no_name_clk_network;
wire i_snim_platform_controller_no_name_rstnn_network;
wire i_snim_platform_controller_no_name_clk_slave;
wire i_snim_platform_controller_no_name_rstnn_slave;
wire i_snim_platform_controller_no_name_comm_disable;
wire i_snim_platform_controller_no_name_spsel;
wire i_snim_platform_controller_no_name_spenable;
wire i_snim_platform_controller_no_name_spwrite;
wire [(32)-1:0] i_snim_platform_controller_no_name_spaddr;
wire [(32)-1:0] i_snim_platform_controller_no_name_spwdata;
wire i_snim_platform_controller_no_name_spready;
wire [(32)-1:0] i_snim_platform_controller_no_name_sprdata;
wire i_snim_platform_controller_no_name_spslverr;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_platform_controller_no_name_rfni_link;
wire i_snim_platform_controller_no_name_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_platform_controller_no_name_rbni_link;
wire i_snim_platform_controller_no_name_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_platform_controller_no_name_svri_rlink;
wire i_snim_platform_controller_no_name_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_platform_controller_no_name_svri_slink;
wire i_snim_platform_controller_no_name_svri_sack;
wire i_mnim_i_main_core_inst_clk_network;
wire i_mnim_i_main_core_inst_rstnn_network;
wire i_mnim_i_main_core_inst_clk_master;
wire i_mnim_i_main_core_inst_rstnn_master;
wire i_mnim_i_main_core_inst_comm_disable;
wire i_mnim_i_main_core_inst_local_allows_holds;
wire i_mnim_i_main_core_inst_rxawready;
wire i_mnim_i_main_core_inst_rxawvalid;
wire [(32)-1:0] i_mnim_i_main_core_inst_rxawaddr;
wire [(4)-1:0] i_mnim_i_main_core_inst_rxawid;
wire [(8)-1:0] i_mnim_i_main_core_inst_rxawlen;
wire [(3)-1:0] i_mnim_i_main_core_inst_rxawsize;
wire [(2)-1:0] i_mnim_i_main_core_inst_rxawburst;
wire i_mnim_i_main_core_inst_rxwready;
wire i_mnim_i_main_core_inst_rxwvalid;
wire [(4)-1:0] i_mnim_i_main_core_inst_rxwid;
wire [(32)-1:0] i_mnim_i_main_core_inst_rxwdata;
wire [(32/8)-1:0] i_mnim_i_main_core_inst_rxwstrb;
wire i_mnim_i_main_core_inst_rxwlast;
wire i_mnim_i_main_core_inst_rxbready;
wire i_mnim_i_main_core_inst_rxbvalid;
wire [(4)-1:0] i_mnim_i_main_core_inst_rxbid;
wire [(2)-1:0] i_mnim_i_main_core_inst_rxbresp;
wire i_mnim_i_main_core_inst_rxarready;
wire i_mnim_i_main_core_inst_rxarvalid;
wire [(32)-1:0] i_mnim_i_main_core_inst_rxaraddr;
wire [(4)-1:0] i_mnim_i_main_core_inst_rxarid;
wire [(8)-1:0] i_mnim_i_main_core_inst_rxarlen;
wire [(3)-1:0] i_mnim_i_main_core_inst_rxarsize;
wire [(2)-1:0] i_mnim_i_main_core_inst_rxarburst;
wire i_mnim_i_main_core_inst_rxrready;
wire i_mnim_i_main_core_inst_rxrvalid;
wire [(4)-1:0] i_mnim_i_main_core_inst_rxrid;
wire [(32)-1:0] i_mnim_i_main_core_inst_rxrdata;
wire i_mnim_i_main_core_inst_rxrlast;
wire [(2)-1:0] i_mnim_i_main_core_inst_rxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_mnim_i_main_core_inst_sfni_link;
wire i_mnim_i_main_core_inst_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_mnim_i_main_core_inst_sbni_link;
wire i_mnim_i_main_core_inst_sbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_main_core_inst_svri_rlink;
wire i_mnim_i_main_core_inst_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_main_core_inst_svri_slink;
wire i_mnim_i_main_core_inst_svri_sack;
wire i_mnim_i_main_core_inst_local_spsel;
wire i_mnim_i_main_core_inst_local_spenable;
wire i_mnim_i_main_core_inst_local_spwrite;
wire [(32)-1:0] i_mnim_i_main_core_inst_local_spaddr;
wire [(32)-1:0] i_mnim_i_main_core_inst_local_spwdata;
wire i_mnim_i_main_core_inst_local_spready;
wire [(32)-1:0] i_mnim_i_main_core_inst_local_sprdata;
wire i_mnim_i_main_core_inst_local_spslverr;
wire i_mnim_i_main_core_data_clk_network;
wire i_mnim_i_main_core_data_rstnn_network;
wire i_mnim_i_main_core_data_clk_master;
wire i_mnim_i_main_core_data_rstnn_master;
wire i_mnim_i_main_core_data_comm_disable;
wire i_mnim_i_main_core_data_local_allows_holds;
wire i_mnim_i_main_core_data_rxawready;
wire i_mnim_i_main_core_data_rxawvalid;
wire [(32)-1:0] i_mnim_i_main_core_data_rxawaddr;
wire [(4)-1:0] i_mnim_i_main_core_data_rxawid;
wire [(8)-1:0] i_mnim_i_main_core_data_rxawlen;
wire [(3)-1:0] i_mnim_i_main_core_data_rxawsize;
wire [(2)-1:0] i_mnim_i_main_core_data_rxawburst;
wire i_mnim_i_main_core_data_rxwready;
wire i_mnim_i_main_core_data_rxwvalid;
wire [(4)-1:0] i_mnim_i_main_core_data_rxwid;
wire [(32)-1:0] i_mnim_i_main_core_data_rxwdata;
wire [(32/8)-1:0] i_mnim_i_main_core_data_rxwstrb;
wire i_mnim_i_main_core_data_rxwlast;
wire i_mnim_i_main_core_data_rxbready;
wire i_mnim_i_main_core_data_rxbvalid;
wire [(4)-1:0] i_mnim_i_main_core_data_rxbid;
wire [(2)-1:0] i_mnim_i_main_core_data_rxbresp;
wire i_mnim_i_main_core_data_rxarready;
wire i_mnim_i_main_core_data_rxarvalid;
wire [(32)-1:0] i_mnim_i_main_core_data_rxaraddr;
wire [(4)-1:0] i_mnim_i_main_core_data_rxarid;
wire [(8)-1:0] i_mnim_i_main_core_data_rxarlen;
wire [(3)-1:0] i_mnim_i_main_core_data_rxarsize;
wire [(2)-1:0] i_mnim_i_main_core_data_rxarburst;
wire i_mnim_i_main_core_data_rxrready;
wire i_mnim_i_main_core_data_rxrvalid;
wire [(4)-1:0] i_mnim_i_main_core_data_rxrid;
wire [(32)-1:0] i_mnim_i_main_core_data_rxrdata;
wire i_mnim_i_main_core_data_rxrlast;
wire [(2)-1:0] i_mnim_i_main_core_data_rxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_mnim_i_main_core_data_sfni_link;
wire i_mnim_i_main_core_data_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_mnim_i_main_core_data_sbni_link;
wire i_mnim_i_main_core_data_sbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_main_core_data_svri_rlink;
wire i_mnim_i_main_core_data_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_main_core_data_svri_slink;
wire i_mnim_i_main_core_data_svri_sack;
wire i_mnim_i_main_core_data_local_spsel;
wire i_mnim_i_main_core_data_local_spenable;
wire i_mnim_i_main_core_data_local_spwrite;
wire [(32)-1:0] i_mnim_i_main_core_data_local_spaddr;
wire [(32)-1:0] i_mnim_i_main_core_data_local_spwdata;
wire i_mnim_i_main_core_data_local_spready;
wire [(32)-1:0] i_mnim_i_main_core_data_local_sprdata;
wire i_mnim_i_main_core_data_local_spslverr;
wire i_mnim_i_edge_video_system_vdma_clk_network;
wire i_mnim_i_edge_video_system_vdma_rstnn_network;
wire i_mnim_i_edge_video_system_vdma_clk_master;
wire i_mnim_i_edge_video_system_vdma_rstnn_master;
wire i_mnim_i_edge_video_system_vdma_comm_disable;
wire i_mnim_i_edge_video_system_vdma_local_allows_holds;
wire i_mnim_i_edge_video_system_vdma_rxawready;
wire i_mnim_i_edge_video_system_vdma_rxawvalid;
wire [(32)-1:0] i_mnim_i_edge_video_system_vdma_rxawaddr;
wire [(4)-1:0] i_mnim_i_edge_video_system_vdma_rxawid;
wire [(8)-1:0] i_mnim_i_edge_video_system_vdma_rxawlen;
wire [(3)-1:0] i_mnim_i_edge_video_system_vdma_rxawsize;
wire [(2)-1:0] i_mnim_i_edge_video_system_vdma_rxawburst;
wire i_mnim_i_edge_video_system_vdma_rxwready;
wire i_mnim_i_edge_video_system_vdma_rxwvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vdma_rxwid;
wire [(128)-1:0] i_mnim_i_edge_video_system_vdma_rxwdata;
wire [(128/8)-1:0] i_mnim_i_edge_video_system_vdma_rxwstrb;
wire i_mnim_i_edge_video_system_vdma_rxwlast;
wire i_mnim_i_edge_video_system_vdma_rxbready;
wire i_mnim_i_edge_video_system_vdma_rxbvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vdma_rxbid;
wire [(2)-1:0] i_mnim_i_edge_video_system_vdma_rxbresp;
wire i_mnim_i_edge_video_system_vdma_rxarready;
wire i_mnim_i_edge_video_system_vdma_rxarvalid;
wire [(32)-1:0] i_mnim_i_edge_video_system_vdma_rxaraddr;
wire [(4)-1:0] i_mnim_i_edge_video_system_vdma_rxarid;
wire [(8)-1:0] i_mnim_i_edge_video_system_vdma_rxarlen;
wire [(3)-1:0] i_mnim_i_edge_video_system_vdma_rxarsize;
wire [(2)-1:0] i_mnim_i_edge_video_system_vdma_rxarburst;
wire i_mnim_i_edge_video_system_vdma_rxrready;
wire i_mnim_i_edge_video_system_vdma_rxrvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vdma_rxrid;
wire [(128)-1:0] i_mnim_i_edge_video_system_vdma_rxrdata;
wire i_mnim_i_edge_video_system_vdma_rxrlast;
wire [(2)-1:0] i_mnim_i_edge_video_system_vdma_rxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_mnim_i_edge_video_system_vdma_sfni_link;
wire i_mnim_i_edge_video_system_vdma_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_mnim_i_edge_video_system_vdma_sbni_link;
wire i_mnim_i_edge_video_system_vdma_sbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_edge_video_system_vdma_svri_rlink;
wire i_mnim_i_edge_video_system_vdma_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_edge_video_system_vdma_svri_slink;
wire i_mnim_i_edge_video_system_vdma_svri_sack;
wire i_mnim_i_edge_video_system_vdma_local_spsel;
wire i_mnim_i_edge_video_system_vdma_local_spenable;
wire i_mnim_i_edge_video_system_vdma_local_spwrite;
wire [(32)-1:0] i_mnim_i_edge_video_system_vdma_local_spaddr;
wire [(128)-1:0] i_mnim_i_edge_video_system_vdma_local_spwdata;
wire i_mnim_i_edge_video_system_vdma_local_spready;
wire [(128)-1:0] i_mnim_i_edge_video_system_vdma_local_sprdata;
wire i_mnim_i_edge_video_system_vdma_local_spslverr;
wire i_mnim_i_edge_video_system_vim_clk;
wire i_mnim_i_edge_video_system_vim_rstnn;
wire i_mnim_i_edge_video_system_vim_comm_disable;
wire i_mnim_i_edge_video_system_vim_local_allows_holds;
wire i_mnim_i_edge_video_system_vim_rxawready;
wire i_mnim_i_edge_video_system_vim_rxawvalid;
wire [(32)-1:0] i_mnim_i_edge_video_system_vim_rxawaddr;
wire [(4)-1:0] i_mnim_i_edge_video_system_vim_rxawid;
wire [(8)-1:0] i_mnim_i_edge_video_system_vim_rxawlen;
wire [(3)-1:0] i_mnim_i_edge_video_system_vim_rxawsize;
wire [(2)-1:0] i_mnim_i_edge_video_system_vim_rxawburst;
wire i_mnim_i_edge_video_system_vim_rxwready;
wire i_mnim_i_edge_video_system_vim_rxwvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vim_rxwid;
wire [(128)-1:0] i_mnim_i_edge_video_system_vim_rxwdata;
wire [(128/8)-1:0] i_mnim_i_edge_video_system_vim_rxwstrb;
wire i_mnim_i_edge_video_system_vim_rxwlast;
wire i_mnim_i_edge_video_system_vim_rxbready;
wire i_mnim_i_edge_video_system_vim_rxbvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vim_rxbid;
wire [(2)-1:0] i_mnim_i_edge_video_system_vim_rxbresp;
wire i_mnim_i_edge_video_system_vim_rxarready;
wire i_mnim_i_edge_video_system_vim_rxarvalid;
wire [(32)-1:0] i_mnim_i_edge_video_system_vim_rxaraddr;
wire [(4)-1:0] i_mnim_i_edge_video_system_vim_rxarid;
wire [(8)-1:0] i_mnim_i_edge_video_system_vim_rxarlen;
wire [(3)-1:0] i_mnim_i_edge_video_system_vim_rxarsize;
wire [(2)-1:0] i_mnim_i_edge_video_system_vim_rxarburst;
wire i_mnim_i_edge_video_system_vim_rxrready;
wire i_mnim_i_edge_video_system_vim_rxrvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vim_rxrid;
wire [(128)-1:0] i_mnim_i_edge_video_system_vim_rxrdata;
wire i_mnim_i_edge_video_system_vim_rxrlast;
wire [(2)-1:0] i_mnim_i_edge_video_system_vim_rxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_mnim_i_edge_video_system_vim_sfni_link;
wire i_mnim_i_edge_video_system_vim_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_mnim_i_edge_video_system_vim_sbni_link;
wire i_mnim_i_edge_video_system_vim_sbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_edge_video_system_vim_svri_rlink;
wire i_mnim_i_edge_video_system_vim_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_edge_video_system_vim_svri_slink;
wire i_mnim_i_edge_video_system_vim_svri_sack;
wire i_mnim_i_edge_video_system_vim_local_spsel;
wire i_mnim_i_edge_video_system_vim_local_spenable;
wire i_mnim_i_edge_video_system_vim_local_spwrite;
wire [(32)-1:0] i_mnim_i_edge_video_system_vim_local_spaddr;
wire [(128)-1:0] i_mnim_i_edge_video_system_vim_local_spwdata;
wire i_mnim_i_edge_video_system_vim_local_spready;
wire [(128)-1:0] i_mnim_i_edge_video_system_vim_local_sprdata;
wire i_mnim_i_edge_video_system_vim_local_spslverr;
wire i_mnim_i_edge_video_system_vom_clk;
wire i_mnim_i_edge_video_system_vom_rstnn;
wire i_mnim_i_edge_video_system_vom_comm_disable;
wire i_mnim_i_edge_video_system_vom_local_allows_holds;
wire i_mnim_i_edge_video_system_vom_rxawready;
wire i_mnim_i_edge_video_system_vom_rxawvalid;
wire [(32)-1:0] i_mnim_i_edge_video_system_vom_rxawaddr;
wire [(4)-1:0] i_mnim_i_edge_video_system_vom_rxawid;
wire [(8)-1:0] i_mnim_i_edge_video_system_vom_rxawlen;
wire [(3)-1:0] i_mnim_i_edge_video_system_vom_rxawsize;
wire [(2)-1:0] i_mnim_i_edge_video_system_vom_rxawburst;
wire i_mnim_i_edge_video_system_vom_rxwready;
wire i_mnim_i_edge_video_system_vom_rxwvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vom_rxwid;
wire [(128)-1:0] i_mnim_i_edge_video_system_vom_rxwdata;
wire [(128/8)-1:0] i_mnim_i_edge_video_system_vom_rxwstrb;
wire i_mnim_i_edge_video_system_vom_rxwlast;
wire i_mnim_i_edge_video_system_vom_rxbready;
wire i_mnim_i_edge_video_system_vom_rxbvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vom_rxbid;
wire [(2)-1:0] i_mnim_i_edge_video_system_vom_rxbresp;
wire i_mnim_i_edge_video_system_vom_rxarready;
wire i_mnim_i_edge_video_system_vom_rxarvalid;
wire [(32)-1:0] i_mnim_i_edge_video_system_vom_rxaraddr;
wire [(4)-1:0] i_mnim_i_edge_video_system_vom_rxarid;
wire [(8)-1:0] i_mnim_i_edge_video_system_vom_rxarlen;
wire [(3)-1:0] i_mnim_i_edge_video_system_vom_rxarsize;
wire [(2)-1:0] i_mnim_i_edge_video_system_vom_rxarburst;
wire i_mnim_i_edge_video_system_vom_rxrready;
wire i_mnim_i_edge_video_system_vom_rxrvalid;
wire [(4)-1:0] i_mnim_i_edge_video_system_vom_rxrid;
wire [(128)-1:0] i_mnim_i_edge_video_system_vom_rxrdata;
wire i_mnim_i_edge_video_system_vom_rxrlast;
wire [(2)-1:0] i_mnim_i_edge_video_system_vom_rxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_mnim_i_edge_video_system_vom_sfni_link;
wire i_mnim_i_edge_video_system_vom_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_mnim_i_edge_video_system_vom_sbni_link;
wire i_mnim_i_edge_video_system_vom_sbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_edge_video_system_vom_svri_rlink;
wire i_mnim_i_edge_video_system_vom_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_i_edge_video_system_vom_svri_slink;
wire i_mnim_i_edge_video_system_vom_svri_sack;
wire i_mnim_i_edge_video_system_vom_local_spsel;
wire i_mnim_i_edge_video_system_vom_local_spenable;
wire i_mnim_i_edge_video_system_vom_local_spwrite;
wire [(32)-1:0] i_mnim_i_edge_video_system_vom_local_spaddr;
wire [(128)-1:0] i_mnim_i_edge_video_system_vom_local_spwdata;
wire i_mnim_i_edge_video_system_vom_local_spready;
wire [(128)-1:0] i_mnim_i_edge_video_system_vom_local_sprdata;
wire i_mnim_i_edge_video_system_vom_local_spslverr;
wire i_mnim_platform_controller_master_clk_network;
wire i_mnim_platform_controller_master_rstnn_network;
wire i_mnim_platform_controller_master_clk_master;
wire i_mnim_platform_controller_master_rstnn_master;
wire i_mnim_platform_controller_master_comm_disable;
wire i_mnim_platform_controller_master_rhready;
wire [(32)-1:0] i_mnim_platform_controller_master_rhaddr;
wire [(3)-1:0] i_mnim_platform_controller_master_rhburst;
wire i_mnim_platform_controller_master_rhmasterlock;
wire [(4)-1:0] i_mnim_platform_controller_master_rhprot;
wire [(3)-1:0] i_mnim_platform_controller_master_rhsize;
wire [(2)-1:0] i_mnim_platform_controller_master_rhtrans;
wire i_mnim_platform_controller_master_rhwrite;
wire [(32)-1:0] i_mnim_platform_controller_master_rhwdata;
wire [(32)-1:0] i_mnim_platform_controller_master_rhrdata;
wire i_mnim_platform_controller_master_rhresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_mnim_platform_controller_master_sfni_link;
wire i_mnim_platform_controller_master_sfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_mnim_platform_controller_master_sbni_link;
wire i_mnim_platform_controller_master_sbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_platform_controller_master_svri_rlink;
wire i_mnim_platform_controller_master_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_mnim_platform_controller_master_svri_slink;
wire i_mnim_platform_controller_master_svri_sack;
wire i_snim_eMamba_IP_slave_clk_network;
wire i_snim_eMamba_IP_slave_rstnn_network;
wire i_snim_eMamba_IP_slave_clk_slave;
wire i_snim_eMamba_IP_slave_rstnn_slave;
wire i_snim_eMamba_IP_slave_comm_disable;
wire i_snim_eMamba_IP_slave_sx4awready;
wire i_snim_eMamba_IP_slave_sx4awvalid;
wire [(32)-1:0] i_snim_eMamba_IP_slave_sx4awaddr;
wire [(1)-1:0] i_snim_eMamba_IP_slave_sx4awid;
wire [(8)-1:0] i_snim_eMamba_IP_slave_sx4awlen;
wire [(3)-1:0] i_snim_eMamba_IP_slave_sx4awsize;
wire [(2)-1:0] i_snim_eMamba_IP_slave_sx4awburst;
wire i_snim_eMamba_IP_slave_sx4wready;
wire i_snim_eMamba_IP_slave_sx4wvalid;
wire [(32)-1:0] i_snim_eMamba_IP_slave_sx4wdata;
wire [(32/8)-1:0] i_snim_eMamba_IP_slave_sx4wstrb;
wire i_snim_eMamba_IP_slave_sx4wlast;
wire i_snim_eMamba_IP_slave_sx4bready;
wire i_snim_eMamba_IP_slave_sx4bvalid;
wire [(1)-1:0] i_snim_eMamba_IP_slave_sx4bid;
wire [(2)-1:0] i_snim_eMamba_IP_slave_sx4bresp;
wire i_snim_eMamba_IP_slave_sx4arready;
wire i_snim_eMamba_IP_slave_sx4arvalid;
wire [(32)-1:0] i_snim_eMamba_IP_slave_sx4araddr;
wire [(1)-1:0] i_snim_eMamba_IP_slave_sx4arid;
wire [(8)-1:0] i_snim_eMamba_IP_slave_sx4arlen;
wire [(3)-1:0] i_snim_eMamba_IP_slave_sx4arsize;
wire [(2)-1:0] i_snim_eMamba_IP_slave_sx4arburst;
wire i_snim_eMamba_IP_slave_sx4rready;
wire i_snim_eMamba_IP_slave_sx4rvalid;
wire [(1)-1:0] i_snim_eMamba_IP_slave_sx4rid;
wire [(32)-1:0] i_snim_eMamba_IP_slave_sx4rdata;
wire i_snim_eMamba_IP_slave_sx4rlast;
wire [(2)-1:0] i_snim_eMamba_IP_slave_sx4rresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_eMamba_IP_slave_rfni_link;
wire i_snim_eMamba_IP_slave_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_eMamba_IP_slave_rbni_link;
wire i_snim_eMamba_IP_slave_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_eMamba_IP_slave_svri_rlink;
wire i_snim_eMamba_IP_slave_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_eMamba_IP_slave_svri_slink;
wire i_snim_eMamba_IP_slave_svri_sack;
wire i_snim_input_bram_slave_clk_network;
wire i_snim_input_bram_slave_rstnn_network;
wire i_snim_input_bram_slave_clk_slave;
wire i_snim_input_bram_slave_rstnn_slave;
wire i_snim_input_bram_slave_comm_disable;
wire i_snim_input_bram_slave_sxawready;
wire i_snim_input_bram_slave_sxawvalid;
wire [(32)-1:0] i_snim_input_bram_slave_sxawaddr;
wire [(1)-1:0] i_snim_input_bram_slave_sxawid;
wire [(8)-1:0] i_snim_input_bram_slave_sxawlen;
wire [(3)-1:0] i_snim_input_bram_slave_sxawsize;
wire [(2)-1:0] i_snim_input_bram_slave_sxawburst;
wire i_snim_input_bram_slave_sxwready;
wire i_snim_input_bram_slave_sxwvalid;
wire [(1)-1:0] i_snim_input_bram_slave_sxwid;
wire [(32)-1:0] i_snim_input_bram_slave_sxwdata;
wire [(32/8)-1:0] i_snim_input_bram_slave_sxwstrb;
wire i_snim_input_bram_slave_sxwlast;
wire i_snim_input_bram_slave_sxbready;
wire i_snim_input_bram_slave_sxbvalid;
wire [(1)-1:0] i_snim_input_bram_slave_sxbid;
wire [(2)-1:0] i_snim_input_bram_slave_sxbresp;
wire i_snim_input_bram_slave_sxarready;
wire i_snim_input_bram_slave_sxarvalid;
wire [(32)-1:0] i_snim_input_bram_slave_sxaraddr;
wire [(1)-1:0] i_snim_input_bram_slave_sxarid;
wire [(8)-1:0] i_snim_input_bram_slave_sxarlen;
wire [(3)-1:0] i_snim_input_bram_slave_sxarsize;
wire [(2)-1:0] i_snim_input_bram_slave_sxarburst;
wire i_snim_input_bram_slave_sxrready;
wire i_snim_input_bram_slave_sxrvalid;
wire [(1)-1:0] i_snim_input_bram_slave_sxrid;
wire [(32)-1:0] i_snim_input_bram_slave_sxrdata;
wire i_snim_input_bram_slave_sxrlast;
wire [(2)-1:0] i_snim_input_bram_slave_sxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_input_bram_slave_rfni_link;
wire i_snim_input_bram_slave_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_input_bram_slave_rbni_link;
wire i_snim_input_bram_slave_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_input_bram_slave_svri_rlink;
wire i_snim_input_bram_slave_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_input_bram_slave_svri_slink;
wire i_snim_input_bram_slave_svri_sack;
wire i_snim_wb_bram_slave_clk_network;
wire i_snim_wb_bram_slave_rstnn_network;
wire i_snim_wb_bram_slave_clk_slave;
wire i_snim_wb_bram_slave_rstnn_slave;
wire i_snim_wb_bram_slave_comm_disable;
wire i_snim_wb_bram_slave_sxawready;
wire i_snim_wb_bram_slave_sxawvalid;
wire [(32)-1:0] i_snim_wb_bram_slave_sxawaddr;
wire [(1)-1:0] i_snim_wb_bram_slave_sxawid;
wire [(8)-1:0] i_snim_wb_bram_slave_sxawlen;
wire [(3)-1:0] i_snim_wb_bram_slave_sxawsize;
wire [(2)-1:0] i_snim_wb_bram_slave_sxawburst;
wire i_snim_wb_bram_slave_sxwready;
wire i_snim_wb_bram_slave_sxwvalid;
wire [(1)-1:0] i_snim_wb_bram_slave_sxwid;
wire [(32)-1:0] i_snim_wb_bram_slave_sxwdata;
wire [(32/8)-1:0] i_snim_wb_bram_slave_sxwstrb;
wire i_snim_wb_bram_slave_sxwlast;
wire i_snim_wb_bram_slave_sxbready;
wire i_snim_wb_bram_slave_sxbvalid;
wire [(1)-1:0] i_snim_wb_bram_slave_sxbid;
wire [(2)-1:0] i_snim_wb_bram_slave_sxbresp;
wire i_snim_wb_bram_slave_sxarready;
wire i_snim_wb_bram_slave_sxarvalid;
wire [(32)-1:0] i_snim_wb_bram_slave_sxaraddr;
wire [(1)-1:0] i_snim_wb_bram_slave_sxarid;
wire [(8)-1:0] i_snim_wb_bram_slave_sxarlen;
wire [(3)-1:0] i_snim_wb_bram_slave_sxarsize;
wire [(2)-1:0] i_snim_wb_bram_slave_sxarburst;
wire i_snim_wb_bram_slave_sxrready;
wire i_snim_wb_bram_slave_sxrvalid;
wire [(1)-1:0] i_snim_wb_bram_slave_sxrid;
wire [(32)-1:0] i_snim_wb_bram_slave_sxrdata;
wire i_snim_wb_bram_slave_sxrlast;
wire [(2)-1:0] i_snim_wb_bram_slave_sxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_wb_bram_slave_rfni_link;
wire i_snim_wb_bram_slave_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_wb_bram_slave_rbni_link;
wire i_snim_wb_bram_slave_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_wb_bram_slave_svri_rlink;
wire i_snim_wb_bram_slave_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_wb_bram_slave_svri_slink;
wire i_snim_wb_bram_slave_svri_sack;
wire i_snim_output_bram_slave_clk_network;
wire i_snim_output_bram_slave_rstnn_network;
wire i_snim_output_bram_slave_clk_slave;
wire i_snim_output_bram_slave_rstnn_slave;
wire i_snim_output_bram_slave_comm_disable;
wire i_snim_output_bram_slave_sxawready;
wire i_snim_output_bram_slave_sxawvalid;
wire [(32)-1:0] i_snim_output_bram_slave_sxawaddr;
wire [(1)-1:0] i_snim_output_bram_slave_sxawid;
wire [(8)-1:0] i_snim_output_bram_slave_sxawlen;
wire [(3)-1:0] i_snim_output_bram_slave_sxawsize;
wire [(2)-1:0] i_snim_output_bram_slave_sxawburst;
wire i_snim_output_bram_slave_sxwready;
wire i_snim_output_bram_slave_sxwvalid;
wire [(1)-1:0] i_snim_output_bram_slave_sxwid;
wire [(32)-1:0] i_snim_output_bram_slave_sxwdata;
wire [(32/8)-1:0] i_snim_output_bram_slave_sxwstrb;
wire i_snim_output_bram_slave_sxwlast;
wire i_snim_output_bram_slave_sxbready;
wire i_snim_output_bram_slave_sxbvalid;
wire [(1)-1:0] i_snim_output_bram_slave_sxbid;
wire [(2)-1:0] i_snim_output_bram_slave_sxbresp;
wire i_snim_output_bram_slave_sxarready;
wire i_snim_output_bram_slave_sxarvalid;
wire [(32)-1:0] i_snim_output_bram_slave_sxaraddr;
wire [(1)-1:0] i_snim_output_bram_slave_sxarid;
wire [(8)-1:0] i_snim_output_bram_slave_sxarlen;
wire [(3)-1:0] i_snim_output_bram_slave_sxarsize;
wire [(2)-1:0] i_snim_output_bram_slave_sxarburst;
wire i_snim_output_bram_slave_sxrready;
wire i_snim_output_bram_slave_sxrvalid;
wire [(1)-1:0] i_snim_output_bram_slave_sxrid;
wire [(32)-1:0] i_snim_output_bram_slave_sxrdata;
wire i_snim_output_bram_slave_sxrlast;
wire [(2)-1:0] i_snim_output_bram_slave_sxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_output_bram_slave_rfni_link;
wire i_snim_output_bram_slave_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_output_bram_slave_rbni_link;
wire i_snim_output_bram_slave_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_output_bram_slave_svri_rlink;
wire i_snim_output_bram_slave_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_output_bram_slave_svri_slink;
wire i_snim_output_bram_slave_svri_sack;
wire i_snim_i_system_ddr_no_name_clk;
wire i_snim_i_system_ddr_no_name_rstnn;
wire i_snim_i_system_ddr_no_name_comm_disable;
wire i_snim_i_system_ddr_no_name_sxawready;
wire i_snim_i_system_ddr_no_name_sxawvalid;
wire [(32)-1:0] i_snim_i_system_ddr_no_name_sxawaddr;
wire [(16)-1:0] i_snim_i_system_ddr_no_name_sxawid;
wire [(8)-1:0] i_snim_i_system_ddr_no_name_sxawlen;
wire [(3)-1:0] i_snim_i_system_ddr_no_name_sxawsize;
wire [(2)-1:0] i_snim_i_system_ddr_no_name_sxawburst;
wire i_snim_i_system_ddr_no_name_sxwready;
wire i_snim_i_system_ddr_no_name_sxwvalid;
wire [(16)-1:0] i_snim_i_system_ddr_no_name_sxwid;
wire [(128)-1:0] i_snim_i_system_ddr_no_name_sxwdata;
wire [(128/8)-1:0] i_snim_i_system_ddr_no_name_sxwstrb;
wire i_snim_i_system_ddr_no_name_sxwlast;
wire i_snim_i_system_ddr_no_name_sxbready;
wire i_snim_i_system_ddr_no_name_sxbvalid;
wire [(16)-1:0] i_snim_i_system_ddr_no_name_sxbid;
wire [(2)-1:0] i_snim_i_system_ddr_no_name_sxbresp;
wire i_snim_i_system_ddr_no_name_sxarready;
wire i_snim_i_system_ddr_no_name_sxarvalid;
wire [(32)-1:0] i_snim_i_system_ddr_no_name_sxaraddr;
wire [(16)-1:0] i_snim_i_system_ddr_no_name_sxarid;
wire [(8)-1:0] i_snim_i_system_ddr_no_name_sxarlen;
wire [(3)-1:0] i_snim_i_system_ddr_no_name_sxarsize;
wire [(2)-1:0] i_snim_i_system_ddr_no_name_sxarburst;
wire i_snim_i_system_ddr_no_name_sxrready;
wire i_snim_i_system_ddr_no_name_sxrvalid;
wire [(16)-1:0] i_snim_i_system_ddr_no_name_sxrid;
wire [(128)-1:0] i_snim_i_system_ddr_no_name_sxrdata;
wire i_snim_i_system_ddr_no_name_sxrlast;
wire [(2)-1:0] i_snim_i_system_ddr_no_name_sxrresp;
wire [(`BW_FNI_LINK(BW_FNI_PHIT))-1:0] i_snim_i_system_ddr_no_name_rfni_link;
wire i_snim_i_system_ddr_no_name_rfni_ready;
wire [(`BW_BNI_LINK(BW_BNI_PHIT))-1:0] i_snim_i_system_ddr_no_name_rbni_link;
wire i_snim_i_system_ddr_no_name_rbni_ready;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_system_ddr_no_name_svri_rlink;
wire i_snim_i_system_ddr_no_name_svri_rack;
wire [(`BW_SVRING_LINK)-1:0] i_snim_i_system_ddr_no_name_svri_slink;
wire i_snim_i_system_ddr_no_name_svri_sack;
wire i_system_router_clk;
wire i_system_router_rstnn;
wire [((`BW_FNI_LINK(BW_FNI_PHIT))*(1))-1:0] i_system_router_rfni_link_list;
wire [((1)*(1))-1:0] i_system_router_rfni_ready_list;
wire [((`BW_BNI_LINK(BW_BNI_PHIT))*(1))-1:0] i_system_router_rbni_link_list;
wire [((1)*(1))-1:0] i_system_router_rbni_ready_list;
wire [((`BW_FNI_LINK(BW_FNI_PHIT))*(7))-1:0] i_system_router_sfni_link_list;
wire [((1)*(7))-1:0] i_system_router_sfni_ready_list;
wire [((`BW_BNI_LINK(BW_BNI_PHIT))*(7))-1:0] i_system_router_sbni_link_list;
wire [((1)*(7))-1:0] i_system_router_sbni_ready_list;
wire i_user_router_clk;
wire i_user_router_rstnn;
wire [((`BW_FNI_LINK(BW_FNI_PHIT))*(6))-1:0] i_user_router_rfni_link_list;
wire [((1)*(6))-1:0] i_user_router_rfni_ready_list;
wire [((`BW_BNI_LINK(BW_BNI_PHIT))*(6))-1:0] i_user_router_rbni_link_list;
wire [((1)*(6))-1:0] i_user_router_rbni_ready_list;
wire [((`BW_FNI_LINK(BW_FNI_PHIT))*(6))-1:0] i_user_router_sfni_link_list;
wire [((1)*(6))-1:0] i_user_router_sfni_ready_list;
wire [((`BW_BNI_LINK(BW_BNI_PHIT))*(6))-1:0] i_user_router_sbni_link_list;
wire [((1)*(6))-1:0] i_user_router_sbni_ready_list;

RVC_ORCA
#(
	.RESET_VECTOR((32'h e2020000)),
	.ENABLE_EXCEPTIONS(1),
	.ENABLE_INTERRUPTS(1),
	.NUM_INTERRUPTS(32)
)
i_main_core
(
	.clk(i_main_core_clk),
	.rstnn(i_main_core_rstnn),
	.interrupt_vector(i_main_core_interrupt_vector),
	.interrupt_out(i_main_core_interrupt_out),
	.inst_sxawready(i_main_core_inst_sxawready),
	.inst_sxawvalid(i_main_core_inst_sxawvalid),
	.inst_sxawaddr(i_main_core_inst_sxawaddr),
	.inst_sxawid(i_main_core_inst_sxawid),
	.inst_sxawlen(i_main_core_inst_sxawlen),
	.inst_sxawsize(i_main_core_inst_sxawsize),
	.inst_sxawburst(i_main_core_inst_sxawburst),
	.inst_sxwready(i_main_core_inst_sxwready),
	.inst_sxwvalid(i_main_core_inst_sxwvalid),
	.inst_sxwid(i_main_core_inst_sxwid),
	.inst_sxwdata(i_main_core_inst_sxwdata),
	.inst_sxwstrb(i_main_core_inst_sxwstrb),
	.inst_sxwlast(i_main_core_inst_sxwlast),
	.inst_sxbready(i_main_core_inst_sxbready),
	.inst_sxbvalid(i_main_core_inst_sxbvalid),
	.inst_sxbid(i_main_core_inst_sxbid),
	.inst_sxbresp(i_main_core_inst_sxbresp),
	.inst_sxarready(i_main_core_inst_sxarready),
	.inst_sxarvalid(i_main_core_inst_sxarvalid),
	.inst_sxaraddr(i_main_core_inst_sxaraddr),
	.inst_sxarid(i_main_core_inst_sxarid),
	.inst_sxarlen(i_main_core_inst_sxarlen),
	.inst_sxarsize(i_main_core_inst_sxarsize),
	.inst_sxarburst(i_main_core_inst_sxarburst),
	.inst_sxrready(i_main_core_inst_sxrready),
	.inst_sxrvalid(i_main_core_inst_sxrvalid),
	.inst_sxrid(i_main_core_inst_sxrid),
	.inst_sxrdata(i_main_core_inst_sxrdata),
	.inst_sxrlast(i_main_core_inst_sxrlast),
	.inst_sxrresp(i_main_core_inst_sxrresp),
	.data_sxawready(i_main_core_data_sxawready),
	.data_sxawvalid(i_main_core_data_sxawvalid),
	.data_sxawaddr(i_main_core_data_sxawaddr),
	.data_sxawid(i_main_core_data_sxawid),
	.data_sxawlen(i_main_core_data_sxawlen),
	.data_sxawsize(i_main_core_data_sxawsize),
	.data_sxawburst(i_main_core_data_sxawburst),
	.data_sxwready(i_main_core_data_sxwready),
	.data_sxwvalid(i_main_core_data_sxwvalid),
	.data_sxwid(i_main_core_data_sxwid),
	.data_sxwdata(i_main_core_data_sxwdata),
	.data_sxwstrb(i_main_core_data_sxwstrb),
	.data_sxwlast(i_main_core_data_sxwlast),
	.data_sxbready(i_main_core_data_sxbready),
	.data_sxbvalid(i_main_core_data_sxbvalid),
	.data_sxbid(i_main_core_data_sxbid),
	.data_sxbresp(i_main_core_data_sxbresp),
	.data_sxarready(i_main_core_data_sxarready),
	.data_sxarvalid(i_main_core_data_sxarvalid),
	.data_sxaraddr(i_main_core_data_sxaraddr),
	.data_sxarid(i_main_core_data_sxarid),
	.data_sxarlen(i_main_core_data_sxarlen),
	.data_sxarsize(i_main_core_data_sxarsize),
	.data_sxarburst(i_main_core_data_sxarburst),
	.data_sxrready(i_main_core_data_sxrready),
	.data_sxrvalid(i_main_core_data_sxrvalid),
	.data_sxrid(i_main_core_data_sxrid),
	.data_sxrdata(i_main_core_data_sxrdata),
	.data_sxrlast(i_main_core_data_sxrlast),
	.data_sxrresp(i_main_core_data_sxrresp),
	.spc(i_main_core_spc),
	.sinst(i_main_core_sinst)
);

ERVP_LED_CHECKER
#(
	.NUM_LED(1)
)
i_led
(
	.clk(i_led_clk),
	.tick_62d5ms(i_led_tick_62d5ms),
	.rstnn(i_led_rstnn),
	.app_finished(i_led_app_finished),
	.led_list(i_led_led_list)
);

ERVP_FLORIAN
#(
	.BW_ADDR(32),
	.BW_DATA(32),
	.SUPPORT_DOUBLE(0)
)
i_florian_000
(
	.clk(i_florian_000_clk),
	.rstnn(i_florian_000_rstnn),
	.rpsel(i_florian_000_rpsel),
	.rpenable(i_florian_000_rpenable),
	.rpwrite(i_florian_000_rpwrite),
	.rpaddr(i_florian_000_rpaddr),
	.rpwdata(i_florian_000_rpwdata),
	.rpready(i_florian_000_rpready),
	.rprdata(i_florian_000_rprdata),
	.rpslverr(i_florian_000_rpslverr)
);

EDGE_VIDEO_SYSTEM
#(
	.BW_ADDR(32)
)
i_edge_video_system
(
	.global_rstnn(i_edge_video_system_global_rstnn),
	.rstnn_noc(i_edge_video_system_rstnn_noc),
	.rstnn_video(i_edge_video_system_rstnn_video),
	.tick_1us(i_edge_video_system_tick_1us),
	.clk_apb(i_edge_video_system_clk_apb),
	.clk_vdma(i_edge_video_system_clk_vdma),
	.clk_vimif(i_edge_video_system_clk_vimif),
	.clk_vomif(i_edge_video_system_clk_vomif),
	.clk_25M(i_edge_video_system_clk_25M),
	.clk_50M(i_edge_video_system_clk_50M),
	.clk_150M(i_edge_video_system_clk_150M),
	.clk_200M(i_edge_video_system_clk_200M),
	.clk_300M(i_edge_video_system_clk_300M),
	.vdma_sxawready(i_edge_video_system_vdma_sxawready),
	.vdma_sxawvalid(i_edge_video_system_vdma_sxawvalid),
	.vdma_sxawaddr(i_edge_video_system_vdma_sxawaddr),
	.vdma_sxawid(i_edge_video_system_vdma_sxawid),
	.vdma_sxawlen(i_edge_video_system_vdma_sxawlen),
	.vdma_sxawsize(i_edge_video_system_vdma_sxawsize),
	.vdma_sxawburst(i_edge_video_system_vdma_sxawburst),
	.vdma_sxwready(i_edge_video_system_vdma_sxwready),
	.vdma_sxwvalid(i_edge_video_system_vdma_sxwvalid),
	.vdma_sxwid(i_edge_video_system_vdma_sxwid),
	.vdma_sxwdata(i_edge_video_system_vdma_sxwdata),
	.vdma_sxwstrb(i_edge_video_system_vdma_sxwstrb),
	.vdma_sxwlast(i_edge_video_system_vdma_sxwlast),
	.vdma_sxbready(i_edge_video_system_vdma_sxbready),
	.vdma_sxbvalid(i_edge_video_system_vdma_sxbvalid),
	.vdma_sxbid(i_edge_video_system_vdma_sxbid),
	.vdma_sxbresp(i_edge_video_system_vdma_sxbresp),
	.vdma_sxarready(i_edge_video_system_vdma_sxarready),
	.vdma_sxarvalid(i_edge_video_system_vdma_sxarvalid),
	.vdma_sxaraddr(i_edge_video_system_vdma_sxaraddr),
	.vdma_sxarid(i_edge_video_system_vdma_sxarid),
	.vdma_sxarlen(i_edge_video_system_vdma_sxarlen),
	.vdma_sxarsize(i_edge_video_system_vdma_sxarsize),
	.vdma_sxarburst(i_edge_video_system_vdma_sxarburst),
	.vdma_sxrready(i_edge_video_system_vdma_sxrready),
	.vdma_sxrvalid(i_edge_video_system_vdma_sxrvalid),
	.vdma_sxrid(i_edge_video_system_vdma_sxrid),
	.vdma_sxrdata(i_edge_video_system_vdma_sxrdata),
	.vdma_sxrlast(i_edge_video_system_vdma_sxrlast),
	.vdma_sxrresp(i_edge_video_system_vdma_sxrresp),
	.vdma_ctrl_rpsel(i_edge_video_system_vdma_ctrl_rpsel),
	.vdma_ctrl_rpenable(i_edge_video_system_vdma_ctrl_rpenable),
	.vdma_ctrl_rpwrite(i_edge_video_system_vdma_ctrl_rpwrite),
	.vdma_ctrl_rpaddr(i_edge_video_system_vdma_ctrl_rpaddr),
	.vdma_ctrl_rpwdata(i_edge_video_system_vdma_ctrl_rpwdata),
	.vdma_ctrl_rpready(i_edge_video_system_vdma_ctrl_rpready),
	.vdma_ctrl_rprdata(i_edge_video_system_vdma_ctrl_rprdata),
	.vdma_ctrl_rpslverr(i_edge_video_system_vdma_ctrl_rpslverr),
	.vim_sxawready(i_edge_video_system_vim_sxawready),
	.vim_sxawvalid(i_edge_video_system_vim_sxawvalid),
	.vim_sxawaddr(i_edge_video_system_vim_sxawaddr),
	.vim_sxawid(i_edge_video_system_vim_sxawid),
	.vim_sxawlen(i_edge_video_system_vim_sxawlen),
	.vim_sxawsize(i_edge_video_system_vim_sxawsize),
	.vim_sxawburst(i_edge_video_system_vim_sxawburst),
	.vim_sxwready(i_edge_video_system_vim_sxwready),
	.vim_sxwvalid(i_edge_video_system_vim_sxwvalid),
	.vim_sxwid(i_edge_video_system_vim_sxwid),
	.vim_sxwdata(i_edge_video_system_vim_sxwdata),
	.vim_sxwstrb(i_edge_video_system_vim_sxwstrb),
	.vim_sxwlast(i_edge_video_system_vim_sxwlast),
	.vim_sxbready(i_edge_video_system_vim_sxbready),
	.vim_sxbvalid(i_edge_video_system_vim_sxbvalid),
	.vim_sxbid(i_edge_video_system_vim_sxbid),
	.vim_sxbresp(i_edge_video_system_vim_sxbresp),
	.vim_sxarready(i_edge_video_system_vim_sxarready),
	.vim_sxarvalid(i_edge_video_system_vim_sxarvalid),
	.vim_sxaraddr(i_edge_video_system_vim_sxaraddr),
	.vim_sxarid(i_edge_video_system_vim_sxarid),
	.vim_sxarlen(i_edge_video_system_vim_sxarlen),
	.vim_sxarsize(i_edge_video_system_vim_sxarsize),
	.vim_sxarburst(i_edge_video_system_vim_sxarburst),
	.vim_sxrready(i_edge_video_system_vim_sxrready),
	.vim_sxrvalid(i_edge_video_system_vim_sxrvalid),
	.vim_sxrid(i_edge_video_system_vim_sxrid),
	.vim_sxrdata(i_edge_video_system_vim_sxrdata),
	.vim_sxrlast(i_edge_video_system_vim_sxrlast),
	.vim_sxrresp(i_edge_video_system_vim_sxrresp),
	.vom_sxawready(i_edge_video_system_vom_sxawready),
	.vom_sxawvalid(i_edge_video_system_vom_sxawvalid),
	.vom_sxawaddr(i_edge_video_system_vom_sxawaddr),
	.vom_sxawid(i_edge_video_system_vom_sxawid),
	.vom_sxawlen(i_edge_video_system_vom_sxawlen),
	.vom_sxawsize(i_edge_video_system_vom_sxawsize),
	.vom_sxawburst(i_edge_video_system_vom_sxawburst),
	.vom_sxwready(i_edge_video_system_vom_sxwready),
	.vom_sxwvalid(i_edge_video_system_vom_sxwvalid),
	.vom_sxwid(i_edge_video_system_vom_sxwid),
	.vom_sxwdata(i_edge_video_system_vom_sxwdata),
	.vom_sxwstrb(i_edge_video_system_vom_sxwstrb),
	.vom_sxwlast(i_edge_video_system_vom_sxwlast),
	.vom_sxbready(i_edge_video_system_vom_sxbready),
	.vom_sxbvalid(i_edge_video_system_vom_sxbvalid),
	.vom_sxbid(i_edge_video_system_vom_sxbid),
	.vom_sxbresp(i_edge_video_system_vom_sxbresp),
	.vom_sxarready(i_edge_video_system_vom_sxarready),
	.vom_sxarvalid(i_edge_video_system_vom_sxarvalid),
	.vom_sxaraddr(i_edge_video_system_vom_sxaraddr),
	.vom_sxarid(i_edge_video_system_vom_sxarid),
	.vom_sxarlen(i_edge_video_system_vom_sxarlen),
	.vom_sxarsize(i_edge_video_system_vom_sxarsize),
	.vom_sxarburst(i_edge_video_system_vom_sxarburst),
	.vom_sxrready(i_edge_video_system_vom_sxrready),
	.vom_sxrvalid(i_edge_video_system_vom_sxrvalid),
	.vom_sxrid(i_edge_video_system_vom_sxrid),
	.vom_sxrdata(i_edge_video_system_vom_sxrdata),
	.vom_sxrlast(i_edge_video_system_vom_sxrlast),
	.vom_sxrresp(i_edge_video_system_vom_sxrresp),
	.video_ctrl_rpsel(i_edge_video_system_video_ctrl_rpsel),
	.video_ctrl_rpenable(i_edge_video_system_video_ctrl_rpenable),
	.video_ctrl_rpwrite(i_edge_video_system_video_ctrl_rpwrite),
	.video_ctrl_rpaddr(i_edge_video_system_video_ctrl_rpaddr),
	.video_ctrl_rpwdata(i_edge_video_system_video_ctrl_rpwdata),
	.video_ctrl_rpready(i_edge_video_system_video_ctrl_rpready),
	.video_ctrl_rprdata(i_edge_video_system_video_ctrl_rprdata),
	.video_ctrl_rpslverr(i_edge_video_system_video_ctrl_rpslverr),
	.cis_rclk_od(i_edge_video_system_cis_rclk_od),
	.cis_rclk_oval(i_edge_video_system_cis_rclk_oval),
	.cis_rclk_ival(i_edge_video_system_cis_rclk_ival),
	.cis_rdata_od(i_edge_video_system_cis_rdata_od),
	.cis_rdata_oval(i_edge_video_system_cis_rdata_oval),
	.cis_rdata_ival(i_edge_video_system_cis_rdata_ival),
	.hdmi_rclk_od(i_edge_video_system_hdmi_rclk_od),
	.hdmi_rclk_oval(i_edge_video_system_hdmi_rclk_oval),
	.hdmi_rclk_ival(i_edge_video_system_hdmi_rclk_ival),
	.hdmi_rdata_od(i_edge_video_system_hdmi_rdata_od),
	.hdmi_rdata_oval(i_edge_video_system_hdmi_rdata_oval),
	.hdmi_rdata_ival(i_edge_video_system_hdmi_rdata_ival)
	`include "video_module_port_mapping.vh"
);

ERVP_COMMON_PERI_GROUP
#(
	.BW_ADDR(32),
	.BW_DATA(32),
	.NUM_LOCK(1),
	.NUM_GLOBAL_TAG(1),
	.NUM_AUTO_ID(1)
)
common_peri_group
(
	.clk(common_peri_group_clk),
	.rstnn(common_peri_group_rstnn),
	.lock_status_list(common_peri_group_lock_status_list),
	.thread_status_list(common_peri_group_thread_status_list),
	.real_clock(common_peri_group_real_clock),
	.global_tag_list(common_peri_group_global_tag_list),
	.system_tick_config(common_peri_group_system_tick_config),
	.core_tick_config(common_peri_group_core_tick_config),
	.rpsel(common_peri_group_rpsel),
	.rpenable(common_peri_group_rpenable),
	.rpwrite(common_peri_group_rpwrite),
	.rpaddr(common_peri_group_rpaddr),
	.rpwdata(common_peri_group_rpwdata),
	.rpready(common_peri_group_rpready),
	.rprdata(common_peri_group_rprdata),
	.rpslverr(common_peri_group_rpslverr)
);

ERVP_TICK_GENERATOR
autoname_104
(
	.clk(autoname_104_clk),
	.rstnn(autoname_104_rstnn),
	.tick_config(autoname_104_tick_config),
	.tick_1us(autoname_104_tick_1us),
	.tick_62d5ms(autoname_104_tick_62d5ms)
);

ERVP_TICK_GENERATOR
autoname_105
(
	.clk(autoname_105_clk),
	.rstnn(autoname_105_rstnn),
	.tick_config(autoname_105_tick_config),
	.tick_1us(autoname_105_tick_1us),
	.tick_62d5ms(autoname_105_tick_62d5ms)
);

ERVP_REAL_CLOCK
autoname_106
(
	.clk(autoname_106_clk),
	.rstnn(autoname_106_rstnn),
	.tick_1us(autoname_106_tick_1us),
	.real_clock(autoname_106_real_clock)
);

ERVP_EXTERNAL_PERI_GROUP
#(
	.BW_ADDR(32),
	.BW_DATA(32),
	.NUM_UART(1),
	.NUM_SPI(0),
	.NUM_I2C(2),
	.NUM_GPIO(0),
	.NUM_AIOIF(0)
)
external_peri_group
(
	.clk(external_peri_group_clk),
	.rstnn(external_peri_group_rstnn),
	.tick_1us(external_peri_group_tick_1us),
	.tick_gpio(external_peri_group_tick_gpio),
	.uart_interrupts(external_peri_group_uart_interrupts),
	.spi_interrupt(external_peri_group_spi_interrupt),
	.i2c_interrupts(external_peri_group_i2c_interrupts),
	.gpio_interrupts(external_peri_group_gpio_interrupts),
	.wifi_interrupt(external_peri_group_wifi_interrupt),
	.spi_common_sclk(external_peri_group_spi_common_sclk),
	.spi_common_sdq0(external_peri_group_spi_common_sdq0),
	.rpsel(external_peri_group_rpsel),
	.rpenable(external_peri_group_rpenable),
	.rpwrite(external_peri_group_rpwrite),
	.rpaddr(external_peri_group_rpaddr),
	.rpwdata(external_peri_group_rpwdata),
	.rpready(external_peri_group_rpready),
	.rprdata(external_peri_group_rprdata),
	.rpslverr(external_peri_group_rpslverr),
	.uart_stx_list(external_peri_group_uart_stx_list),
	.uart_srx_list(external_peri_group_uart_srx_list),
	.i2c_sclk_od_list(external_peri_group_i2c_sclk_od_list),
	.i2c_sclk_oval_list(external_peri_group_i2c_sclk_oval_list),
	.i2c_sclk_ival_list(external_peri_group_i2c_sclk_ival_list),
	.i2c_sdata_od_list(external_peri_group_i2c_sdata_od_list),
	.i2c_sdata_oval_list(external_peri_group_i2c_sdata_oval_list),
	.i2c_sdata_ival_list(external_peri_group_i2c_sdata_ival_list),
	.oled_sdcsel_oe(external_peri_group_oled_sdcsel_oe),
	.oled_sdcsel_oval(external_peri_group_oled_sdcsel_oval),
	.oled_sdcsel_ival(external_peri_group_oled_sdcsel_ival),
	.oled_srstnn_oe(external_peri_group_oled_srstnn_oe),
	.oled_srstnn_oval(external_peri_group_oled_srstnn_oval),
	.oled_srstnn_ival(external_peri_group_oled_srstnn_ival),
	.oled_svbat_oe(external_peri_group_oled_svbat_oe),
	.oled_svbat_oval(external_peri_group_oled_svbat_oval),
	.oled_svbat_ival(external_peri_group_oled_svbat_ival),
	.oled_svdd_oe(external_peri_group_oled_svdd_oe),
	.oled_svdd_oval(external_peri_group_oled_svdd_oval),
	.oled_svdd_ival(external_peri_group_oled_svdd_ival),
	.wifi_sitr(external_peri_group_wifi_sitr),
	.wifi_srstnn(external_peri_group_wifi_srstnn),
	.wifi_swp(external_peri_group_wifi_swp),
	.wifi_shibernate(external_peri_group_wifi_shibernate)
);

ERVP_CORE_PERI_GROUP
#(
	.BW_ADDR(32),
	.BW_DATA(32),
	.PROCESS_ID(0),
	.NUM_LOCK(1),
	.NUM_GLOBAL_TAG(1)
)
core_peri_group
(
	.clk(core_peri_group_clk),
	.rstnn(core_peri_group_rstnn),
	.tick_1us(core_peri_group_tick_1us),
	.delay_notice(core_peri_group_delay_notice),
	.plic_interrupt(core_peri_group_plic_interrupt),
	.lock_status_list(core_peri_group_lock_status_list),
	.global_tag_list(core_peri_group_global_tag_list),
	.thread_status_list(core_peri_group_thread_status_list),
	.core_interrupt_vector(core_peri_group_core_interrupt_vector),
	.allows_holds(core_peri_group_allows_holds),
	.rpsel(core_peri_group_rpsel),
	.rpenable(core_peri_group_rpenable),
	.rpwrite(core_peri_group_rpwrite),
	.rpaddr(core_peri_group_rpaddr),
	.rpwdata(core_peri_group_rpwdata),
	.rpready(core_peri_group_rpready),
	.rprdata(core_peri_group_rprdata),
	.rpslverr(core_peri_group_rpslverr),
	.tcu_spsel(core_peri_group_tcu_spsel),
	.tcu_spenable(core_peri_group_tcu_spenable),
	.tcu_spwrite(core_peri_group_tcu_spwrite),
	.tcu_spaddr(core_peri_group_tcu_spaddr),
	.tcu_spwdata(core_peri_group_tcu_spwdata),
	.tcu_spready(core_peri_group_tcu_spready),
	.tcu_sprdata(core_peri_group_tcu_sprdata),
	.tcu_spslverr(core_peri_group_tcu_spslverr),
	.florian_spsel(core_peri_group_florian_spsel),
	.florian_spenable(core_peri_group_florian_spenable),
	.florian_spwrite(core_peri_group_florian_spwrite),
	.florian_spaddr(core_peri_group_florian_spaddr),
	.florian_spwdata(core_peri_group_florian_spwdata),
	.florian_spready(core_peri_group_florian_spready),
	.florian_sprdata(core_peri_group_florian_sprdata),
	.florian_spslverr(core_peri_group_florian_spslverr)
);

ERVP_PLATFORM_CONTROLLER
#(
	.BW_ADDR(32),
	.NUM_CORE(1),
	.NUM_RESET(7),
	.NUM_AUTO_RESET(4)
)
platform_controller
(
	.clk(platform_controller_clk),
	.external_rstnn(platform_controller_external_rstnn),
	.global_rstnn(platform_controller_global_rstnn),
	.global_rstpp(platform_controller_global_rstpp),
	.rstnn_seqeunce(platform_controller_rstnn_seqeunce),
	.rstpp_seqeunce(platform_controller_rstpp_seqeunce),
	.boot_mode(platform_controller_boot_mode),
	.jtag_select(platform_controller_jtag_select),
	.initialized(platform_controller_initialized),
	.app_finished(platform_controller_app_finished),
	.rstnn(platform_controller_rstnn),
	.shready(platform_controller_shready),
	.shaddr(platform_controller_shaddr),
	.shburst(platform_controller_shburst),
	.shmasterlock(platform_controller_shmasterlock),
	.shprot(platform_controller_shprot),
	.shsize(platform_controller_shsize),
	.shtrans(platform_controller_shtrans),
	.shwrite(platform_controller_shwrite),
	.shwdata(platform_controller_shwdata),
	.shrdata(platform_controller_shrdata),
	.shresp(platform_controller_shresp),
	.rpsel(platform_controller_rpsel),
	.rpenable(platform_controller_rpenable),
	.rpwrite(platform_controller_rpwrite),
	.rpaddr(platform_controller_rpaddr),
	.rpwdata(platform_controller_rpwdata),
	.rpready(platform_controller_rpready),
	.rprdata(platform_controller_rprdata),
	.rpslverr(platform_controller_rpslverr),
	.pjtag_rtck(platform_controller_pjtag_rtck),
	.pjtag_rtrstnn(platform_controller_pjtag_rtrstnn),
	.pjtag_rtms(platform_controller_pjtag_rtms),
	.pjtag_rtdi(platform_controller_pjtag_rtdi),
	.pjtag_rtdo(platform_controller_pjtag_rtdo),
	.noc_debug_spsel(platform_controller_noc_debug_spsel),
	.noc_debug_spenable(platform_controller_noc_debug_spenable),
	.noc_debug_spwrite(platform_controller_noc_debug_spwrite),
	.noc_debug_spaddr(platform_controller_noc_debug_spaddr),
	.noc_debug_spwdata(platform_controller_noc_debug_spwdata),
	.noc_debug_spready(platform_controller_noc_debug_spready),
	.noc_debug_sprdata(platform_controller_noc_debug_sprdata),
	.noc_debug_spslverr(platform_controller_noc_debug_spslverr),
	.rpc_list(platform_controller_rpc_list),
	.rinst_list(platform_controller_rinst_list)
);

MUNOC_DEFAULT_SNIM
#(
	.NODE_ID(`NODE_ID_DEFAULT_SLAVE),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.USE_SW_INTERFACE(1),
	.USE_JTAG_INTERFACE(1),
	.NOC_CONTROLLER_BASEADDR(`NOC_CONTROLLER_BASEADDR)
)
default_slave
(
	.clk_network(default_slave_clk_network),
	.rstnn_network(default_slave_rstnn_network),
	.clk_debug(default_slave_clk_debug),
	.rstnn_debug(default_slave_rstnn_debug),
	.comm_disable(default_slave_comm_disable),
	.rfni_link(default_slave_rfni_link),
	.rfni_ready(default_slave_rfni_ready),
	.rbni_link(default_slave_rbni_link),
	.rbni_ready(default_slave_rbni_ready),
	.debug_rpsel(default_slave_debug_rpsel),
	.debug_rpenable(default_slave_debug_rpenable),
	.debug_rpwrite(default_slave_debug_rpwrite),
	.debug_rpaddr(default_slave_debug_rpaddr),
	.debug_rpwdata(default_slave_debug_rpwdata),
	.debug_rpready(default_slave_debug_rpready),
	.debug_rprdata(default_slave_debug_rprdata),
	.debug_rpslverr(default_slave_debug_rpslverr),
	.svri_rlink(default_slave_svri_rlink),
	.svri_rack(default_slave_svri_rack),
	.svri_slink(default_slave_svri_slink),
	.svri_sack(default_slave_svri_sack)
);

MUNOC_INTER_ROUTER_FIFO
#(
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT)
)
i_inter_router_fifo00
(
	.clk(i_inter_router_fifo00_clk),
	.rstnn(i_inter_router_fifo00_rstnn),
	.rfni_link(i_inter_router_fifo00_rfni_link),
	.rfni_ready(i_inter_router_fifo00_rfni_ready),
	.rbni_link(i_inter_router_fifo00_rbni_link),
	.rbni_ready(i_inter_router_fifo00_rbni_ready),
	.sfni_link(i_inter_router_fifo00_sfni_link),
	.sfni_ready(i_inter_router_fifo00_sfni_ready),
	.sbni_link(i_inter_router_fifo00_sbni_link),
	.sbni_ready(i_inter_router_fifo00_sbni_ready)
);

MUNOC_APB_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_I_EDGE_VIDEO_SYSTEM_VDMA_CTRL),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("i_edge_video_system_vdma_ctrl")
)
i_snim_i_edge_video_system_vdma_ctrl
(
	.clk_network(i_snim_i_edge_video_system_vdma_ctrl_clk_network),
	.rstnn_network(i_snim_i_edge_video_system_vdma_ctrl_rstnn_network),
	.clk_slave(i_snim_i_edge_video_system_vdma_ctrl_clk_slave),
	.rstnn_slave(i_snim_i_edge_video_system_vdma_ctrl_rstnn_slave),
	.comm_disable(i_snim_i_edge_video_system_vdma_ctrl_comm_disable),
	.spsel(i_snim_i_edge_video_system_vdma_ctrl_spsel),
	.spenable(i_snim_i_edge_video_system_vdma_ctrl_spenable),
	.spwrite(i_snim_i_edge_video_system_vdma_ctrl_spwrite),
	.spaddr(i_snim_i_edge_video_system_vdma_ctrl_spaddr),
	.spwdata(i_snim_i_edge_video_system_vdma_ctrl_spwdata),
	.spready(i_snim_i_edge_video_system_vdma_ctrl_spready),
	.sprdata(i_snim_i_edge_video_system_vdma_ctrl_sprdata),
	.spslverr(i_snim_i_edge_video_system_vdma_ctrl_spslverr),
	.rfni_link(i_snim_i_edge_video_system_vdma_ctrl_rfni_link),
	.rfni_ready(i_snim_i_edge_video_system_vdma_ctrl_rfni_ready),
	.rbni_link(i_snim_i_edge_video_system_vdma_ctrl_rbni_link),
	.rbni_ready(i_snim_i_edge_video_system_vdma_ctrl_rbni_ready),
	.svri_rlink(i_snim_i_edge_video_system_vdma_ctrl_svri_rlink),
	.svri_rack(i_snim_i_edge_video_system_vdma_ctrl_svri_rack),
	.svri_slink(i_snim_i_edge_video_system_vdma_ctrl_svri_slink),
	.svri_sack(i_snim_i_edge_video_system_vdma_ctrl_svri_sack)
);

MUNOC_APB_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_I_EDGE_VIDEO_SYSTEM_VIDEO_CTRL),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("i_edge_video_system_video_ctrl")
)
i_snim_i_edge_video_system_video_ctrl
(
	.clk_network(i_snim_i_edge_video_system_video_ctrl_clk_network),
	.rstnn_network(i_snim_i_edge_video_system_video_ctrl_rstnn_network),
	.clk_slave(i_snim_i_edge_video_system_video_ctrl_clk_slave),
	.rstnn_slave(i_snim_i_edge_video_system_video_ctrl_rstnn_slave),
	.comm_disable(i_snim_i_edge_video_system_video_ctrl_comm_disable),
	.spsel(i_snim_i_edge_video_system_video_ctrl_spsel),
	.spenable(i_snim_i_edge_video_system_video_ctrl_spenable),
	.spwrite(i_snim_i_edge_video_system_video_ctrl_spwrite),
	.spaddr(i_snim_i_edge_video_system_video_ctrl_spaddr),
	.spwdata(i_snim_i_edge_video_system_video_ctrl_spwdata),
	.spready(i_snim_i_edge_video_system_video_ctrl_spready),
	.sprdata(i_snim_i_edge_video_system_video_ctrl_sprdata),
	.spslverr(i_snim_i_edge_video_system_video_ctrl_spslverr),
	.rfni_link(i_snim_i_edge_video_system_video_ctrl_rfni_link),
	.rfni_ready(i_snim_i_edge_video_system_video_ctrl_rfni_ready),
	.rbni_link(i_snim_i_edge_video_system_video_ctrl_rbni_link),
	.rbni_ready(i_snim_i_edge_video_system_video_ctrl_rbni_ready),
	.svri_rlink(i_snim_i_edge_video_system_video_ctrl_svri_rlink),
	.svri_rack(i_snim_i_edge_video_system_video_ctrl_svri_rack),
	.svri_slink(i_snim_i_edge_video_system_video_ctrl_svri_slink),
	.svri_sack(i_snim_i_edge_video_system_video_ctrl_svri_sack)
);

MUNOC_AXI_SLAVE_NETWORK_INTERFACE_MODULE
#(
	.NODE_ID(`NODE_ID_I_SNIM_I_SYSTEM_SRAM_NO_NAME),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(128),
	.NAME("i_system_sram_no_name"),
	.BW_AXI_SLAVE_TID(`REQUIRED_BW_OF_SLAVE_TID)
)
i_snim_i_system_sram_no_name
(
	.clk(i_snim_i_system_sram_no_name_clk),
	.rstnn(i_snim_i_system_sram_no_name_rstnn),
	.comm_disable(i_snim_i_system_sram_no_name_comm_disable),
	.sxawready(i_snim_i_system_sram_no_name_sxawready),
	.sxawvalid(i_snim_i_system_sram_no_name_sxawvalid),
	.sxawaddr(i_snim_i_system_sram_no_name_sxawaddr),
	.sxawid(i_snim_i_system_sram_no_name_sxawid),
	.sxawlen(i_snim_i_system_sram_no_name_sxawlen),
	.sxawsize(i_snim_i_system_sram_no_name_sxawsize),
	.sxawburst(i_snim_i_system_sram_no_name_sxawburst),
	.sxwready(i_snim_i_system_sram_no_name_sxwready),
	.sxwvalid(i_snim_i_system_sram_no_name_sxwvalid),
	.sxwid(i_snim_i_system_sram_no_name_sxwid),
	.sxwdata(i_snim_i_system_sram_no_name_sxwdata),
	.sxwstrb(i_snim_i_system_sram_no_name_sxwstrb),
	.sxwlast(i_snim_i_system_sram_no_name_sxwlast),
	.sxbready(i_snim_i_system_sram_no_name_sxbready),
	.sxbvalid(i_snim_i_system_sram_no_name_sxbvalid),
	.sxbid(i_snim_i_system_sram_no_name_sxbid),
	.sxbresp(i_snim_i_system_sram_no_name_sxbresp),
	.sxarready(i_snim_i_system_sram_no_name_sxarready),
	.sxarvalid(i_snim_i_system_sram_no_name_sxarvalid),
	.sxaraddr(i_snim_i_system_sram_no_name_sxaraddr),
	.sxarid(i_snim_i_system_sram_no_name_sxarid),
	.sxarlen(i_snim_i_system_sram_no_name_sxarlen),
	.sxarsize(i_snim_i_system_sram_no_name_sxarsize),
	.sxarburst(i_snim_i_system_sram_no_name_sxarburst),
	.sxrready(i_snim_i_system_sram_no_name_sxrready),
	.sxrvalid(i_snim_i_system_sram_no_name_sxrvalid),
	.sxrid(i_snim_i_system_sram_no_name_sxrid),
	.sxrdata(i_snim_i_system_sram_no_name_sxrdata),
	.sxrlast(i_snim_i_system_sram_no_name_sxrlast),
	.sxrresp(i_snim_i_system_sram_no_name_sxrresp),
	.rfni_link(i_snim_i_system_sram_no_name_rfni_link),
	.rfni_ready(i_snim_i_system_sram_no_name_rfni_ready),
	.rbni_link(i_snim_i_system_sram_no_name_rbni_link),
	.rbni_ready(i_snim_i_system_sram_no_name_rbni_ready),
	.svri_rlink(i_snim_i_system_sram_no_name_svri_rlink),
	.svri_rack(i_snim_i_system_sram_no_name_svri_rack),
	.svri_slink(i_snim_i_system_sram_no_name_svri_slink),
	.svri_sack(i_snim_i_system_sram_no_name_svri_sack)
);

MUNOC_APB_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_COMMON_PERI_GROUP_NO_NAME),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("common_peri_group_no_name")
)
i_snim_common_peri_group_no_name
(
	.clk_network(i_snim_common_peri_group_no_name_clk_network),
	.rstnn_network(i_snim_common_peri_group_no_name_rstnn_network),
	.clk_slave(i_snim_common_peri_group_no_name_clk_slave),
	.rstnn_slave(i_snim_common_peri_group_no_name_rstnn_slave),
	.comm_disable(i_snim_common_peri_group_no_name_comm_disable),
	.spsel(i_snim_common_peri_group_no_name_spsel),
	.spenable(i_snim_common_peri_group_no_name_spenable),
	.spwrite(i_snim_common_peri_group_no_name_spwrite),
	.spaddr(i_snim_common_peri_group_no_name_spaddr),
	.spwdata(i_snim_common_peri_group_no_name_spwdata),
	.spready(i_snim_common_peri_group_no_name_spready),
	.sprdata(i_snim_common_peri_group_no_name_sprdata),
	.spslverr(i_snim_common_peri_group_no_name_spslverr),
	.rfni_link(i_snim_common_peri_group_no_name_rfni_link),
	.rfni_ready(i_snim_common_peri_group_no_name_rfni_ready),
	.rbni_link(i_snim_common_peri_group_no_name_rbni_link),
	.rbni_ready(i_snim_common_peri_group_no_name_rbni_ready),
	.svri_rlink(i_snim_common_peri_group_no_name_svri_rlink),
	.svri_rack(i_snim_common_peri_group_no_name_svri_rack),
	.svri_slink(i_snim_common_peri_group_no_name_svri_slink),
	.svri_sack(i_snim_common_peri_group_no_name_svri_sack)
);

MUNOC_APB_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_EXTERNAL_PERI_GROUP_NO_NAME),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("external_peri_group_no_name")
)
i_snim_external_peri_group_no_name
(
	.clk_network(i_snim_external_peri_group_no_name_clk_network),
	.rstnn_network(i_snim_external_peri_group_no_name_rstnn_network),
	.clk_slave(i_snim_external_peri_group_no_name_clk_slave),
	.rstnn_slave(i_snim_external_peri_group_no_name_rstnn_slave),
	.comm_disable(i_snim_external_peri_group_no_name_comm_disable),
	.spsel(i_snim_external_peri_group_no_name_spsel),
	.spenable(i_snim_external_peri_group_no_name_spenable),
	.spwrite(i_snim_external_peri_group_no_name_spwrite),
	.spaddr(i_snim_external_peri_group_no_name_spaddr),
	.spwdata(i_snim_external_peri_group_no_name_spwdata),
	.spready(i_snim_external_peri_group_no_name_spready),
	.sprdata(i_snim_external_peri_group_no_name_sprdata),
	.spslverr(i_snim_external_peri_group_no_name_spslverr),
	.rfni_link(i_snim_external_peri_group_no_name_rfni_link),
	.rfni_ready(i_snim_external_peri_group_no_name_rfni_ready),
	.rbni_link(i_snim_external_peri_group_no_name_rbni_link),
	.rbni_ready(i_snim_external_peri_group_no_name_rbni_ready),
	.svri_rlink(i_snim_external_peri_group_no_name_svri_rlink),
	.svri_rack(i_snim_external_peri_group_no_name_svri_rack),
	.svri_slink(i_snim_external_peri_group_no_name_svri_slink),
	.svri_sack(i_snim_external_peri_group_no_name_svri_sack)
);

MUNOC_APB_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_PLATFORM_CONTROLLER_NO_NAME),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("platform_controller_no_name")
)
i_snim_platform_controller_no_name
(
	.clk_network(i_snim_platform_controller_no_name_clk_network),
	.rstnn_network(i_snim_platform_controller_no_name_rstnn_network),
	.clk_slave(i_snim_platform_controller_no_name_clk_slave),
	.rstnn_slave(i_snim_platform_controller_no_name_rstnn_slave),
	.comm_disable(i_snim_platform_controller_no_name_comm_disable),
	.spsel(i_snim_platform_controller_no_name_spsel),
	.spenable(i_snim_platform_controller_no_name_spenable),
	.spwrite(i_snim_platform_controller_no_name_spwrite),
	.spaddr(i_snim_platform_controller_no_name_spaddr),
	.spwdata(i_snim_platform_controller_no_name_spwdata),
	.spready(i_snim_platform_controller_no_name_spready),
	.sprdata(i_snim_platform_controller_no_name_sprdata),
	.spslverr(i_snim_platform_controller_no_name_spslverr),
	.rfni_link(i_snim_platform_controller_no_name_rfni_link),
	.rfni_ready(i_snim_platform_controller_no_name_rfni_ready),
	.rbni_link(i_snim_platform_controller_no_name_rbni_link),
	.rbni_ready(i_snim_platform_controller_no_name_rbni_ready),
	.svri_rlink(i_snim_platform_controller_no_name_svri_rlink),
	.svri_rack(i_snim_platform_controller_no_name_svri_rack),
	.svri_slink(i_snim_platform_controller_no_name_svri_slink),
	.svri_sack(i_snim_platform_controller_no_name_svri_sack)
);

MUNOC_AXI_MASTER_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_MNIM_I_MAIN_CORE_INST),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("i_main_core_inst"),
	.BW_AXI_MASTER_TID(4)
)
i_mnim_i_main_core_inst
(
	.clk_network(i_mnim_i_main_core_inst_clk_network),
	.rstnn_network(i_mnim_i_main_core_inst_rstnn_network),
	.clk_master(i_mnim_i_main_core_inst_clk_master),
	.rstnn_master(i_mnim_i_main_core_inst_rstnn_master),
	.comm_disable(i_mnim_i_main_core_inst_comm_disable),
	.local_allows_holds(i_mnim_i_main_core_inst_local_allows_holds),
	.rxawready(i_mnim_i_main_core_inst_rxawready),
	.rxawvalid(i_mnim_i_main_core_inst_rxawvalid),
	.rxawaddr(i_mnim_i_main_core_inst_rxawaddr),
	.rxawid(i_mnim_i_main_core_inst_rxawid),
	.rxawlen(i_mnim_i_main_core_inst_rxawlen),
	.rxawsize(i_mnim_i_main_core_inst_rxawsize),
	.rxawburst(i_mnim_i_main_core_inst_rxawburst),
	.rxwready(i_mnim_i_main_core_inst_rxwready),
	.rxwvalid(i_mnim_i_main_core_inst_rxwvalid),
	.rxwid(i_mnim_i_main_core_inst_rxwid),
	.rxwdata(i_mnim_i_main_core_inst_rxwdata),
	.rxwstrb(i_mnim_i_main_core_inst_rxwstrb),
	.rxwlast(i_mnim_i_main_core_inst_rxwlast),
	.rxbready(i_mnim_i_main_core_inst_rxbready),
	.rxbvalid(i_mnim_i_main_core_inst_rxbvalid),
	.rxbid(i_mnim_i_main_core_inst_rxbid),
	.rxbresp(i_mnim_i_main_core_inst_rxbresp),
	.rxarready(i_mnim_i_main_core_inst_rxarready),
	.rxarvalid(i_mnim_i_main_core_inst_rxarvalid),
	.rxaraddr(i_mnim_i_main_core_inst_rxaraddr),
	.rxarid(i_mnim_i_main_core_inst_rxarid),
	.rxarlen(i_mnim_i_main_core_inst_rxarlen),
	.rxarsize(i_mnim_i_main_core_inst_rxarsize),
	.rxarburst(i_mnim_i_main_core_inst_rxarburst),
	.rxrready(i_mnim_i_main_core_inst_rxrready),
	.rxrvalid(i_mnim_i_main_core_inst_rxrvalid),
	.rxrid(i_mnim_i_main_core_inst_rxrid),
	.rxrdata(i_mnim_i_main_core_inst_rxrdata),
	.rxrlast(i_mnim_i_main_core_inst_rxrlast),
	.rxrresp(i_mnim_i_main_core_inst_rxrresp),
	.sfni_link(i_mnim_i_main_core_inst_sfni_link),
	.sfni_ready(i_mnim_i_main_core_inst_sfni_ready),
	.sbni_link(i_mnim_i_main_core_inst_sbni_link),
	.sbni_ready(i_mnim_i_main_core_inst_sbni_ready),
	.svri_rlink(i_mnim_i_main_core_inst_svri_rlink),
	.svri_rack(i_mnim_i_main_core_inst_svri_rack),
	.svri_slink(i_mnim_i_main_core_inst_svri_slink),
	.svri_sack(i_mnim_i_main_core_inst_svri_sack),
	.local_spsel(i_mnim_i_main_core_inst_local_spsel),
	.local_spenable(i_mnim_i_main_core_inst_local_spenable),
	.local_spwrite(i_mnim_i_main_core_inst_local_spwrite),
	.local_spaddr(i_mnim_i_main_core_inst_local_spaddr),
	.local_spwdata(i_mnim_i_main_core_inst_local_spwdata),
	.local_spready(i_mnim_i_main_core_inst_local_spready),
	.local_sprdata(i_mnim_i_main_core_inst_local_sprdata),
	.local_spslverr(i_mnim_i_main_core_inst_local_spslverr)
);

MUNOC_AXI_MASTER_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_MNIM_I_MAIN_CORE_DATA),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.LOCAL_ENABLE(1),
	.LOCAL_UPPER_ADDR(4'h F),
	.NAME("i_main_core_data"),
	.BW_AXI_MASTER_TID(4)
)
i_mnim_i_main_core_data
(
	.clk_network(i_mnim_i_main_core_data_clk_network),
	.rstnn_network(i_mnim_i_main_core_data_rstnn_network),
	.clk_master(i_mnim_i_main_core_data_clk_master),
	.rstnn_master(i_mnim_i_main_core_data_rstnn_master),
	.comm_disable(i_mnim_i_main_core_data_comm_disable),
	.local_allows_holds(i_mnim_i_main_core_data_local_allows_holds),
	.rxawready(i_mnim_i_main_core_data_rxawready),
	.rxawvalid(i_mnim_i_main_core_data_rxawvalid),
	.rxawaddr(i_mnim_i_main_core_data_rxawaddr),
	.rxawid(i_mnim_i_main_core_data_rxawid),
	.rxawlen(i_mnim_i_main_core_data_rxawlen),
	.rxawsize(i_mnim_i_main_core_data_rxawsize),
	.rxawburst(i_mnim_i_main_core_data_rxawburst),
	.rxwready(i_mnim_i_main_core_data_rxwready),
	.rxwvalid(i_mnim_i_main_core_data_rxwvalid),
	.rxwid(i_mnim_i_main_core_data_rxwid),
	.rxwdata(i_mnim_i_main_core_data_rxwdata),
	.rxwstrb(i_mnim_i_main_core_data_rxwstrb),
	.rxwlast(i_mnim_i_main_core_data_rxwlast),
	.rxbready(i_mnim_i_main_core_data_rxbready),
	.rxbvalid(i_mnim_i_main_core_data_rxbvalid),
	.rxbid(i_mnim_i_main_core_data_rxbid),
	.rxbresp(i_mnim_i_main_core_data_rxbresp),
	.rxarready(i_mnim_i_main_core_data_rxarready),
	.rxarvalid(i_mnim_i_main_core_data_rxarvalid),
	.rxaraddr(i_mnim_i_main_core_data_rxaraddr),
	.rxarid(i_mnim_i_main_core_data_rxarid),
	.rxarlen(i_mnim_i_main_core_data_rxarlen),
	.rxarsize(i_mnim_i_main_core_data_rxarsize),
	.rxarburst(i_mnim_i_main_core_data_rxarburst),
	.rxrready(i_mnim_i_main_core_data_rxrready),
	.rxrvalid(i_mnim_i_main_core_data_rxrvalid),
	.rxrid(i_mnim_i_main_core_data_rxrid),
	.rxrdata(i_mnim_i_main_core_data_rxrdata),
	.rxrlast(i_mnim_i_main_core_data_rxrlast),
	.rxrresp(i_mnim_i_main_core_data_rxrresp),
	.sfni_link(i_mnim_i_main_core_data_sfni_link),
	.sfni_ready(i_mnim_i_main_core_data_sfni_ready),
	.sbni_link(i_mnim_i_main_core_data_sbni_link),
	.sbni_ready(i_mnim_i_main_core_data_sbni_ready),
	.svri_rlink(i_mnim_i_main_core_data_svri_rlink),
	.svri_rack(i_mnim_i_main_core_data_svri_rack),
	.svri_slink(i_mnim_i_main_core_data_svri_slink),
	.svri_sack(i_mnim_i_main_core_data_svri_sack),
	.local_spsel(i_mnim_i_main_core_data_local_spsel),
	.local_spenable(i_mnim_i_main_core_data_local_spenable),
	.local_spwrite(i_mnim_i_main_core_data_local_spwrite),
	.local_spaddr(i_mnim_i_main_core_data_local_spaddr),
	.local_spwdata(i_mnim_i_main_core_data_local_spwdata),
	.local_spready(i_mnim_i_main_core_data_local_spready),
	.local_sprdata(i_mnim_i_main_core_data_local_sprdata),
	.local_spslverr(i_mnim_i_main_core_data_local_spslverr)
);

MUNOC_AXI_MASTER_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_MNIM_I_EDGE_VIDEO_SYSTEM_VDMA),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(128),
	.NAME("i_edge_video_system_vdma"),
	.BW_AXI_MASTER_TID(4)
)
i_mnim_i_edge_video_system_vdma
(
	.clk_network(i_mnim_i_edge_video_system_vdma_clk_network),
	.rstnn_network(i_mnim_i_edge_video_system_vdma_rstnn_network),
	.clk_master(i_mnim_i_edge_video_system_vdma_clk_master),
	.rstnn_master(i_mnim_i_edge_video_system_vdma_rstnn_master),
	.comm_disable(i_mnim_i_edge_video_system_vdma_comm_disable),
	.local_allows_holds(i_mnim_i_edge_video_system_vdma_local_allows_holds),
	.rxawready(i_mnim_i_edge_video_system_vdma_rxawready),
	.rxawvalid(i_mnim_i_edge_video_system_vdma_rxawvalid),
	.rxawaddr(i_mnim_i_edge_video_system_vdma_rxawaddr),
	.rxawid(i_mnim_i_edge_video_system_vdma_rxawid),
	.rxawlen(i_mnim_i_edge_video_system_vdma_rxawlen),
	.rxawsize(i_mnim_i_edge_video_system_vdma_rxawsize),
	.rxawburst(i_mnim_i_edge_video_system_vdma_rxawburst),
	.rxwready(i_mnim_i_edge_video_system_vdma_rxwready),
	.rxwvalid(i_mnim_i_edge_video_system_vdma_rxwvalid),
	.rxwid(i_mnim_i_edge_video_system_vdma_rxwid),
	.rxwdata(i_mnim_i_edge_video_system_vdma_rxwdata),
	.rxwstrb(i_mnim_i_edge_video_system_vdma_rxwstrb),
	.rxwlast(i_mnim_i_edge_video_system_vdma_rxwlast),
	.rxbready(i_mnim_i_edge_video_system_vdma_rxbready),
	.rxbvalid(i_mnim_i_edge_video_system_vdma_rxbvalid),
	.rxbid(i_mnim_i_edge_video_system_vdma_rxbid),
	.rxbresp(i_mnim_i_edge_video_system_vdma_rxbresp),
	.rxarready(i_mnim_i_edge_video_system_vdma_rxarready),
	.rxarvalid(i_mnim_i_edge_video_system_vdma_rxarvalid),
	.rxaraddr(i_mnim_i_edge_video_system_vdma_rxaraddr),
	.rxarid(i_mnim_i_edge_video_system_vdma_rxarid),
	.rxarlen(i_mnim_i_edge_video_system_vdma_rxarlen),
	.rxarsize(i_mnim_i_edge_video_system_vdma_rxarsize),
	.rxarburst(i_mnim_i_edge_video_system_vdma_rxarburst),
	.rxrready(i_mnim_i_edge_video_system_vdma_rxrready),
	.rxrvalid(i_mnim_i_edge_video_system_vdma_rxrvalid),
	.rxrid(i_mnim_i_edge_video_system_vdma_rxrid),
	.rxrdata(i_mnim_i_edge_video_system_vdma_rxrdata),
	.rxrlast(i_mnim_i_edge_video_system_vdma_rxrlast),
	.rxrresp(i_mnim_i_edge_video_system_vdma_rxrresp),
	.sfni_link(i_mnim_i_edge_video_system_vdma_sfni_link),
	.sfni_ready(i_mnim_i_edge_video_system_vdma_sfni_ready),
	.sbni_link(i_mnim_i_edge_video_system_vdma_sbni_link),
	.sbni_ready(i_mnim_i_edge_video_system_vdma_sbni_ready),
	.svri_rlink(i_mnim_i_edge_video_system_vdma_svri_rlink),
	.svri_rack(i_mnim_i_edge_video_system_vdma_svri_rack),
	.svri_slink(i_mnim_i_edge_video_system_vdma_svri_slink),
	.svri_sack(i_mnim_i_edge_video_system_vdma_svri_sack),
	.local_spsel(i_mnim_i_edge_video_system_vdma_local_spsel),
	.local_spenable(i_mnim_i_edge_video_system_vdma_local_spenable),
	.local_spwrite(i_mnim_i_edge_video_system_vdma_local_spwrite),
	.local_spaddr(i_mnim_i_edge_video_system_vdma_local_spaddr),
	.local_spwdata(i_mnim_i_edge_video_system_vdma_local_spwdata),
	.local_spready(i_mnim_i_edge_video_system_vdma_local_spready),
	.local_sprdata(i_mnim_i_edge_video_system_vdma_local_sprdata),
	.local_spslverr(i_mnim_i_edge_video_system_vdma_local_spslverr)
);

MUNOC_AXI_MASTER_NETWORK_INTERFACE_MODULE
#(
	.NODE_ID(`NODE_ID_I_MNIM_I_EDGE_VIDEO_SYSTEM_VIM),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(128),
	.NAME("i_edge_video_system_vim"),
	.BW_AXI_MASTER_TID(4)
)
i_mnim_i_edge_video_system_vim
(
	.clk(i_mnim_i_edge_video_system_vim_clk),
	.rstnn(i_mnim_i_edge_video_system_vim_rstnn),
	.comm_disable(i_mnim_i_edge_video_system_vim_comm_disable),
	.local_allows_holds(i_mnim_i_edge_video_system_vim_local_allows_holds),
	.rxawready(i_mnim_i_edge_video_system_vim_rxawready),
	.rxawvalid(i_mnim_i_edge_video_system_vim_rxawvalid),
	.rxawaddr(i_mnim_i_edge_video_system_vim_rxawaddr),
	.rxawid(i_mnim_i_edge_video_system_vim_rxawid),
	.rxawlen(i_mnim_i_edge_video_system_vim_rxawlen),
	.rxawsize(i_mnim_i_edge_video_system_vim_rxawsize),
	.rxawburst(i_mnim_i_edge_video_system_vim_rxawburst),
	.rxwready(i_mnim_i_edge_video_system_vim_rxwready),
	.rxwvalid(i_mnim_i_edge_video_system_vim_rxwvalid),
	.rxwid(i_mnim_i_edge_video_system_vim_rxwid),
	.rxwdata(i_mnim_i_edge_video_system_vim_rxwdata),
	.rxwstrb(i_mnim_i_edge_video_system_vim_rxwstrb),
	.rxwlast(i_mnim_i_edge_video_system_vim_rxwlast),
	.rxbready(i_mnim_i_edge_video_system_vim_rxbready),
	.rxbvalid(i_mnim_i_edge_video_system_vim_rxbvalid),
	.rxbid(i_mnim_i_edge_video_system_vim_rxbid),
	.rxbresp(i_mnim_i_edge_video_system_vim_rxbresp),
	.rxarready(i_mnim_i_edge_video_system_vim_rxarready),
	.rxarvalid(i_mnim_i_edge_video_system_vim_rxarvalid),
	.rxaraddr(i_mnim_i_edge_video_system_vim_rxaraddr),
	.rxarid(i_mnim_i_edge_video_system_vim_rxarid),
	.rxarlen(i_mnim_i_edge_video_system_vim_rxarlen),
	.rxarsize(i_mnim_i_edge_video_system_vim_rxarsize),
	.rxarburst(i_mnim_i_edge_video_system_vim_rxarburst),
	.rxrready(i_mnim_i_edge_video_system_vim_rxrready),
	.rxrvalid(i_mnim_i_edge_video_system_vim_rxrvalid),
	.rxrid(i_mnim_i_edge_video_system_vim_rxrid),
	.rxrdata(i_mnim_i_edge_video_system_vim_rxrdata),
	.rxrlast(i_mnim_i_edge_video_system_vim_rxrlast),
	.rxrresp(i_mnim_i_edge_video_system_vim_rxrresp),
	.sfni_link(i_mnim_i_edge_video_system_vim_sfni_link),
	.sfni_ready(i_mnim_i_edge_video_system_vim_sfni_ready),
	.sbni_link(i_mnim_i_edge_video_system_vim_sbni_link),
	.sbni_ready(i_mnim_i_edge_video_system_vim_sbni_ready),
	.svri_rlink(i_mnim_i_edge_video_system_vim_svri_rlink),
	.svri_rack(i_mnim_i_edge_video_system_vim_svri_rack),
	.svri_slink(i_mnim_i_edge_video_system_vim_svri_slink),
	.svri_sack(i_mnim_i_edge_video_system_vim_svri_sack),
	.local_spsel(i_mnim_i_edge_video_system_vim_local_spsel),
	.local_spenable(i_mnim_i_edge_video_system_vim_local_spenable),
	.local_spwrite(i_mnim_i_edge_video_system_vim_local_spwrite),
	.local_spaddr(i_mnim_i_edge_video_system_vim_local_spaddr),
	.local_spwdata(i_mnim_i_edge_video_system_vim_local_spwdata),
	.local_spready(i_mnim_i_edge_video_system_vim_local_spready),
	.local_sprdata(i_mnim_i_edge_video_system_vim_local_sprdata),
	.local_spslverr(i_mnim_i_edge_video_system_vim_local_spslverr)
);

MUNOC_AXI_MASTER_NETWORK_INTERFACE_MODULE
#(
	.NODE_ID(`NODE_ID_I_MNIM_I_EDGE_VIDEO_SYSTEM_VOM),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(128),
	.NAME("i_edge_video_system_vom"),
	.BW_AXI_MASTER_TID(4)
)
i_mnim_i_edge_video_system_vom
(
	.clk(i_mnim_i_edge_video_system_vom_clk),
	.rstnn(i_mnim_i_edge_video_system_vom_rstnn),
	.comm_disable(i_mnim_i_edge_video_system_vom_comm_disable),
	.local_allows_holds(i_mnim_i_edge_video_system_vom_local_allows_holds),
	.rxawready(i_mnim_i_edge_video_system_vom_rxawready),
	.rxawvalid(i_mnim_i_edge_video_system_vom_rxawvalid),
	.rxawaddr(i_mnim_i_edge_video_system_vom_rxawaddr),
	.rxawid(i_mnim_i_edge_video_system_vom_rxawid),
	.rxawlen(i_mnim_i_edge_video_system_vom_rxawlen),
	.rxawsize(i_mnim_i_edge_video_system_vom_rxawsize),
	.rxawburst(i_mnim_i_edge_video_system_vom_rxawburst),
	.rxwready(i_mnim_i_edge_video_system_vom_rxwready),
	.rxwvalid(i_mnim_i_edge_video_system_vom_rxwvalid),
	.rxwid(i_mnim_i_edge_video_system_vom_rxwid),
	.rxwdata(i_mnim_i_edge_video_system_vom_rxwdata),
	.rxwstrb(i_mnim_i_edge_video_system_vom_rxwstrb),
	.rxwlast(i_mnim_i_edge_video_system_vom_rxwlast),
	.rxbready(i_mnim_i_edge_video_system_vom_rxbready),
	.rxbvalid(i_mnim_i_edge_video_system_vom_rxbvalid),
	.rxbid(i_mnim_i_edge_video_system_vom_rxbid),
	.rxbresp(i_mnim_i_edge_video_system_vom_rxbresp),
	.rxarready(i_mnim_i_edge_video_system_vom_rxarready),
	.rxarvalid(i_mnim_i_edge_video_system_vom_rxarvalid),
	.rxaraddr(i_mnim_i_edge_video_system_vom_rxaraddr),
	.rxarid(i_mnim_i_edge_video_system_vom_rxarid),
	.rxarlen(i_mnim_i_edge_video_system_vom_rxarlen),
	.rxarsize(i_mnim_i_edge_video_system_vom_rxarsize),
	.rxarburst(i_mnim_i_edge_video_system_vom_rxarburst),
	.rxrready(i_mnim_i_edge_video_system_vom_rxrready),
	.rxrvalid(i_mnim_i_edge_video_system_vom_rxrvalid),
	.rxrid(i_mnim_i_edge_video_system_vom_rxrid),
	.rxrdata(i_mnim_i_edge_video_system_vom_rxrdata),
	.rxrlast(i_mnim_i_edge_video_system_vom_rxrlast),
	.rxrresp(i_mnim_i_edge_video_system_vom_rxrresp),
	.sfni_link(i_mnim_i_edge_video_system_vom_sfni_link),
	.sfni_ready(i_mnim_i_edge_video_system_vom_sfni_ready),
	.sbni_link(i_mnim_i_edge_video_system_vom_sbni_link),
	.sbni_ready(i_mnim_i_edge_video_system_vom_sbni_ready),
	.svri_rlink(i_mnim_i_edge_video_system_vom_svri_rlink),
	.svri_rack(i_mnim_i_edge_video_system_vom_svri_rack),
	.svri_slink(i_mnim_i_edge_video_system_vom_svri_slink),
	.svri_sack(i_mnim_i_edge_video_system_vom_svri_sack),
	.local_spsel(i_mnim_i_edge_video_system_vom_local_spsel),
	.local_spenable(i_mnim_i_edge_video_system_vom_local_spenable),
	.local_spwrite(i_mnim_i_edge_video_system_vom_local_spwrite),
	.local_spaddr(i_mnim_i_edge_video_system_vom_local_spaddr),
	.local_spwdata(i_mnim_i_edge_video_system_vom_local_spwdata),
	.local_spready(i_mnim_i_edge_video_system_vom_local_spready),
	.local_sprdata(i_mnim_i_edge_video_system_vom_local_sprdata),
	.local_spslverr(i_mnim_i_edge_video_system_vom_local_spslverr)
);

MUNOC_AHB_MASTER_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_MNIM_PLATFORM_CONTROLLER_MASTER),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("platform_controller_master")
)
i_mnim_platform_controller_master
(
	.clk_network(i_mnim_platform_controller_master_clk_network),
	.rstnn_network(i_mnim_platform_controller_master_rstnn_network),
	.clk_master(i_mnim_platform_controller_master_clk_master),
	.rstnn_master(i_mnim_platform_controller_master_rstnn_master),
	.comm_disable(i_mnim_platform_controller_master_comm_disable),
	.rhready(i_mnim_platform_controller_master_rhready),
	.rhaddr(i_mnim_platform_controller_master_rhaddr),
	.rhburst(i_mnim_platform_controller_master_rhburst),
	.rhmasterlock(i_mnim_platform_controller_master_rhmasterlock),
	.rhprot(i_mnim_platform_controller_master_rhprot),
	.rhsize(i_mnim_platform_controller_master_rhsize),
	.rhtrans(i_mnim_platform_controller_master_rhtrans),
	.rhwrite(i_mnim_platform_controller_master_rhwrite),
	.rhwdata(i_mnim_platform_controller_master_rhwdata),
	.rhrdata(i_mnim_platform_controller_master_rhrdata),
	.rhresp(i_mnim_platform_controller_master_rhresp),
	.sfni_link(i_mnim_platform_controller_master_sfni_link),
	.sfni_ready(i_mnim_platform_controller_master_sfni_ready),
	.sbni_link(i_mnim_platform_controller_master_sbni_link),
	.sbni_ready(i_mnim_platform_controller_master_sbni_ready),
	.svri_rlink(i_mnim_platform_controller_master_svri_rlink),
	.svri_rack(i_mnim_platform_controller_master_svri_rack),
	.svri_slink(i_mnim_platform_controller_master_svri_slink),
	.svri_sack(i_mnim_platform_controller_master_svri_sack)
);

MUNOC_AXI4_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_EMAMBA_IP_SLAVE),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("eMamba_IP_slave"),
	.BW_AXI_SLAVE_TID(1)
)
i_snim_eMamba_IP_slave
(
	.clk_network(i_snim_eMamba_IP_slave_clk_network),
	.rstnn_network(i_snim_eMamba_IP_slave_rstnn_network),
	.clk_slave(i_snim_eMamba_IP_slave_clk_slave),
	.rstnn_slave(i_snim_eMamba_IP_slave_rstnn_slave),
	.comm_disable(i_snim_eMamba_IP_slave_comm_disable),
	.sx4awready(i_snim_eMamba_IP_slave_sx4awready),
	.sx4awvalid(i_snim_eMamba_IP_slave_sx4awvalid),
	.sx4awaddr(i_snim_eMamba_IP_slave_sx4awaddr),
	.sx4awid(i_snim_eMamba_IP_slave_sx4awid),
	.sx4awlen(i_snim_eMamba_IP_slave_sx4awlen),
	.sx4awsize(i_snim_eMamba_IP_slave_sx4awsize),
	.sx4awburst(i_snim_eMamba_IP_slave_sx4awburst),
	.sx4wready(i_snim_eMamba_IP_slave_sx4wready),
	.sx4wvalid(i_snim_eMamba_IP_slave_sx4wvalid),
	.sx4wdata(i_snim_eMamba_IP_slave_sx4wdata),
	.sx4wstrb(i_snim_eMamba_IP_slave_sx4wstrb),
	.sx4wlast(i_snim_eMamba_IP_slave_sx4wlast),
	.sx4bready(i_snim_eMamba_IP_slave_sx4bready),
	.sx4bvalid(i_snim_eMamba_IP_slave_sx4bvalid),
	.sx4bid(i_snim_eMamba_IP_slave_sx4bid),
	.sx4bresp(i_snim_eMamba_IP_slave_sx4bresp),
	.sx4arready(i_snim_eMamba_IP_slave_sx4arready),
	.sx4arvalid(i_snim_eMamba_IP_slave_sx4arvalid),
	.sx4araddr(i_snim_eMamba_IP_slave_sx4araddr),
	.sx4arid(i_snim_eMamba_IP_slave_sx4arid),
	.sx4arlen(i_snim_eMamba_IP_slave_sx4arlen),
	.sx4arsize(i_snim_eMamba_IP_slave_sx4arsize),
	.sx4arburst(i_snim_eMamba_IP_slave_sx4arburst),
	.sx4rready(i_snim_eMamba_IP_slave_sx4rready),
	.sx4rvalid(i_snim_eMamba_IP_slave_sx4rvalid),
	.sx4rid(i_snim_eMamba_IP_slave_sx4rid),
	.sx4rdata(i_snim_eMamba_IP_slave_sx4rdata),
	.sx4rlast(i_snim_eMamba_IP_slave_sx4rlast),
	.sx4rresp(i_snim_eMamba_IP_slave_sx4rresp),
	.rfni_link(i_snim_eMamba_IP_slave_rfni_link),
	.rfni_ready(i_snim_eMamba_IP_slave_rfni_ready),
	.rbni_link(i_snim_eMamba_IP_slave_rbni_link),
	.rbni_ready(i_snim_eMamba_IP_slave_rbni_ready),
	.svri_rlink(i_snim_eMamba_IP_slave_svri_rlink),
	.svri_rack(i_snim_eMamba_IP_slave_svri_rack),
	.svri_slink(i_snim_eMamba_IP_slave_svri_slink),
	.svri_sack(i_snim_eMamba_IP_slave_svri_sack)
);

MUNOC_AXI_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_INPUT_BRAM_SLAVE),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("input_bram_slave"),
	.BW_AXI_SLAVE_TID(1)
)
i_snim_input_bram_slave
(
	.clk_network(i_snim_input_bram_slave_clk_network),
	.rstnn_network(i_snim_input_bram_slave_rstnn_network),
	.clk_slave(i_snim_input_bram_slave_clk_slave),
	.rstnn_slave(i_snim_input_bram_slave_rstnn_slave),
	.comm_disable(i_snim_input_bram_slave_comm_disable),
	.sxawready(i_snim_input_bram_slave_sxawready),
	.sxawvalid(i_snim_input_bram_slave_sxawvalid),
	.sxawaddr(i_snim_input_bram_slave_sxawaddr),
	.sxawid(i_snim_input_bram_slave_sxawid),
	.sxawlen(i_snim_input_bram_slave_sxawlen),
	.sxawsize(i_snim_input_bram_slave_sxawsize),
	.sxawburst(i_snim_input_bram_slave_sxawburst),
	.sxwready(i_snim_input_bram_slave_sxwready),
	.sxwvalid(i_snim_input_bram_slave_sxwvalid),
	.sxwid(i_snim_input_bram_slave_sxwid),
	.sxwdata(i_snim_input_bram_slave_sxwdata),
	.sxwstrb(i_snim_input_bram_slave_sxwstrb),
	.sxwlast(i_snim_input_bram_slave_sxwlast),
	.sxbready(i_snim_input_bram_slave_sxbready),
	.sxbvalid(i_snim_input_bram_slave_sxbvalid),
	.sxbid(i_snim_input_bram_slave_sxbid),
	.sxbresp(i_snim_input_bram_slave_sxbresp),
	.sxarready(i_snim_input_bram_slave_sxarready),
	.sxarvalid(i_snim_input_bram_slave_sxarvalid),
	.sxaraddr(i_snim_input_bram_slave_sxaraddr),
	.sxarid(i_snim_input_bram_slave_sxarid),
	.sxarlen(i_snim_input_bram_slave_sxarlen),
	.sxarsize(i_snim_input_bram_slave_sxarsize),
	.sxarburst(i_snim_input_bram_slave_sxarburst),
	.sxrready(i_snim_input_bram_slave_sxrready),
	.sxrvalid(i_snim_input_bram_slave_sxrvalid),
	.sxrid(i_snim_input_bram_slave_sxrid),
	.sxrdata(i_snim_input_bram_slave_sxrdata),
	.sxrlast(i_snim_input_bram_slave_sxrlast),
	.sxrresp(i_snim_input_bram_slave_sxrresp),
	.rfni_link(i_snim_input_bram_slave_rfni_link),
	.rfni_ready(i_snim_input_bram_slave_rfni_ready),
	.rbni_link(i_snim_input_bram_slave_rbni_link),
	.rbni_ready(i_snim_input_bram_slave_rbni_ready),
	.svri_rlink(i_snim_input_bram_slave_svri_rlink),
	.svri_rack(i_snim_input_bram_slave_svri_rack),
	.svri_slink(i_snim_input_bram_slave_svri_slink),
	.svri_sack(i_snim_input_bram_slave_svri_sack)
);

MUNOC_AXI_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_WB_BRAM_SLAVE),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("wb_bram_slave"),
	.BW_AXI_SLAVE_TID(1)
)
i_snim_wb_bram_slave
(
	.clk_network(i_snim_wb_bram_slave_clk_network),
	.rstnn_network(i_snim_wb_bram_slave_rstnn_network),
	.clk_slave(i_snim_wb_bram_slave_clk_slave),
	.rstnn_slave(i_snim_wb_bram_slave_rstnn_slave),
	.comm_disable(i_snim_wb_bram_slave_comm_disable),
	.sxawready(i_snim_wb_bram_slave_sxawready),
	.sxawvalid(i_snim_wb_bram_slave_sxawvalid),
	.sxawaddr(i_snim_wb_bram_slave_sxawaddr),
	.sxawid(i_snim_wb_bram_slave_sxawid),
	.sxawlen(i_snim_wb_bram_slave_sxawlen),
	.sxawsize(i_snim_wb_bram_slave_sxawsize),
	.sxawburst(i_snim_wb_bram_slave_sxawburst),
	.sxwready(i_snim_wb_bram_slave_sxwready),
	.sxwvalid(i_snim_wb_bram_slave_sxwvalid),
	.sxwid(i_snim_wb_bram_slave_sxwid),
	.sxwdata(i_snim_wb_bram_slave_sxwdata),
	.sxwstrb(i_snim_wb_bram_slave_sxwstrb),
	.sxwlast(i_snim_wb_bram_slave_sxwlast),
	.sxbready(i_snim_wb_bram_slave_sxbready),
	.sxbvalid(i_snim_wb_bram_slave_sxbvalid),
	.sxbid(i_snim_wb_bram_slave_sxbid),
	.sxbresp(i_snim_wb_bram_slave_sxbresp),
	.sxarready(i_snim_wb_bram_slave_sxarready),
	.sxarvalid(i_snim_wb_bram_slave_sxarvalid),
	.sxaraddr(i_snim_wb_bram_slave_sxaraddr),
	.sxarid(i_snim_wb_bram_slave_sxarid),
	.sxarlen(i_snim_wb_bram_slave_sxarlen),
	.sxarsize(i_snim_wb_bram_slave_sxarsize),
	.sxarburst(i_snim_wb_bram_slave_sxarburst),
	.sxrready(i_snim_wb_bram_slave_sxrready),
	.sxrvalid(i_snim_wb_bram_slave_sxrvalid),
	.sxrid(i_snim_wb_bram_slave_sxrid),
	.sxrdata(i_snim_wb_bram_slave_sxrdata),
	.sxrlast(i_snim_wb_bram_slave_sxrlast),
	.sxrresp(i_snim_wb_bram_slave_sxrresp),
	.rfni_link(i_snim_wb_bram_slave_rfni_link),
	.rfni_ready(i_snim_wb_bram_slave_rfni_ready),
	.rbni_link(i_snim_wb_bram_slave_rbni_link),
	.rbni_ready(i_snim_wb_bram_slave_rbni_ready),
	.svri_rlink(i_snim_wb_bram_slave_svri_rlink),
	.svri_rack(i_snim_wb_bram_slave_svri_rack),
	.svri_slink(i_snim_wb_bram_slave_svri_slink),
	.svri_sack(i_snim_wb_bram_slave_svri_sack)
);

MUNOC_AXI_SLAVE_NETWORK_INTERFACE_MODULE_ASYNCH
#(
	.NODE_ID(`NODE_ID_I_SNIM_OUTPUT_BRAM_SLAVE),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(32),
	.NAME("output_bram_slave"),
	.BW_AXI_SLAVE_TID(1)
)
i_snim_output_bram_slave
(
	.clk_network(i_snim_output_bram_slave_clk_network),
	.rstnn_network(i_snim_output_bram_slave_rstnn_network),
	.clk_slave(i_snim_output_bram_slave_clk_slave),
	.rstnn_slave(i_snim_output_bram_slave_rstnn_slave),
	.comm_disable(i_snim_output_bram_slave_comm_disable),
	.sxawready(i_snim_output_bram_slave_sxawready),
	.sxawvalid(i_snim_output_bram_slave_sxawvalid),
	.sxawaddr(i_snim_output_bram_slave_sxawaddr),
	.sxawid(i_snim_output_bram_slave_sxawid),
	.sxawlen(i_snim_output_bram_slave_sxawlen),
	.sxawsize(i_snim_output_bram_slave_sxawsize),
	.sxawburst(i_snim_output_bram_slave_sxawburst),
	.sxwready(i_snim_output_bram_slave_sxwready),
	.sxwvalid(i_snim_output_bram_slave_sxwvalid),
	.sxwid(i_snim_output_bram_slave_sxwid),
	.sxwdata(i_snim_output_bram_slave_sxwdata),
	.sxwstrb(i_snim_output_bram_slave_sxwstrb),
	.sxwlast(i_snim_output_bram_slave_sxwlast),
	.sxbready(i_snim_output_bram_slave_sxbready),
	.sxbvalid(i_snim_output_bram_slave_sxbvalid),
	.sxbid(i_snim_output_bram_slave_sxbid),
	.sxbresp(i_snim_output_bram_slave_sxbresp),
	.sxarready(i_snim_output_bram_slave_sxarready),
	.sxarvalid(i_snim_output_bram_slave_sxarvalid),
	.sxaraddr(i_snim_output_bram_slave_sxaraddr),
	.sxarid(i_snim_output_bram_slave_sxarid),
	.sxarlen(i_snim_output_bram_slave_sxarlen),
	.sxarsize(i_snim_output_bram_slave_sxarsize),
	.sxarburst(i_snim_output_bram_slave_sxarburst),
	.sxrready(i_snim_output_bram_slave_sxrready),
	.sxrvalid(i_snim_output_bram_slave_sxrvalid),
	.sxrid(i_snim_output_bram_slave_sxrid),
	.sxrdata(i_snim_output_bram_slave_sxrdata),
	.sxrlast(i_snim_output_bram_slave_sxrlast),
	.sxrresp(i_snim_output_bram_slave_sxrresp),
	.rfni_link(i_snim_output_bram_slave_rfni_link),
	.rfni_ready(i_snim_output_bram_slave_rfni_ready),
	.rbni_link(i_snim_output_bram_slave_rbni_link),
	.rbni_ready(i_snim_output_bram_slave_rbni_ready),
	.svri_rlink(i_snim_output_bram_slave_svri_rlink),
	.svri_rack(i_snim_output_bram_slave_svri_rack),
	.svri_slink(i_snim_output_bram_slave_svri_slink),
	.svri_sack(i_snim_output_bram_slave_svri_sack)
);

MUNOC_AXI_SLAVE_NETWORK_INTERFACE_MODULE
#(
	.NODE_ID(`NODE_ID_I_SNIM_I_SYSTEM_DDR_NO_NAME),
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.BW_PLATFORM_ADDR(32),
	.BW_NODE_DATA(128),
	.NAME("i_system_ddr_no_name"),
	.BW_AXI_SLAVE_TID(16)
)
i_snim_i_system_ddr_no_name
(
	.clk(i_snim_i_system_ddr_no_name_clk),
	.rstnn(i_snim_i_system_ddr_no_name_rstnn),
	.comm_disable(i_snim_i_system_ddr_no_name_comm_disable),
	.sxawready(i_snim_i_system_ddr_no_name_sxawready),
	.sxawvalid(i_snim_i_system_ddr_no_name_sxawvalid),
	.sxawaddr(i_snim_i_system_ddr_no_name_sxawaddr),
	.sxawid(i_snim_i_system_ddr_no_name_sxawid),
	.sxawlen(i_snim_i_system_ddr_no_name_sxawlen),
	.sxawsize(i_snim_i_system_ddr_no_name_sxawsize),
	.sxawburst(i_snim_i_system_ddr_no_name_sxawburst),
	.sxwready(i_snim_i_system_ddr_no_name_sxwready),
	.sxwvalid(i_snim_i_system_ddr_no_name_sxwvalid),
	.sxwid(i_snim_i_system_ddr_no_name_sxwid),
	.sxwdata(i_snim_i_system_ddr_no_name_sxwdata),
	.sxwstrb(i_snim_i_system_ddr_no_name_sxwstrb),
	.sxwlast(i_snim_i_system_ddr_no_name_sxwlast),
	.sxbready(i_snim_i_system_ddr_no_name_sxbready),
	.sxbvalid(i_snim_i_system_ddr_no_name_sxbvalid),
	.sxbid(i_snim_i_system_ddr_no_name_sxbid),
	.sxbresp(i_snim_i_system_ddr_no_name_sxbresp),
	.sxarready(i_snim_i_system_ddr_no_name_sxarready),
	.sxarvalid(i_snim_i_system_ddr_no_name_sxarvalid),
	.sxaraddr(i_snim_i_system_ddr_no_name_sxaraddr),
	.sxarid(i_snim_i_system_ddr_no_name_sxarid),
	.sxarlen(i_snim_i_system_ddr_no_name_sxarlen),
	.sxarsize(i_snim_i_system_ddr_no_name_sxarsize),
	.sxarburst(i_snim_i_system_ddr_no_name_sxarburst),
	.sxrready(i_snim_i_system_ddr_no_name_sxrready),
	.sxrvalid(i_snim_i_system_ddr_no_name_sxrvalid),
	.sxrid(i_snim_i_system_ddr_no_name_sxrid),
	.sxrdata(i_snim_i_system_ddr_no_name_sxrdata),
	.sxrlast(i_snim_i_system_ddr_no_name_sxrlast),
	.sxrresp(i_snim_i_system_ddr_no_name_sxrresp),
	.rfni_link(i_snim_i_system_ddr_no_name_rfni_link),
	.rfni_ready(i_snim_i_system_ddr_no_name_rfni_ready),
	.rbni_link(i_snim_i_system_ddr_no_name_rbni_link),
	.rbni_ready(i_snim_i_system_ddr_no_name_rbni_ready),
	.svri_rlink(i_snim_i_system_ddr_no_name_svri_rlink),
	.svri_rack(i_snim_i_system_ddr_no_name_svri_rack),
	.svri_slink(i_snim_i_system_ddr_no_name_svri_slink),
	.svri_sack(i_snim_i_system_ddr_no_name_svri_sack)
);

MUNOC_NETWORK_DUAL_ROUTER
#(
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.NUM_MASTER(1),
	.NUM_SLAVE(7),
	.ROUTER_ID(`ROUTER_ID_I_SYSTEM_ROUTER)
)
i_system_router
(
	.clk(i_system_router_clk),
	.rstnn(i_system_router_rstnn),
	.rfni_link_list(i_system_router_rfni_link_list),
	.rfni_ready_list(i_system_router_rfni_ready_list),
	.rbni_link_list(i_system_router_rbni_link_list),
	.rbni_ready_list(i_system_router_rbni_ready_list),
	.sfni_link_list(i_system_router_sfni_link_list),
	.sfni_ready_list(i_system_router_sfni_ready_list),
	.sbni_link_list(i_system_router_sbni_link_list),
	.sbni_ready_list(i_system_router_sbni_ready_list)
);

MUNOC_NETWORK_DUAL_ROUTER
#(
	.BW_FNI_PHIT(BW_FNI_PHIT),
	.BW_BNI_PHIT(BW_BNI_PHIT),
	.NUM_MASTER(6),
	.NUM_SLAVE(6),
	.ROUTER_ID(`ROUTER_ID_I_USER_ROUTER)
)
i_user_router
(
	.clk(i_user_router_clk),
	.rstnn(i_user_router_rstnn),
	.rfni_link_list(i_user_router_rfni_link_list),
	.rfni_ready_list(i_user_router_rfni_ready_list),
	.rbni_link_list(i_user_router_rbni_link_list),
	.rbni_ready_list(i_user_router_rbni_ready_list),
	.sfni_link_list(i_user_router_sfni_link_list),
	.sfni_ready_list(i_user_router_sfni_ready_list),
	.sbni_link_list(i_user_router_sbni_link_list),
	.sbni_ready_list(i_user_router_sbni_ready_list)
);

assign clk_system_external = clk_system;
assign clk_system_debug = clk_system;
assign clk_local_access = clk_core;
assign clk_process_000 = clk_core;
assign clk_noc = clk_dram_if;
assign clk_50M = clk_system;
assign gclk_core = clk_core;
assign gclk_system = clk_system;
assign gclk_system_external = clk_system_external;
assign gclk_system_debug = clk_system_debug;
assign gclk_local_access = clk_local_access;
assign gclk_process_000 = clk_process_000;
assign gclk_noc = clk_noc;
assign gclk_25M = clk_25M;
assign gclk_50M = clk_50M;
assign gclk_150M = clk_150M;
assign gclk_200M = clk_200M;
assign gclk_300M = clk_300M;
assign tick_1us = autoname_104_tick_1us;
assign tick_62d5ms = autoname_104_tick_62d5ms;
assign tick_gpio = external_peri_group_tick_gpio;
assign spi_common_sclk = external_peri_group_spi_common_sclk;
assign spi_common_sdq0 = external_peri_group_spi_common_sdq0;
assign global_rstnn = platform_controller_global_rstnn;
assign global_rstpp = platform_controller_global_rstpp;
assign rstnn_seqeunce = platform_controller_rstnn_seqeunce;
assign rstpp_seqeunce = platform_controller_rstpp_seqeunce;
assign i_system_ddr_rstnn_dram_if = rstnn_seqeunce[1];
assign i_led_rstnn = rstnn_seqeunce[1];
assign i_system_sram_rstnn = rstnn_seqeunce[1];
assign common_peri_group_rstnn = rstnn_seqeunce[1];
assign autoname_104_rstnn = rstnn_seqeunce[2];
assign autoname_105_rstnn = rstnn_seqeunce[2];
assign autoname_106_rstnn = rstnn_seqeunce[2];
assign external_peri_group_rstnn = rstnn_seqeunce[2];
assign core_peri_group_rstnn = rstnn_seqeunce[3];
assign platform_controller_rstnn = rstnn_seqeunce[3];
assign default_slave_rstnn_network = rstnn_seqeunce[3];
assign default_slave_rstnn_debug = rstnn_seqeunce[3];
assign i_edge_video_system_rstnn_noc = rstnn_seqeunce[4];
assign i_edge_video_system_rstnn_video = rstnn_seqeunce[4];
assign i_florian_000_rstnn = rstnn_seqeunce[4];
assign eMamba_IP_rstnn = rstnn_seqeunce[5];
assign input_bram_rstnn = rstnn_seqeunce[5];
assign output_bram_rstnn = rstnn_seqeunce[5];
assign wb_bram_rstnn = rstnn_seqeunce[5];
assign i_main_core_rstnn = rstnn_seqeunce[6];
assign rstnn_user = rstnn_seqeunce[3];
assign rstpp_user = rstpp_seqeunce[3];
assign clk_dram_ref = i_pll0_clk_dram_ref;
assign i_system_ddr_clk_ref = clk_dram_ref;
assign clk_dram_sys = i_pll0_clk_dram_sys;
assign i_system_ddr_clk_sys = clk_dram_sys;
assign clk_dram_if = i_system_ddr_clk_dram_if;
assign i_led_clk = gclk_system_external;
assign external_peri_group_clk = gclk_system_external;
assign i_florian_000_clk = gclk_local_access;
assign autoname_105_clk = gclk_local_access;
assign core_peri_group_clk = gclk_local_access;
assign i_edge_video_system_clk_apb = gclk_system;
assign i_edge_video_system_clk_vdma = gclk_system;
assign i_edge_video_system_clk_vimif = gclk_noc;
assign i_edge_video_system_clk_vomif = gclk_noc;
assign i_edge_video_system_clk_25M = gclk_25M;
assign i_edge_video_system_clk_50M = gclk_50M;
assign i_edge_video_system_clk_150M = gclk_150M;
assign i_edge_video_system_clk_200M = gclk_200M;
assign i_edge_video_system_clk_300M = gclk_300M;
assign clk_25M = i_pll0_clk_25M;
assign clk_system = i_pll0_clk_system;
assign common_peri_group_clk = clk_system;
assign autoname_104_clk = clk_system;
assign autoname_106_clk = clk_system;
assign platform_controller_clk = clk_system;
assign clk_core = i_pll0_clk_core;
assign clk_150M = i_pll0_clk_150M;
assign clk_200M = i_pll0_clk_200M;
assign clk_300M = i_pll0_clk_300M;
assign default_slave_clk_debug = gclk_system_debug;
assign i_main_core_clk = gclk_process_000;
assign rstnn_noc = rstnn_seqeunce[1];
assign i_system_router_rstnn = rstnn_noc;
assign i_user_router_rstnn = rstnn_noc;
assign i_system_router_clk = gclk_noc;
assign i_user_router_clk = gclk_noc;
assign i_system_sram_clk = gclk_noc;
assign default_slave_clk_network = gclk_noc;
assign i_inter_router_fifo00_clk = gclk_noc;
assign i_inter_router_fifo00_rstnn = rstnn_noc;
assign i_snim_i_edge_video_system_vdma_ctrl_clk_network = gclk_noc;
assign i_snim_i_edge_video_system_vdma_ctrl_rstnn_network = rstnn_noc;
assign i_snim_i_edge_video_system_vdma_ctrl_clk_slave = gclk_system;
assign i_snim_i_edge_video_system_vdma_ctrl_rstnn_slave = rstnn_seqeunce[4];
assign i_snim_i_edge_video_system_video_ctrl_clk_network = gclk_noc;
assign i_snim_i_edge_video_system_video_ctrl_rstnn_network = rstnn_noc;
assign i_snim_i_edge_video_system_video_ctrl_clk_slave = gclk_system;
assign i_snim_i_edge_video_system_video_ctrl_rstnn_slave = rstnn_seqeunce[4];
assign i_snim_i_system_sram_no_name_clk = gclk_noc;
assign i_snim_i_system_sram_no_name_rstnn = rstnn_noc;
assign i_snim_common_peri_group_no_name_clk_network = gclk_noc;
assign i_snim_common_peri_group_no_name_rstnn_network = rstnn_noc;
assign i_snim_common_peri_group_no_name_clk_slave = clk_system;
assign i_snim_common_peri_group_no_name_rstnn_slave = rstnn_seqeunce[1];
assign i_snim_external_peri_group_no_name_clk_network = gclk_noc;
assign i_snim_external_peri_group_no_name_rstnn_network = rstnn_noc;
assign i_snim_external_peri_group_no_name_clk_slave = gclk_system_external;
assign i_snim_external_peri_group_no_name_rstnn_slave = rstnn_seqeunce[2];
assign i_snim_platform_controller_no_name_clk_network = gclk_noc;
assign i_snim_platform_controller_no_name_rstnn_network = rstnn_noc;
assign i_snim_platform_controller_no_name_clk_slave = clk_system;
assign i_snim_platform_controller_no_name_rstnn_slave = rstnn_seqeunce[3];
assign i_mnim_i_main_core_inst_clk_network = gclk_noc;
assign i_mnim_i_main_core_inst_rstnn_network = rstnn_noc;
assign i_mnim_i_main_core_inst_clk_master = gclk_process_000;
assign i_mnim_i_main_core_inst_rstnn_master = rstnn_seqeunce[6];
assign i_mnim_i_main_core_data_clk_network = gclk_noc;
assign i_mnim_i_main_core_data_rstnn_network = rstnn_noc;
assign i_mnim_i_main_core_data_clk_master = gclk_process_000;
assign i_mnim_i_main_core_data_rstnn_master = rstnn_seqeunce[6];
assign i_mnim_i_edge_video_system_vdma_clk_network = gclk_noc;
assign i_mnim_i_edge_video_system_vdma_rstnn_network = rstnn_noc;
assign i_mnim_i_edge_video_system_vdma_clk_master = gclk_system;
assign i_mnim_i_edge_video_system_vdma_rstnn_master = rstnn_seqeunce[4];
assign i_mnim_i_edge_video_system_vim_clk = gclk_noc;
assign i_mnim_i_edge_video_system_vim_rstnn = rstnn_noc;
assign i_mnim_i_edge_video_system_vom_clk = gclk_noc;
assign i_mnim_i_edge_video_system_vom_rstnn = rstnn_noc;
assign i_mnim_platform_controller_master_clk_network = gclk_noc;
assign i_mnim_platform_controller_master_rstnn_network = rstnn_noc;
assign i_mnim_platform_controller_master_clk_master = clk_system;
assign i_mnim_platform_controller_master_rstnn_master = rstnn_seqeunce[3];
assign i_snim_eMamba_IP_slave_clk_network = gclk_noc;
assign i_snim_eMamba_IP_slave_rstnn_network = rstnn_noc;
assign i_snim_eMamba_IP_slave_clk_slave = eMamba_IP_clk;
assign i_snim_eMamba_IP_slave_rstnn_slave = rstnn_seqeunce[5];
assign i_snim_input_bram_slave_clk_network = gclk_noc;
assign i_snim_input_bram_slave_rstnn_network = rstnn_noc;
assign i_snim_input_bram_slave_clk_slave = input_bram_clk;
assign i_snim_input_bram_slave_rstnn_slave = rstnn_seqeunce[5];
assign i_snim_wb_bram_slave_clk_network = gclk_noc;
assign i_snim_wb_bram_slave_rstnn_network = rstnn_noc;
assign i_snim_wb_bram_slave_clk_slave = wb_bram_clk;
assign i_snim_wb_bram_slave_rstnn_slave = rstnn_seqeunce[5];
assign i_snim_output_bram_slave_clk_network = gclk_noc;
assign i_snim_output_bram_slave_rstnn_network = rstnn_noc;
assign i_snim_output_bram_slave_clk_slave = output_bram_clk;
assign i_snim_output_bram_slave_rstnn_slave = rstnn_seqeunce[5];
assign i_snim_i_system_ddr_no_name_clk = gclk_noc;
assign i_snim_i_system_ddr_no_name_rstnn = rstnn_noc;
assign i_system_ddr_rstnn_sys = platform_controller_global_rstnn;
assign i_edge_video_system_global_rstnn = platform_controller_global_rstnn;
assign i_pll0_external_rstnn = platform_controller_global_rstnn;
assign platform_controller_initialized = i_system_ddr_initialized;
assign i_led_tick_62d5ms = autoname_104_tick_62d5ms;
assign i_led_app_finished = platform_controller_app_finished;
assign i_edge_video_system_tick_1us = autoname_104_tick_1us;
assign autoname_106_tick_1us = autoname_104_tick_1us;
assign external_peri_group_tick_1us = autoname_104_tick_1us;
assign core_peri_group_lock_status_list = common_peri_group_lock_status_list;
assign core_peri_group_thread_status_list = common_peri_group_thread_status_list;
assign common_peri_group_real_clock = autoname_106_real_clock;
assign core_peri_group_global_tag_list = common_peri_group_global_tag_list;
assign autoname_104_tick_config = common_peri_group_system_tick_config;
assign autoname_105_tick_config = common_peri_group_core_tick_config;
assign core_peri_group_tick_1us = autoname_105_tick_1us;
assign platform_controller_external_rstnn = external_rstnn;
assign platform_controller_jtag_select = `JTAG_SELECT_NOC;
assign i_main_core_interrupt_vector = core_peri_group_core_interrupt_vector;
assign core_peri_group_allows_holds = i_mnim_i_main_core_data_local_allows_holds;
assign default_slave_comm_disable = 0;
assign i_snim_i_edge_video_system_vdma_ctrl_comm_disable = 0;
assign i_snim_i_edge_video_system_video_ctrl_comm_disable = 0;
assign i_snim_common_peri_group_no_name_comm_disable = 0;
assign i_snim_external_peri_group_no_name_comm_disable = 0;
assign i_snim_platform_controller_no_name_comm_disable = 0;
assign i_mnim_platform_controller_master_comm_disable = 0;
assign i_snim_eMamba_IP_slave_comm_disable = 0;
assign i_snim_input_bram_slave_comm_disable = 0;
assign i_snim_wb_bram_slave_comm_disable = 0;
assign i_snim_output_bram_slave_comm_disable = 0;
assign core_peri_group_plic_interrupt = 0;
assign platform_controller_boot_mode = 0;
assign i_snim_i_system_sram_no_name_comm_disable = 0;
assign i_mnim_i_edge_video_system_vim_comm_disable = 0;
assign i_mnim_i_edge_video_system_vom_comm_disable = 0;
assign i_mnim_i_main_core_inst_comm_disable = 0;
assign i_mnim_i_main_core_data_comm_disable = 0;
assign i_mnim_i_edge_video_system_vdma_comm_disable = 0;
assign i_snim_i_system_ddr_no_name_comm_disable = 0;
assign led_list[1*(0+1)-1 -:1] = i_led_led_list[1*(0+1)-1 -:1];
assign i_edge_video_system_vdma_ctrl_rpsel = i_snim_i_edge_video_system_vdma_ctrl_spsel;
assign i_edge_video_system_vdma_ctrl_rpenable = i_snim_i_edge_video_system_vdma_ctrl_spenable;
assign i_edge_video_system_vdma_ctrl_rpwrite = i_snim_i_edge_video_system_vdma_ctrl_spwrite;
assign i_edge_video_system_vdma_ctrl_rpaddr = i_snim_i_edge_video_system_vdma_ctrl_spaddr;
assign i_edge_video_system_vdma_ctrl_rpwdata = i_snim_i_edge_video_system_vdma_ctrl_spwdata;
assign i_snim_i_edge_video_system_vdma_ctrl_spready = i_edge_video_system_vdma_ctrl_rpready;
assign i_snim_i_edge_video_system_vdma_ctrl_sprdata = i_edge_video_system_vdma_ctrl_rprdata;
assign i_snim_i_edge_video_system_vdma_ctrl_spslverr = i_edge_video_system_vdma_ctrl_rpslverr;
assign i_edge_video_system_video_ctrl_rpsel = i_snim_i_edge_video_system_video_ctrl_spsel;
assign i_edge_video_system_video_ctrl_rpenable = i_snim_i_edge_video_system_video_ctrl_spenable;
assign i_edge_video_system_video_ctrl_rpwrite = i_snim_i_edge_video_system_video_ctrl_spwrite;
assign i_edge_video_system_video_ctrl_rpaddr = i_snim_i_edge_video_system_video_ctrl_spaddr;
assign i_edge_video_system_video_ctrl_rpwdata = i_snim_i_edge_video_system_video_ctrl_spwdata;
assign i_snim_i_edge_video_system_video_ctrl_spready = i_edge_video_system_video_ctrl_rpready;
assign i_snim_i_edge_video_system_video_ctrl_sprdata = i_edge_video_system_video_ctrl_rprdata;
assign i_snim_i_edge_video_system_video_ctrl_spslverr = i_edge_video_system_video_ctrl_rpslverr;
assign i_snim_i_system_sram_no_name_sxawready = i_system_sram_sxawready;
assign i_system_sram_sxawvalid = i_snim_i_system_sram_no_name_sxawvalid;
assign i_system_sram_sxawaddr = i_snim_i_system_sram_no_name_sxawaddr;
assign i_system_sram_sxawid = i_snim_i_system_sram_no_name_sxawid;
assign i_system_sram_sxawlen = i_snim_i_system_sram_no_name_sxawlen;
assign i_system_sram_sxawsize = i_snim_i_system_sram_no_name_sxawsize;
assign i_system_sram_sxawburst = i_snim_i_system_sram_no_name_sxawburst;
assign i_snim_i_system_sram_no_name_sxwready = i_system_sram_sxwready;
assign i_system_sram_sxwvalid = i_snim_i_system_sram_no_name_sxwvalid;
assign i_system_sram_sxwid = i_snim_i_system_sram_no_name_sxwid;
assign i_system_sram_sxwdata = i_snim_i_system_sram_no_name_sxwdata;
assign i_system_sram_sxwstrb = i_snim_i_system_sram_no_name_sxwstrb;
assign i_system_sram_sxwlast = i_snim_i_system_sram_no_name_sxwlast;
assign i_system_sram_sxbready = i_snim_i_system_sram_no_name_sxbready;
assign i_snim_i_system_sram_no_name_sxbvalid = i_system_sram_sxbvalid;
assign i_snim_i_system_sram_no_name_sxbid = i_system_sram_sxbid;
assign i_snim_i_system_sram_no_name_sxbresp = i_system_sram_sxbresp;
assign i_snim_i_system_sram_no_name_sxarready = i_system_sram_sxarready;
assign i_system_sram_sxarvalid = i_snim_i_system_sram_no_name_sxarvalid;
assign i_system_sram_sxaraddr = i_snim_i_system_sram_no_name_sxaraddr;
assign i_system_sram_sxarid = i_snim_i_system_sram_no_name_sxarid;
assign i_system_sram_sxarlen = i_snim_i_system_sram_no_name_sxarlen;
assign i_system_sram_sxarsize = i_snim_i_system_sram_no_name_sxarsize;
assign i_system_sram_sxarburst = i_snim_i_system_sram_no_name_sxarburst;
assign i_system_sram_sxrready = i_snim_i_system_sram_no_name_sxrready;
assign i_snim_i_system_sram_no_name_sxrvalid = i_system_sram_sxrvalid;
assign i_snim_i_system_sram_no_name_sxrid = i_system_sram_sxrid;
assign i_snim_i_system_sram_no_name_sxrdata = i_system_sram_sxrdata;
assign i_snim_i_system_sram_no_name_sxrlast = i_system_sram_sxrlast;
assign i_snim_i_system_sram_no_name_sxrresp = i_system_sram_sxrresp;
assign common_peri_group_rpsel = i_snim_common_peri_group_no_name_spsel;
assign common_peri_group_rpenable = i_snim_common_peri_group_no_name_spenable;
assign common_peri_group_rpwrite = i_snim_common_peri_group_no_name_spwrite;
assign common_peri_group_rpaddr = i_snim_common_peri_group_no_name_spaddr;
assign common_peri_group_rpwdata = i_snim_common_peri_group_no_name_spwdata;
assign i_snim_common_peri_group_no_name_spready = common_peri_group_rpready;
assign i_snim_common_peri_group_no_name_sprdata = common_peri_group_rprdata;
assign i_snim_common_peri_group_no_name_spslverr = common_peri_group_rpslverr;
assign external_peri_group_rpsel = i_snim_external_peri_group_no_name_spsel;
assign external_peri_group_rpenable = i_snim_external_peri_group_no_name_spenable;
assign external_peri_group_rpwrite = i_snim_external_peri_group_no_name_spwrite;
assign external_peri_group_rpaddr = i_snim_external_peri_group_no_name_spaddr;
assign external_peri_group_rpwdata = i_snim_external_peri_group_no_name_spwdata;
assign i_snim_external_peri_group_no_name_spready = external_peri_group_rpready;
assign i_snim_external_peri_group_no_name_sprdata = external_peri_group_rprdata;
assign i_snim_external_peri_group_no_name_spslverr = external_peri_group_rpslverr;
assign platform_controller_rpsel = i_snim_platform_controller_no_name_spsel;
assign platform_controller_rpenable = i_snim_platform_controller_no_name_spenable;
assign platform_controller_rpwrite = i_snim_platform_controller_no_name_spwrite;
assign platform_controller_rpaddr = i_snim_platform_controller_no_name_spaddr;
assign platform_controller_rpwdata = i_snim_platform_controller_no_name_spwdata;
assign i_snim_platform_controller_no_name_spready = platform_controller_rpready;
assign i_snim_platform_controller_no_name_sprdata = platform_controller_rprdata;
assign i_snim_platform_controller_no_name_spslverr = platform_controller_rpslverr;
assign i_main_core_inst_sxawready = i_mnim_i_main_core_inst_rxawready;
assign i_mnim_i_main_core_inst_rxawvalid = i_main_core_inst_sxawvalid;
assign i_mnim_i_main_core_inst_rxawaddr = i_main_core_inst_sxawaddr;
assign i_mnim_i_main_core_inst_rxawid = i_main_core_inst_sxawid;
assign i_mnim_i_main_core_inst_rxawlen = i_main_core_inst_sxawlen;
assign i_mnim_i_main_core_inst_rxawsize = i_main_core_inst_sxawsize;
assign i_mnim_i_main_core_inst_rxawburst = i_main_core_inst_sxawburst;
assign i_main_core_inst_sxwready = i_mnim_i_main_core_inst_rxwready;
assign i_mnim_i_main_core_inst_rxwvalid = i_main_core_inst_sxwvalid;
assign i_mnim_i_main_core_inst_rxwid = i_main_core_inst_sxwid;
assign i_mnim_i_main_core_inst_rxwdata = i_main_core_inst_sxwdata;
assign i_mnim_i_main_core_inst_rxwstrb = i_main_core_inst_sxwstrb;
assign i_mnim_i_main_core_inst_rxwlast = i_main_core_inst_sxwlast;
assign i_mnim_i_main_core_inst_rxbready = i_main_core_inst_sxbready;
assign i_main_core_inst_sxbvalid = i_mnim_i_main_core_inst_rxbvalid;
assign i_main_core_inst_sxbid = i_mnim_i_main_core_inst_rxbid;
assign i_main_core_inst_sxbresp = i_mnim_i_main_core_inst_rxbresp;
assign i_main_core_inst_sxarready = i_mnim_i_main_core_inst_rxarready;
assign i_mnim_i_main_core_inst_rxarvalid = i_main_core_inst_sxarvalid;
assign i_mnim_i_main_core_inst_rxaraddr = i_main_core_inst_sxaraddr;
assign i_mnim_i_main_core_inst_rxarid = i_main_core_inst_sxarid;
assign i_mnim_i_main_core_inst_rxarlen = i_main_core_inst_sxarlen;
assign i_mnim_i_main_core_inst_rxarsize = i_main_core_inst_sxarsize;
assign i_mnim_i_main_core_inst_rxarburst = i_main_core_inst_sxarburst;
assign i_mnim_i_main_core_inst_rxrready = i_main_core_inst_sxrready;
assign i_main_core_inst_sxrvalid = i_mnim_i_main_core_inst_rxrvalid;
assign i_main_core_inst_sxrid = i_mnim_i_main_core_inst_rxrid;
assign i_main_core_inst_sxrdata = i_mnim_i_main_core_inst_rxrdata;
assign i_main_core_inst_sxrlast = i_mnim_i_main_core_inst_rxrlast;
assign i_main_core_inst_sxrresp = i_mnim_i_main_core_inst_rxrresp;
assign i_main_core_data_sxawready = i_mnim_i_main_core_data_rxawready;
assign i_mnim_i_main_core_data_rxawvalid = i_main_core_data_sxawvalid;
assign i_mnim_i_main_core_data_rxawaddr = i_main_core_data_sxawaddr;
assign i_mnim_i_main_core_data_rxawid = i_main_core_data_sxawid;
assign i_mnim_i_main_core_data_rxawlen = i_main_core_data_sxawlen;
assign i_mnim_i_main_core_data_rxawsize = i_main_core_data_sxawsize;
assign i_mnim_i_main_core_data_rxawburst = i_main_core_data_sxawburst;
assign i_main_core_data_sxwready = i_mnim_i_main_core_data_rxwready;
assign i_mnim_i_main_core_data_rxwvalid = i_main_core_data_sxwvalid;
assign i_mnim_i_main_core_data_rxwid = i_main_core_data_sxwid;
assign i_mnim_i_main_core_data_rxwdata = i_main_core_data_sxwdata;
assign i_mnim_i_main_core_data_rxwstrb = i_main_core_data_sxwstrb;
assign i_mnim_i_main_core_data_rxwlast = i_main_core_data_sxwlast;
assign i_mnim_i_main_core_data_rxbready = i_main_core_data_sxbready;
assign i_main_core_data_sxbvalid = i_mnim_i_main_core_data_rxbvalid;
assign i_main_core_data_sxbid = i_mnim_i_main_core_data_rxbid;
assign i_main_core_data_sxbresp = i_mnim_i_main_core_data_rxbresp;
assign i_main_core_data_sxarready = i_mnim_i_main_core_data_rxarready;
assign i_mnim_i_main_core_data_rxarvalid = i_main_core_data_sxarvalid;
assign i_mnim_i_main_core_data_rxaraddr = i_main_core_data_sxaraddr;
assign i_mnim_i_main_core_data_rxarid = i_main_core_data_sxarid;
assign i_mnim_i_main_core_data_rxarlen = i_main_core_data_sxarlen;
assign i_mnim_i_main_core_data_rxarsize = i_main_core_data_sxarsize;
assign i_mnim_i_main_core_data_rxarburst = i_main_core_data_sxarburst;
assign i_mnim_i_main_core_data_rxrready = i_main_core_data_sxrready;
assign i_main_core_data_sxrvalid = i_mnim_i_main_core_data_rxrvalid;
assign i_main_core_data_sxrid = i_mnim_i_main_core_data_rxrid;
assign i_main_core_data_sxrdata = i_mnim_i_main_core_data_rxrdata;
assign i_main_core_data_sxrlast = i_mnim_i_main_core_data_rxrlast;
assign i_main_core_data_sxrresp = i_mnim_i_main_core_data_rxrresp;
assign i_edge_video_system_vdma_sxawready = i_mnim_i_edge_video_system_vdma_rxawready;
assign i_mnim_i_edge_video_system_vdma_rxawvalid = i_edge_video_system_vdma_sxawvalid;
assign i_mnim_i_edge_video_system_vdma_rxawaddr = i_edge_video_system_vdma_sxawaddr;
assign i_mnim_i_edge_video_system_vdma_rxawid = i_edge_video_system_vdma_sxawid;
assign i_mnim_i_edge_video_system_vdma_rxawlen = i_edge_video_system_vdma_sxawlen;
assign i_mnim_i_edge_video_system_vdma_rxawsize = i_edge_video_system_vdma_sxawsize;
assign i_mnim_i_edge_video_system_vdma_rxawburst = i_edge_video_system_vdma_sxawburst;
assign i_edge_video_system_vdma_sxwready = i_mnim_i_edge_video_system_vdma_rxwready;
assign i_mnim_i_edge_video_system_vdma_rxwvalid = i_edge_video_system_vdma_sxwvalid;
assign i_mnim_i_edge_video_system_vdma_rxwid = i_edge_video_system_vdma_sxwid;
assign i_mnim_i_edge_video_system_vdma_rxwdata = i_edge_video_system_vdma_sxwdata;
assign i_mnim_i_edge_video_system_vdma_rxwstrb = i_edge_video_system_vdma_sxwstrb;
assign i_mnim_i_edge_video_system_vdma_rxwlast = i_edge_video_system_vdma_sxwlast;
assign i_mnim_i_edge_video_system_vdma_rxbready = i_edge_video_system_vdma_sxbready;
assign i_edge_video_system_vdma_sxbvalid = i_mnim_i_edge_video_system_vdma_rxbvalid;
assign i_edge_video_system_vdma_sxbid = i_mnim_i_edge_video_system_vdma_rxbid;
assign i_edge_video_system_vdma_sxbresp = i_mnim_i_edge_video_system_vdma_rxbresp;
assign i_edge_video_system_vdma_sxarready = i_mnim_i_edge_video_system_vdma_rxarready;
assign i_mnim_i_edge_video_system_vdma_rxarvalid = i_edge_video_system_vdma_sxarvalid;
assign i_mnim_i_edge_video_system_vdma_rxaraddr = i_edge_video_system_vdma_sxaraddr;
assign i_mnim_i_edge_video_system_vdma_rxarid = i_edge_video_system_vdma_sxarid;
assign i_mnim_i_edge_video_system_vdma_rxarlen = i_edge_video_system_vdma_sxarlen;
assign i_mnim_i_edge_video_system_vdma_rxarsize = i_edge_video_system_vdma_sxarsize;
assign i_mnim_i_edge_video_system_vdma_rxarburst = i_edge_video_system_vdma_sxarburst;
assign i_mnim_i_edge_video_system_vdma_rxrready = i_edge_video_system_vdma_sxrready;
assign i_edge_video_system_vdma_sxrvalid = i_mnim_i_edge_video_system_vdma_rxrvalid;
assign i_edge_video_system_vdma_sxrid = i_mnim_i_edge_video_system_vdma_rxrid;
assign i_edge_video_system_vdma_sxrdata = i_mnim_i_edge_video_system_vdma_rxrdata;
assign i_edge_video_system_vdma_sxrlast = i_mnim_i_edge_video_system_vdma_rxrlast;
assign i_edge_video_system_vdma_sxrresp = i_mnim_i_edge_video_system_vdma_rxrresp;
assign i_edge_video_system_vim_sxawready = i_mnim_i_edge_video_system_vim_rxawready;
assign i_mnim_i_edge_video_system_vim_rxawvalid = i_edge_video_system_vim_sxawvalid;
assign i_mnim_i_edge_video_system_vim_rxawaddr = i_edge_video_system_vim_sxawaddr;
assign i_mnim_i_edge_video_system_vim_rxawid = i_edge_video_system_vim_sxawid;
assign i_mnim_i_edge_video_system_vim_rxawlen = i_edge_video_system_vim_sxawlen;
assign i_mnim_i_edge_video_system_vim_rxawsize = i_edge_video_system_vim_sxawsize;
assign i_mnim_i_edge_video_system_vim_rxawburst = i_edge_video_system_vim_sxawburst;
assign i_edge_video_system_vim_sxwready = i_mnim_i_edge_video_system_vim_rxwready;
assign i_mnim_i_edge_video_system_vim_rxwvalid = i_edge_video_system_vim_sxwvalid;
assign i_mnim_i_edge_video_system_vim_rxwid = i_edge_video_system_vim_sxwid;
assign i_mnim_i_edge_video_system_vim_rxwdata = i_edge_video_system_vim_sxwdata;
assign i_mnim_i_edge_video_system_vim_rxwstrb = i_edge_video_system_vim_sxwstrb;
assign i_mnim_i_edge_video_system_vim_rxwlast = i_edge_video_system_vim_sxwlast;
assign i_mnim_i_edge_video_system_vim_rxbready = i_edge_video_system_vim_sxbready;
assign i_edge_video_system_vim_sxbvalid = i_mnim_i_edge_video_system_vim_rxbvalid;
assign i_edge_video_system_vim_sxbid = i_mnim_i_edge_video_system_vim_rxbid;
assign i_edge_video_system_vim_sxbresp = i_mnim_i_edge_video_system_vim_rxbresp;
assign i_edge_video_system_vim_sxarready = i_mnim_i_edge_video_system_vim_rxarready;
assign i_mnim_i_edge_video_system_vim_rxarvalid = i_edge_video_system_vim_sxarvalid;
assign i_mnim_i_edge_video_system_vim_rxaraddr = i_edge_video_system_vim_sxaraddr;
assign i_mnim_i_edge_video_system_vim_rxarid = i_edge_video_system_vim_sxarid;
assign i_mnim_i_edge_video_system_vim_rxarlen = i_edge_video_system_vim_sxarlen;
assign i_mnim_i_edge_video_system_vim_rxarsize = i_edge_video_system_vim_sxarsize;
assign i_mnim_i_edge_video_system_vim_rxarburst = i_edge_video_system_vim_sxarburst;
assign i_mnim_i_edge_video_system_vim_rxrready = i_edge_video_system_vim_sxrready;
assign i_edge_video_system_vim_sxrvalid = i_mnim_i_edge_video_system_vim_rxrvalid;
assign i_edge_video_system_vim_sxrid = i_mnim_i_edge_video_system_vim_rxrid;
assign i_edge_video_system_vim_sxrdata = i_mnim_i_edge_video_system_vim_rxrdata;
assign i_edge_video_system_vim_sxrlast = i_mnim_i_edge_video_system_vim_rxrlast;
assign i_edge_video_system_vim_sxrresp = i_mnim_i_edge_video_system_vim_rxrresp;
assign i_edge_video_system_vom_sxawready = i_mnim_i_edge_video_system_vom_rxawready;
assign i_mnim_i_edge_video_system_vom_rxawvalid = i_edge_video_system_vom_sxawvalid;
assign i_mnim_i_edge_video_system_vom_rxawaddr = i_edge_video_system_vom_sxawaddr;
assign i_mnim_i_edge_video_system_vom_rxawid = i_edge_video_system_vom_sxawid;
assign i_mnim_i_edge_video_system_vom_rxawlen = i_edge_video_system_vom_sxawlen;
assign i_mnim_i_edge_video_system_vom_rxawsize = i_edge_video_system_vom_sxawsize;
assign i_mnim_i_edge_video_system_vom_rxawburst = i_edge_video_system_vom_sxawburst;
assign i_edge_video_system_vom_sxwready = i_mnim_i_edge_video_system_vom_rxwready;
assign i_mnim_i_edge_video_system_vom_rxwvalid = i_edge_video_system_vom_sxwvalid;
assign i_mnim_i_edge_video_system_vom_rxwid = i_edge_video_system_vom_sxwid;
assign i_mnim_i_edge_video_system_vom_rxwdata = i_edge_video_system_vom_sxwdata;
assign i_mnim_i_edge_video_system_vom_rxwstrb = i_edge_video_system_vom_sxwstrb;
assign i_mnim_i_edge_video_system_vom_rxwlast = i_edge_video_system_vom_sxwlast;
assign i_mnim_i_edge_video_system_vom_rxbready = i_edge_video_system_vom_sxbready;
assign i_edge_video_system_vom_sxbvalid = i_mnim_i_edge_video_system_vom_rxbvalid;
assign i_edge_video_system_vom_sxbid = i_mnim_i_edge_video_system_vom_rxbid;
assign i_edge_video_system_vom_sxbresp = i_mnim_i_edge_video_system_vom_rxbresp;
assign i_edge_video_system_vom_sxarready = i_mnim_i_edge_video_system_vom_rxarready;
assign i_mnim_i_edge_video_system_vom_rxarvalid = i_edge_video_system_vom_sxarvalid;
assign i_mnim_i_edge_video_system_vom_rxaraddr = i_edge_video_system_vom_sxaraddr;
assign i_mnim_i_edge_video_system_vom_rxarid = i_edge_video_system_vom_sxarid;
assign i_mnim_i_edge_video_system_vom_rxarlen = i_edge_video_system_vom_sxarlen;
assign i_mnim_i_edge_video_system_vom_rxarsize = i_edge_video_system_vom_sxarsize;
assign i_mnim_i_edge_video_system_vom_rxarburst = i_edge_video_system_vom_sxarburst;
assign i_mnim_i_edge_video_system_vom_rxrready = i_edge_video_system_vom_sxrready;
assign i_edge_video_system_vom_sxrvalid = i_mnim_i_edge_video_system_vom_rxrvalid;
assign i_edge_video_system_vom_sxrid = i_mnim_i_edge_video_system_vom_rxrid;
assign i_edge_video_system_vom_sxrdata = i_mnim_i_edge_video_system_vom_rxrdata;
assign i_edge_video_system_vom_sxrlast = i_mnim_i_edge_video_system_vom_rxrlast;
assign i_edge_video_system_vom_sxrresp = i_mnim_i_edge_video_system_vom_rxrresp;
assign platform_controller_shready = i_mnim_platform_controller_master_rhready;
assign i_mnim_platform_controller_master_rhaddr = platform_controller_shaddr;
assign i_mnim_platform_controller_master_rhburst = platform_controller_shburst;
assign i_mnim_platform_controller_master_rhmasterlock = platform_controller_shmasterlock;
assign i_mnim_platform_controller_master_rhprot = platform_controller_shprot;
assign i_mnim_platform_controller_master_rhsize = platform_controller_shsize;
assign i_mnim_platform_controller_master_rhtrans = platform_controller_shtrans;
assign i_mnim_platform_controller_master_rhwrite = platform_controller_shwrite;
assign i_mnim_platform_controller_master_rhwdata = platform_controller_shwdata;
assign platform_controller_shrdata = i_mnim_platform_controller_master_rhrdata;
assign platform_controller_shresp = i_mnim_platform_controller_master_rhresp;
assign i_snim_eMamba_IP_slave_sx4awready = eMamba_IP_sx4awready;
assign eMamba_IP_sx4awvalid = i_snim_eMamba_IP_slave_sx4awvalid;
assign eMamba_IP_sx4awaddr = i_snim_eMamba_IP_slave_sx4awaddr;
assign eMamba_IP_sx4awid = i_snim_eMamba_IP_slave_sx4awid;
assign eMamba_IP_sx4awlen = i_snim_eMamba_IP_slave_sx4awlen;
assign eMamba_IP_sx4awsize = i_snim_eMamba_IP_slave_sx4awsize;
assign eMamba_IP_sx4awburst = i_snim_eMamba_IP_slave_sx4awburst;
assign i_snim_eMamba_IP_slave_sx4wready = eMamba_IP_sx4wready;
assign eMamba_IP_sx4wvalid = i_snim_eMamba_IP_slave_sx4wvalid;
assign eMamba_IP_sx4wdata = i_snim_eMamba_IP_slave_sx4wdata;
assign eMamba_IP_sx4wstrb = i_snim_eMamba_IP_slave_sx4wstrb;
assign eMamba_IP_sx4wlast = i_snim_eMamba_IP_slave_sx4wlast;
assign eMamba_IP_sx4bready = i_snim_eMamba_IP_slave_sx4bready;
assign i_snim_eMamba_IP_slave_sx4bvalid = eMamba_IP_sx4bvalid;
assign i_snim_eMamba_IP_slave_sx4bid = eMamba_IP_sx4bid;
assign i_snim_eMamba_IP_slave_sx4bresp = eMamba_IP_sx4bresp;
assign i_snim_eMamba_IP_slave_sx4arready = eMamba_IP_sx4arready;
assign eMamba_IP_sx4arvalid = i_snim_eMamba_IP_slave_sx4arvalid;
assign eMamba_IP_sx4araddr = i_snim_eMamba_IP_slave_sx4araddr;
assign eMamba_IP_sx4arid = i_snim_eMamba_IP_slave_sx4arid;
assign eMamba_IP_sx4arlen = i_snim_eMamba_IP_slave_sx4arlen;
assign eMamba_IP_sx4arsize = i_snim_eMamba_IP_slave_sx4arsize;
assign eMamba_IP_sx4arburst = i_snim_eMamba_IP_slave_sx4arburst;
assign eMamba_IP_sx4rready = i_snim_eMamba_IP_slave_sx4rready;
assign i_snim_eMamba_IP_slave_sx4rvalid = eMamba_IP_sx4rvalid;
assign i_snim_eMamba_IP_slave_sx4rid = eMamba_IP_sx4rid;
assign i_snim_eMamba_IP_slave_sx4rdata = eMamba_IP_sx4rdata;
assign i_snim_eMamba_IP_slave_sx4rlast = eMamba_IP_sx4rlast;
assign i_snim_eMamba_IP_slave_sx4rresp = eMamba_IP_sx4rresp;
assign i_snim_input_bram_slave_sxawready = input_bram_sxawready;
assign input_bram_sxawvalid = i_snim_input_bram_slave_sxawvalid;
assign input_bram_sxawaddr = i_snim_input_bram_slave_sxawaddr;
assign input_bram_sxawid = i_snim_input_bram_slave_sxawid;
assign input_bram_sxawlen = i_snim_input_bram_slave_sxawlen;
assign input_bram_sxawsize = i_snim_input_bram_slave_sxawsize;
assign input_bram_sxawburst = i_snim_input_bram_slave_sxawburst;
assign i_snim_input_bram_slave_sxwready = input_bram_sxwready;
assign input_bram_sxwvalid = i_snim_input_bram_slave_sxwvalid;
assign input_bram_sxwid = i_snim_input_bram_slave_sxwid;
assign input_bram_sxwdata = i_snim_input_bram_slave_sxwdata;
assign input_bram_sxwstrb = i_snim_input_bram_slave_sxwstrb;
assign input_bram_sxwlast = i_snim_input_bram_slave_sxwlast;
assign input_bram_sxbready = i_snim_input_bram_slave_sxbready;
assign i_snim_input_bram_slave_sxbvalid = input_bram_sxbvalid;
assign i_snim_input_bram_slave_sxbid = input_bram_sxbid;
assign i_snim_input_bram_slave_sxbresp = input_bram_sxbresp;
assign i_snim_input_bram_slave_sxarready = input_bram_sxarready;
assign input_bram_sxarvalid = i_snim_input_bram_slave_sxarvalid;
assign input_bram_sxaraddr = i_snim_input_bram_slave_sxaraddr;
assign input_bram_sxarid = i_snim_input_bram_slave_sxarid;
assign input_bram_sxarlen = i_snim_input_bram_slave_sxarlen;
assign input_bram_sxarsize = i_snim_input_bram_slave_sxarsize;
assign input_bram_sxarburst = i_snim_input_bram_slave_sxarburst;
assign input_bram_sxrready = i_snim_input_bram_slave_sxrready;
assign i_snim_input_bram_slave_sxrvalid = input_bram_sxrvalid;
assign i_snim_input_bram_slave_sxrid = input_bram_sxrid;
assign i_snim_input_bram_slave_sxrdata = input_bram_sxrdata;
assign i_snim_input_bram_slave_sxrlast = input_bram_sxrlast;
assign i_snim_input_bram_slave_sxrresp = input_bram_sxrresp;
assign i_snim_wb_bram_slave_sxawready = wb_bram_sxawready;
assign wb_bram_sxawvalid = i_snim_wb_bram_slave_sxawvalid;
assign wb_bram_sxawaddr = i_snim_wb_bram_slave_sxawaddr;
assign wb_bram_sxawid = i_snim_wb_bram_slave_sxawid;
assign wb_bram_sxawlen = i_snim_wb_bram_slave_sxawlen;
assign wb_bram_sxawsize = i_snim_wb_bram_slave_sxawsize;
assign wb_bram_sxawburst = i_snim_wb_bram_slave_sxawburst;
assign i_snim_wb_bram_slave_sxwready = wb_bram_sxwready;
assign wb_bram_sxwvalid = i_snim_wb_bram_slave_sxwvalid;
assign wb_bram_sxwid = i_snim_wb_bram_slave_sxwid;
assign wb_bram_sxwdata = i_snim_wb_bram_slave_sxwdata;
assign wb_bram_sxwstrb = i_snim_wb_bram_slave_sxwstrb;
assign wb_bram_sxwlast = i_snim_wb_bram_slave_sxwlast;
assign wb_bram_sxbready = i_snim_wb_bram_slave_sxbready;
assign i_snim_wb_bram_slave_sxbvalid = wb_bram_sxbvalid;
assign i_snim_wb_bram_slave_sxbid = wb_bram_sxbid;
assign i_snim_wb_bram_slave_sxbresp = wb_bram_sxbresp;
assign i_snim_wb_bram_slave_sxarready = wb_bram_sxarready;
assign wb_bram_sxarvalid = i_snim_wb_bram_slave_sxarvalid;
assign wb_bram_sxaraddr = i_snim_wb_bram_slave_sxaraddr;
assign wb_bram_sxarid = i_snim_wb_bram_slave_sxarid;
assign wb_bram_sxarlen = i_snim_wb_bram_slave_sxarlen;
assign wb_bram_sxarsize = i_snim_wb_bram_slave_sxarsize;
assign wb_bram_sxarburst = i_snim_wb_bram_slave_sxarburst;
assign wb_bram_sxrready = i_snim_wb_bram_slave_sxrready;
assign i_snim_wb_bram_slave_sxrvalid = wb_bram_sxrvalid;
assign i_snim_wb_bram_slave_sxrid = wb_bram_sxrid;
assign i_snim_wb_bram_slave_sxrdata = wb_bram_sxrdata;
assign i_snim_wb_bram_slave_sxrlast = wb_bram_sxrlast;
assign i_snim_wb_bram_slave_sxrresp = wb_bram_sxrresp;
assign i_snim_output_bram_slave_sxawready = output_bram_sxawready;
assign output_bram_sxawvalid = i_snim_output_bram_slave_sxawvalid;
assign output_bram_sxawaddr = i_snim_output_bram_slave_sxawaddr;
assign output_bram_sxawid = i_snim_output_bram_slave_sxawid;
assign output_bram_sxawlen = i_snim_output_bram_slave_sxawlen;
assign output_bram_sxawsize = i_snim_output_bram_slave_sxawsize;
assign output_bram_sxawburst = i_snim_output_bram_slave_sxawburst;
assign i_snim_output_bram_slave_sxwready = output_bram_sxwready;
assign output_bram_sxwvalid = i_snim_output_bram_slave_sxwvalid;
assign output_bram_sxwid = i_snim_output_bram_slave_sxwid;
assign output_bram_sxwdata = i_snim_output_bram_slave_sxwdata;
assign output_bram_sxwstrb = i_snim_output_bram_slave_sxwstrb;
assign output_bram_sxwlast = i_snim_output_bram_slave_sxwlast;
assign output_bram_sxbready = i_snim_output_bram_slave_sxbready;
assign i_snim_output_bram_slave_sxbvalid = output_bram_sxbvalid;
assign i_snim_output_bram_slave_sxbid = output_bram_sxbid;
assign i_snim_output_bram_slave_sxbresp = output_bram_sxbresp;
assign i_snim_output_bram_slave_sxarready = output_bram_sxarready;
assign output_bram_sxarvalid = i_snim_output_bram_slave_sxarvalid;
assign output_bram_sxaraddr = i_snim_output_bram_slave_sxaraddr;
assign output_bram_sxarid = i_snim_output_bram_slave_sxarid;
assign output_bram_sxarlen = i_snim_output_bram_slave_sxarlen;
assign output_bram_sxarsize = i_snim_output_bram_slave_sxarsize;
assign output_bram_sxarburst = i_snim_output_bram_slave_sxarburst;
assign output_bram_sxrready = i_snim_output_bram_slave_sxrready;
assign i_snim_output_bram_slave_sxrvalid = output_bram_sxrvalid;
assign i_snim_output_bram_slave_sxrid = output_bram_sxrid;
assign i_snim_output_bram_slave_sxrdata = output_bram_sxrdata;
assign i_snim_output_bram_slave_sxrlast = output_bram_sxrlast;
assign i_snim_output_bram_slave_sxrresp = output_bram_sxrresp;
assign i_snim_i_system_ddr_no_name_sxawready = i_system_ddr_sxawready;
assign i_system_ddr_sxawvalid = i_snim_i_system_ddr_no_name_sxawvalid;
assign i_system_ddr_sxawaddr = i_snim_i_system_ddr_no_name_sxawaddr;
assign i_system_ddr_sxawid = i_snim_i_system_ddr_no_name_sxawid;
assign i_system_ddr_sxawlen = i_snim_i_system_ddr_no_name_sxawlen;
assign i_system_ddr_sxawsize = i_snim_i_system_ddr_no_name_sxawsize;
assign i_system_ddr_sxawburst = i_snim_i_system_ddr_no_name_sxawburst;
assign i_snim_i_system_ddr_no_name_sxwready = i_system_ddr_sxwready;
assign i_system_ddr_sxwvalid = i_snim_i_system_ddr_no_name_sxwvalid;
assign i_system_ddr_sxwid = i_snim_i_system_ddr_no_name_sxwid;
assign i_system_ddr_sxwdata = i_snim_i_system_ddr_no_name_sxwdata;
assign i_system_ddr_sxwstrb = i_snim_i_system_ddr_no_name_sxwstrb;
assign i_system_ddr_sxwlast = i_snim_i_system_ddr_no_name_sxwlast;
assign i_system_ddr_sxbready = i_snim_i_system_ddr_no_name_sxbready;
assign i_snim_i_system_ddr_no_name_sxbvalid = i_system_ddr_sxbvalid;
assign i_snim_i_system_ddr_no_name_sxbid = i_system_ddr_sxbid;
assign i_snim_i_system_ddr_no_name_sxbresp = i_system_ddr_sxbresp;
assign i_snim_i_system_ddr_no_name_sxarready = i_system_ddr_sxarready;
assign i_system_ddr_sxarvalid = i_snim_i_system_ddr_no_name_sxarvalid;
assign i_system_ddr_sxaraddr = i_snim_i_system_ddr_no_name_sxaraddr;
assign i_system_ddr_sxarid = i_snim_i_system_ddr_no_name_sxarid;
assign i_system_ddr_sxarlen = i_snim_i_system_ddr_no_name_sxarlen;
assign i_system_ddr_sxarsize = i_snim_i_system_ddr_no_name_sxarsize;
assign i_system_ddr_sxarburst = i_snim_i_system_ddr_no_name_sxarburst;
assign i_system_ddr_sxrready = i_snim_i_system_ddr_no_name_sxrready;
assign i_snim_i_system_ddr_no_name_sxrvalid = i_system_ddr_sxrvalid;
assign i_snim_i_system_ddr_no_name_sxrid = i_system_ddr_sxrid;
assign i_snim_i_system_ddr_no_name_sxrdata = i_system_ddr_sxrdata;
assign i_snim_i_system_ddr_no_name_sxrlast = i_system_ddr_sxrlast;
assign i_snim_i_system_ddr_no_name_sxrresp = i_system_ddr_sxrresp;
assign i_system_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(0+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_inter_router_fifo00_sfni_link;
assign i_inter_router_fifo00_sfni_ready = i_system_router_rfni_ready_list[1*(0+1)-1 -:1];
assign i_inter_router_fifo00_sbni_link = i_system_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(0+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_system_router_rbni_ready_list[1*(0+1)-1 -:1] = i_inter_router_fifo00_sbni_ready;
assign i_snim_i_edge_video_system_vdma_ctrl_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(0+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(0+1)-1 -:1] = i_snim_i_edge_video_system_vdma_ctrl_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(0+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_i_edge_video_system_vdma_ctrl_rbni_link;
assign i_snim_i_edge_video_system_vdma_ctrl_rbni_ready = i_system_router_sbni_ready_list[1*(0+1)-1 -:1];
assign i_snim_i_edge_video_system_video_ctrl_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(1+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(1+1)-1 -:1] = i_snim_i_edge_video_system_video_ctrl_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(1+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_i_edge_video_system_video_ctrl_rbni_link;
assign i_snim_i_edge_video_system_video_ctrl_rbni_ready = i_system_router_sbni_ready_list[1*(1+1)-1 -:1];
assign i_snim_i_system_sram_no_name_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(2+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(2+1)-1 -:1] = i_snim_i_system_sram_no_name_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(2+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_i_system_sram_no_name_rbni_link;
assign i_snim_i_system_sram_no_name_rbni_ready = i_system_router_sbni_ready_list[1*(2+1)-1 -:1];
assign i_snim_common_peri_group_no_name_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(3+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(3+1)-1 -:1] = i_snim_common_peri_group_no_name_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(3+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_common_peri_group_no_name_rbni_link;
assign i_snim_common_peri_group_no_name_rbni_ready = i_system_router_sbni_ready_list[1*(3+1)-1 -:1];
assign i_snim_external_peri_group_no_name_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(4+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(4+1)-1 -:1] = i_snim_external_peri_group_no_name_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(4+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_external_peri_group_no_name_rbni_link;
assign i_snim_external_peri_group_no_name_rbni_ready = i_system_router_sbni_ready_list[1*(4+1)-1 -:1];
assign i_snim_platform_controller_no_name_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(5+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(5+1)-1 -:1] = i_snim_platform_controller_no_name_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(5+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_platform_controller_no_name_rbni_link;
assign i_snim_platform_controller_no_name_rbni_ready = i_system_router_sbni_ready_list[1*(5+1)-1 -:1];
assign default_slave_rfni_link = i_system_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(6+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_system_router_sfni_ready_list[1*(6+1)-1 -:1] = default_slave_rfni_ready;
assign i_system_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(6+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = default_slave_rbni_link;
assign default_slave_rbni_ready = i_system_router_sbni_ready_list[1*(6+1)-1 -:1];
assign i_user_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(0+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_mnim_i_main_core_inst_sfni_link;
assign i_mnim_i_main_core_inst_sfni_ready = i_user_router_rfni_ready_list[1*(0+1)-1 -:1];
assign i_mnim_i_main_core_inst_sbni_link = i_user_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(0+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_user_router_rbni_ready_list[1*(0+1)-1 -:1] = i_mnim_i_main_core_inst_sbni_ready;
assign i_user_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(1+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_mnim_i_main_core_data_sfni_link;
assign i_mnim_i_main_core_data_sfni_ready = i_user_router_rfni_ready_list[1*(1+1)-1 -:1];
assign i_mnim_i_main_core_data_sbni_link = i_user_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(1+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_user_router_rbni_ready_list[1*(1+1)-1 -:1] = i_mnim_i_main_core_data_sbni_ready;
assign i_user_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(2+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_mnim_i_edge_video_system_vdma_sfni_link;
assign i_mnim_i_edge_video_system_vdma_sfni_ready = i_user_router_rfni_ready_list[1*(2+1)-1 -:1];
assign i_mnim_i_edge_video_system_vdma_sbni_link = i_user_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(2+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_user_router_rbni_ready_list[1*(2+1)-1 -:1] = i_mnim_i_edge_video_system_vdma_sbni_ready;
assign i_user_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(3+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_mnim_i_edge_video_system_vim_sfni_link;
assign i_mnim_i_edge_video_system_vim_sfni_ready = i_user_router_rfni_ready_list[1*(3+1)-1 -:1];
assign i_mnim_i_edge_video_system_vim_sbni_link = i_user_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(3+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_user_router_rbni_ready_list[1*(3+1)-1 -:1] = i_mnim_i_edge_video_system_vim_sbni_ready;
assign i_user_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(4+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_mnim_i_edge_video_system_vom_sfni_link;
assign i_mnim_i_edge_video_system_vom_sfni_ready = i_user_router_rfni_ready_list[1*(4+1)-1 -:1];
assign i_mnim_i_edge_video_system_vom_sbni_link = i_user_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(4+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_user_router_rbni_ready_list[1*(4+1)-1 -:1] = i_mnim_i_edge_video_system_vom_sbni_ready;
assign i_user_router_rfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(5+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)] = i_mnim_platform_controller_master_sfni_link;
assign i_mnim_platform_controller_master_sfni_ready = i_user_router_rfni_ready_list[1*(5+1)-1 -:1];
assign i_mnim_platform_controller_master_sbni_link = i_user_router_rbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(5+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)];
assign i_user_router_rbni_ready_list[1*(5+1)-1 -:1] = i_mnim_platform_controller_master_sbni_ready;
assign i_snim_eMamba_IP_slave_rfni_link = i_user_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(0+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_user_router_sfni_ready_list[1*(0+1)-1 -:1] = i_snim_eMamba_IP_slave_rfni_ready;
assign i_user_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(0+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_eMamba_IP_slave_rbni_link;
assign i_snim_eMamba_IP_slave_rbni_ready = i_user_router_sbni_ready_list[1*(0+1)-1 -:1];
assign i_snim_input_bram_slave_rfni_link = i_user_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(1+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_user_router_sfni_ready_list[1*(1+1)-1 -:1] = i_snim_input_bram_slave_rfni_ready;
assign i_user_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(1+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_input_bram_slave_rbni_link;
assign i_snim_input_bram_slave_rbni_ready = i_user_router_sbni_ready_list[1*(1+1)-1 -:1];
assign i_snim_wb_bram_slave_rfni_link = i_user_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(2+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_user_router_sfni_ready_list[1*(2+1)-1 -:1] = i_snim_wb_bram_slave_rfni_ready;
assign i_user_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(2+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_wb_bram_slave_rbni_link;
assign i_snim_wb_bram_slave_rbni_ready = i_user_router_sbni_ready_list[1*(2+1)-1 -:1];
assign i_snim_output_bram_slave_rfni_link = i_user_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(3+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_user_router_sfni_ready_list[1*(3+1)-1 -:1] = i_snim_output_bram_slave_rfni_ready;
assign i_user_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(3+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_output_bram_slave_rbni_link;
assign i_snim_output_bram_slave_rbni_ready = i_user_router_sbni_ready_list[1*(3+1)-1 -:1];
assign i_snim_i_system_ddr_no_name_rfni_link = i_user_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(4+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_user_router_sfni_ready_list[1*(4+1)-1 -:1] = i_snim_i_system_ddr_no_name_rfni_ready;
assign i_user_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(4+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_snim_i_system_ddr_no_name_rbni_link;
assign i_snim_i_system_ddr_no_name_rbni_ready = i_user_router_sbni_ready_list[1*(4+1)-1 -:1];
assign i_inter_router_fifo00_rfni_link = i_user_router_sfni_link_list[`BW_FNI_LINK(BW_FNI_PHIT)*(5+1)-1 -:`BW_FNI_LINK(BW_FNI_PHIT)];
assign i_user_router_sfni_ready_list[1*(5+1)-1 -:1] = i_inter_router_fifo00_rfni_ready;
assign i_user_router_sbni_link_list[`BW_BNI_LINK(BW_BNI_PHIT)*(5+1)-1 -:`BW_BNI_LINK(BW_BNI_PHIT)] = i_inter_router_fifo00_rbni_link;
assign i_inter_router_fifo00_rbni_ready = i_user_router_sbni_ready_list[1*(5+1)-1 -:1];
assign platform_controller_rpc_list[32*(0+1)-1 -:32] = i_main_core_spc;
assign platform_controller_rinst_list[32*(0+1)-1 -:32] = i_main_core_sinst;
assign default_slave_debug_rpsel = platform_controller_noc_debug_spsel;
assign default_slave_debug_rpenable = platform_controller_noc_debug_spenable;
assign default_slave_debug_rpwrite = platform_controller_noc_debug_spwrite;
assign default_slave_debug_rpaddr = platform_controller_noc_debug_spaddr;
assign default_slave_debug_rpwdata = platform_controller_noc_debug_spwdata;
assign platform_controller_noc_debug_spready = default_slave_debug_rpready;
assign platform_controller_noc_debug_sprdata = default_slave_debug_rprdata;
assign platform_controller_noc_debug_spslverr = default_slave_debug_rpslverr;
assign i_florian_000_rpsel = core_peri_group_florian_spsel;
assign i_florian_000_rpenable = core_peri_group_florian_spenable;
assign i_florian_000_rpwrite = core_peri_group_florian_spwrite;
assign i_florian_000_rpaddr = core_peri_group_florian_spaddr;
assign i_florian_000_rpwdata = core_peri_group_florian_spwdata;
assign core_peri_group_florian_spready = i_florian_000_rpready;
assign core_peri_group_florian_sprdata = i_florian_000_rprdata;
assign core_peri_group_florian_spslverr = i_florian_000_rpslverr;
assign core_peri_group_rpsel = i_mnim_i_main_core_data_local_spsel;
assign core_peri_group_rpenable = i_mnim_i_main_core_data_local_spenable;
assign core_peri_group_rpwrite = i_mnim_i_main_core_data_local_spwrite;
assign core_peri_group_rpaddr = i_mnim_i_main_core_data_local_spaddr;
assign core_peri_group_rpwdata = i_mnim_i_main_core_data_local_spwdata;
assign i_mnim_i_main_core_data_local_spready = core_peri_group_rpready;
assign i_mnim_i_main_core_data_local_sprdata = core_peri_group_rprdata;
assign i_mnim_i_main_core_data_local_spslverr = core_peri_group_rpslverr;
assign platform_controller_pjtag_rtck = pjtag_rtck;
assign platform_controller_pjtag_rtrstnn = pjtag_rtrstnn;
assign platform_controller_pjtag_rtms = pjtag_rtms;
assign platform_controller_pjtag_rtdi = pjtag_rtdi;
assign pjtag_rtdo = platform_controller_pjtag_rtdo;
assign external_peri_group_oled_sdcsel_ival = 0;
assign external_peri_group_oled_srstnn_ival = 0;
assign external_peri_group_oled_svbat_ival = 0;
assign external_peri_group_oled_svdd_ival = 0;
assign external_peri_group_wifi_sitr = 0;
assign i_mnim_i_main_core_inst_local_spready = 0;
assign i_mnim_i_main_core_inst_local_sprdata = 0;
assign i_mnim_i_main_core_inst_local_spslverr = 0;
assign i_mnim_i_edge_video_system_vdma_local_spready = 0;
assign i_mnim_i_edge_video_system_vdma_local_sprdata = 0;
assign i_mnim_i_edge_video_system_vdma_local_spslverr = 0;
assign i_mnim_i_edge_video_system_vim_local_spready = 0;
assign i_mnim_i_edge_video_system_vim_local_sprdata = 0;
assign i_mnim_i_edge_video_system_vim_local_spslverr = 0;
assign i_mnim_i_edge_video_system_vom_local_spready = 0;
assign i_mnim_i_edge_video_system_vom_local_sprdata = 0;
assign i_mnim_i_edge_video_system_vom_local_spslverr = 0;
assign default_slave_svri_rlink = 0;
assign default_slave_svri_sack = 0;
assign i_snim_i_edge_video_system_vdma_ctrl_svri_rlink = 0;
assign i_snim_i_edge_video_system_vdma_ctrl_svri_sack = 0;
assign i_snim_i_edge_video_system_video_ctrl_svri_rlink = 0;
assign i_snim_i_edge_video_system_video_ctrl_svri_sack = 0;
assign i_snim_i_system_sram_no_name_svri_rlink = 0;
assign i_snim_i_system_sram_no_name_svri_sack = 0;
assign i_snim_common_peri_group_no_name_svri_rlink = 0;
assign i_snim_common_peri_group_no_name_svri_sack = 0;
assign i_snim_external_peri_group_no_name_svri_rlink = 0;
assign i_snim_external_peri_group_no_name_svri_sack = 0;
assign i_snim_platform_controller_no_name_svri_rlink = 0;
assign i_snim_platform_controller_no_name_svri_sack = 0;
assign i_mnim_i_main_core_inst_svri_rlink = 0;
assign i_mnim_i_main_core_inst_svri_sack = 0;
assign i_mnim_i_main_core_data_svri_rlink = 0;
assign i_mnim_i_main_core_data_svri_sack = 0;
assign i_mnim_i_edge_video_system_vdma_svri_rlink = 0;
assign i_mnim_i_edge_video_system_vdma_svri_sack = 0;
assign i_mnim_i_edge_video_system_vim_svri_rlink = 0;
assign i_mnim_i_edge_video_system_vim_svri_sack = 0;
assign i_mnim_i_edge_video_system_vom_svri_rlink = 0;
assign i_mnim_i_edge_video_system_vom_svri_sack = 0;
assign i_mnim_platform_controller_master_svri_rlink = 0;
assign i_mnim_platform_controller_master_svri_sack = 0;
assign i_snim_eMamba_IP_slave_svri_rlink = 0;
assign i_snim_eMamba_IP_slave_svri_sack = 0;
assign i_snim_input_bram_slave_svri_rlink = 0;
assign i_snim_input_bram_slave_svri_sack = 0;
assign i_snim_wb_bram_slave_svri_rlink = 0;
assign i_snim_wb_bram_slave_svri_sack = 0;
assign i_snim_output_bram_slave_svri_rlink = 0;
assign i_snim_output_bram_slave_svri_sack = 0;
assign i_snim_i_system_ddr_no_name_svri_rlink = 0;
assign i_snim_i_system_ddr_no_name_svri_sack = 0;
assign core_peri_group_tcu_spready = 0;
assign core_peri_group_tcu_sprdata = 0;
assign core_peri_group_tcu_spslverr = 0;
assign i_edge_video_system_cis_rclk_od = external_peri_group_i2c_sclk_od_list[1*(`I2C_INDEX_FOR_CIS+1)-1 -:1];
assign i_edge_video_system_cis_rclk_oval = external_peri_group_i2c_sclk_oval_list[1*(`I2C_INDEX_FOR_CIS+1)-1 -:1];
assign external_peri_group_i2c_sclk_ival_list[1*(`I2C_INDEX_FOR_CIS+1)-1 -:1] = i_edge_video_system_cis_rclk_ival;
assign i_edge_video_system_cis_rdata_od = external_peri_group_i2c_sdata_od_list[1*(`I2C_INDEX_FOR_CIS+1)-1 -:1];
assign i_edge_video_system_cis_rdata_oval = external_peri_group_i2c_sdata_oval_list[1*(`I2C_INDEX_FOR_CIS+1)-1 -:1];
assign external_peri_group_i2c_sdata_ival_list[1*(`I2C_INDEX_FOR_CIS+1)-1 -:1] = i_edge_video_system_cis_rdata_ival;
assign i_edge_video_system_hdmi_rclk_od = external_peri_group_i2c_sclk_od_list[1*(`I2C_INDEX_FOR_HDMI+1)-1 -:1];
assign i_edge_video_system_hdmi_rclk_oval = external_peri_group_i2c_sclk_oval_list[1*(`I2C_INDEX_FOR_HDMI+1)-1 -:1];
assign external_peri_group_i2c_sclk_ival_list[1*(`I2C_INDEX_FOR_HDMI+1)-1 -:1] = i_edge_video_system_hdmi_rclk_ival;
assign i_edge_video_system_hdmi_rdata_od = external_peri_group_i2c_sdata_od_list[1*(`I2C_INDEX_FOR_HDMI+1)-1 -:1];
assign i_edge_video_system_hdmi_rdata_oval = external_peri_group_i2c_sdata_oval_list[1*(`I2C_INDEX_FOR_HDMI+1)-1 -:1];
assign external_peri_group_i2c_sdata_ival_list[1*(`I2C_INDEX_FOR_HDMI+1)-1 -:1] = i_edge_video_system_hdmi_rdata_ival;
assign printf_tx = external_peri_group_uart_stx_list[1*(`UART_INDEX_FOR_UART_PRINTF+1)-1 -:1];
assign external_peri_group_uart_srx_list[1*(`UART_INDEX_FOR_UART_PRINTF+1)-1 -:1] = printf_rx;


endmodule