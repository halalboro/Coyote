/**
 * Coyote Example 15 — OCM channel host verdict reader.
 *
 * The R5 (AMC firmware, vOcmSelfTest) exercises the vFPGA<->R5 OCM channel on
 * boot: it posts a "+1 over N words" request into the OCM mailbox, the vFPGA
 * services it over S_AXI_LPD, and the R5 verifies the result. The R5 mirrors a
 * compact verdict into the host-visible AMC DDR window at OCM_VERDICT_DDR.
 *
 * This tool maps that window (driver MMAP_AMC region = BAR4 DDR window) and
 * prints the verdict. It is the host side of the on-card OCM channel test — the
 * authoritative result is also on the R5 debug log ("OCM self-test: PASS/FAIL").
 *
 * Layout at OCM_VERDICT_DDR (little-endian words):
 *   +0x00  magic  0x4F434D54 ("OCMT") once the R5 has written the verdict
 *   +0x04  pass   1 = PASS, 0 = FAIL
 *   +0x08  mism   number of mismatched data words
 *   +0x0C  rcode  vFPGA RCODE (0 ok, 1 bad opcode, 2 too big, 0xFFFFFFFF = timeout)
 */

#include <cstdint>
#include <cstdio>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <glob.h>
#include <string>

// Must match the driver (coyote_defs.h) and the AMC firmware (amc.c).
static constexpr long     PAGE            = 4096;
static constexpr long     MMAP_AMC        = 0x4;
static constexpr size_t   AMC_SIZE        = 0x02000000;   // 32 MB BAR4 DDR window
static constexpr uint32_t OCM_VERDICT_DDR = 0x01FF0000;   // R5 verdict mirror
static constexpr uint32_t OCM_VERDICT_MAGIC = 0x4F434D54; // "OCMT"

static std::string find_dev() {
    glob_t g; std::string r;
    if (glob("/dev/coyote_fpga_*_v*", 0, nullptr, &g) == 0 && g.gl_pathc)
        r = g.gl_pathv[0];
    globfree(&g);
    return r;
}

int main() {
    std::string dev = find_dev();
    if (dev.empty()) { fprintf(stderr, "no coyote device (/dev/coyote_fpga_*_v*)\n"); return 2; }

    int fd = open(dev.c_str(), O_RDWR | O_SYNC);
    if (fd < 0) { perror("open"); return 2; }

    volatile uint8_t *base = (volatile uint8_t *) mmap(
        nullptr, AMC_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, MMAP_AMC * PAGE);
    if (base == MAP_FAILED) { perror("mmap MMAP_AMC"); close(fd); return 2; }

    auto rd = [&](uint32_t o){ return *(volatile uint32_t *)(base + o); };

    uint32_t magic = rd(OCM_VERDICT_DDR + 0x00);
    int rc = 2;
    if (magic != OCM_VERDICT_MAGIC) {
        printf("OCM verdict: not written yet (magic=0x%08X, expected 0x%08X)\n"
               "  -> is the AMC firmware running with EN_OCM_SELFTEST=1?\n",
               magic, OCM_VERDICT_MAGIC);
    } else {
        uint32_t pass = rd(OCM_VERDICT_DDR + 0x04);
        uint32_t mism = rd(OCM_VERDICT_DDR + 0x08);
        uint32_t rcode= rd(OCM_VERDICT_DDR + 0x0C);
        printf("OCM channel self-test verdict (from R5): %s\n", pass ? "PASS" : "FAIL");
        printf("  mismatches = %u\n", mism);
        printf("  vFPGA rcode = 0x%08X%s\n", rcode,
               rcode == 0xFFFFFFFF ? " (R5 timed out waiting on vFPGA)" : "");
        rc = pass ? 0 : 1;
    }

    munmap((void*)base, AMC_SIZE);
    close(fd);
    return rc;
}
