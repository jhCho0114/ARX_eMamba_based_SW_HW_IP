#include "core.h"
#include "base.h"

/* RVX: replace unavailable libc. */
#include "ervp_printf.h"        /* printf */
#include "ervp_platform_api.h"  /* exit   */
#include <stdint.h>
#include <limits.h>

static double rvx_floor(double x)
{
    long long i = (long long)x;
    if ((double)i > x) i -= 1;
    return (double)i;
}
static double rvx_sqrt(double v)
{
    if (v <= 0.0) return 0.0;
    double g = v;
    for (int i = 0; i < 60; i++) g = 0.5 * (g + v / g);
    return g;
}

/*
 * All activation buffers are int8_t. Wide intermediates live only in local
 * scalars; the output shift (exp_dOut) and int8 saturation are fused into the
 * per-element store. Input scaling (exp_dIn) and weight scaling (exp_weight)
 * are applied on the fly at the moment of use.
 */

/* int8 saturating store helper */
static inline int8_t cap8(long long v)
{
    if (v > 127)
        return 127;
    if (v < -128)
        return -128;
    return (int8_t)v;
}

void Patch_Rearrange(
    const int8_t fp_dIn[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH],
    int8_t dOut[NUM_SEQLEN][NUM_DIM]
)
{
    for (int h = 0; h < NUM_HEIGHT / PATCH1; h++)
        for (int w = 0; w < NUM_WIDTH / PATCH2; w++)
            for (int ph = 0; ph < PATCH1; ph++)
                for (int pw = 0; pw < PATCH2; pw++)
                    for (int c = 0; c < NUM_CHANNELS; c++)
                        dOut[h * (NUM_WIDTH / PATCH2) + w][(PATCH2 * ph + pw) * NUM_CHANNELS + c]
                            = fp_dIn[c][PATCH1 * h + ph][PATCH2 * w + pw];
}

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
)
{
    int exp_bias = scale_dIn + scale_weight - scale_bias;
    int exp_dOut = -(scale_dIn + scale_weight - scale_dOut);

    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            int sum = 0;

            for (int k = 0; k < K; k++)
            {
                /* weight kept at native int8 scale (folded into exp_bias/exp_dOut) */
                sum += (int)fp_dIn[n][k] * (int)fp_weight[m][k];
            }

            int acc = sum + scale_value_int((int)fp_bias[m], exp_bias);
            dOut[n][m] = cap8((long long)scale_value_int(acc, exp_dOut));
        }
    }
}

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
)
{

    if (K != M)
    {
        printf("LightNorm error: K and M must be same. K=%d, M=%d\n", K, M);
        return;
    }

    for (int n = 0; n < N; n++)
    {
        int sum = 0;

        for (int k = 0; k < K; k++)
        {
            sum += scale_value_int((int)fp_dIn[n][k], exp_dIn);
        }

        int dIn_mean = sum / K;

        int first_diff = scale_value_int((int)fp_dIn[n][0], exp_dIn) - dIn_mean;
        int max_diff = first_diff;
        int min_diff = first_diff;

        for (int k = 0; k < K; k++)
        {
            int diff = scale_value_int((int)fp_dIn[n][k], exp_dIn) - dIn_mean;

            if (diff > max_diff)
                max_diff = diff;

            if (diff < min_diff)
                min_diff = diff;
        }

        int dIn_range = max_diff - min_diff;

        for (int m = 0; m < M; m++)
        {
            int w = scale_value_int((int)fp_weight[m], exp_weight);
            int din = scale_value_int((int)fp_dIn[n][m], exp_dIn);

            int norm_n = w * (din - dIn_mean) * 25;
            int norm_d = dIn_range;

            norm_n >>= 5;
            norm_d >>= 5;

            int norm;

            if (norm_d == 0)
            {
                norm = norm_n;
            }
            else
            {
                if (norm_n > 0)
                {
                    norm = norm_n / norm_d;
                }
                else
                {
                    norm = -((-norm_n) / norm_d);
                }
            }

            int acc = norm + scale_value_int((int)fp_bias[m], exp_bias);
            dOut[n][m] = cap8((long long)scale_value_int(acc, exp_dOut));
        }
    }
}

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
)
{
    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            int sum = 0;

            for (int k = 0; k < K; k++)
            {
                sum += scale_value_int((int)fp_dIn[n][k], exp_dIn)
                     * scale_value_int((int)fp_weight[m][k], exp_weight);
            }

            int acc = sum + scale_value_int((int)fp_bias[m], exp_bias);
            dOut[n][m] = cap8((long long)scale_value_int(acc, exp_dOut));
        }
    }
}

