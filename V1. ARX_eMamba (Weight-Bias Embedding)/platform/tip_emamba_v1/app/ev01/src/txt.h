#ifndef __TXT_H__
#define __TXT_H__

#include <stdint.h>
#include "config.h"

int load_int_value_txt(const char *filename, int8_t out[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH]);

#endif