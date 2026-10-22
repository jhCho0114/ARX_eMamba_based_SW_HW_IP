#include "base.h"

/* RVX: stdio/stdlib are unavailable -> use ervp replacements. */
#include "ervp_printf.h"        /* printf */
#include "ervp_platform_api.h"  /* exit   */
#include <limits.h>

int64_t scale_value_i64(int64_t value, int exp)
{
    if (exp == 0)
    {
        return value;
    }

    if (exp > 0)
    {
        if (exp >= 63)
        {
            printf( "scale_value_i64: exp too large: %d\n", exp);
            exit(1);
        }

        int64_t factor = INT64_C(1) << exp;

        if (value > INT64_MAX / factor || value < INT64_MIN / factor)
        {
            printf(
                "scale_value_i64: overflow: value=%lld, exp=%d\n",
                (long long)value,
                exp
            );
            exit(1);
        }

        return value * factor;
    }
    int shift = -exp;

    if (shift >= 63)
    {
        printf( "scale_value_i64: exp too small: %d\n", exp);
        exit(1);
    }

    int64_t divisor = INT64_C(1) << shift;

    int64_t quotient = value / divisor;
    int64_t remainder = value % divisor;

    if (remainder < 0)
    {
        quotient -= 1;
        remainder += divisor;
    }

    if (remainder >= divisor / 2)
    {
        quotient += 1;
    }

    return quotient;
}

int scale_value_int(int value, int exp)
{
    int64_t result = scale_value_i64((int64_t)value, exp);

    if (result > INT_MAX || result < INT_MIN)
    {
        printf( "scale_value_int: overflow\n");
        exit(1);
    }

    return (int)result;
}
void shift_array3D(
    int D0,
    int D1,
    int D2,
    int array[D0][D1][D2],
    int exp
)
{
    if (exp == 0)
    {
        return;
    }

    for (int i = 0; i < D0; i++)
    {
        for (int j = 0; j < D1; j++)
        {
            for (int k = 0; k < D2; k++)
            {
                array[i][j][k] = scale_value_int(array[i][j][k], exp);
            }
        }
    }
}

void shift_array2D(
    int N,
    int M,
    int array[N][M],
    int exp
)
{
    if (exp == 0)
    {
        return;
    }

    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            array[n][m] = scale_value_int(array[n][m], exp);
        }
    }
}

void shift_array1D(
    int M,
    int array[M],
    int exp
)
{
    if (exp == 0)
    {
        return;
    }

    for (int m = 0; m < M; m++)
    {
        array[m] = scale_value_int(array[m], exp);
    }
}

// static int shift_value(int value, int exp)
// {
//     return scale_value_int(value, exp);
// }

long long shift_value_ll(long long value, int exp)
{
    return (long long)scale_value_i64((int64_t)value, exp);
}

void MM_t_A(
    int N,
    int K,
    int M,
    int input[N][K],
    int weight[M][K],
    int bias[M],
    int output[N][M]
)
{
    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            int sum = 0;

            for (int k = 0; k < K; k++)
            {
                sum += input[n][k] * weight[m][k];
            }

            output[n][m] = sum + bias[m];
        }
    }
}


void cap_int8(int N, int M, int array[N][M])
{
    for (int n = 0; n < N; n++)
    {
        for (int m = 0; m < M; m++)
        {
            if (array[n][m] > 127)
                array[n][m] = 127;
            if (array[n][m] < -128)
                array[n][m] = -128;
        }
    }
}
void cap_int8_3D(
    int D0,
    int D1,
    int D2,
    int array[D0][D1][D2]
)
{
    for (int i = 0; i < D0; i++)
    {
        for (int j = 0; j < D1; j++)
        {
            for (int k = 0; k < D2; k++)
            {
                if (array[i][j][k] > 127)
                    array[i][j][k] = 127;

                if (array[i][j][k] < -128)
                    array[i][j][k] = -128;
            }
        }
    }
}