// ****************************************************************************
// ****************************************************************************
// Copyright SoC Design Research Group, All rights reservxd.
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
// 2026-10-26
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_platform_controller_memorymap_offset.vh"
`include "ervp_external_peri_group_memorymap_offset.vh"
`include "memorymap_info.vh"
`include "ervp_global.vh"
`include "platform_info.vh"
`include "munoc_network_include.vh"

module U601_FPGA
(
	boot_mode,
	external_clk_0,
	external_rstnn,
	led_list,
	pjtag_rtck,
	pjtag_rtrstnn,
	pjtag_rtms,
	pjtag_rtdi,
	pjtag_rtdo,
	printf_tx,
	printf_rx,
	spi_flash_sclk,
	spi_flash_scs,
	spi_flash_sdq0,
	spi_flash_sdq1
	`include "video_module_port_dec.vh"
	`include "fast_dram_cell_port_dec.vh"
);

input wire [`BW_BOOT_MODE-1:0] boot_mode;
input wire external_clk_0;
input wire external_rstnn;
output wire [(1)*(1)-1:0] led_list;
input wire pjtag_rtck;
input wire pjtag_rtrstnn;
input wire pjtag_rtms;
input wire pjtag_rtdi;
output wire pjtag_rtdo;
output wire printf_tx;
input wire printf_rx;
output wire spi_flash_sclk;
output wire spi_flash_scs;
output wire spi_flash_sdq0;
input wire spi_flash_sdq1;

`include "video_module_port_def.vh"
`include "fast_dram_cell_port_def.vh"

wire external_clk_0_pair = 0;

U601
i_platform
(
	.boot_mode(boot_mode),
	.external_clk_0(external_clk_0),
	.external_clk_0_pair(external_clk_0_pair),
	.external_rstnn(external_rstnn),
	.led_list(led_list),
	.pjtag_rtck(pjtag_rtck),
	.pjtag_rtrstnn(pjtag_rtrstnn),
	.pjtag_rtms(pjtag_rtms),
	.pjtag_rtdi(pjtag_rtdi),
	.pjtag_rtdo(pjtag_rtdo),
	.printf_tx(printf_tx),
	.printf_rx(printf_rx),
	.spi_flash_sclk(spi_flash_sclk),
	.spi_flash_scs(spi_flash_scs),
	.spi_flash_sdq0(spi_flash_sdq0),
	.spi_flash_sdq1(spi_flash_sdq1)
	`include "video_module_port_mapping.vh"
	`include "fast_dram_cell_port_mapping.vh"
);

endmodule