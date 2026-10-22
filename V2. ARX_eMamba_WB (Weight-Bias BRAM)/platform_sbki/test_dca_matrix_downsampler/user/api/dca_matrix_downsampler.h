#ifndef __DCA_DOWNSAMPLER_H__
#define __DCA_DOWNSAMPLER_H__

#include "ervp_matrix_op.h"
#include "ervp_mmiox1.h"
#include "dca_module_ext_memorymap_offset.h"

static const int _DCA_DOWNSAMPLER_ALL_FROM_MEMORY = DCA_DOWNSAMPLER_OPCODE_LSU0_REQ | DCA_DOWNSAMPLER_OPCODE_LSU1_REQ;
static const int DCA_DOWNSAMPLER_TOPLEFT = DCA_DOWNSAMPLER_OPCODE_TOPLEFT | _DCA_DOWNSAMPLER_ALL_FROM_MEMORY;
static const int DCA_DOWNSAMPLER_MAX = DCA_DOWNSAMPLER_OPCODE_MAX | _DCA_DOWNSAMPLER_ALL_FROM_MEMORY;
static const int DCA_DOWNSAMPLER_AVG = DCA_DOWNSAMPLER_OPCODE_AVG | _DCA_DOWNSAMPLER_ALL_FROM_MEMORY;
static const int DCA_DOWNSAMPLER_SUM = DCA_DOWNSAMPLER_OPCODE_SUM | _DCA_DOWNSAMPLER_ALL_FROM_MEMORY;

static inline int dca_matrix_downsampler_get_opcode(unsigned int downsample_option_value)
{
  ervp_mdownsample_option_t downsample_option;
  downsample_option.value = downsample_option_value;

  int option;

  switch (downsample_option.br.downsample_mode)
  {
    case DOWNSAMPLE_TOPLEFT:
      option = DCA_DOWNSAMPLER_TOPLEFT; 
      break; 
    case DOWNSAMPLE_MAX:
      option = DCA_DOWNSAMPLER_MAX;
      break;
    case DOWNSAMPLE_AVERAGE:
      option = DCA_DOWNSAMPLER_AVG;
      break;
    case DOWNSAMPLE_SUM:
      option = DCA_DOWNSAMPLER_SUM;
      break;
    default:
      option = DOWNSAMPLE_NONE;
      break;
  }
  return option;
}

typedef struct
{
  unsigned int bw_addr;
  unsigned int ma_bw_data; // input
  unsigned int ma_has_burden;
  unsigned int ma_bw_burden;
  unsigned int mc_bw_data; // output
  unsigned int mc_has_burden;
  unsigned int mc_bw_burden;
  unsigned int matrix_size_para;
  unsigned int tensor_para;
  unsigned int bw_config;
  unsigned int bw_status;
  unsigned int bw_log;
  unsigned int bw_inst;
  unsigned int bw_input;
  unsigned int bw_output;
  unsigned int config_default_value; // invalid due to the limit of data type, but not used
  unsigned int log_fifo_depth;
  unsigned int inst_fifo_depth;
  unsigned int input_fifo_depth;
  unsigned int output_fifo_depth;
  unsigned int lsu_para;
} dca_matrix_downsampler_hwpara_t;

typedef struct
{
  const ervp_mmiox1_hwinfo_t *mmiox_info;
  unsigned int num_row : 16;
  unsigned int num_col : 16;
  uint32_t id;
} dca_matrix_downsampler_hwinfo_t;

void dca_matrix_downsampler_hwinfo_elaborate(dca_matrix_downsampler_hwpara_t *hwpara, dca_matrix_downsampler_hwinfo_t *hwinfo);

static inline ervp_hwtask_busy_fx_t dca_matrix_downsampler_busy_fx(const dca_matrix_downsampler_hwinfo_t *const hwinfo)
{
  return hwinfo->mmiox_info->busy_fx;
}

static inline void dca_matrix_downsampler_wait(const dca_matrix_downsampler_hwinfo_t *const hwinfo)
{
  hwtask_wait_complete(dca_matrix_downsampler_busy_fx(hwinfo));
}

ervp_hwtask_busy_fx_t dca_matrix_downsampler_start(ervp_mop_mapping_t *mop_mapping, const dca_matrix_downsampler_hwinfo_t *const hwinfo, int opcode, const ErvpMatrixInfo *ma_info, ErvpMatrixInfo *mc_info, unsigned int option_value);

static inline ervp_hwtask_busy_fx_t dca_matrix_downsampler(ervp_mop_mapping_t *mop_mapping, const dca_matrix_downsampler_hwinfo_t *const hwinfo, const ErvpMatrixInfo *ma_info, ErvpMatrixInfo *mc_info, unsigned int option_value)
{
  int downsample_option_value = dca_matrix_downsampler_get_opcode(option_value);
  return dca_matrix_downsampler_start(mop_mapping, hwinfo, downsample_option_value, ma_info, mc_info, option_value);
}

#endif