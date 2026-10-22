/*****************/
/* Custom Region */
/*****************/

// wire clk_system;
// wire clk_core;
// wire clk_system_external;
// wire clk_system_debug;
// wire clk_local_access;
// wire clk_process_000;
// wire clk_noc;
// wire gclk_system;
// wire gclk_core;
// wire gclk_system_external;
// wire gclk_system_debug;
// wire gclk_local_access;
// wire gclk_process_000;
// wire gclk_noc;
// wire tick_1us;
// wire tick_62d5ms;
// wire tick_gpio;
// wire spi_common_sclk;
// wire spi_common_sdq0;
// wire global_rstnn;
// wire global_rstpp;
// wire [(6)-1:0] rstnn_seqeunce;
// wire [(6)-1:0] rstpp_seqeunce;
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

/* DO NOT MODIFY THE ABOVE */
/* MUST MODIFY THE BELOW   */


/*
USER_IP
#(
	.SIZE_OF_MEMORYMAP((32'h 800)),
	.BW_ADDR(32),
	.BW_DATA(32),
	.BW_AXI_TID(1)
)
eMamba_IP
(
	.clk(eMamba_IP_clk),
	.rstnn(eMamba_IP_rstnn),
	.rx4awready(eMamba_IP_rx4awready),
	.rx4awvalid(eMamba_IP_rx4awvalid),
	.rx4awaddr(eMamba_IP_rx4awaddr),
	.rx4awid(eMamba_IP_rx4awid),
	.rx4awlen(eMamba_IP_rx4awlen),
	.rx4awsize(eMamba_IP_rx4awsize),
	.rx4awburst(eMamba_IP_rx4awburst),
	.rx4wready(eMamba_IP_rx4wready),
	.rx4wvalid(eMamba_IP_rx4wvalid),
	.rx4wdata(eMamba_IP_rx4wdata),
	.rx4wstrb(eMamba_IP_rx4wstrb),
	.rx4wlast(eMamba_IP_rx4wlast),
	.rx4bready(eMamba_IP_rx4bready),
	.rx4bvalid(eMamba_IP_rx4bvalid),
	.rx4bid(eMamba_IP_rx4bid),
	.rx4bresp(eMamba_IP_rx4bresp),
	.rx4arready(eMamba_IP_rx4arready),
	.rx4arvalid(eMamba_IP_rx4arvalid),
	.rx4araddr(eMamba_IP_rx4araddr),
	.rx4arid(eMamba_IP_rx4arid),
	.rx4arlen(eMamba_IP_rx4arlen),
	.rx4arsize(eMamba_IP_rx4arsize),
	.rx4arburst(eMamba_IP_rx4arburst),
	.rx4rready(eMamba_IP_rx4rready),
	.rx4rvalid(eMamba_IP_rx4rvalid),
	.rx4rid(eMamba_IP_rx4rid),
	.rx4rdata(eMamba_IP_rx4rdata),
	.rx4rlast(eMamba_IP_rx4rlast),
	.rx4rresp(eMamba_IP_rx4rresp)
);
*/
// //assign `NOT_CONNECT = eMamba_IP_clk;
// //assign `NOT_CONNECT = eMamba_IP_rstnn;
// assign eMamba_IP_rx4awready = 0;
// //assign `NOT_CONNECT = eMamba_IP_rx4awvalid;
// //assign `NOT_CONNECT = eMamba_IP_rx4awaddr;
// //assign `NOT_CONNECT = eMamba_IP_rx4awid;
// //assign `NOT_CONNECT = eMamba_IP_rx4awlen;
// //assign `NOT_CONNECT = eMamba_IP_rx4awsize;
// //assign `NOT_CONNECT = eMamba_IP_rx4awburst;
// assign eMamba_IP_rx4wready = 0;
// //assign `NOT_CONNECT = eMamba_IP_rx4wvalid;
// //assign `NOT_CONNECT = eMamba_IP_rx4wdata;
// //assign `NOT_CONNECT = eMamba_IP_rx4wstrb;
// //assign `NOT_CONNECT = eMamba_IP_rx4wlast;
// //assign `NOT_CONNECT = eMamba_IP_rx4bready;
// assign eMamba_IP_rx4bvalid = 0;
// assign eMamba_IP_rx4bid = 0;
// assign eMamba_IP_rx4bresp = 0;
// assign eMamba_IP_rx4arready = 0;
// //assign `NOT_CONNECT = eMamba_IP_rx4arvalid;
// //assign `NOT_CONNECT = eMamba_IP_rx4araddr;
// //assign `NOT_CONNECT = eMamba_IP_rx4arid;
// //assign `NOT_CONNECT = eMamba_IP_rx4arlen;
// //assign `NOT_CONNECT = eMamba_IP_rx4arsize;
// //assign `NOT_CONNECT = eMamba_IP_rx4arburst;
// //assign `NOT_CONNECT = eMamba_IP_rx4rready;
// assign eMamba_IP_rx4rvalid = 0;
// assign eMamba_IP_rx4rid = 0;
// assign eMamba_IP_rx4rdata = 0;
// assign eMamba_IP_rx4rlast = 0;
// assign eMamba_IP_rx4rresp = 0;


