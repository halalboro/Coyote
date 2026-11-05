/*
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2025, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

// Captures samples from the RF ADC to card memory, reads them back to the ARM and checks them.
//   test -s 64           real samples: prints their statistics (and writes them to a file with -o)
//   test -s 64 -p 1      the shell's test pattern, at the full ADC rate: every sample is checked
//   test -s 1 -k 251     plays a tone of 251 * 1.2 MHz on the DAC during the capture, and measures it at the ADC
//   test --scan          plays tones on each DAC channel in turn, and measures them on every ADC channel
//   test --sweep -d 3    sweeps a tone within each of several DAC starts
//   test --pulse -d 3    plays a sharp pulse, and compares what it predicts with tones
//   test --stability -k 855 -d 3    measures a tone repeatedly, restarting a different part between captures each time
// -c and -d choose the ADC and DAC channel. The DAC stays off unless -k or --scan is given. With those, it runs only
// around the captures, and is shut down afterwards.
// Only use -k or --scan when you know what the DAC outputs are connected to.

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <unistd.h>
#include <vector>

#include <boost/program_options.hpp>

#include <coyote/cRF.hpp>
#include <coyote/cThread.hpp>

// vFPGA registers (hw/src/hdl/rf_capture.sv)
constexpr uint32_t CAPTURE_WORDS_REG = 0;
constexpr uint32_t CAPTURE_START_REG = 1;
constexpr uint32_t CAPTURE_BUSY_REG = 2;
constexpr uint32_t CAPTURE_DONE_REG = 3;
constexpr uint32_t WAVE_SAMPLE_REG = 4;
constexpr uint32_t WAVE_PLAY_REG = 5;
constexpr int WAVE_SAMPLES = 2048;

// Largest DAC amplitude this program accepts, as a fraction of full scale
constexpr double MAX_AMPLITUDE = 0.25;

constexpr uint64_t WORD_BYTES = 64;
// Read from the shell once it is known to have the converters
static double SAMPLES_PER_SECOND = 2.4576e9;

static double binMHz(unsigned int bin) { return bin * SAMPLES_PER_SECOND / WAVE_SAMPLES / 1e6; }

// Amplitude at a tone's frequency, over a whole number of waveform periods
static double toneAmplitude(const int16_t *buf, uint64_t n, unsigned int bin) {
    uint64_t m = n - n % WAVE_SAMPLES;
    double re = 0, im = 0;
    for (uint64_t i = 0; i < m; i++) {
        double phase = 2 * M_PI * (double) ((bin * i) % WAVE_SAMPLES) / WAVE_SAMPLES;
        re += buf[i] * std::cos(phase);
        im += buf[i] * std::sin(phase);
    }
    return 2 * std::sqrt(re * re + im * im) / m;
}

static double rmsAroundMean(const int16_t *buf, uint64_t n) {
    double sum = 0, sum2 = 0;
    for (uint64_t i = 0; i < n; i++) {
        sum += buf[i];
        sum2 += (double) buf[i] * buf[i];
    }
    double mean = sum / n;
    return std::sqrt(std::max(0.0, sum2 / n - mean * mean));
}

struct CaptureResult {
    uint64_t captured, busy;
    uint32_t adc_words;
    bool overflow, timeout;
    double seconds;
};

// One capture of a whole buffer from the chosen ADC channel, read back to the ARM
static CaptureResult capture(coyote::cRF &rf, coyote::cThread &thread, int16_t *buf, uint32_t size, int adc_channel, bool pattern) {
    memset(buf, 0, size);

    // Move the buffer to card memory first, so that the capture never waits for a page fault
    coyote::syncSg sync_sg = { .addr = buf, .len = size };
    thread.invoke(coyote::CoyoteOper::LOCAL_OFFLOAD, sync_sg);

    // The write command waits in the shell until data arrives
    coyote::localSg sg = { .addr = buf, .len = size, .stream = coyote::STRM_CARD };
    thread.clearCompleted();
    rf.adcStream(false);
    rf.adcSelect(adc_channel);
    rf.adcStream(true, pattern);
    thread.invoke(coyote::CoyoteOper::LOCAL_WRITE, sg);
    thread.setCSR(size / WORD_BYTES, CAPTURE_WORDS_REG);

    auto begin = std::chrono::steady_clock::now();
    thread.setCSR(1, CAPTURE_START_REG);

    CaptureResult r = {};
    while (thread.checkCompleted(coyote::CoyoteOper::LOCAL_WRITE) != 1) {
        if (std::chrono::steady_clock::now() - begin > std::chrono::seconds(5)) {
            r.timeout = true;
            break;
        }
    }
    r.seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - begin).count();
    r.overflow = rf.adcOverflow();
    r.adc_words = rf.adcWords();
    r.captured = thread.getCSR(CAPTURE_DONE_REG);
    r.busy = thread.getCSR(CAPTURE_BUSY_REG);
    rf.adcStream(false);

    if (!r.timeout) {
        thread.invoke(coyote::CoyoteOper::LOCAL_SYNC, sync_sg);
    }
    return r;
}

// Loads a tone into the waveform memory; the DAC stream must not be playing
static void loadTone(coyote::cThread &thread, unsigned int bin, double amplitude) {
    thread.setCSR(0, WAVE_PLAY_REG);
    for (int i = 0; i < WAVE_SAMPLES; i++) {
        auto value = (int16_t) std::lround(amplitude * 32767 * std::sin(2 * M_PI * bin * i / WAVE_SAMPLES));
        thread.setCSR(((uint64_t) i << 16) | (uint16_t) value, WAVE_SAMPLE_REG);
    }
}

static void dacOn(coyote::cRF &rf, coyote::cThread &thread, int dac_channel) {
    rf.dacSelect(dac_channel);
    if (!rf.dacStart()) {
        throw std::runtime_error("ERROR: the DAC tiles did not start, and were shut down again");
    }
    rf.dacStream(true);
    thread.setCSR(1, WAVE_PLAY_REG);
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
}

static void dacOff(coyote::cRF &rf, coyote::cThread &thread) {
    thread.setCSR(0, WAVE_PLAY_REG);
    rf.dacStream(false);
    if (!rf.dacShutdown()) {
        throw std::runtime_error("ERROR: the DAC tiles did not shut down");
    }
}

static void printTiles(const coyote::cRF &rf) {
    for (int i = 0; i < rf.tiles(); i++) {
        int t = coyote::cRF::ADC_TILE + i;
        std::cout << "Tile " << t << ": ADC state " << rf.adcState(t) << (rf.adcLocked(t) ? ", PLL locked" : ", PLL NOT locked")
                  << "; DAC state " << rf.dacState(t) << (rf.dacLocked(t) ? ", PLL locked" : ", PLL NOT locked") << std::endl;
    }
}

// Plays tones on each DAC channel in turn and measures every ADC channel
static int scan(coyote::cRF &rf, coyote::cThread &thread, int16_t *buf, uint32_t size, double amplitude) {
    const std::vector<unsigned int> bins = { 25, 85, 251, 417, 667, 835, 1001 };
    const int channels = rf.channels();
    const uint64_t n = size / 2;
    const double sent = amplitude * 32767;
    int failed = 0;

    auto checked = [&](int adc) {
        CaptureResult r = capture(rf, thread, buf, size, adc, false);
        if (r.timeout) { throw std::runtime_error("ERROR: a capture did not complete in time"); }
        failed |= r.overflow;
    };

    // Noise floor: several captures with the DAC off, at every tone frequency
    std::vector<std::vector<double>> floor(channels, std::vector<double>(bins.size(), 0));
    std::cout << "DAC off:" << std::endl;
    for (int adc = 0; adc < channels; adc++) {
        for (int repeat = 0; repeat < 3; repeat++) {
            checked(adc);
            for (size_t b = 0; b < bins.size(); b++) {
                floor[adc][b] = std::max(floor[adc][b], toneAmplitude(buf, n, bins[b]));
            }
        }
        std::cout << "  ADC " << adc << ": RMS " << rmsAroundMean(buf, n) << ", largest level at a tone frequency "
                  << *std::max_element(floor[adc].begin(), floor[adc].end()) << std::endl;
    }

    std::cout << "Sent amplitude " << sent << "; level at the ADC, * = more than 10 times the DAC-off level:" << std::endl;
    std::cout << std::fixed << std::setprecision(2);
    double best = 0, best_floor = 0;
    int best_dac = -1, best_adc = -1;
    unsigned int best_bin = 0;
    for (int dac = 0; dac < channels; dac++) {
        for (size_t b = 0; b < bins.size(); b++) {
            std::vector<double> level(channels);
            loadTone(thread, bins[b], amplitude);
            dacOn(rf, thread, dac);
            bool underflow = false;
            for (int adc = 0; adc < channels; adc++) {
                checked(adc);
                level[adc] = toneAmplitude(buf, n, bins[b]);
                underflow |= rf.dacUnderflow();
            }
            dacOff(rf, thread);
            failed |= underflow;

            std::cout << "  DAC " << dac << ", " << std::setw(7) << binMHz(bins[b]) << " MHz:";
            for (int adc = 0; adc < channels; adc++) {
                bool seen = level[adc] > 10 * floor[adc][b];
                std::cout << "  ADC " << adc << " " << std::setw(8) << level[adc] << (seen ? "*" : " ");
                if (seen && level[adc] > best) {
                    best = level[adc]; best_floor = floor[adc][b]; best_dac = dac; best_adc = adc; best_bin = bins[b];
                }
            }
            std::cout << (underflow ? "  DAC UNDERFLOW" : "") << std::endl;
        }
    }

    std::cout << std::defaultfloat;
    if (best_dac >= 0) {
        std::cout << "Strongest: DAC " << best_dac << " to ADC " << best_adc << " at " << binMHz(best_bin) << " MHz, level " << best
                  << " (" << 20 * std::log10(best / sent) << " dB from the amplitude sent; DAC-off level " << best_floor << ")" << std::endl;
    } else {
        std::cout << "No tone found on any pair" << std::endl;
    }
    printTiles(rf);
    std::cout << (failed ? "FAIL: data was lost during the scan" : "No data lost during the scan") << std::endl;
    return failed ? EXIT_FAILURE : EXIT_SUCCESS;
}

// Finds which restart changes a tone's level: measures it several times, doing one thing between the captures.
static int stability(coyote::cRF &rf, coyote::cThread &thread, int16_t *buf, uint32_t size, int adc, int dac, unsigned int bin, double amplitude) {
    constexpr int REPEATS = 12;
    const uint64_t n = size / 2;
    const std::vector<std::pair<std::string, std::function<bool()>>> modes = {
        { "nothing", [] { return true; } },
        { "DAC stream off and on", [&] {
            thread.setCSR(0, WAVE_PLAY_REG);
            rf.dacStream(false);
            rf.dacStream(true);
            thread.setCSR(1, WAVE_PLAY_REG);
            return true;
        } },
        { "ADC tiles restarted", [&] { return rf.adcShutdown() && rf.adcStart(); } },
        { "DAC tile 3 restarted", [&] { return rf.dacRestart(3); } },
        { "DAC tile 2 restarted", [&] { return rf.dacRestart(2); } },
        { "DAC tiles shut down and started", [&] { return rf.dacShutdown() && rf.dacStart(); } },
    };

    int failed = 0;
    std::cout << "Tone " << binMHz(bin) << " MHz, DAC " << dac << " to ADC " << adc << ", sent amplitude " << amplitude * 32767 << std::endl;
    std::cout << std::fixed << std::setprecision(0);
    for (const auto &mode : modes) {
        loadTone(thread, bin, amplitude);
        dacOn(rf, thread, dac);
        std::vector<double> level;
        bool lost = false;
        for (int i = 0; i < REPEATS; i++) {
            CaptureResult r = capture(rf, thread, buf, size, adc, false);
            if (r.timeout) { throw std::runtime_error("ERROR: a capture did not complete in time"); }
            lost |= r.overflow;
            level.push_back(toneAmplitude(buf, n, bin));
            if (i + 1 < REPEATS) {
                if (!mode.second()) { throw std::runtime_error("ERROR: a tile did not restart: " + mode.first); }
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            }
        }
        dacOff(rf, thread);
        failed |= lost;
        std::cout << std::setw(32) << mode.first << ": range " << std::setw(5) << *std::min_element(level.begin(), level.end())
                  << " to " << std::setw(5) << *std::max_element(level.begin(), level.end()) << " :";
        for (double l : level) { std::cout << " " << l; }
        std::cout << (lost ? "  ADC OVERFLOW" : "") << std::endl;
    }
    std::cout << std::defaultfloat;
    printTiles(rf);
    std::cout << "All DAC tiles off " << rf.dacOff() << std::endl;
    return failed || !rf.dacOff() ? EXIT_FAILURE : EXIT_SUCCESS;
}

// Sweeps the tone within each start of the DAC, so that one row of the table has a single state of the converters
static int sweep(coyote::cRF &rf, coyote::cThread &thread, int16_t *buf, uint32_t size, int adc, int dac, double amplitude) {
    constexpr int STARTS = 16;
    const std::vector<unsigned int> bins = { 25, 85, 251, 417, 584, 667, 750, 835, 855, 918, 959, 1001, 1023 };
    const uint64_t n = size / 2;
    int failed = 0;
    std::cout << "DAC " << dac << " to ADC " << adc << ", sent amplitude " << amplitude * 32767 << "; one row per DAC start. MHz:" << std::endl;
    std::cout << std::fixed << std::setprecision(1);
    for (unsigned int bin : bins) { std::cout << std::setw(8) << binMHz(bin); }
    std::cout << std::endl << std::setprecision(0);
    for (int start = 0; start < STARTS; start++) {
        loadTone(thread, bins[0], amplitude);
        dacOn(rf, thread, dac);
        for (unsigned int bin : bins) {
            loadTone(thread, bin, amplitude);
            thread.setCSR(1, WAVE_PLAY_REG);
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            CaptureResult r = capture(rf, thread, buf, size, adc, false);
            if (r.timeout) { throw std::runtime_error("ERROR: a capture did not complete in time"); }
            failed |= r.overflow;
            std::cout << std::setw(8) << toneAmplitude(buf, n, bin);
        }
        dacOff(rf, thread);
        std::cout << std::endl;
    }
    std::cout << std::defaultfloat;
    printTiles(rf);
    std::cout << "All DAC tiles off " << rf.dacOff() << std::endl;
    return failed || !rf.dacOff() ? EXIT_FAILURE : EXIT_SUCCESS;
}

// Plays one sharp pulse per waveform period and prints what arrives, averaged over the capture. The tones then played in the
// same DAC start are compared with the levels the pulse predicts, so one row has a single state of the converters.
static int pulse(coyote::cRF &rf, coyote::cThread &thread, int16_t *buf, uint32_t size, int adc, int dac, double amplitude) {
    constexpr int STARTS = 16;
    const std::vector<unsigned int> bins = { 251, 750, 855, 1023 };
    const uint64_t n = size / 2;
    const double height = amplitude * 32767;
    int failed = 0;

    auto checked = [&]() {
        CaptureResult r = capture(rf, thread, buf, size, adc, false);
        if (r.timeout) { throw std::runtime_error("ERROR: a capture did not complete in time"); }
        failed |= r.overflow;
    };

    std::cout << "DAC " << dac << " to ADC " << adc << ", pulse height " << height << ". Samples around the largest, as a fraction of the height:" << std::endl;
    std::cout << std::fixed;
    for (int start = 0; start < STARTS; start++) {
        thread.setCSR(0, WAVE_PLAY_REG);
        for (int i = 0; i < WAVE_SAMPLES; i++) {
            thread.setCSR(((uint64_t) i << 16) | (uint16_t) (i == 0 ? std::lround(height) : 0), WAVE_SAMPLE_REG);
        }
        dacOn(rf, thread, dac);
        checked();

        std::vector<double> mean(WAVE_SAMPLES, 0);
        uint64_t m = n - n % WAVE_SAMPLES;
        for (uint64_t i = 0; i < m; i++) { mean[i % WAVE_SAMPLES] += buf[i]; }
        double dc = 0;
        for (double &v : mean) { v /= m / WAVE_SAMPLES; dc += v / WAVE_SAMPLES; }
        int peak = 0;
        for (int i = 0; i < WAVE_SAMPLES; i++) {
            mean[i] -= dc;
            if (std::abs(mean[i]) > std::abs(mean[peak])) { peak = i; }
        }

        std::cout << std::setprecision(3);
        for (int d = -3; d <= 4; d++) { std::cout << std::setw(8) << mean[(peak + d + WAVE_SAMPLES) % WAVE_SAMPLES] / height; }
        std::cout << "  |" << std::setprecision(0);

        // A tone of this height should arrive at the size of the pulse's spectrum at that frequency
        for (unsigned int bin : bins) {
            double re = 0, im = 0;
            for (int i = 0; i < WAVE_SAMPLES; i++) {
                double phase = 2 * M_PI * (double) ((bin * i) % WAVE_SAMPLES) / WAVE_SAMPLES;
                re += mean[i] * std::cos(phase);
                im += mean[i] * std::sin(phase);
            }
            loadTone(thread, bin, amplitude);
            thread.setCSR(1, WAVE_PLAY_REG);
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            checked();
            std::cout << "  " << binMHz(bin) << "MHz " << std::sqrt(re * re + im * im) << "/" << toneAmplitude(buf, n, bin);
        }
        dacOff(rf, thread);
        std::cout << std::endl;
    }
    std::cout << std::defaultfloat << "(after the bar: level predicted from the pulse / level measured with a tone)" << std::endl;
    printTiles(rf);
    std::cout << "All DAC tiles off " << rf.dacOff() << std::endl;
    return failed || !rf.dacOff() ? EXIT_FAILURE : EXIT_SUCCESS;
}

static int run(int argc, char *argv[]) {
    unsigned int size_mb, tone_bin;
    int adc_channel, dac_channel;
    double amplitude;
    bool pattern, do_scan = false, do_stability = false, do_sweep = false, do_pulse = false, do_clocks = false;
    std::string out_file;

    boost::program_options::options_description opts("Coyote RF capture options");
    opts.add_options()
        ("size,s", boost::program_options::value<unsigned int>(&size_mb)->default_value(64), "Capture size in MB, at most 128")
        ("pattern,p", boost::program_options::value<bool>(&pattern)->default_value(false), "Capture the test pattern instead of samples")
        ("adc,c", boost::program_options::value<int>(&adc_channel)->default_value(0), "ADC channel")
        ("dac,d", boost::program_options::value<int>(&dac_channel)->default_value(0), "DAC channel")
        ("tone,k", boost::program_options::value<unsigned int>(&tone_bin)->default_value(0), "Play a tone on the DAC at this many times 1/2048 of the sampling rate (1.2 MHz by default), 1-1023; 0 keeps the DAC off")
        ("amplitude,a", boost::program_options::value<double>(&amplitude)->default_value(0.0625), "Tone amplitude as a fraction of DAC full scale, at most 0.25")
        ("scan", boost::program_options::bool_switch(&do_scan), "Play tones on each DAC channel in turn and measure every ADC channel; uses 1 MB captures")
        ("stability", boost::program_options::bool_switch(&do_stability), "Measure the tone from -k repeatedly, restarting a different part between captures each time; uses 1 MB captures")
        ("sweep", boost::program_options::bool_switch(&do_sweep), "Sweep a tone within each of several DAC starts; uses 1 MB captures")
        ("pulse", boost::program_options::bool_switch(&do_pulse), "Play a sharp pulse of the -a height and compare what it predicts with tones, in each of several DAC starts; uses 1 MB captures")
        ("program-clocks", boost::program_options::bool_switch(&do_clocks), "Program the reference clock chips first, as needed once after every power cycle")
        ("out,o", boost::program_options::value<std::string>(&out_file), "Write the samples to this file (16-bit integers, in order)");
    boost::program_options::variables_map vm;
    boost::program_options::store(boost::program_options::parse_command_line(argc, argv, opts), vm);
    boost::program_options::notify(vm);

    if (do_scan || do_stability || do_sweep || do_pulse) { size_mb = 1; }
    uint32_t size = size_mb * 1024 * 1024;
    bool tone = tone_bin != 0;
    if (tone_bin > WAVE_SAMPLES / 2 - 1 || !(amplitude > 0 && amplitude <= MAX_AMPLITUDE) || (tone && pattern)) {
        std::cerr << "The tone must be 1-1023 and its amplitude above 0 and at most " << MAX_AMPLITUDE << ", without -p" << std::endl;
        return EXIT_FAILURE;
    }

    coyote::cRF rf;
    coyote::cThread thread(0, getpid());
    SAMPLES_PER_SECOND = rf.sampleRate();
    std::cout << "Sampling rate " << SAMPLES_PER_SECOND / 1e6 << " MS/s; tone bins are " << binMHz(1) << " MHz" << std::endl;

    printTiles(rf);
    if (!rf.dacOff()) {
        std::cerr << "The DAC tiles should be off; not continuing" << std::endl;
        return EXIT_FAILURE;
    }
    if (do_clocks) {
        bool ok = rf.programClocks();
        std::cout << "Clock chips programmed" << std::endl;
        printTiles(rf);
        if (!ok) {
            std::cerr << "The DAC tiles did not stay off or the ADC tiles did not start" << std::endl;
            return EXIT_FAILURE;
        }
    }
    if (!rf.adcRunning() && !rf.adcStart()) {
        printTiles(rf);
        std::cerr << "The ADC tiles did not start; are the clocks programmed (--program-clocks)?" << std::endl;
        return EXIT_FAILURE;
    }

    int16_t *buf = (int16_t *) thread.getMem({coyote::CoyoteAllocType::HPF, size});
    if (!buf) {
        std::cerr << "Could not allocate memory" << std::endl;
        return EXIT_FAILURE;
    }

    if (do_scan) {
        return scan(rf, thread, buf, size, amplitude);
    }
    if (do_pulse) {
        return pulse(rf, thread, buf, size, adc_channel, dac_channel, amplitude);
    }
    if (do_sweep) {
        return sweep(rf, thread, buf, size, adc_channel, dac_channel, amplitude);
    }
    if (do_stability) {
        if (!tone || rf.channels() < 4) {
            std::cerr << "--stability needs -k and the four-channel image" << std::endl;
            return EXIT_FAILURE;
        }
        return stability(rf, thread, buf, size, adc_channel, dac_channel, tone_bin, amplitude);
    }

    bool underflow = false;
    uint32_t dac_words = 0;
    if (tone) {
        loadTone(thread, tone_bin, amplitude);
        dacOn(rf, thread, dac_channel);
        printTiles(rf);
    }

    CaptureResult r = capture(rf, thread, buf, size, adc_channel, pattern);

    if (tone) {
        underflow = rf.dacUnderflow();
        dac_words = rf.dacWords();
        dacOff(rf, thread);
        std::cout << "DAC channel " << dac_channel << ": words " << dac_words << ", underflow " << underflow
                  << "; all DAC tiles off " << rf.dacOff() << std::endl;
    }

    std::cout << "ADC channel " << adc_channel << ": words captured " << r.captured << " of " << size / WORD_BYTES << ", busy " << r.busy
              << ", words from the ADC " << r.adc_words << ", overflow " << r.overflow << std::endl;
    std::cout << "Took " << r.seconds * 1e3 << " ms; the ADC delivers this much in "
              << size / 2 / SAMPLES_PER_SECOND * 1e3 << " ms" << std::endl;
    if (r.timeout) {
        std::cerr << "FAIL: the write did not complete in time" << std::endl;
        return EXIT_FAILURE;
    }

    uint64_t n = size / 2;
    int failed = r.overflow || (tone && underflow);
    if (pattern) {
        uint64_t bad = 0, first_bad = 0;
        for (uint64_t i = 1; i < n; i++) {
            if ((uint16_t) buf[i] != (uint16_t) (buf[i - 1] + 1)) {
                if (!bad) { first_bad = i; }
                bad++;
            }
        }
        std::cout << "Test pattern: first value " << (uint16_t) buf[0] << ", " << bad << " breaks in " << n << " samples";
        if (bad) { std::cout << ", first at sample " << first_bad; }
        std::cout << std::endl;
        failed |= bad != 0;
    } else {
        int min = 32767, max = -32768;
        double sum = 0;
        for (uint64_t i = 0; i < n; i++) {
            min = std::min<int>(min, buf[i]);
            max = std::max<int>(max, buf[i]);
            sum += buf[i];
        }
        std::cout << "Samples: " << n << ", min " << min << ", max " << max << ", mean " << sum / n
                  << ", RMS around the mean " << rmsAroundMean(buf, n) << std::endl;
        failed |= min == max;
    }

    if (tone) {
        double measured = toneAmplitude(buf, n, tone_bin);
        std::cout << "Tone " << binMHz(tone_bin) << " MHz: sent amplitude " << amplitude * 32767 << ", measured at the ADC " << measured
                  << " (" << 20 * std::log10(measured / (amplitude * 32767)) << " dB)" << std::endl;
    }

    if (vm.count("out")) {
        std::ofstream(out_file, std::ios::binary).write((const char *) buf, size);
        std::cout << "Wrote " << out_file << std::endl;
    }

    std::cout << (failed ? "FAIL" : "PASS") << std::endl;
    return failed ? EXIT_FAILURE : EXIT_SUCCESS;
}

int main(int argc, char *argv[]) {
    // Catching this unwinds the stack, so that the DAC is shut down whatever goes wrong
    try {
        return run(argc, argv);
    } catch (const std::exception &e) {
        std::cerr << e.what() << std::endl;
        return EXIT_FAILURE;
    }
}
