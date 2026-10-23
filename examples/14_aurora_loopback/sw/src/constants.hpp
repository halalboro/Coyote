/**
 * Coyote Example 14 — shared constants
 *
 * Mirrors the register map in hw/src/vfpga_top.svh. If you change one, change
 * the other: there is no build-time link between them, and a silent mismatch
 * here reads as a hardware fault.
 */

#pragma once

#include <cstdint>

namespace aurora {

// vFPGA ID and stream geometry
constexpr uint32_t VFPGA_ID   = 0;
constexpr uint32_t BEAT_BYTES = 32;      // 256-bit AXI4-Stream
constexpr double   ACLK_MHZ   = 400.0;   // must match ACLK_F in the hw build

// Control registers. Host CSR index = byte offset / 8.
namespace reg {
constexpr uint32_t CTRL          = 0;    // RW
constexpr uint32_t STATUS        = 1;    // RO
constexpr uint32_t TX_BURST      = 2;    // RW, burst length in beats
constexpr uint32_t RX_BEATS      = 3;    // RO
constexpr uint32_t RX_MISMATCH   = 4;    // RO
constexpr uint32_t TX_BEAT_IDX   = 5;    // RO
constexpr uint32_t TX_DBG        = 6;    // RO
constexpr uint32_t RX_FIRST_BEAT = 7;    // RO
constexpr uint32_t RTT_HEAD      = 8;    // RO, aclk cycles
constexpr uint32_t RTT_FULL      = 9;    // RO, aclk cycles
constexpr uint32_t SCRATCH       = 10;   // RW, 10..15 unused by the design
}

// CTRL bits
namespace ctrl {
constexpr uint64_t TX_START  = 1ULL << 0;
constexpr uint64_t RX_ARM    = 1ULL << 1;
constexpr uint64_t DBG_CLEAR = 1ULL << 2;
constexpr uint64_t ECHO      = 1ULL << 3;
}

// STATUS bit positions
namespace status {
constexpr int TX_DONE     = 0;
constexpr int RX_DONE     = 1;
constexpr int CHANNEL_UP  = 2;
constexpr int LANE_UP_LSB = 3;           // 4 bits
}

// TX_DBG bit positions
namespace dbg {
constexpr int TX_RUNNING        = 0;
constexpr int TX_DONE           = 1;
constexpr int TX_VALID          = 2;
constexpr int AURORA_TREADY     = 3;
constexpr int STK_TREADY        = 4;
constexpr int STK_TX_HANDSHAKE  = 5;
constexpr int CHANNEL_UP        = 6;
constexpr int LANE_UP_LSB       = 7;     // 4 bits
constexpr int RX_ARM            = 11;
constexpr int RX_TVALID         = 12;
constexpr int STK_RX_TVALID     = 13;
constexpr int RX_DONE           = 14;
constexpr int STK_RX_TLAST      = 15;
constexpr int TX_START          = 16;
constexpr int TX_LAST           = 17;
}

// Defaults
constexpr uint64_t DEFAULT_BEATS      = 1024;
constexpr uint64_t DEFAULT_ITERS      = 1000;
constexpr uint64_t DEFAULT_MIN_BYTES  = 64;
constexpr uint64_t DEFAULT_MAX_BYTES  = 65536;
constexpr int      DEFAULT_TIMEOUT_MS = 200;
constexpr int      LINK_TIMEOUT_MS    = 5000;
constexpr int      DEFAULT_RX_WAIT_S  = 60;   // how long `rx` waits for a sender

}  // namespace aurora
