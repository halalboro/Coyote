/*
 * Coyote Example 15 — R5 co-processor provider firmware (bare-metal, R5-0).
 *
 * The R5 is the master/orchestrator. After the host binds this provider to the
 * logical co-processor port, the R5 runs a small self-test against the vFPGA
 * co-processor slave: for each opcode (PING/INC/ADD/SUM) it sends a request
 * packet, receives the result, checks it and times it. It then mirrors a
 * verdict into the vFPGA MMIO aperture (app_write64), which the host reads back
 * over BAR. See coprocessor_abi.h for the wire + register layout.
 *
 * Transport: cyt_provider_install_r5_transport() (MMIO at 0x80010000).
 */
#include "provider.h"
#include "provider_platform.h"
#include "coprocessor_abi.h"

#include <stdint.h>
#include <stddef.h>
#include <string.h>

extern const struct cyt_provider_firmware_identity cyt_r5_provider_identity;

#define POLL_BUDGET 200000u
#define R5_MHZ      33u   /* approximate; host may override when interpreting cycles */

static inline uint32_t ld32(const uint8_t *p, unsigned off) {
    uint32_t v; memcpy(&v, p + off, sizeof v); return v;
}
static inline void st32(uint8_t *p, unsigned off, uint32_t v) {
    memcpy(p + off, &v, sizeof v);
}

/* R5 (Cortex-R5) PMU cycle counter; stubbed off-target so the file builds x86. */
#if defined(__arm__) || defined(__aarch64__)
static inline void pmu_enable(void) {
    uint32_t v;
    __asm__ volatile("mrc p15, 0, %0, c9, c12, 0" : "=r"(v));
    v |= 0x5u; /* PMCR.E (enable) | PMCR.C (reset cycle counter) */
    __asm__ volatile("mcr p15, 0, %0, c9, c12, 0" :: "r"(v));
    __asm__ volatile("mcr p15, 0, %0, c9, c12, 1" :: "r"(0x80000000u)); /* PMCNTENSET */
}
static inline uint32_t cycles(void) {
    uint32_t c; __asm__ volatile("mrc p15, 0, %0, c9, c13, 0" : "=r"(c)); return c;
}
#else
static inline void pmu_enable(void) {}
static inline uint32_t cycles(void) { return 0u; }
#endif

static uint32_t expected_result(uint32_t op, uint32_t a, uint32_t b) {
    switch (op) {
    case COP_OP_PING: return a;
    case COP_OP_INC:  return a + 1u;
    case COP_OP_ADD:  return a + b;
    case COP_OP_SUM:  return a; /* PING (op 0) resets the accumulator to 0 first */
    default:          return 0u;
    }
}

int main(void) {
    cyt_provider *prov;
    struct cyt_provider_identity pid;
    struct cyt_provider_status  status;

    pmu_enable();
    cyt_provider_install_r5_transport();

    while (cyt_provider_open(&cyt_r5_provider_identity, &prov, &pid) != CYT_PROVIDER_OK) {
        /* spin until the provider hardware is present/matched */
    }

    /* wait for the host to bind us to a logical port */
    for (;;) {
        if (cyt_provider_read_status(prov, &status) == CYT_PROVIDER_OK && status.selected) {
            break;
        }
        cyt_provider_refresh_binding(prov);
    }

    static const uint32_t ops[4] = { COP_OP_PING, COP_OP_INC, COP_OP_ADD, COP_OP_SUM };
    uint32_t passed = 0u, total = 4u, first_fail = 0u;
    uint32_t lat_min = 0xffffffffu, lat_max = 0u, lat_sum = 0u;

    uint8_t txb[COP_BEAT_BYTES], rxb[COP_BEAT_BYTES];
    struct cyt_provider_packet_metadata tmeta, rmeta;
    struct cyt_provider_wait wait;

    for (unsigned i = 0; i < 4u; ++i) {
        uint32_t op  = ops[i];
        uint32_t a   = 0x100u + i;
        uint32_t b   = 0x10u;
        uint32_t seq = i + 1u;
        uint32_t exp = expected_result(op, a, b);

        memset(txb, 0, sizeof txb);
        st32(txb, COP_REQ_OPCODE, op);
        st32(txb, COP_REQ_OPA, a);
        st32(txb, COP_REQ_OPB, b);
        st32(txb, COP_REQ_SEQ, seq);
        tmeta.beat_count = 1u;
        tmeta.beat_id[0] = 0u;

        wait.polls_left = POLL_BUDGET;
        if (cyt_provider_send(prov, txb, COP_BEAT_BYTES, &tmeta, &wait) != CYT_PROVIDER_OK) {
            if (!first_fail) first_fail = i + 1u;
            continue;
        }

        uint32_t t0 = cycles();
        size_t len = 0u;
        wait.polls_left = POLL_BUDGET;
        enum cyt_provider_result rr =
            cyt_provider_receive(prov, rxb, sizeof rxb, &len, &rmeta, &wait);
        uint32_t dt = cycles() - t0;

        if (rr != CYT_PROVIDER_OK) {
            if (!first_fail) first_fail = i + 1u;
            continue;
        }

        uint32_t st  = ld32(rxb, COP_RSP_STATUS);
        uint32_t res = ld32(rxb, COP_RSP_RESULT);
        uint32_t rsq = ld32(rxb, COP_RSP_SEQ);

        if (st == COP_ST_OK && res == exp && rsq == seq) {
            passed++;
            if (dt < lat_min) lat_min = dt;
            if (dt > lat_max) lat_max = dt;
            lat_sum += dt;
        } else if (!first_fail) {
            first_fail = i + 1u;
        }
    }

    uint32_t lat_avg = passed ? (lat_sum / passed) : 0u;
    if (lat_min == 0xffffffffu) lat_min = 0u;

    /* mirror the verdict into the vFPGA MMIO aperture (host reads over BAR) */
    wait.polls_left = POLL_BUDGET;
    cyt_provider_app_write64(prov, COP_MMIO_OFF_VERD0,
                             ((uint64_t)total << 32) | passed, 0xFFu, &wait);
    wait.polls_left = POLL_BUDGET;
    cyt_provider_app_write64(prov, COP_MMIO_OFF_VERD1,
                             ((uint64_t)1u << 32) | first_fail, 0xFFu, &wait); /* done=1 */
    wait.polls_left = POLL_BUDGET;
    cyt_provider_app_write64(prov, COP_MMIO_OFF_VERD2,
                             ((uint64_t)lat_max << 32) | lat_min, 0xFFu, &wait);
    wait.polls_left = POLL_BUDGET;
    cyt_provider_app_write64(prov, COP_MMIO_OFF_VERD3,
                             ((uint64_t)R5_MHZ << 32) | lat_avg, 0xFFu, &wait);

    cyt_provider_set_idle(prov, true);
    for (;;) {
        /* idle; a fuller firmware would poll for quiesce/fault here */
    }
    return 0;
}
