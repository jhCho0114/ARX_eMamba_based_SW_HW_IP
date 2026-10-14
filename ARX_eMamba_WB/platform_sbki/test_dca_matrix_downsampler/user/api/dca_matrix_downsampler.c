#include "ervp_mmiox1.h"
#include "ervp_printf.h"
#include "ervp_caching.h"
#include "ervp_delay.h"
#include "ervp_matrix_op_sw.h"

#include "dca_matrix_info.h"
#include "dca_matrix_downsampler.h"

typedef struct
{
	dca_matrix_info_t ma;
	dca_matrix_info_t mc;
	uint32_t opcode;
} dca_matrix_downsampler_inst_t;

static UNKNOWN_TYPE scalar_matrix_value;
static ErvpMatrixInfo scalar_matrix_info;

static void __attribute__((constructor)) construct_dca_neugemm()
{
	matrix_generate_info(MATRIX_DATATYPE_SINT32, 1, 1, &scalar_matrix_value, &scalar_matrix_info);
}

void dca_matrix_downsampler_hwinfo_elaborate(dca_matrix_downsampler_hwpara_t *hwpara, dca_matrix_downsampler_hwinfo_t *hwinfo)
{
	static int id_to_issue = 0;
	hwinfo->num_col = hwpara->matrix_size_para % 10000;
	hwinfo->num_row = (hwpara->matrix_size_para / 10000) % 10000;
	if (hwinfo->num_row == 0)
		hwinfo->num_row = hwinfo->num_col;
	hwinfo->id = id_to_issue++;
}

static void _dca_matrix_downsampler_request(const dca_matrix_downsampler_hwinfo_t *const hwinfo, int opcode, const ErvpMatrixInfo *ma_info, ErvpMatrixInfo *mc_info)
{
	dca_matrix_downsampler_inst_t inst;

	inst.opcode = opcode;
	dca_matrix_info_generate(ma_info, &(inst.ma));
	dca_matrix_info_generate(mc_info, &(inst.mc));

	// dca_matrix_downsampler_wait(hwinfo); // DO NOT remove even if not used
	mmiox1_inst_push(hwinfo->mmiox_info, &inst, 1, 0);
}

ervp_hwtask_busy_fx_t dca_matrix_downsampler_start(ervp_mop_mapping_t *mop_mapping, const dca_matrix_downsampler_hwinfo_t *const hwinfo, int opcode, const ErvpMatrixInfo *ma_info, ErvpMatrixInfo *mc_info, unsigned int option_value)
{
	ervp_mop_option_t mop_option;
	mop_option.value = option_value;

	ervp_hwtask_busy_fx_t hwtask_busy_fx = NULL;
	/*
	if (mop_option_has_postprocess(option_value))
	{
		const int stride = mop_option.br.stride_m1 + 1;
		ErvpMatrixInfo *temp = matrix_alloc(MATRIX_DATATYPE_SINT32, mc_info->num_row * stride, mc_info->num_col * stride, NULL);
		cache_flush_smart(2, ma_info->addr, mc_info->addr);
		_dca_matrix_downsampler_request(hwinfo, opcode, ma_info, temp);
		dca_matrix_downsampler_wait(hwinfo);
		task_wait_fx = matrix_perform_postprocess_tf(mop_mapping, temp, mc_info, option_value);
		task_wait_finish(task_wait_fx);
		matrix_free(temp);
	}
	else
	*/

		cache_flush_smart(2, ma_info->addr, mc_info->addr);
		_dca_matrix_downsampler_request(hwinfo, opcode, ma_info, mc_info);
		hwtask_busy_fx = dca_matrix_downsampler_busy_fx(hwinfo);
	
	return hwtask_busy_fx;
}