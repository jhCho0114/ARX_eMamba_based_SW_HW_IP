`timescale 1ns / 1ps
// L00 SimpleStem : 01 conv0 -> 02 SiLU -> 03 conv3 -> 04 SiLU  (= L00 layer_out)
//
//   instance (= LOG / int8_WB step)   module    shape / shift
//   L00_SimpleStem_01_conv0_Conv2d    Conv3x3   [3, 640, 640] s6  -> [16, 320, 320] s2   stride 2, 3 -> 16
//   L00_SimpleStem_02_SiLU            SiLU      s2 -> s2
//   L00_SimpleStem_03_conv3_Conv2d    Conv3x3   [16, 320, 320] s2 -> [32, 160, 160] s0   stride 2, 16 -> 32
//   L00_SimpleStem_04_SiLU            SiLU      s0 -> s0, layer_out s0
//
// Every output shift equals the next input shift: no requant between the steps. Pixel vectors in raster order with
// the Linear_Transform_Dynamic_WB valid/ready handshake; conv3 starts a row as soon as the step-02 rows it needs are in.
// wb_valid / wb_addr / wb_data : weight / bias broadcast; each conv takes its window emy_wb_map_pkg::WB_<instance>
//              (load before ps_start). Frames stream continuously after one ps_start.
// frame_done : one-cycle pulse when the last layer_out pixel of a frame has been taken (m_valid & m_ready).
module L00_SimpleStem import emy_pkg::*, emy_wb_map_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn  [0:2],      // model input pixels, raster, int8 shift 6
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] dOut [0:31],
    input  logic m_ready,
    output logic m_valid,
    output logic frame_done
);

logic signed [ACT_W-1:0] conv0_dOut [0:15];
logic signed [ACT_W-1:0] silu0_dOut [0:15];
logic signed [ACT_W-1:0] conv3_dOut [0:31];
logic conv0_valid, conv0_ready;
logic silu0_valid, silu0_ready;
logic conv3_valid, conv3_ready;

Conv3x3 #(
    .NUM_CH(3),
    .NUM_HEIGHT(640),
    .NUM_WIDTH(640),
    .NUM_OUT(16),
    .STRIDE(2),
    .WB_BASE(WB_L00_SimpleStem_01_conv0_Conv2d)
) L00_SimpleStem_01_conv0_Conv2d (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(conv0_dOut),
    .m_ready(conv0_ready),
    .m_valid(conv0_valid)
);

SiLU #(
    .NUM_DIM(16),
    .NUM_SCALE_DIN(2),
    .NUM_SCALE_DOUT(2)
) L00_SimpleStem_02_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(conv0_dOut),
    .s_valid(conv0_valid),
    .s_ready(conv0_ready),

    .dOut(silu0_dOut),
    .m_ready(silu0_ready),
    .m_valid(silu0_valid)
);

Conv3x3 #(
    .NUM_CH(16),
    .NUM_HEIGHT(320),
    .NUM_WIDTH(320),
    .NUM_OUT(32),
    .STRIDE(2),
    .WB_BASE(WB_L00_SimpleStem_03_conv3_Conv2d)
) L00_SimpleStem_03_conv3_Conv2d (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(silu0_dOut),
    .s_valid(silu0_valid),
    .s_ready(silu0_ready),

    .dOut(conv3_dOut),
    .m_ready(conv3_ready),
    .m_valid(conv3_valid)
);

SiLU #(
    .NUM_DIM(32),
    .NUM_SCALE_DIN(0),
    .NUM_SCALE_DOUT(0)
) L00_SimpleStem_04_SiLU (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(conv3_dOut),
    .s_valid(conv3_valid),
    .s_ready(conv3_ready),

    .dOut(dOut),
    .m_ready(m_ready),
    .m_valid(m_valid)
);

emy_frame_counter #(
    .NUM_PIX(160 * 160)
) frame_cnt (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .valid(m_valid),
    .ready(m_ready),
    .frame_done(frame_done)
);

endmodule
