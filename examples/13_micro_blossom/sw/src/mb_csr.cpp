/**
 * Coyote Example 13: Micro Blossom QEC Decoder — host CSR transport shim.
 *
 * Implements the mb_csr_* transport used by the reused Rust host decoder.
 * Translates Micro Blossom byte addresses into Coyote control-register indices
 * (byte/8), applying the readout-block address alias that mirrors the remap in
 * hw/src/vfpga_top.svh.
 */
#include "mb_csr.h"

#include <cstdio>
#include <cstdlib>

#include <coyote/cThread.hpp>

namespace {

// Must match the localparams in hw/src/vfpga_top.svh.
constexpr uint64_t MB_ALIAS_BASE   = 0x00008000ULL;  // host-reachable window
constexpr uint64_t MB_READOUT_BASE = 0x00020000ULL;  // MB per-context readout
constexpr uint64_t MB_ALIAS_SPAN   = 0x00000080ULL;  // one 128 B context block

// Coyote's user control window (CTRL_REGION_SIZE) is 64 KiB.
constexpr uint64_t MB_CTRL_WINDOW_BYTES = 64ULL * 1024ULL;

coyote::cThread* g_cthread = nullptr;

// Hard-fail without throwing: these functions are called across the Rust FFI
// boundary, where a C++ exception unwinding into Rust frames is undefined
// behavior. A bad address / unset thread is an unrecoverable programmer error.
[[noreturn]] void mb_csr_fatal(const char* msg, uint64_t addr) {
    std::fprintf(stderr, "mb_csr fatal: %s (addr=0x%llx)\n", msg,
                 static_cast<unsigned long long>(addr));
    std::abort();
}

// Map a Micro Blossom byte address into a Coyote CSR index (= byte / 8),
// aliasing the readout block into the host-reachable low window.
uint32_t mb_byte_to_csr_index(uint64_t byte_address) {
    uint64_t addr = byte_address;
    if (addr >= MB_READOUT_BASE && addr < (MB_READOUT_BASE + MB_ALIAS_SPAN)) {
        addr = MB_ALIAS_BASE + (addr - MB_READOUT_BASE);
    }
    if (addr >= MB_CTRL_WINDOW_BYTES) {
        // Only context 0 of the readout block is aliased into the 64 KiB window.
        mb_csr_fatal("byte address outside the 64 KiB Coyote control window", byte_address);
    }
    if (addr & 0x7ULL) {
        mb_csr_fatal("byte address is not 8-byte aligned", byte_address);
    }
    return static_cast<uint32_t>(addr >> 3);
}

}  // namespace

extern "C" {

void mb_csr_set_cthread(coyote::cThread* thread) {
    g_cthread = thread;
}

void mb_csr_write64(uint64_t byte_address, uint64_t data) noexcept {
    if (g_cthread == nullptr) {
        mb_csr_fatal("cThread not set (call mb_csr_set_cthread first)", byte_address);
    }
    g_cthread->setCSR(data, mb_byte_to_csr_index(byte_address));
}

uint64_t mb_csr_read64(uint64_t byte_address) noexcept {
    if (g_cthread == nullptr) {
        mb_csr_fatal("cThread not set (call mb_csr_set_cthread first)", byte_address);
    }
    return g_cthread->getCSR(mb_byte_to_csr_index(byte_address));
}

}  // extern "C"
