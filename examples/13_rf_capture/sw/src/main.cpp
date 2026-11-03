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
// The DAC stays off unless -k is given. With -k it runs only during the capture, and is shut down afterwards.
// Only use -k when you know what the DAC output (tile 2, block 0) is connected to.

#include <chrono>
#include <cmath>
#include <cstring>
#include <fstream>
#include <iostream>
#include <thread>
#include <unistd.h>

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
constexpr double SAMPLES_PER_SECOND = 2.4576e9;

int run(int argc, char *argv[]) {
    unsigned int size_mb, tone_bin;
    double amplitude;
    bool pattern;
    std::string out_file;

    boost::program_options::options_description opts("Coyote RF capture options");
    opts.add_options()
        ("size,s", boost::program_options::value<unsigned int>(&size_mb)->default_value(64), "Capture size in MB, at most 128")
        ("pattern,p", boost::program_options::value<bool>(&pattern)->default_value(false), "Capture the test pattern instead of samples")
        ("tone,k", boost::program_options::value<unsigned int>(&tone_bin)->default_value(0), "Play a tone on the DAC at this many times 1.2 MHz, 1-1023; 0 keeps the DAC off")
        ("amplitude,a", boost::program_options::value<double>(&amplitude)->default_value(0.0625), "Tone amplitude as a fraction of DAC full scale, at most 0.25")
        ("out,o", boost::program_options::value<std::string>(&out_file), "Write the samples to this file (16-bit integers, in order)");
    boost::program_options::variables_map vm;
    boost::program_options::store(boost::program_options::parse_command_line(argc, argv, opts), vm);
    boost::program_options::notify(vm);

    uint32_t size = size_mb * 1024 * 1024;
    bool tone = tone_bin != 0;
    if (tone_bin > WAVE_SAMPLES / 2 - 1 || !(amplitude > 0 && amplitude <= MAX_AMPLITUDE) || (tone && pattern)) {
        std::cerr << "The tone must be 1-1023 and its amplitude above 0 and at most " << MAX_AMPLITUDE << ", without -p" << std::endl;
        return EXIT_FAILURE;
    }

    coyote::cRF rf;
    coyote::cThread thread(0, getpid());

    std::cout << "ADC tile state " << rf.adcState() << (rf.adcLocked() ? ", PLL locked" : ", PLL NOT locked") << std::endl;
    std::cout << "DAC tile state " << rf.dacState() << std::endl;
    if (rf.dacState() != coyote::cRF::TILE_STATE_OFF) {
        std::cerr << "The DAC tile should be off; not continuing" << std::endl;
        return EXIT_FAILURE;
    }
    if (rf.adcState() != coyote::cRF::TILE_STATE_RUNNING && !rf.adcStart()) {
        std::cerr << "The ADC tile did not start; are the clocks programmed?" << std::endl;
        return EXIT_FAILURE;
    }

    // Move the buffer to card memory first, so that the capture never waits for a page fault
    int16_t *buf = (int16_t *) thread.getMem({coyote::CoyoteAllocType::HPF, size});
    if (!buf) {
        std::cerr << "Could not allocate memory" << std::endl;
        return EXIT_FAILURE;
    }
    memset(buf, 0, size);
    coyote::syncSg sync_sg = { .addr = buf, .len = size };
    thread.invoke(coyote::CoyoteOper::LOCAL_OFFLOAD, sync_sg);

    if (tone) {
        thread.setCSR(0, WAVE_PLAY_REG);
        for (int i = 0; i < WAVE_SAMPLES; i++) {
            auto value = (int16_t) std::lround(amplitude * 32767 * std::sin(2 * M_PI * tone_bin * i / WAVE_SAMPLES));
            thread.setCSR(((uint64_t) i << 16) | (uint16_t) value, WAVE_SAMPLE_REG);
        }
        if (!rf.dacStart()) {
            std::cerr << "The DAC tile did not start and was shut down again; PLL "
                      << (rf.dacLocked() ? "locked" : "NOT locked") << std::endl;
            return EXIT_FAILURE;
        }
        std::cout << "DAC tile state " << rf.dacState() << (rf.dacLocked() ? ", PLL locked" : ", PLL NOT locked") << std::endl;
        rf.dacStream(true);
        thread.setCSR(1, WAVE_PLAY_REG);
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    // The write command waits in the shell until data arrives
    coyote::localSg sg = { .addr = buf, .len = size, .stream = coyote::STRM_CARD };
    thread.clearCompleted();
    rf.adcStream(false);
    rf.adcStream(true, pattern);
    thread.invoke(coyote::CoyoteOper::LOCAL_WRITE, sg);
    thread.setCSR(size / WORD_BYTES, CAPTURE_WORDS_REG);

    auto begin = std::chrono::steady_clock::now();
    thread.setCSR(1, CAPTURE_START_REG);

    bool timeout = false;
    while (thread.checkCompleted(coyote::CoyoteOper::LOCAL_WRITE) != 1) {
        if (std::chrono::steady_clock::now() - begin > std::chrono::seconds(5)) {
            timeout = true;
            break;
        }
    }
    double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - begin).count();

    bool overflow = rf.adcOverflow();
    uint32_t adc_words = rf.adcWords();
    bool underflow = rf.dacUnderflow();
    uint32_t dac_words = rf.dacWords();
    if (tone) {
        thread.setCSR(0, WAVE_PLAY_REG);
        rf.dacStream(false);
        bool off = rf.dacShutdown();
        std::cout << "DAC words " << dac_words << ", underflow " << underflow << "; DAC tile state " << rf.dacState()
                  << (off ? " (off)" : " (FAILED TO SHUT DOWN)") << std::endl;
    }
    uint64_t captured = thread.getCSR(CAPTURE_DONE_REG), busy = thread.getCSR(CAPTURE_BUSY_REG);
    rf.adcStream(false);

    std::cout << "Words captured " << captured << " of " << size / WORD_BYTES << ", busy " << busy
              << ", words from the ADC " << adc_words << ", overflow " << overflow << std::endl;
    std::cout << "Took " << seconds * 1e3 << " ms; the ADC delivers this much in "
              << size / 2 / SAMPLES_PER_SECOND * 1e3 << " ms" << std::endl;
    if (timeout) {
        std::cerr << "FAIL: the write did not complete in time" << std::endl;
        return EXIT_FAILURE;
    }

    thread.invoke(coyote::CoyoteOper::LOCAL_SYNC, sync_sg);

    uint64_t n = size / 2;
    int failed = overflow || (tone && underflow);
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
        double sum = 0, sum2 = 0;
        for (uint64_t i = 0; i < n; i++) {
            min = std::min<int>(min, buf[i]);
            max = std::max<int>(max, buf[i]);
            sum += buf[i];
            sum2 += (double) buf[i] * buf[i];
        }
        double mean = sum / n;
        std::cout << "Samples: " << n << ", min " << min << ", max " << max << ", mean " << mean
                  << ", RMS around the mean " << std::sqrt(std::max(0.0, sum2 / n - mean * mean)) << std::endl;
        failed |= min == max;
    }

    if (tone) {
        // Amplitude at the tone's frequency, over a whole number of waveform periods
        uint64_t m = n - n % WAVE_SAMPLES;
        double re = 0, im = 0;
        for (uint64_t i = 0; i < m; i++) {
            double phase = 2 * M_PI * (double) ((tone_bin * i) % WAVE_SAMPLES) / WAVE_SAMPLES;
            re += buf[i] * std::cos(phase);
            im += buf[i] * std::sin(phase);
        }
        double measured = 2 * std::sqrt(re * re + im * im) / m;
        std::cout << "Tone " << tone_bin * SAMPLES_PER_SECOND / WAVE_SAMPLES / 1e6 << " MHz: sent amplitude "
                  << amplitude * 32767 << ", measured at the ADC " << measured << " ("
                  << 20 * std::log10(measured / (amplitude * 32767)) << " dB)" << std::endl;
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
