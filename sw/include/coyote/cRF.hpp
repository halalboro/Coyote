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

#ifndef _COYOTE_CRF_HPP_
#define _COYOTE_CRF_HPP_

#include <cstdint>

namespace coyote {

/**
 * @brief Control of the RF data converters of a shell built with EN_RF (ZCU216 only)
 *
 * The reference clocks are not programmed here: they stay programmed until the board is power cycled, and are
 * set with PYNQ's xrfclk (see docs/source/intro/zcu216-notes.rst). The driver shuts the DAC tile down whenever
 * it loads. If this object started the DAC tile, its destructor stops the DAC stream and shuts the tile down again;
 * a process that is killed leaves it running until the driver is next loaded.
 */
class cRF {
public:
    /// The converter tiles used by the shell on the ZCU216 (hw/bd/zynq_us_plus/cr_rf.tcl)
    static constexpr int ADC_TILE = 2;
    static constexpr int DAC_TILE = 2;

    /// Tile state machine: off, and running
    static constexpr uint32_t TILE_STATE_OFF = 1;
    static constexpr uint32_t TILE_STATE_RUNNING = 15;

    /// Maps the registers through the driver; throws if the loaded shell has no RF data converters
    cRF(unsigned int vfid = 0, unsigned int device = 0);
    ~cRF();
    cRF(const cRF &) = delete;
    cRF &operator=(const cRF &) = delete;

    /// Current state of the tile's state machine
    uint32_t adcState() const;
    uint32_t dacState() const;

    /// True if the tile's PLL is locked
    bool adcLocked() const;
    bool dacLocked() const;

    /// Starts the ADC tile and waits until it runs; returns false after about 1 s if it does not
    bool adcStart();

    /// Starts the DAC tile and waits until it runs; returns false after about 1 s if it does not, leaving it off
    /// Only call this when you know what the DAC output is connected to: the output is live as soon as it runs
    bool dacStart();

    /// Shuts a tile down and waits until it is off; returns false after about 1 s if it is not
    bool adcShutdown();
    bool dacShutdown();

    /// Turns the ADC stream to the vFPGA on or off; turning it off clears its flag and counter
    /// With test_pattern, the stream carries consecutive 16-bit values instead of samples
    void adcStream(bool enable, bool test_pattern = false);

    /// Turns the DAC stream from the vFPGA on or off; turning it off clears its flag and counter, and outputs zeros
    void dacStream(bool enable);

    /// True if the DAC ran out of data since its stream was enabled
    bool dacUnderflow() const;

    /// Number of 64-byte words sent to the DAC since its stream was enabled
    uint32_t dacWords() const;

    /// True if ADC words were dropped since the stream was enabled
    bool adcOverflow() const;

    /// Number of 64-byte words taken from the ADC since the stream was enabled
    uint32_t adcWords() const;

private:
    int fd;
    volatile uint32_t *regs;
    uint32_t ctrl = 0;
    bool dac_started = false;

    uint32_t tileRd(uint32_t tile_base, uint32_t offs) const;
    bool tileRestart(uint32_t tile_base, uint32_t start, uint32_t end);
    void writeCtrl(uint32_t bits, uint32_t mask);
};

}

#endif
