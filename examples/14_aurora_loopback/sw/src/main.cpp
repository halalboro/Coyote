/**
 * Coyote Example 14: Aurora 64B/66B FPGA-to-FPGA Loopback — host app
 *
 * Usage:  sudo ./test <mode> [options]
 *
 *   rx      arm the receiver and count incoming beats
 *   tx      send one burst
 *   echo    reflect everything received back out (run on the far card)
 *   bench   round-trip latency sweep across transfer sizes
 *
 * Data test:        ./test rx        on one card,  ./test tx    on the other
 * Latency sweep:    ./test echo      on one card,  ./test bench on the other
 *
 * Every mode first checks that host CSR writes actually reach the vFPGA. That
 * check exists because a broken AXI4-Lite write path once made a working link
 * look like a dead one for an entire debugging session.
 */

#include <algorithm>
#include <bitset>
#include <chrono>
#include <iomanip>
#include <iostream>
#include <string>
#include <thread>
#include <vector>
#include <unistd.h>
#include <boost/program_options.hpp>

#include <coyote/cThread.hpp>

#include "constants.hpp"

namespace po = boost::program_options;
using namespace aurora;

// ---------------------------------------------------------------- helpers

static void print_status(uint64_t s) {
    std::cout << "  channel_up=" << ((s >> status::CHANNEL_UP) & 1)
              << " lane_up="     << std::bitset<4>((s >> status::LANE_UP_LSB) & 0xF)
              << " tx_done="     << ((s >> status::TX_DONE) & 1)
              << " rx_done="     << ((s >> status::RX_DONE) & 1) << "\n";
}

// `tx_side` gates the interpretation hints: on a receiver, tx_start is meant to
// be low, so the TX diagnostics would otherwise emit a confidently wrong answer.
static void print_dbg(coyote::cThread& t, bool tx_side) {
    uint64_t d = t.getCSR(reg::TX_DBG);
    auto bit = [&](int b) { return (d >> b) & 0x1; };
    std::cout << "--- debug ---\n"
              << "  TX_DBG=0x" << std::hex << d << std::dec
              << "  tx_beat_idx=" << t.getCSR(reg::TX_BEAT_IDX) << "\n"
              << "  tx_start="      << bit(dbg::TX_START)
              << " tx_running="     << bit(dbg::TX_RUNNING)
              << " tx_done="        << bit(dbg::TX_DONE)
              << " aurora_tready="  << bit(dbg::AURORA_TREADY) << "\n"
              << "  rx_arm="        << bit(dbg::RX_ARM)
              << " rx_done="        << bit(dbg::RX_DONE) << "\n"
              << "  sticky: tready=" << bit(dbg::STK_TREADY)
              << " tx_handshake="    << bit(dbg::STK_TX_HANDSHAKE)
              << " rx_tvalid="       << bit(dbg::STK_RX_TVALID)
              << " rx_tlast="        << bit(dbg::STK_RX_TLAST) << "\n";

    if (tx_side) {
        if (!bit(dbg::TX_START))              std::cout << "  >> tx_start low: CTRL write did not land.\n";
        else if (!bit(dbg::STK_TREADY))       std::cout << "  >> Aurora never asserted tready: TX stalled.\n";
        else if (!bit(dbg::STK_TX_HANDSHAKE)) std::cout << "  >> tready but no handshake: check channel_up.\n";
    } else {
        if (!bit(dbg::STK_RX_TVALID))         std::cout << "  >> nothing arrived: is the far card sending?\n";
        else if (!bit(dbg::STK_RX_TLAST))     std::cout << "  >> beats arrived but no tlast: burst truncated.\n";
    }
}

// Confirms host writes reach the vFPGA, using a scratch register the design
// does not otherwise touch.
static bool csr_ok(coyote::cThread& t) {
    const uint64_t pat = 0xDEADBEEFCAFEF00DULL;
    t.setCSR(pat, reg::SCRATCH);
    bool ok = (t.getCSR(reg::SCRATCH) == pat);
    t.setCSR(0, reg::SCRATCH);
    if (!ok) {
        std::cerr << "[FAIL] CSR write path is broken: scratch register does not read back.\n"
                  << "       Reads work but writes do not land, so no mode below can function.\n";
    }
    return ok;
}

