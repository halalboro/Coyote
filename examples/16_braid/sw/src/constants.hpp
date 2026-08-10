/**
 * Coyote Example 16: BRAID — shared constants
 *
 * Mirrors the register map in hw/src/vfpga_top.svh. Nothing enforces that at
 * build time, so if you change one, change the other.
 */

#pragma once

#include <cstdint>

namespace braid {

constexpr uint32_t VFPGA_ID = 0;
constexpr double   ACLK_MHZ = 400.0;

namespace reg {
constexpr uint32_t CTRL        = 0;    // RW
constexpr uint32_t STATUS      = 1;    // RO
constexpr uint32_t N_ROUNDS    = 2;    // RW
constexpr uint32_t INTERVAL    = 3;    // RW, aclk cycles between rounds
constexpr uint32_t TX_FRAMES   = 4;    // RO
constexpr uint32_t TX_DROPPED  = 5;    // RO
constexpr uint32_t RX_FRAMES   = 6;    // RO
constexpr uint32_t RX_ERRORS   = 7;    // RO
constexpr uint32_t RX_GAPS     = 8;    // RO
constexpr uint32_t RX_MISMATCH = 9;    // RO
constexpr uint32_t LAST_ROUND  = 10;   // RO
constexpr uint32_t SYN_WORDS   = 11;   // RW, payload words per frame (1..32)
constexpr uint32_t RTT_CYCLES  = 12;   // RO, aclk cycles for the last echo
constexpr uint32_t SCRATCH     = 13;   // RW, 13..15
}

namespace ctrl {
constexpr uint64_t RUN   = 1ULL << 0;  // run the syndrome generator
constexpr uint64_t ARM   = 1ULL << 1;  // arm the checker
constexpr uint64_t CLEAR = 1ULL << 2;  // clear counters
constexpr uint64_t ECHO  = 1ULL << 3;  // reflect received syndromes back
}

namespace status {
constexpr int CHANNEL_UP  = 0;
constexpr int LANE_UP_LSB = 1;         // 4 bits
constexpr int LINK_UP     = 5;
}

constexpr uint64_t DEFAULT_ROUNDS   = 100000;
constexpr uint64_t DEFAULT_INTERVAL = 400;    // 400 aclk @400MHz = 1 us, a QEC round
constexpr int      LINK_TIMEOUT_MS  = 5000;

// Latency sweep. A protocol word is 4 bytes; 1..32 words spans 4..128 bytes,
// which covers realistic surface-code sizes (d=11 is ~15 B, d=25 ~78 B).
constexpr uint32_t WORD_BYTES       = 4;
constexpr uint32_t MAX_SYN_WORDS    = 32;
constexpr uint64_t DEFAULT_ITERS    = 1000;
constexpr int      RTT_TIMEOUT_MS   = 100;

}  // namespace braid