// #define INT_MAX 2147483647
// #define INT_MIN -2147483648

int round_to_int(double x)
{
    double lower = rvx_floor(x);
    double fraction = x - lower;
    double rounded;

    if (fraction < 0.5)
    {
        rounded = lower;
    }
    else if (fraction > 0.5)
    {
        rounded = lower + 1.0;
    }
    else
    {
        int64_t lower_int = (int64_t)lower;

        if ((lower_int % 2) == 0)
        {
            rounded = lower;
        }
        else
        {
            rounded = lower + 1.0;
        }
    }

    if (rounded > INT_MAX || rounded < INT_MIN)
    {
        printf( "round_to_int: out of range\n");
        exit(1);
    }

    return (int)rounded;
}


void SiLU_piecewise(
    int N,
    int M,
    const int8_t fp_dIn[N][M],
    int8_t dOut[N][M],
    int exp_dIn,
    int exp_dOut,
    int scale_dIn
)
{
    int SCALE_DIN = 1 << scale_dIn;
    int SCALE_DIN_2 = SCALE_DIN * SCALE_DIN;

    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            int x = scale_value_int((int)fp_dIn[n][m], exp_dIn);
            int y;

            if (x < round_to_int(-7.000 * SCALE_DIN))
            {
                y = 0;
            }
            else if (x < round_to_int(-6.417 * SCALE_DIN))
            {
                y = round_to_int(-0.007 * SCALE_DIN) * x
                    - round_to_int(0.055 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-5.821 * SCALE_DIN))
            {
                y = round_to_int(-0.011 * SCALE_DIN) * x
                    - round_to_int(0.083 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-5.205 * SCALE_DIN))
            {
                y = round_to_int(-0.018 * SCALE_DIN) * x
                    - round_to_int(0.123 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-4.560 * SCALE_DIN))
            {
                y = round_to_int(-0.029 * SCALE_DIN) * x
                    - round_to_int(0.180 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-3.862 * SCALE_DIN))
            {
                y = round_to_int(-0.046 * SCALE_DIN) * x
                    - round_to_int(0.258 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-3.033 * SCALE_DIN))
            {
                y = round_to_int(-0.072 * SCALE_DIN) * x
                    - round_to_int(0.358 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-1.547 * SCALE_DIN))
            {
                y = round_to_int(-0.089 * SCALE_DIN) * x
                    - round_to_int(0.409 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-0.998 * SCALE_DIN))
            {
                y = round_to_int(0.005 * SCALE_DIN) * x
                    - round_to_int(0.265 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-0.594 * SCALE_DIN))
            {
                y = round_to_int(0.142 * SCALE_DIN) * x
                    - round_to_int(0.127 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-0.294 * SCALE_DIN))
            {
                y = round_to_int(0.287 * SCALE_DIN) * x
                    - round_to_int(0.041 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-0.093 * SCALE_DIN))
            {
                y = round_to_int(0.406 * SCALE_DIN) * x
                    - round_to_int(0.006 * SCALE_DIN_2);
            }
            else if (x < round_to_int(-0.004 * SCALE_DIN))
            {
                y = round_to_int(0.476 * SCALE_DIN) * x;
            }
            else if (x < round_to_int(0.004 * SCALE_DIN))
            {
                y = round_to_int(0.500 * SCALE_DIN) * x;
            }
            else if (x < round_to_int(0.098 * SCALE_DIN))
            {
                y = round_to_int(0.526 * SCALE_DIN) * x;
            }
            else if (x < round_to_int(0.327 * SCALE_DIN))
            {
                y = round_to_int(0.605 * SCALE_DIN) * x
                    - round_to_int(0.008 * SCALE_DIN_2);
            }
            else if (x < round_to_int(1.085 * SCALE_DIN))
            {
                y = round_to_int(0.856 * SCALE_DIN) * x
                    - round_to_int(0.117 * SCALE_DIN_2);
            }
            else if (x < round_to_int(7.000 * SCALE_DIN))
            {
                y = round_to_int(1.045 * SCALE_DIN) * x
                    - round_to_int(0.324 * SCALE_DIN_2);
            }
            else
            {
                y = x * SCALE_DIN;
            }

            dOut[n][m] = cap8((long long)scale_value_int(y, exp_dOut));
        }
    }
}


