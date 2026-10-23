/*
 * Coyote Example 15 — R5 co-processor provider host.
 *
 * 1) Binds the R5 provider (endpoint 1) to logical co-processor port 0 by driving
 *    the co-processor control target.
 * 2) The bound R5 firmware runs its PING/INC/ADD/SUM self-test and mirrors a
 *    verdict into the vFPGA MMIO aperture (axi_ctrl).
 * 3) Reads that verdict back and prints PASS/FAIL.
 *
 * ADDRESSING (verified against the BD + shell template, 2026-09-16 — the earlier
 * driver-mmap version read the WRONG region and wedged the V80 shell bus, which
 * hard-reset clara):
 *
 *   - Control target = axi_main + 0x2000.  The shell control splitter
 *     (`axil_address_splitter`, SERVICE_BASE 0x2000) sits on `axi_cnfg`, and
 *     `axi_cnfg/Reg` is at offset 0x0 in /axi_main (cr_ctrl.tcl:386). axi_main is
 *     the host BAR4 window, so the control target is BAR4 + 0x2000.
 *   - Verdict (axi_ctrl user region) = BAR4 + VFPGA_CTRL_OFFS(0x100000) +
 *     VFPGA_CTRL_USER_OFFS(0x20000) = BAR4 + 0x120000.
 *
 * The driver exposes NEITHER offset through a page-offset mmap (its MMAP_CNFG is
 * the per-vFPGA config region at BAR4+0x130000, a different bus), so this tool
 * goes straight to the raw sysfs BAR4 resource, exactly like fw/apu_v80/a3/boot_a3.py.
 * That needs the Coyote driver UNBOUND from the V80 (a bound driver claims the BAR
 * and the resource mmap returns EINVAL):
 *     sudo sh -c 'echo 0000:81:00.0 > /sys/bus/pci/drivers/coyote_driver/unbind'
 *
 * SAFETY: the control target's MAGIC is read first; if it is all-ones (a dead/wedged
 * bus, or a non-R5-provider bitstream where 0x2000 does not decode a live slave) the
 * tool exits IMMEDIATELY with no further MMIO. Never hammer a wedged shell bus.
 */
#include "coprocessor_verdict.hpp"

#include <cstdint>
#include <cstdio>
#include <cerrno>
#include <cstring>
#include <string>
#include <fcntl.h>
#include <unistd.h>
#include <glob.h>
#include <sys/mman.h>

using namespace ex15;

// BAR4 byte offsets (see the ADDRESSING note above).
static constexpr off_t  CT_BASE_BAR4   = 0x2000;      // co-processor control target
static constexpr off_t  VERDICT_BAR4   = 0x120000;    // vFPGA 0 axi_ctrl user region
static constexpr size_t MAP_SZ         = 0x10000;     // 64 KB per window (page aligned)

// Locate the V80's BAR4 sysfs resource (Xilinx b03f). Returns "" if not found.
static std::string find_bar4() {
    glob_t g; std::string r;
    if (glob("/sys/bus/pci/devices/*/resource4", 0, nullptr, &g) == 0) {
        for (size_t i = 0; i < g.gl_pathc; ++i) {
            std::string res = g.gl_pathv[i];
            std::string dir = res.substr(0, res.rfind('/'));
            char buf[16] = {0};
            int f = open((dir + "/device").c_str(), O_RDONLY);
            if (f >= 0) { ssize_t n = read(f, buf, sizeof(buf) - 1); (void)n; close(f); }
            if (strtoul(buf, nullptr, 16) == 0xb03f) { r = res; break; }
        }
    }
    globfree(&g);
    return r;
}

