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
// 2024-06-27
// HyeongUk Jang (lemon@etri.re.kr)
// Kyuseung Han (han@etri.re.kr)
// 2026-02-02
// Subin Ki (subinki@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`include "ervp_global.vh"
`include "ervp_axi_define.vh"
`include "dca_module_ext_memorymap_offset.vh"

module DCA_MATRIX_DOWNSAMPLER_BLOCK_CAL
(
  clk,
  rstnn,
  clear,
  enable,
  busy,

  cal_start,
  cal_inst,
  cal_finish,

  mreg0_all_rdata_list2d,
  mreg0_shift_up,
  mreg0_shift_left,

  mreg2_init,
  mreg2_all_wenable_list2d,
  mreg2_all_wdata_list2d
);

parameter MATRIX_SIZE_PARA = 4;
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

input wire cal_start;
input wire [BW_BLOCKED_STEP_INST-1:0] cal_inst;
output wire cal_finish;

input wire [BW_TENSOR_MATRIX-1:0] mreg0_all_rdata_list2d;
output wire mreg0_shift_up;
output wire mreg0_shift_left;

output wire mreg2_init;
output wire [MATRIX_NUM_ELEMENT-1:0] mreg2_all_wenable_list2d;
output reg [BW_TENSOR_MATRIX-1:0] mreg2_all_wdata_list2d;

/////////////
/* signals */
/////////////

wire [`BW_DCA_DOWNSAMPLER_OPCODE-1:0] opcode;
wire [MATRIX_MAX_DIM-1:0] stride_onehot;
wire valid_stride;
wire ma_is_binary;
wire mb_is_binary;
wire is_last_block_of_all_steps;
wire [MATRIX_NUM_COL-1:0] valid_col_list;
wire [MATRIX_NUM_ROW-1:0] valid_row_list;
wire [MATRIX_MAX_DIM-1:0] valid_mmult_list;

wire opcode_topleft;
wire opcode_max;
wire opcode_avg;
wire opcode_sum;

localparam BW_STATE = 1;
localparam IDLE = 0;
localparam BUSY = 1;

//wire do_write;

reg [BW_STATE-1:0] state;

genvar i_row, i_col;

reg ds_finish;

wire [BW_TENSOR_MATRIX-1:0] i_downsampler_output_matrix;

// TENSOR_PARA
localparam BW_TENSOR_SCALAR_ACC_EXTRA = 2;
localparam BW_TENSOR_SCALAR_ACC = BW_TENSOR_SCALAR + BW_TENSOR_SCALAR_ACC_EXTRA;

////////////
/* logics */
////////////

assign {valid_mmult_list, valid_row_list, valid_col_list, is_last_block_of_all_steps, mb_is_binary, ma_is_binary, valid_stride, stride_onehot, opcode} = cal_inst;

assign opcode_topleft = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_TOPLEFT];
assign opcode_max = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_MAX];
assign opcode_avg = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_AVG];
assign opcode_sum = opcode[`DCA_DOWNSAMPLER_OPCODE_INDEX_SUM];

always@(posedge clk, negedge rstnn)
begin
  if(rstnn==0)
    state <= IDLE;
  else if(clear)
    state <= IDLE;
  else
    case(state)
      IDLE:
        if(cal_start)
          state <= BUSY;
      BUSY:
        if(cal_finish)
          state <= IDLE;
    endcase
end

// fully-parallel downsampler: no sliding scan inside CAL
assign mreg0_shift_up   = 0;
assign mreg0_shift_left = 0;

assign mreg2_init = 0;

assign cal_finish = ds_finish;

always@(*)
begin
  ds_finish = 0;
  if(state==BUSY)
    ds_finish = 1;
end

function integer GET_MATRIX_INDEX;
  input integer row_index;
  input integer col_index;
begin
  GET_MATRIX_INDEX = (row_index*BW_TENSOR_ROW) + (col_index*BW_TENSOR_SCALAR) + BW_TENSOR_SCALAR - 1;
end
endfunction

