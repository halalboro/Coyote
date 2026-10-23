/**
 * Coyote Example 16 - V80 200G DCMAC raw Ethernet echo
 *
 * Bring-up and monitoring tool. The datapath is entirely in hardware: the
 * vFPGA echoes received Ethernet frames back to the peer with the source and
 * destination MAC addresses swapped. This program only drives the control
 * register and reports what the counters say.
 *
 * Typical use:
 *   ./test --status              # is the MAC up? decode mac_status and stop
 *   ./test --echo --watch 30     # enable echo, poll counters for 30 s
 *   ./test --sink --watch 10     # accept and discard, to measure receive only
 *   ./test --gen 1000            # emit 1000 frames and report what came back
 *   ./test --mac                 # DCMAC PHY/MAC status, counters, segment monitor
 *   ./test --bench --force       # bounded-burst loss benchmark (opt-in; see below)
 *
 * Back-to-back loop test across two V80s:
 *   far side:   ./test --echo
 *   near side:  ./test --gen 1000 --clear
 * The near side should report gen_sent = tx_frames = rx_frames = 1000.
 *
 * SAFETY. Driving traffic through this bitstream's DCMAC RX path (which is
 * currently corrupting frames) has hard-wedged the host: a CSR MMIO access to a
 * wedged card stalls the CPU until the hardware watchdog resets the box, and an
 * unbounded generator burst left latched on re-wedges it on every reboot. This
 * tool is therefore safe-by-construction:
 *   - TX_BURST is always clamped (MAX_BURST); no path can free-run the generator.
 *   - An atexit + SIGINT/SIGTERM handler always stops the generator on the way
 *     out, so it can never be left latched if a run is interrupted.
 *   - --bench is OFF unless --force, fires only bounded self-terminating bursts,
 *     waits for each to drain before arming the next, and aborts the instant one
 *     fails to drain (the precursor to a wedge).
 * Genuine sustained line-rate benchmarking still needs a HW generator throttle
 * that this build does not have yet; until then the reported Gb/s is a low
 * duty-cycled rate and the meaningful numbers are the loss/runt fractions. In
 * loopback (const_loopback != 0) --bench measures the internal path on one card;
 * for a one-way two-card run, --bench on the sender and `--sink --watch N` on
 * the receiver.
 *
 * Every --gen run also reads the DCMAC's own statistics and the shell's
 * segment monitor around the burst and prints the frame count at each stage
 * of the path, so a loss is pinned to one stage (see report_stages()).
 *
 * Register map (see hw/src/vfpga_top.svh):
 *   0 CTRL RW   1 STATUS RO   2 RX_FRAMES RO   3 RX_BYTES RO
 *   4 TX_FRAMES RO   5 TX_BYTES RO   6 RX_FIRST RO   7 RX_RUNTS RO
 *   8 TX_BURST RW   9 GEN_SENT RO
 *   10 MREG_ADDR RW   11 MREG_WDATA RW   12 MREG_CMD W   13 MREG_RESP RO
 */

#include <iostream>
#include <iomanip>
#include <string>
#include <unistd.h>
#include <chrono>
#include <cstdio>
#include <csignal>
#include <cstdlib>

#include <boost/program_options.hpp>
#include <coyote/cThread.hpp>

namespace po = boost::program_options;

constexpr uint32_t DEFAULT_VFPGA_ID = 0;

constexpr uint32_t REG_CTRL      = 0;
constexpr uint32_t REG_STATUS    = 1;
constexpr uint32_t REG_RX_FRAMES = 2;
constexpr uint32_t REG_RX_BYTES  = 3;
constexpr uint32_t REG_TX_FRAMES = 4;
constexpr uint32_t REG_TX_BYTES  = 5;
constexpr uint32_t REG_RX_FIRST  = 6;
constexpr uint32_t REG_RX_RUNTS  = 7;
constexpr uint32_t REG_TX_BURST  = 8;
constexpr uint32_t REG_GEN_SENT  = 9;
constexpr uint32_t REG_MREG_ADDR = 10;
constexpr uint32_t REG_MREG_WDAT = 11;
constexpr uint32_t REG_MREG_CMD  = 12;
constexpr uint32_t REG_MREG_RESP = 13;

constexpr uint64_t CTRL_ECHO  = 1ULL << 0;
constexpr uint64_t CTRL_SINK  = 1ULL << 1;
constexpr uint64_t CTRL_CLEAR = 1ULL << 2;
constexpr uint64_t CTRL_GEN   = 1ULL << 3;

// The largest burst any single generate step is ever allowed to arm. The HW
// generator free-runs until gen_sent reaches TX_BURST, so an unbounded value
// (~0) can never self-terminate: if the host dies mid-run the generator stays
// latched in the FPGA and keeps hammering the (broken) RX path across reboots.
// Every path in this tool clamps TX_BURST to this, so a generate step always
// ends on its own.
constexpr uint64_t MAX_BURST = 1000000;

// Safety net so a generate run can never leave the FPGA generator latched on.
// g_thread/g_armed are set once a traffic mode actually starts the generator;
// stop_generator() (registered with atexit and called from the signal handler
// path) then pulses CTRL_CLEAR, which aborts the generator and zeroes the
// counters. Non-traffic modes (--status/--echo/--sink/--watch) never arm it, so
// their state is left untouched. g_stop lets long loops bail out on Ctrl-C.
static coyote::cThread*      g_thread = nullptr;
static bool                  g_armed  = false;
static volatile sig_atomic_t g_stop   = 0;

static void stop_generator() {
    if (g_thread && g_armed) {
        g_thread->setCSR(CTRL_CLEAR, REG_CTRL);
        g_thread->setCSR(0, REG_CTRL);
        g_armed = false;
    }
}

static void on_signal(int) { g_stop = 1; }

