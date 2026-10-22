`timescale 1ns / 1ps
// eMambaYOLO_IP : eMambaYOLO (U_106 rtl/top, L00-L20) 를 AXI4 slave + BRAM 3개로 감싼 IP.
//   eMamba_IP (U_eMamba 분류기) 와 같은 핀 (BRAM_IN / BRAM_OUT / BRAM_WB + s_axi) 이라 BD / user region 에 그대로 꽂힌다.
//
//   S_AXI : 제어 레지스터 (CTRL / STATUS / 슬롯 길이 / 카운터, 레지스터 표와 CPU 순서는 S_AXI.sv 헤더)
//   emy_ip_core   : eMambaYOLO + BRAM 이동기 (슬롯 layout 은 emy_ip_core.sv 헤더). eMambaYOLO 포트가 SV 배열이라
//                   이 Verilog 파일에서 직접 연결할 수 없어서 SV 모듈 하나를 사이에 둔다.
//
//   v7 (eMamba_IP) 와 다른 점
//     BRAM_IN  : 프레임 320 B 통째 -> 1.2 MB 프레임을 슬롯 2개 (각 16 KB) 로 이어서 받는다 (HWC, 3 B/pixel)
//     BRAM_WB  : 19,440 B 한 번 -> 5.4 MB WB 이미지를 슬롯 2개로 이어서 받는다 (wb_broadcast_loader 대신 emy_ip_core)
//     BRAM_OUT : 토큰 57 B / 행 -> P3 / P4 / P5 64 B 행, 스트림별 영역 + 슬롯 2개 (CPU 가 읽고 OUT_RELEASE)
//     ps_start : ram[0][31] & wb_done 레벨 -> START 를 쓰면 1 clk 펄스 한 번, 그 뒤 프레임이 끊김 없이 흐른다
//   파일 목록 : 이 파일, S_AXI.sv, emy_ip_core.sv + sources_1/new/engine (emy_engine_pkg, eMambaYOLO_engine, 엔진 · 버퍼 · 로더)
//              (emy_pkg, emy_requant 도 engine/ 에 있음). v2 (2026-10-15): 코어 = 공유 엔진 eMambaYOLO_engine (ENGINE_SPEC §10);
//              BRAM_WB 스트림 = program.mem (32 KB) + engine_image.mem; LAYER_DONE 레지스터 → SEQ / IN_ROWS / OUT_ROWS / CMD0-7.

module eMambaYOLO_IP#
(
	// Users to add parameters here
	parameter integer BRAM_IN_ADDR_W  = 15,   // BRAM_IN  byte address bits (32 KB, 32-bit words)
	parameter integer BRAM_WB_ADDR_W  = 15,   // BRAM_WB  byte address bits (32 KB, 32-bit words)
	parameter integer BRAM_OUT_ADDR_W = 13,   // BRAM_OUT byte address bits (8 KB, 512-bit rows)
	parameter integer IMG_LINES       = 198992, // weight image lines (L00 .. L21 since 2026-10-19 default switch; board value set here)
	parameter integer IMG_URAM_LINES  = 184320, // [Jae 2026-10-19] IMG ext: lines in URAM (45 URAM x 4 banks), the rest in BRAM. 192512 (47/bank, URAM 288 = 100 %) failed placement on xcku19p (Place 30-365, URAM cascades); 184320 -> URAM 280 as in U_203
	parameter integer OUT_P3_ROWS     = 19200,  // BRAM_OUT rows per frame and head (L21 head on the engine: 3 rows / pixel; neck-only program: 6400 / 3200 / 1600)
	parameter integer OUT_P4_ROWS     = 4800,
	parameter integer OUT_P5_ROWS     = 1200,
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
	// BRAM_IN : 입력 프레임 청크를 읽는 포트 (Port B, 읽기 전용). Port A = axi_bram_ctrl, CPU 가 슬롯에 쓴다.
	//   슬롯 0 = byte [0, 16K), 슬롯 1 = [16K, 32K) (BRAM_IN_ADDR_W = 15).
	// ------------------------------------------------------------------------------------------
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN CLK",
	   X_INTERFACE_MODE = "Master",
	   X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 32, MEM_ECC NONE, READ_LATENCY 1" *)
	output wire        BRAM_IN_clk,    // s_axi_aclk
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN RST" *)
	output wire        BRAM_IN_rst,    // 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN EN" *)
	output wire        BRAM_IN_en,     // 1 이면 이번 클럭에 addr 의 워드를 읽는다 (다음 클럭에 dout)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN ADDR" *)
	output wire [BRAM_IN_ADDR_W-1:0] BRAM_IN_addr,   // 바이트 주소 (4 의 배수)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN DIN" *)
	output wire [31:0] BRAM_IN_din,    // 0 (읽기 전용)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN WE" *)
	output wire [3:0]  BRAM_IN_we,     // 0 (읽기 전용)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_IN DOUT" *)
	input  wire [31:0] BRAM_IN_dout,

	// ------------------------------------------------------------------------------------------
	// BRAM_OUT : P3 / P4 / P5 64 B 행을 쓰는 포트 (Port B, 쓰기 전용, 512 bit). Port A = axi_bram_ctrl (512 bit), CPU 가 읽는다.
	//   행 : byte c = channel c (int8). P4 픽셀 = 행 2개 (ch 0-63, 64-127), P5 픽셀 = 행 4개.
	//   BRAM_OUT_ADDR_W = 13 : P3 슬롯 0x0000 / 0x0800, P4 0x1000 / 0x1400, P5 0x1800 / 0x1C00.
	// ------------------------------------------------------------------------------------------
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT CLK",
	   X_INTERFACE_MODE = "Master",
	   X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 512, MEM_ECC NONE, READ_LATENCY 1" *)
	output wire         BRAM_OUT_clk,    // s_axi_aclk
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT RST" *)
	output wire         BRAM_OUT_rst,    // 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT EN" *)
	output wire         BRAM_OUT_en,     // 행 하나를 쓰는 클럭에 1
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT ADDR" *)
	output wire [BRAM_OUT_ADDR_W-1:0] BRAM_OUT_addr,   // 바이트 주소 (64 의 배수)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT DIN" *)
	output wire [511:0] BRAM_OUT_din,
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT WE" *)
	output wire [63:0]  BRAM_OUT_we,     // 쓰는 클럭에 64 바이트 전부 1
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_OUT DOUT" *)
	input  wire [511:0] BRAM_OUT_dout,   // 안 씀 (인터페이스 규격상 있어야 함)

	// ------------------------------------------------------------------------------------------
	// BRAM_WB : WB 이미지 청크를 읽는 포트 (Port B, 읽기 전용). 슬롯 구성은 BRAM_IN 과 같다.
	// ------------------------------------------------------------------------------------------
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB CLK",
	   X_INTERFACE_MODE = "Master",
	   X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_WIDTH 32, MEM_ECC NONE, READ_LATENCY 1" *)
	output wire        BRAM_WB_clk,    // s_axi_aclk
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB RST" *)
	output wire        BRAM_WB_rst,    // 0
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB EN" *)
	output wire        BRAM_WB_en,
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB ADDR" *)
	output wire [BRAM_WB_ADDR_W-1:0] BRAM_WB_addr,
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB DIN" *)
	output wire [31:0] BRAM_WB_din,    // 0 (읽기 전용)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB WE" *)
	output wire [3:0]  BRAM_WB_we,     // 0 (읽기 전용)
	(* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_WB DOUT" *)
	input  wire [31:0] BRAM_WB_dout,

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
	// Internal variables (S_AXI <-> emy_ip_core)
	// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
	wire        ps_start;
	wire        wb_restart;

	wire [31:0] in_len0, in_len1;
	wire [1:0]  in_full, in_take;

	wire [31:0] wb_len0, wb_len1;
	wire [1:0]  wb_full, wb_take;

	wire [5:0]  out_full, out_fill;

	wire        wb_done;
	wire [31:0] wb_count;
	wire        pix_fire;
	wire        frame_done;
	wire        busy, active_v_dbg, out_fifo_overflow, wb_overflow;
	wire [9:0]  pc_dbg;
	wire [255:0] cmd_dbg;
	wire [1:0]  active_dbg;
	wire [15:0] in_rows;
	wire [7:0]  buf_fault;
	wire [31:0] out_rows;
	wire        filt_en;            // [Jae 2026-10-21] FILTER register -> core (output candidate filter)
	wire [7:0]  qthr0, qthr1, qthr2;
	wire        det_en;             // FILTER[1] -> core (DET mode: head math in the adapter, one row per candidate)
	wire        nms_en;             // FILTER[2] -> core (NMS mode: NMS in the adapter, detection rows + END)

	// BRAM 고정 신호 : 같은 클럭, 리셋 안 씀, IN / WB 는 읽기 전용
	assign BRAM_IN_clk  = s_axi_aclk;
	assign BRAM_IN_rst  = 1'b0;
	assign BRAM_IN_din  = 32'd0;
	assign BRAM_IN_we   = 4'b0000;

	assign BRAM_WB_clk  = s_axi_aclk;
	assign BRAM_WB_rst  = 1'b0;
	assign BRAM_WB_din  = 32'd0;
	assign BRAM_WB_we   = 4'b0000;

	assign BRAM_OUT_clk = s_axi_aclk;
	assign BRAM_OUT_rst = 1'b0;

// Instantiation of Axi Bus Interface S_AXI
S_AXI # (
	.IN_BRAM_ADDR_W(BRAM_IN_ADDR_W),
	.WB_BRAM_ADDR_W(BRAM_WB_ADDR_W),
	.OUT_BRAM_ADDR_W(BRAM_OUT_ADDR_W),

	.C_S_AXI_ID_WIDTH(C_S_AXI_ID_WIDTH),
	.C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
	.C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
	.C_S_AXI_AWUSER_WIDTH(C_S_AXI_AWUSER_WIDTH),
	.C_S_AXI_ARUSER_WIDTH(C_S_AXI_ARUSER_WIDTH),
	.C_S_AXI_WUSER_WIDTH(C_S_AXI_WUSER_WIDTH),
	.C_S_AXI_RUSER_WIDTH(C_S_AXI_RUSER_WIDTH),
	.C_S_AXI_BUSER_WIDTH(C_S_AXI_BUSER_WIDTH)
) S_AXI (
	// User I/O
	.ps_start(ps_start),
	.wb_restart(wb_restart),

	.in_len0(in_len0),
	.in_len1(in_len1),
	.in_full(in_full),
	.in_take(in_take),

	.wb_len0(wb_len0),
	.wb_len1(wb_len1),
	.wb_full(wb_full),
	.wb_take(wb_take),

	.out_full(out_full),
	.out_fill(out_fill),

	.wb_done(wb_done),
	.wb_count(wb_count),
	.pix_fire(pix_fire),
	.frame_done(frame_done),
	.busy(busy),
	.pc_dbg(pc_dbg),
	.cmd_dbg(cmd_dbg),
	.active_dbg(active_dbg),
	.active_v_dbg(active_v_dbg),
	.in_rows(in_rows),
	.buf_fault(buf_fault),
	.out_fifo_overflow(out_fifo_overflow),
	.wb_overflow(wb_overflow),
	.out_rows(out_rows),
	.filt_en(filt_en),
	.det_en(det_en),
	.nms_en(nms_en),
	.qthr0(qthr0),
	.qthr1(qthr1),
	.qthr2(qthr2),

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
	.S_AXI_RREADY(s_axi_rready)
);

emy_ip_core #(
	.IN_AW(BRAM_IN_ADDR_W),
	.WB_AW(BRAM_WB_ADDR_W),
	.OUT_AW(BRAM_OUT_ADDR_W),
	.IMG_LINES(IMG_LINES),
	.IMG_URAM_LINES(IMG_URAM_LINES),
	.OUT_P3_ROWS(OUT_P3_ROWS),
	.OUT_P4_ROWS(OUT_P4_ROWS),
	.OUT_P5_ROWS(OUT_P5_ROWS)
) core (
	.clk(s_axi_aclk),
	.nRst(s_axi_aresetn),

	.ps_start(ps_start),
	.wb_restart(wb_restart),

	.in_len0(in_len0[BRAM_IN_ADDR_W-1:0]),
	.in_len1(in_len1[BRAM_IN_ADDR_W-1:0]),
	.in_full(in_full),
	.in_take(in_take),

	.wb_len0(wb_len0[BRAM_WB_ADDR_W-1:0]),
	.wb_len1(wb_len1[BRAM_WB_ADDR_W-1:0]),
	.wb_full(wb_full),
	.wb_take(wb_take),

	.out_full(out_full),
	.out_fill(out_fill),

	.wb_done(wb_done),
	.wb_count(wb_count),
	.pix_fire(pix_fire),
	.frame_done(frame_done),
	.busy(busy),
	.pc_dbg(pc_dbg),
	.cmd_dbg(cmd_dbg),
	.active_dbg(active_dbg),
	.active_v_dbg(active_v_dbg),
	.in_rows(in_rows),
	.buf_fault(buf_fault),
	.out_fifo_overflow(out_fifo_overflow),
	.wb_overflow(wb_overflow),
	.out_rows(out_rows),
	.filt_en(filt_en),
	.det_en(det_en),
	.nms_en(nms_en),
	.qthr0(qthr0),
	.qthr1(qthr1),
	.qthr2(qthr2),

	.in_bram_en(BRAM_IN_en),
	.in_bram_addr(BRAM_IN_addr),
	.in_bram_dout(BRAM_IN_dout),

	.wb_bram_en(BRAM_WB_en),
	.wb_bram_addr(BRAM_WB_addr),
	.wb_bram_dout(BRAM_WB_dout),

	.out_bram_en(BRAM_OUT_en),
	.out_bram_we(BRAM_OUT_we),
	.out_bram_addr(BRAM_OUT_addr),
	.out_bram_din(BRAM_OUT_din)
);

endmodule
