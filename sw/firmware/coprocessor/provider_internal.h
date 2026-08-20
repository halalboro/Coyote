#ifndef COYOTE_R5_PROVIDER_INTERNAL_H
#define COYOTE_R5_PROVIDER_INTERNAL_H

#include "provider.h"

struct cyt_provider_transport {
    void *context;
    bool (*read32)(void *context, uint16_t offset, uint32_t *value);
    bool (*write32)(void *context, uint16_t offset, uint32_t value);
};

void cyt_provider_install_transport(const struct cyt_provider_transport *transport);

#endif
