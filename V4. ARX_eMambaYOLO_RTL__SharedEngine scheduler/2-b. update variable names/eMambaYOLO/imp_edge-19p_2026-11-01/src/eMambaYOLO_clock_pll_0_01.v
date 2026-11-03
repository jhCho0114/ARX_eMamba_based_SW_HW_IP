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
// 2026-11-01
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

module EMAMBAYOLO_CLOCK_PLL_0_01
(
	external_clk,
	external_clk_pair,
	external_rstnn,
	clk_25M,
	clk_system,
	clk_core,
	clk_150M,
	clk_200M,
	clk_300M,
	clk_dram_sys,
	clk_dram_ref
);

input wire external_clk;
input wire external_clk_pair;
input wire external_rstnn;
output wire clk_25M;
output wire clk_system;
output wire clk_core;
output wire clk_150M;
output wire clk_200M;
output wire clk_300M;
output wire clk_dram_sys;
output wire clk_dram_ref;

wire clk_25000000;
wire clk_100000000;
wire clk_300000000;
wire clk_150000000;
wire clk_200000000;

assign clk_system = external_clk;
assign clk_dram_sys = 0;
assign clk_dram_ref = 0;

xilinx_clock_pll_0
i_xilinx_clock_pll_0
(
	.clk_in1(external_clk),
	.clk_25000000(clk_25000000),
	.clk_100000000(clk_100000000),
	.clk_300000000(clk_300000000),
	.clk_150000000(clk_150000000),
	.clk_200000000(clk_200000000)
);

assign clk_25M = clk_25000000;
assign clk_core = clk_100000000;
assign clk_150M = clk_150000000;
assign clk_200M = clk_200000000;
assign clk_300M = clk_300000000;


endmodule