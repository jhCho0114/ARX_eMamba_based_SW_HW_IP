// ****************************************************************************
// ****************************************************************************
// Copyright SoC Design Research Group, All rights reserved.
// Electronics and Telecommunications Research Institute (ETRI)
// 
// THESE DOCUMENTS CONTAIN CONFIDENTIAL INFORMATION AND KNOWLEDGE
// WHICH IS THE PROPERTY OF ETRI. NO PART OF THIS PUBLICATION IS
// TO BE USED FOR ANY OTHER PURPOSE, AND THESE ARE NOT TO BE
// REPRODUCED, COPIED, DISCLOSED, TRANSMITTED, STORED IN A RETRIEVAL
// SYSTEM OR TRANSLATED INTO ANY OTHER HUMAN OR COMPUTER LANGUAGE,
// IN ANY FORM, BY ANY MEANS, IN WHOLE OR IN PART, WITHOUT THE
// COMPLETE PRIOR WRITTEN PERMISSION OF ETRI.
// ****************************************************************************
// 2024-06-28
// Kyuseung Han (han@etri.re.kr)
// 2026-02-02
// Subin Ki (subinki@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_global.vh"
`include "ervp_endian.vh"
`include "dca_module_ext_memorymap_offset.vh"

`include "dca_matrix_info.vh"
`include "dca_matrix_lsu_inst.vh"

module DCA_MATRIX_DOWNSAMPLER_MMIOX_MLSU
(
  clk,
  rstnn,

  control_rmx_core_config,
  control_rmx_core_status,
  control_rmx_clear_request,
  control_rmx_clear_finish,
  control_rmx_log_fifo_wready,
  control_rmx_log_fifo_wrequest,
  control_rmx_log_fifo_wdata,
  control_rmx_inst_fifo_rready,
  control_rmx_inst_fifo_rdata,
  control_rmx_inst_fifo_rrequest,
  control_rmx_operation_finish,
  control_rmx_input_fifo_rready,
  control_rmx_input_fifo_rdata,
  control_rmx_input_fifo_rrequest,
  control_rmx_output_fifo_wready,
  control_rmx_output_fifo_wrequest,
  control_rmx_output_fifo_wdata,

  ma_sinst_wvalid,
	ma_sinst_wdata,
	ma_sinst_wready,
	ma_sinst_decode_finish,
	ma_sinst_execute_finish,
	ma_sinst_busy,
	ma_sload_tensor_row_wvalid,
	ma_sload_tensor_row_wlast,
	ma_sload_tensor_row_wdata,
	ma_sload_tensor_row_wready,
	ma_sstore_tensor_row_rvalid,
	ma_sstore_tensor_row_rlast,
	ma_sstore_tensor_row_rready,
  ma_sstore_tensor_row_rdata,

  mc_sinst_wvalid,
	mc_sinst_wdata,
	mc_sinst_wready,
	mc_sinst_decode_finish,
	mc_sinst_execute_finish,
	mc_sinst_busy,
	mc_sload_tensor_row_wvalid,
	mc_sload_tensor_row_wlast,
	mc_sload_tensor_row_wdata,
	mc_sload_tensor_row_wready,
	mc_sstore_tensor_row_rvalid,
	mc_sstore_tensor_row_rlast,
	mc_sstore_tensor_row_rready,
	mc_sstore_tensor_row_rdata
);

////////////////////////////
/* parameter input output */
////////////////////////////

parameter BW_ADDR = 32;
parameter MA_BW_DATA = 128;
parameter MB_BW_DATA = 128;
parameter MC_BW_DATA = 128;

parameter MATRIX_SIZE_PARA = 8;
parameter TENSOR_PARA = 0;

localparam BW_CONFIG = 1;
localparam BW_STATUS = `BW_DCA_DOWNSAMPLER_STATUS;
localparam BW_LOG = `BW_DCA_DOWNSAMPLER_LOG;
localparam BW_INST = `BW_DCA_DOWNSAMPLER_INST;
localparam BW_INPUT = 32;
localparam BW_OUTPUT = 32;

`include "dca_matrix_dim_util.vb"
`include "dca_matrix_dim_lpara.vb"
`include "dca_tensor_scalar_lpara.vb"

input wire clk;
input wire rstnn;

input wire [(BW_CONFIG)-1:0] control_rmx_core_config;
output wire [(BW_STATUS)-1:0] control_rmx_core_status;
input wire control_rmx_clear_request;
output wire control_rmx_clear_finish;
input wire control_rmx_log_fifo_wready;
output wire control_rmx_log_fifo_wrequest;
output wire [(BW_LOG)-1:0] control_rmx_log_fifo_wdata;
input wire control_rmx_inst_fifo_rready;
input wire [(BW_INST)-1:0] control_rmx_inst_fifo_rdata;
output wire control_rmx_inst_fifo_rrequest;
output wire control_rmx_operation_finish;
input wire control_rmx_input_fifo_rready;
input wire [(BW_INPUT)-1:0] control_rmx_input_fifo_rdata;
output wire control_rmx_input_fifo_rrequest;
input wire control_rmx_output_fifo_wready;
output wire control_rmx_output_fifo_wrequest;
output wire [(BW_OUTPUT)-1:0] control_rmx_output_fifo_wdata;

