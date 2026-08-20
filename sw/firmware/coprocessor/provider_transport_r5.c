#include "provider_internal.h"

#include <stdint.h>

#define PROVIDER_BASE UINT32_C(0x80010000)

static bool r5_read32(void *context, uint16_t offset, uint32_t *value) {
    (void)context;
    *value = *(volatile uint32_t *)(uintptr_t)(PROVIDER_BASE + offset);
    __asm__ volatile("dmb sy" ::: "memory");
    return true;
}

static bool r5_write32(void *context, uint16_t offset, uint32_t value) {
    (void)context;
    *(volatile uint32_t *)(uintptr_t)(PROVIDER_BASE + offset) = value;
    __asm__ volatile("dmb sy" ::: "memory");
    return true;
}

void cyt_provider_install_r5_transport(void) {
    const struct cyt_provider_transport transport = {
        .context = (void *)0,
        .read32 = r5_read32,
        .write32 = r5_write32,
    };
    cyt_provider_install_transport(&transport);
}
