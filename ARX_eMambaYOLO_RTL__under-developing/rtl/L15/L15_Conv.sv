`timescale 1ns / 1ps
// L15 Conv : 01 Conv 3x3 s2 -> 02 SiLU  (= L15 layer_out, L16 Concat main) = ConvSiLU with this layer's numbers
//
//   blk.<instance>   step (LOG / int8_WB)        shape / shift
//   s01_Conv3x3      L15_Conv_01_conv_Conv2d    [64, 80, 80] s5 (L14 XSSBlock layer_out) -> [64, 40, 40] s3, stride 2, out_rshift 9..12
//   s02_SiLU         L15_Conv_02_SiLU           s3 -> s3, layer_out s3
//
// wb_* : weight / bias broadcast (conv window emy_wb_map_pkg::WB_<step>).
// frame_done : the last layer_out pixel has been taken (m_valid & m_ready).
module L15_Conv import emy_pkg::*, emy_wb_map_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:64-1],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:64-1],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

ConvSiLU #(
    .NUM_CH(64),
    .NUM_HEIGHT(80),
    .NUM_WIDTH(80),
    .NUM_OUT(64),
    .STRIDE(2),
    .S02_IN(3),
    .S02_OUT(3),
    .WB_01(WB_L15_Conv_01_conv_Conv2d)
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
