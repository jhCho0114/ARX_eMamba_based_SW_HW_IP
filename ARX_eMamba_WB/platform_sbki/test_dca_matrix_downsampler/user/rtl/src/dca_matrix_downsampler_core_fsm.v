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

module DCA_MATRIX_DOWNSAMPLER_CORE_FSM
(
  clk,
  rstnn,
  clear,
  enable,
  busy,

  blocked_step_inst_rready,
  blocked_step_inst_rdata,
  blocked_step_inst_rrequest,

  loadreg0_rready,
  loadreg0_rrequest,
  mreg2_wready,
  storereg_wready,
  storereg_wrequest,
  lsu2_finish,

  cal_start,
  cal_inst,
  cal_finish,

  loadreg0_release,
  inst_finish
);

////////////////////////////
/* parameter input output */
////////////////////////////

parameter MATRIX_SIZE_PARA = 8;

`include "dca_matrix_dim_util.vb"
`include "dca_matrix_dim_lpara.vb"
`include "dca_matrix_downsampler_lpara.vh"

input wire clk;
input wire rstnn;
input wire clear;
input wire enable;
output wire busy;

input wire blocked_step_inst_rready;
input wire [BW_BLOCKED_STEP_INST-1:0] blocked_step_inst_rdata;
output wire blocked_step_inst_rrequest;

input wire loadreg0_rready;
output wire loadreg0_rrequest;
input wire mreg2_wready;
input wire storereg_wready;
output wire storereg_wrequest;
input wire lsu2_finish;

output wire cal_start;
output wire [BW_BLOCKED_STEP_INST-1:0] cal_inst;
input wire cal_finish;

output wire loadreg0_release;
output wire inst_finish;

/////////////
/* signals */
/////////////

wire [`BW_DCA_DOWNSAMPLER_OPCODE-1:0] opcode;
wire [MATRIX_MAX_DIM-1:0] stride_onehot;
wire valid_stride;
wire ma_is_binary;
wire mb_is_binary;
wire [MATRIX_NUM_COL-1:0] valid_col_list;
wire [MATRIX_NUM_ROW-1:0] valid_row_list;
wire is_last_block_of_all_steps;

wire has_lsu0_request;
wire has_lsu2_request;

localparam BW_STORE_LOCK_STATE = 4;
reg [BW_STORE_LOCK_STATE-1:0] store_lock_state;
wire store_finish;

localparam BW_STATE = 2;
localparam IDLE = 0;
localparam CAL = 1;
localparam WAIT = 2;

reg [BW_STATE-1:0] state;
wire go_cal;
wire go_idle;
wire go_wait;
wire finish;
wire direct_finish;

////////////
/* logics */
////////////

assign cal_inst = blocked_step_inst_rdata;

assign {valid_row_list, valid_col_list, is_last_block_of_all_steps, mb_is_binary, ma_is_binary, valid_stride, stride_onehot, opcode} = blocked_step_inst_rdata;

assign has_lsu0_request = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_LSU0_REQ];
assign has_lsu2_request = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_LSU2_REQ];

always@(posedge clk, negedge rstnn)
begin
  if(rstnn==0)
    store_lock_state <= 1;
  else
  begin
    if(storereg_wrequest & store_finish)
      ;
    else if(store_finish)
      store_lock_state <= store_lock_state>>1;
    else if(storereg_wrequest)
      store_lock_state <= store_lock_state<<1;
  end
end

assign store_finish = lsu2_finish;

always@(posedge clk or negedge rstnn)
begin
  if(~rstnn)
    state <= IDLE;
  else if(clear)
    state <= IDLE;
  else if(enable)
    case(state)
      IDLE:
        if(go_cal)
          state <= CAL;
      CAL:
        if(go_wait)
          state <= WAIT;
        else if(go_idle)
          state <= IDLE;
      WAIT:
        if(inst_finish)
          state <= IDLE;
    endcase
end

assign go_cal = (state==IDLE) & blocked_step_inst_rready & (has_lsu0_request? loadreg0_rready : 1) & mreg2_wready & (has_lsu2_request? (storereg_wready & (~store_lock_state[BW_STORE_LOCK_STATE-1])) : 1);
assign go_idle = (state==CAL) & cal_finish & (~is_last_block_of_all_steps);
assign go_wait = (state==CAL) & cal_finish & is_last_block_of_all_steps;
assign inst_finish = (state==WAIT) & (store_lock_state[0] | (store_lock_state[1] & store_finish));

assign loadreg0_release = go_cal & has_lsu0_request;

assign finish = cal_finish; 

assign cal_start = go_cal;
assign loadreg0_rrequest  = finish & has_lsu0_request;
assign storereg_wrequest = finish & has_lsu2_request;
assign blocked_step_inst_rrequest = finish;

assign busy = (state!=IDLE);

endmodule
