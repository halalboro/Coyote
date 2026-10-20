/**
 * Coyote Example 16: QLINK — host app (Phase A + C)
 *
 * Usage:  sudo ./qlink <mode> [options]
 *
 *   arm     clear counters, arm the checker, exit (stays armed)
 *   send    generate synthetic SYN frames at the configured cadence
 *   report  read counters and judge pass/fail, changing nothing
 *   recv    arm + collect + report in one go (needs the sender to overlap)
 *   echo    reflect received frames back, retagged as FRM
 *   bench   round-trip latency measurement
 *   status  print link and PHY diagnostics, changing nothing
 *   clock   measure the real tx_clk against the host clock
 *   cal     trigger a TICK calibration and report measured one-way D
 *
 * Race-free workflow:  'arm' on card A, 'send' on card B, 'report' on A.
 *
 * Phase-A frame is FIXED 64 bytes (QLink v1.6 §3): no --words sweep.
 * Phase-C adds the TICK calibration path and a re-train sticky bit.
 */

#include <algorithm>
#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>
#include <thread>
#include <unistd.h>
#include <boost/program_options.hpp>

#include <coyote/cThread.hpp>

#include "constants.hpp"

namespace po = boost::program_options;
using namespace qlink;

static const char* type_name(uint8_t t) {
    switch (t) {
        case type::SYN: return "SYN";
        case type::FRM: return "FRM";
        case type::FUS: return "FUS";
        case type::CTL: return "CTL";
        default:        return "?";
    }
}

static void print_counters(coyote::cThread& t) {
    uint64_t last_type = t.getCSR(reg::LAST_TYPE) & 0xF;
    std::cout << "  tx_frames="  << t.getCSR(reg::TX_FRAMES)
              << " tx_dropped="  << t.getCSR(reg::TX_DROPPED) << "\n"
              << "  rx_frames="  << t.getCSR(reg::RX_FRAMES)
              << " rx_errors="   << t.getCSR(reg::RX_ERRORS)
              << " mismatches="  << t.getCSR(reg::RX_MISMATCH) << "\n"
              << "  last_round=" << t.getCSR(reg::LAST_ROUND)
              << " last_type="   << type_name(static_cast<uint8_t>(last_type))
              << " (" << last_type << ")\n";
}

// Phase C: print the TICK calibration + retrain state. ns_per_cycle lets
// the caller re-use the host-side tx_clk period estimate rather than
// pulling TXCLK_MHZ in from constants here.
static void print_cal(coyote::cThread& t, double ns_per_cycle) {
    uint64_t c   = t.getCSR(reg::CAL_CTRL);
    uint64_t d   = t.getCSR(reg::CAL_D);
    uint64_t ds  = t.getCSR(reg::CAL_D_SHADOW);
    uint64_t rc  = t.getCSR(reg::RETRAIN_CNT);

    const char* state_name[] = {"IDLE", "SEND", "WAIT", "HOLD"};
    uint64_t state = (c >> cal::STATE_LSB) & cal::STATE_MASK;

    std::cout << "  cal_valid=" << ((c >> cal::VALID_BIT) & 1)
              << "  retrain_sticky=" << ((c >> cal::RETRAIN_STICKY) & 1)
              << "  state=" << state_name[state]
              << "  retrain_count=" << rc << "\n"
              << "  cal_d="        << d  << " cycles ("
              << std::fixed << std::setprecision(1)
              << (d  * ns_per_cycle) << " ns)"
              << "  shadow=" << ds << " cycles ("
              << (ds * ns_per_cycle) << " ns)\n";
}

