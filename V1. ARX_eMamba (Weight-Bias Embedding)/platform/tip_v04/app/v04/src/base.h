#ifndef __BASE_H__
#define __BASE_H__


#include <stdint.h>

void shift_array3D(int D0, int D1, int D2, int array[D0][D1][D2], int exp);
void shift_array2D(int N, int M, int array[N][M], int exp);
void shift_array1D(int M, int array[M], int exp);
void cap_int8(int N, int M, int array[N][M]);
void cap_int8_3D(int D0, int D1, int D2, int array[D0][D1][D2]);
long long shift_value_ll(long long value, int exp);

void MM_t_A(int N, int K, int M, int input[N][K], int weight[M][K], int bias[M], int output[N][M]);

int64_t scale_value_i64(int64_t value, int exp);
int scale_value_int(int value, int exp);

#endif