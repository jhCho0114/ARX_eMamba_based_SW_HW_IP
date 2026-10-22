#ifndef __JSON_H__
#define __JSON_H__

#include <stdint.h>

#include "config.h"

/* Two JSON reads only: first = quantized input, last = FPGA reference (both int8). */
int load_int_value_json(const char *filename, int8_t out[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH]);
int load_int_value_json_3D_batch1_to_2D(const char *filename, int rows, int cols, int8_t out[rows][cols]);

void skip_ws(const char **p);
int expect_char(const char **p, char expected);
int parse_int_number(const char **p, int *out);

#endif