#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_printf_section.h"
#include "ervp_variable_allocation.h"
#include "ervp_special_matrix_op.h"
#include "ervp_matrix.h"
#include "ervp_matrix_op_sw.h"
#include "ervp_core_id.h"
#include "ervp_assert.h"

#include "test_matrix.h"
#include "map_your_matrix_hw.h"

// this app is modified from "verify_matrix_opt"

///////////////////////////////////////////////////////////////

#define DOWNSAMPLE_KERNEL_SIZE 2
#define DOWNSAMPLE_STRIDE 2

#define NUM_MATRIX 1
#define INPUT_MATRIX_SIZE 13
#define OUTPUT_MATRIX_SIZE (INPUT_MATRIX_SIZE / DOWNSAMPLE_KERNEL_SIZE)

#define VERIFY_DOWNSAMPLE_TOPLEFT 1
#define VERIFY_DOWNSAMPLE_MAX 1
#define VERIFY_DOWNSAMPLE_AVG 1
#define VERIFY_DOWNSAMPLE_SUM 1

#define MI_DATATYPE MATRIX_DATATYPE_SINT08
#define MO_DATATYPE MATRIX_DATATYPE_SINT08

#if (GET_NUM_BITS(MI_DATATYPE) == 32)
typedef uint32_t mi_type_t;
#elif (GET_NUM_BITS(MI_DATATYPE) == 16)
typedef uint16_t mi_type_t;
#else
typedef uint8_t mi_type_t;
#endif

#if (GET_NUM_BITS(MO_DATATYPE) == 32)
typedef uint32_t mo_type_t;
#elif (GET_NUM_BITS(MO_DATATYPE) == 16)
typedef uint16_t mo_type_t;
#else
typedef uint8_t mo_type_t;
#endif

#define SKIP_SIM 1

#define ALIGNED_MATRIX __attribute__((aligned(0x1000)))

mi_type_t input_array[NUM_MATRIX][INPUT_MATRIX_SIZE][INPUT_MATRIX_SIZE] BIG_DATA_BSS ALIGNED_MATRIX;
mo_type_t output_array[NUM_MATRIX][OUTPUT_MATRIX_SIZE][OUTPUT_MATRIX_SIZE] BIG_DATA_BSS ALIGNED_MATRIX;
mo_type_t ref_array[NUM_MATRIX][OUTPUT_MATRIX_SIZE][OUTPUT_MATRIX_SIZE] BIG_DATA_BSS ALIGNED_MATRIX;

ErvpMatrixInfo *input_info = NULL;
ErvpMatrixInfo *output_info = NULL;
ErvpMatrixInfo *ref_info = NULL;

void matrix_info_init()
{
  input_info = matrix_generate_info(MI_DATATYPE, INPUT_MATRIX_SIZE, INPUT_MATRIX_SIZE, NULL, NULL);
  output_info = matrix_generate_info(MO_DATATYPE, OUTPUT_MATRIX_SIZE, OUTPUT_MATRIX_SIZE, NULL, NULL);
  ref_info = matrix_generate_info(MO_DATATYPE, OUTPUT_MATRIX_SIZE, OUTPUT_MATRIX_SIZE, NULL, NULL);
}

void matrix_info_setup(int index)
{ 
  input_info->addr = (void *)(input_array[index]);
  output_info->addr = (void *)(output_array[index]);
  ref_info->addr = (void *)(ref_array[index]);
}

