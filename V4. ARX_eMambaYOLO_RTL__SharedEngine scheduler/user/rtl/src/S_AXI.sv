`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: S_AXI
// Description: eMambaYOLO_IP 의 제어 레지스터 (AXI4 slave). U_eMamba S_AXI 에서 가져와
//              AXI4 템플릿 부분은 그대로 두고, 사용자 레지스터를 eMambaYOLO (U_106 rtl/top) 용으로 새로 만들었다.
//
// 레지스터 (워드, WSTRB 무시 = 항상 32bit 전체 쓰기)
//   0x00 CTRL       [31] START    : 1 을 쓰면 WB_DONE 인 동안 ps_start 1 clk 펄스를 내고 0 으로 돌아온다
//                                   (펄스와 함께 FRAME_DONE, IN 슬롯, OUT 슬롯, 카운터가 비워진다)
//                   [30] WB_LOAD  : 0 -> 1 로 쓰면 WB 스트림을 byte 0 부터 다시 시작 (WB_DONE, WB 슬롯 비움)
//                   [15] FRAME_DONE (R, sticky; 0 을 써서 지울 수 있다)   [14] WB_DONE (R)
//                   (U_eMamba 때와 같은 자리 : bit31 start, bit30 wb_load, bit15 frame_done, bit14 wb_done)
//   0x04 STATUS (R) [1:0] IN_FULL  [3:2] WB_FULL  [5:4] P3_FULL  [7:6] P4_FULL  [9:8] P5_FULL  (bit k = 슬롯 k)
//                   [16] WB_DONE  [17] FRAME_DONE
//   0x08 IN_LEN0    IN 슬롯 0 / 1 에 넣은 바이트 수 (4 의 배수, <= 슬롯 크기). 슬롯이 비었을 때 쓰면 FULL 이 된다.
//   0x0C IN_LEN1
//   0x10 WB_LEN0    WB 슬롯 0 / 1, 같은 규칙
//   0x14 WB_LEN1
//   0x18 OUT_RELEASE (W) 1 을 쓴 비트의 OUT 슬롯을 비운다 (STATUS[9:4] 와 같은 순서 : [1:0] P3, [3:2] P4, [5:4] P5)
//                    (R) OUT FULL 6 bit
//   0x1C FRAME_COUNT (R) START 이후 끝난 프레임 수
//   0x20 WB_COUNT    (R) WB_LOAD 이후 보낸 WB 바이트 수 (끝 = 5,395,568)
//   0x24 SEQ         (R) [9:0] PC (시퀀서 프로그램 카운터)  [17:16] ACTIVE (엔진 0 vec / 1 GEMM / 2 DW / 3 scan)  [18] ACTIVE_V
//                       [19] BUSY (프레임 실행 중)  [20] OUT_FIFO_OVF (sticky)  [21] WB_OVF (부팅 바이트 초과, sticky)
//                       [31:24] BUF_FAULT (emy_buf 진단 8 bit, sticky OR). 아무 값이나 쓰면 sticky 비트가 지워진다.
//                       (v1 의 LAYER_DONE 자리; 공유 엔진에는 레이어 모듈이 없다)
//   0x28 PIX_COUNT   (R) START 이후 입력 링에 쓴 픽셀 수 (프레임당 409,600)
//   0x2C INFO        (R) {OUT_AW, WB_AW, IN_AW, 8'h02}  BRAM 주소 폭 (슬롯 = 2^(AW-1) B, emy_ip_core 헤더 참조); 버전 2 = 공유 엔진
//   0x30 IN_ROWS     (R) [15:0] 이번 프레임에 입력 링이 받은 행 수 (640 이면 프레임 입력 끝)
//   0x34 OUT_ROWS    (R) 이번 프레임에 BRAM_OUT 에 쓴 행 수 (끝 = 6,400 + 3,200 + 1,600; L21 Detect 헤드를 엔진에서 돌리는 이미지면 19,200 + 4,800 + 1,200, CPU_SEQUENCE §5;
//                       FILTER_EN 이면 헤드마다 후보 × 2 + END 행 1)
//   0x38 FILTER      (R/W) [0] FILTER_EN  [15:8] QTHR0 (P3)  [23:16] QTHR1 (P4)  [31:24] QTHR2 (P5) — signed int8 cls logit 문턱 (CPU_SEQUENCE §5;
//                       conf > 0.25 ⇔ −4 / −2 / −4, 리셋값 0xFCFEFC00). 1 이면 출력 어댑터가 문턱을 넘는 픽셀만 (META 행, box 행) 으로 내보내고
//                       프레임 끝에 헤드마다 END 행을 쓴다 (emy_out_adapter 헤더). [Jae 2026-10-21]
//                       [1] DET_EN: 후보당 DET 행 1 (head-math, B 안). [2] NMS_EN (DET_EN 과 함께): 어댑터가 NMS 까지 하고 검출 행 (0x03) 을
//                       헤드 0 슬롯으로, END 3 개 (헤드 0 count = 검출 수, 바이트 8-9 후보 수, 10-11 버린 후보). 값 0x..01 / 0x..03 / 0x..07.
//   0x40-0x5C CMD0-7 (R) 지금 실행 중인 명령 256 bit (CMD0 = bit 31:0; ENGINE_SPEC §5)
//
// CPU 순서
//   1. WB : CTRL = 1<<30. 그 뒤 부팅 스트림 = program.mem (1,024 줄 × 32 B = 32,768 B, 짧으면 0 으로 채움) 에 이어
//           engine_image.mem (198,992 줄 × 32 B, L00 .. L21; 줄 수는 engine_image.json total_lines) 을 청크로 : 비어 있는 슬롯 (0, 1, 0, 1 ...) 에 BRAM_WB 로 쓰고 WB_LENk 를 쓴다.
//           WB_DONE 이 뜰 때까지 (WB_COUNT 끝 = 32,768 + 198,992 × 32 = 6,400,512). 한 번만 (프레임마다 다시 보내지 않는다).
//   2. 프레임마다 CTRL = 1<<31 (START): 시퀀서가 0 번 줄부터 END 까지 한 프레임을 실행한다 (v1 과 달리 프레임이 자동으로
//      이어지지 않는다). 펄스 후 IN / OUT 슬롯 · 카운터 · 입력 링은 모두 비어 있다.
//   3. 그 프레임 동안 : IN 슬롯이 비면 프레임 바이트 (HWC, 3 B/pixel) 다음 청크를 넣고 IN_LENk (입력 링이 행 단위로 받고,
//             시퀀서가 소비한 행만 덮어쓴다 → L00 이 진행되는 만큼만 받는다).
//             OUT 슬롯이 차면 (STATUS) 그 슬롯을 읽고 OUT_RELEASE. 스트림마다 슬롯 0, 1, 0, 1 ... 순서 (P3 → P4 → P5 순으로 나온다).
//             프레임 끝 = FRAME_COUNT 증가 (FRAME_DONE). 다음 프레임은 다시 START 부터.
//////////////////////////////////////////////////////////////////////////////////


	module S_AXI #
	(
		// Users to add parameters here
		parameter integer IN_BRAM_ADDR_W  = 15,   // BRAM_IN  byte address bits
		parameter integer WB_BRAM_ADDR_W  = 15,   // BRAM_WB  byte address bits
		parameter integer OUT_BRAM_ADDR_W = 13,   // BRAM_OUT byte address bits
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
		output wire ps_start,              // -> eMambaYOLO ps_start (1 clk)
		output wire wb_restart,            // -> WB 스트림 재시작 (1 clk)

		output wire [31:0] in_len0,        // IN 슬롯 바이트 수
		output wire [31:0] in_len1,
		output wire [1:0]  in_full,
		input  wire [1:0]  in_take,        // 슬롯을 다 읽었다 (FULL 해제)

		output wire [31:0] wb_len0,
		output wire [31:0] wb_len1,
		output wire [1:0]  wb_full,
		input  wire [1:0]  wb_take,

		output wire [5:0]  out_full,       // {P5, P4, P3} x 슬롯 {1, 0}
		input  wire [5:0]  out_fill,       // 슬롯을 다 썼다 (FULL 설정)

		input  wire        wb_done,
		input  wire [31:0] wb_count,
		input  wire        pix_fire,
		input  wire        frame_done,
		// shared-engine debug (ENGINE_SPEC §10)
		input  wire        busy,
		input  wire [9:0]  pc_dbg,
		input  wire [255:0] cmd_dbg,
		input  wire [1:0]  active_dbg,
		input  wire        active_v_dbg,
		input  wire [15:0] in_rows,
		input  wire [7:0]  buf_fault,
		input  wire        out_fifo_overflow,
		input  wire        wb_overflow,
		input  wire [31:0] out_rows,
		output wire        filt_en,          // FILTER[0]
		output wire        det_en,           // FILTER[1]  DET mode (one DET row per candidate)
		output wire        nms_en,           // FILTER[2]  NMS mode (with DET: NMS in the adapter, detection rows + END)
		output wire [7:0]  qthr0,            // FILTER[15:8]  (signed int8)
		output wire [7:0]  qthr1,            // FILTER[23:16]
		output wire [7:0]  qthr2,            // FILTER[31:24]
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
	// User registers (S_AXI_WSTRB ignored)
	// ------------------------------------------
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_CTRL        = 'd0;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_STATUS      = 'd1;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_IN_LEN0     = 'd2;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_IN_LEN1     = 'd3;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_WB_LEN0     = 'd4;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_WB_LEN1     = 'd5;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_OUT_RELEASE = 'd6;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_FRAME_COUNT = 'd7;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_WB_COUNT    = 'd8;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_SEQ         = 'd9;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_PIX_COUNT   = 'd10;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_INFO        = 'd11;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_IN_ROWS     = 'd12;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_OUT_ROWS    = 'd13;
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_FILTER      = 'd14;   // 0x38
	localparam [C_S_AXI_ADDR_WIDTH-ADDR_LSB-1:0] REG_CMD0        = 'd16;   // 0x40 .. 0x5C

	assign mem_address = (axi_arv_arr_flag? axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] : (axi_awv_awr_flag? axi_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB] : 0));

	wire mem_rden;
	wire mem_wren;

	assign mem_wren = axi_wready && S_AXI_WVALID ;
	assign mem_rden = axi_arv_arr_flag ; //& ~axi_rvalid

	wire [C_S_AXI_DATA_WIDTH-1:0] data_in;
	reg  [C_S_AXI_DATA_WIDTH-1:0] data_out;

	assign data_in = S_AXI_WDATA;

	reg        start_req;      // CTRL[31]
	reg        wb_load;        // CTRL[30]
	reg        wb_load_d;
	reg        frame_done_s;   // CTRL[15]
	wire [31:0] in_len_r [0:1];
	wire [31:0] wb_len_r [0:1];
	wire [1:0]  in_full_r;
	wire [1:0]  wb_full_r;
	reg [5:0]  out_full_r;
	reg [31:0] frame_cnt;
	reg [31:0] pix_cnt;
	reg [7:0]  buf_fault_s;    // sticky OR of emy_buf faults
	reg        out_ovf_s, wb_ovf_s;

	wire wr_ctrl    = mem_wren && (mem_address == REG_CTRL);
	wire wr_in0     = mem_wren && (mem_address == REG_IN_LEN0);
	wire wr_in1     = mem_wren && (mem_address == REG_IN_LEN1);
	wire wr_wb0     = mem_wren && (mem_address == REG_WB_LEN0);
	wire wr_wb1     = mem_wren && (mem_address == REG_WB_LEN1);
	wire wr_release = mem_wren && (mem_address == REG_OUT_RELEASE);
	wire wr_seq     = mem_wren && (mem_address == REG_SEQ);
	wire wr_filter  = mem_wren && (mem_address == REG_FILTER);
	reg [31:0] filter_r;   // [Jae 2026-10-21] FILTER register
	always @( posedge S_AXI_ACLK ) begin
		if (S_AXI_ARESETN == 1'b0) filter_r <= #1 32'hFCFEFC00;
		else if (wr_filter) filter_r <= #1 data_in;
	end
	assign filt_en = filter_r[0];
	assign det_en  = filter_r[1];
	assign nms_en  = filter_r[2];   // [Jae 2026-10-21] NMS mode
	assign qthr0   = filter_r[15:8];
	assign qthr1   = filter_r[23:16];
	assign qthr2   = filter_r[31:24];

	assign ps_start   = start_req & wb_done;
	assign wb_restart = wb_load & ~wb_load_d;

	// CTRL
	always @( posedge S_AXI_ACLK ) begin
		if (S_AXI_ARESETN == 1'b0) begin
			start_req    <= #1 1'b0;
			wb_load      <= #1 1'b0;
			wb_load_d    <= #1 1'b0;
			frame_done_s <= #1 1'b0;
		end else begin
			wb_load_d <= #1 wb_load;
			if (wr_ctrl) begin
				start_req    <= #1 data_in[31];
				wb_load      <= #1 data_in[30];
				frame_done_s <= #1 data_in[15];
			end else if (ps_start) begin
				start_req    <= #1 1'b0;
				frame_done_s <= #1 1'b0;
			end else if (frame_done) begin
				frame_done_s <= #1 1'b1;
			end
		end
	end

	// IN / WB slots : the CPU fills an empty slot and writes its length -> FULL, the reader takes it -> empty
	genvar k;
	generate
		for (k = 0; k < 2; k = k + 1) begin : g_slot
			wire wr_in = (k == 0) ? wr_in0 : wr_in1;
			wire wr_wb = (k == 0) ? wr_wb0 : wr_wb1;

			reg        in_full_q, wb_full_q;
			reg [31:0] in_len_q,  wb_len_q;

			always @( posedge S_AXI_ACLK ) begin
				if (S_AXI_ARESETN == 1'b0 || ps_start) begin
					in_full_q <= #1 1'b0;
					in_len_q  <= #1 'd0;
				end else if (wr_in && !in_full_q) begin
					in_full_q <= #1 1'b1;
					in_len_q  <= #1 data_in;
				end else if (in_take[k]) begin
					in_full_q <= #1 1'b0;
				end
			end

			always @( posedge S_AXI_ACLK ) begin
				if (S_AXI_ARESETN == 1'b0 || wb_restart) begin
					wb_full_q <= #1 1'b0;
					wb_len_q  <= #1 'd0;
				end else if (wr_wb && !wb_full_q) begin
					wb_full_q <= #1 1'b1;
					wb_len_q  <= #1 data_in;
				end else if (wb_take[k]) begin
					wb_full_q <= #1 1'b0;
				end
			end

			assign in_full_r[k] = in_full_q;
			assign in_len_r[k]  = in_len_q;
			assign wb_full_r[k] = wb_full_q;
			assign wb_len_r[k]  = wb_len_q;
		end
	endgenerate

	// OUT slots : the core fills a slot -> FULL, the CPU reads it and releases it -> empty
	always @( posedge S_AXI_ACLK ) begin
		if (S_AXI_ARESETN == 1'b0 || ps_start) begin
			out_full_r <= #1 6'd0;
		end else begin
			out_full_r <= #1 (out_full_r & ~(wr_release ? data_in[5:0] : 6'd0)) | out_fill;
		end
	end

	// counters (debug / progress)
	always @( posedge S_AXI_ACLK ) begin
		if (S_AXI_ARESETN == 1'b0 || ps_start) begin
			frame_cnt    <= #1 'd0;
			pix_cnt      <= #1 'd0;
			buf_fault_s  <= #1 'd0;
			out_ovf_s    <= #1 1'b0;
			wb_ovf_s     <= #1 1'b0;
		end else begin
			if (frame_done) frame_cnt <= #1 frame_cnt + 1'b1;
			if (pix_fire)   pix_cnt   <= #1 pix_cnt + 1'b1;
			buf_fault_s <= #1 (wr_seq ? 8'd0 : buf_fault_s) | buf_fault;
			out_ovf_s   <= #1 (wr_seq ? 1'b0 : out_ovf_s) | out_fifo_overflow;
			wb_ovf_s    <= #1 (wr_seq ? 1'b0 : wb_ovf_s) | wb_overflow;
		end
	end

	assign in_len0  = in_len_r[0];
	assign in_len1  = in_len_r[1];
	assign in_full  = in_full_r;
	assign wb_len0  = wb_len_r[0];
	assign wb_len1  = wb_len_r[1];
	assign wb_full  = wb_full_r;
	assign out_full = out_full_r;

	// read mux
	always @(*) begin
		case (mem_address)
			REG_CTRL        : data_out = {start_req, wb_load, 14'd0, frame_done_s, wb_done, 14'd0};
			REG_STATUS      : data_out = {14'd0, frame_done_s, wb_done, 6'd0, out_full_r, wb_full_r, in_full_r};
			REG_IN_LEN0     : data_out = in_len_r[0];
			REG_IN_LEN1     : data_out = in_len_r[1];
			REG_WB_LEN0     : data_out = wb_len_r[0];
			REG_WB_LEN1     : data_out = wb_len_r[1];
			REG_OUT_RELEASE : data_out = {26'd0, out_full_r};
			REG_FRAME_COUNT : data_out = frame_cnt;
			REG_WB_COUNT    : data_out = wb_count;
			REG_SEQ         : data_out = {buf_fault_s, 2'd0, wb_ovf_s, out_ovf_s, busy, active_v_dbg, active_dbg, 6'd0, pc_dbg};
			REG_PIX_COUNT   : data_out = pix_cnt;
			REG_INFO        : data_out = {8'(OUT_BRAM_ADDR_W), 8'(WB_BRAM_ADDR_W), 8'(IN_BRAM_ADDR_W), 8'h02};
			REG_IN_ROWS     : data_out = {16'd0, in_rows};
			REG_OUT_ROWS    : data_out = out_rows;
			REG_FILTER      : data_out = filter_r;
			REG_CMD0 + 0    : data_out = cmd_dbg[ 31:  0];
			REG_CMD0 + 1    : data_out = cmd_dbg[ 63: 32];
			REG_CMD0 + 2    : data_out = cmd_dbg[ 95: 64];
			REG_CMD0 + 3    : data_out = cmd_dbg[127: 96];
			REG_CMD0 + 4    : data_out = cmd_dbg[159:128];
			REG_CMD0 + 5    : data_out = cmd_dbg[191:160];
			REG_CMD0 + 6    : data_out = cmd_dbg[223:192];
			REG_CMD0 + 7    : data_out = cmd_dbg[255:224];
			default         : data_out = 'd0;
		endcase
	end

	always @( posedge S_AXI_ACLK ) begin
		if ( S_AXI_ARESETN == 1'b0 ) begin
			mem_data_out <= #1 '0;
		end else if (mem_rden) begin
			mem_data_out <= #1 data_out;
		end
	end

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

	// User logic ends

	endmodule