static bool wait_for_channel_up(coyote::cThread& t) {
    auto deadline = std::chrono::steady_clock::now()
                  + std::chrono::milliseconds(LINK_TIMEOUT_MS);
    while (std::chrono::steady_clock::now() < deadline) {
        uint64_t s = t.getCSR(reg::STATUS);
        if ((s >> status::CHANNEL_UP) & 0x1) {
            std::cout << "[OK] Aurora link up; ";
            print_status(s);
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    std::cout << "[FAIL] channel_up did not assert within "
              << LINK_TIMEOUT_MS << " ms\n";
    print_status(t.getCSR(reg::STATUS));
    return false;
}

// ---------------------------------------------------------------- modes

static int mode_rx(coyote::cThread& t, uint64_t n_beats, int wait_s) {
    // Clear CTRL before arming. rx_arm is level-triggered -- the counters reset
    // only while it is LOW -- so writing RX_ARM when it is already set does
    // nothing and the run inherits stale counts from whatever ran before.
    t.setCSR(0, reg::CTRL);
    t.setCSR(ctrl::RX_ARM, reg::CTRL);

    std::cout << "Armed for " << n_beats << " beats ("
              << n_beats * BEAT_BYTES << " bytes). Waiting up to "
              << wait_s << "s for the sender -- start TX on the other card now.\n";

    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(wait_s);
    uint64_t prev = 0;
    while (std::chrono::steady_clock::now() < deadline) {
        uint64_t beats = t.getCSR(reg::RX_BEATS);
        if (beats != prev) {
            std::cout << "  beats received: " << beats << "/" << n_beats << "\n";
            prev = beats;
        }
        if (beats >= n_beats) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    uint64_t beats    = t.getCSR(reg::RX_BEATS);
    uint64_t mismatch = t.getCSR(reg::RX_MISMATCH);
    std::cout << "[RX] beats=" << beats << " mismatches=" << mismatch << "\n";

    bool pass = (beats == n_beats && mismatch == 0);
    if (!pass) print_dbg(t, /*tx_side=*/false);
    t.setCSR(0, reg::CTRL);

    if (pass) {
        std::cout << "*** PASS: " << n_beats << " beats, no mismatch ***\n";
        return 0;
    }
    std::cout << "*** FAIL ***\n";
    return 1;
}

static int mode_tx(coyote::cThread& t, uint64_t n_beats) {
    // Clear first so tx_done from a previous run cannot block the start
    // condition (tx_start && !tx_running && !tx_done).
    t.setCSR(0, reg::CTRL);
    t.setCSR(n_beats, reg::TX_BURST);

    std::cout << "Sending " << n_beats << " beats ("
              << n_beats * BEAT_BYTES << " bytes)...\n";
    t.setCSR(ctrl::TX_START, reg::CTRL);

    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
    while (std::chrono::steady_clock::now() < deadline) {
        if ((t.getCSR(reg::STATUS) >> status::TX_DONE) & 0x1) {
            std::cout << "[OK] TX done.\n";
            t.setCSR(0, reg::CTRL);
            return 0;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    print_dbg(t, /*tx_side=*/true);
    t.setCSR(0, reg::CTRL);
    std::cout << "*** FAIL: TX did not complete ***\n";
    return 1;
}

static int mode_echo(coyote::cThread& t) {
    t.setCSR(ctrl::ECHO, reg::CTRL);
    std::cout << "Reflector active. Everything received is sent straight back.\n"
              << "Ctrl-C to stop.\n";
    while (true) std::this_thread::sleep_for(std::chrono::seconds(1));
    return 0;
}

// One measured round trip.
//
// RX is reset at the top of every iteration by dropping rx_arm. The vFPGA's
// pattern checker expects beat N to carry value N and each burst restarts at
// zero, so holding rx_arm across iterations would leave the expectation running
// ahead and flag every later beat as a mismatch. Clearing it also resets
// tx_done so the next burst can trigger.
static bool run_once(coyote::cThread& t, uint64_t beats, int timeout_ms,
                     uint64_t& head, uint64_t& full, uint64_t& mism) {
    t.setCSR(0, reg::CTRL);
    t.setCSR(beats, reg::TX_BURST);

    // Arm and fire in one write: rx_arm releases the counter reset on the same
    // cycle tx_start launches the burst.
    t.setCSR(ctrl::RX_ARM | ctrl::TX_START, reg::CTRL);

    auto deadline = std::chrono::steady_clock::now()
                  + std::chrono::milliseconds(timeout_ms);
    bool done = false;
    while (std::chrono::steady_clock::now() < deadline) {
        if (t.getCSR(reg::RX_BEATS) >= beats) { done = true; break; }
    }

    // Read before clearing CTRL: dropping rx_arm zeroes the RX counters.
    if (done) {
        head = t.getCSR(reg::RTT_HEAD);
        full = t.getCSR(reg::RTT_FULL);
        mism = t.getCSR(reg::RX_MISMATCH);
    }
    t.setCSR(0, reg::CTRL);
    return done;
}

struct Stats { double min, med, p99; };

static Stats summarise(std::vector<uint64_t> v, double ns_per_cycle) {
    std::sort(v.begin(), v.end());
    auto at = [&](double q) {
        return v[static_cast<size_t>(q * (v.size() - 1) + 0.5)] * ns_per_cycle;
    };
    return { v.front() * ns_per_cycle, at(0.50), at(0.99) };
}

static int mode_bench(coyote::cThread& t, uint64_t iters,
                      uint64_t min_bytes, uint64_t max_bytes,
                      double aclk_mhz, int timeout_ms) {
    const double ns_per_cycle = 1000.0 / aclk_mhz;
    if (min_bytes < BEAT_BYTES) min_bytes = BEAT_BYTES;

    std::cout << iters << " iterations per size, aclk " << aclk_mhz << " MHz ("
              << ns_per_cycle << " ns/cycle).\n"
              << "Round trip; halve for a one-way estimate. Includes 1 cycle ("
              << ns_per_cycle << " ns) from the reflector's register stage.\n\n";

    std::cout << std::left << std::setw(9) << "bytes" << std::right
              << std::setw(7)  << "beats"
              << std::setw(10) << "head_min" << std::setw(10) << "head_med"
              << std::setw(10) << "head_p99"
              << std::setw(10) << "full_min" << std::setw(10) << "full_med"
              << std::setw(10) << "full_p99"
              << std::setw(9)  << "Gbps" << std::setw(7) << "lost" << "\n"
              << std::string(92, '-') << "\n";

    uint64_t total_mismatches = 0;

    for (uint64_t bytes = min_bytes; bytes <= max_bytes; bytes *= 2) {
        const uint64_t beats = (bytes + BEAT_BYTES - 1) / BEAT_BYTES;

        std::vector<uint64_t> head, full;
        head.reserve(iters);
        full.reserve(iters);
        uint64_t lost = 0;

        for (uint64_t i = 0; i < iters; i++) {
            uint64_t h = 0, f = 0, m = 0;
            if (run_once(t, beats, timeout_ms, h, f, m)) {
                head.push_back(h);
                full.push_back(f);
                total_mismatches += m;
            } else {
                lost++;
            }
        }

        if (head.empty()) {
            std::cout << std::left << std::setw(9) << bytes << std::right
                      << std::setw(7) << beats << "   all iterations timed out\n";
            continue;
        }

        Stats hs = summarise(head, ns_per_cycle);
        Stats fs = summarise(full, ns_per_cycle);

        // One-way goodput. NOT full/2: the reflector is cut-through (a single
        // register stage), so a beat is forwarded as it arrives rather than
        // after the whole burst lands. The payload therefore crosses the wire
        // once in each direction and its serialisation time is counted once in
        // the round trip, not twice. Halving here would report ~180 Gbps on a
        // 103 Gbps link.
        double gbps = (fs.med > 0.0) ? (bytes * 8.0) / fs.med : 0.0;

        std::cout << std::fixed << std::setprecision(0)
                  << std::left << std::setw(9) << bytes << std::right
                  << std::setw(7)  << beats
                  << std::setw(10) << hs.min << std::setw(10) << hs.med
                  << std::setw(10) << hs.p99
                  << std::setw(10) << fs.min << std::setw(10) << fs.med
                  << std::setw(10) << fs.p99
                  << std::setprecision(1) << std::setw(9) << gbps
                  << std::setw(7) << lost << "\n";
    }

    std::cout << "\nLatencies in ns (round trip; halve for one-way).\n"
                 "Gbps is one-way goodput, bytes/full_med -- not halved, the\n"
                 "reflector is cut-through so payload serialisation is counted once.\n";
    if (total_mismatches) {
        std::cout << "WARNING: " << total_mismatches
                  << " pattern mismatches -- these numbers describe corrupted traffic.\n";
        return 1;
    }
    std::cout << "Echoed data matched throughout.\n";
    return 0;
}

// ---------------------------------------------------------------- main

int main(int argc, char* argv[]) {
    std::string mode;
    uint64_t    beats, iters, min_bytes, max_bytes;
    double      aclk_mhz;
    int         timeout_ms, wait_s;

    po::options_description opts("Options");
    opts.add_options()
        ("help,h", "Show this message")
        ("beats,b",   po::value<uint64_t>(&beats)->default_value(DEFAULT_BEATS),
         "rx/tx: beats per burst (1 beat = 32 B)")
        ("wait,w",    po::value<int>(&wait_s)->default_value(DEFAULT_RX_WAIT_S),
         "rx: seconds to wait for the sender")
        ("iters,n",   po::value<uint64_t>(&iters)->default_value(DEFAULT_ITERS),
         "bench: iterations per size")
        ("min",       po::value<uint64_t>(&min_bytes)->default_value(DEFAULT_MIN_BYTES),
         "bench: smallest transfer in bytes")
        ("max",       po::value<uint64_t>(&max_bytes)->default_value(DEFAULT_MAX_BYTES),
         "bench: largest transfer in bytes")
        ("aclk",      po::value<double>(&aclk_mhz)->default_value(ACLK_MHZ),
         "bench: aclk MHz, for cycles->ns")
        ("timeout",   po::value<int>(&timeout_ms)->default_value(DEFAULT_TIMEOUT_MS),
         "bench: per-iteration timeout in ms");

    po::options_description hidden;
    hidden.add_options()("mode", po::value<std::string>(&mode)->default_value("rx"), "");
    po::positional_options_description pos;
    pos.add("mode", 1);

    po::options_description all;
    all.add(opts).add(hidden);

    po::variables_map vm;
    po::store(po::command_line_parser(argc, argv).options(all).positional(pos).run(), vm);
    po::notify(vm);

    if (vm.count("help")) {
        std::cout << "Usage: sudo ./test <mode> [options]\n\n"
                  << "Modes:\n"
                  << "  rx     arm receiver and count beats\n"
                  << "  tx     send one burst\n"
                  << "  echo   reflect received traffic (far card, for bench)\n"
                  << "  bench  round-trip latency sweep\n\n"
                  << "  data test:     ./test rx     |  ./test tx\n"
                  << "  latency sweep: ./test echo   |  ./test bench\n\n"
                  << opts << "\n";
        return 0;
    }

    std::cout << "=== Coyote Example 14: Aurora (" << mode << ") ===\n";

    coyote::cThread t(VFPGA_ID, getpid());

    if (!csr_ok(t))            return 1;
    if (!wait_for_channel_up(t)) return 1;

    if (mode == "rx")    return mode_rx(t, beats, wait_s);
    if (mode == "tx")    return mode_tx(t, beats);
    if (mode == "echo")  return mode_echo(t);
    if (mode == "bench") return mode_bench(t, iters, min_bytes, max_bytes,
                                           aclk_mhz, timeout_ms);

    std::cerr << "Unknown mode '" << mode << "'. Try --help.\n";
    return 2;
}