// PHY diagnostics ride on the four wires that used to carry lane_up.
static void print_phy_dbg(uint64_t s) {
    uint64_t d = (s >> status::LANE_UP_LSB) & 0xF;
    const bool aligned    = (d >> 0) & 1;
    const bool ber_any    = (d >> 1) & 1;
    const bool ber_heavy  = (d >> 2) & 1;
    const bool bypass_err = (d >> 3) & 1;

    std::cout << "  phy_dbg=0x" << std::hex << d << std::dec
              << "  rx_aligned="  << aligned
              << " ber_any="      << ber_any
              << " ber_heavy="    << ber_heavy
              << " bypass_err="   << bypass_err << "\n";

    if (bypass_err)
        std::cout << "  >> RX buffer-bypass alignment FAILED. The RX datapath is "
                     "sampling at the wrong phase.\n";
    else if (!aligned)
        std::cout << "  >> the framer never found the ALIGN pattern: nothing is "
                     "arriving, or the far card is not transmitting.\n";
    else if (ber_heavy)
        std::cout << "  >> aligned, but erroring continuously (>=256). Line "
                     "quality problem.\n";
    else if (ber_any)
        std::cout << "  >> aligned, with a few errors. Benign if during bring-up.\n";
}

static bool csr_ok(coyote::cThread& t) {
    const uint64_t pat = 0xB2A1D000C0FFEE01ULL;
    t.setCSR(pat, reg::SCRATCH);
    bool ok = (t.getCSR(reg::SCRATCH) == pat);
    t.setCSR(0, reg::SCRATCH);
    if (!ok)
        std::cerr << "[FAIL] CSR write path broken: scratch does not read back.\n";
    return ok;
}

