`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2024 09:57:49 PM
// Design Name: 
// Module Name: S_AXI
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


	module S_AXI #
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

		// Width of ID for for write address, write data, read address and read data
		parameter integer C_S_AXI_ID_WIDTH		= 1,
		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 15,
		// Width of optional user defined signal in write address channel
		parameter integer C_S_AXI_AWUSER_WIDTH	= 0,
		// Width of optional user defined signal in read address channel
		parameter integer C_S_AXI_ARUSER_WIDTH	= 0,
		// Width of optional user defined signal in write data channel
		parameter integer C_S_AXI_WUSER_WIDTH	= 0,
		// Width of optional user defined signal in read data channel
		parameter integer C_S_AXI_RUSER_WIDTH	= 0,
		// Width of optional user defined signal in write response channel
		parameter integer C_S_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here
		output wire ps_start,
		
		input wire eMamba_start,
		// output wire ram_ready,   // [J-AXI Conn.] 이번 클럭에 dOut 을 받을 수 있는가 (-> U_eMamba.m_ready)
		// [J-EXT-BRAM-OUT] ↑ 삭제 : dOut 이 S_AXI 로 안 오니 "받을 수 있나" 를 S_AXI 가 답할 이유가 없다 (eMamba_IP.out_ready 로 이동)

		// Initial Input
		// output logic signed [DATA_WIDTH * NUM_CHANNEL * NUM_HEIGHT * NUM_WIDTH - 1:0] dIn, // 1x5x8x8
		// [J-EXT-BRAM] ↑ 삭제 : ram[1..80] 을 병렬로 뽑아 U_eMamba 에 꽂던 포트.
		//               입력 프레임은 BD 의 BRAM(axi_bram_ctrl_0) 에 있고 eMamba_IP.BRAM_PORTB 가 직접 읽는다.
		//               S_AXI 는 이제 ctrl(word 0) / weight(word 81..) 만 담당한다. (dOut 도 [J-EXT-BRAM-OUT] 에서 BRAM_OUT 으로 나갔다)

		// 1. Patchembedding
		// output logic signed [DATA_WIDTH * NUM_DIM * NUM_DIM - 1:0] patch_weight, // 20x20
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] patch_bias, // 20

		// // ----- 1st MAMBA Block ----- //
		// // 2. LightNorm
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_weight, // 20
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_bias,   // 20

		// // 3-1. Linear expand x1
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_x1_weight, // 40x20
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_x1_bias,             // 40

		// // 3-2. Linear expand z1
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_z1_weight, // 40x20
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_z1_bias,             // 40

		// // 4. Convolution 1D
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_ED - 1:0] conv1d_weight, // 40x40
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] conv1d_bias,             // 40

		// // 5. SSM
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_N - 1:0] matrix_A, // 40x8
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] matrix_D, // 40

		// // Linear expand deltaBC
		// output logic signed [DATA_WIDTH * NUM_DBC * NUM_ED - 1:0] linEx_dBC_weight, // 48x40

		// // Linear expand delta
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_DELTA - 1:0] linEx_delta_weight, // 40x32
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_delta_bias, // 40

		// // 7. Linear contract
		// output logic signed [DATA_WIDTH * NUM_DIM * NUM_ED - 1:0] linCont_weight, // 20x40
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] linCont_bias, // 20

		// // ----- 2nd MAMBA Block ----- //
		// // 2. LightNorm
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_2nd_weight, // 20
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_2nd_bias,   // 20

		// // 3-1. Linear expand x1
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_x1_2nd_weight, // 40x20
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_x1_2nd_bias,             // 40

		// // 3-2. Linear expand z1
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_z1_2nd_weight, // 40x20
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_z1_2nd_bias,             // 40

		// // 4. Convolution 1D
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_ED - 1:0] conv1d_2nd_weight, // 40x40
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] conv1d_2nd_bias,             // 40

		// // 5. SSM
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_N - 1:0] matrix_A_2nd, // 40x8
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] matrix_D_2nd, // 40

		// // Linear expand deltaBC
		// output logic signed [DATA_WIDTH * NUM_DBC * NUM_ED - 1:0] linEx_dBC_2nd_weight, // 48x40

		// // Linear expand delta
		// output logic signed [DATA_WIDTH * NUM_ED * NUM_DELTA - 1:0] linEx_delta_2nd_weight, // 40x32
		// output logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_delta_2nd_bias, // 40

		// // 7. Linear contract
		// output logic signed [DATA_WIDTH * NUM_DIM * NUM_ED - 1:0] linCont_2nd_weight, // 20x40
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] linCont_2nd_bias, // 20

		// // ----- Outputhead ----- //
		// // LightNorm
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] OH_lightNorm_weight, // 20
		// output logic signed [DATA_WIDTH * NUM_DIM - 1:0] OH_lightNorm_bias,   // 20

		// // Linear expand 57
		// output logic signed [DATA_WIDTH * NUM_CLASS * NUM_DIM - 1:0] OH_linEx_weight, // 57x20
		// output logic signed [DATA_WIDTH * NUM_CLASS - 1:0] OH_linEx_bias, // 57

		// Final Output
		// input logic signed [DATA_WIDTH * NUM_CLASS - 1:0] dOut, // Class 57
		// input wire m_valid,
		// input wire [((NUM_SEQLEN > 1) ? $clog2(NUM_SEQLEN) : 1)-1:0] dOut_seq_idx, // [J-AXI Conn.] 4 -> SEQ_W(NUM_SEQLEN)
		// [J-EXT-BRAM-OUT] ↑ 세 포트 삭제 : 결과는 eMamba_IP.BRAM_OUT 이 BD 의 출력 BRAM 에 직접 쓴다.
		//                  frame_done 만 남긴다 : ctrl word 0 bit 15 로 PS 에 "프레임 끝" 을 알리는 건 여전히 S_AXI 의 일.
		input wire frame_done,   // [J-AXI Conn.] framem_valid -> frame_done

		output wire wb_load, // output : wb가 준비되었어라고 cpu가 적어주는거 wb_broadcaster에 전달해야해.
		input wire wb_done, // input : wb를 각 모듈로 전부 넘겼는지 cpu에게 알려줄 준비.
		// output [8*1024-1:0] byte_ram_out,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write Address ID
		input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_AWID,
		// Write address
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		input wire [7 : 0] S_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		input wire [2 : 0] S_AXI_AWSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		input wire [1 : 0] S_AXI_AWBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		input wire  S_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		input wire [3 : 0] S_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each
    // write transaction.
		input wire [3 : 0] S_AXI_AWQOS,
		// Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
		input wire [3 : 0] S_AXI_AWREGION,
		// Optional User-defined signal in the write address channel.
		input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] S_AXI_AWUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid write address and
    // control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
		output wire  S_AXI_AWREADY,
		// Write Data
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write last. This signal indicates the last transfer
    // in a write burst.
		input wire  S_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		input wire [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
		// Write valid. This signal indicates that valid write
    // data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    // can accept the write data.
		output wire  S_AXI_WREADY,
		// Response ID tag. This signal is the ID tag of the
    // write response.
		output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_BID,
		// Write response. This signal indicates the status
    // of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Optional User-defined signal in the write response channel.
		output wire [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
		// Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    // can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address ID. This signal is the identification
    // tag for the read address group of signals.
		input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_ARID,
		// Read address. This signal indicates the initial
    // address of a read burst transaction.
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		input wire [7 : 0] S_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		input wire [2 : 0] S_AXI_ARSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		input wire [1 : 0] S_AXI_ARBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		input wire  S_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		input wire [3 : 0] S_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each
    // read transaction.
		input wire [3 : 0] S_AXI_ARQOS,
		// Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
		input wire [3 : 0] S_AXI_ARREGION,
		// Optional User-defined signal in the read address channel.
		input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] S_AXI_ARUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid read address and
    // control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
		output wire  S_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
		output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_RID,
		// Read Data
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of
    // the read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read last. This signal indicates the last transfer
    // in a read burst.
		output wire  S_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		output wire [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
		// Read valid. This signal indicates that the channel
    // is signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    // accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4FULL signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg [C_S_AXI_BUSER_WIDTH-1 : 0] 	axi_buser;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rlast;
	reg [C_S_AXI_RUSER_WIDTH-1 : 0] 	axi_ruser;
	reg  	axi_rvalid;
	// aw_wrap_en determines wrap boundary and enables wrapping
	wire aw_wrap_en;
	// ar_wrap_en determines wrap boundary and enables wrapping
	wire ar_wrap_en;
	// aw_wrap_size is the size of the write transfer, the
	// write address wraps to a lower address if upper address
	// limit is reached
	wire [31:0]  aw_wrap_size ; 
	// ar_wrap_size is the size of the read transfer, the
	// read address wraps to a lower address if upper address
	// limit is reached
	wire [31:0]  ar_wrap_size ; 
	// The axi_awv_awr_flag flag marks the presence of write address valid
	reg axi_awv_awr_flag;
	//The axi_arv_arr_flag flag marks the presence of read address valid
	reg axi_arv_arr_flag; 
	// The axi_awlen_cntr internal write address counter to keep track of beats in a burst transaction
	reg [7:0] axi_awlen_cntr;
	//The axi_arlen_cntr internal read address counter to keep track of beats in a burst transaction
	reg [7:0] axi_arlen_cntr;
	reg [1:0] axi_arburst;
	reg [1:0] axi_awburst;
	reg [7:0] axi_arlen;
	reg [7:0] axi_awlen;
	//local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	//ADDR_LSB is used for addressing 32/64 bit registers/memories
	//ADDR_LSB = 2 for 32 bits (n downto 2) 
	//ADDR_LSB = 3 for 42 bits (n downto 3)

	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32)+ 1;
	localparam integer OPT_MEM_ADDR_BITS = 7;
	localparam integer USER_NUM_MEM = 1;
	//----------------------------------------------
	//-- Signals for user logic memory space example
	//------------------------------------------------
	wire [(C_S_AXI_ADDR_WIDTH-ADDR_LSB-1) :0] mem_address;
//	wire [USER_NUM_MEM-1:0] mem_select;
	reg [C_S_AXI_DATA_WIDTH-1:0] mem_data_out;

	genvar i;
	genvar j;
	genvar mem_byte_index;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY		= axi_wready;
	assign S_AXI_BRESP		= axi_bresp;
	assign S_AXI_BUSER		= axi_buser;
	assign S_AXI_BVALID		= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA		= axi_rdata;
	assign S_AXI_RRESP		= axi_rresp;
	assign S_AXI_RLAST		= axi_rlast;
	assign S_AXI_RUSER		= axi_ruser;
	assign S_AXI_RVALID		= axi_rvalid;
	assign S_AXI_BID 		= S_AXI_AWID;
	assign S_AXI_RID 		= S_AXI_ARID;
	assign aw_wrap_size 	= (C_S_AXI_DATA_WIDTH/8 * (axi_awlen)); 
	assign ar_wrap_size 	= (C_S_AXI_DATA_WIDTH/8 * (axi_arlen)); 
	assign aw_wrap_en 		= ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
	assign ar_wrap_en 		= ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;

	// Implement axi_awready generation

	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= #1 1'b0;
	      axi_awv_awr_flag <= #1 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag)
	        begin
	          // slave is ready to accept an address and
	          // associated control signals
	          axi_awready <= #1 1'b1;
	          axi_awv_awr_flag  <= #1 1'b1; 
	          // used for generation of bresp() and bvalid
	        end
	      else if (S_AXI_WLAST && axi_wready)          
	      // preparing to accept next address after current write burst tx completion
	        begin
	          axi_awv_awr_flag  <= #1 1'b0;
	        end
	      else        
	        begin
	          axi_awready <= #1 1'b0;
	        end
	    end 
	end       
	// Implement axi_awaddr latching

	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= #1 0;
	      axi_awlen_cntr <= #1 0;
	      axi_awburst <= #1 0;
	      axi_awlen <= #1 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag)
	        begin
	          // address latching 
	          axi_awaddr <= #1 S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH - 1:0];  
	           axi_awburst <= #1 S_AXI_AWBURST; 
	           axi_awlen <= #1 S_AXI_AWLEN;     
	          // start address of transfer
	          axi_awlen_cntr <= #1 0;
	        end   
	      else if((axi_awlen_cntr <= axi_awlen) && axi_wready && S_AXI_WVALID)        
	        begin

	          axi_awlen_cntr <= #1 axi_awlen_cntr + 1;

	          case (axi_awburst)
	            2'b00: // fixed burst
	            // The write address for all the beats in the transaction are fixed
	              begin
	                axi_awaddr <= #1 axi_awaddr;          
	                //for awsize = 4 bytes (010)
	              end   
	            2'b01: //incremental burst
	            // The write address for all the beats in the transaction are increments by awsize
	              begin
	                axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= #1 axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                //awaddr aligned to 4 byte boundary
	                axi_awaddr[ADDR_LSB-1:0]  <= #1 {ADDR_LSB{1'b0}};   
	                //for awsize = 4 bytes (010)
	              end   
	            2'b10: //Wrapping burst
	            // The write address wraps when the address reaches wrap boundary 
	              if (aw_wrap_en)
	                begin
	                  axi_awaddr <= #1 (axi_awaddr - aw_wrap_size); 
	                end
	              else
	                begin
	                  axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= #1 axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                  axi_awaddr[ADDR_LSB-1:0]  <= #1 {ADDR_LSB{1'b0}}; 
	                end                      
	            default: //reserved (incremental burst for example)
	              begin
	                axi_awaddr <= #1 axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
	                //for awsize = 4 bytes (010)
	              end
	          endcase              
	        end
	    end 
	end       
	// Implement axi_wready generation

	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= #1 1'b0;
	    end 
	  else
	    begin    
	      if ( ~axi_wready && S_AXI_WVALID && axi_awv_awr_flag)
	        begin
	          // slave can accept the write data
	          axi_wready <= #1 1'b1;
	        end
	      //else if (~axi_awv_awr_flag)
	      else if (S_AXI_WLAST && axi_wready)
	        begin
	          axi_wready <= #1 1'b0;
	        end
	    end 
	end       
	// Implement write response logic generation

	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid <= #1 0;
	      axi_bresp <= #1 2'b0;
	      axi_buser <= #1 0;
	    end 
	  else
	    begin    
	      if (axi_awv_awr_flag && axi_wready && S_AXI_WVALID && ~axi_bvalid && S_AXI_WLAST )
	        begin
	          axi_bvalid <= #1 1'b1;
	          axi_bresp  <= #1 2'b0; 
	          // 'OKAY' response 
	        end                   
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	          //check if bready is asserted while bvalid is high) 
	          //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= #1 1'b0; 
	            end  
	        end
	    end
	 end   
	// Implement axi_arready generation

	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= #1 1'b0;
	      axi_arv_arr_flag <= #1 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag)
	        begin
	          axi_arready <= #1 1'b1;
	          axi_arv_arr_flag <= #1 1'b1;
	        end
	      else if (axi_rvalid && S_AXI_RREADY && axi_arlen_cntr == axi_arlen)
	      // preparing to accept next address after current read completion
	        begin
	          axi_arv_arr_flag  <= #1 1'b0;
	        end
	      else        
	        begin
	          axi_arready <= #1 1'b0;
	        end
	    end 
	end       
	// Implement axi_araddr latching

	//This process is used to latch the address when both 
	//S_AXI_ARVALID and S_AXI_RVALID are valid. 
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_araddr <= #1 0;
	      axi_arlen_cntr <= #1 0;
	      axi_arburst <= #1 0;
	      axi_arlen <= #1 0;
	      axi_rlast <= #1 1'b0;
	      axi_ruser <= #1 0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag)
	        begin
	          // address latching 
	          axi_araddr <= #1 S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH - 1:0]; 
	          axi_arburst <= #1 S_AXI_ARBURST; 
	          axi_arlen <= #1 S_AXI_ARLEN;     
	          // start address of transfer
	          axi_arlen_cntr <= #1 0;
	          axi_rlast <= #1 1'b0;
	        end   
	      else if((axi_arlen_cntr <= axi_arlen) && axi_rvalid && S_AXI_RREADY)        
	        begin
	         
	          axi_arlen_cntr <= #1 axi_arlen_cntr + 1;
	          axi_rlast <= #1 1'b0;
	        
	          case (axi_arburst)
	            2'b00: // fixed burst
	             // The read address for all the beats in the transaction are fixed
	              begin
	                axi_araddr       <= #1 axi_araddr;        
	                //for arsize = 4 bytes (010)
	              end   
	            2'b01: //incremental burst
	            // The read address for all the beats in the transaction are increments by awsize
	              begin
	                axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= #1 axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
	                //araddr aligned to 4 byte boundary
	                axi_araddr[ADDR_LSB-1:0]  <= #1 {ADDR_LSB{1'b0}};   
	                //for awsize = 4 bytes (010)
	              end   
	            2'b10: //Wrapping burst
	            // The read address wraps when the address reaches wrap boundary 
	              if (ar_wrap_en) 
	                begin
	                  axi_araddr <= #1 (axi_araddr - ar_wrap_size); 
	                end
	              else 
	                begin
	                axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= #1 axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
	                //araddr aligned to 4 byte boundary
	                axi_araddr[ADDR_LSB-1:0]  <= #1 {ADDR_LSB{1'b0}};   
	                end                      
	            default: //reserved (incremental burst for example)
	              begin
	                axi_araddr <= #1 axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
	                //for arsize = 4 bytes (010)
	              end
	          endcase              
	        end
	      else if((axi_arlen_cntr == axi_arlen) && ~axi_rlast && axi_arv_arr_flag )   
	        begin
	          axi_rlast <= #1 1'b1;
	        end          
	      else if (S_AXI_RREADY)   
	        begin
	          axi_rlast <= #1 1'b0;
	        end          
	    end 
	end       
	// Implement axi_arvalid generation

	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= #1 0;
	      axi_rresp  <= #1 0;
	    end 
	  else
	    begin    
	      if (axi_arv_arr_flag && ~axi_rvalid)
	        begin
	          axi_rvalid <= #1 1'b1;
	          axi_rresp  <= #1 2'b0; 
	          // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          axi_rvalid <= #1 1'b0;
	        end            
	    end
	end    
	// ------------------------------------------
	// Ignore S_AXI_WSTRB
	// ------------------------------------------

	// reg [C_S_AXI_DATA_WIDTH - 1:0] ram [0:(2**(C_S_AXI_ADDR_WIDTH-ADDR_LSB))-1];
	reg [C_S_AXI_DATA_WIDTH - 1:0] ram [0:1];

//	assign mem_address = (axi_arv_arr_flag? axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]:(axi_awv_awr_flag? axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]:0));
	assign mem_address = (axi_arv_arr_flag? axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] : (axi_awv_awr_flag? axi_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] : 0));

	wire mem_rden;
	wire mem_wren;

	assign mem_wren = axi_wready && S_AXI_WVALID ;
	assign mem_rden = axi_arv_arr_flag ; //& ~axi_rvalid

	// [J-AXI Conn.] ram write 우선순위 1(mem_wren)·2(eMamba_start) 가 이길 클럭에는 토큰을 받지 않는다
	// assign ram_ready = S_AXI_ARESETN                              // [J-AXI Conn.]
	//                 && !eMamba_start                              // [J-AXI Conn.]
	//                 && !(mem_wren && (mem_address < 'd21440));    // [J-AXI Conn.]
	// [J-EXT-BRAM-OUT] 삭제. 그 조건("AXI 가 ram[] 을 쓰는 클럭엔 토큰을 받지 마라") 은
	//   dOut 과 AXI write 가 같은 배열 ram[] 을 두고 경쟁해서 필요했던 것. 지금 dOut 은 다른 BRAM 으로 가니 경쟁이 없다.
	//   (eMamba_IP.v 의 out_ready = S_AXI_ARESETN && !eMamba_start 가 그 자리를 대신)

	wire [C_S_AXI_DATA_WIDTH-1:0] data_in ;
	wire [C_S_AXI_DATA_WIDTH-1:0] data_out;

	assign data_in  = S_AXI_WDATA;
	assign data_out = ram[mem_address];

	always @( posedge S_AXI_ACLK ) begin
		// if (mem_wren && (mem_address < 'd21440)) begin
		if (mem_wren && (mem_address < 'd2)) begin
			ram[mem_address] <= #1 data_in;
		end else if (S_AXI_ARESETN == 1'b0 || eMamba_start) begin //|| (mem_rden && (mem_address == 'h0) && ram[0][15])) begin
			ram[0] <= #1 'd0;
		// end else if (m_valid) begin
		// 	// One frame data output
		// 	// 456bit = 14.25 * 4byte < 15 * 4byte
		// 	// 15byte * 16 = 240
		// 	// 5120 ~ 5134 : dOut seqlength 0
		// 	// 5135 ~ 5149 : dOut seqlength 1
		// 	// 5150 ~ 5164 : dOut seqlength 2
		// 	// 5165 ~ 5179 : dOut seqlength 3
		// 	// 5180 ~ 5194 : dOut seqlength 4
		// 	// 5195 ~ 5209 : dOut seqlength 5
		// 	// 5210 ~ 5224 : dOut seqlength 6
		// 	// 5225 ~ 5239 : dOut seqlength 7
		// 	// 5240 ~ 5254 : dOut seqlength 8
		// 	// 5255 ~ 5269 : dOut seqlength 9
		// 	// 5270 ~ 5284 : dOut seqlength 10
		// 	// 5285 ~ 5299 : dOut seqlength 11
		// 	// 5300 ~ 5314 : dOut seqlength 12
		// 	// 5315 ~ 5329 : dOut seqlength 13
		// 	// 5330 ~ 5344 : dOut seqlength 14
		// 	// 5345 ~ 5359 : dOut seqlength 15
		// 	ram[5120 + dOut_seq_idx * 15 + 0]  <= dOut[0 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 1]  <= dOut[1 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 2]  <= dOut[2 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 3]  <= dOut[3 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 4]  <= dOut[4 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 5]  <= dOut[5 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 6]  <= dOut[6 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 7]  <= dOut[7 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 8]  <= dOut[8 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 9]  <= dOut[9 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 10] <= dOut[10 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 11] <= dOut[11 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 12] <= dOut[12 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 13] <= dOut[13 * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH];
		// 	ram[5120 + dOut_seq_idx * 15 + 14] <= {dOut_seq_idx, 4'h0, dOut[455:448]};
		// [J-EXT-BRAM-OUT] 삭제 (15 워드 동시 쓰기). eMamba_IP 가 같은 클럭에 BRAM_OUT 행 하나(64B) 로 쓴다.
		//   행의 word 14 에 {idx, 4'h0, class56} 태그도 그대로 넣어 둔다 (byte 57 = {idx, 4'b0}).
		//   word 5120..5359 창은 이제 빈 창 (읽으면 예전 값/미정). frame_done 분기는 m_valid 와 같은 클럭에 겹치지 않는다
		//   (U_Outputhead.frame_done_r 은 마지막 토큰 핸드셰이크 "다음" 클럭에 선다) 라 우선순위 변화 없음.
		end else begin
			if (frame_done) begin   // [J-AXI Conn.] framem_valid -> frame_done
				ram[0][15] <= #1 frame_done;   // [J-AXI Conn.]
			end
			ram[0][14] <= #1 wb_done; // [J-WB]
		end
	end    
	
	always @( posedge S_AXI_ACLK ) begin
		if ( S_AXI_ARESETN == 1'b0 ) begin                    // [J-unopt-reset]
			mem_data_out <= #1 '0;                            // [J-unopt-reset]
		end else if (mem_rden) begin                          // [J-unopt-reset] 기존 if 앞에 리셋 분기 추가
			mem_data_out <= #1 data_out;
		end
	end

	// // implement Block RAM(s)
	// generate 
	//   	for(i=0; i<= USER_NUM_MEM-1; i=i+1) begin:BRAM_GEN
	// 		wire mem_rden;
	// 		wire mem_wren;

	// 		assign mem_wren = axi_wready && S_AXI_WVALID ;

	// 		assign mem_rden = axi_arv_arr_flag ; //& ~axi_rvalid
	     
	// 		for(mem_byte_index=0; mem_byte_index<= (C_S_AXI_DATA_WIDTH/8-1); mem_byte_index=mem_byte_index+1) begin:BYTE_BRAM_GEN
	// 			wire [8-1:0] data_in ;
	// 			wire [8-1:0] data_out;
	// 			reg  [8-1:0] byte_ram [0 : 255];
				
	// 			//assigning 8 bit data
	// 			assign data_in  = S_AXI_WDATA[(mem_byte_index*8+7) -: 8];
	// 			assign data_out = byte_ram[mem_address];
				
	// 			always @( posedge S_AXI_ACLK ) begin
	// 				if (mem_wren && S_AXI_WSTRB[mem_byte_index]) begin
	// 					byte_ram[mem_address] <= data_in;
	// 				end   
	// 			end    
				
	// 			always @( posedge S_AXI_ACLK ) begin
	// 				if (mem_rden) begin
	// 					mem_data_out[i][(mem_byte_index*8+7) -: 8] <= data_out;
	// 				end
	// 			end

	// 			// Added by Jiyong
    //             for (j = 0; j < 1024; j = j + 1) begin
    //                 assign byte_ram_out[mem_byte_index*8 + C_S_AXI_DATA_WIDTH*j +: 8] = byte_ram[j];
    //             end
				
	//     	end
	//   	end
	// endgenerate
	//Output register or memory read data

	always @( mem_data_out, axi_rvalid)
	begin
	  if (axi_rvalid) 
	    begin
	      // Read address mux
	      axi_rdata <= #1 mem_data_out;
	    end   
	  else
	    begin
	      axi_rdata <= #1 32'h00000000;
	    end       
	end    

	// Add user logic here
	// Control signals
	assign ps_start = ram[0][31] & wb_done;
	assign wb_load  = ram[0][30];    // [J-WB]

	// Initial Input(Frame data)
	// 2560bit = 80 * 4-byte 
	// 1 ~ 80
	// generate
	// 	for (i = 0; i < 80; i = i + 1) begin
	// 		assign dIn[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1];
	// 	end
	// endgenerate

// 1. Patchembedding
	// weight
	// 3200bit = 100 * 4byte
	// 81 ~ 180
	// generate
	// 	for (i = 0; i < 100; i = i + 1) begin
	// 		assign patch_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 81];
	// 	end
	// endgenerate
	// // bias
	// // 160bit = 5 * 4byte
	// // 181 ~ 185
	// generate
	// 	for (i = 0; i < 5; i = i + 1) begin
	// 		assign patch_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 181];
	// 	end
	// endgenerate

	// // ----- 1st MAMBA Block ----- //
	// // 2. LightNorm
	// // weight
	// // 160bit = 5 * 4byte
	// // 186 ~ 190
	// // bias
	// // 160bit = 5 * 4byte
	// // 191 ~ 195
	// generate
	// 	for (i = 0; i < 5; i = i + 1) begin
	// 		assign lightNorm_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 186];
	// 		assign lightNorm_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 191];
	// 	end
	// endgenerate

	// // 3-1. Linear expand x1
	// // weight
	// // 6400bit = 200 * 4byte
	// // 196 ~ 395
	// generate
	// 	for (i = 0; i < 200; i = i + 1) begin
	// 		assign linEx_x1_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 196];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 396 ~ 405
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign linEx_x1_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 396];
	// 	end
	// endgenerate

	// // 3-2. Linear expand z1
	// // weight
	// // 6400bit = 200 * 4byte
	// // 406 ~ 605
	// generate
	// 	for (i = 0; i < 200; i = i + 1) begin
	// 		assign linEx_z1_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 406];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 606 ~ 615
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign linEx_z1_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 606];
	// 	end
	// endgenerate

	// // 4. Convolution 1D
	// // weight
	// // 12800bit = 400 * 4byte
	// // 1024 ~ 1423
	// generate
	// 	for (i = 0; i < 400; i = i + 1) begin
	// 		assign conv1d_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1024];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 1424 ~ 1433
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign conv1d_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1424];
	// 	end
	// endgenerate

	// // 5. SSM
	// // Matrix A
	// // 2560bit = 80 * 4byte
	// // 1434 ~ 1513
	// generate
	// 	for (i = 0; i < 80; i = i + 1) begin
	// 		assign matrix_A[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1434];
	// 	end
	// endgenerate
	// // Matrix D
	// // 320bit = 10 * 4byte
	// // 1514 ~ 1523
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign matrix_D[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1514];
	// 	end
	// endgenerate

	// // Linear expand deltaBC
	// // weight
	// // 15360bit = 480 * 4byte
	// // 1524 ~ 2003
	// generate
	// 	for (i = 0; i < 480; i = i + 1) begin
	// 		assign linEx_dBC_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 1524];
	// 	end
	// endgenerate

	// // Linear expand delta
	// // weight
	// // 10240bit = 320 * 4byte
	// // 2048 ~ 2367
	// generate
	// 	for (i = 0; i < 320; i = i + 1) begin
	// 		assign linEx_delta_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2048];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 2368 ~ 2377
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign linEx_delta_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2368];
	// 	end
	// endgenerate

	// // 7. Linear contract
	// // weight
	// // 6400bit = 200 * 4byte
	// // 2378 ~ 2577
	// generate
	// 	for (i = 0; i < 200; i = i + 1) begin
	// 		assign linCont_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2378];
	// 	end
	// endgenerate
	// // bias
	// // 160bit = 5 * 4byte
	// // 2578 ~ 2582
	// generate
	// 	for (i = 0; i < 5; i = i + 1) begin
	// 		assign linCont_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2578];
	// 	end
	// endgenerate

	// // ----- 2nd MAMBA Block ----- //
	// // 2. LightNorm
	// // weight
	// // 160bit = 5 * 4byte
	// // 2583 ~ 2587
	// // bias
	// // 160bit = 5 * 4byte
	// // 2588 ~ 2592
	// generate
	// 	for (i = 0; i < 5; i = i + 1) begin
	// 		assign lightNorm_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2583];
	// 		assign lightNorm_2nd_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2588];
	// 	end
	// endgenerate

	// // 3-1. Linear expand x1
	// // weight
	// // 6400bit = 200 * 4byte
	// // 2593 ~ 2792
	// generate
	// 	for (i = 0; i < 200; i = i + 1) begin
	// 		assign linEx_x1_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2593];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 2793 ~ 2802
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign linEx_x1_2nd_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2793];
	// 	end
	// endgenerate

	// // 3-2. Linear expand z1
	// // weight
	// // 6400bit = 200 * 4byte
	// // 2803 ~ 3002
	// generate
	// 	for (i = 0; i < 200; i = i + 1) begin
	// 		assign linEx_z1_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 2803];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 3003 ~ 3012
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign linEx_z1_2nd_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 3003];
	// 	end
	// endgenerate

	// // 4. Convolution 1D
	// // weight
	// // 12800bit = 400 * 4byte
	// // 3072 ~ 3471
	// generate
	// 	for (i = 0; i < 400; i = i + 1) begin
	// 		assign conv1d_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 3072];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 3472 ~ 3481
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign conv1d_2nd_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 3472];
	// 	end
	// endgenerate

	// // 5. SSM
	// // Matrix A
	// // 3012bit = 80 * 4byte
	// // 3482 ~ 3561
	// generate
	// 	for (i = 0; i < 80; i = i + 1) begin
	// 		assign matrix_A_2nd[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 3482];
	// 	end
	// endgenerate
	// // Matrix D
	// // 320bit = 10 * 4byte
	// // 3562 ~ 3571
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign matrix_D_2nd[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 3562];
	// 	end
	// endgenerate

	// // Linear expand deltaBC
	// // weight
	// // 15360bit = 480 * 4byte
	// // 3572 ~ 4051
	// generate
	// 	for (i = 0; i < 480; i = i + 1) begin
	// 		assign linEx_dBC_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 3572];
	// 	end
	// endgenerate

	// // Linear expand delta
	// // weight
	// // 10240bit = 320 * 4byte
	// // 4096 ~ 4415
	// generate
	// 	for (i = 0; i < 320; i = i + 1) begin
	// 		assign linEx_delta_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4096];
	// 	end
	// endgenerate
	// // bias
	// // 320bit = 10 * 4byte
	// // 4416 ~ 4425
	// generate
	// 	for (i = 0; i < 10; i = i + 1) begin
	// 		assign linEx_delta_2nd_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4416];
	// 	end
	// endgenerate

	// // 7. Linear contract
	// // weight
	// // 6400bit = 200 * 4byte
	// // 4426 ~ 4625
	// generate
	// 	for (i = 0; i < 200; i = i + 1) begin
	// 		assign linCont_2nd_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4426];
	// 	end
	// endgenerate
	// // bias
	// // 160bit = 5 * 4byte
	// // 4626 ~ 4630
	// generate
	// 	for (i = 0; i < 5; i = i + 1) begin
	// 		assign linCont_2nd_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4626];
	// 	end
	// endgenerate

	// // ----- Outputhead ----- //
	// // LightNorm
	// // weight
	// // 160bit = 5 * 4byte
	// // 4631 ~ 4635
	// // bias
	// // 160bit = 5 * 4byte
	// // 4636 ~ 4640
	// generate
	// 	for (i = 0; i < 5; i = i + 1) begin
	// 		assign OH_lightNorm_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4631];
	// 		assign OH_lightNorm_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4636];
	// 	end
	// endgenerate

	// // Linear expand 57
	// // wight
	// // 9120bit = 285 * 4byte
	// // 4641 ~ 4925
	// generate
	// 	for (i = 0; i < 285; i = i + 1) begin
	// 		assign OH_linEx_weight[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4641];
	// 	end
	// endgenerate
	// // bias
	// // 456bit = 14.25 * 4byte < 15 * 4byte
	// // 4926 ~ 4940
	// generate
	// 	for (i = 0; i < 14; i = i + 1) begin
	// 		assign OH_linEx_bias[i * C_S_AXI_DATA_WIDTH +: C_S_AXI_DATA_WIDTH] = ram[i + 4926];
	// 	end
	// 	// i == 15 / 1byte
	// 	assign OH_linEx_bias[455:448] = ram[4940][7:0];
	// endgenerate

	// User logic ends

	endmodule