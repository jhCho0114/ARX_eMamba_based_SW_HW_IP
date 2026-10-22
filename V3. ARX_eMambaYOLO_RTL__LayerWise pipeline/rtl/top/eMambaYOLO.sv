`timescale 1ns / 1ps
// eMambaYOLO : the INT8 eMamba-YOLO (Mamba-YOLO-T) L00-L20, the layer modules of rtl/Lxx wired as the step graph
//
//   Generated from the step graph (docs/step_graph.csv) by a generator script; do not edit by hand.
//   input  : dIn [3] pixels of the 640 x 640 image, raster, int8 shift 6
//   output : P3 = L14 layer_out [64, 80, 80], P4 = L17 [128, 40, 40], P5 = L20 [256, 20, 20] (Detect inputs)
//   wb_*   : one weight / bias broadcast for every layer (the whole image, emy_wb_map_pkg), before ps_start
//   frame  : v2, one ps_start (power-up / abort), then frames stream continuously (no s_valid in the ps_start cycle);
//            layer_done[i] = frame_done pulse of layer i (order below); frame_done = pulse when P3, P4 and P5 have all
//            finished one more frame (the frame counters of the three outputs, min).
//   Streams: pixel vectors, raster, Linear_Transform_Dynamic_WB valid / ready. A layer with two consumers goes
//   through emy_stream_fork; the skip operand of a Concat waits in the one-frame FIFO inside the Concat layer.
//
//   i   instance              input (main)          skip             consumers
//   0   l00_SimpleStem        dIn                                    L01_VSSBlock
//   1   l01_VSSBlock          L00_SimpleStem                         L02_VisionClueMerge
//   2   l02_VisionClueMerge   L01_VSSBlock                           L03_VSSBlock
//   3   l03_VSSBlock          L02_VisionClueMerge                    L04_VisionClueMerge, L13_Concat
//   4   l04_VisionClueMerge   L03_VSSBlock                           L05_VSSBlock0
//   5   l050_VSSBlock0        L04_VisionClueMerge                    L05_VSSBlock1
//   6   l051_VSSBlock1        L05_VSSBlock0                          L05_VSSBlock2
//   7   l052_VSSBlock2        L05_VSSBlock1                          L06_VisionClueMerge, L10_Concat
//   8   l06_VisionClueMerge   L05_VSSBlock2                          L07_VSSBlock
//   9   l07_VSSBlock          L06_VisionClueMerge                    L08_SPPF
//   10  l08_SPPF              L07_VSSBlock                           L09_Upsample, L19_Concat
//   11  l09_Upsample          L08_SPPF                               L10_Concat
//   12  l10_Concat            L09_Upsample          L05_VSSBlock2    L11_XSSBlock
//   13  l11_XSSBlock          L10_Concat                             L12_Upsample, L16_Concat
//   14  l12_Upsample          L11_XSSBlock                           L13_Concat
//   15  l13_Concat            L12_Upsample          L03_VSSBlock     L14_XSSBlock
//   16  l14_XSSBlock          L13_Concat                             L15_Conv, P3
//   17  l15_Conv              L14_XSSBlock                           L16_Concat
//   18  l16_Concat            L15_Conv              L11_XSSBlock     L17_XSSBlock
//   19  l17_XSSBlock          L16_Concat                             L18_Conv, P4
//   20  l18_Conv              L17_XSSBlock                           L19_Concat
//   21  l19_Concat            L18_Conv              L08_SPPF         L20_XSSBlock
//   22  l20_XSSBlock          L19_Concat                             P5
module eMambaYOLO import emy_pkg::*; (
    input  logic clk,
    input  logic nRst,
    input  logic ps_start,

    input  logic wb_valid,
    input  logic [WB_ADDR_W-1:0] wb_addr,
    input  logic [WB_DATA_W-1:0] wb_data,

    input  logic signed [ACT_W-1:0] dIn [0:2],
    input  logic s_valid,
    output logic s_ready,

    output logic signed [ACT_W-1:0] p3_dOut [0:63],     // L14_XSSBlock output s5, 80 x 80
    output logic p3_m_valid,
    input  logic p3_m_ready,

    output logic signed [ACT_W-1:0] p4_dOut [0:127],     // L17_XSSBlock output s5, 40 x 40
    output logic p4_m_valid,
    input  logic p4_m_ready,

    output logic signed [ACT_W-1:0] p5_dOut [0:255],     // L20_XSSBlock output s5, 20 x 20
    output logic p5_m_valid,
    input  logic p5_m_ready,

    output logic frame_done,
    output logic layer_done [0:22]
);

logic signed [ACT_W-1:0] l00_dOut [0:31];
logic l00_valid, l00_ready;
logic signed [ACT_W-1:0] l01_dOut [0:31];
logic l01_valid, l01_ready;
logic signed [ACT_W-1:0] l02_dOut [0:63];
logic l02_valid, l02_ready;
logic signed [ACT_W-1:0] l03_dOut [0:63];
logic l03_valid, l03_ready;
logic signed [ACT_W-1:0] l03_b0_dOut [0:63];
logic l03_b0_valid, l03_b0_ready;
logic signed [ACT_W-1:0] l03_b1_dOut [0:63];
logic l03_b1_valid, l03_b1_ready;
logic signed [ACT_W-1:0] l04_dOut [0:127];
logic l04_valid, l04_ready;
logic signed [WIDE_W-1:0] l050_dOut [0:127];
logic l050_valid, l050_ready;
logic signed [WIDE_W-1:0] l051_dOut [0:127];
logic l051_valid, l051_ready;
logic signed [ACT_W-1:0] l052_dOut [0:127];
logic l052_valid, l052_ready;
logic signed [ACT_W-1:0] l052_b0_dOut [0:127];
logic l052_b0_valid, l052_b0_ready;
logic signed [ACT_W-1:0] l052_b1_dOut [0:127];
logic l052_b1_valid, l052_b1_ready;
logic signed [ACT_W-1:0] l06_dOut [0:255];
logic l06_valid, l06_ready;
logic signed [ACT_W-1:0] l07_dOut [0:255];
logic l07_valid, l07_ready;
logic signed [ACT_W-1:0] l08_dOut [0:255];
logic l08_valid, l08_ready;
logic signed [ACT_W-1:0] l08_b0_dOut [0:255];
logic l08_b0_valid, l08_b0_ready;
logic signed [ACT_W-1:0] l08_b1_dOut [0:255];
logic l08_b1_valid, l08_b1_ready;
logic signed [ACT_W-1:0] l09_dOut [0:255];
logic l09_valid, l09_ready;
logic signed [ACT_W-1:0] l10_dOut [0:383];
logic l10_valid, l10_ready;
logic signed [ACT_W-1:0] l11_dOut [0:127];
logic l11_valid, l11_ready;
logic signed [ACT_W-1:0] l11_b0_dOut [0:127];
logic l11_b0_valid, l11_b0_ready;
logic signed [ACT_W-1:0] l11_b1_dOut [0:127];
logic l11_b1_valid, l11_b1_ready;
logic signed [ACT_W-1:0] l12_dOut [0:127];
logic l12_valid, l12_ready;
logic signed [ACT_W-1:0] l13_dOut [0:191];
logic l13_valid, l13_ready;
logic signed [ACT_W-1:0] l14_dOut [0:63];
logic l14_valid, l14_ready;
logic signed [ACT_W-1:0] l14_b0_dOut [0:63];
logic l14_b0_valid, l14_b0_ready;
logic signed [ACT_W-1:0] l14_b1_dOut [0:63];
logic l14_b1_valid, l14_b1_ready;
logic signed [ACT_W-1:0] l15_dOut [0:63];
logic l15_valid, l15_ready;
logic signed [ACT_W-1:0] l16_dOut [0:191];
logic l16_valid, l16_ready;
logic signed [ACT_W-1:0] l17_dOut [0:127];
logic l17_valid, l17_ready;
logic signed [ACT_W-1:0] l17_b0_dOut [0:127];
logic l17_b0_valid, l17_b0_ready;
logic signed [ACT_W-1:0] l17_b1_dOut [0:127];
logic l17_b1_valid, l17_b1_ready;
logic signed [ACT_W-1:0] l18_dOut [0:127];
logic l18_valid, l18_ready;
logic signed [ACT_W-1:0] l19_dOut [0:383];
logic l19_valid, l19_ready;
logic signed [ACT_W-1:0] l20_dOut [0:255];
logic l20_valid, l20_ready;

// ---------- forks (a layer output with two consumers) ---------- //
emy_stream_fork #(
    .NUM_DIM(64),
    .DATA_W(ACT_W)
) l03_fork (
    .dIn(l03_dOut),
    .s_valid(l03_valid),
    .s_ready(l03_ready),

    .dOut0(l03_b0_dOut),
    .m_valid0(l03_b0_valid),
    .m_ready0(l03_b0_ready),

    .dOut1(l03_b1_dOut),
    .m_valid1(l03_b1_valid),
    .m_ready1(l03_b1_ready)
);

emy_stream_fork #(
    .NUM_DIM(128),
    .DATA_W(ACT_W)
) l052_fork (
    .dIn(l052_dOut),
    .s_valid(l052_valid),
    .s_ready(l052_ready),

    .dOut0(l052_b0_dOut),
    .m_valid0(l052_b0_valid),
    .m_ready0(l052_b0_ready),

    .dOut1(l052_b1_dOut),
    .m_valid1(l052_b1_valid),
    .m_ready1(l052_b1_ready)
);

emy_stream_fork #(
    .NUM_DIM(256),
    .DATA_W(ACT_W)
) l08_fork (
    .dIn(l08_dOut),
    .s_valid(l08_valid),
    .s_ready(l08_ready),

    .dOut0(l08_b0_dOut),
    .m_valid0(l08_b0_valid),
    .m_ready0(l08_b0_ready),

    .dOut1(l08_b1_dOut),
    .m_valid1(l08_b1_valid),
    .m_ready1(l08_b1_ready)
);

emy_stream_fork #(
    .NUM_DIM(128),
    .DATA_W(ACT_W)
) l11_fork (
    .dIn(l11_dOut),
    .s_valid(l11_valid),
    .s_ready(l11_ready),

    .dOut0(l11_b0_dOut),
    .m_valid0(l11_b0_valid),
    .m_ready0(l11_b0_ready),

    .dOut1(l11_b1_dOut),
    .m_valid1(l11_b1_valid),
    .m_ready1(l11_b1_ready)
);

emy_stream_fork #(
    .NUM_DIM(64),
    .DATA_W(ACT_W)
) l14_fork (
    .dIn(l14_dOut),
    .s_valid(l14_valid),
    .s_ready(l14_ready),

    .dOut0(l14_b0_dOut),
    .m_valid0(l14_b0_valid),
    .m_ready0(l14_b0_ready),

    .dOut1(l14_b1_dOut),
    .m_valid1(l14_b1_valid),
    .m_ready1(l14_b1_ready)
);

emy_stream_fork #(
    .NUM_DIM(128),
    .DATA_W(ACT_W)
) l17_fork (
    .dIn(l17_dOut),
    .s_valid(l17_valid),
    .s_ready(l17_ready),

    .dOut0(l17_b0_dOut),
    .m_valid0(l17_b0_valid),
    .m_ready0(l17_b0_ready),

    .dOut1(l17_b1_dOut),
    .m_valid1(l17_b1_valid),
    .m_ready1(l17_b1_ready)
);

// ---------- L00_SimpleStem ---------- //
L00_SimpleStem l00_SimpleStem (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(dIn),
    .s_valid(s_valid),
    .s_ready(s_ready),

    .dOut(l00_dOut),
    .m_ready(l00_ready),
    .m_valid(l00_valid),
    .frame_done(layer_done[0])
);

// ---------- L01_VSSBlock ---------- //
L01_VSSBlock l01_VSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l00_dOut),
    .s_valid(l00_valid),
    .s_ready(l00_ready),

    .dOut(l01_dOut),
    .m_ready(l01_ready),
    .m_valid(l01_valid),
    .frame_done(layer_done[1])
);

// ---------- L02_VisionClueMerge ---------- //
L02_VisionClueMerge l02_VisionClueMerge (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l01_dOut),
    .s_valid(l01_valid),
    .s_ready(l01_ready),

    .dOut(l02_dOut),
    .m_ready(l02_ready),
    .m_valid(l02_valid),
    .frame_done(layer_done[2])
);

// ---------- L03_VSSBlock ---------- //
L03_VSSBlock l03_VSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l02_dOut),
    .s_valid(l02_valid),
    .s_ready(l02_ready),

    .dOut(l03_dOut),
    .m_ready(l03_ready),
    .m_valid(l03_valid),
    .frame_done(layer_done[3])
);

// ---------- L04_VisionClueMerge ---------- //
L04_VisionClueMerge l04_VisionClueMerge (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l03_b0_dOut),
    .s_valid(l03_b0_valid),
    .s_ready(l03_b0_ready),

    .dOut(l04_dOut),
    .m_ready(l04_ready),
    .m_valid(l04_valid),
    .frame_done(layer_done[4])
);

// ---------- L05_VSSBlock0 ---------- //
L05_VSSBlock0 l050_VSSBlock0 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l04_dOut),
    .s_valid(l04_valid),
    .s_ready(l04_ready),

    .dOut(l050_dOut),
    .m_ready(l050_ready),
    .m_valid(l050_valid),
    .frame_done(layer_done[5])
);

// ---------- L05_VSSBlock1 ---------- //
L05_VSSBlock1 l051_VSSBlock1 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l050_dOut),
    .s_valid(l050_valid),
    .s_ready(l050_ready),

    .dOut(l051_dOut),
    .m_ready(l051_ready),
    .m_valid(l051_valid),
    .frame_done(layer_done[6])
);

// ---------- L05_VSSBlock2 ---------- //
L05_VSSBlock2 l052_VSSBlock2 (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l051_dOut),
    .s_valid(l051_valid),
    .s_ready(l051_ready),

    .dOut(l052_dOut),
    .m_ready(l052_ready),
    .m_valid(l052_valid),
    .frame_done(layer_done[7])
);

// ---------- L06_VisionClueMerge ---------- //
L06_VisionClueMerge l06_VisionClueMerge (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l052_b0_dOut),
    .s_valid(l052_b0_valid),
    .s_ready(l052_b0_ready),

    .dOut(l06_dOut),
    .m_ready(l06_ready),
    .m_valid(l06_valid),
    .frame_done(layer_done[8])
);

// ---------- L07_VSSBlock ---------- //
L07_VSSBlock l07_VSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l06_dOut),
    .s_valid(l06_valid),
    .s_ready(l06_ready),

    .dOut(l07_dOut),
    .m_ready(l07_ready),
    .m_valid(l07_valid),
    .frame_done(layer_done[9])
);

// ---------- L08_SPPF ---------- //
L08_SPPF l08_SPPF (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l07_dOut),
    .s_valid(l07_valid),
    .s_ready(l07_ready),

    .dOut(l08_dOut),
    .m_ready(l08_ready),
    .m_valid(l08_valid),
    .frame_done(layer_done[10])
);

// ---------- L09_Upsample ---------- //
L09_Upsample l09_Upsample (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(l08_b0_dOut),
    .s_valid(l08_b0_valid),
    .s_ready(l08_b0_ready),

    .dOut(l09_dOut),
    .m_ready(l09_ready),
    .m_valid(l09_valid),
    .frame_done(layer_done[11])
);

// ---------- L10_Concat ---------- //
L10_Concat l10_Concat (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(l09_dOut),
    .s_valid0(l09_valid),
    .s_ready0(l09_ready),

    .dIn1(l052_b1_dOut),
    .s_valid1(l052_b1_valid),
    .s_ready1(l052_b1_ready),

    .dOut(l10_dOut),
    .m_ready(l10_ready),
    .m_valid(l10_valid),
    .frame_done(layer_done[12])
);

// ---------- L11_XSSBlock ---------- //
L11_XSSBlock l11_XSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l10_dOut),
    .s_valid(l10_valid),
    .s_ready(l10_ready),

    .dOut(l11_dOut),
    .m_ready(l11_ready),
    .m_valid(l11_valid),
    .frame_done(layer_done[13])
);

// ---------- L12_Upsample ---------- //
L12_Upsample l12_Upsample (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn(l11_b0_dOut),
    .s_valid(l11_b0_valid),
    .s_ready(l11_b0_ready),

    .dOut(l12_dOut),
    .m_ready(l12_ready),
    .m_valid(l12_valid),
    .frame_done(layer_done[14])
);

// ---------- L13_Concat ---------- //
L13_Concat l13_Concat (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(l12_dOut),
    .s_valid0(l12_valid),
    .s_ready0(l12_ready),

    .dIn1(l03_b1_dOut),
    .s_valid1(l03_b1_valid),
    .s_ready1(l03_b1_ready),

    .dOut(l13_dOut),
    .m_ready(l13_ready),
    .m_valid(l13_valid),
    .frame_done(layer_done[15])
);

// ---------- L14_XSSBlock ---------- //
L14_XSSBlock l14_XSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l13_dOut),
    .s_valid(l13_valid),
    .s_ready(l13_ready),

    .dOut(l14_dOut),
    .m_ready(l14_ready),
    .m_valid(l14_valid),
    .frame_done(layer_done[16])
);

// ---------- L15_Conv ---------- //
L15_Conv l15_Conv (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l14_b0_dOut),
    .s_valid(l14_b0_valid),
    .s_ready(l14_b0_ready),

    .dOut(l15_dOut),
    .m_ready(l15_ready),
    .m_valid(l15_valid),
    .frame_done(layer_done[17])
);

// ---------- L16_Concat ---------- //
L16_Concat l16_Concat (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(l15_dOut),
    .s_valid0(l15_valid),
    .s_ready0(l15_ready),

    .dIn1(l11_b1_dOut),
    .s_valid1(l11_b1_valid),
    .s_ready1(l11_b1_ready),

    .dOut(l16_dOut),
    .m_ready(l16_ready),
    .m_valid(l16_valid),
    .frame_done(layer_done[18])
);

// ---------- L17_XSSBlock ---------- //
L17_XSSBlock l17_XSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l16_dOut),
    .s_valid(l16_valid),
    .s_ready(l16_ready),

    .dOut(l17_dOut),
    .m_ready(l17_ready),
    .m_valid(l17_valid),
    .frame_done(layer_done[19])
);

// ---------- L18_Conv ---------- //
L18_Conv l18_Conv (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l17_b0_dOut),
    .s_valid(l17_b0_valid),
    .s_ready(l17_b0_ready),

    .dOut(l18_dOut),
    .m_ready(l18_ready),
    .m_valid(l18_valid),
    .frame_done(layer_done[20])
);

// ---------- L19_Concat ---------- //
L19_Concat l19_Concat (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .dIn0(l18_dOut),
    .s_valid0(l18_valid),
    .s_ready0(l18_ready),

    .dIn1(l08_b1_dOut),
    .s_valid1(l08_b1_valid),
    .s_ready1(l08_b1_ready),

    .dOut(l19_dOut),
    .m_ready(l19_ready),
    .m_valid(l19_valid),
    .frame_done(layer_done[21])
);

// ---------- L20_XSSBlock ---------- //
L20_XSSBlock l20_XSSBlock (
    .clk(clk),
    .nRst(nRst),
    .ps_start(ps_start),

    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .dIn(l19_dOut),
    .s_valid(l19_valid),
    .s_ready(l19_ready),

    .dOut(l20_dOut),
    .m_ready(l20_ready),
    .m_valid(l20_valid),
    .frame_done(layer_done[22])
);

// ---------- Detect inputs ---------- //
assign p3_dOut    = l14_b1_dOut;
assign p3_m_valid = l14_b1_valid;
assign l14_b1_ready = p3_m_ready;

assign p4_dOut    = l17_b1_dOut;
assign p4_m_valid = l17_b1_valid;
assign l17_b1_ready = p4_m_ready;

assign p5_dOut    = l20_dOut;
assign p5_m_valid = l20_valid;
assign l20_ready = p5_m_ready;

// ---------- frame_done: the slowest Detect output has finished one more frame ---------- //
logic [31:0] det_cnt [0:2];
logic [31:0] det_min, det_min_q;
always @(posedge clk) begin
    if (!nRst || ps_start) begin
        det_cnt[0] <= #1 '0;
        det_cnt[1] <= #1 '0;
        det_cnt[2] <= #1 '0;
        det_min_q <= #1 '0;
        frame_done <= #1 1'b0;
    end else begin
        if (layer_done[16]) det_cnt[0] <= #1 det_cnt[0] + 1'b1;
        if (layer_done[19]) det_cnt[1] <= #1 det_cnt[1] + 1'b1;
        if (layer_done[22]) det_cnt[2] <= #1 det_cnt[2] + 1'b1;
        det_min_q  <= #1 det_min;
        frame_done <= #1 (det_min != det_min_q);
    end
end
always_comb begin
    det_min = det_cnt[0];
    if (det_cnt[1] < det_min) det_min = det_cnt[1];
    if (det_cnt[2] < det_min) det_min = det_cnt[2];
end

endmodule
