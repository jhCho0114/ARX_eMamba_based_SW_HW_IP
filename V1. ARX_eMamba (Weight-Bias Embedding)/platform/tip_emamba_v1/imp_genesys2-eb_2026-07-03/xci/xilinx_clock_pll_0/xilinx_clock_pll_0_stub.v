// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (lin64) Build 5076996 Wed May 22 18:36:09 MDT 2024
// Date        : Fri Jul  3 19:12:05 2026
// Host        : Venus running 64-bit Ubuntu 22.04.5 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/sanghun/RVX/rvx-tutorials/platform/tip_emamba_v1/imp_genesys2-eb_2026-07-03/xci/xilinx_clock_pll_0/xilinx_clock_pll_0_stub.v
// Design      : xilinx_clock_pll_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7k325tffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module xilinx_clock_pll_0(clk_50000000, clk_in1_p, clk_in1_n)
/* synthesis syn_black_box black_box_pad_pin="clk_in1_p,clk_in1_n" */
/* synthesis syn_force_seq_prim="clk_50000000" */;
  output clk_50000000 /* synthesis syn_isclock = 1 */;
  input clk_in1_p;
  input clk_in1_n;
endmodule
