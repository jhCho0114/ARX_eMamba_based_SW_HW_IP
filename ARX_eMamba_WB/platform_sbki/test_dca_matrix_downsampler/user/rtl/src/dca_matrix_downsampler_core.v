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
// 2024-06-17
// Kyuseung Han (han@etri.re.kr)
// 2026-02-02
// Subin Ki (subinki@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_global.vh"

`include "dca_matrix_info.vh"
`include "dca_matrix_lsu_inst.vh"
`include "dca_module_ext_memorymap_offset.vh"

module DCA_MATRIX_DOWNSAMPLER_CORE
(
  clk,
  rstnn,
  clear,
  enable,
  busy,

  inst_rready,
  inst_rdata,
  inst_rrequest,
  inst_execute_finish,
  log_wready,
  log_wrequest,
  log_wdata,
  status,

  lsu0_busy,
  lsu0_inst_wvalid,
  lsu0_inst_wdata,
  lsu0_inst_wready,
  lsu0_inst_decode_finish,
  lsu0_inst_execute_finish,
  lsu0_load_tensor_row_wready,
  lsu0_load_tensor_row_wvalid,
  lsu0_load_tensor_row_wlast,
  lsu0_load_tensor_row_wdata,

  lsu2_busy,
  lsu2_inst_wvalid,
  lsu2_inst_wdata,
  lsu2_inst_wready,
  lsu2_inst_decode_finish,
  lsu2_inst_execute_finish,
  lsu2_store_tensor_row_rvalid,
  lsu2_store_tensor_row_rready,
  lsu2_store_tensor_row_rlast,
  lsu2_store_tensor_row_rdata
);

////////////////////////////
/* parameter input output */
////////////////////////////

parameter MATRIX_SIZE_PARA = 8;
parameter TENSOR_PARA = 0;

`include "dca_matrix_dim_util.vb"
`include "dca_matrix_dim_lpara.vb"
`include "dca_tensor_scalar_lpara.vb"
`include "dca_tensor_dim_lpara.vb"
`include "dca_matrix_downsampler_lpara.vh"

input wire clk;
input wire rstnn;
input wire clear;
input wire enable;
output wire busy;

localparam BW_INST = `BW_DCA_DOWNSAMPLER_INST;
localparam BW_LOG = `BW_DCA_DOWNSAMPLER_LOG;
localparam BW_STATUS = `BW_DCA_DOWNSAMPLER_STATUS;

input wire inst_rready;
input wire [BW_INST-1:0] inst_rdata;
output wire inst_rrequest;
output wire inst_execute_finish;
input wire log_wready;
output wire log_wrequest;
output wire [BW_LOG-1:0] log_wdata;
output wire [BW_STATUS-1:0] status;

input wire lsu0_busy;
output wire lsu0_inst_wvalid;
output wire [`BW_DCA_MATRIX_LSU_INST-1:0] lsu0_inst_wdata;
input wire lsu0_inst_wready;
input wire lsu0_inst_decode_finish;
input wire lsu0_inst_execute_finish;

output wire lsu0_load_tensor_row_wready;
input wire lsu0_load_tensor_row_wvalid;
input wire lsu0_load_tensor_row_wlast;
input wire [BW_TENSOR_ROW-1:0] lsu0_load_tensor_row_wdata;

