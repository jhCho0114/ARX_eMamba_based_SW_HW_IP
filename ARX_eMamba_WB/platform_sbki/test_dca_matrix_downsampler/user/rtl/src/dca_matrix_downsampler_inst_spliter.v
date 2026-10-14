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

module DCA_MATRIX_DOWNSAMPLER_INST_SPLITER
(
  clk,
  rstnn,
  clear,
  enable,
  busy,

  inst_rready,
  inst_rdata,
  inst_rrequest,

  loadreg0_release,

  blocked_step_inst_buffer_wready,
  blocked_step_inst_buffer_wrequest,
  blocked_step_inst_buffer_wdata,
  lsu0_inst_buffer_wready,
  lsu0_inst_buffer_wrequest,
  lsu0_inst_buffer_wdata,
  lsu2_inst_buffer_wready,
  lsu2_inst_buffer_wrequest,
  lsu2_inst_buffer_wdata
);

////////////////////////////
/* parameter input output */
////////////////////////////

parameter MATRIX_SIZE_PARA = 8;
parameter MATRIX_SIZE_PARA_MC = MATRIX_SIZE_PARA >> 1;

`include "dca_matrix_dim_util.vb"
`include "dca_matrix_dim_lpara.vb"
`include "dca_matrix_downsampler_lpara.vh"

input wire clk;
input wire rstnn;
input wire clear;
input wire enable;
output wire busy;

localparam BW_INST = `BW_DCA_DOWNSAMPLER_INST;

input wire inst_rready;
input wire [BW_INST-1:0] inst_rdata;
output wire inst_rrequest;
input wire loadreg0_release;

input wire blocked_step_inst_buffer_wready;
output wire blocked_step_inst_buffer_wrequest;
output reg [BW_BLOCKED_STEP_INST-1:0] blocked_step_inst_buffer_wdata;

input wire lsu0_inst_buffer_wready;
output wire lsu0_inst_buffer_wrequest;
output wire [`BW_DCA_MATRIX_LSU_INST-1:0] lsu0_inst_buffer_wdata;

input wire lsu2_inst_buffer_wready;
output wire lsu2_inst_buffer_wrequest;
output wire [`BW_DCA_MATRIX_LSU_INST-1:0] lsu2_inst_buffer_wdata;

/////////////
/* signals */
/////////////

wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] ma_info;
wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] mc_info;
wire [`BW_DCA_DOWNSAMPLER_INST_STRIDE_ONEHOT-1:0] stride_onehot;
wire [`BW_DCA_DOWNSAMPLER_OPCODE-1:0] opcode;

wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] ma_info_eff;
wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] mc_info_eff;

wire [`BW_DCA_MATRIX_INFO_ADDR-1:0] ma_addr;
wire [`BW_DCA_MATRIX_INFO_STRIDE_LS3-1:0] ma_stride_ls3;
wire [`BW_DCA_MATRIX_INFO_NUM_ROW_M1-1:0] ma_row_m1, ma_row_m1_eff;
wire [`BW_DCA_MATRIX_INFO_NUM_COL_M1-1:0] ma_col_m1, ma_col_m1_eff;
wire [`BW_DCA_MATRIX_INFO_FLAGS-1:0] ma_flags;
wire [`BW_DCA_MATRIX_INFO_ADDR-1:0] mc_addr;
wire [`BW_DCA_MATRIX_INFO_STRIDE_LS3-1:0] mc_stride_ls3;
wire [`BW_DCA_MATRIX_INFO_NUM_ROW_M1-1:0] mc_row_m1, mc_row_m1_eff;
wire [`BW_DCA_MATRIX_INFO_NUM_COL_M1-1:0] mc_col_m1, mc_col_m1_eff;
wire [`BW_DCA_MATRIX_INFO_FLAGS-1:0] mc_flags;

wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] i_ma_spliter_matrix_info;
wire i_ma_spliter_init;
wire i_ma_spliter_is_col_first;
wire i_ma_spliter_iterate;
reg i_ma_spliter_go_next_base;
wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] i_ma_spliter_block_info;
wire i_ma_spliter_is_first_x;
wire i_ma_spliter_is_last_x;
wire i_ma_spliter_is_first_y;
wire i_ma_spliter_is_last_y;
wire i_ma_spliter_is_first_element;
wire i_ma_spliter_is_last_element;

wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] i_mc_spliter_matrix_info;
wire i_mc_spliter_init;
wire i_mc_spliter_is_col_first;
wire i_mc_spliter_iterate;
reg i_mc_spliter_go_next_base;
wire [`BW_DCA_MATRIX_INFO_ALIGNED-1:0] i_mc_spliter_block_info;
wire i_mc_spliter_is_first_x;
wire i_mc_spliter_is_last_x;
wire i_mc_spliter_is_first_y;
wire i_mc_spliter_is_last_y;
wire i_mc_spliter_is_first_element;
wire i_mc_spliter_is_last_element;

wire [`BW_DCA_MATRIX_LSU_INST_OPCODE-1:0] lsu0_inst_opcode;
wire [`BW_DCA_MATRIX_LSU_INST_OPCODE-1:0] lsu2_inst_opcode;

localparam BW_STATE = 1;
localparam IDLE = 0;
localparam BUSY = 1;

reg [BW_STATE-1:0] state;
wire start;
wire finish;
wire blocked_step_inst_is_transfered;

reg loaded_acc_was_handled;

wire has_lsu0_request; // load
wire has_lsu2_request; //store

wire is_first_block_of_all_steps;
wire is_last_block_of_all_steps;

wire [MATRIX_MAX_DIM-1:0] stride_onehot_extended;
wire valid_stride;
wire ma_is_binary;
wire mb_is_binary;
wire [MATRIX_NUM_ROW-1:0] valid_row_list;
wire [MATRIX_NUM_COL-1:0] valid_col_list;
wire [MATRIX_MAX_DIM-1:0] valid_mmult_list; 

//wire [MATRIX_NUM_ROW-1:0] valid_mmult_list_reduced;

////////////
/* logics */
////////////

assign {ma_flags, ma_col_m1, ma_row_m1, ma_stride_ls3, ma_addr} = ma_info;
assign {mc_flags, mc_col_m1, mc_row_m1, mc_stride_ls3, mc_addr} = mc_info;

assign ma_row_m1_eff = ma_row_m1 - {{(`BW_DCA_MATRIX_INFO_NUM_ROW_M1-1){1'b0}}, ~ma_row_m1[0]};
assign ma_col_m1_eff = ma_col_m1 - {{(`BW_DCA_MATRIX_INFO_NUM_COL_M1-1){1'b0}}, ~ma_col_m1[0]};
assign mc_row_m1_eff = ((ma_row_m1_eff + 1) >> 1) - 1;
assign mc_col_m1_eff = ((ma_col_m1_eff + 1) >> 1) - 1;

assign ma_info_eff = {ma_flags, ma_col_m1_eff, ma_row_m1_eff, ma_stride_ls3, ma_addr};
assign mc_info_eff = {mc_flags, mc_col_m1_eff, mc_row_m1_eff, mc_stride_ls3, mc_addr};

assign {opcode,mc_info,ma_info} = inst_rdata;
assign stride_onehot = 2;
assign stride_onehot_extended = {stride_onehot, stride_onehot};
assign valid_stride = 0;
assign ma_is_binary = 0;
assign mb_is_binary = 0;

assign is_first_block_of_all_steps = i_ma_spliter_is_first_element & i_mc_spliter_is_first_element;
assign is_last_block_of_all_steps = i_ma_spliter_is_last_element & i_mc_spliter_is_last_element;

DCA_MATRIX_SPLITER
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA)
)
i_ma_spliter
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(clear),
  .enable(enable),

  .matrix_info(i_ma_spliter_matrix_info),
  .init(i_ma_spliter_init),
  .is_col_first(i_ma_spliter_is_col_first),
  .iterate(i_ma_spliter_iterate),
  .go_next_base(i_ma_spliter_go_next_base),

  .block_info(i_ma_spliter_block_info),
  .is_first_x(i_ma_spliter_is_first_x),
  .is_last_x(i_ma_spliter_is_last_x),
  .is_first_y(i_ma_spliter_is_first_y),
  .is_last_y(i_ma_spliter_is_last_y),
  .is_first_element(i_ma_spliter_is_first_element),
  .is_last_element(i_ma_spliter_is_last_element),
  .valid_row_list(),
  .valid_col_list()
);

//assign i_ma_spliter_matrix_info = ma_info;
assign i_ma_spliter_matrix_info = ma_info_eff;
assign i_ma_spliter_init = start;
assign i_ma_spliter_is_col_first = 1;
assign i_ma_spliter_iterate = blocked_step_inst_is_transfered & has_lsu0_request;

DCA_MATRIX_SPLITER
#(
  .MATRIX_SIZE_PARA(MATRIX_SIZE_PARA_MC)
)
i_mc_spliter
(
  .clk(clk),
  .rstnn(rstnn),
  .clear(clear),
  .enable(enable),

  .matrix_info(i_mc_spliter_matrix_info),
  .init(i_mc_spliter_init),
  .is_col_first(i_mc_spliter_is_col_first),
  .iterate(i_mc_spliter_iterate),
  .go_next_base(i_mc_spliter_go_next_base),

  .block_info(i_mc_spliter_block_info),
  .is_first_x(i_mc_spliter_is_first_x),
  .is_last_x(i_mc_spliter_is_last_x),
  .is_first_y(i_mc_spliter_is_first_y),
  .is_last_y(i_mc_spliter_is_last_y),
  .is_first_element(i_mc_spliter_is_first_element),
  .is_last_element(i_mc_spliter_is_last_element),
  .valid_row_list(valid_row_list),
  .valid_col_list(valid_col_list)
);

//assign i_mc_spliter_matrix_info = mc_info;
assign i_mc_spliter_matrix_info = mc_info_eff;
assign i_mc_spliter_init = start;
assign i_mc_spliter_is_col_first = 1;
assign i_mc_spliter_iterate = blocked_step_inst_is_transfered & has_lsu2_request;

always@(*)
begin
  i_ma_spliter_go_next_base = 0;
  i_mc_spliter_go_next_base = 0;
  if(blocked_step_inst_is_transfered)
  begin
    i_ma_spliter_go_next_base = i_ma_spliter_is_last_x;
    i_mc_spliter_go_next_base = i_mc_spliter_is_last_x;
  end
end

assign has_lsu0_request = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_LSU0_REQ];
assign has_lsu2_request = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_LSU2_REQ];

always@(posedge clk, negedge rstnn)
begin
  if(rstnn==0)
    state <= IDLE;
  else if(enable)
    case(state)
      IDLE:
        if(start)
          state <= BUSY;
      BUSY:
        if(finish)
          state <= IDLE;
    endcase
end

assign start = (state==IDLE) & inst_rready;
assign blocked_step_inst_is_transfered = blocked_step_inst_buffer_wready & blocked_step_inst_buffer_wrequest;
assign finish = blocked_step_inst_is_transfered & is_last_block_of_all_steps;

assign inst_rrequest = finish;

assign blocked_step_inst_buffer_wrequest = (state==BUSY) & blocked_step_inst_buffer_wready & (has_lsu0_request? lsu0_inst_buffer_wready : 1) & (has_lsu2_request? lsu2_inst_buffer_wready : 1);

assign valid_mmult_list = 0;

always@(*)
begin
  blocked_step_inst_buffer_wdata = {valid_mmult_list, valid_row_list, valid_col_list, is_last_block_of_all_steps, mb_is_binary, ma_is_binary, valid_stride, stride_onehot_extended, opcode};
  blocked_step_inst_buffer_wdata[`DCA_DOWNSAMPLER_OPCODE_INDEX_LSU0_REQ] = has_lsu0_request;
  blocked_step_inst_buffer_wdata[`DCA_DOWNSAMPLER_OPCODE_INDEX_LSU2_REQ] = has_lsu2_request;
end

assign lsu0_inst_buffer_wrequest = blocked_step_inst_buffer_wrequest & has_lsu0_request;
assign lsu2_inst_buffer_wrequest = blocked_step_inst_buffer_wrequest & has_lsu2_request;

assign lsu0_inst_opcode = `DCA_MATRIX_LSU_INST_OPCODE_READ;
assign lsu2_inst_opcode = `DCA_MATRIX_LSU_INST_OPCODE_WRITE;

assign lsu0_inst_buffer_wdata = {i_ma_spliter_block_info, lsu0_inst_opcode};
assign lsu2_inst_buffer_wdata = {i_mc_spliter_block_info, lsu2_inst_opcode};

assign busy = (state==BUSY);

endmodule


