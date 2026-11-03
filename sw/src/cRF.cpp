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

// Layout of the window the driver maps; must match driver/include/coyote_defs.h
static constexpr uint64_t RF_WINDOW_SIZE = 0x41000;
static constexpr uint32_t RF_SERVICE_OFFS = 0x40000;

// RF service registers (hw/hdl/rf/rf_slave.sv)
static constexpr uint32_t RF_ID_REG = 0x00;
static constexpr uint32_t RF_CTRL_REG = 0x04;
static constexpr uint32_t RF_STATUS_REG = 0x08;
static constexpr uint32_t RF_ADC_WORDS_REG = 0x0C;
static constexpr uint32_t RF_ID = 0x52460001;

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

uint32_t cRF::adcState() const { return tileRd(adcTile(ADC_TILE), TILE_CURRENT_STATE); }
uint32_t cRF::dacState() const { return tileRd(dacTile(DAC_TILE), TILE_CURRENT_STATE); }
bool cRF::adcLocked() const { return tileRd(adcTile(ADC_TILE), TILE_STATUS) & TILE_PLL_LOCKED; }
bool cRF::dacLocked() const { return tileRd(dacTile(DAC_TILE), TILE_STATUS) & TILE_PLL_LOCKED; }

bool cRF::adcStart() { return tileRestart(adcTile(ADC_TILE), TILE_STATE_OFF, TILE_STATE_RUNNING); }
bool cRF::adcShutdown() { return tileRestart(adcTile(ADC_TILE), TILE_STATE_OFF, TILE_STATE_OFF); }
bool cRF::dacShutdown() { return tileRestart(dacTile(DAC_TILE), TILE_STATE_OFF, TILE_STATE_OFF); }

void cRF::adcStream(bool enable, bool test_pattern) {
    // Bit 1, the DAC stream, stays 0
    regs[(RF_SERVICE_OFFS + RF_CTRL_REG) / 4] = (test_pattern ? 0x4 : 0x0);
    regs[(RF_SERVICE_OFFS + RF_CTRL_REG) / 4] = (test_pattern ? 0x4 : 0x0) | (enable ? 0x1 : 0x0);
}

bool cRF::adcOverflow() const { return regs[(RF_SERVICE_OFFS + RF_STATUS_REG) / 4] & 0x1; }
uint32_t cRF::adcWords() const { return regs[(RF_SERVICE_OFFS + RF_ADC_WORDS_REG) / 4]; }

}
