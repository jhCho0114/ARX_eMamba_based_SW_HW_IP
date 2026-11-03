// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (lin64) Build 5076996 Wed May 22 18:36:09 MDT 2024
// Date        : Mon Oct 26 15:28:18 2026
// Host        : Venus running 64-bit Ubuntu 22.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/sanghun/RVX/n2w_etri/npx_downsampler/platform/u601/imp_edge-19p_2026-10-26/xci/xilinx_clock_pll_0/xilinx_clock_pll_0_stub.v
// Design      : xilinx_clock_pll_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xcku19p-ffvj1760-3-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module xilinx_clock_pll_0(clk_25000000, clk_100000000, clk_300000000, 
  clk_150000000, clk_200000000, reset, locked, clk_in1)
/* synthesis syn_black_box black_box_pad_pin="reset,locked,clk_in1" */
/* synthesis syn_force_seq_prim="clk_25000000" */
/* synthesis syn_force_seq_prim="clk_100000000" */
/* synthesis syn_force_seq_prim="clk_300000000" */
/* synthesis syn_force_seq_prim="clk_150000000" */
/* synthesis syn_force_seq_prim="clk_200000000" */;
  output clk_25000000 /* synthesis syn_isclock = 1 */;
  output clk_100000000 /* synthesis syn_isclock = 1 */;
  output clk_300000000 /* synthesis syn_isclock = 1 */;
  output clk_150000000 /* synthesis syn_isclock = 1 */;
  output clk_200000000 /* synthesis syn_isclock = 1 */;
  input reset;
  output locked;
  input clk_in1;
endmodule
