`timescale 1ns / 1ps
// L07_VSSBlock : the whole block, steps 01-29 (SS2D 09-20 inside) = SSBlock with this block's numbers
//
//   Generated from the step graph (docs/step_graph.csv) by a generator script; do not edit by hand.
//   blk.<instance>   step (LOG / int8_WB)
//   s01_Conv1x1      01_proj_Conv2d
//   s02_SiLU         02_proj_SiLU
//   s03_DWConv3x3    03_ls_fc1_DWConv2d
//   s04_Conv1x1      04_ls_fc2_Conv2d
//   s05_SiLU         05_ls_SiLU
//   s06_Conv1x1      06_ls_fc3_Conv2d
//   s07_Add          07_ls_Add
//   s08_LightNorm    08_norm_LightNorm
//   s21_Add          21_Add
//   s22_LightNorm    22_norm2_LightNorm
//   s23_Conv1x1      23_mlp_fc1_Conv2d
//   s24_DWConv3x3    24_mlp_DWConv2d
//   s25_Add          25_mlp_Add
//   s26_SiLU         26_mlp_SiLU
//   s27_Mul          27_mlp_Mul
//   s28_Conv1x1      28_mlp_fc2_Conv2d
//   s29_Add          29_Add
//   ss2d             09-20 (SS2D)
//
//   dIn   [256] s3 layer_out = L06_VisionClueMerge_03_SiLU
//   dOut  [256] s4 output = L07_VSSBlock_29_Add
// wb_* : weight / bias broadcast (load before ps_start). frame_done : one-cycle pulse when the last block output pixel
//   of a frame has been taken; frames stream continuously after one ps_start.
module L07_VSSBlock import emy_pkg::*, emy_wb_map_pkg::*; #(
    parameter integer NUM_LANE = 8      // channels per cycle in DWConv / LightNorm / SS2D gate (SSBlock)
)(
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn [0:255],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:255],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

SSBlock #(
    .NUM_CIN(256),
    .NUM_C(256),
    .NUM_H(20),
    .NUM_W(20),
    .DIN_W(ACT_W),
    .DOUT_W(ACT_W),
    .S_IN(3),
    .S_OUT(4),
    .S01_IN(3),
    .S01_OUT(3),
    .S02_IN(3),
    .S02_OUT(5),
    .S03_IN(5),
    .S03_OUT(2),
    .S04_IN(2),
    .S04_OUT(4),
    .S05_IN(4),
    .S05_OUT(4),
    .S06_IN(4),
    .S06_OUT(6),
    .S08_IN(4),
    .S08_W(4),
    .S08_B(5),
    .S08_OUT(3),
    .S09_IN(3),
    .S09_OUT(4),
    .S10_IN(4),
    .S10_OUT(4),
    .S11_IN(4),
    .S11_OUT(4),
    .S12_IN(4),
    .S12_OUT(4),
    .K0_S_U(4),
    .K0_S_DELTA(5),
    .K0_S_A(6),
    .K0_S_DA(7),
    .K0_S_B(7),
    .K0_S_DB(5),
    .K0_S_C(6),
    .K0_S_D(10),
    .K0_S_Y(7),
    .K1_S_U(4),
    .K1_S_DELTA(5),
    .K1_S_A(6),
    .K1_S_DA(7),
    .K1_S_B(7),
    .K1_S_DB(6),
    .K1_S_C(6),
    .K1_S_D(10),
    .K1_S_Y(7),
    .K2_S_U(4),
    .K2_S_DELTA(5),
    .K2_S_A(6),
    .K2_S_DA(7),
    .K2_S_B(7),
    .K2_S_DB(6),
    .K2_S_C(6),
    .K2_S_D(10),
    .K2_S_Y(7),
    .K3_S_U(4),
    .K3_S_DELTA(5),
    .K3_S_A(6),
    .K3_S_DA(7),
    .K3_S_B(7),
    .K3_S_DB(5),
    .K3_S_C(6),
    .K3_S_D(10),
    .K3_S_Y(7),
    .S18_IN(6),
    .S18_W(4),
    .S18_B(6),
    .S18_OUT(3),
    .S20_IN(3),
    .S20_OUT(6),
    .S22_IN(4),
    .S22_W(5),
    .S22_B(6),
    .S22_OUT(3),
    .S23_IN(3),
    .S23_OUT(4),
    .S24_IN(4),
    .S24_OUT(5),
    .S26_IN(4),
    .S26_OUT(4),
    .S28_IN(3),
    .S28_OUT(6),
    .WB_01(WB_L07_VSSBlock_01_proj_Conv2d),
    .WB_03(WB_L07_VSSBlock_03_ls_fc1_DWConv2d),
    .WB_04(WB_L07_VSSBlock_04_ls_fc2_Conv2d),
    .WB_06(WB_L07_VSSBlock_06_ls_fc3_Conv2d),
    .WB_08(WB_L07_VSSBlock_08_norm_LightNorm),
    .WB_SS2D(WB_L07_VSSBlock_ss2d),
    .WB_22(WB_L07_VSSBlock_22_norm2_LightNorm),
    .WB_23(WB_L07_VSSBlock_23_mlp_fc1_Conv2d),
    .WB_24(WB_L07_VSSBlock_24_mlp_DWConv2d),
    .WB_28(WB_L07_VSSBlock_28_mlp_fc2_Conv2d),
    .NUM_LANE(NUM_LANE)
) blk (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid),
    .frame_done(frame_done)
);

endmodule
