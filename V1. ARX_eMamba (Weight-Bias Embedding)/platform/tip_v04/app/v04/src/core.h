#ifndef __CORE_H__
#define __CORE_H__

#include <stdint.h>

#include "config.h"


#define NUM_BATCH  1
#define NUM_CHANNELS  5
#define NUM_HEIGHT  8
#define NUM_WIDTH  8
#define PATCH1  2
#define PATCH2  2
#define NUM_SEQLEN  16
#define NUM_DIM  20
#define NUM_ED  40
#define NUM_TEMP  48
#define NUM_N  8
#define NUM_DELTA  32
#define NUM_CLASS  57


/*
 * Activations propagate through main as int8_t (every value handed back to
 * main is cap_int8 / clamped to [-128,127]). Kernels read int8 at the
 * boundary, keep all wide arithmetic in local int/long long scratch, and fuse
 * the output shift (exp_dOut) + saturation into the per-element int8 store, so
 * no buffer ever holds an out-of-range intermediate.
 *
 * Weights/biases remain `const int8_t` header arrays, scaled on the fly.
 * Every exp_* / scale_* parameter is kept even when it is currently 0.
 */

/* scalar scale/shift helpers (defined in base.c) */
long long shift_value_ll(long long value, int exp);
int64_t scale_value_i64(int64_t value, int exp);
int scale_value_int(int value, int exp);


void Patch_Rearrange(
    const int8_t fp_dIn[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH],
    int8_t dOut[NUM_SEQLEN][NUM_DIM]
);
void Patch_Linear(
    int N,
    int K,
    int M,
    const int8_t fp_dIn[N][K],
    const int8_t fp_weight[M][K],
    const int8_t fp_bias[M],
    int8_t dOut[N][M],
    int scale_dIn,
    int scale_weight,
    int scale_bias,
    int scale_dOut
);
void LightNorm(
    int N,
    int K,
    int M,
    const int8_t fp_dIn[N][K],
    const int8_t fp_weight[M],
    const int8_t fp_bias[M],
    int8_t dOut[N][M],
    int exp_dIn,
    int exp_weight,
    int exp_bias,
    int exp_dOut
);
void Linear_expand(
    int N,
    int K,
    int M,
    const int8_t fp_dIn[N][K],
    const int8_t fp_weight[M][K],
    const int8_t fp_bias[M],
    int8_t dOut[N][M],
    int exp_dIn,
    int exp_weight,
    int exp_bias,
    int exp_dOut
);
void SiLU_piecewise(
    int N,
    int M,
    const int8_t fp_dIn[N][M],
    int8_t dOut[N][M],
    int exp_dIn,
    int exp_dOut,
    int scale_dIn
);
void Rearrange(
    int N,
    int M,
    const int8_t fp_dIn[N][M],
    int8_t dOut[M][N]
);
void Conv1D(
    int OUT_CH,
    int IN_CH,
    int SEQ_LEN,
    const int8_t fp_dIn[IN_CH][SEQ_LEN],
    const int8_t fp_weight[OUT_CH][IN_CH][1],
    const int8_t fp_bias[OUT_CH],
    int8_t dOut[OUT_CH][SEQ_LEN],
    int exp_dIn,
    int exp_weight,
    int exp_bias,
    int exp_dOut
);
void SSM_pre_Linear_dBC(
    const int8_t fp_dIn[NUM_SEQLEN][NUM_ED],
    const int8_t fp_weight[NUM_TEMP][NUM_ED],
    int8_t delta[NUM_SEQLEN][NUM_DELTA],
    int8_t B[NUM_SEQLEN][NUM_N],
    int8_t C[NUM_SEQLEN][NUM_N],
    int exp_dIn,
    int exp_weight,
    int exp_dOut,
    int exp_delta,
    int exp_B,
    int exp_C
);
void SSM_pre_Linear_delta(
    const int8_t fp_dIn[NUM_SEQLEN][NUM_DELTA],
    const int8_t fp_weight[NUM_ED][NUM_DELTA],
    const int8_t fp_bias[NUM_ED],
    int8_t dOut[NUM_SEQLEN][NUM_ED],
    int exp_dIn,
    int exp_weight,
    int exp_bias,
    int exp_dOut
);
void SSM_pre_ReLU(
    int N,
    int M,
    const int8_t fp_dIn[N][M],
    int8_t dOut[N][M]
);
void SSM_pre_deltaA(
    const int8_t fp_delta[NUM_SEQLEN][NUM_ED],
    const int8_t fp_A[NUM_ED][NUM_N],
    int8_t dOut[NUM_SEQLEN][NUM_ED][NUM_N],
    int exp_dIn,
    int exp_A,
    int exp_dOut,
    int scale_delta,
    int scale_A
);
void SSM_pre_deltaB(
    const int8_t fp_delta[NUM_SEQLEN][NUM_ED],
    const int8_t fp_B[NUM_SEQLEN][NUM_N],
    int8_t dOut[NUM_SEQLEN][NUM_ED][NUM_N],
    int exp_dOut
);
void SSM_computation(
    const int8_t fp_dIn[NUM_SEQLEN][NUM_ED],
    const int8_t fp_deltaA[NUM_SEQLEN][NUM_ED][NUM_N],
    const int8_t fp_deltaB[NUM_SEQLEN][NUM_ED][NUM_N],
    const int8_t fp_C[NUM_SEQLEN][NUM_N],
    const int8_t fp_D[NUM_ED],
    int8_t dOut[NUM_SEQLEN][NUM_ED],
    int scale_dIn,
    int scale_deltaA,
    int scale_deltaB,
    int scale_C,
    int scale_D,
    int scale_dOut
);
void Elementwise_Product(
    int N,
    int M,
    const int8_t fp_dIn1[N][M],
    const int8_t fp_dIn2[N][M],
    int8_t dOut[N][M],
    int exp_dIn1,
    int exp_dIn2,
    int exp_dOut
);
void Linear_contract(
    int N,
    int K,
    int M,
    const int8_t fp_dIn[N][K],
    const int8_t fp_weight[M][K],
    const int8_t fp_bias[M],
    int8_t dOut[N][M],
    int exp_dIn,
    int exp_weight,
    int exp_bias,
    int exp_dOut
);
void Elementwise_Add(
    int N,
    int M,
    const int8_t fp_dIn1[N][M],
    const int8_t fp_dIn2[N][M],
    int8_t dOut[N][M],
    int exp_dIn1,
    int exp_dIn2,
    int exp_dOut
);
void compare_int_2D(
    const char *name,
    int rows,
    int cols,
    const int8_t actual[rows][cols],
    const int8_t expected[rows][cols]
);
// void compare_int_3D(
//     const char *name,
//     int dim0,
//     int dim1,
//     int dim2,
//     const int8_t actual[dim0][dim1][dim2],
//     const int8_t expected[dim0][dim1][dim2]
// );
#endif