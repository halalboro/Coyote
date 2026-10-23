/**
 * Freestanding libc shims for the R5 provider firmware.
 *
 * The image links with -nostdlib, but GCC still emits calls to memcpy/memset/
 * memmove for struct assignments and array initialisation even under
 * -ffreestanding (the compiler is allowed to assume these four exist). Without
 * them the link fails with "undefined reference to `memcpy'".
 *
 * MUST be compiled with -fno-tree-loop-distribute-patterns, or GCC recognises
 * the byte loops below and rewrites them into calls to themselves -> infinite
 * recursion at run time. build_r5_provider.sh applies that flag to this file.
 */
#include <stddef.h>

void *memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) { *d++ = *s++; }
    return dst;
}

void *memset(void *dst, int c, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    while (n--) { *d++ = (unsigned char)c; }
    return dst;
}

void *memmove(void *dst, const void *src, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    if (d == s || n == 0) { return dst; }
    if (d < s) {
        while (n--) { *d++ = *s++; }
    } else {
        d += n; s += n;
        while (n--) { *--d = *--s; }
    }
    return dst;
}

int memcmp(const void *a, const void *b, size_t n)
{
    const unsigned char *x = (const unsigned char *)a;
    const unsigned char *y = (const unsigned char *)b;
    for (; n--; x++, y++) {
        if (*x != *y) { return (int)*x - (int)*y; }
    }
    return 0;
}
