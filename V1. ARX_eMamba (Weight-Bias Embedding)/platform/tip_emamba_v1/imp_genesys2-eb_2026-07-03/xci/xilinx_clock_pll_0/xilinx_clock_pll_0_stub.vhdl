-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2024.1 (lin64) Build 5076996 Wed May 22 18:36:09 MDT 2024
-- Date        : Fri Jul  3 19:12:05 2026
-- Host        : Venus running 64-bit Ubuntu 22.04.5 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/sanghun/RVX/rvx-tutorials/platform/tip_emamba_v1/imp_genesys2-eb_2026-07-03/xci/xilinx_clock_pll_0/xilinx_clock_pll_0_stub.vhdl
-- Design      : xilinx_clock_pll_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7k325tffg900-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xilinx_clock_pll_0 is
  Port ( 
    clk_50000000 : out STD_LOGIC;
    clk_in1_p : in STD_LOGIC;
    clk_in1_n : in STD_LOGIC
  );

end xilinx_clock_pll_0;

architecture stub of xilinx_clock_pll_0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_50000000,clk_in1_p,clk_in1_n";
begin
end;
