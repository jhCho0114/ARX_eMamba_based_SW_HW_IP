`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/07/2024 10:27:04 AM
// Design Name: 
// Module Name: eMamba_IP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module eMamba_IP #
(
	// Users to add parameters here
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_CHANNEL = 5,
    parameter integer NUM_HEIGHT  = 8,
    parameter integer NUM_WIDTH   = 8,
    parameter integer PATCH1      = 2,
    parameter integer PATCH2      = 2,
    parameter integer NUM_SEQLEN  = 16, // L
    parameter integer NUM_DIM     = 20, // D
    parameter integer NUM_ED      = 40, // ED
    parameter integer NUM_N       = 8,  // N
    parameter integer NUM_DELTA   = 32,
    parameter integer NUM_DBC     = 48, // NUM_DELTA + NUM_N * 2
    parameter integer NUM_CLASS   = 57,
	// User parameters ends

	// Do not modify the parameters beyond this line
	// Parameters of Axi Slave Bus Interface S_AXI
	parameter integer C_S_AXI_ID_WIDTH		= 1,
	parameter integer C_S_AXI_DATA_WIDTH	= 32,
	parameter integer C_S_AXI_ADDR_WIDTH	= 11,
	parameter integer C_S_AXI_AWUSER_WIDTH	= 0,
	parameter integer C_S_AXI_ARUSER_WIDTH	= 0,
	parameter integer C_S_AXI_WUSER_WIDTH	= 0,
	parameter integer C_S_AXI_RUSER_WIDTH	= 0,
	parameter integer C_S_AXI_BUSER_WIDTH	= 0
)
(
	// Users to add ports here
	// User ports ends

	// Do not modify the ports beyond this line
	// Ports of Axi Slave Bus Interface S_AXI
	input wire  s_axi_aclk,
	input wire  s_axi_aresetn,

	input wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_awid,
	input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_awaddr,
	input wire [7 : 0] s_axi_awlen,
	input wire [2 : 0] s_axi_awsize,
	input wire [1 : 0] s_axi_awburst,

	input wire  s_axi_awlock,
	input wire [3 : 0] s_axi_awcache,
	input wire [2 : 0] s_axi_awprot,
	input wire [3 : 0] s_axi_awqos,
	input wire [3 : 0] s_axi_awregion,
	input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] s_axi_awuser,

	input wire  s_axi_awvalid,
	output wire  s_axi_awready,

	input wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_wdata,
	input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] s_axi_wstrb,
	input wire  s_axi_wlast,

	input wire [C_S_AXI_WUSER_WIDTH-1 : 0] s_axi_wuser,

	input wire  s_axi_wvalid,
	output wire  s_axi_wready,

	output wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_bid,
	output wire [1 : 0] s_axi_bresp,

	output wire [C_S_AXI_BUSER_WIDTH-1 : 0] s_axi_buser,

	output wire  s_axi_bvalid,
	input wire  s_axi_bready,

	input wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_arid,
	input wire [C_S_AXI_ADDR_WIDTH-1 : 0] s_axi_araddr,
	input wire [7 : 0] s_axi_arlen,
	input wire [2 : 0] s_axi_arsize,
	input wire [1 : 0] s_axi_arburst,
	
	input wire  s_axi_arlock,
	input wire [3 : 0] s_axi_arcache,
	input wire [2 : 0] s_axi_arprot,
	input wire [3 : 0] s_axi_arqos,
	input wire [3 : 0] s_axi_arregion,
	input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] s_axi_aruser,
	
	input wire  s_axi_arvalid,
	output wire  s_axi_arready,
	output wire [C_S_AXI_ID_WIDTH-1 : 0] s_axi_rid,
	output wire [C_S_AXI_DATA_WIDTH-1 : 0] s_axi_rdata,
	output wire [1 : 0] s_axi_rresp,
	output wire  s_axi_rlast,
	output wire [C_S_AXI_RUSER_WIDTH-1 : 0] s_axi_ruser,
	output wire  s_axi_rvalid,
	input wire  s_axi_rready
);

	// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
	// Internal variables
	// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
	wire ps_start;

	// Initial Input
	wire signed [DATA_WIDTH * NUM_CHANNEL * NUM_HEIGHT * NUM_WIDTH - 1:0] eMamba_dIn; // 1x5x8x8

	// Final Output
	wire signed [DATA_WIDTH * NUM_CLASS - 1:0] eMamba_dOut; // Class 57
	wire dOut_ready;
	wire [3:0] dOut_seqlength;
	wire frameDout_ready;

	wire eMamba_start;

// Instantiation of Axi Bus Interface S_AXI
S_AXI # ( 
	.C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
	.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
	.C_S_AXI_AWUSER_WIDTH(C_S_AXI_AWUSER_WIDTH),
	.C_S_AXI_ARUSER_WIDTH(C_S_AXI_ARUSER_WIDTH),
	.C_S_AXI_WUSER_WIDTH(C_S_AXI_WUSER_WIDTH),
	.C_S_AXI_RUSER_WIDTH(C_S_AXI_RUSER_WIDTH),
	.C_S_AXI_BUSER_WIDTH(C_S_AXI_BUSER_WIDTH),

	// User parameters
	.DATA_WIDTH(DATA_WIDTH),
	.NUM_CHANNEL(NUM_CHANNEL),
	.NUM_HEIGHT(NUM_HEIGHT),
	.NUM_WIDTH(NUM_WIDTH),
	.PATCH1(PATCH1),
	.PATCH2(PATCH2),
	.NUM_SEQLEN(NUM_SEQLEN),
	.NUM_DIM(NUM_DIM),
	.NUM_ED(NUM_ED),
	.NUM_N(NUM_N),
	.NUM_DELTA(NUM_DELTA),
	.NUM_DBC(NUM_DBC),
	.NUM_CLASS(NUM_CLASS)
) S_AXI (
	.S_AXI_ACLK(s_axi_aclk),
	.S_AXI_ARESETN(s_axi_aresetn),
	.S_AXI_AWID(s_axi_awid),
	.S_AXI_AWADDR(s_axi_awaddr),
	.S_AXI_AWLEN(s_axi_awlen),
	.S_AXI_AWSIZE(s_axi_awsize),
	.S_AXI_AWBURST(s_axi_awburst),
	.S_AXI_AWLOCK(s_axi_awlock),
	.S_AXI_AWCACHE(s_axi_awcache),
	.S_AXI_AWPROT(s_axi_awprot),
	.S_AXI_AWQOS(s_axi_awqos),
	.S_AXI_AWREGION(s_axi_awregion),
	.S_AXI_AWUSER(s_axi_awuser),
	.S_AXI_AWVALID(s_axi_awvalid),
	.S_AXI_AWREADY(s_axi_awready),
	.S_AXI_WDATA(s_axi_wdata),
	.S_AXI_WSTRB(s_axi_wstrb),
	.S_AXI_WLAST(s_axi_wlast),
	.S_AXI_WUSER(s_axi_wuser),
	.S_AXI_WVALID(s_axi_wvalid),
	.S_AXI_WREADY(s_axi_wready),
	.S_AXI_BID(s_axi_bid),
	.S_AXI_BRESP(s_axi_bresp),
	.S_AXI_BUSER(s_axi_buser),
	.S_AXI_BVALID(s_axi_bvalid),
	.S_AXI_BREADY(s_axi_bready),
	.S_AXI_ARID(s_axi_arid),
	.S_AXI_ARADDR(s_axi_araddr),
	.S_AXI_ARLEN(s_axi_arlen),
	.S_AXI_ARSIZE(s_axi_arsize),
	.S_AXI_ARBURST(s_axi_arburst),
	.S_AXI_ARLOCK(s_axi_arlock),
	.S_AXI_ARCACHE(s_axi_arcache),
	.S_AXI_ARPROT(s_axi_arprot),
	.S_AXI_ARQOS(s_axi_arqos),
	.S_AXI_ARREGION(s_axi_arregion),
	.S_AXI_ARUSER(s_axi_aruser),
	.S_AXI_ARVALID(s_axi_arvalid),
	.S_AXI_ARREADY(s_axi_arready),
	.S_AXI_RID(s_axi_rid),
	.S_AXI_RDATA(s_axi_rdata),
	.S_AXI_RRESP(s_axi_rresp),
	.S_AXI_RLAST(s_axi_rlast),
	.S_AXI_RUSER(s_axi_ruser),
	.S_AXI_RVALID(s_axi_rvalid),
	.S_AXI_RREADY(s_axi_rready),

	// User I/O
    .ps_start(ps_start),

    .dIn(eMamba_dIn),

	.dOut(eMamba_dOut),
    .dOut_ready(dOut_ready),
	.dOut_seqlength(dOut_seqlength),
	.frameDout_ready(frameDout_ready),
	
	.eMamba_start(eMamba_start)
);

eMamba #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNEL(NUM_CHANNEL),
    .NUM_HEIGHT(NUM_HEIGHT),
    .NUM_WIDTH(NUM_WIDTH),
    .PATCH1(PATCH1),
    .PATCH2(PATCH2),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),
    .NUM_ED(NUM_ED),
    .NUM_N(NUM_N),
    .NUM_DELTA(NUM_DELTA),
    .NUM_DBC(NUM_DBC),
    .NUM_CLASS(NUM_CLASS)
) eMamba (
    .clk(s_axi_aclk),
    .nRst(s_axi_aresetn),

    .ps_start(ps_start),

    .dIn(eMamba_dIn),
    .dOut(eMamba_dOut),

    .dOut_ready(dOut_ready),
    .dOut_seqlength(dOut_seqlength),
	.frameDout_ready(frameDout_ready),
	
	.eMamba_start(eMamba_start)
);

endmodule