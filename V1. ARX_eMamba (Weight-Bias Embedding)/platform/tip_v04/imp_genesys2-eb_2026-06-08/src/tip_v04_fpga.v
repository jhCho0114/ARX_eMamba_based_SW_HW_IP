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
// 2026-06-08
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_platform_controller_memorymap_offset.vh"
`include "ervp_external_peri_group_memorymap_offset.vh"
`include "memorymap_info.vh"
`include "ervp_global.vh"
`include "platform_info.vh"
`include "munoc_network_include.vh"

module TIP_V04_FPGA
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



STARTUPE2
#(
  .PROG_USR("FALSE"),
  .SIM_CCLK_FREQ(0.0)
)
i_STARTUPE2
(
  .CFGCLK(),
  .CFGMCLK(),
  .EOS(),
  .PREQ(),

  .CLK(1'b0),
  .GSR(1'b0),
  .GTS(1'b0),
  .KEYCLEARB(1'b0),
  .PACK(1'b0),
  .USRCCLKO(spi_flash_sclk),
  .USRCCLKTS(1'b0),
  .USRDONEO(1'b1),
  .USRDONETS(1'b0)
);

TIP_V04
i_platform
(
	.external_clk_0(external_clk_0),
	.external_clk_0_pair(external_clk_0_pair),
	.external_rstnn(external_rstnn),
	.pjtag_rtck(pjtag_rtck),
	.pjtag_rtrstnn(pjtag_rtrstnn),
	.pjtag_rtms(pjtag_rtms),
	.pjtag_rtdi(pjtag_rtdi),
	.pjtag_rtdo(pjtag_rtdo),
	.printf_tx(printf_tx),
	.printf_rx(printf_rx)
);

endmodule