-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2024.1 (lin64) Build 5076996 Wed May 22 18:36:09 MDT 2024
-- Date        : Sun Nov  1 20:53:56 2026
-- Host        : Venus running 64-bit Ubuntu 22.04.5 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/sanghun/RVX/n2w_etri/npx_downsampler/platform/eMambaYOLO/imp_edge-19p_2026-11-01/xci/xilinx_clock_pll_0/xilinx_clock_pll_0_stub.vhdl
-- Design      : xilinx_clock_pll_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xcku19p-ffvj1760-3-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity xilinx_clock_pll_0 is
  Port ( 
    clk_25000000 : out STD_LOGIC;
    clk_100000000 : out STD_LOGIC;
    clk_300000000 : out STD_LOGIC;
    clk_150000000 : out STD_LOGIC;
    clk_200000000 : out STD_LOGIC;
    reset : in STD_LOGIC;
    locked : out STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

end xilinx_clock_pll_0;

architecture stub of xilinx_clock_pll_0 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk_25000000,clk_100000000,clk_300000000,clk_150000000,clk_200000000,reset,locked,clk_in1";
begin
end;
