/*****************/
/* Custom Region */
/*****************/

// wire clk_core;
// wire clk_system;
// wire clk_system_external;
// wire clk_system_debug;
// wire clk_local_access;
// wire clk_process_000;
// wire clk_dram_if;
// wire clk_dram_sys;
// wire clk_dram_ref;
// wire clk_noc;
// wire clk_25M;
// wire clk_50M;
// wire clk_150M;
// wire clk_200M;
// wire clk_300M;
// wire gclk_core;
// wire gclk_system;
// wire gclk_system_external;
// wire gclk_system_debug;
// wire gclk_local_access;
// wire gclk_process_000;
// wire gclk_noc;
// wire gclk_25M;
// wire gclk_50M;
// wire gclk_150M;
// wire gclk_200M;
// wire gclk_300M;
// wire tick_1us;
// wire tick_62d5ms;
// wire tick_gpio;
// wire spi_common_sclk;
// wire spi_common_sdq0;
// wire global_rstnn;
// wire global_rstpp;
// wire [(7)-1:0] rstnn_seqeunce;
// wire [(7)-1:0] rstpp_seqeunce;
// wire rstnn_user;
// wire rstpp_user;
// wire eMamba_BRAM_WB_IP_clk;
// wire eMamba_BRAM_WB_IP_rstnn;
// wire eMamba_BRAM_WB_IP_rx4awready;
// wire eMamba_BRAM_WB_IP_rx4awvalid;
// wire [(32)-1:0] eMamba_BRAM_WB_IP_rx4awaddr;
// wire [(1)-1:0] eMamba_BRAM_WB_IP_rx4awid;
// wire [(8)-1:0] eMamba_BRAM_WB_IP_rx4awlen;
// wire [(3)-1:0] eMamba_BRAM_WB_IP_rx4awsize;
// wire [(2)-1:0] eMamba_BRAM_WB_IP_rx4awburst;
// wire eMamba_BRAM_WB_IP_rx4wready;
// wire eMamba_BRAM_WB_IP_rx4wvalid;
// wire [(32)-1:0] eMamba_BRAM_WB_IP_rx4wdata;
// wire [(32/8)-1:0] eMamba_BRAM_WB_IP_rx4wstrb;
// wire eMamba_BRAM_WB_IP_rx4wlast;
// wire eMamba_BRAM_WB_IP_rx4bready;
// wire eMamba_BRAM_WB_IP_rx4bvalid;
// wire [(1)-1:0] eMamba_BRAM_WB_IP_rx4bid;
// wire [(2)-1:0] eMamba_BRAM_WB_IP_rx4bresp;
// wire eMamba_BRAM_WB_IP_rx4arready;
// wire eMamba_BRAM_WB_IP_rx4arvalid;
// wire [(32)-1:0] eMamba_BRAM_WB_IP_rx4araddr;
// wire [(1)-1:0] eMamba_BRAM_WB_IP_rx4arid;
// wire [(8)-1:0] eMamba_BRAM_WB_IP_rx4arlen;
// wire [(3)-1:0] eMamba_BRAM_WB_IP_rx4arsize;
// wire [(2)-1:0] eMamba_BRAM_WB_IP_rx4arburst;
// wire eMamba_BRAM_WB_IP_rx4rready;
// wire eMamba_BRAM_WB_IP_rx4rvalid;
// wire [(1)-1:0] eMamba_BRAM_WB_IP_rx4rid;
// wire [(32)-1:0] eMamba_BRAM_WB_IP_rx4rdata;
// wire eMamba_BRAM_WB_IP_rx4rlast;
// wire [(2)-1:0] eMamba_BRAM_WB_IP_rx4rresp;

/* DO NOT MODIFY THE ABOVE */
/* MUST MODIFY THE BELOW   */


