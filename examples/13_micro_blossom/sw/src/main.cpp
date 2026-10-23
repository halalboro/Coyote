/**
 * Coyote Example 13: Micro Blossom QEC Decoder — Smoke Test
 *
 * Reads Micro Blossom's version register at offset 0x8 (register index 1
 * in Coyote's 8-byte-aligned CSR space). Expected value: 0x240123c0.
 *
 * This validates the entire AXI fabric: host PCIe -> BAR -> axi_main ->
 * smartconnect_1 -> shell -> vFPGA's axi_ctrl -> axi_protocol_converter ->
 * MicroBlossomBus.s0 -> register read -> response back.
 */

#include <cstdint>
#include <iostream>
#include <unistd.h>

#include <coyote/cThread.hpp>

constexpr uint32_t DEFAULT_VFPGA_ID = 0;
constexpr uint32_t MB_TIMER_REG_IDX    = 0;  // offset 0x00 (free-running counter, 64-bit)
constexpr uint32_t MB_VERSION_REG_IDX  = 1;  // offset 0x08 (version low32, ctx depth high32)
constexpr uint64_t MB_EXPECTED_VERSION = 0x240123c0ULL;

int main(int /*argc*/, char* /*argv*/[]) {
    coyote::cThread coyote_thread(DEFAULT_VFPGA_ID, getpid());

    // Read the 64-bit word at offset 0x08. The low 32 bits are the version
    // stamp; the high 32 bits are the context depth.
    uint64_t reg = coyote_thread.getCSR(MB_VERSION_REG_IDX);
    uint32_t version = static_cast<uint32_t>(reg & 0xFFFFFFFFULL);
    uint32_t ctx_depth = static_cast<uint32_t>(reg >> 32);

    std::cout << std::hex
              << "Version register (offset 0x08): 0x" << version << "\n"
              << "Context depth   (offset 0x0C): 0x" << ctx_depth << "\n"
              << "Expected version             : 0x" << MB_EXPECTED_VERSION << "\n";

    // Read timer twice; should monotonically increase
    uint64_t t0 = coyote_thread.getCSR(MB_TIMER_REG_IDX);
    uint64_t t1 = coyote_thread.getCSR(MB_TIMER_REG_IDX);
    std::cout << "Timer reg sample 1: 0x" << t0 << "\n"
              << "Timer reg sample 2: 0x" << t1 << "\n";

    bool version_ok = (version == MB_EXPECTED_VERSION);
    bool timer_increments = (t1 > t0);

    std::cout << std::dec
              << "\nVersion OK:        " << (version_ok ? "yes" : "no") << "\n"
              << "Timer increments:  " << (timer_increments ? "yes" : "no") << "\n";

    if (version_ok && timer_increments) {
        std::cout << "\n*** MICRO BLOSSOM V80 SMOKE TEST PASSED ***\n";
        return 0;
    }
    std::cerr << "\n*** SMOKE TEST FAILED ***\n";
    return 1;
}
