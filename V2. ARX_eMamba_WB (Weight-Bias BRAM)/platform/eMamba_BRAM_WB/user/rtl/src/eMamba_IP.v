`timescale 1ns / 1ps

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
	parameter integer C_S_AXI_ADDR_WIDTH	= 15,
	parameter integer C_S_AXI_AWUSER_WIDTH	= 0,
	parameter integer C_S_AXI_ARUSER_WIDTH	= 0,
	parameter integer C_S_AXI_WUSER_WIDTH	= 0,
	parameter integer C_S_AXI_RUSER_WIDTH	= 0,
	parameter integer C_S_AXI_BUSER_WIDTH	= 0
)
(
	// Users to add ports here
	// ------------------------------------------------------------------------------------------
	// [J-EXT-BRAM] BRAM_IN : 입력 프레임(dIn) 을 읽어 오는 "선 하나".
	//
	//   v7 까지 : PS 가 S_AXI 의 ram[1..80] 에 dIn 을 쓰고, S_AXI 가 2560bit 버스(eMamba_dIn) 로 U_eMamba 에 꽂아 줬다.
	//   지금    : dIn 은 eMamba_IP 밖, Block Design 의 BRAM(axi_bram_ctrl_0_bram) 에 있다.
	//             - Port A : axi_bram_ctrl_0 이 잡는다. PS 가 0xA000_8000 에 쓰면 여기로 들어간다.
	//             - Port B : 이 7개 핀. eMamba_IP 가 "주소를 주고 데이터를 받는" 문.
	//
	//   핀 7개가 한 세트인 이유 : Vivado 의 bram 인터페이스(xilinx.com:interface:bram_rtl) 규격이라
	//   BD 에서 blk_mem_gen 의 BRAM_IN 에 한 번에 드래그해서 붙일 수 있다. 우리는 읽기만 하니
	//   din/we/rst 는 0 으로 묶어 둔다 (아래 assign).
	//
	//   방향 : eMamba_IP 가 이 인터페이스의 master (주소·클럭·en 을 내보내고 dout 만 받는다).
	// ------------------------------------------------------------------------------------------
	// [J-EXT-BRAM] Module Reference 로 BD 에 올릴 때 핀 7개를 bram 인터페이스 하나로 묶는 속성.
	//   MASTER_TYPE BRAM_CTRL : blk_mem_gen 이 이 포트를 axi_bram_ctrl 과 같은 규약(바이트 주소, 32bit) 으로 본다.
	//   READ_LATENCY 1        : addr 준 다음 클럭에 dout (출력 레지스터 없음).
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN CLK",
	   X_INTERFACE_MODE = "Master",
	   X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 32, MEM_ECC NONE, READ_LATENCY 1" *)
	output wire        BRAM_IN_clk,    // [J-EXT-BRAM] BRAM 클럭. eMamba 와 같은 s_axi_aclk 을 내보낸다
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN RST" *)
	output wire        BRAM_IN_rst,    // [J-EXT-BRAM] BRAM 출력 레지스터 리셋. 안 쓰니 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN EN" *)
	output wire        BRAM_IN_en,     // [J-EXT-BRAM] 1 이면 이번 클럭에 addr 의 워드를 읽는다 (다음 클럭에 dout 에 나옴)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN ADDR" *)
	output wire [14:0] BRAM_IN_addr,   // [J-EXT-BRAM] 바이트 주소 (axi_bram_ctrl_0 이 보는 오프셋과 같은 단위)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN DIN" *)
	output wire [31:0] BRAM_IN_din,    // [J-EXT-BRAM] 쓰기 데이터. 안 쓰니 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN WE" *)
	output wire [3:0]  BRAM_IN_we,     // [J-EXT-BRAM] 바이트 쓰기 인에이블. 안 쓰니 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN DOUT" *)
	input  wire [31:0] BRAM_IN_dout,   // [J-EXT-BRAM] 읽은 워드 (en=1 준 클럭의 "다음" 클럭에 유효)

	// ------------------------------------------------------------------------------------------
	// [J-EXT-BRAM-OUT] BRAM_OUT : 결과(dOut) 를 내보내는 "선 하나". 입력 BRAM_IN 의 반대 방향.
	//
	//   v7 까지 : U_eMamba 가 토큰 하나(57 바이트) 를 낼 때마다 S_AXI 가 ram[5120 + idx*15 .. +14] 15 워드에 동시에 써 넣고,
	//             PS 가 eMamba base + word 5120.. 에서 읽어 갔다.
	//   지금    : BD 의 두 번째 BRAM(axi_bram_ctrl_1_bram, 폭 512bit) 에 토큰 하나 = 행 하나(64 바이트) 로 쓴다.
	//             - Port B : 이 7개 핀. eMamba_IP 가 en/we/addr/din 을 내고 한 클럭에 행 하나를 쓴다.
	//             - Port A : axi_bram_ctrl_1 (512bit). PS 는 32bit 씩 16 번 읽으면 행 하나 (SmartConnect 가 폭 변환).
	//
	//   행 layout (64 바이트, 리틀엔디언) :
	//     byte 0..56  : dOut[455:0]  (class 0..56)
	//     byte 57     : {dOut_seq_idx, 4'b0}   -> PS 가 word 14 를 읽으면 v7 처럼 [15:12] = idx, [7:0] = class 56
	//     byte 58..63 : 0
	//   즉 PS 쪽에서 토큰 idx 의 word k 는  axi_bram_ctrl_1 base + 64*idx + 4*k  (k = 0..14).
	//
	//   폭이 512 인 이유 : 토큰 57 바이트를 한 클럭에 쓰려고. axi_bram_ctrl 의 Data Width 도 512 로 맞춘다
	//   (BRAM Controller 모드는 Port A/B 폭이 같아야 한다). 주소는 바이트 주소, 하위 6bit 무시.
	// ------------------------------------------------------------------------------------------
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT CLK",
	   X_INTERFACE_MODE = "Master",
	   X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 512, MEM_ECC NONE, READ_LATENCY 1" *)
	output wire         BRAM_OUT_clk,    // [J-EXT-BRAM-OUT] s_axi_aclk
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT RST" *)
	output wire         BRAM_OUT_rst,    // [J-EXT-BRAM-OUT] 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT EN" *)
	output wire         BRAM_OUT_en,     // [J-EXT-BRAM-OUT] 토큰 하나를 쓰는 클럭에 1
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT ADDR" *)
	output wire [12:0]  BRAM_OUT_addr,   // [J-EXT-BRAM-OUT] 바이트 주소 = 64 * dOut_seq_idx (8K 창 -> 13bit)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT DIN" *)
	output wire [511:0] BRAM_OUT_din,    // [J-EXT-BRAM-OUT] 행 하나 (위 layout)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT WE" *)
	output wire [63:0]  BRAM_OUT_we,     // [J-EXT-BRAM-OUT] 바이트별 쓰기 인에이블. 쓰는 클럭에 64개 전부 1 (패딩도 0 으로 써 둔다)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT DOUT" *)
	input  wire [511:0] BRAM_OUT_dout,   // [J-EXT-BRAM-OUT] 안 씀 (인터페이스 규격상 있어야 함)


	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB CLK",
	   X_INTERFACE_MODE = "Master",
	   X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 32, MEM_ECC NONE, READ_LATENCY 1" *)
	output wire        BRAM_WB_clk,    // [J-WB-BRAM] BRAM 클럭. eMamba 와 같은 s_axi_aclk 을 내보낸다
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB RST" *)
	output wire        BRAM_WB_rst,    // [J-WB-BRAM] BRAM 출력 레지스터 리셋. 안 쓰니 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB EN" *)
	output wire        BRAM_WB_en,     // [J-WB-BRAM] 1 이면 이번 클럭에 addr 의 워드를 읽는다 (다음 클럭에 dout 에 나옴)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB ADDR" *)
	output wire [14:0] BRAM_WB_addr,   // [J-WB-BRAM] 바이트 주소 (axi_bram_ctrl_0 이 보는 오프셋과 같은 단위)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB DIN" *)
	output wire [31:0] BRAM_WB_din,    // [J-WB-BRAM] 쓰기 데이터. 안 쓰니 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB WE" *)
	output wire [3:0]  BRAM_WB_we,     // [J-WB-BRAM] 바이트 쓰기 인에이블. 안 쓰니 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB DOUT" *)
	input  wire [31:0] BRAM_WB_dout,   // [J-WB-BRAM] 읽은 워드 (en=1 준 클럭의 "다음" 클럭에 유효)


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
	localparam integer SEQ_W = (NUM_SEQLEN > 1) ? $clog2(NUM_SEQLEN) : 1; // [J-AXI Conn.] dOut_seq_idx width

	localparam integer BRAM_WB_SIZE = 32'd19440;
	localparam integer AXI_WIDTH = 32;
	localparam integer WB_BRAM_ADDR_W = 15; // 8192 - 13bit
	// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
	// Internal variables
	// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
	wire ps_start;

	// ------------------------------------------------------------------------------------------
	// [J-EXT-BRAM] Initial Input
	//
	//   v7 : wire [2559:0] eMamba_dIn  (S_AXI -> U_eMamba, 프레임 320 바이트가 통째로 병렬 배선)
	//   지금 : 아래 3개 신호가 그 자리를 대신한다. 프레임은 BRAM 에 있고, 안쪽(U_PatchEmbedding 의
	//          Token_Fetcher) 이 "몇 번째 워드" 인지 주소를 올려 보내면 이 파일이 BRAM 에서 읽어 내려 준다.
	//
	//   U_eMamba ──in_rd_en / in_rd_addr──▶ (이 파일) ──BRAM_IN_en / addr──▶ BRAM
	//   U_eMamba ◀──────in_rd_data────────  (이 파일) ◀──────BRAM_IN_dout────── BRAM
	// ------------------------------------------------------------------------------------------
	wire        in_rd_en;     // [J-EXT-BRAM] Token_Fetcher 가 "읽어 달라" (U_eMamba -> 여기)
	wire [6:0]  in_rd_addr;   // [J-EXT-BRAM] 몇 번째 32bit 워드? 0..79  (U_eMamba -> 여기)
	wire [31:0] in_rd_data;   // [J-EXT-BRAM] 읽힌 워드, 요청 다음 클럭에 유효 (여기 -> U_eMamba)


	// [J-EXT-BRAM] word 주소 -> byte 주소 변환이 이 파일이 하는 일의 전부.
	//   Token_Fetcher 는 "워드 k" 로 센다 (프레임 320B 를 4B 씩 묶은 인덱스, k = 0..79).
	//   BRAM 컨트롤러 계열(axi_bram_ctrl / BRAM Controller 모드 blk_mem_gen) 은 "바이트" 로 센다.
	//   PS 가 0xA000_8000 + 4k 에 쓴 워드는 BRAM 안에서 바이트 주소 4k 다. 그래서 Port B 도 4k 를 줘야 같은 자리를 읽는다.
	//   4k = k 를 왼쪽으로 2bit 밀기 = {k, 2'b00}. 15bit 로 맞추려고 위에 0 을 6개 채운다 (6 + 7 + 2 = 15).
	//
	//     PS 주소        bram_addr_a(ctrl)   BRAM_IN_addr   in_rd_addr
	//     0xA000_8000    0                   0                 0
	//     0xA000_8004    4                   4                 1
	//     0xA000_813C    316                 316               79
	assign BRAM_IN_clk  = s_axi_aclk;                  // [J-EXT-BRAM]
	assign BRAM_IN_rst  = 1'b0;                        // [J-EXT-BRAM]
	assign BRAM_IN_en   = in_rd_en;                    // [J-EXT-BRAM]
	assign BRAM_IN_addr = {6'b0, in_rd_addr, 2'b00};   // [J-EXT-BRAM] word k -> byte 4k
	assign BRAM_IN_din  = 32'd0;                       // [J-EXT-BRAM] 읽기 전용
	assign BRAM_IN_we   = 4'b0000;                     // [J-EXT-BRAM] 읽기 전용
	assign in_rd_data      = BRAM_IN_dout;             // [J-EXT-BRAM] 그대로 내려 보낸다


	wire wb_bram_en;
	wire [WB_BRAM_ADDR_W-1:0] bram_rd_addr;
	wire [AXI_WIDTH-1:0] bram_rd_data;

	assign BRAM_WB_clk  = s_axi_aclk;                  // [J-WB-BRAM]
	assign BRAM_WB_rst  = 1'b0;                        // [J-WB-BRAM]
	assign BRAM_WB_en   = wb_bram_en;                    // [J-WB-BRAM]
	assign BRAM_WB_addr = bram_rd_addr;   // [J-WB-BRAM] word k -> byte 4k
	assign BRAM_WB_din  = 32'd0;                       // [J-WB-BRAM] 읽기 전용
	assign BRAM_WB_we   = 4'b0000;                     // [J-WB-BRAM] 읽기 전용
	assign bram_rd_data = BRAM_WB_dout;             // [J-WB-BRAM] 그대로 내려 보낸다
	// Initial Input
	// wire signed [DATA_WIDTH * NUM_CHANNEL * NUM_HEIGHT * NUM_WIDTH - 1:0] eMamba_dIn; // 1x5x8x8
	// [J-EXT-BRAM] ↑ 삭제 : S_AXI -> U_eMamba 2560bit 버스. 위의 in_rd_* 3개가 대신한다.

	// 1. Patchembedding
	// wire signed [DATA_WIDTH * NUM_DIM * NUM_DIM - 1:0] patch_weight; // 20x20
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] patch_bias; // 20

	// // ----- 1st MAMBA Block ----- //
	// // 2. LightNorm
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_weight; // 20
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_bias;   // 20

	// // 3-1. Linear expand x1
	// wire signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_x1_weight; // 40x20
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] linEx_x1_bias;             // 40

	// // 3-2. Linear expand z1
	// wire signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_z1_weight; // 40x20
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] linEx_z1_bias;             // 40

	// // 4. Convolution 1D
	// wire signed [DATA_WIDTH * NUM_ED * NUM_ED - 1:0] conv1d_weight; // 40x40
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] conv1d_bias;             // 40

	// // 5. SSM
	// wire signed [DATA_WIDTH * NUM_ED * NUM_N - 1:0] matrix_A; // 40x8
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] matrix_D; // 40

	// // Linear expand deltaBC
	// wire signed [DATA_WIDTH * NUM_DBC * NUM_ED - 1:0] linEx_dBC_weight; // 48x40

	// // Linear expand delta
	// wire signed [DATA_WIDTH * NUM_ED * NUM_DELTA - 1:0] linEx_delta_weight; // 40x32
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] linEx_delta_bias; // 40

	// // 7. Linear contract
	// wire signed [DATA_WIDTH * NUM_DIM * NUM_ED - 1:0] linCont_weight; // 20x40
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] linCont_bias; // 20

	// // ----- 2nd MAMBA Block ----- //
	// // 2. LightNorm
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_2nd_weight; // 20
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_2nd_bias;   // 20

	// // 3-1. Linear expand x1
	// wire signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_x1_2nd_weight; // 40x20
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] linEx_x1_2nd_bias;             // 40

	// // 3-2. Linear expand z1
	// wire signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_z1_2nd_weight; // 40x20
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] linEx_z1_2nd_bias;             // 40

	// // 4. Convolution 1D
	// wire signed [DATA_WIDTH * NUM_ED * NUM_ED - 1:0] conv1d_2nd_weight; // 40x40
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] conv1d_2nd_bias;             // 40

	// // 5. SSM
	// wire signed [DATA_WIDTH * NUM_ED * NUM_N - 1:0] matrix_A_2nd; // 40x8
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] matrix_D_2nd; // 40

	// // Linear expand deltaBC
	// wire signed [DATA_WIDTH * NUM_DBC * NUM_ED - 1:0] linEx_dBC_2nd_weight; // 48x40

	// // Linear expand delta
	// wire signed [DATA_WIDTH * NUM_ED * NUM_DELTA - 1:0] linEx_delta_2nd_weight; // 40x32
	// wire signed [DATA_WIDTH * NUM_ED - 1:0] linEx_delta_2nd_bias; // 40

	// // 7. Linear contract
	// wire signed [DATA_WIDTH * NUM_DIM * NUM_ED - 1:0] linCont_2nd_weight; // 20x40
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] linCont_2nd_bias; // 20

	// // ----- Outputhead ----- //
	// // LightNorm
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] OH_lightNorm_weight; // 20
	// wire signed [DATA_WIDTH * NUM_DIM - 1:0] OH_lightNorm_bias;   // 20

	// // Linear expand 57
	// wire signed [DATA_WIDTH * NUM_CLASS * NUM_DIM - 1:0] OH_linEx_weight; // 57x20
	// wire signed [DATA_WIDTH * NUM_CLASS - 1:0] OH_linEx_bias; // 57

	// Final Output
	wire signed [DATA_WIDTH * NUM_CLASS - 1:0] eMamba_dOut; // Class 57
	wire m_valid;
	wire [SEQ_W-1:0] dOut_seq_idx; // [J-AXI Conn.] 4 -> SEQ_W
	wire frame_done;
	// wire ram_ready;   // [J-AXI Conn.] S_AXI.ram_ready -> U_eMamba.m_ready
	// [J-EXT-BRAM-OUT] ↑ 삭제 : S_AXI 는 더 이상 dOut 을 받지 않는다. 아래 out_ready 가 U_eMamba.m_ready 로 간다

	wire eMamba_start;

	// ------------------------------------------------------------------------------------------
	// [J-EXT-BRAM-OUT] 출력 BRAM 쓰기. 옛 S_AXI 의 "else if (m_valid) ram[5120 + idx*15 + k] <= dOut[...]" 15 줄이
	//   여기 한 클럭 쓰기로 바뀐 것. U_eMamba 쪽 핸드셰이크(dOut / m_valid / dOut_seq_idx / m_ready) 는 v7 그대로.
	//
	//   out_ready : 옛 S_AXI.ram_ready. 그때는 AXI write 와 같은 배열을 건드려서 "이번 클럭에 AXI 가 쓰면 토큰을 받지 마라" 가
	//               필요했지만, 지금 Port B 는 eMamba 전용이라 충돌이 없다. 리셋/재시작 중만 막는다.
	//   out_fire  : 토큰 하나가 넘어오는 클럭 = BRAM 에 행 하나를 쓰는 클럭.
	// ------------------------------------------------------------------------------------------
	wire out_ready = s_axi_aresetn && !eMamba_start;                       // [J-EXT-BRAM-OUT] -> U_eMamba.m_ready
	wire out_fire  = m_valid && out_ready;                                 // [J-EXT-BRAM-OUT]

	// 행 하나 : byte 0..56 = dOut, byte 57 = {idx, 4'b0}, byte 58..63 = 0   (아래쪽이 낮은 바이트)
	wire [511:0] out_row = { {(512 - DATA_WIDTH*NUM_CLASS - 8){1'b0}},      // [J-EXT-BRAM-OUT] byte 58..63
	                         {{(4-SEQ_W){1'b0}}, dOut_seq_idx, 4'b0},      // [J-EXT-BRAM-OUT] byte 57  = {idx, 4'b0}
	                         eMamba_dOut };                                 // [J-EXT-BRAM-OUT] byte 0..56

	assign BRAM_OUT_clk  = s_axi_aclk;                                     // [J-EXT-BRAM-OUT]
	assign BRAM_OUT_rst  = 1'b0;                                           // [J-EXT-BRAM-OUT]
	assign BRAM_OUT_en   = out_fire;                                       // [J-EXT-BRAM-OUT]
	assign BRAM_OUT_we   = {64{out_fire}};                                 // [J-EXT-BRAM-OUT] 64 바이트 전부
	assign BRAM_OUT_addr = {{(13-SEQ_W-6){1'b0}}, dOut_seq_idx, 6'b0};     // [J-EXT-BRAM-OUT] 64 * idx
	assign BRAM_OUT_din  = out_row;                                        // [J-EXT-BRAM-OUT]





	wire wb_load;
	wire              wb_valid;
	wire [WB_BRAM_ADDR_W-1:0] wb_addr;
	wire [AXI_WIDTH-1:0] wb_data;

	wire              wb_done;

// Instantiation of Axi Bus Interface S_AXI
S_AXI # ( // [J-AXI Conn.]
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

    // .dIn(eMamba_dIn),
    // [J-EXT-BRAM] 삭제 : S_AXI 는 이제 dIn 을 모른다 (ram[1..80] 창은 비어 있음).

    // Patchembedding
    // .patch_weight(patch_weight),
    // .patch_bias(patch_bias),

    // // MAMBA Block
    // .lightNorm_weight(lightNorm_weight),
    // .lightNorm_bias(lightNorm_bias),

    // .linEx_x1_weight(linEx_x1_weight),
    // .linEx_x1_bias(linEx_x1_bias),

    // .linEx_z1_weight(linEx_z1_weight),
    // .linEx_z1_bias(linEx_z1_bias),
    
    // .conv1d_weight(conv1d_weight),
    // .conv1d_bias(conv1d_bias),

    // .matrix_A(matrix_A),
    // .matrix_D(matrix_D),
    // .linEx_dBC_weight(linEx_dBC_weight),
    // .linEx_delta_weight(linEx_delta_weight),
    // .linEx_delta_bias(linEx_delta_bias),

    // .linCont_weight(linCont_weight),
    // .linCont_bias(linCont_bias),

    // // 2nd MAMBA Block
    // .lightNorm_2nd_weight(lightNorm_2nd_weight),
    // .lightNorm_2nd_bias(lightNorm_2nd_bias),

    // .linEx_x1_2nd_weight(linEx_x1_2nd_weight),
    // .linEx_x1_2nd_bias(linEx_x1_2nd_bias),

    // .linEx_z1_2nd_weight(linEx_z1_2nd_weight),
    // .linEx_z1_2nd_bias(linEx_z1_2nd_bias),

    // .conv1d_2nd_weight(conv1d_2nd_weight),
    // .conv1d_2nd_bias(conv1d_2nd_bias),

    // .matrix_A_2nd(matrix_A_2nd),
    // .matrix_D_2nd(matrix_D_2nd),
    // .linEx_dBC_2nd_weight(linEx_dBC_2nd_weight),
    // .linEx_delta_2nd_weight(linEx_delta_2nd_weight),
    // .linEx_delta_2nd_bias(linEx_delta_2nd_bias),
    // .linCont_2nd_weight(linCont_2nd_weight),
    // .linCont_2nd_bias(linCont_2nd_bias),

    // // Outputhead
    // .OH_lightNorm_weight(OH_lightNorm_weight),
    // .OH_lightNorm_bias(OH_lightNorm_bias),
    // .OH_linEx_weight(OH_linEx_weight),
    // .OH_linEx_bias(OH_linEx_bias),

	// .dOut(eMamba_dOut),
    // .m_valid(m_valid),
	// .dOut_seq_idx(dOut_seq_idx),
	// .ram_ready(ram_ready),   // [J-AXI Conn.]
	// [J-EXT-BRAM-OUT] 네 줄 삭제 : 결과는 BRAM_OUT 으로 나간다.
	//                  frame_done 만 남는다 (ctrl word 0 bit 15 = "프레임 끝" 은 여전히 S_AXI 가 PS 에 알려 준다).
	.frame_done(frame_done),
	
	.eMamba_start(eMamba_start),

	.wb_load(wb_load), // output : wb가 준비되었어라고 cpu가 적어주는거 wb_broadcaster에 전달해야해.
	.wb_done(wb_done) // input : wb를 각 모듈로 전부 넘겼는지 cpu에게 알려줄 준비.
);

wb_broadcast_loader #(
    .AXI_WIDTH(AXI_WIDTH), // 32
    .BRAM_WB_SIZE(BRAM_WB_SIZE), // 4860
    .WB_BRAM_ADDR_W(WB_BRAM_ADDR_W)// = 13  (8192 - 13bit)
)wb_broadcaster(
    .clk(s_axi_aclk),
    .nRst(s_axi_aresetn),

    .wb_load(wb_load), // axi bram 에 wb 가 준비 되어있다고 cpu가 적어주는거야.

    .bram_en(wb_bram_en), // bram 읽기 en.
    .bram_rd_addr(bram_rd_addr), // bram 읽기 addr.
    .bram_rd_data(bram_rd_data), // bram 읽기 data.

    .wb_valid(wb_valid), // wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // wb 의 addr.
    .wb_data(wb_data), // wb 의 data.

    .wb_done(wb_done) // wb 가 끝났는지 아닌지.
);

U_eMamba #( // [J-AXI Conn.] eMamba -> U_eMamba
	 .AXI_WIDTH(AXI_WIDTH),
	 .WB_BRAM_ADDR_W(WB_BRAM_ADDR_W),

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
) eMamba ( // [J-AXI Conn.] instance name kept as eMamba
    .clk(s_axi_aclk),
    .nRst(s_axi_aresetn),

    .ps_start(ps_start),

    // .dIn(eMamba_dIn),
    // [J-EXT-BRAM] 삭제, 아래 3개 신호로 교체. U_eMamba 안에서는 U_PatchEmbedding 까지 그대로 관통한다.
    .in_rd_en(in_rd_en),       // [J-EXT-BRAM] U_eMamba -> 위의 assign -> BRAM_IN_en
    .in_rd_addr(in_rd_addr),   // [J-EXT-BRAM] U_eMamba -> 위의 assign -> BRAM_IN_addr
    .in_rd_data(in_rd_data),   // [J-EXT-BRAM] BRAM_IN_dout -> U_eMamba

	.wb_valid(wb_valid), // input : wb 가 유효한지 아닌지.
    .wb_addr(wb_addr), // input : wb 의 addr.
    .wb_data(wb_data), // input : wb 의 data.

    .dOut(eMamba_dOut),        // [J-EXT-BRAM-OUT] v7 그대로. 이 값이 위 out_row 로 

    // Patchembedding
    // .patch_weight(patch_weight),
    // .patch_bias(patch_bias),

    // // MAMBA Block
    // .lightNorm_weight(lightNorm_weight),
    // .lightNorm_bias(lightNorm_bias),

    // .linEx_x1_weight(linEx_x1_weight),
    // .linEx_x1_bias(linEx_x1_bias),

    // .linEx_z1_weight(linEx_z1_weight),
    // .linEx_z1_bias(linEx_z1_bias),
    
    // .conv1d_weight(conv1d_weight),
    // .conv1d_bias(conv1d_bias),

    // .matrix_A(matrix_A),
    // .matrix_D(matrix_D),
    // .linEx_dBC_weight(linEx_dBC_weight),
    // .linEx_delta_weight(linEx_delta_weight),
    // .linEx_delta_bias(linEx_delta_bias),

    // .linCont_weight(linCont_weight),
    // .linCont_bias(linCont_bias),

    // // 2nd MAMBA Block
    // .lightNorm_2nd_weight(lightNorm_2nd_weight),
    // .lightNorm_2nd_bias(lightNorm_2nd_bias),

    // .linEx_x1_2nd_weight(linEx_x1_2nd_weight),
    // .linEx_x1_2nd_bias(linEx_x1_2nd_bias),

    // .linEx_z1_2nd_weight(linEx_z1_2nd_weight),
    // .linEx_z1_2nd_bias(linEx_z1_2nd_bias),

    // .conv1d_2nd_weight(conv1d_2nd_weight),
    // .conv1d_2nd_bias(conv1d_2nd_bias),

    // .matrix_A_2nd(matrix_A_2nd),
    // .matrix_D_2nd(matrix_D_2nd),
    // .linEx_dBC_2nd_weight(linEx_dBC_2nd_weight),
    // .linEx_delta_2nd_weight(linEx_delta_2nd_weight),
    // .linEx_delta_2nd_bias(linEx_delta_2nd_bias),
    // .linCont_2nd_weight(linCont_2nd_weight),
    // .linCont_2nd_bias(linCont_2nd_bias),

    // // Outputhead
    // .OH_lightNorm_weight(OH_lightNorm_weight),
    // .OH_lightNorm_bias(OH_lightNorm_bias),
    // .OH_linEx_weight(OH_linEx_weight),
    // .OH_linEx_bias(OH_linEx_bias),

    .m_valid(m_valid),
    .dOut_seq_idx(dOut_seq_idx),
	.frame_done(frame_done),
	// .m_ready(ram_ready),     // [J-AXI Conn.]
	.m_ready(out_ready),     // [J-EXT-BRAM-OUT] ram_ready -> out_ready (S_AXI 대신 eMamba_IP 가)
	
	.eMamba_start(eMamba_start)
);

endmodule