input wire lsu2_busy;
output wire lsu2_inst_wvalid;
output wire [`BW_DCA_MATRIX_LSU_INST-1:0] lsu2_inst_wdata;
input wire lsu2_inst_wready;
input wire lsu2_inst_decode_finish;
input wire lsu2_inst_execute_finish;

input wire lsu2_store_tensor_row_rvalid;
output wire lsu2_store_tensor_row_rready;
input wire lsu2_store_tensor_row_rlast;
output wire [BW_TENSOR_ROW-1:0] lsu2_store_tensor_row_rdata;

/////////////
/* signals */
/////////////

localparam I_BLOCKED_STEP_INST_BUFFER_BW_DATA = BW_BLOCKED_STEP_INST;
localparam I_BLOCKED_STEP_INST_BUFFER_DEPTH = 4;

wire blocked_step_inst_buffer_wready;
wire blocked_step_inst_buffer_wrequest;
wire [I_BLOCKED_STEP_INST_BUFFER_BW_DATA-1:0] blocked_step_inst_buffer_wdata;
wire blocked_step_inst_buffer_rready;
wire blocked_step_inst_buffer_rrequest;
wire [I_BLOCKED_STEP_INST_BUFFER_BW_DATA-1:0] blocked_step_inst_buffer_rdata;

localparam BW_MOVE_DATA = BW_TENSOR_ROW;
localparam MREG_RESET_VALUE = TENSOR_ZERO;

wire i_mreg0_move_wenable;
wire [BW_MOVE_DATA-1:0] i_mreg0_move_wdata_list;
wire i_mreg0_move_renable;
wire [BW_MOVE_DATA-1:0] i_mreg0_move_rdata_list;
wire i_mreg0_shift_up;
wire i_mreg0_shift_left;
wire i_mreg0_transpose;
wire [BW_TENSOR_MATRIX-1:0] i_mreg0_all_rdata_list2d;
wire [BW_TENSOR_ROW-1:0] i_mreg0_upmost_rdata_list1d;

wire i_load02mreg_busy;
wire i_load02mreg_loadreg_rready;
wire i_load02mreg_loadreg_rrequest;

wire i_mreg2_init;
wire i_mreg2_move_wenable;
wire [BW_MOVE_DATA-1:0] i_mreg2_move_wdata_list;
wire i_mreg2_move_renable;
wire [BW_MOVE_DATA-1:0] i_mreg2_move_rdata_list;
wire [MATRIX_NUM_ELEMENT-1:0] i_mreg2_all_wenable_list2d;
wire [BW_TENSOR_MATRIX-1:0] i_mreg2_all_wdata_list2d;
wire [BW_TENSOR_MATRIX-1:0] i_mreg2_all_rdata_list2d;

wire i_mreg2store_busy;
wire i_mreg2store_storereg_wready;
wire i_mreg2store_storereg_wrequest;

wire i_cal_busy;
wire i_cal_cal_start;
wire [BW_BLOCKED_STEP_INST-1:0] i_cal_cal_inst;
wire i_cal_cal_finish;
wire i_cal_loadreg0_release;

wire i_fsm_busy;

////////////
/* logics */
////////////

ERVP_FIFO
#(
  .BW_DATA(I_BLOCKED_STEP_INST_BUFFER_BW_DATA),
  .DEPTH(I_BLOCKED_STEP_INST_BUFFER_DEPTH)
)
i_step_inst_buffer
(
	.clk(clk),
  .rstnn(rstnn),
	.enable(enable),
  .clear(clear),
	.wready(blocked_step_inst_buffer_wready),
	.wfull(),
	.wrequest(blocked_step_inst_buffer_wrequest),
	.wdata(blocked_step_inst_buffer_wdata),
	.wnum(),
	.rready(blocked_step_inst_buffer_rready),
	.rempty(),
	.rrequest(blocked_step_inst_buffer_rrequest),
	.rdata(blocked_step_inst_buffer_rdata),
	.rnum()
);

DCA_MATRIX_DOWNSAMPLER_INST_SPLITER
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA)
)
i_inst_spliter
(
	.clk(clk),
	.rstnn(rstnn),
  .clear(clear),
  .enable(enable),
  .busy(),

  .inst_rready(inst_rready),
  .inst_rdata(inst_rdata),
  .inst_rrequest(inst_rrequest),
  
  .loadreg0_release(i_cal_loadreg0_release),

  .blocked_step_inst_buffer_wready(blocked_step_inst_buffer_wready),
  .blocked_step_inst_buffer_wrequest(blocked_step_inst_buffer_wrequest),
  .blocked_step_inst_buffer_wdata(blocked_step_inst_buffer_wdata),
  .lsu0_inst_buffer_wready(lsu0_inst_wready),
  .lsu0_inst_buffer_wrequest(lsu0_inst_wvalid),
  .lsu0_inst_buffer_wdata(lsu0_inst_wdata),
  .lsu2_inst_buffer_wready(lsu2_inst_wready),
  .lsu2_inst_buffer_wrequest(lsu2_inst_wvalid),
  .lsu2_inst_buffer_wdata(lsu2_inst_wdata)
);

DCA_MATRIX_REGISTER_TYPE3
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA),
  .BW_TENSOR_SCALAR(BW_TENSOR_SCALAR),
  .BW_MOVE_DATA(BW_MOVE_DATA),
  .RESET_VALUE(MREG_RESET_VALUE)
)
i_mreg0
(
  .clk(clk),
  .rstnn(rstnn),

  .move_wenable(i_mreg0_move_wenable),
  .move_wdata_list(i_mreg0_move_wdata_list),
  .move_renable(i_mreg0_move_renable),
  .move_rdata_list(i_mreg0_move_rdata_list),
  
  .shift_up(i_mreg0_shift_up),
  .shift_left(i_mreg0_shift_left),
  .transpose(i_mreg0_transpose),
  
  .all_rdata_list2d(i_mreg0_all_rdata_list2d),
  .upmost_rdata_list1d(i_mreg0_upmost_rdata_list1d)
);

assign i_mreg0_move_renable = 0;
assign i_mreg0_transpose = 0;

DCA_MATRIX_LOAD2MREG
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA),
  .TENSOR_PARA(TENSOR_PARA)
)
i_load02mreg
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(clear),
  .enable(enable),
  .busy(i_load02mreg_busy),

  .load_tensor_row_wready(lsu0_load_tensor_row_wready),
  .load_tensor_row_wvalid(lsu0_load_tensor_row_wvalid),
  .load_tensor_row_wlast(lsu0_load_tensor_row_wlast),
  .load_tensor_row_wdata(lsu0_load_tensor_row_wdata),

  .mreg_move_wenable(i_mreg0_move_wenable),
  .mreg_move_wdata_list1d(i_mreg0_move_wdata_list),

  .loadreg_rready(i_load02mreg_loadreg_rready),
  .loadreg_rrequest(i_load02mreg_loadreg_rrequest)
);

DCA_MATRIX_REGISTER_TYPE5
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA),
  .BW_TENSOR_SCALAR(BW_TENSOR_SCALAR),
  .RESET_VALUE(MREG_RESET_VALUE)
)
i_mreg2
(
  .clk(clk),
  .rstnn(rstnn),

  .init(i_mreg2_init),

  .move_wenable(i_mreg2_move_wenable),
  .move_wdata_list(i_mreg2_move_wdata_list),
  .move_renable(i_mreg2_move_renable),
  .move_rdata_list(i_mreg2_move_rdata_list),

  .all_wenable_list2d(i_mreg2_all_wenable_list2d),
  .all_wdata_list2d(i_mreg2_all_wdata_list2d),
  .all_rdata_list2d(i_mreg2_all_rdata_list2d)
);

DCA_MATRIX_MREG2STORE
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA),
  .BW_TENSOR_SCALAR(BW_TENSOR_SCALAR)
)
i_mreg2store
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(clear),
  .enable(enable),
  .busy(i_mreg2store_busy),

  .storereg_wready(i_mreg2store_storereg_wready),
  .storereg_wrequest(i_mreg2store_storereg_wrequest),

  .mreg_move_renable(i_mreg2_move_renable),
  .mreg_move_rdata_list1d(i_mreg2_move_rdata_list),

  .store_tensor_row_rvalid(lsu2_store_tensor_row_rvalid),
  .store_tensor_row_rready(lsu2_store_tensor_row_rready),
  .store_tensor_row_rlast(lsu2_store_tensor_row_rlast),
  .store_tensor_row_rdata(lsu2_store_tensor_row_rdata)
);

DCA_MATRIX_DOWNSAMPLER_BLOCK_CAL
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA),
  .TENSOR_PARA(TENSOR_PARA)
)
i_cal
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(clear),
  .enable(enable),
  .busy(i_cal_busy),

  .cal_start(i_cal_cal_start),
  .cal_inst(i_cal_cal_inst),
  .cal_finish(i_cal_cal_finish),

  .mreg0_all_rdata_list2d(i_mreg0_all_rdata_list2d),
  .mreg0_shift_up(i_mreg0_shift_up),
  .mreg0_shift_left(i_mreg0_shift_left),

  .mreg2_init(i_mreg2_init),
  .mreg2_all_wenable_list2d(i_mreg2_all_wenable_list2d),
  .mreg2_all_wdata_list2d(i_mreg2_all_wdata_list2d)
);

DCA_MATRIX_DOWNSAMPLER_CORE_FSM
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA)
)
i_fsm
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(clear),
  .enable(enable),
  .busy(i_fsm_busy),

  .blocked_step_inst_rready(blocked_step_inst_buffer_rready),
  .blocked_step_inst_rdata(blocked_step_inst_buffer_rdata),
  .blocked_step_inst_rrequest(blocked_step_inst_buffer_rrequest),

  .loadreg0_rready(i_load02mreg_loadreg_rready),
  .loadreg0_rrequest(i_load02mreg_loadreg_rrequest),
  .mreg2_wready(i_mreg2store_storereg_wready),
  .storereg_wready(i_mreg2store_storereg_wready),
  .storereg_wrequest(i_mreg2store_storereg_wrequest),
  .lsu2_finish(lsu2_inst_execute_finish),

  .cal_start(i_cal_cal_start),
  .cal_inst(i_cal_cal_inst),
  .cal_finish(i_cal_cal_finish),

  .loadreg0_release(i_cal_loadreg0_release),
  .inst_finish(inst_execute_finish)
);

assign log_wrequest = 0;
assign log_wdata = 0;
assign status = 0;
assign busy = inst_rready | blocked_step_inst_buffer_rready | i_fsm_busy;

endmodule
