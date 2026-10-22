#include "json.h"
#include "rvx_compat.h"

/*
 * No dynamic allocation: RVX's realloc (and a fragile malloc/heap) are avoided
 * entirely. The file is read with getc into a fixed static buffer, and since
 * the parser ignores whitespace, whitespace bytes are dropped on the fly. The
 * model dimensions are fixed (config.h), so the non-whitespace JSON payload is
 * bounded well under JSON_MAX.
 */
#define JSON_MAX 8192

static char s_filebuf[JSON_MAX];

static int rvx_isspace(char c)
{
    return c == ' '  ||
           c == '\n' ||
           c == '\r' ||
           c == '\t' ||
           c == '\v' ||
           c == '\f';
}

static size_t rvx_strlen(const char *s)
{
    size_t n = 0;
    while (s[n] != '\0') {
        n++;
    }
    return n;
}

static const char *rvx_strstr(const char *s, const char *pat)
{
    if (*pat == '\0') {
        return s;
    }

    for (; *s; s++) {
        const char *a = s;
        const char *b = pat;

        while (*a && *b && *a == *b) {
            a++;
            b++;
        }

        if (*b == '\0') {
            return s;
        }
    }

    return NULL;
}

void skip_ws(const char **p)
{
    while (**p && rvx_isspace(**p)) {
        (*p)++;
    }
}

int expect_char(const char **p, char expected)
{
    skip_ws(p);

    if (**p != expected) {
        return -1;
    }

    (*p)++;
    return 0;
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
static char *read_file_all(const char *filename)
{
    FAKEFILE *fp = ffopen(filename, "r");
    if (!fp) {
        RVX_LOG("read_file_all: ffopen('%s') failed\n", filename);
        return NULL;
    }

    size_t len = 0;
    int c;
    while ((c = ffgetc(fp)) != EOF) {
        if (rvx_isspace((char)c)) {
            continue;
        }
        if (len + 1 >= JSON_MAX) {
            RVX_LOG("read_file_all: '%s' exceeds JSON_MAX(%d)\n", filename, JSON_MAX);
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
static char *read_file_all(const char *filename)
{
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        RVX_LOG("read_file_all: fopen('%s') failed\n", filename);
        return NULL;
    }

    size_t len = 0;
    int c;
    while ((c = fgetc(fp)) != EOF) {
        if (rvx_isspace((char)c)) {
            continue;
        }
        if (len + 1 >= JSON_MAX) {
            RVX_LOG("read_file_all: '%s' exceeds JSON_MAX(%d)\n", filename, JSON_MAX);
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

/* ---- first read: quantized input tensor (int8 output) ---- */
int load_int_value_json(
    const char *filename,
    int8_t out[NUM_CHANNELS][NUM_HEIGHT][NUM_WIDTH]
)
{
    char *json = read_file_all(filename);
    const char *p;

    if (!json) {
        return -1;
    }

    p = rvx_strstr(json, "\"int_value\"");
    if (!p) {
        return -2;
    }

    p += rvx_strlen("\"int_value\"");

    if (expect_char(&p, ':') != 0) { return -3; }
    if (expect_char(&p, '[') != 0) { return -4; }

    for (int i = 0; i < NUM_CHANNELS; i++) {
        if (expect_char(&p, '[') != 0) { return -5; }

        for (int j = 0; j < NUM_HEIGHT; j++) {
            if (expect_char(&p, '[') != 0) { return -6; }

            for (int k = 0; k < NUM_WIDTH; k++) {
                int tmp;
                if (parse_int_number(&p, &tmp) != 0) { return -7; }
                out[i][j][k] = (int8_t)tmp;

                if (k < NUM_WIDTH - 1) {
                    if (expect_char(&p, ',') != 0) { return -8; }
                }
            }

            if (expect_char(&p, ']') != 0) { return -9; }

            if (j < NUM_HEIGHT - 1) {
                if (expect_char(&p, ',') != 0) { return -10; }
            }
        }

        if (expect_char(&p, ']') != 0) { return -11; }

        if (i < NUM_CHANNELS - 1) {
            if (expect_char(&p, ',') != 0) { return -12; }
        }
    }

    if (expect_char(&p, ']') != 0) { return -13; }

    return 0;
}

/* ---- last read: FPGA reference, JSON shape [1][rows][cols] (int8 output) ---- */
int load_int_value_json_3D_batch1_to_2D(
    const char *filename,
    int rows,
    int cols,
    int8_t out[rows][cols]
)
{
    char *json = read_file_all(filename);
    const char *p;

    if (!json) {
        return -1;
    }

    p = rvx_strstr(json, "\"int_value\"");
    if (!p) {
        return -2;
    }

    p += rvx_strlen("\"int_value\"");

    if (expect_char(&p, ':') != 0) { return -3; }
    if (expect_char(&p, '[') != 0) { return -4; }
    if (expect_char(&p, '[') != 0) { return -5; }

    for (int i = 0; i < rows; i++) {
        if (expect_char(&p, '[') != 0) { return -6; }

        for (int j = 0; j < cols; j++) {
            int tmp;
            if (parse_int_number(&p, &tmp) != 0) { return -7; }
            out[i][j] = (int8_t)tmp;

            if (j < cols - 1) {
                if (expect_char(&p, ',') != 0) { return -8; }
            }
        }

        if (expect_char(&p, ']') != 0) { return -9; }

        if (i < rows - 1) {
            if (expect_char(&p, ',') != 0) { return -10; }
        }
    }

    if (expect_char(&p, ']') != 0) { return -11; }  /* batch 0 end */
    if (expect_char(&p, ']') != 0) { return -12; }  /* int_value end */

    return 0;
}