eMamba_IP
// #(
// 	// .SIZE_OF_MEMORYMAP((32'h 800)),
// 	// .BW_ADDR(32),
// 	// .BW_DATA(32),
// 	// .BW_AXI_TID(1)
// )
my_emamba_ip
(
	.s_axi_aclk(eMamba_IP_clk),
	.s_axi_aresetn(eMamba_IP_rstnn),

	.s_axi_awid(eMamba_IP_rx4awid),
	.s_axi_awaddr(eMamba_IP_rx4awaddr[10:0]), // 11 bits address (0x000 ~ 0x7FF)
	.s_axi_awlen(eMamba_IP_rx4awlen),
	.s_axi_awsize(eMamba_IP_rx4awsize),
	.s_axi_awburst(eMamba_IP_rx4awburst),

	.s_axi_awlock(0), //empty input
	.s_axi_awcache(4'b0), //empty input
	.s_axi_awprot(3'b0), //empty input
	.s_axi_awqos(4'b0), //empty input
	.s_axi_awregion(4'b0), //empty input
	.s_axi_awuser(0), //empty input

	.s_axi_awvalid(eMamba_IP_rx4awvalid),
	.s_axi_awready(eMamba_IP_rx4awready),

	.s_axi_wdata(eMamba_IP_rx4wdata),
	.s_axi_wstrb(eMamba_IP_rx4wstrb),
	.s_axi_wlast(eMamba_IP_rx4wlast),

	.s_axi_wuser(0), //empty input

	.s_axi_wvalid(eMamba_IP_rx4wvalid),
	.s_axi_wready(eMamba_IP_rx4wready),

	.s_axi_bid(eMamba_IP_rx4bid),
	.s_axi_bresp(eMamba_IP_rx4bresp),

	.s_axi_buser(), 					// empty output

	.s_axi_bvalid(eMamba_IP_rx4bvalid),
	.s_axi_bready(eMamba_IP_rx4bready),

	.s_axi_arid(eMamba_IP_rx4arid),
	.s_axi_araddr(eMamba_IP_rx4araddr[10:0]), // 11 bits address (0x000 ~ 0x7FF)
	.s_axi_arlen(eMamba_IP_rx4arlen),
	.s_axi_arsize(eMamba_IP_rx4arsize),
	.s_axi_arburst(eMamba_IP_rx4arburst),

	.s_axi_arlock(0), //empty input
	.s_axi_arcache(4'b0), //empty input
	.s_axi_arprot(3'b0), //empty input
	.s_axi_arqos(4'b0), //empty input
	.s_axi_arregion(4'b0), //empty input
	.s_axi_aruser(0), //empty input

	.s_axi_arvalid(eMamba_IP_rx4arvalid),
	.s_axi_arready(eMamba_IP_rx4arready),
	.s_axi_rid(eMamba_IP_rx4rid),
	.s_axi_rdata(eMamba_IP_rx4rdata),
	.s_axi_rresp(eMamba_IP_rx4rresp),
	.s_axi_rlast(eMamba_IP_rx4rlast),
	.s_axi_ruser(), 			// empty output
	.s_axi_rvalid(eMamba_IP_rx4rvalid),
	.s_axi_rready(eMamba_IP_rx4rready)
);