// dcmac_reset_ctrl.sv state encoding. ST_DONE is the steady state; anything
// else means the reset FSM is still sequencing, or stuck.
static const char* rst_state_name(unsigned s) {
    static const char* names[] = {
        "ST_INIT", "ST_RESET_GT_AND_AXIS", "ST_WAIT_GT_RST", "ST_WAIT_INT_1",
        "ST_RST_DCMAC_TX", "ST_RST_DCMAC_TX_WAIT_1", "ST_RST_DCMAC_TX_WAIT_2",
        "ST_RST_DCMAC_TX_WAIT_3", "ST_WAIT_INT_2", "ST_RST_DCMAC_RX",
        "ST_RST_DCMAC_RX_WAIT_1", "ST_RST_DCMAC_RX_WAIT_2",
        "ST_RST_DCMAC_RX_WAIT_3", "ST_DONE"
    };
    return (s < sizeof(names) / sizeof(names[0])) ? names[s] : "??";
}

static void dump_status(uint64_t status) {
    const unsigned mac      = status & 0xFF;
    const unsigned st       = mac & 0x1F;
    const bool rst_done     = (mac >> 5) & 0x1;
    const bool gt_done_tx   = (mac >> 6) & 0x1;
    const bool gt_done_rx   = (mac >> 7) & 0x1;

    std::cout << "MAC status (0x" << std::hex << mac << std::dec << ")\n"
              << "  reset FSM   : " << rst_state_name(st) << " (" << st << ")\n"
              << "  rst_done    : " << (rst_done   ? "yes" : "NO") << "\n"
              << "  gt_done_tx  : " << (gt_done_tx ? "yes" : "NO") << "\n"
              << "  gt_done_rx  : " << (gt_done_rx ? "yes" : "NO") << "\n"
              << "datapath\n"
              << "  tx_valid_q  : " << ((status >> 8)  & 0x1) << "\n"
              << "  sof         : " << ((status >> 9)  & 0x1) << "\n"
              << "  rx_tvalid   : " << ((status >> 10) & 0x1) << "\n"
              << "  tx_tready   : " << ((status >> 11) & 0x1) << "\n"
              << "  gen_run     : " << ((status >> 12) & 0x1) << "\n";

    if (!gt_done_tx || !gt_done_rx) {
        std::cout << "\n  The GT reset handshake has not completed. Check that the QSFP56\n"
                     "  module is seated and powered up (ami_tool on the V80 - the cage is\n"
                     "  owned by the AVED satellite controller, not the PL) and that the\n"
                     "  reference clock is present.\n";
    } else if (!rst_done) {
        std::cout << "\n  The transceivers came up but the DCMAC reset sequence did not finish.\n"
                     "  The state name above says how far it got.\n";
    }
}

static void dump_counters(coyote::cThread& t) {
    const uint64_t rx_frames = t.getCSR(REG_RX_FRAMES);
    const uint64_t rx_bytes  = t.getCSR(REG_RX_BYTES);
    const uint64_t tx_frames = t.getCSR(REG_TX_FRAMES);
    const uint64_t tx_bytes  = t.getCSR(REG_TX_BYTES);
    const uint64_t runts     = t.getCSR(REG_RX_RUNTS);
    const uint64_t first     = t.getCSR(REG_RX_FIRST);

    std::cout << "  rx: " << std::setw(12) << rx_frames << " frames, "
              << std::setw(14) << rx_bytes << " bytes"
              << "   tx: " << std::setw(12) << tx_frames << " frames, "
              << std::setw(14) << tx_bytes << " bytes"
              << "   runts: " << runts << "\n";

    if (rx_frames) {
        // Byte 0 of the frame is the low byte of the first beat.
        std::cout << "      last frame started with dst MAC ";
        for (int i = 0; i < 6; i++) {
            std::cout << std::hex << std::setw(2) << std::setfill('0')
                      << ((first >> (8 * i)) & 0xFF) << (i < 5 ? ":" : "");
        }
        std::cout << std::dec << std::setfill(' ') << "\n";
    }
}

// ---------------------------------------------------------------------------
// MAC register port
//
// One access at a time through MREG_*: below 0x100000 is the DCMAC's own
// register space (PG369), from 0x100000 the shell's segment monitor
// (hw/hdl/network/dcmac_cyt/dcmac_debug.sv). The shell answers every access,
// failing it with resp 3 after ~2.6 ms if the DCMAC does not respond, so these
// never hang; the poll limit here is only a second line of defence.
// ---------------------------------------------------------------------------
struct mreg_result { uint32_t data; unsigned resp; bool ok; };

static mreg_result mreg_access(coyote::cThread& t, bool wr, uint32_t addr, uint32_t wdata) {
    const uint64_t before = t.getCSR(REG_MREG_RESP);
    const uint16_t done0  = before >> 48;
    t.setCSR(addr, REG_MREG_ADDR);
    t.setCSR(wdata, REG_MREG_WDAT);
    t.setCSR(wr ? 1 : 0, REG_MREG_CMD);
    for (int i = 0; i < 2000; i++) {
        const uint64_t r = t.getCSR(REG_MREG_RESP);
        if (!((r >> 34) & 0x1) && (uint16_t)(r >> 48) != done0) {
            const unsigned resp = (r >> 32) & 0x3;
            return { (uint32_t)r, resp, resp == 0 };
        }
        if (i > 20) usleep(10);
    }
    return { 0, 0xF, false };
}

static uint32_t mreg_rd(coyote::cThread& t, uint32_t addr, bool* ok = nullptr) {
    mreg_result r = mreg_access(t, false, addr, 0);
    if (ok) *ok = r.ok;
    return r.data;
}

static bool mreg_wr(coyote::cThread& t, uint32_t addr, uint32_t data) {
    return mreg_access(t, true, addr, data).ok;
}

static uint64_t mreg_rd64(coyote::cThread& t, uint32_t lsb_addr) {
    const uint64_t lo = mreg_rd(t, lsb_addr);
    const uint64_t hi = mreg_rd(t, lsb_addr + 4);
    return (hi << 32) | lo;
}

