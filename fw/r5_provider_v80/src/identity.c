/*
 * Coyote Example 15 — R5 provider immutable runtime identity.
 *
 * runtime_abi / firmware_abi must be non-zero (cyt_provider_open rejects zero)
 * and are reported to the host via CYT_REG_RUNTIME_ABI/FIRMWARE_ABI for
 * staleness/recovery detection. Values here correspond to the example's
 * registration (RUNTIME_ABI baremetal, FIRMWARE_ABI coyote-r5-provider-mmio-v1).
 * image_identity is a fixed build tag ("EX15R5PV" packed).
 */
#include "provider.h"

const struct cyt_provider_firmware_identity cyt_r5_provider_identity = {
    .runtime_abi  = 1u,   /* baremetal */
    .firmware_abi = 1u,   /* coyote-r5-provider-mmio-v1 */
    .image_identity = {
        0x35315845u, /* "EX15" */
        0x56503552u, /* "R5PV" */
        0x00000001u, /* version */
        0x00000000u,
        0x00000000u,
        0x00000000u,
        0x00000000u,
        0x00000000u,
    },
};