/*
USER_IP
#(
	.SIZE_OF_MEMORYMAP((32'h 8000)),
	.BW_ADDR(32),
	.BW_DATA(32),
	.BW_AXI_TID(1)
)
eMamba_BRAM_WB_IP
(
	.clk(eMamba_BRAM_WB_IP_clk),
	.rstnn(eMamba_BRAM_WB_IP_rstnn),
	.rx4awready(eMamba_BRAM_WB_IP_rx4awready),
	.rx4awvalid(eMamba_BRAM_WB_IP_rx4awvalid),
	.rx4awaddr(eMamba_BRAM_WB_IP_rx4awaddr),
	.rx4awid(eMamba_BRAM_WB_IP_rx4awid),
	.rx4awlen(eMamba_BRAM_WB_IP_rx4awlen),
	.rx4awsize(eMamba_BRAM_WB_IP_rx4awsize),
	.rx4awburst(eMamba_BRAM_WB_IP_rx4awburst),
	.rx4wready(eMamba_BRAM_WB_IP_rx4wready),
	.rx4wvalid(eMamba_BRAM_WB_IP_rx4wvalid),
	.rx4wdata(eMamba_BRAM_WB_IP_rx4wdata),
	.rx4wstrb(eMamba_BRAM_WB_IP_rx4wstrb),
	.rx4wlast(eMamba_BRAM_WB_IP_rx4wlast),
	.rx4bready(eMamba_BRAM_WB_IP_rx4bready),
	.rx4bvalid(eMamba_BRAM_WB_IP_rx4bvalid),
	.rx4bid(eMamba_BRAM_WB_IP_rx4bid),
	.rx4bresp(eMamba_BRAM_WB_IP_rx4bresp),
	.rx4arready(eMamba_BRAM_WB_IP_rx4arready),
	.rx4arvalid(eMamba_BRAM_WB_IP_rx4arvalid),
	.rx4araddr(eMamba_BRAM_WB_IP_rx4araddr),
	.rx4arid(eMamba_BRAM_WB_IP_rx4arid),
	.rx4arlen(eMamba_BRAM_WB_IP_rx4arlen),
	.rx4arsize(eMamba_BRAM_WB_IP_rx4arsize),
	.rx4arburst(eMamba_BRAM_WB_IP_rx4arburst),
	.rx4rready(eMamba_BRAM_WB_IP_rx4rready),
	.rx4rvalid(eMamba_BRAM_WB_IP_rx4rvalid),
	.rx4rid(eMamba_BRAM_WB_IP_rx4rid),
	.rx4rdata(eMamba_BRAM_WB_IP_rx4rdata),
	.rx4rlast(eMamba_BRAM_WB_IP_rx4rlast),
	.rx4rresp(eMamba_BRAM_WB_IP_rx4rresp)
);
*/
//assign `NOT_CONNECT = eMamba_BRAM_WB_IP_clk;
//assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rstnn;
// assign eMamba_BRAM_WB_IP_rx4awready = 0;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4awvalid;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4awaddr;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4awid;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4awlen;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4awsize;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4awburst;
// assign eMamba_BRAM_WB_IP_rx4wready = 0;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4wvalid;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4wdata;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4wstrb;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4wlast;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4bready;
// assign eMamba_BRAM_WB_IP_rx4bvalid = 0;
// assign eMamba_BRAM_WB_IP_rx4bid = 0;
// assign eMamba_BRAM_WB_IP_rx4bresp = 0;
// assign eMamba_BRAM_WB_IP_rx4arready = 0;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4arvalid;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4araddr;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4arid;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4arlen;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4arsize;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4arburst;
// //assign `NOT_CONNECT = eMamba_BRAM_WB_IP_rx4rready;
// assign eMamba_BRAM_WB_IP_rx4rvalid = 0;
// assign eMamba_BRAM_WB_IP_rx4rid = 0;
// assign eMamba_BRAM_WB_IP_rx4rdata = 0;
// assign eMamba_BRAM_WB_IP_rx4rlast = 0;
// assign eMamba_BRAM_WB_IP_rx4rresp = 0;


wire        in_clk, in_rst, in_en;
wire [14:0] in_addr;
wire [31:0] in_din, in_dout;
wire [3:0]  in_we;

wire        wb_clk, wb_rst, wb_en;
wire [14:0] wb_addr;
wire [31:0] wb_din, wb_dout;
wire [3:0]  wb_we;

wire         out_clk, out_rst, out_en;
wire [12:0]  out_addr;
wire [511:0] out_din, out_dout;
wire [63:0]  out_we;


assign eMamba_IP_clk   = clk_core;
assign input_bram_clk  = clk_core;
assign wb_bram_clk     = clk_core;
assign output_bram_clk = clk_core;