// DCMAC register offsets, port/channel 0. Taken from AMD's sample driver that
// the IP generates (sample_c_files/dcmac_exdes_test.c).
constexpr uint32_t DC_TX_MODE         = 0x1040;
constexpr uint32_t DC_RX_MODE         = 0x1044;
constexpr uint32_t DC_PORT_TICK_RX    = 0x10F4;
constexpr uint32_t DC_PORT_TICK_TX    = 0x10FC;
constexpr uint32_t DC_TX_MAC_STATUS   = 0x1100;   // bit0 local fault
constexpr uint32_t DC_RX_MAC_STATUS   = 0x1140;   // bits[2:1] faults
constexpr uint32_t DC_TX_FEC_STATUS   = 0x180C;
constexpr uint32_t DC_RX_PHY_STATUS   = 0x1C00;   // bit0 rx_status, bit2 aligned
constexpr uint32_t DC_RX_FEC_STATUS   = 0x1C34;
constexpr uint32_t DC_STAT_TX_BASE    = 0x1200;   // TX statistics block
constexpr uint32_t DC_STAT_TX_END     = 0x1400;
constexpr uint32_t DC_STAT_RX_BASE    = 0x1400;   // RX statistics block
constexpr uint32_t DC_STAT_RX_END     = 0x1800;
constexpr uint32_t DC_STAT_TX_BYTES      = 0x1200;
constexpr uint32_t DC_STAT_TX_GOOD_BYTES = 0x1208;
constexpr uint32_t DC_STAT_TX_PKTS       = 0x1210;
constexpr uint32_t DC_STAT_TX_GOOD_PKTS  = 0x1218;
constexpr uint32_t DC_STAT_RX_BYTES      = 0x1400;
constexpr uint32_t DC_STAT_RX_GOOD_BYTES = 0x1408;
constexpr uint32_t DC_STAT_RX_PKTS       = 0x1410;
constexpr uint32_t DC_STAT_RX_GOOD_PKTS  = 0x1418;

// Segment monitor (dcmac_debug.sv)
constexpr uint32_t MON          = 0x100000;
constexpr uint32_t MON_ID       = MON + 0x000;
constexpr uint32_t MON_CTRL     = MON + 0x004;   // bit0 clear, bit1 TX tick, bit2 RX tick
constexpr uint32_t MON_DCLK     = MON + 0x008;
constexpr uint32_t MON_NCLK     = MON + 0x00C;
constexpr uint32_t MON_RX_VLD   = MON + 0x010;
constexpr uint32_t MON_RX_SOP   = MON + 0x014;
constexpr uint32_t MON_RX_EOP   = MON + 0x018;
constexpr uint32_t MON_RX_ERR   = MON + 0x01C;
constexpr uint32_t MON_RX_MSOP  = MON + 0x020;
constexpr uint32_t MON_RX_PROTO = MON + 0x024;
constexpr uint32_t MON_RX_SEGS  = MON + 0x028;
constexpr uint32_t MON_TX_VLD   = MON + 0x030;
constexpr uint32_t MON_TX_ACC   = MON + 0x034;
constexpr uint32_t MON_TX_SOP   = MON + 0x038;
constexpr uint32_t MON_TX_EOP   = MON + 0x03C;
constexpr uint32_t MON_TX_STALL = MON + 0x040;
constexpr uint32_t MON_TX_PROTO = MON + 0x044;
constexpr uint32_t MON_TX_SEGS  = MON + 0x048;
constexpr uint32_t MON_RX_CAPN  = MON + 0x04C;
constexpr uint32_t MON_BD_TXF   = MON + 0x050;
constexpr uint32_t MON_BD_TXB   = MON + 0x054;
constexpr uint32_t MON_BD_RXF   = MON + 0x058;
constexpr uint32_t MON_BD_RXB   = MON + 0x05C;
constexpr uint32_t MON_BD_RXSTL = MON + 0x060;
constexpr uint32_t MON_BD_TXSTL = MON + 0x064;
constexpr uint32_t MON_TX_CAPN  = MON + 0x068;
constexpr uint32_t MON_BD_RXERR = MON + 0x06C;
constexpr uint32_t MON_RX_CAP   = MON + 0x100;
constexpr uint32_t MON_TX_CAP   = MON + 0x140;
constexpr uint32_t MON_ID_VALUE = 0xDC4D0001;

static bool mon_present(coyote::cThread& t) {
    bool ok = false;
    const uint32_t id = mreg_rd(t, MON_ID, &ok);
    return ok && id == MON_ID_VALUE;
}

static void mon_ctrl_pulse(coyote::cThread& t, uint32_t bits) {
    mreg_wr(t, MON_CTRL, bits);
    usleep(1000);
    mreg_wr(t, MON_CTRL, 0);
    usleep(1000);
}

// DCMAC statistics latch on a "tick", which also zeroes the internal counters
// (PG369, Per-Port Statistics Monitoring). The tick comes either from the
// pm_tick pins or from the PORT_TICK registers, chosen by a mode bit this tool
// cannot name, so it does both, in a fixed order, and lets the caller work out
// which one took effect.
static void dcmac_tick_pin(coyote::cThread& t) { mon_ctrl_pulse(t, 0x6); }
static void dcmac_tick_reg(coyote::cThread& t) {
    mreg_wr(t, DC_PORT_TICK_TX, 1);
    mreg_wr(t, DC_PORT_TICK_RX, 1);
    usleep(1000);
}

struct dcmac_stats {
    uint64_t tx_pkts, tx_good_pkts, tx_bytes, tx_good_bytes;
    uint64_t rx_pkts, rx_good_pkts, rx_bytes, rx_good_bytes;
};

static dcmac_stats read_dcmac_stats(coyote::cThread& t) {
    dcmac_stats s;
    s.tx_pkts       = mreg_rd64(t, DC_STAT_TX_PKTS);
    s.tx_good_pkts  = mreg_rd64(t, DC_STAT_TX_GOOD_PKTS);
    s.tx_bytes      = mreg_rd64(t, DC_STAT_TX_BYTES);
    s.tx_good_bytes = mreg_rd64(t, DC_STAT_TX_GOOD_BYTES);
    s.rx_pkts       = mreg_rd64(t, DC_STAT_RX_PKTS);
    s.rx_good_pkts  = mreg_rd64(t, DC_STAT_RX_GOOD_PKTS);
    s.rx_bytes      = mreg_rd64(t, DC_STAT_RX_BYTES);
    s.rx_good_bytes = mreg_rd64(t, DC_STAT_RX_GOOD_BYTES);
    return s;
}

static uint64_t stats_activity(const dcmac_stats& s) {
    return s.tx_pkts + s.rx_pkts + s.tx_bytes + s.rx_bytes;
}