static bool wait_link(coyote::cThread& t) {
    auto deadline = std::chrono::steady_clock::now()
                  + std::chrono::milliseconds(LINK_TIMEOUT_MS);
    while (std::chrono::steady_clock::now() < deadline) {
        uint64_t s = t.getCSR(reg::STATUS);
        if ((s >> status::LINK_UP) & 1) {
            std::cout << "[OK] link up\n";
            print_phy_dbg(s);
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    std::cerr << "[FAIL] link did not come up (STATUS=0x" << std::hex
              << t.getCSR(reg::STATUS) << std::dec << ")\n";
    return false;
}

static int judge(coyote::cThread& t) {
    print_counters(t);
    uint64_t frames = t.getCSR(reg::RX_FRAMES);
    uint64_t bad    = t.getCSR(reg::RX_ERRORS) + t.getCSR(reg::RX_MISMATCH);
    if (frames && !bad) {
        std::cout << "*** PASS: " << frames
                  << " frames, no errors or mismatches ***\n";
        return 0;
    }
    if (!frames) {
        std::cout << "No frames received.\n";
        print_phy_dbg(t.getCSR(reg::STATUS));
    }
    std::cout << "*** FAIL ***\n";
    return 1;
}

int main(int argc, char* argv[]) {
    std::string mode;
    uint64_t    rounds, interval, iters, lb;
    int         wait_s;

    po::options_description opts("Options");
    opts.add_options()
        ("help,h", "Show this message")
        ("rounds,r",   po::value<uint64_t>(&rounds)->default_value(DEFAULT_ROUNDS),
         "send: rounds to generate (0 = free-run)")
        ("interval,i", po::value<uint64_t>(&interval)->default_value(DEFAULT_INTERVAL),
         "send: tx_clk cycles between frames (391 = 1 us at 390.625 MHz)")
        ("wait,w",     po::value<int>(&wait_s)->default_value(30),
         "recv: seconds to collect before reporting")
        ("iters,n",    po::value<uint64_t>(&iters)->default_value(DEFAULT_ITERS),
         "bench: iterations")
        ("loopback,l", po::value<uint64_t>(&lb)->default_value(loopback::NORMAL),
         "GT loopback: 0=normal 1=near-PCS 2=near-PMA 4=far-PCS 6=far-PMA");

    po::options_description hidden;
    hidden.add_options()("mode", po::value<std::string>(&mode)->default_value("status"), "");
    po::positional_options_description pos;
    pos.add("mode", 1);
    po::options_description all;
    all.add(opts).add(hidden);

    po::variables_map vm;
    po::store(po::command_line_parser(argc, argv).options(all).positional(pos).run(), vm);
    po::notify(vm);

    if (vm.count("help")) {
        std::cout << "Usage: sudo ./qlink <mode> [options]\n\n"
                  << "  arm     clear counters, arm the checker, exit (stays armed)\n"
                  << "  send    generate synthetic SYN frames\n"
                  << "  report  read counters and judge pass/fail\n"
                  << "  recv    arm + collect + report in one go\n"
                  << "  echo    reflect received frames back, retagged as FRM\n"
                  << "  bench   round-trip latency measurement (fixed 64 B frame)\n"
                  << "  status  print link and PHY diagnostics\n"
                  << "  clock   measure the real tx_clk against the host clock\n"
                  << "  cal     trigger TICK calibration and report one-way D\n\n"
                  << "  Phase A: frame size is FIXED at 64 bytes (QLink v1.6 §3).\n"
                  << "  There is no --words sweep.\n\n"
                  << opts << "\n";
        return 0;
    }

    std::cout << "=== QLINK (" << mode << ") ===\n";
    coyote::cThread t(VFPGA_ID, getpid());

    if (!csr_ok(t)) return 1;

    // Set loopback before anything waits on the link: changing it resets the
    // transceiver, so the link drops and has to come back up.
    if (t.getCSR(reg::LOOPBACK) != lb) {
        t.setCSR(lb, reg::LOOPBACK);
        std::cout << "  loopback -> " << lb << " (GT reset; link will drop)\n";
    }
    if (lb != loopback::NORMAL)
        std::cout << "  NOTE: loopback " << lb << " active -- NOT a link measurement.\n";

    if (mode == "status") {
        uint64_t s = t.getCSR(reg::STATUS);
        std::cout << "  STATUS=0x" << std::hex << s << std::dec
                  << "  link_up=" << ((s >> status::LINK_UP) & 1) << "\n";
        print_phy_dbg(s);
        print_counters(t);
        print_cal(t, 1000.0 / TXCLK_MHZ);
        return 0;
    }

    if (mode == "report") {
        return judge(t);
    }

    if (!wait_link(t)) return 1;

    if (mode == "arm") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(ctrl::ARM, reg::CTRL);
        std::cout << "Checker armed and left armed. Counters cleared.\n"
                  << "Now run 'qlink send' on the other card, then 'qlink report' here.\n";
        return 0;
    }

    if (mode == "clock") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(0, reg::N_ROUNDS);                  // free-run
        t.setCSR(CLOCK_INTERVAL, reg::INTERVAL);
        t.setCSR(ctrl::RUN, reg::CTRL);

        auto     w0 = std::chrono::steady_clock::now();
        uint64_t f0 = t.getCSR(reg::TX_FRAMES);
        std::this_thread::sleep_for(std::chrono::seconds(CLOCK_SECONDS));
        uint64_t f1 = t.getCSR(reg::TX_FRAMES);
        auto     w1 = std::chrono::steady_clock::now();
        t.setCSR(0, reg::CTRL);

        double secs = std::chrono::duration<double>(w1 - w0).count();
        if (f1 <= f0) {
            std::cerr << "[FAIL] no frames generated (link down?). "
                      << "Try 'qlink clock -l 2'.\n";
            return 1;
        }
        double mhz = (f1 - f0) * double(CLOCK_INTERVAL + 1) / secs / 1e6;

        std::cout << std::fixed << std::setprecision(3)
                  << "  frames=" << (f1 - f0) << " over " << secs << " s\n"
                  << "  tx_clk = " << mhz << " MHz\n";

        struct { double f; const char* what; } cand[] = {
            {TXCLK_IF_12500_MHZ, "refclk 156.25       -> 12.5 Gbps"},
            {TXCLK_IF_16113_MHZ, "refclk 161.1328125  -> 16.1133 Gbps"},
        };
        const char* best = nullptr;
        double best_err = 1e9;
        for (auto& c : cand) {
            double err = std::abs(mhz - c.f) / c.f * 100.0;
            std::cout << "    vs " << std::setw(9) << c.f << " MHz  ("
                      << c.what << ")  error " << std::setprecision(2)
                      << err << "%\n" << std::setprecision(3);
            if (err < best_err) { best_err = err; best = c.what; }
        }
        if (best_err < 0.5)
            std::cout << "  => " << best << "\n";
        else
            std::cout << "  => matches NEITHER candidate within 0.5%.\n";
        return best_err < 0.5 ? 0 : 1;
    }

    if (mode == "echo") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(ctrl::ECHO | ctrl::ARM, reg::CTRL);
        std::cout << "Reflector active (frames reflected as FRM).\n"
                  << "Run 'qlink bench' on the other card.\n"
                  << "Ctrl-C to stop.\n";
        while (true) std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    if (mode == "bench") {
        // RTT_CYCLES is counted in the GT transmit clock (390.625 MHz / 2.56 ns).
        const double ns_per_cycle = 1000.0 / TXCLK_MHZ;

        std::cout << iters << " iterations at the fixed 64 B frame, tx_clk "
                  << TXCLK_MHZ << " MHz (" << ns_per_cycle << " ns/cycle).\n"
                  << "Round trip; halve for a one-way estimate.\n\n";

        // Pre-flight: one round before committing to the whole sweep.
        {
            t.setCSR(ctrl::CLEAR, reg::CTRL);
            t.setCSR(0, reg::CTRL);
            t.setCSR(1, reg::N_ROUNDS);
            t.setCSR(0, reg::INTERVAL);
            t.setCSR(ctrl::ARM | ctrl::RUN, reg::CTRL);
            auto dl = std::chrono::steady_clock::now()
                    + std::chrono::milliseconds(RTT_TIMEOUT_MS);
            bool ok = false;
            while (std::chrono::steady_clock::now() < dl)
                if (t.getCSR(reg::RTT_CYCLES) != 0) { ok = true; break; }
            uint64_t sent = t.getCSR(reg::TX_FRAMES);
            t.setCSR(0, reg::CTRL);
            if (!ok) {
                std::cerr << "[FAIL] no echo came back (sent " << sent << " frame).\n"
                          << "       Is 'qlink echo' running on the other card RIGHT NOW?\n";
                if (sent == 0)
                    std::cerr << "       tx_frames=0: this card did not even transmit.\n";
                return 1;
            }
        }

        std::vector<uint64_t> rtt;
        rtt.reserve(iters);
        uint64_t lost = 0, total_bad = 0;

        for (uint64_t i = 0; i < iters; i++) {
            t.setCSR(ctrl::CLEAR, reg::CTRL);
            t.setCSR(0, reg::CTRL);
            t.setCSR(1, reg::N_ROUNDS);
            t.setCSR(0, reg::INTERVAL);
            t.setCSR(ctrl::ARM | ctrl::RUN, reg::CTRL);

            auto deadline = std::chrono::steady_clock::now()
                          + std::chrono::milliseconds(RTT_TIMEOUT_MS);
            uint64_t r = 0;
            while (std::chrono::steady_clock::now() < deadline) {
                r = t.getCSR(reg::RTT_CYCLES);
                if (r != 0) break;
            }
            if (r) {
                rtt.push_back(r);
                total_bad += t.getCSR(reg::RX_ERRORS) + t.getCSR(reg::RX_MISMATCH);
            } else {
                lost++;
            }
        }
        t.setCSR(0, reg::CTRL);

        if (rtt.empty()) {
            std::cerr << "[FAIL] all " << iters << " iterations timed out.\n";
            return 1;
        }

        std::sort(rtt.begin(), rtt.end());
        auto at = [&](double q) {
            return rtt[static_cast<size_t>(q * (rtt.size() - 1) + 0.5)] * ns_per_cycle;
        };
        double med = at(0.50);

        std::cout << std::left << std::setw(8) << "bytes" << std::right
                  << std::setw(10) << "rtt_min" << std::setw(10) << "rtt_med"
                  << std::setw(10) << "rtt_p99" << std::setw(10) << "one_way"
                  << std::setw(8)  << "lost" << "\n"
                  << std::string(56, '-') << "\n";

        std::cout << std::fixed << std::setprecision(0)
                  << std::left << std::setw(8) << FRAME_BYTES
                  << std::right
                  << std::setw(10) << rtt.front() * ns_per_cycle
                  << std::setw(10) << med
                  << std::setw(10) << at(0.99)
                  << std::setw(10) << med / 2.0
                  << std::setw(8)  << lost << "\n";

        std::cout << "\nLatencies in ns. one_way = rtt_med/2.\n";
        if (total_bad) {
            std::cout << "WARNING: " << total_bad
                      << " errors/mismatches during the sweep -- these numbers "
                         "describe corrupted traffic.\n";
            return 1;
        }
        std::cout << "Payloads matched throughout.\n";
        return 0;
    }

    if (mode == "send") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(rounds, reg::N_ROUNDS);
        t.setCSR(interval, reg::INTERVAL);

        double us = interval / TXCLK_MHZ;
        std::cout << "Generating " << (rounds ? std::to_string(rounds) : "unbounded")
                  << " SYN frames, one every " << interval << " cycles ("
                  << us << " us)\n";

        t.setCSR(ctrl::RUN, reg::CTRL);
        if (rounds) {
            double secs = rounds * us / 1e6;
            std::this_thread::sleep_for(
                std::chrono::milliseconds(static_cast<int>(secs * 1000) + 500));
        } else {
            std::cout << "Free-running. Ctrl-C to stop.\n";
            while (true) std::this_thread::sleep_for(std::chrono::seconds(1));
        }

        t.setCSR(0, reg::CTRL);
        std::cout << "[send] done.\n";
        print_counters(t);
        return 0;
    }

    if (mode == "recv") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(ctrl::ARM, reg::CTRL);
        std::cout << "Checker armed, collecting for " << wait_s
                  << "s -- start the sender now.\n";

        for (int i = 0; i < wait_s; i++) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
            if (t.getCSR(reg::RX_FRAMES)) break;
        }
        uint64_t prev = 0, now = t.getCSR(reg::RX_FRAMES);
        while (now != prev) {
            prev = now;
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            now = t.getCSR(reg::RX_FRAMES);
        }
        return judge(t);
    }

    if (mode == "cal") {
        // Phase C: trigger a calibration and poll for cal_valid. The far
        // side must be running 'echo' (or anything that echoes TICK probes
        // — the vFPGA does that unconditionally when it sees a probe).
        const double ns_per_cycle = 1000.0 / TXCLK_MHZ;

        // Clear retrain sticky too: if the link just came up, retrain_sticky
        // is set and the FSM will refuse to run. Trigger with both bits.
        t.setCSR(cal::TRIGGER | cal::RETRAIN_CLR, reg::CAL_CTRL);
        t.setCSR(0, reg::CAL_CTRL);

        auto deadline = std::chrono::steady_clock::now()
                      + std::chrono::milliseconds(cal::CAL_TIMEOUT_MS);
        bool got_valid = false;
        while (std::chrono::steady_clock::now() < deadline) {
            uint64_t c = t.getCSR(reg::CAL_CTRL);
            if ((c >> cal::VALID_BIT) & 1) { got_valid = true; break; }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }

        print_cal(t, ns_per_cycle);
        if (!got_valid) {
            std::cerr << "[FAIL] cal_valid did not come up within "
                      << cal::CAL_TIMEOUT_MS << " ms. Is the far side echoing?\n";
            return 1;
        }
        std::cout << "[OK] calibration complete\n";
        return 0;
    }

    std::cerr << "Unknown mode '" << mode << "'. Try --help.\n";
    return 2;
}