output wire ma_sinst_wvalid;
output wire [(`BW_DCA_MATRIX_LSU_INST)-1:0] ma_sinst_wdata;
input wire ma_sinst_wready;
input wire ma_sinst_decode_finish;
input wire ma_sinst_execute_finish;
input wire ma_sinst_busy;
input wire ma_sload_tensor_row_wvalid;
input wire ma_sload_tensor_row_wlast;
input wire [(BW_TENSOR_SCALAR*MATRIX_NUM_COL)-1:0] ma_sload_tensor_row_wdata;
output wire ma_sload_tensor_row_wready;
input wire ma_sstore_tensor_row_rvalid;
input wire ma_sstore_tensor_row_rlast;
output wire ma_sstore_tensor_row_rready;
output wire [(BW_TENSOR_SCALAR*MATRIX_NUM_COL)-1:0] ma_sstore_tensor_row_rdata;

output wire mc_sinst_wvalid;
output wire [(`BW_DCA_MATRIX_LSU_INST)-1:0] mc_sinst_wdata;
input wire mc_sinst_wready;
input wire mc_sinst_decode_finish;
input wire mc_sinst_execute_finish;
input wire mc_sinst_busy;
input wire mc_sload_tensor_row_wvalid;
input wire mc_sload_tensor_row_wlast;
input wire [(BW_TENSOR_SCALAR*MATRIX_NUM_COL)-1:0] mc_sload_tensor_row_wdata;
output wire mc_sload_tensor_row_wready;
input wire mc_sstore_tensor_row_rvalid;
input wire mc_sstore_tensor_row_rlast;
output wire mc_sstore_tensor_row_rready;
output wire [(BW_TENSOR_SCALAR*MATRIX_NUM_COL)-1:0] mc_sstore_tensor_row_rdata;

/////////////
/* signals */
/////////////

wire inst_rready;
wire [BW_INST-1:0] inst_rdata;
wire inst_rrequest;
wire inst_execute_finish;
wire log_wready;
wire log_wrequest;
wire [BW_LOG-1:0] log_wdata;
wire [BW_STATUS-1:0] status;

////////////
/* logics */
////////////

// control_rmx_core_config;
assign control_rmx_core_status = status;
assign control_rmx_clear_finish = 0;
assign log_wready = control_rmx_log_fifo_wready;
assign control_rmx_log_fifo_wrequest = log_wrequest;
assign control_rmx_log_fifo_wdata = log_wdata;
assign inst_rready = control_rmx_inst_fifo_rready;
assign inst_rdata = control_rmx_inst_fifo_rdata;
assign control_rmx_inst_fifo_rrequest = inst_rrequest;
assign control_rmx_operation_finish = inst_execute_finish;
// control_rmx_input_fifo_rready;
// control_rmx_input_fifo_rdata;
assign control_rmx_input_fifo_rrequest = 0;
// control_rmx_output_fifo_wready;
assign control_rmx_output_fifo_wrequest = 0;
assign control_rmx_output_fifo_wdata = 0;

DCA_MATRIX_DOWNSAMPLER_CORE
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA),
  .TENSOR_PARA(TENSOR_PARA)
)
i_core
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(1'b 0),
  .enable(1'b 1),
  .busy(),

  .inst_rready(inst_rready),
  .inst_rdata(inst_rdata),
  .inst_rrequest(inst_rrequest),
  .inst_execute_finish(inst_execute_finish),
  .log_wready(log_wready),
  .log_wrequest(log_wrequest),
  .log_wdata(log_wdata),
  .status(status),

  .lsu0_busy(ma_sinst_busy),
  .lsu0_inst_wvalid(ma_sinst_wvalid),
  .lsu0_inst_wdata(ma_sinst_wdata),
  .lsu0_inst_wready(ma_sinst_wready),
  .lsu0_inst_decode_finish(ma_sinst_decode_finish),
  .lsu0_inst_execute_finish(ma_sinst_execute_finish),
  .lsu0_load_tensor_row_wready(ma_sload_tensor_row_wready),
  .lsu0_load_tensor_row_wvalid(ma_sload_tensor_row_wvalid), 
  .lsu0_load_tensor_row_wlast(ma_sload_tensor_row_wlast),
  .lsu0_load_tensor_row_wdata(ma_sload_tensor_row_wdata),

  .lsu2_busy(mc_sinst_busy),
  .lsu2_inst_wvalid(mc_sinst_wvalid),
  .lsu2_inst_wdata(mc_sinst_wdata),
  .lsu2_inst_wready(mc_sinst_wready),
  .lsu2_inst_decode_finish(mc_sinst_decode_finish),
  .lsu2_inst_execute_finish(mc_sinst_execute_finish),
  .lsu2_store_tensor_row_rvalid(mc_sstore_tensor_row_rvalid),
  .lsu2_store_tensor_row_rready(mc_sstore_tensor_row_rready),
  .lsu2_store_tensor_row_rlast(mc_sstore_tensor_row_rlast),
  .lsu2_store_tensor_row_rdata(mc_sstore_tensor_row_rdata)
);

assign ma_sstore_tensor_row_rready = 0;
assign ma_sstore_tensor_row_rdata = 0;
assign mc_sload_tensor_row_wready = 0;

endmodule