int main() {
    std::string bar4 = find_bar4();
    if (bar4.empty()) {
        fprintf(stderr, "no V80 (Xilinx b03f) found under /sys/bus/pci/devices/*/resource4\n");
        return 2;
    }
    int fd = open(bar4.c_str(), O_RDWR | O_SYNC);
    if (fd < 0) { perror("open BAR4 resource"); return 2; }

    auto *ct = (volatile uint8_t *) mmap(nullptr, MAP_SZ, PROT_READ | PROT_WRITE,
                                         MAP_SHARED, fd, CT_BASE_BAR4);
    auto *vd = (volatile uint8_t *) mmap(nullptr, MAP_SZ, PROT_READ | PROT_WRITE,
                                         MAP_SHARED, fd, VERDICT_BAR4);
    if (ct == MAP_FAILED || vd == MAP_FAILED) {
        fprintf(stderr, "mmap BAR4: %s\n"
                "(a bound Coyote driver claims the BAR -> unbind it first:\n"
                " sudo sh -c 'echo 0000:81:00.0 > /sys/bus/pci/drivers/coyote_driver/unbind')\n",
                strerror(errno));
        close(fd);
        return 2;
    }

    // The control target is a 64-bit-wide AXI4-Lite slave, but the PCIe/QDMA BAR path only
    // handles 32-bit MMIO to it: a single 64-bit read returns all-ones (verified on HW,
    // 2026-09-20). So access each 64-bit register as its two adjacent 32-bit words.
    auto rd32 = [&](uint32_t off) -> uint32_t { return *(volatile uint32_t *)(ct + off); };
    auto wr32 = [&](uint32_t off, uint32_t v) { *(volatile uint32_t *)(ct + off) = v; };
    auto ct_rd = [&](uint32_t off) -> uint64_t {
        return ((uint64_t) rd32(off + 4) << 32) | rd32(off);
    };
    // The control target is a 64-bit AXI-Lite slave that REQUIRES full byte-strobes
    // (wstrb==0xff, coprocessor_control_target.sv:123) — a 32-bit write is SLVERR'd and
    // silently dropped, so every command (CMD/BGEN/EGEN/SUBMIT/ACK) is ignored and the
    // bind "times out". The QDMA BAR path delivers a single 64-bit store as one
    // wstrb==0xff beat (verified on HW 2026-09-22), so writes MUST be 64-bit. Reads are
    // the opposite: a 64-bit read returns all-ones, so reads stay 32-bit low-word (rd32).
    auto ct_wr = [&](uint32_t off, uint64_t val) {
        *(volatile uint64_t *)(ct + off) = val;
    };
    (void) wr32;
    // Verdict registers are also 64-bit; read each as two 32-bit words (word i is at byte i*8).
    auto vd_rd = [&](uint32_t word) -> uint64_t {
        uint32_t lo = *(volatile uint32_t *)(vd + word * 8);
        uint32_t hi = *(volatile uint32_t *)(vd + word * 8 + 4);
        return ((uint64_t) hi << 32) | lo;
    };
    // Debounced read: neutralize the A72-style read-after-write transient (a freshly
    // settled register can read stale/0 for a beat on this MMIO path). Read until the
    // value is stable and nonzero; warn if it never settles.
    auto ct_rd_stable = [&](uint32_t off) -> uint64_t {
        uint64_t a = ct_rd(off), b = ct_rd(off);
        int k = 0;
        for (; k < 16 && (a != b || a == 0); ++k) { a = b; b = ct_rd(off); }
        if (a != b || a == 0)
            fprintf(stderr, "  [warn] CT+0x%03x unstable/zero after %d reads: %#llx vs %#llx\n",
                    off, k, (unsigned long long)a, (unsigned long long)b);
        return b;
    };
    auto dump_status = [&](const char *tag) -> uint64_t {
        uint64_t s = ct_rd(CT_STATUS);
        fprintf(stderr, "  [%s] STATUS=%#018llx inflight=%d done=%d valid=%d result=%u compl=%#x\n",
                tag, (unsigned long long)s, (int)st_inflight(s), (int)st_done(s),
                (int)((s >> 6) & 1u), st_result(s), st_completion(s));
        return s;
    };

    // Fail-fast: read the control-target MAGIC and STOP on an all-ones / wrong bus.
    // No further MMIO happens if this fails, so a wedged bus is never hammered.
    uint64_t magic = ct_rd(CT_MAGIC);
    if ((uint32_t)magic == 0xFFFFFFFFu) {
        fprintf(stderr, "control target reads all-ones at BAR4+0x%lx -- dead/wedged bus or "
                "non-R5-provider bitstream. Aborting with no further access.\n", (long)CT_BASE_BAR4);
        return 2;
    }
    if ((uint32_t)magic != CT_MAGIC_VALUE) {
        fprintf(stderr, "control target magic 0x%08x (want 0x%08x \"CPCT\") -- wrong bitstream?\n",
                (uint32_t)magic, CT_MAGIC_VALUE);
        return 2;
    }

    uint64_t prov = ct_rd(CT_PROV);
    if (!prov_available(prov) || !prov_healthy(prov)) {
        fprintf(stderr, "provider not available/healthy (0x%016llx) — is the R5 firmware up?\n",
                (unsigned long long)prov);
        // continue anyway; the R5 acks its generation in refresh_binding
    }

    uint32_t endpoint_gen = (uint32_t) ct_rd(CT_PROVGEN);
    uint32_t binding_gen  = (uint32_t) ct_rd(CT_BINDGEN);

    // Issue BIND(endpoint 1) -> port 0
    ct_wr(CT_CMD,  ((uint64_t)ENDPOINT_ID << 16) | OP_BIND);
    ct_wr(CT_BGEN, binding_gen);
    ct_wr(CT_EGEN, endpoint_gen);
    // command_token is in the low 32 bits; the high-word read is all-ones on this BAR
    // path, so mask it. completion_token mirrors command_token, so we ACK with this same
    // value (its high word can't be read back either).
    uint64_t token = ct_rd_stable(CT_SUBMIT) & 0xffffffffu;
    ct_wr(CT_SUBMIT, token);          // submit

    fprintf(stderr, "  bind: token=%#llx prov=%#llx(avail=%d healthy=%d) provgen=%u bindgen=%u\n",
            (unsigned long long)token, (unsigned long long)prov, (int)prov_available(prov),
            (int)prov_healthy(prov), endpoint_gen, binding_gen);
    dump_status("post-submit");

    // Poll completion
    uint64_t st = 0;
    for (int i = 0; i < 1000000; ++i) {
        st = ct_rd(CT_STATUS);
        if (st_done(st)) break;
    }
    if (!st_done(st)) {
        dump_status("timeout");
        fprintf(stderr, "bind timed out (inflight=%d -> %s)\n", (int)st_inflight(st),
                st_inflight(st)
                  ? "submit dispatched, provider/gateway never returned response_valid -- R5 fw / gateway side"
                  : "submit NOT dispatched (token mismatch / stale read) -- host side, debounce should fix");
        return 1;
    }
    uint32_t result = st_result(st);
    ct_wr(CT_ACK, token);             // ack (completion_token == the command_token we submitted)
    if (result != 0) { fprintf(stderr, "bind failed, result=%u\n", result); return 1; }
    printf("bound provider endpoint %u -> port 0 (binding_generation=%u)\n",
           ENDPOINT_ID, (uint32_t) ct_rd(CT_BINDGEN));

    // Wait for the R5 self-test verdict (done flag in VERD1 high word)
    uint64_t v1 = 0;
    for (int i = 0; i < 2000000; ++i) {
        v1 = vd_rd(VERD1_WORD);
        if ((uint32_t)(v1 >> 32) == 1u) break;   // done
        usleep(10);
    }
    uint32_t vmagic = (uint32_t) vd_rd(VMAGIC_WORD);
    if (vmagic != MMIO_MAGIC) {
        fprintf(stderr, "verdict MAGIC mismatch 0x%08x (want 0x%08x) — R5 wrote no verdict\n",
                vmagic, MMIO_MAGIC);
        return 1;
    }
    if ((uint32_t)(v1 >> 32) != 1u) { fprintf(stderr, "verdict not done (timeout)\n"); return 1; }

    uint64_t v0 = vd_rd(VERD0_WORD), v2 = vd_rd(VERD2_WORD), v3 = vd_rd(VERD3_WORD);
    uint32_t passed = (uint32_t) v0, total = (uint32_t)(v0 >> 32);
    uint32_t first_fail = (uint32_t) v1;
    uint32_t lat_min = (uint32_t) v2, lat_max = (uint32_t)(v2 >> 32);
    uint32_t lat_avg = (uint32_t) v3, r5_mhz = (uint32_t)(v3 >> 32);

    static const char *NAMES[] = { "none", "PING", "INC", "ADD", "SUM" };
    bool ok = (passed == total);
    printf("R5 co-processor self-test (via provider): %s  (%u/%u opcodes)\n",
           ok ? "PASS" : "FAIL", passed, total);
    if (!ok) printf("  first failing opcode: %s\n", first_fail <= 4 ? NAMES[first_fail] : "?");
    printf("  latency (R5 cycles): min=%u max=%u avg=%u\n", lat_min, lat_max, lat_avg);
    if (r5_mhz) printf("                       min ~= %.3f us (@ %u MHz)\n",
                       (double) lat_min / r5_mhz, r5_mhz);

    munmap((void*)ct, MAP_SZ); munmap((void*)vd, MAP_SZ); close(fd);
    return ok ? 0 : 1;
}