// Latch the counters accumulated since the previous tick and return them,
// trying the pin tick first and the register tick second. In pin mode the
// register tick does nothing and the first read already has the data; in
// register mode the pin tick does nothing and only the second read does. The
// second read is the one to use whenever the first shows no activity.
static dcmac_stats latch_dcmac_stats(coyote::cThread& t, const char** mode) {
    dcmac_tick_pin(t);
    dcmac_stats a = read_dcmac_stats(t);
    dcmac_tick_reg(t);
    dcmac_stats b = read_dcmac_stats(t);
    const bool pin_live = stats_activity(a) != 0;
    const bool reg_live = !pin_live && stats_activity(b) != 0;
    *mode = pin_live ? "pin" : (reg_live ? "register" : "no activity seen - mode unknown");
    return pin_live ? a : b;
}

// Print every nonzero 64-bit counter in a statistics block, by offset. The
// tool only names the eight counters in AMD's sample driver; anything else
// that moved (bad FCS, undersize, fragments, ...) shows up here by address,
// to be looked up in PG369.
static void dump_nonzero_stats(coyote::cThread& t, const char* tag, uint32_t base, uint32_t end) {
    std::cout << "  nonzero " << tag << " counters (offset: value):";
    unsigned n = 0;
    for (uint32_t a = base; a < end; a += 8) {
        bool ok = false;
        const uint64_t lo = mreg_rd(t, a, &ok);
        if (!ok) {
            std::cout << "\n    0x" << std::hex << a << std::dec << ": read failed, stopping";
            break;
        }
        const uint64_t hi = mreg_rd(t, a + 4);
        const uint64_t v = (hi << 32) | lo;
        if (v) {
            std::cout << (n % 4 == 0 ? "\n    " : "   ")
                      << "0x" << std::hex << a << std::dec << ": " << v;
            n++;
        }
    }
    std::cout << (n ? "\n" : " none\n");
}

// Status registers are latched-high and cleared by writing 1s (PG369, Status
// Registers), so each is read, cleared, and read again: the first value is
// "what happened since the last clear", the second is "what is true now".
static void dump_dcmac_status(coyote::cThread& t) {
    struct { const char* name; uint32_t addr; } regs[] = {
        { "RX_PHY_STATUS (bit0 rx_status, bit2 aligned)", DC_RX_PHY_STATUS },
        { "TX_MAC_STATUS (bit0 local fault)          ", DC_TX_MAC_STATUS },
        { "RX_MAC_STATUS (bits 1-2 faults)           ", DC_RX_MAC_STATUS },
        { "TX_FEC_STATUS                             ", DC_TX_FEC_STATUS },
        { "RX_FEC_STATUS                             ", DC_RX_FEC_STATUS },
    };
    std::cout << "DCMAC status (latched -> now):\n";
    for (auto& r : regs) {
        bool ok1 = false, ok2 = false;
        const uint32_t latched = mreg_rd(t, r.addr, &ok1);
        mreg_wr(t, r.addr, 0xFFFFFFFF);
        const uint32_t now = mreg_rd(t, r.addr, &ok2);
        std::cout << "  " << r.name << " 0x" << std::hex << std::setw(8) << std::setfill('0')
                  << latched << " -> 0x" << std::setw(8) << now << std::dec << std::setfill(' ')
                  << ((ok1 && ok2) ? "" : "   (access failed)") << "\n";
    }
    std::cout << "  TX_MODE 0x" << std::hex << mreg_rd(t, DC_TX_MODE)
              << "  RX_MODE 0x" << mreg_rd(t, DC_RX_MODE) << std::dec << "\n";
}

// One capture entry is a byte per segment: {ena, sop, eop, err, mty[3:0]}.
static void dump_capture(coyote::cThread& t, const char* tag, uint32_t base, uint32_t n) {
    if (n > 16) n = 16;
    std::cout << "  " << tag << " capture, first " << n << " cycles (seg0..seg3; S=sop E=eop !=err mN=empty bytes):\n";
    for (uint32_t i = 0; i < n; i++) {
        const uint32_t e = mreg_rd(t, base + 4 * i);
        std::cout << "    [" << std::setw(2) << i << "]";
        for (int sgm = 0; sgm < 4; sgm++) {
            const uint32_t b = (e >> (8 * sgm)) & 0xFF;
            const bool ena = b & 0x80, sop = b & 0x40, eop = b & 0x20, err = b & 0x10;
            const unsigned mty = b & 0xF;
            std::string c;
            if (!ena) c = "  .   ";
            else {
                c  = sop ? "S" : "-";
                c += eop ? "E" : "-";
                c += err ? "!" : " ";
                c += eop ? ("m" + std::to_string(mty)) : "  ";
                while (c.size() < 6) c += " ";
            }
            std::cout << "  " << c;
        }
        std::cout << "\n";
    }
}

struct mon_counts {
    uint32_t dclk, rx_vld, rx_sop, rx_eop, rx_err, rx_msop, rx_proto, rx_segs;
    uint32_t tx_vld, tx_acc, tx_sop, tx_eop, tx_stall, tx_proto, tx_segs;
    uint32_t rx_capn, tx_capn, bd_txf, bd_txb, bd_rxf, bd_rxb, bd_rxstl, bd_txstl, bd_rxerr;
};

static mon_counts read_mon(coyote::cThread& t) {
    mon_counts m;
    m.dclk = mreg_rd(t, MON_DCLK);
    m.rx_vld = mreg_rd(t, MON_RX_VLD);     m.rx_sop = mreg_rd(t, MON_RX_SOP);
    m.rx_eop = mreg_rd(t, MON_RX_EOP);     m.rx_err = mreg_rd(t, MON_RX_ERR);
    m.rx_msop = mreg_rd(t, MON_RX_MSOP);   m.rx_proto = mreg_rd(t, MON_RX_PROTO);
    m.rx_segs = mreg_rd(t, MON_RX_SEGS);
    m.tx_vld = mreg_rd(t, MON_TX_VLD);     m.tx_acc = mreg_rd(t, MON_TX_ACC);
    m.tx_sop = mreg_rd(t, MON_TX_SOP);     m.tx_eop = mreg_rd(t, MON_TX_EOP);
    m.tx_stall = mreg_rd(t, MON_TX_STALL); m.tx_proto = mreg_rd(t, MON_TX_PROTO);
    m.tx_segs = mreg_rd(t, MON_TX_SEGS);
    m.rx_capn = mreg_rd(t, MON_RX_CAPN);   m.tx_capn = mreg_rd(t, MON_TX_CAPN);
    m.bd_txf = mreg_rd(t, MON_BD_TXF);     m.bd_txb = mreg_rd(t, MON_BD_TXB);
    m.bd_rxf = mreg_rd(t, MON_BD_RXF);     m.bd_rxb = mreg_rd(t, MON_BD_RXB);
    m.bd_rxstl = mreg_rd(t, MON_BD_RXSTL); m.bd_txstl = mreg_rd(t, MON_BD_TXSTL);
    m.bd_rxerr = mreg_rd(t, MON_BD_RXERR);
    return m;
}