generate
  for(i_row=0; i_row<MATRIX_NUM_ROW; i_row=i_row+1)
  begin : gen_row
    for(i_col=0; i_col<MATRIX_NUM_COL; i_col=i_col+1)
    begin : gen_col

      localparam integer OUT_BIT = GET_MATRIX_INDEX(i_row, i_col);

      wire is_out_region;
      assign is_out_region = (i_row < OUT_MATRIX_NUM_ROW) && (i_col < OUT_MATRIX_NUM_COL);

      wire wen;
      assign wen = (state==BUSY) & is_out_region & valid_row_list[i_row] & valid_col_list[i_col];

      assign mreg2_all_wenable_list2d[i_row*MATRIX_NUM_COL + i_col] = wen;

      if((i_row < OUT_MATRIX_NUM_ROW) && (i_col < OUT_MATRIX_NUM_COL))
      begin : gen_calc

        localparam integer IN_R0 = (2*i_row);
        localparam integer IN_C0 = (2*i_col);

        localparam integer BIT00 = GET_MATRIX_INDEX(IN_R0,   IN_C0);
        localparam integer BIT01 = GET_MATRIX_INDEX(IN_R0,   (IN_C0+1));
        localparam integer BIT10 = GET_MATRIX_INDEX((IN_R0+1), IN_C0);
        localparam integer BIT11 = GET_MATRIX_INDEX((IN_R0+1), (IN_C0+1));

        // extract 2x2 input elements
        wire [BW_TENSOR_SCALAR-1:0] a00_u = mreg0_all_rdata_list2d[BIT00-:BW_TENSOR_SCALAR];
        wire [BW_TENSOR_SCALAR-1:0] a01_u = mreg0_all_rdata_list2d[BIT01-:BW_TENSOR_SCALAR];
        wire [BW_TENSOR_SCALAR-1:0] a10_u = mreg0_all_rdata_list2d[BIT10-:BW_TENSOR_SCALAR];
        wire [BW_TENSOR_SCALAR-1:0] a11_u = mreg0_all_rdata_list2d[BIT11-:BW_TENSOR_SCALAR];

        // sign-extend all inputs to accumulator width
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] sx00 =
          {{BW_TENSOR_SCALAR_ACC_EXTRA{a00_u[BW_TENSOR_SCALAR-1]}}, a00_u};
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] sx01 =
          {{BW_TENSOR_SCALAR_ACC_EXTRA{a01_u[BW_TENSOR_SCALAR-1]}}, a01_u};
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] sx10 =
          {{BW_TENSOR_SCALAR_ACC_EXTRA{a10_u[BW_TENSOR_SCALAR-1]}}, a10_u};
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] sx11 =
          {{BW_TENSOR_SCALAR_ACC_EXTRA{a11_u[BW_TENSOR_SCALAR-1]}}, a11_u};

        // shared ALU control:
        //   do_sub  = 1 for max (subtract to compare via sign bit)
        //   is_pass = 1 for topleft (bypass ALU, pass left operand)
        wire do_sub  = opcode_max;
        wire is_pass = opcode_topleft;

        //----------------------------------------------------------
        // Stage 1, Node1: ALU(sx00, sx01)
        //   unified add/sub form: a + (sub ? ~b : b) + sub
        //   add mode  -> sx00 + sx01
        //   sub mode  -> sx00 - sx01 (sign bit selects max)
        //----------------------------------------------------------
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node1_alu =
          sx00 + (do_sub ? ~sx01 : sx01) + do_sub;
        wire node1_neg = node1_alu[BW_TENSOR_SCALAR_ACC-1];

        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node1 =
          is_pass ? sx00 :
          do_sub  ? (node1_neg ? sx01 : sx00) :
                    node1_alu;

        //----------------------------------------------------------
        // Stage 1, Node2: ALU(sx10, sx11)
        //----------------------------------------------------------
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node2_alu =
          sx10 + (do_sub ? ~sx11 : sx11) + do_sub;
        wire node2_neg = node2_alu[BW_TENSOR_SCALAR_ACC-1];

        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node2 =
          is_pass ? sx10 :
          do_sub  ? (node2_neg ? sx11 : sx10) :
                    node2_alu;

        //----------------------------------------------------------
        // Stage 2, Node3: ALU(Node1, Node2)
        //----------------------------------------------------------
        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node3_alu =
          node1 + (do_sub ? ~node2 : node2) + do_sub;
        wire node3_neg = node3_alu[BW_TENSOR_SCALAR_ACC-1];

        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node3 =
          is_pass ? node1 :
          do_sub  ? (node3_neg ? node2 : node1) :
                    node3_alu;

        //----------------------------------------------------------
        // Post-processing: avg only
        //   negative rounding correction (neg & rem) ? +3, then >>> 2
        //----------------------------------------------------------
        wire neg_node3 = node3[BW_TENSOR_SCALAR_ACC-1];
        wire has_rem   = |node3[1:0];

        wire signed [BW_TENSOR_SCALAR_ACC-1:0] node3_adj =
          (neg_node3 & has_rem) ? (node3 + 3) : node3;

        wire signed [BW_TENSOR_SCALAR_ACC-1:0] avgv = (node3_adj >>> 2);

        // output selection:
        //   avg    -> avgv truncated to BW_TENSOR_SCALAR
        //   others -> node3 truncated (topleft=a00, max=maxval, sum=sumval)
        wire signed [BW_TENSOR_SCALAR-1:0] out_calc =
          opcode_avg ? $signed(avgv[BW_TENSOR_SCALAR-1:0]) :
                       $signed(node3[BW_TENSOR_SCALAR-1:0]);

        wire [BW_TENSOR_SCALAR-1:0] out_u =
          wen ? out_calc[BW_TENSOR_SCALAR-1:0] : {BW_TENSOR_SCALAR{1'b0}};

        assign i_downsampler_output_matrix[OUT_BIT-:BW_TENSOR_SCALAR] = out_u;

      end
      else
      begin : gen_zero
        assign i_downsampler_output_matrix[OUT_BIT-:BW_TENSOR_SCALAR] = {BW_TENSOR_SCALAR{1'b0}};
      end

    end
  end
endgenerate

always@(*)
begin
  mreg2_all_wdata_list2d = i_downsampler_output_matrix;
end

assign busy = (state!=IDLE);

`ifdef SIM_ENV
`ifdef PRINT_DCA_MATRIX_CAL

integer m, n;

always@(negedge clk)
begin
  if(state==BUSY)
  begin
    $write("\n[DS_OUTPUT]");
    for(m=0; m<MATRIX_NUM_ROW; m=m+1)
    begin
      $write("\n");
      for(n=0; n<MATRIX_NUM_COL; n=n+1)
      begin
        $write(" %d", $signed(mreg2_all_wdata_list2d[GET_MATRIX_INDEX(m,n)-:BW_TENSOR_SCALAR]));
      end
    end
  end
end

`endif
`endif

endmodule


