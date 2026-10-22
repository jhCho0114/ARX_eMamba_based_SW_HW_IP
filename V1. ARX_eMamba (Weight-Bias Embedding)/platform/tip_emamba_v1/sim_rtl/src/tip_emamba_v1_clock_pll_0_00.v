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
// 2026-07-04
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

module TIP_EMAMBA_V1_CLOCK_PLL_0_00
(
	external_clk,
	external_clk_pair,
	external_rstnn,
	clk_system
);

input wire external_clk;
input wire external_clk_pair;
input wire external_rstnn;
output wire clk_system;

wire clk_50000000;


CLOCK_GENERATOR
#(
	.CLK_INITIAL_DELAY(1),
	.CLK_PERIOD(20)
)
i_gen_clk_0
(
	.clk(clk_50000000),
	.rstnn(),
	.rst()
);


assign clk_system = clk_50000000;


endmodule