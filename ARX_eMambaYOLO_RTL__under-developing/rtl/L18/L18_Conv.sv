`timescale 1ns / 1ps
// L18 Conv : 01 Conv 3x3 s2 -> 02 SiLU  (= L18 layer_out, L19 Concat main) = ConvSiLU with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)        shape / shift
//   s01_Conv3x3      L18_Conv_01_conv_Conv2d    [128, 40, 40] s5 (L17 XSSBlock layer_out) -> [128, 20, 20] s2, stride 2, out_rshift 10..12
//   s02_SiLU         L18_Conv_02_SiLU           s2 -> s3, layer_out s3
//
// wb_* : weight / bias broadcast (conv window emy_wb_map_pkg::WB_<step>).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L18_Conv import emy_pkg::*, emy_wb_map_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:128-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:128-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

ConvSiLU #(
    .NUM_CH(128),
    .NUM_HEIGHT(40),
    .NUM_WIDTH(40),
    .NUM_OUT(128),
    .STRIDE(2),
    .S02_IN(2),
    .S02_OUT(3),
    .WB_01(WB_L18_Conv_01_conv_Conv2d)
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