int main()
{
  if (EXCLUSIVE_ID == 0)
  {
    ervp_hwtask_busy_fx_t hwtask_busy_fx;
    ervp_mop_mapping_t *mop_mapping = matrix_op_mapping_alloc();
    map_your_matrix_function(mop_mapping);
    matrix_info_init();

    // init matrices
    for (int i = 0; i < NUM_MATRIX; i = i + 1)
    {
      matrix_info_setup(i);
      generate_test_matrix(input_info, i);
    }
    flush_cache();

    ervp_mdownsample_option_t downsample_option;
    downsample_option.value = 0;
    downsample_option.br.stride_m1 = DOWNSAMPLE_STRIDE - 1; // turn on postprocess 

    //
    if (VERIFY_DOWNSAMPLE_TOPLEFT)
    { 
      printf_section(SKIP_SIM, "%s_DOWNSAMPLE_TOPLEFT", matrix_hw_name);
      downsample_option.br.downsample_mode = DOWNSAMPLE_TOPLEFT;
      for (int i = 0; i < NUM_MATRIX; i = i + 1)      {
        flush_cache();
        matrix_info_setup(i);
        matrix_downsample_sw(input_info, ref_info, downsample_option.value);
        hwtask_busy_fx = mop_mapping->matrix_downsample(mop_mapping, input_info, output_info, downsample_option.value);
        hwtask_wait_complete(hwtask_busy_fx);
        int all_are_equal = matrix_compare(output_info, ref_info, 1);
        if (!all_are_equal)
        {
          matrix_print(input_info);
          matrix_print(output_info);
          matrix_print(ref_info);
          assert(0);
          break;
        }
      }
    }

    //
    if (VERIFY_DOWNSAMPLE_MAX)
    {
      printf_section(SKIP_SIM, "%s_DOWNSAMPLE_MAX", matrix_hw_name);
      downsample_option.br.downsample_mode = DOWNSAMPLE_MAX;
      for (int i = 0; i < NUM_MATRIX; i = i + 1)
      {
        flush_cache();
        matrix_info_setup(i);
        matrix_downsample_sw(input_info, ref_info, downsample_option.value);
        hwtask_busy_fx = mop_mapping->matrix_downsample(mop_mapping, input_info, output_info, downsample_option.value);
        hwtask_wait_complete(hwtask_busy_fx);
        int all_are_equal = matrix_compare(output_info, ref_info, 1);
        if (!all_are_equal)
        {
          matrix_print(input_info);
          matrix_print(output_info);
          matrix_print(ref_info);
          assert(0);
          break;
        }
      }
    }

    //
    if (VERIFY_DOWNSAMPLE_AVG)
    {
      printf_section(SKIP_SIM, "%s_DOWNSAMPLE_AVG", matrix_hw_name);
      downsample_option.br.downsample_mode = DOWNSAMPLE_AVERAGE;
      for (int i = 0; i < NUM_MATRIX; i = i + 1)
      {
        flush_cache();
        matrix_info_setup(i);
        matrix_downsample_sw(input_info, ref_info, downsample_option.value);
        hwtask_busy_fx = mop_mapping->matrix_downsample(mop_mapping, input_info, output_info, downsample_option.value);
        hwtask_wait_complete(hwtask_busy_fx);
        int all_are_equal = matrix_compare(output_info, ref_info, 1);
        if (!all_are_equal)
        {
          matrix_print(input_info);
          matrix_print(output_info);
          matrix_print(ref_info);
          assert(0);
          break;
        }
      }
    }

    //
    if (VERIFY_DOWNSAMPLE_SUM)
    {
      printf_section(SKIP_SIM, "%s_DOWNSAMPLE_SUM", matrix_hw_name);
      downsample_option.br.downsample_mode = DOWNSAMPLE_SUM;
      for (int i = 0; i < NUM_MATRIX; i = i + 1)
      {
        flush_cache();
        matrix_info_setup(i);
        matrix_downsample_sw(input_info, ref_info, downsample_option.value);  
        hwtask_busy_fx = mop_mapping->matrix_downsample(mop_mapping, input_info, output_info, downsample_option.value);
        hwtask_wait_complete(hwtask_busy_fx);
        int all_are_equal = matrix_compare(output_info, ref_info, 1);
        if (!all_are_equal)
        {
          matrix_print(input_info);
          matrix_print(output_info);
          matrix_print(ref_info);
          assert(0);
          break;
        }
      }
    }

    flush_cache();
  }
  return 0;
}

