/**
 * Coyote Example 16: QLINK — host app
 *
 * Usage:  sudo ./qlink <mode> [options]
 *
 *   arm     clear counters, arm the checker, exit (stays armed)
 *   send    generate synthetic syndrome rounds
 *   report  read counters and judge pass/fail, changing nothing
 *   recv    arm + collect + report in one go (needs the sender to overlap)
 *   status  print link and PHY diagnostics, changing nothing
 *
 * Race-free workflow:  'arm' on card A, 'send' on card B, 'report' on card A.
 * There is no window to miss -- the checker stays armed until something clears
 * it, so the sender can run whenever.
 *
 * Every mode first checks that host CSR writes reach the vFPGA, because a dead
 * write path presents as a dead link and that is an expensive way to spend an
 * afternoon.
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

static void print_counters(coyote::cThread& t) {
    std::cout << "  tx_frames="  << t.getCSR(reg::TX_FRAMES)
              << " tx_dropped="  << t.getCSR(reg::TX_DROPPED) << "\n"
              << "  rx_frames="  << t.getCSR(reg::RX_FRAMES)
              << " rx_errors="   << t.getCSR(reg::RX_ERRORS)
              << " rx_gaps="     << t.getCSR(reg::RX_GAPS)
              << " mismatches="  << t.getCSR(reg::RX_MISMATCH) << "\n"
              << "  last_round=" << t.getCSR(reg::LAST_ROUND) << "\n";
}

// PHY diagnostics ride on the four wires that used to carry lane_up (only one
// lane exists, so per-lane status was redundant). See qlink_phy_gty.phy_dbg.
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

    // Ordered most-fundamental first: a bypass failure explains a bad line,
    // and a bad line explains the error counters, so report the root and stop.
    if (bypass_err)
        std::cout << "  >> RX buffer-bypass alignment FAILED. The RX datapath is "
                     "sampling at the wrong phase, so nothing below this is "
                     "meaningful. This is a GT/refclk problem, not a cable one.\n";
    else if (!aligned)
        std::cout << "  >> the framer never found the ALIGN pattern: nothing is "
                     "arriving, or the far card is not transmitting. In raw mode "
                     "alignment is ours (rxslide), not the GT's -- expect it to "
                     "take up to ~5.5 us after the line goes live.\n";
    else if (ber_heavy)
        std::cout << "  >> aligned, but erroring continuously (>=256 errors). "
                     "That is a line-quality problem, not a bring-up transient.\n";
    else if (ber_any)
        std::cout << "  >> aligned, with a few errors. The counter is gated on "
                     "rx_aligned, so these were NOT logged during the hunt -- a "
                     "frame arriving in the window after alignment but before "
                     "link_up is the benign explanation.\n";
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
    uint64_t bad    = t.getCSR(reg::RX_ERRORS) + t.getCSR(reg::RX_MISMATCH)
                    + t.getCSR(reg::RX_GAPS);
    if (frames && !bad) {
        std::cout << "*** PASS: " << frames
                  << " frames, no errors, gaps or mismatches ***\n";
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
    uint32_t    words_opt;
    int         wait_s;

    po::options_description opts("Options");
    opts.add_options()
        ("help,h", "Show this message")
        ("rounds,r",   po::value<uint64_t>(&rounds)->default_value(DEFAULT_ROUNDS),
         "send: rounds to generate (0 = free-run)")
        ("interval,i", po::value<uint64_t>(&interval)->default_value(DEFAULT_INTERVAL),
         "send: tx_clk cycles between rounds (391 = 1 us at 390.625 MHz)")
        ("wait,w",     po::value<int>(&wait_s)->default_value(30),
         "recv: seconds to collect before reporting")
        ("iters,n",    po::value<uint64_t>(&iters)->default_value(DEFAULT_ITERS),
         "bench: iterations per size")
        ("loopback,l", po::value<uint64_t>(&lb)->default_value(loopback::NORMAL),
         "GT loopback: 0=normal 1=near-PCS 2=near-PMA 4=far-PCS 6=far-PMA")
        ("words",      po::value<uint32_t>(&words_opt)->default_value(0),
         "echo: words to reflect (0 = full width); bench: measure only this size");

    po::options_description hidden;
    hidden.add_options()("mode", po::value<std::string>(&mode)->default_value("status"), "");
    po::positional_options_description pos;
    pos.add("mode", 1);
    po::options_description all;
    all.add(opts).add(hidden);

    po::variables_map vm;
    po::store(po::command_line_parser(argc, argv).options(all).positional(pos).run(), vm);
    po::notify(vm);

    // The hardware clamps an out-of-range length to MAX_SYN_WORDS silently, so
    // without this the tool would report a size it never actually sent.
    if (words_opt > MAX_SYN_WORDS) {
        std::cerr << "--words " << words_opt << " exceeds MAX_SYN_WORDS ("
                  << MAX_SYN_WORDS << "); clamping.\n";
        words_opt = MAX_SYN_WORDS;
    }

    if (vm.count("help")) {
        std::cout << "Usage: sudo ./qlink <mode> [options]\n\n"
                  << "  arm     clear counters, arm checker, exit (stays armed)\n"
                  << "  send    generate synthetic syndrome rounds\n"
                  << "  report  read counters and judge pass/fail\n"
                  << "  recv    arm + collect + report in one go (needs overlap)\n"
                  << "  echo    reflect received syndromes (far card, for bench)\n"
                  << "  bench   round-trip latency sweep across syndrome sizes\n"
                  << "  status  print link and PHY diagnostics\n"
                  << "  clock   measure the real tx_clk against the host clock\n\n"
                  << "  Race-free: 'arm' on card A, 'send' on card B, 'report' on A.\n\n"
                  << "  Latency decomposition, one card, no cable, no peer:\n"
                  << "    qlink bench -l 2    reflect in our own PMA -> our fabric + our GT\n"
                  << "    qlink bench         peer echoing            -> the whole path\n"
                  << "  The difference is cable + far card. Neither number means anything\n"
                  << "  on its own; the point is subtracting one from the other.\n"
                  << "  -l 2 is also SYMMETRIC for free: the card reflects its own frames,\n"
                  << "  so both legs are the size you asked for. A two-card run is not --\n"
                  << "  see --words.\n\n"
                  << opts << "\n";
        return 0;
    }

    std::cout << "=== QLINK (" << mode << ") ===\n";
    coyote::cThread t(VFPGA_ID, getpid());

    if (!csr_ok(t)) return 1;

    // Set loopback before anything waits on the link: changing it resets the
    // transceiver, so the link drops and has to come back up. Written on every
    // run, including the default 0, so a previous -l 2 cannot silently persist
    // in the register and quietly invalidate the next measurement.
    if (t.getCSR(reg::LOOPBACK) != lb) {
        t.setCSR(lb, reg::LOOPBACK);
        std::cout << "  loopback -> " << lb << " (GT reset; link will drop)\n";
    }
    if (lb != loopback::NORMAL)
        std::cout << "  NOTE: loopback " << lb << " active -- this is NOT a link measurement.\n";

    if (mode == "status") {
        uint64_t s = t.getCSR(reg::STATUS);
        std::cout << "  STATUS=0x" << std::hex << s << std::dec
                  << "  link_up=" << ((s >> status::LINK_UP) & 1) << "\n";
        print_phy_dbg(s);
        print_counters(t);
        return 0;
    }

    // Read out and judge without touching CTRL, so it is safe to repeat.
    if (mode == "report") {
        return judge(t);
    }

    if (!wait_link(t)) return 1;

    // Arm and exit, LEAVING the checker armed. Decouples the two cards so there
    // is no window to miss.
    if (mode == "arm") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(ctrl::ARM, reg::CTRL);
        std::cout << "Checker armed and left armed. Counters cleared.\n"
                  << "Now run 'qlink send' on the other card, then 'qlink report' here.\n";
        return 0;
    }

    // Measure the ACTUAL GT user clock against the host clock.
    //
    // Every latency number this tool prints is a cycle count scaled by an
    // assumed frequency, so if the board's reference clock is not what the GT
    // wizard was told, every result is silently wrong by that ratio and nothing
    // anywhere reports it. Aurora on this same QSFP cage declares 161.1328125
    // MHz while its measured throughput implies the board delivers 156.25 -- a
    // 3% discrepancy that no build step would ever flag.
    //
    // Works standalone under -l 2: near-end loopback brings the link up with no
    // cable and no peer.
    if (mode == "clock") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(0, reg::N_ROUNDS);                  // free-run
        t.setCSR(CLOCK_INTERVAL, reg::INTERVAL);
        t.setCSR(1, reg::SYN_WORDS);
        t.setCSR(ctrl::RUN, reg::CTRL);

        // Read the counter and the host clock as close together as possible at
        // both ends; the CSR round trip is microseconds against a 3 s window.
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
            {TXCLK_IF_15625_MHZ, "refclk 156.25       -> 15.625 Gbps"},
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
            std::cout << "  => matches NEITHER candidate within 0.5%. "
                         "Do not trust any latency number until this is explained.\n";
        return best_err < 0.5 ? 0 : 1;
    }

    // Reflector: every received syndrome goes straight back out. The far card
    // measures the round trip against its own clock.
    if (mode == "echo") {
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        // The reflector transmits with ITS OWN SYN_WORDS, not the length of the
        // frame it just received, so leaving this at 0 makes every echo full
        // width regardless of what the sender asked for. The return leg then
        // stops varying with payload size and the measured RTT is asymmetric:
        // the slope collapses from 2 cycles per word to 1, and small payloads
        // are inflated by a constant ~100 ns.
        //
        // Until the RTL mirrors the received length, match this to the sender
        // by hand and sweep one size at a time: `qlink echo --words 4` here,
        // `qlink bench --words 4` there.
        t.setCSR(words_opt, reg::SYN_WORDS);
        t.setCSR(ctrl::ECHO | ctrl::ARM, reg::CTRL);
        std::cout << "Reflecting " << (words_opt ? std::to_string(words_opt)
                                                 : std::string("full-width"))
                  << " word frames.\n";
        if (words_opt == 0)
            std::cout << "  WARNING: full width. RTT on the far card will be\n"
                      << "  asymmetric and inflated -- pass --words N to match it.\n";
        std::cout << "Reflector active. Run 'qlink bench' on the other card.\n"
                  << "Ctrl-C to stop.\n";
        while (true) std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    // Round-trip latency sweep across syndrome sizes.
    if (mode == "bench") {
        // RTT_CYCLES is counted in the GT transmit clock, not aclk. The
        // datapath moved off aclk in Task 2b; only the CSR block is still there.
        const double ns_per_cycle = 1000.0 / TXCLK_MHZ;

        std::cout << iters << " iterations per size, tx_clk " << TXCLK_MHZ
                  << " MHz (" << ns_per_cycle << " ns/cycle).\n"
                  << "Round trip; halve for a one-way estimate.\n\n";

        // Pre-flight: one round before committing to the whole sweep. A
        // round-trip measurement needs the reflector live at the same time,
        // and 6 sizes x N iterations of silent timeouts is a slow way to
        // discover it is not.
        {
            t.setCSR(ctrl::CLEAR, reg::CTRL);   // zeroes counters AND rtt_cycles
            t.setCSR(0, reg::CTRL);
            t.setCSR(1, reg::SYN_WORDS);
            t.setCSR(1, reg::N_ROUNDS);
            t.setCSR(0, reg::INTERVAL);
            t.setCSR(ctrl::ARM | ctrl::RUN, reg::CTRL);
            auto dl = std::chrono::steady_clock::now()
                    + std::chrono::milliseconds(RTT_TIMEOUT_MS);
            bool ok = false;
            // Wait on rtt_cycles, not rx_frames. rx_frames is CUMULATIVE and is
            // not cleared per iteration, so a previous test leaves it non-zero
            // and every poll returns instantly without an echo ever arriving.
            // rtt_cycles is zeroed by CLEAR above and can never legitimately
            // read back as 0, so it is an unambiguous "measurement complete".
            while (std::chrono::steady_clock::now() < dl)
                if (t.getCSR(reg::RTT_CYCLES) != 0) { ok = true; break; }
            uint64_t sent = t.getCSR(reg::TX_FRAMES);
            t.setCSR(0, reg::CTRL);
            if (!ok) {
                std::cerr << "[FAIL] no echo came back (sent " << sent << " frame).\n"
                          << "       Is 'qlink echo' running on the other card RIGHT NOW?\n"
                          << "       The reflector must be live for the whole sweep -- unlike\n"
                          << "       arm/report, a round trip cannot be decoupled.\n";
                if (sent == 0)
                    std::cerr << "       tx_frames=0: this card did not even transmit.\n";
                return 1;
            }
        }

        std::cout << std::left << std::setw(8) << "bytes" << std::right
                  << std::setw(7)  << "words"
                  << std::setw(10) << "rtt_min" << std::setw(10) << "rtt_med"
                  << std::setw(10) << "rtt_p99" << std::setw(10) << "one_way"
                  << std::setw(8)  << "lost" << "\n"
                  << std::string(63, '-') << "\n";

        uint64_t total_bad = 0;

        // Powers of two up to 16, then the full-width point. MAX_SYN_WORDS is
        // 31, not 32, so doubling alone would stop at 16 and never exercise a
        // full-size frame -- which is the size most likely to expose a depth or
        // width bug.
        // --words pins the sweep to one size, so it can be matched against a
        // reflector running `qlink echo --words N` for a symmetric measurement.
        for (uint32_t words = words_opt ? words_opt : 1;
             words <= (words_opt ? words_opt : MAX_SYN_WORDS);
             words = words_opt ? words_opt + 1
                   : ((words * 2 > MAX_SYN_WORDS && words != MAX_SYN_WORDS)
                      ? MAX_SYN_WORDS : words * 2)) {
            std::vector<uint64_t> rtt;
            rtt.reserve(iters);
            uint64_t lost = 0;

            for (uint64_t i = 0; i < iters; i++) {
                // One round in flight at a time: fire, wait for the echo, read.
                t.setCSR(ctrl::CLEAR, reg::CTRL);
                t.setCSR(0, reg::CTRL);
                t.setCSR(words, reg::SYN_WORDS);
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
                std::cout << std::left << std::setw(8) << words * WORD_BYTES
                          << std::right << std::setw(7) << words
                          << "   all iterations timed out\n";
                continue;
            }

            std::sort(rtt.begin(), rtt.end());
            auto at = [&](double q) {
                return rtt[static_cast<size_t>(q * (rtt.size() - 1) + 0.5)] * ns_per_cycle;
            };
            double med = at(0.50);

            std::cout << std::fixed << std::setprecision(0)
                      << std::left << std::setw(8) << words * WORD_BYTES
                      << std::right << std::setw(7) << words
                      << std::setw(10) << rtt.front() * ns_per_cycle
                      << std::setw(10) << med
                      << std::setw(10) << at(0.99)
                      << std::setw(10) << med / 2.0
                      << std::setw(8)  << lost << "\n";
        }

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
        // Pulse CLEAR first: qlink_link's counters and round-tracking state are
        // cumulative otherwise, so a second run inherits the first run's totals
        // and a sender restarting at round 0 reads as a gap.
        t.setCSR(ctrl::CLEAR, reg::CTRL);
        t.setCSR(0, reg::CTRL);
        t.setCSR(rounds, reg::N_ROUNDS);
        t.setCSR(interval, reg::INTERVAL);

        double us = interval / TXCLK_MHZ;
        std::cout << "Generating " << (rounds ? std::to_string(rounds) : "unbounded")
                  << " rounds, one every " << interval << " cycles ("
                  << us << " us)\n";

        t.setCSR(ctrl::RUN, reg::CTRL);
        if (rounds) {
            // Generation is fabric-paced; wait the expected duration plus slack.
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
        // Let the burst finish once traffic has been seen.
        uint64_t prev = 0, now = t.getCSR(reg::RX_FRAMES);
        while (now != prev) {
            prev = now;
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            now = t.getCSR(reg::RX_FRAMES);
        }

        // Deliberately does NOT clear CTRL: if the sender was late, the checker
        // stays armed and 'qlink report' can still pick it up.
        return judge(t);
    }

    std::cerr << "Unknown mode '" << mode << "'. Try --help.\n";
    return 2;
}
