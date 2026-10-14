`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2024 11:57:14 PM
// Design Name: 
// Module Name: eMamba
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module U_eMamba #(
    parameter integer AXI_WIDTH = 32,
    parameter integer WB_BRAM_ADDR_W = 13,
    
    parameter integer DATA_WIDTH  = 8,
    parameter integer NUM_CHANNEL = 5,
    parameter integer NUM_HEIGHT  = 8,
    parameter integer NUM_WIDTH   = 8,
    parameter integer PATCH1      = 2,
    parameter integer PATCH2      = 2,
    parameter integer NUM_SEQLEN  = 16, // L
    parameter integer NUM_DIM     = 20, // D
    parameter integer NUM_ED      = 40, // ED
    parameter integer NUM_N       = 8,  // N
    parameter integer NUM_DELTA   = 32,
    parameter integer NUM_DBC     = 48, // NUM_DELTA + NUM_N * 2
    parameter integer NUM_CLASS   = 57,

    // -=--=-=-=-=-=-=- BRAM WB Loader ADDED -=--=-=-=-=-=-=-
    parameter integer WB_ADDR_W = 15,     // wb_addr 폭. eMamba_IP 의 WB_BRAM_ADDR_W 와 같게
    // Patchembedding
    parameter integer PATCH_LINEAR_W_BASE = 0,      // weight 창의 첫 워드 번호
    // MAMBA 1ST BLOCK
    parameter integer MAMBA_1ST_LNORM_W_BASE = 420,
    parameter integer MAMBA_1ST_LINEX_X1_W_BASE = 460,
    parameter integer MAMBA_1ST_LINEX_Z1_W_BASE = 1300,
    parameter integer MAMBA_1ST_CONV1D_W_BASE = 3772,

    parameter integer MAMBA_1ST_SSM_A_BASE = 5412,      // [J-WB]
    parameter integer MAMBA_1ST_SSM_D_BASE = 5732,      // [J-WB]
    parameter integer MAMBA_1ST_LIN_DBC_DELTA_W_BASE = 5772,    // [J-WB]
    parameter integer MAMBA_1ST_LIN_DBC_B_W_BASE     = 7052,    // [J-WB]
    parameter integer MAMBA_1ST_LIN_DBC_C_W_BASE     = 7372,    // [J-WB]
    parameter integer MAMBA_1ST_LIN_DELTA_W_BASE     = 7868,    // [J-WB] 

    parameter integer MAMBA_1ST_LINCONT_W_BASE = 9188,
    // MAMBA 2ND BLOCK
    parameter integer MAMBA_2ND_LNORM_W_BASE = 10008,
    parameter integer MAMBA_2ND_LINEX_X1_W_BASE = 10048,
    parameter integer MAMBA_2ND_LINEX_Z1_W_BASE = 10888,
    parameter integer MAMBA_2ND_CONV1D_W_BASE = 11964,

    parameter integer MAMBA_2ND_SSM_A_BASE = 13604,     // [J-WB]
    parameter integer MAMBA_2ND_SSM_D_BASE = 13924,     // [J-WB]
    parameter integer MAMBA_2ND_LIN_DBC_DELTA_W_BASE = 13964,   // [J-WB]
    parameter integer MAMBA_2ND_LIN_DBC_B_W_BASE     = 15244,   // [J-WB]
    parameter integer MAMBA_2ND_LIN_DBC_C_W_BASE     = 15564,   // [J-WB]
    parameter integer MAMBA_2ND_LIN_DELTA_W_BASE     = 16060,   // [J-WB]

    parameter integer MAMBA_2ND_LINCONT_W_BASE = 17380,
    // Outputhead
    parameter integer OH_LNORM_W_BASE = 18200,
    parameter integer OH_LINEAR_W_BASE = 18240,
    // -=--=-=-=-=-=-=- BRAM WB Loader ADDED -=--=-=-=-=-=-=-

    // ========== ========== ========== ========== ==========
    // Patch embedding
    parameter integer PATCH_NUM_SCALE_DIN    = 3,
    parameter integer PATCH_NUM_SCALE_WEIGHT = 7,
    parameter integer PATCH_NUM_SCALE_BIAS   = 8,
    parameter integer PATCH_NUM_SCALE_DOUT   = 5,

    // ========== ========== ========== ========== ==========
    // MAMBA BLOCK 1ST
    // LightNorm
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_BIAS   = 7,
    parameter integer MAMBA_1ST_LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand x1
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_1ST_LINEX_X1_NUM_SCALE_DOUT   = 6,

    // Linear expand z1
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_1ST_LINEX_Z1_NUM_SCALE_DOUT   = 5,

    // SiLU piecewise
    parameter integer MAMBA_1ST_SILU_NUM_SCALE_DIN  = 5,
    parameter integer MAMBA_1ST_SILU_NUM_SCALE_DOUT = 5,

    // Convolution 1D
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_BIAS   = 9,
    parameter integer MAMBA_1ST_CONV1D_NUM_SCALE_DOUT   = 5,

    // SSM
    // Preprocess
    // Linear expand dBC delta
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 5,

    // Linear expand dBC B
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DOUT   = 5,

    // Linear expand dBC C
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DOUT   = 5,

    // Linear expand dleta
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 3,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT  = 3,

    // Computation
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DIN     = 5,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DELTA_A = 7,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DELTA_B = 3,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_C       = 5,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_D       = 6,
    parameter integer MAMBA_1ST_SSM_NUM_SCALE_DOUT    = 1,

    // Elementwise Production
    parameter integer MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_1 = 1,
    parameter integer MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_1ST_EW_PROD_NUM_SCALE_DOUT  = 2,

    // Linear contract
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_DIN    = 2,
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_BIAS   = 9,
    parameter integer MAMBA_1ST_LINCONT_NUM_SCALE_DOUT   = 3,

    // Elementwise Addition
    parameter integer MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_1 = 3,
    parameter integer MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_1ST_EW_ADD_NUM_SCALE_DOUT  = 3,

    // ========== ========== ========== ========== ==========
    // MAMBA BLOCK 2ND
    // LightNorm
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_DIN    = 3,
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_BIAS   = 7,
    parameter integer MAMBA_2ND_LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand x1
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_LINEX_X1_NUM_SCALE_DOUT   = 6,

    // Linear expand z1
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_LINEX_Z1_NUM_SCALE_DOUT   = 5,

    // SiLU piecewise
    parameter integer MAMBA_2ND_SILU_NUM_SCALE_DIN  = 5,
    parameter integer MAMBA_2ND_SILU_NUM_SCALE_DOUT = 5,

    // Convolution 1D
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_DIN    = 6,
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_CONV1D_NUM_SCALE_DOUT   = 5,

    // SSM
    // Preprocess
    // Linear expand dBC delta
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT   = 5,

    // Linear expand dBC B
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DOUT   = 3,

    // Linear expand dBC C
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DOUT   = 3,

    // Linear expand dleta
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DIN    = 5,
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT = 8,
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_BIAS   = 8,
    parameter integer MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DOUT   = 4,

    // DimExpander delta_A
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2 = 2,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT  = 7,

    // DimExpander delta_B
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1 = 4,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2 = 3,
    parameter integer MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT  = 1,

    // Computation
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DIN     = 5,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DELTA_A = 7,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DELTA_B = 1,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_C       = 3,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_D       = 6,
    parameter integer MAMBA_2ND_SSM_NUM_SCALE_DOUT    = -3,

    // Elementwise Production
    parameter integer MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_1 = -3,
    parameter integer MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_2 = 5,
    parameter integer MAMBA_2ND_EW_PROD_NUM_SCALE_DOUT  = -4,

    // Linear contract
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_DIN    = -4,
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_WEIGHT = 7,
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_BIAS   = 9,
    parameter integer MAMBA_2ND_LINCONT_NUM_SCALE_DOUT   = -3,

    // Elementwise Addition
    parameter integer MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_1 = -3,
    parameter integer MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_2 = 3,
    parameter integer MAMBA_2ND_EW_ADD_NUM_SCALE_DOUT  = -3,

    // ========== ========== ========== ========== ==========
    // Outputhead
    // LightNorm
    parameter integer OH_LNORM_NUM_SCALE_DIN    = -3,
    parameter integer OH_LNORM_NUM_SCALE_WEIGHT = 7,
    parameter integer OH_LNORM_NUM_SCALE_BIAS   = 7,
    parameter integer OH_LNORM_NUM_SCALE_DOUT   = 6,

    // Linear expand
    parameter integer OH_LINEX_NUM_SCALE_DIN    = 6,
    parameter integer OH_LINEX_NUM_SCALE_WEIGHT = 8,
    parameter integer OH_LINEX_NUM_SCALE_BIAS   = 8,
    parameter integer OH_LINEX_NUM_SCALE_DOUT   = 6
)(
    clk,
    nRst,

    ps_start,

    // dIn,
    in_rd_en,     // [J-EXT-BRAM] ↑ dIn(2560bit) 삭제, BRAM 읽기 신호 3개로 교체. 이 파일은 그냥 통과시킨다
    in_rd_addr,   // [J-EXT-BRAM]
    in_rd_data,   // [J-EXT-BRAM]

    wb_valid,
    wb_addr,
    wb_data,

    dOut,         // [J-EXT-BRAM-OUT] 출력은 v7 그대로 (dOut / m_valid / dOut_seq_idx / m_ready). BRAM 쓰기는 eMamba_IP 가 한다

    // Patchembedding
    // patch_weight,
    // patch_bias,

    // // 1st MAMBA Block
    // lightNorm_weight,
    // lightNorm_bias,

    // linEx_x1_weight,
    // linEx_x1_bias,

    // linEx_z1_weight,
    // linEx_z1_bias,
    
    // conv1d_weight,
    // conv1d_bias,

    // matrix_A,
    // matrix_D,
    // linEx_dBC_weight,
    // linEx_delta_weight,
    // linEx_delta_bias,

    // linCont_weight,
    // linCont_bias,

    // // 2nd MAMBA Block
    // lightNorm_2nd_weight,
    // lightNorm_2nd_bias,

    // linEx_x1_2nd_weight,
    // linEx_x1_2nd_bias,

    // linEx_z1_2nd_weight,
    // linEx_z1_2nd_bias,

    // conv1d_2nd_weight,
    // conv1d_2nd_bias,

    // matrix_A_2nd,
    // matrix_D_2nd,
    // linEx_dBC_2nd_weight,
    // linEx_delta_2nd_weight,
    // linEx_delta_2nd_bias,
    // linCont_2nd_weight,
    // linCont_2nd_bias,

    // // Outputhead
    // OH_lightNorm_weight,
    // OH_lightNorm_bias,
    // OH_linEx_weight,
    // OH_linEx_bias,

    m_valid,
    dOut_seq_idx,
    frame_done,   // [J-AXI Conn.] frame_valid -> frame_done
    m_ready,      // [J-AXI Conn.] S_AXI.ram_ready
    
    eMamba_start
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Local Parameters
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
localparam integer DEBUG_SWITCH_PATCHEMBEDDING  = 1,
                   DEBUG_SWITCH_MAMBA_1ST   = 1,
                   DEBUG_SWITCH_MAMBA_2ND   = 2,
                   DEBUG_SWITCH_OUTPUTHEAD  = 1;

localparam IDLE = 1'b0,
           BUSY = 1'b1;

localparam integer SEQ_W = (NUM_SEQLEN > 1) ? $clog2(NUM_SEQLEN) : 1; // [J-AXI Conn.] dOut_seq_idx width (was hard-coded 4)

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Ports
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
input clk, nRst;
input ps_start;

// input   logic signed [DATA_WIDTH * NUM_CHANNEL * NUM_HEIGHT * NUM_WIDTH - 1:0] dIn; // 1x5x8x8
// [J-EXT-BRAM] ↑ 삭제. 지금은 U_PatchEmbedding.Token_Fetcher 가 내는 읽기 요청을 위(eMamba_IP)로 올리고
//                   읽힌 워드를 아래로 내리는 통로 3개. 이 파일에서는 이름만 이어 준다.
output  logic        in_rd_en;     // [J-EXT-BRAM] 읽기 요청     (U_PatchEmbedding -> eMamba_IP)
output  logic [6:0]  in_rd_addr;   // [J-EXT-BRAM] 워드 번호 0..79 (U_PatchEmbedding -> eMamba_IP)
input   logic [31:0] in_rd_data;   // [J-EXT-BRAM] 읽힌 워드, 요청 다음 클럭 (eMamba_IP -> U_PatchEmbedding)

input wb_valid;
input [WB_BRAM_ADDR_W-1:0] wb_addr;
input [AXI_WIDTH-1:0] wb_data;

output  logic signed [DATA_WIDTH * NUM_CLASS - 1:0] dOut; // Class 57

output m_valid;
output [SEQ_W-1:0] dOut_seq_idx; // [J-AXI Conn.] 4 -> SEQ_W
output frame_done;   // [J-AXI Conn.] frame_valid -> frame_done
input  m_ready;      // [J-AXI Conn.] S_AXI.ram_ready   [J-EXT-BRAM-OUT] 지금은 eMamba_IP.out_ready (출력 BRAM 은 eMamba 전용 포트라 거의 항상 1)

output  eMamba_start;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// I/O Indexing
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
genvar c, h, w;
genvar d, d1, d2, ed, ed1, ed2, n, dbc;

// Initial Input
// logic signed [DATA_WIDTH-1:0] dIn_arr [0:NUM_CHANNEL-1][0:NUM_HEIGHT-1][0:NUM_WIDTH-1]; // 1x5x8x8
// generate
//     for (c = 0; c < NUM_CHANNEL; c = c + 1) begin
//         for (h = 0; h < NUM_HEIGHT; h = h + 1) begin
//             for (w = 0; w < NUM_WIDTH; w = w + 1) begin
//                 assign dIn_arr[c][h][w] = dIn[(c * NUM_HEIGHT * NUM_WIDTH + h * NUM_WIDTH + w) * DATA_WIDTH +: DATA_WIDTH];
//             end
//         end
//     end
// endgenerate
// [J-EXT-BRAM] ↑ 삭제 : 2560bit 버스를 5x8x8 배열로 풀던 generate.
//   그 "바이트 위치 = (c*H*W + h*W + w)" 계산은 그대로 Token_Fetcher 안의 주소 계산이 됐다.
//   즉 v7 은 배선으로 풀었고, 지금은 같은 식을 BRAM 주소로 계산해서 한 워드씩 읽는다.

// 1. Patchembedding
// input logic signed [DATA_WIDTH * NUM_DIM * NUM_DIM - 1:0] patch_weight; // 20x20
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] patch_bias; // 20
// logic signed [DATA_WIDTH-1:0] patch_weight_arr [0:NUM_DIM-1][0:NUM_DIM-1]; // 20x20
// logic signed [DATA_WIDTH-1:0] patch_bias_arr   [0:NUM_DIM-1]; // 20
// generate
//     for (d1 = 0; d1 < NUM_DIM; d1 = d1 + 1) begin
//         for (d2 = 0; d2 < NUM_DIM; d2 = d2 + 1) begin
//             assign patch_weight_arr[d1][d2] = patch_weight[(d1 * NUM_DIM + d2) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign patch_bias_arr[d1] = patch_bias[d1 * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // ----- 1st MAMBA Block ----- //
// // 2. LightNorm
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_weight; // 20
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_bias;   // 20
// logic signed [DATA_WIDTH-1:0] lightNorm_weight_arr [0:NUM_DIM-1]; // 20
// logic signed [DATA_WIDTH-1:0] lightNorm_bias_arr   [0:NUM_DIM-1]; // 20
// generate
//     for (d = 0; d < NUM_DIM; d = d + 1) begin
//         assign lightNorm_weight_arr[d] = lightNorm_weight[d * DATA_WIDTH +: DATA_WIDTH];
//         assign lightNorm_bias_arr[d] = lightNorm_bias[d * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 3-1. Linear expand x1
// input logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_x1_weight; // 40x20
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_x1_bias;             // 40
// logic signed [DATA_WIDTH-1:0] linEx_x1_weight_arr [0:NUM_ED-1][0:NUM_DIM-1]; // 40x20
// logic signed [DATA_WIDTH-1:0] linEx_x1_bias_arr   [0:NUM_ED-1];              // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (d = 0; d < NUM_DIM; d = d + 1) begin
//             assign linEx_x1_weight_arr[ed][d] = linEx_x1_weight[(ed * NUM_DIM + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linEx_x1_bias_arr[ed] = linEx_x1_bias[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 3-2. Linear expand z1
// input logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_z1_weight; // 40x20
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_z1_bias;             // 40
// logic signed [DATA_WIDTH-1:0] linEx_z1_weight_arr [0:NUM_ED-1][0:NUM_DIM-1]; // 40x20
// logic signed [DATA_WIDTH-1:0] linEx_z1_bias_arr   [0:NUM_ED-1];              // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (d = 0; d < NUM_DIM; d = d + 1) begin
//             assign linEx_z1_weight_arr[ed][d] = linEx_z1_weight[(ed * NUM_DIM + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linEx_z1_bias_arr[ed] = linEx_z1_bias[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 4. Convolution 1D
// input logic signed [DATA_WIDTH * NUM_ED * NUM_ED - 1:0] conv1d_weight ; // 40x40
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] conv1d_bias;             // 40
// logic signed [DATA_WIDTH-1:0] conv1d_weight_arr [0:NUM_ED-1][0:NUM_ED-1]; // 40x40
// logic signed [DATA_WIDTH-1:0] conv1d_bias_arr   [0:NUM_ED-1];             // 40
// generate
//     for (ed1 = 0; ed1 < NUM_ED; ed1 = ed1 + 1) begin
//         for (ed2 = 0; ed2 < NUM_ED; ed2 = ed2 + 1) begin
//             assign conv1d_weight_arr[ed1][ed2] = conv1d_weight[(ed1 * NUM_ED + ed2) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign conv1d_bias_arr[ed1] = conv1d_bias[ed1 * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 5. SSM
// input logic signed [DATA_WIDTH * NUM_ED * NUM_N - 1:0] matrix_A; // 40x8
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] matrix_D; // 40
// logic signed [DATA_WIDTH-1:0] matrix_A_arr [0:NUM_ED-1][0:NUM_N-1]; // 40x8
// logic signed [DATA_WIDTH-1:0] matrix_D_arr [0:NUM_ED-1]; // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (n = 0; n < NUM_N; n = n + 1) begin
//             assign matrix_A_arr[ed][n] = matrix_A[(ed * NUM_N + n) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign matrix_D_arr[ed] = matrix_D[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // Linear expand deltaBC
// input logic signed [DATA_WIDTH * NUM_DBC * NUM_ED - 1:0] linEx_dBC_weight; // 48x40
// logic signed [DATA_WIDTH-1:0] linEx_dBC_weight_arr [0:NUM_DBC-1][0:NUM_ED-1]; // 48x40
// generate
//     for (dbc = 0; dbc < NUM_DBC; dbc = dbc + 1) begin
//         for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//             assign linEx_dBC_weight_arr[dbc][ed] = linEx_dBC_weight[(dbc * NUM_ED + ed) * DATA_WIDTH +: DATA_WIDTH];
//         end
//     end
// endgenerate

// // Linear expand delta
// input logic signed [DATA_WIDTH * NUM_ED * NUM_DELTA - 1:0] linEx_delta_weight; // 40x32
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_delta_bias; // 40
// logic signed [DATA_WIDTH-1:0] linEx_delta_weight_arr [0:NUM_ED-1][0:NUM_DELTA-1]; // 40x32
// logic signed [DATA_WIDTH-1:0] linEx_delta_bias_arr   [0:NUM_ED-1]; // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (d = 0; d < NUM_DELTA; d = d + 1) begin
//             assign linEx_delta_weight_arr[ed][d] = linEx_delta_weight[(ed * NUM_DELTA + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linEx_delta_bias_arr[ed] = linEx_delta_bias[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 7. Linear contract
// input logic signed [DATA_WIDTH * NUM_DIM * NUM_ED - 1:0] linCont_weight; // 20x40
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] linCont_bias; // 20
// logic signed [DATA_WIDTH-1:0] linCont_weight_arr [0:NUM_DIM-1][0:NUM_ED-1]; // 20x40
// logic signed [DATA_WIDTH-1:0] linCont_bias_arr   [0:NUM_DIM-1]; // 20
// generate
//     for (d = 0; d < NUM_DIM; d = d + 1) begin
//         for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//             assign linCont_weight_arr[d][ed] = linCont_weight[(d * NUM_ED + ed) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linCont_bias_arr[d] = linCont_bias[d * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // ----- 2nd MAMBA Block ----- //
// // 2. LightNorm
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_2nd_weight; // 20
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] lightNorm_2nd_bias;   // 20
// logic signed [DATA_WIDTH-1:0] lightNorm_2nd_weight_arr [0:NUM_DIM-1]; // 20
// logic signed [DATA_WIDTH-1:0] lightNorm_2nd_bias_arr   [0:NUM_DIM-1]; // 20
// generate
//     for (d = 0; d < NUM_DIM; d = d + 1) begin
//         assign lightNorm_2nd_weight_arr[d] = lightNorm_2nd_weight[d * DATA_WIDTH +: DATA_WIDTH];
//         assign lightNorm_2nd_bias_arr[d] = lightNorm_2nd_bias[d * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 3-1. Linear expand x1
// input logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_x1_2nd_weight; // 40x20
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_x1_2nd_bias;             // 40
// logic signed [DATA_WIDTH-1:0] linEx_x1_2nd_weight_arr [0:NUM_ED-1][0:NUM_DIM-1]; // 40x20
// logic signed [DATA_WIDTH-1:0] linEx_x1_2nd_bias_arr   [0:NUM_ED-1];              // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (d = 0; d < NUM_DIM; d = d + 1) begin
//             assign linEx_x1_2nd_weight_arr[ed][d] = linEx_x1_2nd_weight[(ed * NUM_DIM + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linEx_x1_2nd_bias_arr[ed] = linEx_x1_2nd_bias[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 3-2. Linear expand z1
// input logic signed [DATA_WIDTH * NUM_ED * NUM_DIM - 1:0] linEx_z1_2nd_weight; // 40x20
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_z1_2nd_bias;             // 40
// logic signed [DATA_WIDTH-1:0] linEx_z1_2nd_weight_arr [0:NUM_ED-1][0:NUM_DIM-1]; // 40x20
// logic signed [DATA_WIDTH-1:0] linEx_z1_2nd_bias_arr   [0:NUM_ED-1];              // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (d = 0; d < NUM_DIM; d = d + 1) begin
//             assign linEx_z1_2nd_weight_arr[ed][d] = linEx_z1_2nd_weight[(ed * NUM_DIM + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linEx_z1_2nd_bias_arr[ed] = linEx_z1_2nd_bias[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 4. Convolution 1D
// input logic signed [DATA_WIDTH * NUM_ED * NUM_ED - 1:0] conv1d_2nd_weight ; // 40x40
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] conv1d_2nd_bias;             // 40
// logic signed [DATA_WIDTH-1:0] conv1d_2nd_weight_arr [0:NUM_ED-1][0:NUM_ED-1]; // 40x40
// logic signed [DATA_WIDTH-1:0] conv1d_2nd_bias_arr   [0:NUM_ED-1];             // 40
// generate
//     for (ed1 = 0; ed1 < NUM_ED; ed1 = ed1 + 1) begin
//         for (ed2 = 0; ed2 < NUM_ED; ed2 = ed2 + 1) begin
//             assign conv1d_2nd_weight_arr[ed1][ed2] = conv1d_2nd_weight[(ed1 * NUM_ED + ed2) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign conv1d_2nd_bias_arr[ed1] = conv1d_2nd_bias[ed1 * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 5. SSM
// input logic signed [DATA_WIDTH * NUM_ED * NUM_N - 1:0] matrix_A_2nd; // 40x8
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] matrix_D_2nd; // 40
// logic signed [DATA_WIDTH-1:0] matrix_A_2nd_arr [0:NUM_ED-1][0:NUM_N-1]; // 40x8
// logic signed [DATA_WIDTH-1:0] matrix_D_2nd_arr [0:NUM_ED-1]; // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (n = 0; n < NUM_N; n = n + 1) begin
//             assign matrix_A_2nd_arr[ed][n] = matrix_A_2nd[(ed * NUM_N + n) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign matrix_D_2nd_arr[ed] = matrix_D_2nd[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // Linear expand deltaBC
// input logic signed [DATA_WIDTH * NUM_DBC * NUM_ED - 1:0] linEx_dBC_2nd_weight; // 48x40
// logic signed [DATA_WIDTH-1:0] linEx_dBC_2nd_weight_arr [0:NUM_DBC-1][0:NUM_ED-1]; // 48x40
// generate
//     for (dbc = 0; dbc < NUM_DBC; dbc = dbc + 1) begin
//         for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//             assign linEx_dBC_2nd_weight_arr[dbc][ed] = linEx_dBC_2nd_weight[(dbc * NUM_ED + ed) * DATA_WIDTH +: DATA_WIDTH];
//         end
//     end
// endgenerate

// // Linear expand delta
// input logic signed [DATA_WIDTH * NUM_ED * NUM_DELTA - 1:0] linEx_delta_2nd_weight; // 40x32
// input logic signed [DATA_WIDTH * NUM_ED - 1:0] linEx_delta_2nd_bias; // 40
// logic signed [DATA_WIDTH-1:0] linEx_delta_2nd_weight_arr [0:NUM_ED-1][0:NUM_DELTA-1]; // 40x32
// logic signed [DATA_WIDTH-1:0] linEx_delta_2nd_bias_arr   [0:NUM_ED-1]; // 40
// generate
//     for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//         for (d = 0; d < NUM_DELTA; d = d + 1) begin
//             assign linEx_delta_2nd_weight_arr[ed][d] = linEx_delta_2nd_weight[(ed * NUM_DELTA + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linEx_delta_2nd_bias_arr[ed] = linEx_delta_2nd_bias[ed * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // 7. Linear contract
// input logic signed [DATA_WIDTH * NUM_DIM * NUM_ED - 1:0] linCont_2nd_weight; // 20x40
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] linCont_2nd_bias; // 20
// logic signed [DATA_WIDTH-1:0] linCont_2nd_weight_arr [0:NUM_DIM-1][0:NUM_ED-1]; // 20x40
// logic signed [DATA_WIDTH-1:0] linCont_2nd_bias_arr   [0:NUM_DIM-1]; // 20
// generate
//     for (d = 0; d < NUM_DIM; d = d + 1) begin
//         for (ed = 0; ed < NUM_ED; ed = ed + 1) begin
//             assign linCont_2nd_weight_arr[d][ed] = linCont_2nd_weight[(d * NUM_ED + ed) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign linCont_2nd_bias_arr[d] = linCont_2nd_bias[d * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // ----- Outputhead ----- //
// // LightNorm
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] OH_lightNorm_weight; // 20
// input logic signed [DATA_WIDTH * NUM_DIM - 1:0] OH_lightNorm_bias;   // 20
// logic signed [DATA_WIDTH-1:0] OH_lightNorm_weight_arr [0:NUM_DIM-1]; // 20
// logic signed [DATA_WIDTH-1:0] OH_lightNorm_bias_arr   [0:NUM_DIM-1]; // 20
// generate
//     for (d = 0; d < NUM_DIM; d = d + 1) begin
//         assign OH_lightNorm_weight_arr[d] = OH_lightNorm_weight[d * DATA_WIDTH +: DATA_WIDTH];
//         assign OH_lightNorm_bias_arr[d] = OH_lightNorm_bias[d * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// // Linear expand 57
// input logic signed [DATA_WIDTH * NUM_CLASS * NUM_DIM - 1:0] OH_linEx_weight; // 57x20
// input logic signed [DATA_WIDTH * NUM_CLASS - 1:0] OH_linEx_bias; // 57
// logic signed [DATA_WIDTH-1:0] OH_linEx_weight_arr [0:NUM_CLASS-1][0:NUM_DIM-1]; // 57x20
// logic signed [DATA_WIDTH-1:0] OH_linEx_bias_arr   [0:NUM_CLASS-1]; // 57
// generate
//     for (c = 0; c < NUM_CLASS; c = c + 1) begin
//         for (d = 0; d < NUM_DIM; d = d + 1) begin
//             assign OH_linEx_weight_arr[c][d] = OH_linEx_weight[(c * NUM_DIM + d) * DATA_WIDTH +: DATA_WIDTH];
//         end
//         assign OH_linEx_bias_arr[c] = OH_linEx_bias[c * DATA_WIDTH +: DATA_WIDTH];
//     end
// endgenerate

// Final Output
generate
    for (c = 0; c < NUM_CLASS; c = c + 1) begin
        assign dOut[c * DATA_WIDTH +: DATA_WIDTH] = OH_dOut[c];
    end
endgenerate

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Internal Variables
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main FSM
logic curr_startCtrl_state, next_startCtrl_state;

// Frame data signal
logic frame_busy; // [J] 출력 포트 frame_done 와 다른거야   // [J-AXI Conn.] 주석의 포트명 갱신

// 1. Patchembedding
logic signed [DATA_WIDTH-1:0] patch_dOut [0:NUM_DIM-1];
logic patch_frame_done, patch_m_valid;
logic frame_handshaking;

// 1st MAMBA
logic signed [DATA_WIDTH-1:0] MAMBA_1st_dOut [0:NUM_DIM-1];
logic MAMBA_1st_s_ready, MAMBA_1st_m_valid;

// 2nd MAMBA
logic signed [DATA_WIDTH-1:0] MAMBA_2nd_dOut [0:NUM_DIM-1];
logic MAMBA_2nd_s_ready, MAMBA_2nd_m_valid;

// Outputhead
logic signed [DATA_WIDTH-1:0] OH_dOut [0:NUM_CLASS-1];
logic OH_s_ready, OH_m_valid;
logic OH_frame_done;

// PS start signal edges
logic ps_start_rising, ps_start_falling;

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Submodules
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// [J]
U_PatchEmbedding #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_CHANNEL(NUM_CHANNEL), 
    .NUM_HEIGHT(NUM_HEIGHT), 
    .NUM_WIDTH(NUM_WIDTH),

    .PATCH1(PATCH1), 
    .PATCH2(PATCH2),
    .NUM_SEQLEN(NUM_SEQLEN), 
    .NUM_DIM(NUM_DIM),

    .NUM_SCALE_DIN(PATCH_NUM_SCALE_DIN),
    .NUM_SCALE_WEIGHT(PATCH_NUM_SCALE_WEIGHT),
    .NUM_SCALE_BIAS(PATCH_NUM_SCALE_BIAS),
    .NUM_SCALE_DOUT(PATCH_NUM_SCALE_DOUT),

    .WB_ADDR_W(WB_ADDR_W),
    .PATCH_LINEAR_W_BASE(PATCH_LINEAR_W_BASE),

    .DEBUG_SWITCH(DEBUG_SWITCH_PATCHEMBEDDING)
) U_PatchEmbedding (
    .clk(clk), 
    .nRst(nRst),

    .ps_start(ps_start_rising),

    // .dIn(dIn_arr), 
    .in_rd_en(in_rd_en),       // [J-EXT-BRAM] ↑ .dIn(dIn_arr) 삭제, 3개로 교체. 그냥 관통
    .in_rd_addr(in_rd_addr),   // [J-EXT-BRAM]
    .in_rd_data(in_rd_data),   // [J-EXT-BRAM]

    .dOut(patch_dOut),
    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .frame_valid(frame_busy),          // [J]
    .frame_done(patch_frame_done),      // [J]

    .m_valid(patch_m_valid),
    .m_ready(MAMBA_1st_s_ready)
);

U_MAMBA #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM_1(NUM_DIM),   // D(20)
    .NUM_DIM_2(NUM_ED),   // ED(40)
    
    .NUM_DIM_N(NUM_N),          // N(8)
    .NUM_DIM_DELTA(NUM_DELTA),  // dt_rank(32)

    // [J-WB] ---------- wb loader ----------
    .WB_ADDR_W(WB_ADDR_W),

    .LIGHTNORM_W_BASE(MAMBA_1ST_LNORM_W_BASE),
    .LINEX_X1_W_BASE(MAMBA_1ST_LINEX_X1_W_BASE),
    .LINEX_Z1_W_BASE(MAMBA_1ST_LINEX_Z1_W_BASE),
    .CONV1D_W_BASE(MAMBA_1ST_CONV1D_W_BASE),

    .SSM_A_BASE(MAMBA_1ST_SSM_A_BASE),                  // [J-WB]
    .SSM_D_BASE(MAMBA_1ST_SSM_D_BASE),                  // [J-WB]
    .LIN_DBC_DELTA_W_BASE(MAMBA_1ST_LIN_DBC_DELTA_W_BASE),
    .LIN_DBC_B_W_BASE(MAMBA_1ST_LIN_DBC_B_W_BASE),
    .LIN_DBC_C_W_BASE(MAMBA_1ST_LIN_DBC_C_W_BASE),
    .LIN_DELTA_W_BASE(MAMBA_1ST_LIN_DELTA_W_BASE),

    .LINCONT_W_BASE(MAMBA_1ST_LINCONT_W_BASE),
    // [J-WB] ---------- wb loader ----------

    // LightNorm
    .LNORM_NUM_SCALE_DIN(MAMBA_1ST_LNORM_NUM_SCALE_DIN),
    .LNORM_NUM_SCALE_WEIGHT(MAMBA_1ST_LNORM_NUM_SCALE_WEIGHT),
    .LNORM_NUM_SCALE_BIAS(MAMBA_1ST_LNORM_NUM_SCALE_BIAS),
    .LNORM_NUM_SCALE_DOUT(MAMBA_1ST_LNORM_NUM_SCALE_DOUT),

    // Linear expand x1
    .LINEX_X1_NUM_SCALE_DIN(MAMBA_1ST_LINEX_X1_NUM_SCALE_DIN),
    .LINEX_X1_NUM_SCALE_WEIGHT(MAMBA_1ST_LINEX_X1_NUM_SCALE_WEIGHT),
    .LINEX_X1_NUM_SCALE_BIAS(MAMBA_1ST_LINEX_X1_NUM_SCALE_BIAS),
    .LINEX_X1_NUM_SCALE_DOUT(MAMBA_1ST_LINEX_X1_NUM_SCALE_DOUT),

    // Linear expand z1
    .LINEX_Z1_NUM_SCALE_DIN(MAMBA_1ST_LINEX_Z1_NUM_SCALE_DIN),
    .LINEX_Z1_NUM_SCALE_WEIGHT(MAMBA_1ST_LINEX_Z1_NUM_SCALE_WEIGHT),
    .LINEX_Z1_NUM_SCALE_BIAS(MAMBA_1ST_LINEX_Z1_NUM_SCALE_BIAS),
    .LINEX_Z1_NUM_SCALE_DOUT(MAMBA_1ST_LINEX_Z1_NUM_SCALE_DOUT),

    // SiLU piecewise
    .SILU_NUM_SCALE_DIN(MAMBA_1ST_SILU_NUM_SCALE_DIN),
    .SILU_NUM_SCALE_DOUT(MAMBA_1ST_SILU_NUM_SCALE_DOUT),

    // Convolution 1D
    .CONV1D_NUM_SCALE_DIN(MAMBA_1ST_CONV1D_NUM_SCALE_DIN),
    .CONV1D_NUM_SCALE_WEIGHT(MAMBA_1ST_CONV1D_NUM_SCALE_WEIGHT),
    .CONV1D_NUM_SCALE_BIAS(MAMBA_1ST_CONV1D_NUM_SCALE_BIAS),
    .CONV1D_NUM_SCALE_DOUT(MAMBA_1ST_CONV1D_NUM_SCALE_DOUT),

    // SSM
    // Preprocess
    // Linear expand dBC delta
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .SSM_LINEX_DBC_B_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_B_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .SSM_LINEX_DBC_C_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_C_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .SSM_LINEX_DELTA_NUM_SCALE_DIN(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DELTA_NUM_SCALE_WEIGHT(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DELTA_NUM_SCALE_BIAS(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_BIAS),
    .SSM_LINEX_DELTA_NUM_SCALE_DOUT(MAMBA_1ST_SSM_LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1(MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2(MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT(MAMBA_1ST_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1(MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2(MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT(MAMBA_1ST_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT),

    // Computation
    .SSM_NUM_SCALE_DIN(MAMBA_1ST_SSM_NUM_SCALE_DIN),
    .SSM_NUM_SCALE_DELTA_A(MAMBA_1ST_SSM_NUM_SCALE_DELTA_A),
    .SSM_NUM_SCALE_DELTA_B(MAMBA_1ST_SSM_NUM_SCALE_DELTA_B),
    .SSM_NUM_SCALE_C(MAMBA_1ST_SSM_NUM_SCALE_C),
    .SSM_NUM_SCALE_D(MAMBA_1ST_SSM_NUM_SCALE_D),
    .SSM_NUM_SCALE_DOUT(MAMBA_1ST_SSM_NUM_SCALE_DOUT),

    // Elementwise Production
    .EW_PROD_NUM_SCALE_DIN_1(MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_1),
    .EW_PROD_NUM_SCALE_DIN_2(MAMBA_1ST_EW_PROD_NUM_SCALE_DIN_2),
    .EW_PROD_NUM_SCALE_DOUT(MAMBA_1ST_EW_PROD_NUM_SCALE_DOUT),

    // Linear contract
    .LINCONT_NUM_SCALE_DIN(MAMBA_1ST_LINCONT_NUM_SCALE_DIN),
    .LINCONT_NUM_SCALE_WEIGHT(MAMBA_1ST_LINCONT_NUM_SCALE_WEIGHT),
    .LINCONT_NUM_SCALE_BIAS(MAMBA_1ST_LINCONT_NUM_SCALE_BIAS),
    .LINCONT_NUM_SCALE_DOUT(MAMBA_1ST_LINCONT_NUM_SCALE_DOUT),

    // Elementwise Addition
    .EW_ADD_NUM_SCALE_DIN_1(MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_1),
    .EW_ADD_NUM_SCALE_DIN_2(MAMBA_1ST_EW_ADD_NUM_SCALE_DIN_2),
    .EW_ADD_NUM_SCALE_DOUT(MAMBA_1ST_EW_ADD_NUM_SCALE_DOUT),

    .DEBUG_SWITCH(DEBUG_SWITCH_MAMBA_1ST)
) MAMBA_1st (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(patch_dOut),
    .dOut(MAMBA_1st_dOut),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    // SSM
    // .matrix_A(matrix_A_arr),
    // .matrix_D(matrix_D_arr),
    // .linEx_dBC_weight(linEx_dBC_weight_arr),
    // .linEx_delta_weight(linEx_delta_weight_arr),
    // .linEx_delta_bias(linEx_delta_bias_arr),

    .s_valid(patch_m_valid),
    .m_ready(MAMBA_2nd_s_ready),
    .s_ready(MAMBA_1st_s_ready),
    .m_valid(MAMBA_1st_m_valid)
);

U_MAMBA #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN), // L(16)
    .NUM_DIM_1(NUM_DIM),   // D(20)
    .NUM_DIM_2(NUM_ED),   // ED(40)
    
    .NUM_DIM_N(NUM_N),          // N(8)
    .NUM_DIM_DELTA(NUM_DELTA),  // dt_rank(32)

    // [J-WB] ---------- wb loader ----------
    .WB_ADDR_W(WB_ADDR_W),

    .LIGHTNORM_W_BASE(MAMBA_2ND_LNORM_W_BASE),      // [J-WB]
    .LINEX_X1_W_BASE(MAMBA_2ND_LINEX_X1_W_BASE),
    .LINEX_Z1_W_BASE(MAMBA_2ND_LINEX_Z1_W_BASE),
    .CONV1D_W_BASE(MAMBA_2ND_CONV1D_W_BASE),

    .LIN_DBC_DELTA_W_BASE(MAMBA_2ND_LIN_DBC_DELTA_W_BASE),
    .LIN_DBC_B_W_BASE(MAMBA_2ND_LIN_DBC_B_W_BASE),
    .LIN_DBC_C_W_BASE(MAMBA_2ND_LIN_DBC_C_W_BASE),
    .LIN_DELTA_W_BASE(MAMBA_2ND_LIN_DELTA_W_BASE),
    .SSM_A_BASE(MAMBA_2ND_SSM_A_BASE),
    .SSM_D_BASE(MAMBA_2ND_SSM_D_BASE),                  // [J-WB]

    .LINCONT_W_BASE(MAMBA_2ND_LINCONT_W_BASE),
    // [J-WB] ---------- wb loader ----------

    // LightNorm
    .LNORM_NUM_SCALE_DIN(MAMBA_2ND_LNORM_NUM_SCALE_DIN),
    .LNORM_NUM_SCALE_WEIGHT(MAMBA_2ND_LNORM_NUM_SCALE_WEIGHT),
    .LNORM_NUM_SCALE_BIAS(MAMBA_2ND_LNORM_NUM_SCALE_BIAS),
    .LNORM_NUM_SCALE_DOUT(MAMBA_2ND_LNORM_NUM_SCALE_DOUT),

    // Linear expand x1
    .LINEX_X1_NUM_SCALE_DIN(MAMBA_2ND_LINEX_X1_NUM_SCALE_DIN),
    .LINEX_X1_NUM_SCALE_WEIGHT(MAMBA_2ND_LINEX_X1_NUM_SCALE_WEIGHT),
    .LINEX_X1_NUM_SCALE_BIAS(MAMBA_2ND_LINEX_X1_NUM_SCALE_BIAS),
    .LINEX_X1_NUM_SCALE_DOUT(MAMBA_2ND_LINEX_X1_NUM_SCALE_DOUT),

    // Linear expand z1
    .LINEX_Z1_NUM_SCALE_DIN(MAMBA_2ND_LINEX_Z1_NUM_SCALE_DIN),
    .LINEX_Z1_NUM_SCALE_WEIGHT(MAMBA_2ND_LINEX_Z1_NUM_SCALE_WEIGHT),
    .LINEX_Z1_NUM_SCALE_BIAS(MAMBA_2ND_LINEX_Z1_NUM_SCALE_BIAS),
    .LINEX_Z1_NUM_SCALE_DOUT(MAMBA_2ND_LINEX_Z1_NUM_SCALE_DOUT),

    // SiLU piecewise
    .SILU_NUM_SCALE_DIN(MAMBA_2ND_SILU_NUM_SCALE_DIN),
    .SILU_NUM_SCALE_DOUT(MAMBA_2ND_SILU_NUM_SCALE_DOUT),

    // Convolution 1D
    .CONV1D_NUM_SCALE_DIN(MAMBA_2ND_CONV1D_NUM_SCALE_DIN),
    .CONV1D_NUM_SCALE_WEIGHT(MAMBA_2ND_CONV1D_NUM_SCALE_WEIGHT),
    .CONV1D_NUM_SCALE_BIAS(MAMBA_2ND_CONV1D_NUM_SCALE_BIAS),
    .CONV1D_NUM_SCALE_DOUT(MAMBA_2ND_CONV1D_NUM_SCALE_DOUT),

    // SSM
    // Preprocess
    // Linear expand dBC delta
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DBC_DELTA_NUM_SCALE_DOUT),

    // Linear expand dBC B
    .SSM_LINEX_DBC_B_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_B_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DBC_B_NUM_SCALE_DOUT),

    // Linear expand dBC C
    .SSM_LINEX_DBC_C_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DIN),
    .SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DBC_C_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DBC_C_NUM_SCALE_DOUT),

    // Linear expand dleta
    .SSM_LINEX_DELTA_NUM_SCALE_DIN(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DIN),
    .SSM_LINEX_DELTA_NUM_SCALE_WEIGHT(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_WEIGHT),
    .SSM_LINEX_DELTA_NUM_SCALE_BIAS(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_BIAS),
    .SSM_LINEX_DELTA_NUM_SCALE_DOUT(MAMBA_2ND_SSM_LINEX_DELTA_NUM_SCALE_DOUT),

    // DimExpander delta_A
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1(MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2(MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT(MAMBA_2ND_SSM_DIMEX_DELTA_A_NUM_SCALE_DOUT),

    // DimExpander delta_B
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1(MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_1),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2(MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DIN_2),
    .SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT(MAMBA_2ND_SSM_DIMEX_DELTA_B_NUM_SCALE_DOUT),

    // Computation
    .SSM_NUM_SCALE_DIN(MAMBA_2ND_SSM_NUM_SCALE_DIN),
    .SSM_NUM_SCALE_DELTA_A(MAMBA_2ND_SSM_NUM_SCALE_DELTA_A),
    .SSM_NUM_SCALE_DELTA_B(MAMBA_2ND_SSM_NUM_SCALE_DELTA_B),
    .SSM_NUM_SCALE_C(MAMBA_2ND_SSM_NUM_SCALE_C),
    .SSM_NUM_SCALE_D(MAMBA_2ND_SSM_NUM_SCALE_D),
    .SSM_NUM_SCALE_DOUT(MAMBA_2ND_SSM_NUM_SCALE_DOUT),

    // Elementwise Production
    .EW_PROD_NUM_SCALE_DIN_1(MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_1),
    .EW_PROD_NUM_SCALE_DIN_2(MAMBA_2ND_EW_PROD_NUM_SCALE_DIN_2),
    .EW_PROD_NUM_SCALE_DOUT(MAMBA_2ND_EW_PROD_NUM_SCALE_DOUT),

    // Linear contract
    .LINCONT_NUM_SCALE_DIN(MAMBA_2ND_LINCONT_NUM_SCALE_DIN),
    .LINCONT_NUM_SCALE_WEIGHT(MAMBA_2ND_LINCONT_NUM_SCALE_WEIGHT),
    .LINCONT_NUM_SCALE_BIAS(MAMBA_2ND_LINCONT_NUM_SCALE_BIAS),
    .LINCONT_NUM_SCALE_DOUT(MAMBA_2ND_LINCONT_NUM_SCALE_DOUT),

    // Elementwise Addition
    .EW_ADD_NUM_SCALE_DIN_1(MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_1),
    .EW_ADD_NUM_SCALE_DIN_2(MAMBA_2ND_EW_ADD_NUM_SCALE_DIN_2),
    .EW_ADD_NUM_SCALE_DOUT(MAMBA_2ND_EW_ADD_NUM_SCALE_DOUT),

    .DEBUG_SWITCH(DEBUG_SWITCH_MAMBA_2ND)
) MAMBA_2nd (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(MAMBA_1st_dOut),
    .dOut(MAMBA_2nd_dOut),

    // LightNorm
    // .lightNorm_weight(lightNorm_2nd_weight_arr),
    // .lightNorm_bias(lightNorm_2nd_bias_arr),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    // SSM
    // .matrix_A(matrix_A_2nd_arr),
    // .matrix_D(matrix_D_2nd_arr),
    // .linEx_dBC_weight(linEx_dBC_2nd_weight_arr),
    // .linEx_delta_weight(linEx_delta_2nd_weight_arr),
    // .linEx_delta_bias(linEx_delta_2nd_bias_arr),

    .s_valid(MAMBA_1st_m_valid),
    .m_ready(OH_s_ready),
    .s_ready(MAMBA_2nd_s_ready),
    .m_valid(MAMBA_2nd_m_valid)
);

U_Outputhead #(
    .DATA_WIDTH(DATA_WIDTH),
    .NUM_SEQLEN(NUM_SEQLEN),
    .NUM_DIM(NUM_DIM),
    .NUM_CLASS(NUM_CLASS),

    // LightNorm
    .LNORM_NUM_SCALE_DIN(OH_LNORM_NUM_SCALE_DIN),
    .LNORM_NUM_SCALE_WEIGHT(OH_LNORM_NUM_SCALE_WEIGHT),
    .LNORM_NUM_SCALE_BIAS(OH_LNORM_NUM_SCALE_BIAS),
    .LNORM_NUM_SCALE_DOUT(OH_LNORM_NUM_SCALE_DOUT),

    // Linear expand
    .LINEX_NUM_SCALE_DIN(OH_LINEX_NUM_SCALE_DIN),
    .LINEX_NUM_SCALE_WEIGHT(OH_LINEX_NUM_SCALE_WEIGHT),
    .LINEX_NUM_SCALE_BIAS(OH_LINEX_NUM_SCALE_BIAS),
    .LINEX_NUM_SCALE_DOUT(OH_LINEX_NUM_SCALE_DOUT),

    // [J-WB] ---------- wb loader ----------
    .LOG_NAME("WB_OH_Linear"),
    .WB_ADDR_W(WB_ADDR_W),
    .LIGHTNORM_W_BASE(OH_LNORM_W_BASE),
    .OH_LINEAR_W_BASE(OH_LINEAR_W_BASE),

    .DEBUG_SWITCH(DEBUG_SWITCH_OUTPUTHEAD)
) Outputhead (
    .clk(clk),
    .nRst(nRst),

    .ps_start(ps_start_rising),

    .dIn(MAMBA_2nd_dOut),
    .dOut(OH_dOut),

    // .lightNorm_weight(OH_lightNorm_weight_arr),
    // .lightNorm_bias(OH_lightNorm_bias_arr),

    // [J-WB] weight / bias 포트 삭제. 아래 3 신호에서 값 받아와
    .wb_valid(wb_valid),
    .wb_addr(wb_addr),
    .wb_data(wb_data),

    .s_valid(MAMBA_2nd_m_valid),
    .s_ready(OH_s_ready),

    .m_ready(m_ready), // [J-AXI Conn.] 상수 1 땜빵 제거 -> S_AXI.ram_ready
    .m_valid(OH_m_valid),

    .dOut_seq_idx(dOut_seq_idx),
    .frame_done(OH_frame_done)
);

edgeDetector edgeDetector (
    .clk(clk),
    .nRst(nRst),

    .curr_signal(ps_start),

    .rising_edge(ps_start_rising),
    .falling_edge(ps_start_falling)
);

// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========
// Main Code
// ========== ========== ========== ========== ========== ========== ========== ========== ========== ==========

//---------- ---------- ---------- Input frame control FSM ---------- ---------- ----------
logic startCtrl_busy_d;

assign frame_handshaking = frame_busy & patch_frame_done;
assign frame_busy  = (curr_startCtrl_state == BUSY); // [J] 입력측 frame 제어 (내부 전용)
assign eMamba_start = (curr_startCtrl_state == BUSY) && !startCtrl_busy_d;

// [J]
always @(posedge clk) begin
    if (!nRst) startCtrl_busy_d <= #1 1'b0;
    else       startCtrl_busy_d <= #1 (curr_startCtrl_state == BUSY);
end

always @(posedge clk) begin
    if (!nRst)
        curr_startCtrl_state <= #1 IDLE;
    else
        curr_startCtrl_state <= #1 next_startCtrl_state;
end

always @(*) begin
    next_startCtrl_state = curr_startCtrl_state;

    case (curr_startCtrl_state)
        IDLE: begin
            if (ps_start_rising)    next_startCtrl_state = BUSY;
        end
        BUSY: begin
            if (frame_handshaking)  next_startCtrl_state = IDLE;
        end
    endcase
end
//========== ========== ========== Input frame control FSM ========== ========== ==========

//---------- ---------- ---------- Output token control FSM ---------- ---------- ----------

assign m_valid = OH_m_valid;
assign frame_done  = OH_frame_done;   // [J-AXI Conn.] frame_valid -> frame_done

//========== ========== ========== Output token control FSM ========== ========== ==========

endmodule