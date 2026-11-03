// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.2 (lin64) Build 6299465 Fri Nov 14 12:34:56 MST 2025
// Date        : Mon Jun 29 16:05:04 2026
// Host        : subinki running 64-bit Red Hat Enterprise Linux release 8.10 (Ootpa)
// Command     : write_verilog -force -mode synth_stub
//               /home/subinki/project/ARX/edge_video_system/ip_package_test/EDGE_VIDEO_SYSTEM_stub.v
// Design      : EDGE_VIDEO_SYSTEM
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku19p-ffvj1760-3-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* BW_ADDR = "32" *) (* BW_APB_DATA = "32" *) (* BW_AXI_TID = "4" *) 
(* BW_SDRAM_DATA = "32" *) (* BW_VDMA_DATA = "128" *) (* BW_VIM_DATA = "128" *) 
(* BW_VOM_DATA = "128" *) 
module EDGE_VIDEO_SYSTEM
#(
  parameter BW_ADDR = 32
)
(global_rstnn, rstnn_noc, clk_apb, tick_1us, 
  clk_vdma, vdma_sxawid, vdma_sxawaddr, vdma_sxawlen, vdma_sxawsize, vdma_sxawburst, 
  vdma_sxawvalid, vdma_sxawready, vdma_sxwid, vdma_sxwdata, vdma_sxwstrb, vdma_sxwlast, 
  vdma_sxwvalid, vdma_sxwready, vdma_sxbid, vdma_sxbresp, vdma_sxbvalid, vdma_sxbready, 
  vdma_sxarid, vdma_sxaraddr, vdma_sxarlen, vdma_sxarsize, vdma_sxarburst, vdma_sxarvalid, 
  vdma_sxarready, vdma_sxrid, vdma_sxrdata, vdma_sxrresp, vdma_sxrlast, vdma_sxrvalid, 
  vdma_sxrready, vdma_ctrl_rpsel, vdma_ctrl_rpenable, vdma_ctrl_rpaddr, vdma_ctrl_rpwrite, 
  vdma_ctrl_rpwdata, vdma_ctrl_rprdata, vdma_ctrl_rpready, vdma_ctrl_rpslverr, rstnn_video, 
  clk_25M, clk_50M, clk_150M, clk_200M, clk_300M, clk_vimif, vim_sxawid, vim_sxawaddr, vim_sxawlen, 
  vim_sxawsize, vim_sxawburst, vim_sxawvalid, vim_sxawready, vim_sxwid, vim_sxwdata, 
  vim_sxwstrb, vim_sxwlast, vim_sxwvalid, vim_sxwready, vim_sxbid, vim_sxbresp, vim_sxbvalid, 
  vim_sxbready, vim_sxarid, vim_sxaraddr, vim_sxarlen, vim_sxarsize, vim_sxarburst, 
  vim_sxarvalid, vim_sxarready, vim_sxrid, vim_sxrdata, vim_sxrresp, vim_sxrlast, vim_sxrvalid, 
  vim_sxrready, clk_vomif, vom_sxawid, vom_sxawaddr, vom_sxawlen, vom_sxawsize, vom_sxawburst, 
  vom_sxawvalid, vom_sxawready, vom_sxwid, vom_sxwdata, vom_sxwstrb, vom_sxwlast, vom_sxwvalid, 
  vom_sxwready, vom_sxbid, vom_sxbresp, vom_sxbvalid, vom_sxbready, vom_sxarid, vom_sxaraddr, 
  vom_sxarlen, vom_sxarsize, vom_sxarburst, vom_sxarvalid, vom_sxarready, vom_sxrid, 
  vom_sxrdata, vom_sxrresp, vom_sxrlast, vom_sxrvalid, vom_sxrready, video_ctrl_rpsel, 
  video_ctrl_rpenable, video_ctrl_rpaddr, video_ctrl_rpwrite, video_ctrl_rpwdata, 
  video_ctrl_rprdata, video_ctrl_rpready, video_ctrl_rpslverr, hdmi_rclk_od, 
  hdmi_rclk_oval, hdmi_rclk_ival, hdmi_rdata_od, hdmi_rdata_oval, hdmi_rdata_ival, 
  cis_rclk_od, cis_rclk_oval, cis_rclk_ival, cis_rdata_od, cis_rdata_oval, cis_rdata_ival, 
  HDMI_I2C_SCL, HDMI_I2C_SDA, HDMI_RX_DCK, HDMI_RX_HS, HDMI_RX_DE, HDMI_RX_VS, HDMI_RX_RST_N, 
  HDMI_RX_VD, HDMI_RX_AMCLK, HDMI_RX_ASCLK, HDMI_RX_AP, CIS_I2C_SCL, CIS_I2C_SDA, CIS_MCLK, 
  CIS_PCLK, CIS_RESET_N, CIS_VS, CIS_HS, CIS_PD_N, CIS_D, HDMI_TX_DCK, HDMI_TX_DE, HDMI_TX_HS, 
  HDMI_TX_VS, HDMI_TX_RST_N, HDMI_TX_VD, HDMI_TX_AO_MCLK, HDMI_TX_AO_SCK, HDMI_TX_AO_WS, 
  HDMI_TX_AO_SD, HDMI_TX_AO_SPDIF)