// Zero everything that report_stages() compares, before a burst.
static void arm_stage_counters(coyote::cThread& t) {
    mon_ctrl_pulse(t, 0x1);     // monitor counters + re-arm captures
    dcmac_tick_pin(t);          // zero the DCMAC's internal counters,
    dcmac_tick_reg(t);          // whichever tick mode it is in
}

// The frame count at every observation point, in path order, and the first
// stage that comes up short of what the generator sent.
static void report_stages(coyote::cThread& t, uint64_t sent) {
    const char* tick_mode = "";
    const dcmac_stats d = latch_dcmac_stats(t, &tick_mode);
    const mon_counts m = read_mon(t);
    const uint64_t vf_tx = t.getCSR(REG_TX_FRAMES);
    const uint64_t vf_rx = t.getCSR(REG_RX_FRAMES);

    struct stage { const char* name; uint64_t frames; const char* note; };
    const stage st[] = {
        { "vFPGA generator (gen_sent)          ", sent,           "" },
        { "vFPGA TX handshakes (tx_frames)     ", vf_tx,          "" },
        { "shell -> block design (BD_TX_FRAMES)", m.bd_txf,       "after the min-frame padder" },
        { "DCMAC TX pins, EOPs (seg monitor)   ", m.tx_eop,       "after tx FIFO + axis_to_dcmac_seg" },
        { "DCMAC STAT_TX_TOTAL_PACKETS         ", d.tx_pkts,      "the MAC's own count" },
        { "DCMAC STAT_RX_TOTAL_PACKETS         ", d.rx_pkts,      "after PHY / loopback" },
        { "DCMAC STAT_RX_TOTAL_GOOD_PACKETS    ", d.rx_good_pkts, "minus FCS/length errors" },
        { "DCMAC RX pins, EOPs (seg monitor)   ", m.rx_eop,       "what the MAC handed out" },
        { "block design -> shell (BD_RX_FRAMES)", m.bd_rxf,       "after seg->axis, dwidth, rx FIFO" },
        { "vFPGA RX (rx_frames)                ", vf_rx,          "after the aclk crossing" },
    };

    std::cout << "\nStage-by-stage frame count (sent " << sent << ", DCMAC tick mode: "
              << tick_mode << "):\n";
    const stage* first_short = nullptr;
    for (const auto& s : st) {
        const bool short_ = s.frames < sent;
        if (short_ && !first_short) first_short = &s;
        std::cout << "  " << s.name << " " << std::setw(10) << s.frames
                  << (s.frames == sent ? "  ok " : (short_ ? "  LOW" : "  HIGH"))
                  << "   " << s.note << "\n";
    }

    std::cout << "\n  TX pins: sop " << m.tx_sop << ", eop " << m.tx_eop << ", valid cycles " << m.tx_vld
              << ", accepted " << m.tx_acc << ", stalled " << m.tx_stall
              << ", framing violations " << m.tx_proto << ", segments " << m.tx_segs << "\n";
    std::cout << "  RX pins: sop " << m.rx_sop << ", eop " << m.rx_eop << ", eop+err " << m.rx_err
              << ", multi-sop cycles " << m.rx_msop << ", framing violations " << m.rx_proto
              << ", segments " << m.rx_segs << "\n";
    std::cout << "  BD RX: frames with tuser err " << m.bd_rxerr << ", beats " << m.bd_rxb
              << ", stall cycles " << m.bd_rxstl << "   BD TX: beats " << m.bd_txb
              << ", stall cycles " << m.bd_txstl << "\n";
    std::cout << "  DCMAC bytes: tx " << d.tx_bytes << " (good " << d.tx_good_bytes << "), rx "
              << d.rx_bytes << " (good " << d.rx_good_bytes << "), tx good pkts " << d.tx_good_pkts << "\n";

    dump_capture(t, "TX", MON_TX_CAP, m.tx_capn);
    dump_capture(t, "RX", MON_RX_CAP, m.rx_capn);

    if (first_short) {
        std::cout << "\n  First stage short of " << sent << ": " << first_short->name << "\n";
    } else {
        std::cout << "\n  Every stage saw all " << sent << " frames.\n";
    }
    if (m.tx_proto || m.rx_proto)
        std::cout << "  Framing violations on the segmented interface - see the captures above.\n";
    if (m.rx_err || m.bd_rxerr)
        std::cout << "  The MAC flagged received frames as errored (tuser_err); they still reach\n"
                     "  the vFPGA, because the 512-bit stream carries no error bit.\n";
}

// --mac: everything the MAC knows, with no traffic.
static void report_mac(coyote::cThread& t) {
    if (!mon_present(t)) {
        std::cout << "\nThe MAC register port does not answer (no segment monitor ID). This\n"
                     "bitstream predates it, or the shell is not a Versal DCMAC build.\n";
        return;
    }
    std::cout << "\n";
    dump_dcmac_status(t);
    const char* mode = "";
    latch_dcmac_stats(t, &mode);
    std::cout << "DCMAC statistics since the previous tick (tick mode: " << mode << "):\n";
    dump_nonzero_stats(t, "TX", DC_STAT_TX_BASE, DC_STAT_TX_END);
    dump_nonzero_stats(t, "RX", DC_STAT_RX_BASE, DC_STAT_RX_END);
    const mon_counts m = read_mon(t);
    std::cout << "Segment monitor (since its last clear): dclk " << m.dclk
              << "\n  TX: eop " << m.tx_eop << ", sop " << m.tx_sop << ", framing violations " << m.tx_proto
              << "\n  RX: eop " << m.rx_eop << ", sop " << m.rx_sop << ", eop+err " << m.rx_err
              << ", framing violations " << m.rx_proto
              << "\n  BD: tx frames " << m.bd_txf << ", rx frames " << m.bd_rxf
              << ", rx frames with err " << m.bd_rxerr << "\n";
    dump_capture(t, "TX", MON_TX_CAP, m.tx_capn);
    dump_capture(t, "RX", MON_RX_CAP, m.rx_capn);
}

