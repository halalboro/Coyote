/**
 * Coyote Example 13: Micro Blossom QEC Decoder — host CSR transport shim.
 *
 * The Rust host decoder (Micro Blossom primal + control loop, reused from the
 * `blossom` crate) thinks in Micro Blossom *byte addresses* (the same address
 * space the VMK180 `binding.c` reference driver uses). It reaches the hardware
 * through these three C symbols, which this shim implements over Coyote's
 * per-vFPGA control registers (`cThread::getCSR` / `setCSR`).
 *
 * Address handling (see mb_csr.cpp and the matching remap in vfpga_top.svh):
 *   - Coyote's getCSR(i)/setCSR(val,i) is a 64-bit access at byte address i*8.
 *   - Micro Blossom's per-context readout block lives at byte 0x2_0000, which is
 *     outside Coyote's 64 KiB control window. The HW wrapper aliases it to
 *     0x8000, so this shim translates byte addresses in [0x2_0000,0x2_0080) to
 *     [0x8000,0x8080) before dividing by 8. Everything else passes through.
 */
#ifndef MB_CSR_H
#define MB_CSR_H

#include <cstdint>

namespace coyote { class cThread; }

extern "C" {

// Register the Coyote thread whose control registers back the CSR transport.
// Must be called once before any mb_decode()/mb_csr_* access.
void mb_csr_set_cthread(coyote::cThread* thread);

// 64-bit MMIO at a Micro Blossom *byte* address (read-modify nothing; the bus
// is 64-bit AXI4-Lite and every MB register the host touches is isolated in its
// own aligned 8-byte word). noexcept: these are called across the Rust FFI
// boundary, so they must never let a C++ exception escape (UB otherwise); a
// fatal misuse aborts instead.
void     mb_csr_write64(uint64_t byte_address, uint64_t data) noexcept;
uint64_t mb_csr_read64(uint64_t byte_address) noexcept;

}  // extern "C"

#endif  // MB_CSR_H
