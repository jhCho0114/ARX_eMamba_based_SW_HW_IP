#include "txt.h"
#include "rvx_compat.h"


#define TXT_MAX 8192

static char s_filebuf[TXT_MAX];

static int rvx_isspace(char c)
{
    return c == ' '  ||
           c == '\n' ||
           c == '\r' ||
           c == '\t' ||
           c == '\v' ||
           c == '\f';
}


void skip_ws(const char **p)
{
    while (**p && rvx_isspace(**p)) {
        (*p)++;
    }
}


int parse_int_number(const char **p, int *out)
{
    int sign = 1;
    long long value = 0;
    int has_digit = 0;

    skip_ws(p);

    if (**p == '-') {
        sign = -1;
        (*p)++;
    } else if (**p == '+') {
        (*p)++;
    }

    while (**p >= '0' && **p <= '9') {
        int digit = **p - '0';
        has_digit = 1;

        value = value * 10 + digit;

        if (sign == 1 && value > 2147483647LL) {
            return -1;
        }
        if (sign == -1 && value > 2147483648LL) {
            return -1;
        }

        (*p)++;
    }

    if (!has_digit) {
        return -1;
    }

    if (sign == -1) {
        if (value == 2147483648LL) {
            *out = -2147483647 - 1;
        } else {
            *out = -(int)value;
        }
    } else {
        *out = (int)value;
    }

    return 0;
}

/*
 * Read whole file with getc into the static buffer, skipping whitespace.
 * Uses only ffopen/ffgetc/ffclose (target) or fopen/fgetc/fclose (PC) -- no
 * seek/tell, no malloc/realloc/free. Returns s_filebuf or NULL.
 */
#ifdef TARGET_RVX
static char *read_file_all(const char *filename, int keep_ws)
{
    FAKEFILE *fp = ffopen(filename, "r");
    if (!fp) {
        RVX_LOG("read_file_all: ffopen('%s') failed\n", filename);
        return NULL;
    }

    size_t len = 0;
    int c;
    while ((c = ffgetc(fp)) != EOF) {
        if (!keep_ws && rvx_isspace((char)c)) {
            continue;
        }
        if (len + 1 >= TXT_MAX) {
            RVX_LOG("read_file_all: '%s' exceeds TXT_MAX(%d)\n", filename, TXT_MAX);
            ffclose(fp);
            return NULL;
        }
        s_filebuf[len++] = (char)c;
    }
    s_filebuf[len] = '\0';
    ffclose(fp);

    if (len == 0) {
        RVX_LOG("read_file_all: '%s' opened but read 0 bytes\n", filename);
        return NULL;
    }
    return s_filebuf;
}
#else
static char *read_file_all(const char *filename, int keep_ws)
{
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        RVX_LOG("read_file_all: fopen('%s') failed\n", filename);
        return NULL;
    }

    size_t len = 0;
    int c;
    while ((c = fgetc(fp)) != EOF) {
        if (!keep_ws && rvx_isspace((char)c)) {
            continue;
        }
        if (len + 1 >= TXT_MAX) {
            RVX_LOG("read_file_all: '%s' exceeds TXT_MAX(%d)\n", filename, TXT_MAX);
            fclose(fp);
            return NULL;
        }
        s_filebuf[len++] = (char)c;
    }
    s_filebuf[len] = '\0';
    fclose(fp);

    if (len == 0) {
        RVX_LOG("read_file_all: '%s' opened but read 0 bytes\n", filename);
        return NULL;
    }
    return s_filebuf;
}
#endif

/* ---- first read: quantized input tensor (int8 output) ----
 * Plain text format: one integer per line, NUM_CHANNELS*NUM_HEIGHT*NUM_WIDTH
 * values total, filled in [channel][height][width] order. No brackets/commas.
 * read_file_all is called with keep_ws=1 so the newline separators survive;
 * parse_int_number then skips the whitespace between consecutive numbers.
 */
int load_int_value_txt(
    const char *filename,
    int8_t out[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH]
)
{
    char *buf = read_file_all(filename, 1);
    const char *p;

    if (!buf) {
        return -1;
    }

    p = buf;

    for (int i = 0; i < NUM_CHANNELS; i++) {
        for (int j = 0; j < NUM_HEIGHT; j++) {
            for (int k = 0; k < NUM_WIDTH; k++) {
                int tmp;
                if (parse_int_number(&p, &tmp) != 0) { return -2; }
                out[i][j][k] = (int8_t)tmp;
            }
        }
    }

    return 0;
}