// A point-in-time read of the counters plus a monotonic timestamp, so rates
// can be computed from the difference of two samples.
struct cnt_sample {
    uint64_t gen_sent, tx_frames, tx_bytes, rx_frames, rx_bytes, runts, first;
    double   t;  // seconds since the reference point
};

static cnt_sample take_sample(coyote::cThread& t,
                              std::chrono::steady_clock::time_point ref) {
    cnt_sample s;
    s.gen_sent  = t.getCSR(REG_GEN_SENT);
    s.tx_frames = t.getCSR(REG_TX_FRAMES);
    s.tx_bytes  = t.getCSR(REG_TX_BYTES);
    s.rx_frames = t.getCSR(REG_RX_FRAMES);
    s.rx_bytes  = t.getCSR(REG_RX_BYTES);
    s.runts     = t.getCSR(REG_RX_RUNTS);
    s.first     = t.getCSR(REG_RX_FIRST);
    s.t = std::chrono::duration<double>(std::chrono::steady_clock::now() - ref).count();
    return s;
}

// Rate/loss line for the delta between two samples. Frame loss is relative to
// what was transmitted; the runt fraction is relative to what was received.
static void report_window(const char* tag, const cnt_sample& a, const cnt_sample& b) {
    const double   dt    = b.t - a.t;
    const uint64_t dtxf  = b.tx_frames - a.tx_frames;
    const uint64_t drxf  = b.rx_frames - a.rx_frames;
    const uint64_t dtxb  = b.tx_bytes  - a.tx_bytes;
    const uint64_t drxb  = b.rx_bytes  - a.rx_bytes;
    const uint64_t drunt = b.runts     - a.runts;

    const double txg   = dt > 0 ? (dtxb * 8.0) / dt / 1e9 : 0.0;
    const double rxg   = dt > 0 ? (drxb * 8.0) / dt / 1e9 : 0.0;
    const double loss  = dtxf ? 100.0 * (double)((int64_t)dtxf - (int64_t)drxf) / (double)dtxf : 0.0;
    const double runtp = drxf ? 100.0 * (double)drunt / (double)drxf : 0.0;

    std::cout << "  " << tag
              << "  tx "   << std::fixed << std::setprecision(1) << std::setw(6) << txg << " Gb/s"
              << "  rx "   << std::setw(6) << rxg << " Gb/s"
              << "  loss " << std::setprecision(2) << std::setw(7) << loss << " %"
              << "  runts " << std::setw(6) << runtp << " %"
              << std::setprecision(1) << "\n";
}

