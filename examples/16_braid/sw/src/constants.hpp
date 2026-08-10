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

// aclk drives the CSR block only. Everything that produces a number the host
// reads -- INTERVAL, RTT_CYCLES -- is counted in the GT transmit clock, because
// that is where the datapath now lives. Using ACLK_MHZ to convert an RTT gives
// an answer 55% too small.
constexpr double   ACLK_MHZ = 400.0;
constexpr double   TXCLK_MHZ = 257.8125;   // 10.3125 Gbps / 10 bits / 4 chars

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
constexpr uint32_t RTT_CYCLES  = 12;   // RO, tx_clk cycles for the last echo
constexpr uint32_t LOOPBACK    = 13;   // RW, GT LOOPBACK[2:0]
constexpr uint32_t SCRATCH     = 14;   // RW, 14..15
}

namespace ctrl {
constexpr uint64_t RUN   = 1ULL << 0;  // run the syndrome generator
constexpr uint64_t ARM   = 1ULL << 1;  // arm the checker
constexpr uint64_t CLEAR = 1ULL << 2;  // clear counters
constexpr uint64_t ECHO  = 1ULL << 3;  // reflect received syndromes back
}

// GT loopback select (UG578 LOOPBACK[2:0]), written to reg::LOOPBACK.
//
// This is how the latency budget gets decomposed without a second bitstream.
// NEAR_PMA reflects inside this card's own transceiver, so an RTT measured
// under it contains our fabric plus our GT and NOTHING else -- subtract it from
// the normal RTT and what is left is the cable plus the far card. Changing this
// resets the transceiver, so the link drops; wait for STATUS before measuring.
namespace loopback {
constexpr uint64_t NORMAL   = 0;
constexpr uint64_t NEAR_PCS = 1;
constexpr uint64_t NEAR_PMA = 2;
constexpr uint64_t FAR_PCS  = 4;
constexpr uint64_t FAR_PMA  = 6;
}

namespace status {
constexpr int CHANNEL_UP  = 0;
constexpr int LANE_UP_LSB = 1;         // 4 bits
constexpr int LINK_UP     = 5;
}

constexpr uint64_t DEFAULT_ROUNDS   = 100000;
constexpr uint64_t DEFAULT_INTERVAL = 258;    // 258 tx_clk @257.8125MHz = 1 us, a QEC round
constexpr int      LINK_TIMEOUT_MS  = 5000;

// Latency sweep. A protocol word is 4 bytes; 1..31 words spans 4..124 bytes,
// which covers realistic surface-code sizes (d=11 is ~15 B, d=25 ~78 B).
//
// 31 and not 32: echo mode crosses {round, payload} between the GT receive and
// transmit clocks in one atomic transfer, and xpm_cdc_handshake tops out at
// 1024 bits. 31*32 + 20 = 1012 fits. See N_STAB in vfpga_top.svh.
constexpr uint32_t WORD_BYTES       = 4;
constexpr uint32_t MAX_SYN_WORDS    = 31;
constexpr uint64_t DEFAULT_ITERS    = 1000;
constexpr int      RTT_TIMEOUT_MS   = 100;

}  // namespace braid
