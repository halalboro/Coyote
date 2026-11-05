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

#include <coyote/cRF.hpp>

#include <chrono>
#include <fcntl.h>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <thread>
#include <unistd.h>

#include <coyote/cDefs.hpp>

namespace coyote {

void rfClockProgram();  // cRFClocks.cpp

// Layout of the window the driver maps; must match driver/include/coyote_defs.h
static constexpr uint64_t RF_WINDOW_SIZE = 0x41000;
static constexpr uint32_t RF_SERVICE_OFFS = 0x40000;

// RF service registers (hw/hdl/rf/rf_slave.sv)
static constexpr uint32_t RF_ID_REG = 0x00;
static constexpr uint32_t RF_CTRL_REG = 0x04;
static constexpr uint32_t RF_STATUS_REG = 0x08;
static constexpr uint32_t RF_ADC_WORDS_REG = 0x0C;
static constexpr uint32_t RF_DAC_WORDS_REG = 0x10;
static constexpr uint32_t RF_CHANNELS_REG = 0x14;
static constexpr uint32_t RF_SELECT_REG = 0x18;
static constexpr uint32_t RF_RATE_REG = 0x1C;
static constexpr uint32_t RF_ID = 0x52460001;
static constexpr uint32_t CTRL_ADC_EN = 0x1;
static constexpr uint32_t CTRL_DAC_EN = 0x2;
static constexpr uint32_t CTRL_ADC_TEST = 0x4;

// Converter tile registers, as in Xilinx's rfdc driver
static constexpr uint32_t TILE_RESTART = 0x04;
static constexpr uint32_t TILE_RESTART_STATE = 0x08;
static constexpr uint32_t TILE_CURRENT_STATE = 0x0C;
static constexpr uint32_t TILE_STATUS = 0x228;
static constexpr uint32_t TILE_PLL_LOCKED = 0x8;
static constexpr uint32_t adcTile(int t) { return 0x14000 + t * 0x4000; }
static constexpr uint32_t dacTile(int t) { return 0x4000 + t * 0x4000; }

cRF::cRF(unsigned int vfid, unsigned int device) {
    std::string path = "/dev/coyote_fpga_" + std::to_string(device) + "_v" + std::to_string(vfid);
    fd = open(path.c_str(), O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        throw std::runtime_error("ERROR: cRF could not open " + path);
    }

    void *mem = mmap(NULL, RF_WINDOW_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, MMAP_RF);
    if (mem == MAP_FAILED) {
        close(fd);
        throw std::runtime_error("ERROR: cRF could not map the RF registers; does the loaded shell have them (EN_RF)?");
    }
    regs = static_cast<volatile uint32_t *>(mem);

    if (regs[(RF_SERVICE_OFFS + RF_ID_REG) / 4] != RF_ID) {
        munmap(mem, RF_WINDOW_SIZE);
        close(fd);
        throw std::runtime_error("ERROR: cRF read a wrong RF service ID");
    }
}

cRF::~cRF() {
    if (dac_started) {
        dacStream(false);
        dacShutdown();
    }
    munmap(const_cast<uint32_t *>(regs), RF_WINDOW_SIZE);
    close(fd);
}

uint32_t cRF::tileRd(uint32_t tile_base, uint32_t offs) const {
    return regs[(tile_base + offs) / 4];
}

bool cRF::tileRestart(uint32_t tile_base, uint32_t start, uint32_t end) {
    regs[(tile_base + TILE_RESTART_STATE) / 4] = (start << 8) | end;
    regs[(tile_base + TILE_RESTART) / 4] = 1;
    for (int i = 0; i < 1000; i++) {
        if (tileRd(tile_base, TILE_CURRENT_STATE) == end) {
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return false;
}

int cRF::channels() const {
    uint32_t n = regs[(RF_SERVICE_OFFS + RF_CHANNELS_REG) / 4];
    return n ? n : 1;
}
double cRF::sampleRate() const {
    uint32_t khz = regs[(RF_SERVICE_OFFS + RF_RATE_REG) / 4];
    return (khz ? khz : 2457600) * 1e3;
}
int cRF::tiles() const { return channels() > 2 ? 2 : 1; }

uint32_t cRF::adcState(int tile) const { return tileRd(adcTile(tile), TILE_CURRENT_STATE); }
uint32_t cRF::dacState(int tile) const { return tileRd(dacTile(tile), TILE_CURRENT_STATE); }
bool cRF::adcLocked(int tile) const { return tileRd(adcTile(tile), TILE_STATUS) & TILE_PLL_LOCKED; }
bool cRF::dacLocked(int tile) const { return tileRd(dacTile(tile), TILE_STATUS) & TILE_PLL_LOCKED; }

bool cRF::adcRunning() const {
    for (int i = 0; i < tiles(); i++) {
        if (adcState(ADC_TILE + i) != TILE_STATE_RUNNING) { return false; }
    }
    return true;
}

bool cRF::dacOff() const {
    for (int i = 0; i < tiles(); i++) {
        if (dacState(DAC_TILE + i) != TILE_STATE_OFF) { return false; }
    }
    return true;
}

bool cRF::adcStart() {
    bool ok = true;
    for (int i = 0; i < tiles(); i++) {
        ok &= tileRestart(adcTile(ADC_TILE + i), TILE_STATE_OFF, TILE_STATE_RUNNING);
    }
    return ok;
}

bool cRF::adcShutdown() {
    bool ok = true;
    for (int i = tiles() - 1; i >= 0; i--) {
        ok &= tileRestart(adcTile(ADC_TILE + i), TILE_STATE_OFF, TILE_STATE_OFF);
    }
    return ok;
}

bool cRF::dacShutdown() {
    bool ok = true;
    for (int i = tiles() - 1; i >= 0; i--) {
        ok &= tileRestart(dacTile(DAC_TILE + i), TILE_STATE_OFF, TILE_STATE_OFF);
    }
    return ok;
}

bool cRF::dacStart() {
    dac_started = true;
    bool ok = true;
    for (int i = 0; i < tiles(); i++) {
        ok &= tileRestart(dacTile(DAC_TILE + i), TILE_STATE_OFF, TILE_STATE_RUNNING);
    }
    if (!ok) {
        dacShutdown();
    }
    return ok;
}

bool cRF::dacRestart(int tile) {
    dac_started = true;
    return tileRestart(dacTile(tile), TILE_STATE_OFF, TILE_STATE_OFF) && tileRestart(dacTile(tile), TILE_STATE_OFF, TILE_STATE_RUNNING);
}

bool cRF::programClocks() {
    // The tiles lose their clock while the chips are written; shutting down fails harmlessly if they never had one
    dacStream(false);
    adcStream(false);
    dacShutdown();
    adcShutdown();

    rfClockProgram();
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    // A tile that was waiting for a clock may have started by itself, so the DAC is shut down again
    return dacShutdown() && adcStart();
}

void cRF::adcSelect(int channel) {
    if (channel < 0 || channel >= channels()) { throw std::runtime_error("ERROR: no such ADC channel"); }
    select = (select & ~0x3u) | channel;
    regs[(RF_SERVICE_OFFS + RF_SELECT_REG) / 4] = select;
}

void cRF::dacSelect(int channel) {
    if (channel < 0 || channel >= channels()) { throw std::runtime_error("ERROR: no such DAC channel"); }
    select = (select & ~0x300u) | (channel << 8);
    regs[(RF_SERVICE_OFFS + RF_SELECT_REG) / 4] = select;
}

void cRF::writeCtrl(uint32_t bits, uint32_t mask) {
    ctrl = (ctrl & ~mask) | (bits & mask);
    regs[(RF_SERVICE_OFFS + RF_CTRL_REG) / 4] = ctrl;
}

void cRF::adcStream(bool enable, bool test_pattern) {
    // The test bit changes while the stream is disabled
    writeCtrl(test_pattern ? CTRL_ADC_TEST : 0, CTRL_ADC_EN | CTRL_ADC_TEST);
    if (enable) {
        writeCtrl(CTRL_ADC_EN, CTRL_ADC_EN);
    }
}

void cRF::dacStream(bool enable) { writeCtrl(enable ? CTRL_DAC_EN : 0, CTRL_DAC_EN); }
bool cRF::dacUnderflow() const { return regs[(RF_SERVICE_OFFS + RF_STATUS_REG) / 4] & 0x2; }
uint32_t cRF::dacWords() const { return regs[(RF_SERVICE_OFFS + RF_DAC_WORDS_REG) / 4]; }

bool cRF::adcOverflow() const { return regs[(RF_SERVICE_OFFS + RF_STATUS_REG) / 4] & 0x1; }
uint32_t cRF::adcWords() const { return regs[(RF_SERVICE_OFFS + RF_ADC_WORDS_REG) / 4]; }

}