/* synthesis syn_black_box black_box_pad_pin="global_rstnn,rstnn_noc,tick_1us,vdma_sxawid[3:0],vdma_sxawaddr[31:0],vdma_sxawlen[7:0],vdma_sxawsize[2:0],vdma_sxawburst[1:0],vdma_sxawvalid,vdma_sxawready,vdma_sxwid[3:0],vdma_sxwdata[127:0],vdma_sxwstrb[15:0],vdma_sxwlast,vdma_sxwvalid,vdma_sxwready,vdma_sxbid[3:0],vdma_sxbresp[1:0],vdma_sxbvalid,vdma_sxbready,vdma_sxarid[3:0],vdma_sxaraddr[31:0],vdma_sxarlen[7:0],vdma_sxarsize[2:0],vdma_sxarburst[1:0],vdma_sxarvalid,vdma_sxarready,vdma_sxrid[3:0],vdma_sxrdata[127:0],vdma_sxrresp[1:0],vdma_sxrlast,vdma_sxrvalid,vdma_sxrready,vdma_ctrl_rpsel,vdma_ctrl_rpenable,vdma_ctrl_rpaddr[31:0],vdma_ctrl_rpwrite,vdma_ctrl_rpwdata[31:0],vdma_ctrl_rprdata[31:0],vdma_ctrl_rpready,vdma_ctrl_rpslverr,rstnn_video,clk_25M,clk_150M,clk_300M,vim_sxawid[3:0],vim_sxawaddr[31:0],vim_sxawlen[7:0],vim_sxawsize[2:0],vim_sxawburst[1:0],vim_sxawvalid,vim_sxawready,vim_sxwid[3:0],vim_sxwdata[127:0],vim_sxwstrb[15:0],vim_sxwlast,vim_sxwvalid,vim_sxwready,vim_sxbid[3:0],vim_sxbresp[1:0],vim_sxbvalid,vim_sxbready,vim_sxarid[3:0],vim_sxaraddr[31:0],vim_sxarlen[7:0],vim_sxarsize[2:0],vim_sxarburst[1:0],vim_sxarvalid,vim_sxarready,vim_sxrid[3:0],vim_sxrdata[127:0],vim_sxrresp[1:0],vim_sxrlast,vim_sxrvalid,vim_sxrready,vom_sxawid[3:0],vom_sxawaddr[31:0],vom_sxawlen[7:0],vom_sxawsize[2:0],vom_sxawburst[1:0],vom_sxawvalid,vom_sxawready,vom_sxwid[3:0],vom_sxwdata[127:0],vom_sxwstrb[15:0],vom_sxwlast,vom_sxwvalid,vom_sxwready,vom_sxbid[3:0],vom_sxbresp[1:0],vom_sxbvalid,vom_sxbready,vom_sxarid[3:0],vom_sxaraddr[31:0],vom_sxarlen[7:0],vom_sxarsize[2:0],vom_sxarburst[1:0],vom_sxarvalid,vom_sxarready,vom_sxrid[3:0],vom_sxrdata[127:0],vom_sxrresp[1:0],vom_sxrlast,vom_sxrvalid,vom_sxrready,video_ctrl_rpsel,video_ctrl_rpenable,video_ctrl_rpaddr[31:0],video_ctrl_rpwrite,video_ctrl_rpwdata[31:0],video_ctrl_rprdata[31:0],video_ctrl_rpready,video_ctrl_rpslverr,hdmi_rclk_od,hdmi_rclk_oval,hdmi_rclk_ival,hdmi_rdata_od,hdmi_rdata_oval,hdmi_rdata_ival,cis_rclk_od,cis_rclk_oval,cis_rclk_ival,cis_rdata_od,cis_rdata_oval,cis_rdata_ival,HDMI_I2C_SCL,HDMI_I2C_SDA,HDMI_RX_DCK,HDMI_RX_HS,HDMI_RX_DE,HDMI_RX_VS,HDMI_RX_RST_N,HDMI_RX_VD[35:0],HDMI_RX_AMCLK,HDMI_RX_ASCLK,HDMI_RX_AP[5:0],CIS_I2C_SCL,CIS_I2C_SDA,CIS_MCLK,CIS_PCLK,CIS_RESET_N,CIS_VS,CIS_HS,CIS_PD_N,CIS_D[7:0],HDMI_TX_DCK,HDMI_TX_DE,HDMI_TX_HS,HDMI_TX_VS,HDMI_TX_RST_N,HDMI_TX_VD[35:0],HDMI_TX_AO_MCLK,HDMI_TX_AO_SCK,HDMI_TX_AO_WS,HDMI_TX_AO_SD[3:0],HDMI_TX_AO_SPDIF" */
/* synthesis syn_force_seq_prim="clk_apb" */
/* synthesis syn_force_seq_prim="clk_vdma" */
/* synthesis syn_force_seq_prim="clk_50M" */
/* synthesis syn_force_seq_prim="clk_200M" */
/* synthesis syn_force_seq_prim="clk_vimif" */
/* synthesis syn_force_seq_prim="clk_vomif" */;
  input global_rstnn;
  input rstnn_noc;
  input clk_apb /* synthesis syn_isclock = 1 */;
  input tick_1us;
  input clk_vdma /* synthesis syn_isclock = 1 */;
  output [3:0]vdma_sxawid;
  output [31:0]vdma_sxawaddr;
  output [7:0]vdma_sxawlen;
  output [2:0]vdma_sxawsize;
  output [1:0]vdma_sxawburst;
  output vdma_sxawvalid;
  input vdma_sxawready;
  output [3:0]vdma_sxwid;
  output [127:0]vdma_sxwdata;
  output [15:0]vdma_sxwstrb;
  output vdma_sxwlast;
  output vdma_sxwvalid;
  input vdma_sxwready;
  input [3:0]vdma_sxbid;
  input [1:0]vdma_sxbresp;
  input vdma_sxbvalid;
  output vdma_sxbready;
  output [3:0]vdma_sxarid;
  output [31:0]vdma_sxaraddr;
  output [7:0]vdma_sxarlen;
  output [2:0]vdma_sxarsize;
  output [1:0]vdma_sxarburst;
  output vdma_sxarvalid;
  input vdma_sxarready;
  input [3:0]vdma_sxrid;
  input [127:0]vdma_sxrdata;
  input [1:0]vdma_sxrresp;
  input vdma_sxrlast;
  input vdma_sxrvalid;
  output vdma_sxrready;
  input vdma_ctrl_rpsel;
  input vdma_ctrl_rpenable;
  input [31:0]vdma_ctrl_rpaddr;
  input vdma_ctrl_rpwrite;
  input [31:0]vdma_ctrl_rpwdata;
  output [31:0]vdma_ctrl_rprdata;
  output vdma_ctrl_rpready;
  output vdma_ctrl_rpslverr;
  input rstnn_video;
  input clk_25M;
  input clk_50M /* synthesis syn_isclock = 1 */;
  input clk_150M;
  input clk_200M /* synthesis syn_isclock = 1 */;
  input clk_300M;
  input clk_vimif /* synthesis syn_isclock = 1 */;
  output [3:0]vim_sxawid;
  output [31:0]vim_sxawaddr;
  output [7:0]vim_sxawlen;
  output [2:0]vim_sxawsize;
  output [1:0]vim_sxawburst;
  output vim_sxawvalid;
  input vim_sxawready;
  output [3:0]vim_sxwid;
  output [127:0]vim_sxwdata;
  output [15:0]vim_sxwstrb;
  output vim_sxwlast;
  output vim_sxwvalid;
  input vim_sxwready;
  input [3:0]vim_sxbid;
  input [1:0]vim_sxbresp;
  input vim_sxbvalid;
  output vim_sxbready;
  output [3:0]vim_sxarid;
  output [31:0]vim_sxaraddr;
  output [7:0]vim_sxarlen;
  output [2:0]vim_sxarsize;
  output [1:0]vim_sxarburst;
  output vim_sxarvalid;
  input vim_sxarready;
  input [3:0]vim_sxrid;
  input [127:0]vim_sxrdata;
  input [1:0]vim_sxrresp;
  input vim_sxrlast;
  input vim_sxrvalid;
  output vim_sxrready;
  input clk_vomif /* synthesis syn_isclock = 1 */;
  output [3:0]vom_sxawid;
  output [31:0]vom_sxawaddr;
  output [7:0]vom_sxawlen;
  output [2:0]vom_sxawsize;
  output [1:0]vom_sxawburst;
  output vom_sxawvalid;
  input vom_sxawready;
  output [3:0]vom_sxwid;
  output [127:0]vom_sxwdata;
  output [15:0]vom_sxwstrb;
  output vom_sxwlast;
  output vom_sxwvalid;
  input vom_sxwready;
  input [3:0]vom_sxbid;
  input [1:0]vom_sxbresp;
  input vom_sxbvalid;
  output vom_sxbready;
  output [3:0]vom_sxarid;
  output [31:0]vom_sxaraddr;
  output [7:0]vom_sxarlen;
  output [2:0]vom_sxarsize;
  output [1:0]vom_sxarburst;
  output vom_sxarvalid;
  input vom_sxarready;
  input [3:0]vom_sxrid;
  input [127:0]vom_sxrdata;
  input [1:0]vom_sxrresp;
  input vom_sxrlast;
  input vom_sxrvalid;
  output vom_sxrready;
  input video_ctrl_rpsel;
  input video_ctrl_rpenable;
  input [31:0]video_ctrl_rpaddr;
  input video_ctrl_rpwrite;
  input [31:0]video_ctrl_rpwdata;
  output [31:0]video_ctrl_rprdata;
  output video_ctrl_rpready;
  output video_ctrl_rpslverr;
  input hdmi_rclk_od;
  input hdmi_rclk_oval;
  output hdmi_rclk_ival;
  input hdmi_rdata_od;
  input hdmi_rdata_oval;
  output hdmi_rdata_ival;
  input cis_rclk_od;
  input cis_rclk_oval;
  output cis_rclk_ival;
  input cis_rdata_od;
  input cis_rdata_oval;
  output cis_rdata_ival;
  inout HDMI_I2C_SCL;
  inout HDMI_I2C_SDA;
  input HDMI_RX_DCK;
  input HDMI_RX_HS;
  input HDMI_RX_DE;
  input HDMI_RX_VS;
  output HDMI_RX_RST_N;
  input [35:0]HDMI_RX_VD;
  input HDMI_RX_AMCLK;
  input HDMI_RX_ASCLK;
  input [5:0]HDMI_RX_AP;
  inout CIS_I2C_SCL;
  inout CIS_I2C_SDA;
  output CIS_MCLK;
  input CIS_PCLK;
  output CIS_RESET_N;
  input CIS_VS;
  input CIS_HS;
  output CIS_PD_N;
  input [7:0]CIS_D;
  output HDMI_TX_DCK;
  output HDMI_TX_DE;
  output HDMI_TX_HS;
  output HDMI_TX_VS;
  output HDMI_TX_RST_N;
  output [35:0]HDMI_TX_VD;
  output HDMI_TX_AO_MCLK;
  output HDMI_TX_AO_SCK;
  output HDMI_TX_AO_WS;
  output [3:0]HDMI_TX_AO_SD;
  output HDMI_TX_AO_SPDIF;
endmodule