void Rearrange(
    int N,
    int M,
    const int8_t fp_dIn[N][M],
    int8_t dOut[M][N]
)
{
    for (int m = 0; m < M; m++)
    {
        for (int n = 0; n < N; n++)
        {
            dOut[m][n] = fp_dIn[n][m];
        }
    }
}
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
)
{
    for (int d = 0; d < OUT_CH; d++)
    {
        for (int s = 0; s < SEQ_LEN; s++)
        {
            int sum = 0;

            for (int i = 0; i < IN_CH; i++)
            {
                sum += scale_value_int((int)fp_dIn[i][s], exp_dIn)
                     * scale_value_int((int)fp_weight[d][i][0], exp_weight);
            }

            int acc = sum + scale_value_int((int)fp_bias[d], exp_bias);
            dOut[d][s] = cap8((long long)scale_value_int(acc, exp_dOut));
        }
    }
}

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
)
{
    /* No [NUM_SEQLEN][NUM_TEMP] scratch buffer: each MAC result is shifted by
     * exp_dOut, then routed and shifted again (exp_delta/exp_B/exp_C) directly
     * into the int8 outputs — two-step rounding identical to the original. */
    for (int s = 0; s < NUM_SEQLEN; s++)
    {
        for (int t = 0; t < NUM_TEMP; t++)
        {
            int sum = 0;

            for (int i = 0; i < NUM_ED; i++)
            {
                sum += scale_value_int((int)fp_dIn[s][i], exp_dIn)
                     * scale_value_int((int)fp_weight[t][i], exp_weight);
            }

            int v = scale_value_int(sum, exp_dOut);

            if (t < NUM_DELTA)
            {
                delta[s][t] = cap8((long long)scale_value_int(v, exp_delta));
            }
            else if (t < NUM_DELTA + NUM_N)
            {
                B[s][t - NUM_DELTA] = cap8((long long)scale_value_int(v, exp_B));
            }
            else
            {
                C[s][t - NUM_DELTA - NUM_N] = cap8((long long)scale_value_int(v, exp_C));
            }
        }
    }
}

void SSM_pre_Linear_delta(
    const int8_t fp_dIn[NUM_SEQLEN][NUM_DELTA],
    const int8_t fp_weight[NUM_ED][NUM_DELTA],
    const int8_t fp_bias[NUM_ED],
    int8_t dOut[NUM_SEQLEN][NUM_ED],
    int exp_dIn,
    int exp_weight,
    int exp_bias,
    int exp_dOut
)
{
    for (int s = 0; s < NUM_SEQLEN; s++)
    {
        for (int ed = 0; ed < NUM_ED; ed++)
        {
            int sum = 0;

            for (int n = 0; n < NUM_DELTA; n++)
            {
                sum += scale_value_int((int)fp_dIn[s][n], exp_dIn)
                     * scale_value_int((int)fp_weight[ed][n], exp_weight);
            }

            int acc = sum + scale_value_int((int)fp_bias[ed], exp_bias);
            dOut[s][ed] = cap8((long long)scale_value_int(acc, exp_dOut));
        }
    }
}