// Repeated bounded-burst benchmark. Reached only via --force (see main).
//
// SAFETY: this deliberately does NOT free-run the generator. Holding this
// bitstream at continuous line rate drove the (known-broken) RX datapath into a
// wedge and took the host down with it - a CSR MMIO access to a wedged card
// faults the host. Instead it fires bounded, self-terminating bursts (the
// clamped --gen profile) and WAITS for each one to drain before arming the
// next, so a slow/stuck path can never silently turn this back into a
// continuous run. The moment a burst fails to drain within the timeout it
// stops, and Ctrl-C / exit always stops the generator.
//
// Trade-off: it measures loss and runt FRACTION over many frames, not true
// line-rate throughput (the reported Gb/s is the low duty-cycled offered rate,
// not link capacity). Genuine sustained benchmarking needs the HW generator
// throttle (GEN_GAP), which this bitstream does not have yet. Returns an exit
// code.
static int run_bench(coyote::cThread& t, unsigned warmup, unsigned window, uint64_t burst) {
    if (burst == 0) burst = 1000;
    if (burst > MAX_BURST) burst = MAX_BURST;   // never free-run

    // Arm the safety net: from here on, any exit (normal, Ctrl-C, exception)
    // pulses CTRL_CLEAR and stops the generator.
    g_armed = true;

    // Zero the counters once; bursts accumulate into them and we read deltas.
    t.setCSR(CTRL_CLEAR, REG_CTRL);
    t.setCSR(0, REG_CTRL);

    auto elapsed = [](std::chrono::steady_clock::time_point r) {
        return std::chrono::duration<double>(std::chrono::steady_clock::now() - r).count();
    };

    // Fire one bounded burst and WAIT for it to finish before returning, so the
    // next burst can never re-arm while this one is still draining (that is what
    // silently turned the old version back into a continuous free-run). Returns
    // false if the burst did not complete within the timeout - i.e. the transmit
    // path is not draining, the exact precursor to a wedge - so the caller stops
    // rather than keep hammering.
    auto fire_burst = [&](uint64_t b) -> bool {
        t.setCSR(b, REG_TX_BURST);
        t.setCSR(CTRL_SINK | CTRL_GEN, REG_CTRL);
        t.setCSR(CTRL_SINK, REG_CTRL);
        for (int i = 0; i < 200 && !g_stop; i++) {
            if (t.getCSR(REG_GEN_SENT) >= b && !((t.getCSR(REG_STATUS) >> 12) & 0x1))
                return true;
            usleep(1000);
        }
        return false;
    };

    const double total = (double)warmup + (double)window;

    std::cout << "\nBounded-burst benchmark: " << warmup << " s warmup + " << window
              << " s measurement, self-terminating bursts of " << burst << " frames.\n"
                 "Each burst completes before the next is armed; Ctrl-C stops cleanly.\n"
                 "Gb/s is the duty-cycled offered rate, not link capacity:\n";

    const auto ref = std::chrono::steady_clock::now();
    cnt_sample prev = take_sample(t, ref);
    cnt_sample meas_start = prev;   // if warmup == 0, baseline is the start
    bool warm_done = (warmup == 0);
    bool stalled   = false;
    unsigned tick = 1;

    while (elapsed(ref) < total && !g_stop) {
        if (!fire_burst(burst)) { stalled = true; break; }
        const double now = elapsed(ref);
        if (now >= (double)tick && tick <= warmup + window) {
            cnt_sample cur = take_sample(t, ref);
            char tag[8];
            std::snprintf(tag, sizeof(tag), "%c%3u", (tick <= warmup) ? 'W' : ' ', tick);
            report_window(tag, prev, cur);
            if (!warm_done && now >= (double)warmup) { meas_start = cur; warm_done = true; }
            prev = cur;
            tick++;
        }
    }

    if (stalled)
        std::cout << "\n  A burst did not drain within the timeout - stopping to avoid wedging\n"
                     "  the card. The transmit path is stuck (broken RX back-pressure).\n";
    else if (g_stop)
        std::cout << "\n  Interrupted - stopping the generator.\n";

    // Sample before clearing: CTRL_CLEAR also zeroes the hardware counters.
    const cnt_sample meas_end = take_sample(t, ref);

    // Generator is already idle between bursts; clear to be certain and reset.
    t.setCSR(CTRL_CLEAR, REG_CTRL);
    t.setCSR(0, REG_CTRL);
    g_armed = false;   // generator stopped: disarm the atexit net before `t`
                       // (which g_thread points at) is destroyed on return.

    // Summary over the measurement window only.
    const double   dt   = meas_end.t - meas_start.t;
    const uint64_t dtxf = meas_end.tx_frames - meas_start.tx_frames;
    const uint64_t drxf = meas_end.rx_frames - meas_start.rx_frames;
    const uint64_t dtxb = meas_end.tx_bytes  - meas_start.tx_bytes;
    const uint64_t drxb = meas_end.rx_bytes  - meas_start.rx_bytes;
    const uint64_t drun = meas_end.runts     - meas_start.runts;

    std::cout << "\nMeasurement window (" << std::setprecision(2) << dt << " s, warmup discarded):\n";
    report_window("   ", meas_start, meas_end);
    std::cout << "    tx frames " << dtxf << ", rx frames " << drxf
              << ", runts " << drun << "\n";
    if (drxf) {
        std::cout << "    mean rx frame " << std::setprecision(1)
                  << (double)drxb / (double)drxf << " bytes (sent 64)\n";
        std::cout << "    last rx dst MAC ";
        for (int i = 0; i < 6; i++)
            std::cout << std::hex << std::setw(2) << std::setfill('0')
                      << ((meas_end.first >> (8 * i)) & 0xFF) << (i < 5 ? ":" : "");
        std::cout << std::dec << std::setfill(' ') << "\n";
    }

    const double loss = dtxf ? 100.0 * (double)((int64_t)dtxf - (int64_t)drxf) / (double)dtxf : 0.0;
    if (dtxf == 0) {
        std::cout << "\n  Generator transmitted nothing - transmit path is not draining.\n";
    } else if (drxf == 0) {
        std::cout << "\n  Nothing received. In loopback this means the internal RX path is dead;\n"
                     "  across two cards, check the far side and the cable.\n";
    } else if (loss < 1.0 && drun == 0) {
        std::cout << "\n  Clean across every burst. The frame loss in the one-shot --gen test\n"
                     "  was not reproducible at scale.\n";
    } else {
        std::cout << "\n  Loss/runts are significant and persist across many independent bursts -\n"
                     "  this is real corruption in the RX path, not a one-shot artifact. Compare\n"
                     "  the per-second lines: a stable fraction means it never recovers.\n";
    }
    return 0;
}

