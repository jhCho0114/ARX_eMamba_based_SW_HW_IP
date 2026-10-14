`timescale 1ns / 1ps
// L02 VisionClueMerge : 01 SpaceToDepth -> 02 pw_linear Conv 1x1 -> 03 SiLU  (= L02 layer_out) = VisionClueMerge with this layer's numbers
//
//   blk.<instance>     step (LOG / int8_WB)                    shape / shift
//   s01_SpaceToDepth   L02_VisionClueMerge_01_SpaceToDepth       [32, 160, 160] s3 (L01 layer_out) -> [128, 80, 80] s3
//   s02_Conv1x1        L02_VisionClueMerge_02_pw_linear_Conv2d   128 -> 64, s3 -> s4, out_rshift 7..9
//   s03_SiLU           L02_VisionClueMerge_03_SiLU               s4 -> s4, layer_out s4
//
// wb_* : weight / bias broadcast (conv window emy_wb_map_pkg::WB_<step>).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L02_VisionClueMerge import emy_pkg::*, emy_wb_map_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:32-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:64-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

VisionClueMerge #(
    .NUM_CH(32),
    .NUM_HEIGHT(160),
    .NUM_WIDTH(160),
    .S03_IN(4),
    .S03_OUT(4),
    .WB_02(WB_L02_VisionClueMerge_02_pw_linear_Conv2d)
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