void SSM_pre_ReLU(
    int N,
    int M,
    const int8_t fp_dIn[N][M],
    int8_t dOut[N][M]
)
{
    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            if (fp_dIn[n][m] < 0)
                dOut[n][m] = 0;
            else
                dOut[n][m] = fp_dIn[n][m];
        }
    }
}
void SSM_pre_deltaA(
    const int8_t fp_delta[NUM_SEQLEN][NUM_ED],
    const int8_t fp_A[NUM_ED][NUM_N],
    int8_t dOut[NUM_SEQLEN][NUM_ED][NUM_N],
    int exp_dIn,
    int exp_A,
    int exp_dOut,
    int scale_delta,
    int scale_A
)
{
    int scale_sum = scale_delta + scale_A;

    int SCALE_DELTA_A = 1 << scale_sum;
    int SCALE_DELTA_A_2 = SCALE_DELTA_A * SCALE_DELTA_A;

    for (int l = 0; l < NUM_SEQLEN; l++)
    {
        for (int ed = 0; ed < NUM_ED; ed++)
        {
            for (int n = 0; n < NUM_N; n++)
            {
                int deltaA = scale_value_int((int)fp_delta[l][ed], exp_dIn)
                           * scale_value_int((int)fp_A[ed][n], exp_A);
                int y;

                if (deltaA < round_to_int(-4.000 * SCALE_DELTA_A))
                {
                    y = 0;
                }
                else if (deltaA <= round_to_int(-3.513 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.024 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.113 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-3.026 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.038 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.165 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-2.539 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.063 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.238 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-2.052 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.102 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.337 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-1.565 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.166 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.468 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-1.077 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.270 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.631 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-0.590 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.439 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.813 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(-0.103 * SCALE_DELTA_A))
                {
                    y = round_to_int(0.714 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.976 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(0.384 * SCALE_DELTA_A))
                {
                    y = round_to_int(1.162 * SCALE_DELTA_A) * deltaA
                        + round_to_int(1.022 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(0.871 * SCALE_DELTA_A))
                {
                    y = round_to_int(1.891 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.742 * SCALE_DELTA_A_2);
                }
                else if (deltaA <= round_to_int(1.000 * SCALE_DELTA_A))
                {
                    y = round_to_int(2.550 * SCALE_DELTA_A) * deltaA
                        + round_to_int(0.160 * SCALE_DELTA_A_2);
                }
                else
                {
                    y = round_to_int(2.718 * SCALE_DELTA_A) * SCALE_DELTA_A;
                }

                dOut[l][ed][n] = cap8((long long)scale_value_int(y, exp_dOut));
            }
        }
    }
}

void SSM_pre_deltaB(
    const int8_t fp_delta[NUM_SEQLEN][NUM_ED],
    const int8_t fp_B[NUM_SEQLEN][NUM_N],
    int8_t dOut[NUM_SEQLEN][NUM_ED][NUM_N],
    int exp_dOut
)
{
    for (int l = 0; l < NUM_SEQLEN; l++)
    {
        for (int ed = 0; ed < NUM_ED; ed++)
        {
            for (int n = 0; n < NUM_N; n++)
            {
                int prod = (int)fp_delta[l][ed] * (int)fp_B[l][n];
                dOut[l][ed][n] = cap8((long long)scale_value_int(prod, exp_dOut));
            }
        }
    }
}
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
)
{
    int scale_xP1 = scale_deltaB + scale_dIn;

    long long x_state[NUM_ED][NUM_N];

    for (int ed = 0; ed < NUM_ED; ed++)
    {
        for (int n = 0; n < NUM_N; n++)
        {
            x_state[ed][n] = 0;
        }
    }

    for (int l = 0; l < NUM_SEQLEN; l++)
    {
        for (int ed = 0; ed < NUM_ED; ed++)
        {
            long long CxkP1 = 0;

            for (int n = 0; n < NUM_N; n++)
            {
                long long Ax;
                long long Bu;

                if (l == 0)
                {
                    Ax = 0;
                }
                else
                {
                    Ax = (long long)(int)fp_deltaA[l][ed][n] * x_state[ed][n];
                }

                Bu = (long long)(int)fp_deltaB[l][ed][n] * (int)fp_dIn[l][ed];

                if (scale_deltaA > 0)
                {
                    Bu = shift_value_ll(Bu, scale_deltaA);
                }
                else if (scale_deltaA < 0)
                {
                    Ax = shift_value_ll(Ax, scale_deltaA);
                }

                long long x_raw = Ax + Bu;

                CxkP1 += (long long)(int)fp_C[l][n] * x_raw;

                x_state[ed][n] = shift_value_ll(x_raw, -scale_deltaA);
            }

            /* D is read straight from the int8 header (native scale). */
            long long Du = (long long)(int)fp_D[ed] * (int)fp_dIn[l][ed];

            int scale_Cx = scale_C + scale_deltaA + scale_xP1;
            int scale_Du = scale_D + scale_dIn;

            int scale_diff = scale_Cx - scale_Du;

            if (scale_diff > 0)
            {
                Du = shift_value_ll(Du, scale_diff);
            }
            else if (scale_diff < 0)
            {
                CxkP1 = shift_value_ll(CxkP1, -scale_diff);
                scale_Cx = scale_Du;
            }

            long long y = CxkP1 + Du;

            int final_shift = -(scale_Cx - scale_dOut);
            y = shift_value_ll(y, final_shift);

            dOut[l][ed] = cap8(y);
        }
    }
}


void Elementwise_Product(
    int N,
    int M,
    const int8_t fp_dIn1[N][M],
    const int8_t fp_dIn2[N][M],
    int8_t dOut[N][M],
    int exp_dIn1,
    int exp_dIn2,
    int exp_dOut
)
{
    for (int l = 0; l < N; l++)
    {
        for (int ed = 0; ed < M; ed++)
        {
            int a = scale_value_int((int)fp_dIn1[l][ed], exp_dIn1);
            int b = scale_value_int((int)fp_dIn2[l][ed], exp_dIn2);
            dOut[l][ed] = cap8((long long)scale_value_int(a * b, exp_dOut));
        }
    }
}
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
)
{
    for (int s = 0; s < N; s++)
    {
        for (int d = 0; d < M; d++)
        {
            int sum = 0;

            for (int i = 0; i < K; i++)
            {
                sum += scale_value_int((int)fp_dIn[s][i], exp_dIn)
                     * scale_value_int((int)fp_weight[d][i], exp_weight);
            }

            int acc = sum + scale_value_int((int)fp_bias[d], exp_bias);
            dOut[s][d] = cap8((long long)scale_value_int(acc, exp_dOut));
        }
    }
}
void Elementwise_Add(
    int N,
    int M,
    const int8_t fp_dIn1[N][M],
    const int8_t fp_dIn2[N][M],
    int8_t dOut[N][M],
    int exp_dIn1,
    int exp_dIn2,
    int exp_dOut
)
{
    for (int l = 0; l < N; l++)
    {
        for (int d = 0; d < M; d++)
        {
            int a = scale_value_int((int)fp_dIn1[l][d], exp_dIn1);
            int b = scale_value_int((int)fp_dIn2[l][d], exp_dIn2);
            dOut[l][d] = cap8((long long)scale_value_int(a + b, exp_dOut));
        }
    }
}

void compare_int_2D(
    const char *name,
    int rows,
    int cols,
    const int8_t actual[rows][cols],
    const int8_t expected[rows][cols]
)
{
    int total = rows * cols;

    int exact_count = 0;
    int within_1_count = 0;
    int within_2_count = 0;

    int sum_abs_error = 0;
    int sum_squared_error = 0;
    int sum_signed_error = 0;

    int max_abs_error = -1;
    int max_error_row = 0;
    int max_error_col = 0;

    for (int i = 0; i < rows; i++)
    {
        for (int j = 0; j < cols; j++)
        {
            int diff = actual[i][j] - expected[i][j];

            int abs_diff = diff < 0 ? -diff : diff;

            if (abs_diff == 0)
                exact_count++;

            if (abs_diff <= 1)
                within_1_count++;

            if (abs_diff <= 2)
                within_2_count++;

            sum_abs_error += abs_diff;
            sum_squared_error += diff * diff;
            sum_signed_error += diff;

            if (abs_diff > max_abs_error)
            {
                max_abs_error = abs_diff;
                max_error_row = i;
                max_error_col = j;
            }
        }
    }

    printf("\n============================================================\n");
    printf("Comparison: %s\n", name);
    printf("Shape: [%d][%d]\n", rows, cols);
    printf("Total values: %d\n", total);
    printf("Exact match: %d / %d \n",
           exact_count, total);
    printf("Mismatch rate: %d\n", (total - exact_count) / total);
    printf("|error| <= 1: %d / %d\n",
           within_1_count, total );
    printf("|error| <= 2: %d / %d \n",
           within_2_count, total);
  
    printf("Max absolute error: %d at [%d][%d]\n",
           max_abs_error, max_error_row, max_error_col);
    printf("Actual: %d, Expected: %d\n",
           actual[max_error_row][max_error_col],
           expected[max_error_row][max_error_col]);
    printf("============================================================\n\n");
}
// void compare_int_3D(
//     const char *name,
//     int dim0,
//     int dim1,
//     int dim2,
//     const int8_t actual[dim0][dim1][dim2],
//     const int8_t expected[dim0][dim1][dim2]
// )
// {
//     long long total =
//         (long long)dim0 *
//         (long long)dim1 *
//         (long long)dim2;

//     if (total <= 0)
//     {
//         printf("\n============================================================\n");
//         printf("Comparison: %s\n", name);
//         printf("Invalid shape: [%d][%d][%d]\n", dim0, dim1, dim2);
//         printf("============================================================\n\n");
//         return;
//     }

//     long long exact_count = 0;
//     long long within_1_count = 0;
//     long long within_2_count = 0;

//     long long sum_abs_error = 0;
//     long long sum_squared_error = 0;
//     long long sum_signed_error = 0;

//     long long max_abs_error = -1;

//     int max_error_i = 0;
//     int max_error_j = 0;
//     int max_error_k = 0;

//     for (int i = 0; i < dim0; i++)
//     {
//         for (int j = 0; j < dim1; j++)
//         {
//             for (int k = 0; k < dim2; k++)
//             {
//                 long long diff =
//                     (long long)actual[i][j][k] -
//                     (long long)expected[i][j][k];

//                 long long abs_diff =
//                     diff < 0 ? -diff : diff;

//                 if (abs_diff == 0)
//                 {
//                     exact_count++;
//                 }

//                 if (abs_diff <= 1)
//                 {
//                     within_1_count++;
//                 }

//                 if (abs_diff <= 2)
//                 {
//                     within_2_count++;
//                 }

//                 sum_abs_error += abs_diff;
//                 sum_squared_error += diff * diff;
//                 sum_signed_error += diff;

//                 if (abs_diff > max_abs_error)
//                 {
//                     max_abs_error = abs_diff;

//                     max_error_i = i;
//                     max_error_j = j;
//                     max_error_k = k;
//                 }
//             }
//         }
//     }

//     double exact_rate =
//         100.0 * (double)exact_count / (double)total;

//     double mismatch_rate =
//         100.0 * (double)(total - exact_count) / (double)total;

//     double within_1_rate =
//         100.0 * (double)within_1_count / (double)total;

//     double within_2_rate =
//         100.0 * (double)within_2_count / (double)total;

//     double mae =
//         (double)sum_abs_error / (double)total;

//     double rmse =
//         rvx_sqrt((double)sum_squared_error / (double)total);

//     double mean_signed_error =
//         (double)sum_signed_error / (double)total;

//     printf("\n============================================================\n");
//     printf("Comparison: %s\n", name);
//     printf("Shape: [%d][%d][%d]\n", dim0, dim1, dim2);
//     printf("Total values: %lld\n", total);

//     printf(
//         "Exact match: %lld / %lld (%.2f%%)\n",
//         exact_count,
//         total,
//         exact_rate
//     );

//     printf("Mismatch rate: %.2f%%\n", mismatch_rate);

//     printf(
//         "|error| <= 1: %lld / %lld (%.2f%%)\n",
//         within_1_count,
//         total,
//         within_1_rate
//     );

//     printf(
//         "|error| <= 2: %lld / %lld (%.2f%%)\n",
//         within_2_count,
//         total,
//         within_2_rate
//     );

//     printf("MAE: %.6f\n", mae);
//     printf("RMSE: %.6f\n", rmse);
//     printf("Mean signed error: %.6f\n", mean_signed_error);

//     printf(
//         "Max absolute error: %lld at [%d][%d][%d]\n",
//         max_abs_error,
//         max_error_i,
//         max_error_j,
//         max_error_k
//     );

//     printf(
//         "Actual: %d, Expected: %d\n",
//         actual[max_error_i][max_error_j][max_error_k],
//         expected[max_error_i][max_error_j][max_error_k]
//     );

//     printf("============================================================\n\n");
// }