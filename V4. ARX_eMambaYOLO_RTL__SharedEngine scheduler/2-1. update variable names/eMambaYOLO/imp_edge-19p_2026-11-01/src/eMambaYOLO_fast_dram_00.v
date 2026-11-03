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
// 2026-11-01
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_global.vh"
`include "ervp_axi_define.vh"

module EMAMBAYOLO_FAST_DRAM_00
(
	clk_ref,
	clk_sys,
	rstnn_sys,
	rstnn_dram_if,
	
	rxawid,
	rxawaddr,
	rxawlen,
	rxawsize,
	rxawburst,
	rxawvalid,
	rxawready,

	rxwid,
	rxwdata,
	rxwstrb,
	rxwlast,
	rxwvalid,
	rxwready,

	rxbid,
	rxbresp,
	rxbvalid,
	rxbready,

	rxarid,
	rxaraddr,
	rxarlen,
	rxarsize,
	rxarburst,
	rxarvalid,
	rxarready,

	rxrid,
	rxrdata,
	rxrresp,
	rxrlast,
	rxrvalid,
	rxrready,

	clk_dram_if,
	initialized
	`include "fast_dram_cell_port_dec.vh"
);

////////////////////////////
/* parameter input output */
////////////////////////////

localparam BW_ADDR = 32;
localparam BW_DATA = 128;
localparam BW_AXI_TID = 16;

input wire clk_ref;
input wire clk_sys;
input wire rstnn_sys;
input wire rstnn_dram_if;

input wire rxrready;
output wire rxrvalid;
output wire rxrlast;
output wire [`BW_AXI_RRESP-1:0] rxrresp;
output wire [BW_DATA-1:0] rxrdata;
output wire [BW_AXI_TID-1:0] rxrid;
output wire rxarready;
input wire rxarvalid;
input wire [`BW_AXI_ABURST-1:0] rxarburst;
input wire [`BW_AXI_ASIZE-1:0] rxarsize;
input wire [`BW_AXI_ALEN-1:0] rxarlen;
input wire [BW_ADDR-1:0] rxaraddr;
input wire [BW_AXI_TID-1:0] rxarid;
input wire rxbready;
output wire rxbvalid;
output wire [`BW_AXI_BRESP-1:0] rxbresp;
output wire [BW_AXI_TID-1:0] rxbid;
output wire rxwready;
input wire rxwvalid;
input wire rxwlast;
input wire [`BW_AXI_WSTRB(BW_DATA)-1:0] rxwstrb;
input wire [BW_DATA-1:0] rxwdata;
input wire [BW_AXI_TID-1:0] rxwid;
output wire rxawready;
input wire rxawvalid;
input wire [`BW_AXI_ABURST-1:0] rxawburst;
input wire [`BW_AXI_ASIZE-1:0] rxawsize;
input wire [`BW_AXI_ALEN-1:0] rxawlen;
input wire [BW_ADDR-1:0] rxawaddr;
input wire [BW_AXI_TID-1:0] rxawid;

output wire clk_dram_if;
output wire initialized;

`include "fast_dram_cell_port_def.vh"

`include "fast_dram_body.vh"


endmodule