my_axi_bram #(
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(1),
    .DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(15)
) u_input_bram (
    .clk(input_bram_clk),
    .rstnn(input_bram_rstnn),
    .rxawid(input_bram_rxawid),
    .rxawaddr({17'b0, input_bram_rxawaddr[14:0]}),
    .rxawlen(input_bram_rxawlen),
    .rxawsize(input_bram_rxawsize),
    .rxawburst(input_bram_rxawburst),
    .rxawvalid(input_bram_rxawvalid),
    .rxawready(input_bram_rxawready),
    .rxwid(input_bram_rxwid),
    .rxwdata(input_bram_rxwdata),
    .rxwstrb(input_bram_rxwstrb),
    .rxwlast(input_bram_rxwlast),
    .rxwvalid(input_bram_rxwvalid),
    .rxwready(input_bram_rxwready),
    .rxbid(input_bram_rxbid),
    .rxbresp(input_bram_rxbresp),
    .rxbvalid(input_bram_rxbvalid),
    .rxbready(input_bram_rxbready),
    .rxarid(input_bram_rxarid),
    .rxaraddr({17'b0, input_bram_rxaraddr[14:0]}),
    .rxarlen(input_bram_rxarlen),
    .rxarsize(input_bram_rxarsize),
    .rxarburst(input_bram_rxarburst),
    .rxarvalid(input_bram_rxarvalid),
    .rxarready(input_bram_rxarready),
    .rxrid(input_bram_rxrid),
    .rxrdata(input_bram_rxrdata),
    .rxrresp(input_bram_rxrresp),
    .rxrlast(input_bram_rxrlast),
    .rxrvalid(input_bram_rxrvalid),
    .rxrready(input_bram_rxrready),

    .BRAM_IN_clk(in_clk),
    .BRAM_IN_rst(in_rst),
    .BRAM_IN_en(in_en),
    .BRAM_IN_addr(in_addr),
    .BRAM_IN_din(in_din),
    .BRAM_IN_we(in_we),
    .BRAM_IN_dout(in_dout)
);

my_axi_bram #(
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(1),
    .DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(15)
) u_wb_bram (
    .clk(wb_bram_clk),
    .rstnn(wb_bram_rstnn),
    .rxawid(wb_bram_rxawid),
    .rxawaddr({17'b0, wb_bram_rxawaddr[14:0]}),
    .rxawlen(wb_bram_rxawlen),
    .rxawsize(wb_bram_rxawsize),
    .rxawburst(wb_bram_rxawburst),
    .rxawvalid(wb_bram_rxawvalid),
    .rxawready(wb_bram_rxawready),
    .rxwid(wb_bram_rxwid),
    .rxwdata(wb_bram_rxwdata),
    .rxwstrb(wb_bram_rxwstrb),
    .rxwlast(wb_bram_rxwlast),
    .rxwvalid(wb_bram_rxwvalid),
    .rxwready(wb_bram_rxwready),
    .rxbid(wb_bram_rxbid),
    .rxbresp(wb_bram_rxbresp),
    .rxbvalid(wb_bram_rxbvalid),
    .rxbready(wb_bram_rxbready),
    .rxarid(wb_bram_rxarid),
    .rxaraddr({17'b0, wb_bram_rxaraddr[14:0]}),
    .rxarlen(wb_bram_rxarlen),
    .rxarsize(wb_bram_rxarsize),
    .rxarburst(wb_bram_rxarburst),
    .rxarvalid(wb_bram_rxarvalid),
    .rxarready(wb_bram_rxarready),
    .rxrid(wb_bram_rxrid),
    .rxrdata(wb_bram_rxrdata),
    .rxrresp(wb_bram_rxrresp),
    .rxrlast(wb_bram_rxrlast),
    .rxrvalid(wb_bram_rxrvalid),
    .rxrready(wb_bram_rxrready),

    .BRAM_IN_clk(wb_clk),
    .BRAM_IN_rst(wb_rst),
    .BRAM_IN_en(wb_en),
    .BRAM_IN_addr(wb_addr),
    .BRAM_IN_din(wb_din),
    .BRAM_IN_we(wb_we),
    .BRAM_IN_dout(wb_dout)
);

my_axi_bram_output #(
    .AXI_ADDR_WIDTH(32),
    .AXI_ID_WIDTH(1),
    .DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(13)
) u_output_bram (
    .clk(output_bram_clk),
    .rstnn(output_bram_rstnn),
    .rxawid(output_bram_rxawid),
    .rxawaddr({19'b0, output_bram_rxawaddr[12:0]}),
    .rxawlen(output_bram_rxawlen),
    .rxawsize(output_bram_rxawsize),
    .rxawburst(output_bram_rxawburst),
    .rxawvalid(output_bram_rxawvalid),
    .rxawready(output_bram_rxawready),
    .rxwid(output_bram_rxwid),
    .rxwdata(output_bram_rxwdata),
    .rxwstrb(output_bram_rxwstrb),
    .rxwlast(output_bram_rxwlast),
    .rxwvalid(output_bram_rxwvalid),
    .rxwready(output_bram_rxwready),
    .rxbid(output_bram_rxbid),
    .rxbresp(output_bram_rxbresp),
    .rxbvalid(output_bram_rxbvalid),
    .rxbready(output_bram_rxbready),
    .rxarid(output_bram_rxarid),
    .rxaraddr({19'b0, output_bram_rxaraddr[12:0]}),
    .rxarlen(output_bram_rxarlen),
    .rxarsize(output_bram_rxarsize),
    .rxarburst(output_bram_rxarburst),
    .rxarvalid(output_bram_rxarvalid),
    .rxarready(output_bram_rxarready),
    .rxrid(output_bram_rxrid),
    .rxrdata(output_bram_rxrdata),
    .rxrresp(output_bram_rxrresp),
    .rxrlast(output_bram_rxrlast),
    .rxrvalid(output_bram_rxrvalid),
    .rxrready(output_bram_rxrready),

    .BRAM_IN_clk(out_clk),
    .BRAM_IN_rst(out_rst),
    .BRAM_IN_en(out_en),
    .BRAM_IN_addr(out_addr),
    .BRAM_IN_din(out_din),
    .BRAM_IN_we(out_we),
    .BRAM_IN_dout(out_dout)
);

eMamba_IP #(
    .C_S_AXI_ID_WIDTH(1),
    .C_S_AXI_DATA_WIDTH(32),
    .C_S_AXI_ADDR_WIDTH(15)
) my_emamba_ip (
    .BRAM_IN_clk(in_clk),
    .BRAM_IN_rst(in_rst),
    .BRAM_IN_en(in_en),
    .BRAM_IN_addr(in_addr),
    .BRAM_IN_din(in_din),
    .BRAM_IN_we(in_we),
    .BRAM_IN_dout(in_dout),

    .BRAM_WB_clk(wb_clk),
    .BRAM_WB_rst(wb_rst),
    .BRAM_WB_en(wb_en),
    .BRAM_WB_addr(wb_addr),
    .BRAM_WB_din(wb_din),
    .BRAM_WB_we(wb_we),
    .BRAM_WB_dout(wb_dout),

    .BRAM_OUT_clk(out_clk),
    .BRAM_OUT_rst(out_rst),
    .BRAM_OUT_en(out_en),
    .BRAM_OUT_addr(out_addr),
    .BRAM_OUT_din(out_din),
    .BRAM_OUT_we(out_we),
    .BRAM_OUT_dout(out_dout),

    .s_axi_aclk(eMamba_IP_clk),
    .s_axi_aresetn(eMamba_IP_rstnn),
    .s_axi_awid(eMamba_IP_rx4awid),
    
//    .s_axi_awaddr(eMamba_IP_rx4awaddr[14:0]),
    .s_axi_awaddr({4'b0, eMamba_IP_rx4awaddr[10:0]}),
    
    .s_axi_awlen(eMamba_IP_rx4awlen),
    .s_axi_awsize(eMamba_IP_rx4awsize),
    .s_axi_awburst(eMamba_IP_rx4awburst),
    .s_axi_awvalid(eMamba_IP_rx4awvalid),
    .s_axi_awready(eMamba_IP_rx4awready),
    .s_axi_wdata(eMamba_IP_rx4wdata),
    .s_axi_wstrb(eMamba_IP_rx4wstrb),
    .s_axi_wlast(eMamba_IP_rx4wlast),
    .s_axi_wvalid(eMamba_IP_rx4wvalid),
    .s_axi_wready(eMamba_IP_rx4wready),
    .s_axi_bid(eMamba_IP_rx4bid),
    .s_axi_bresp(eMamba_IP_rx4bresp),
    .s_axi_bvalid(eMamba_IP_rx4bvalid),
    .s_axi_bready(eMamba_IP_rx4bready),
    .s_axi_arid(eMamba_IP_rx4arid),
    
//    .s_axi_araddr(eMamba_IP_rx4araddr[14:0]),
    .s_axi_araddr({4'b0, eMamba_IP_rx4araddr[10:0]}),
    
    .s_axi_arlen(eMamba_IP_rx4arlen),
    .s_axi_arsize(eMamba_IP_rx4arsize),
    .s_axi_arburst(eMamba_IP_rx4arburst),
    .s_axi_arvalid(eMamba_IP_rx4arvalid),
    .s_axi_arready(eMamba_IP_rx4arready),
    .s_axi_rid(eMamba_IP_rx4rid),
    .s_axi_rdata(eMamba_IP_rx4rdata),
    .s_axi_rresp(eMamba_IP_rx4rresp),
    .s_axi_rlast(eMamba_IP_rx4rlast),
    .s_axi_rvalid(eMamba_IP_rx4rvalid),
    .s_axi_rready(eMamba_IP_rx4rready),
    .s_axi_awlock(1'b0), .s_axi_awcache(4'b0),
    .s_axi_awprot(3'b0), .s_axi_awqos(4'b0), .s_axi_awregion(4'b0),
    .s_axi_awuser(0), .s_axi_wuser(0), .s_axi_buser(),
    .s_axi_arlock(1'b0), .s_axi_arcache(4'b0),
    .s_axi_arprot(3'b0), .s_axi_arqos(4'b0), .s_axi_arregion(4'b0),
    .s_axi_aruser(0), .s_axi_ruser()
);

