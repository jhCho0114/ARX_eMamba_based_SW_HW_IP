#ifndef RVX_COMPAT_H
#define RVX_COMPAT_H

#include <stddef.h>
#include <stdint.h>

#define TARGET_RVX 1

#ifdef TARGET_RVX

#include "ervp_assert.h"
#include "ervp_printf.h"
#include "ervp_malloc.h"
#include "ervp_stdlib.h"
#include "ervp_platform_api.h"
#include "ervp_fakefile.h"

#define RVX_LOG(...) printf(__VA_ARGS__)
#define RVX_EXIT(code) exit(code)

#else

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#define RVX_LOG(...) printf(__VA_ARGS__)
#define RVX_EXIT(code) exit(code)

#endif

static inline void *rvx_memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;

    while (n--) {
        *d++ = *s++;
    }

    return dst;
}

#endif