int main(int argc, char* argv[]) {
    po::options_description opts("Coyote Example 16: DCMAC raw Ethernet echo");
    opts.add_options()
        ("help,h",   "show this message")
        ("status,s", "decode the MAC bring-up status and exit")
        ("mac,m",    "dump the DCMAC's PHY/MAC status, statistics and the segment monitor, then exit")
        ("echo,e",   "enable the MAC-swap echo")
        ("sink",     "accept and discard frames instead of echoing")
        ("off",      "disable both echo and sink, leaving the receive path stalled")
        ("gen,g",    po::value<uint64_t>()->default_value(0), "emit N generated frames, then report")
        ("bench,b",  "bounded-burst throughput+loss benchmark (OFF unless --force; can wedge a broken card)")
        ("force",    "allow --bench to emit traffic despite the wedge risk")
        ("secs",     po::value<unsigned>()->default_value(10), "benchmark measurement window (s)")
        ("warmup",   po::value<unsigned>()->default_value(2),  "benchmark warmup to discard (s)")
        ("burst",    po::value<uint64_t>()->default_value(1000), "frames per bounded burst in --bench (capped)")
        ("clear,c",  "clear the counters before starting")
        ("watch,w",  po::value<unsigned>()->default_value(0), "poll the counters for N seconds")
        ("vfpga",    po::value<uint32_t>()->default_value(DEFAULT_VFPGA_ID), "vFPGA id");

    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, opts), vm);
    po::notify(vm);

    if (vm.count("help")) {
        std::cout << opts << "\n";
        return 0;
    }

    coyote::cThread t(vm["vfpga"].as<uint32_t>(), getpid());

    // Safety net: no matter how this process ends (normal return, Ctrl-C, a
    // thrown exception that unwinds through exit), the generator is stopped if a
    // traffic mode armed it, so it can never be left latched in the FPGA.
    g_thread = &t;
    std::atexit(stop_generator);
    std::signal(SIGINT,  on_signal);
    std::signal(SIGTERM, on_signal);

    const uint64_t status = t.getCSR(REG_STATUS);
    dump_status(status);

    if (vm.count("status")) {
        return 0;
    }

    // Register reads only, plus the write-1-to-clear of the status latches
    // and the statistics ticks; no traffic. Works even if the MAC never left
    // reset, which is when its registers matter most.
    if (vm.count("mac")) {
        report_mac(t);
        return 0;
    }

    const bool mac_ready = (status >> 5) & 0x1;
    if (!mac_ready) {
        std::cout << "\nRefusing to start traffic: the MAC is not out of reset.\n"
                     "Re-run with --status once the link is up.\n";
        return 1;
    }

    // The benchmark owns the control register for its whole run (clear, start,
    // sample, stop), so it is handled before the one-shot ctrl logic below.
    //
    // It is OFF by default. Driving repeated traffic through this bitstream's RX
    // path (which is currently corrupting frames) has hard-wedged the host, and
    // no amount of pacing in software is guaranteed safe until the hardware
    // carries a generator throttle. --bench therefore refuses without an
    // explicit --force, and even with --force it only ever fires bounded,
    // self-terminating bursts that stop the moment one fails to drain.
    if (vm.count("bench")) {
        if (!vm.count("force")) {
            std::cout << "\n--bench is disabled by default on this bitstream.\n"
                         "Repeated generation into the DCMAC RX path has wedged the host; safe\n"
                         "benchmarking needs a hardware generator throttle that this build does\n"
                         "not have yet. For a single safe probe use:  ./test --gen 1000\n"
                         "To run bounded, self-terminating bursts anyway, re-run with --force.\n";
            return 1;   // no traffic, generator never armed
        }
        return run_bench(t, vm["warmup"].as<unsigned>(), vm["secs"].as<unsigned>(),
                         vm["burst"].as<uint64_t>());
    }

    if (vm.count("clear")) {
        t.setCSR(CTRL_CLEAR, REG_CTRL);
        t.setCSR(0, REG_CTRL);
    }

    uint64_t burst = vm["gen"].as<uint64_t>();
    if (burst > MAX_BURST) {
        std::cout << "--gen capped to " << MAX_BURST << " frames (was " << burst
                  << "); an unbounded burst can latch the generator on.\n";
        burst = MAX_BURST;
    }

    uint64_t ctrl = 0;
    if (vm.count("echo")) ctrl |= CTRL_ECHO;
    if (vm.count("sink")) ctrl |= CTRL_SINK;
    if (vm.count("off"))  ctrl = 0;

    // Generating implies sink mode, and it matters. gen_run forces the receive
    // path to accept only while the burst is running; the echoed frames come
    // back after it ends, by which point acceptance would fall back to
    // echo_en && out_free. Without sink that is 0, so the returning frames
    // would sit unread in the FIFO and rx_frames would stay near zero --
    // indistinguishable from a dead link. Sink keeps tready high so they are
    // counted, and suppresses echoing them back into an endless loop.
    if (burst) {
        if (vm.count("echo")) {
            std::cout << "Note: --echo is ignored while generating; a generator that also\n"
                         "      echoed what came back would loop forever.\n";
        }
        ctrl = (ctrl & ~CTRL_ECHO) | CTRL_SINK;
    }

    t.setCSR(ctrl, REG_CTRL);
    const uint64_t readback = t.getCSR(REG_CTRL);
    if (readback != ctrl) {
        std::cout << "\nCTRL wrote 0x" << std::hex << ctrl << " but read back 0x"
                  << readback << std::dec << " - the CSR write path is broken.\n";
        return 1;
    }

    std::cout << "\nCTRL = 0x" << std::hex << ctrl << std::dec
              << (ctrl & CTRL_SINK ? "  (sink)" : (ctrl & CTRL_ECHO ? "  (echo)" : "  (idle)"))
              << "\n";

    // Generate a burst. CTRL bit3 is edge-triggered in hardware, so it is
    // pulsed rather than left set; that also lets the command be repeated.
    if (burst) {
        t.setCSR(burst, REG_TX_BURST);
        if (t.getCSR(REG_TX_BURST) != burst) {
            std::cout << "TX_BURST did not read back; CSR write path is broken.\n";
            return 1;
        }

        // Zero the DCMAC statistics and the segment monitor so the stage
        // report below covers exactly this burst.
        const bool have_mon = mon_present(t);
        if (have_mon) {
            arm_stage_counters(t);
        } else {
            std::cout << "(no MAC register port in this bitstream - stage report skipped)\n";
        }

        std::cout << "Generating " << burst << " frames...\n";
        g_armed = true;   // generator about to start: arm the stop-on-exit net
        t.setCSR(ctrl | CTRL_GEN, REG_CTRL);
        t.setCSR(ctrl, REG_CTRL);

        // The burst is bounded by line rate, so this converges quickly; the
        // cap just stops us hanging if the transmit path never drains, and
        // Ctrl-C breaks out immediately.
        uint64_t sent = 0;
        for (int i = 0; i < 1000 && !g_stop; i++) {
            sent = t.getCSR(REG_GEN_SENT);
            if (sent >= burst && !((t.getCSR(REG_STATUS) >> 12) & 0x1)) break;
            usleep(1000);
        }

        std::cout << "  gen_sent = " << sent << " / " << burst
                  << (sent >= burst ? "" : "   <-- generator stalled, transmit path is not draining")
                  << "\n";

        // Give the far side time to turn the frames around before counting.
        usleep(200000);
        dump_counters(t);

        const uint64_t rx = t.getCSR(REG_RX_FRAMES);
        if (rx == 0) {
            std::cout << "\nNothing came back. Check that the far side has echo enabled\n"
                         "(./test --echo), that both ends are on the same QSFP cage, and\n"
                         "that the cable is seated.\n";
        } else if (rx < burst) {
            std::cout << "\nOnly " << rx << " of " << burst << " frames returned.\n";
        } else {
            std::cout << "\nAll " << burst << " frames returned.\n";
        }

        if (have_mon) {
            report_stages(t, sent);
        }

        // Stop the generator and disarm the atexit net before returning. `t`
        // (which g_thread points at) is destroyed when main returns, so the
        // handler must not fire against it - that dangling setCSR() was the
        // post-report segfault. Clearing here also covers a Ctrl-C mid-burst,
        // where we broke out of the poll loop with the generator still running.
        t.setCSR(CTRL_CLEAR, REG_CTRL);
        t.setCSR(0, REG_CTRL);
        g_armed = false;
        return 0;
    }

    const unsigned secs = vm["watch"].as<unsigned>();
    for (unsigned i = 0; i < secs; i++) {
        sleep(1);
        std::cout << "[" << std::setw(4) << (i + 1) << "s]";
        dump_counters(t);
    }
    if (secs == 0) {
        dump_counters(t);
    }

    return 0;
}
