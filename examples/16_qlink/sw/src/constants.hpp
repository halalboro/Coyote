/**
 * Coyote Example 16: QLINK — shared constants (Phase A)
 *
 * Mirrors the register map in hw/src/vfpga_top.svh. Nothing enforces that
 * at build time, so if you change one, change the other.
 */

#pragma once

#include <cstdint>

namespace qlink {

constexpr uint32_t VFPGA_ID = 0;

// aclk drives the CSR block only. Every number the host reads from a counter
// (INTERVAL, RTT_CYCLES) is counted in the GT transmit clock, because that is
// where the datapath lives.
constexpr double   ACLK_MHZ  = 400.0;
// Raw-mode GT: 12.5 Gbps / 32-bit datapath = 390.625 MHz. See
// scripts/ip_inst/qlink_infrastructure.tcl.
constexpr double   TXCLK_MHZ = 390.625;

namespace reg {
constexpr uint32_t CTRL        = 0;    // RW
constexpr uint32_t STATUS      = 1;    // RO
constexpr uint32_t N_ROUNDS    = 2;    // RW
constexpr uint32_t INTERVAL    = 3;    // RW, tx_clk cycles between generated rounds
constexpr uint32_t TX_FRAMES   = 4;    // RO
constexpr uint32_t TX_DROPPED  = 5;    // RO
constexpr uint32_t RX_FRAMES   = 6;    // RO
constexpr uint32_t RX_ERRORS   = 7;    // RO: CRC / length / PHY
constexpr uint32_t RX_MISMATCH = 8;    // RO: payload != pattern(round)
constexpr uint32_t LAST_ROUND  = 9;    // RO
constexpr uint32_t LAST_TYPE   = 10;   // RO: §4 TYPE of last good frame
constexpr uint32_t RTT_CYCLES  = 11;   // RO
constexpr uint32_t LOOPBACK    = 12;   // RW
constexpr uint32_t SCRATCH     = 13;
}

namespace ctrl {
constexpr uint64_t RUN   = 1ULL << 0;  // run the generator
constexpr uint64_t ARM   = 1ULL << 1;  // arm the checker
constexpr uint64_t CLEAR = 1ULL << 2;  // clear counters
constexpr uint64_t ECHO  = 1ULL << 3;  // reflect received frames back
}

// GT loopback select (UG578 LOOPBACK[2:0]). NEAR_PMA splits the latency
// budget without a second bitstream.
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

// §4 traffic classes. Must match TYPE_* localparams in vfpga_top.svh.
namespace type {
constexpr uint8_t SYN = 1;
constexpr uint8_t FRM = 2;
constexpr uint8_t FUS = 3;
constexpr uint8_t CTL = 4;
}

constexpr uint64_t DEFAULT_ROUNDS   = 100000;
constexpr uint64_t DEFAULT_INTERVAL = 391;    // 391 tx_clk @ 390.625 MHz = 1 us
constexpr int      LINK_TIMEOUT_MS  = 5000;

// Phase A: frame is fixed at 64 bytes.
constexpr uint32_t FRAME_BYTES      = 64;
constexpr uint32_t PAYLOAD_BYTES    = 52;
constexpr uint64_t DEFAULT_ITERS    = 1000;
constexpr int      RTT_TIMEOUT_MS   = 100;

// qlink clock: generator emits one frame every INTERVAL+1 tx_clk cycles; count
// frames against the host clock to measure the actual GT user clock.
constexpr uint64_t CLOCK_INTERVAL = 10000;
constexpr int      CLOCK_SECONDS  = 3;

// Candidate frequencies for the clock check. At 12.5 Gbps the natural
// reference is 156.25 MHz x 80, giving 390.625 MHz. The 16.1133 point is left
// in because an Aurora bitstream nearby declares that reference and surprises
// have reached hardware before.
constexpr double TXCLK_IF_12500_MHZ = 390.625;    // refclk 156.25,       x80
constexpr double TXCLK_IF_16113_MHZ = 402.832;    // refclk 161.1328125,  x100

}  // namespace qlink
