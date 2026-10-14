#include "platform_info.h"
#include "ervp_assert.h"
#include "ervp_printf.h"
#include "ervp_blocked_matrix_op.h"

#include "ip_instance_info.h"
#include "dca_matrix_downsampler.h"

#include "map_your_matrix_hw.h"

const char matrix_hw_name[] = "DCA";

ervp_hwtask_busy_fx_t i_dca_matrix_downsampler00(ervp_mop_mapping_t *mop_mapping, const ErvpMatrixInfo *ma_info, ErvpMatrixInfo *mc_info, unsigned int option_value)
{
  return dca_matrix_downsampler(mop_mapping, i_dca_matrix_downsampler00_info, ma_info, mc_info, option_value);
}

void map_your_matrix_function(ervp_mop_mapping_t* mop_mapping)
{
  /* map your own functions */
  mop_mapping->matrix_downsample = i_dca_matrix_downsampler00;
}
