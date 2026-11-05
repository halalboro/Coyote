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
 * Channels: 0 is tile 2 block 0, 1 is tile 2 block 2, 2 is tile 3 block 0, 3 is tile 3 block 2. Older shells only have channel 0.
 * Tile 3 takes its clock from tile 2, so the tiles of a direction are always started and shut down together.
 *
 * The reference clocks stay programmed until the board is power cycled; programClocks() sets them, and PYNQ's xrfclk
 * can too (see docs/source/intro/zcu216-notes.rst). The driver shuts the DAC tile down whenever it loads. If this object started the DAC tiles, its destructor stops the DAC stream and shuts them down again;
 * a process that is killed leaves it running until the driver is next loaded.
 */
class cRF {
public:
    /// The first converter tiles used by the shell on the ZCU216 (hw/bd/zynq_us_plus/cr_rf.tcl)
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

    /// Number of converter channels in each direction, and tiles they are on
    int channels() const;
    int tiles() const;

    /// Sampling rate of all converters, in samples per second, set when the shell is built (RF_RATE_KHZ)
    double sampleRate() const;

    /// Current state of a tile's state machine
    uint32_t adcState(int tile = ADC_TILE) const;
    uint32_t dacState(int tile = DAC_TILE) const;

    /// True if a tile's PLL is locked
    bool adcLocked(int tile = ADC_TILE) const;
    bool dacLocked(int tile = DAC_TILE) const;

    /// True if every tile of the direction is running or off
    bool adcRunning() const;
    bool dacOff() const;

    /// Starts the ADC tiles and waits until they run; returns false after about 1 s per tile if they do not
    bool adcStart();

    /// Starts the DAC tiles and waits until they run; returns false after about 1 s per tile if they do not, leaving them off
    /// Only call this when you know what the DAC output is connected to: the output is live as soon as it runs
    bool dacStart();

    /// Shuts the tiles down and waits until they are off; returns false after about 1 s per tile if they are not
    bool adcShutdown();
    bool dacShutdown();

    /// Shuts down and starts one DAC tile; tile 3 needs tile 2 running to pass data. Returns false if it did not reach the state.
    bool dacRestart(int tile);

    /// Programs the reference clock chips for 2.4576 GS/s and restarts the ADC tiles, leaving the DAC tiles off; needs root.
    /// Returns false if the DAC tiles did not stay off or the ADC tiles did not start; throws if the chips cannot be written.
    /// Everything using the converters stops while this runs, and the timing between ADC and DAC samples can change.
    bool programClocks();

    /// Chooses the channel of a stream; only call these while that stream is off
    void adcSelect(int channel);
    void dacSelect(int channel);

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
    uint32_t select = 0;
    bool dac_started = false;

    uint32_t tileRd(uint32_t tile_base, uint32_t offs) const;
    bool tileRestart(uint32_t tile_base, uint32_t start, uint32_t end);
    void writeCtrl(uint32_t bits, uint32_t mask);
};

}

#endif
