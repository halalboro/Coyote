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

// Programs the ZCU216's reference clock chips over SPI, as PYNQ's xrfclk does with set_ref_clks(245.76, 491.52).
// The register values are PYNQ's LMK04828_245.76.txt and LMX2594_491.52.txt (Copyright (c) 2021, Xilinx, Inc., BSD 3-clause).

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <unistd.h>
#include <vector>

namespace coyote {

static const uint32_t LMK04828_245_76[] = {
    0x000090, 0x000010, 0x000200, 0x000306, 0x0004D0, 0x00055B, 0x000600, 0x000C51, 0x000D04, 0x01006A,
    0x010155, 0x010255, 0x010301, 0x010422, 0x010500, 0x010673, 0x010703, 0x01086A, 0x010955, 0x010A55,
    0x010B00, 0x010C22, 0x010D00, 0x010EF0, 0x010F30, 0x01106A, 0x011155, 0x011255, 0x011301, 0x011422,
    0x011500, 0x011673, 0x011703, 0x01186A, 0x011955, 0x011A55, 0x011B01, 0x011C22, 0x011D00, 0x011E72,
    0x011F03, 0x012074, 0x012155, 0x012255, 0x012301, 0x012422, 0x012500, 0x012670, 0x012733, 0x01286A,
    0x012955, 0x012A55, 0x012B00, 0x012C22, 0x012D00, 0x012EF0, 0x012F30, 0x01306A, 0x013155, 0x013255,
    0x013301, 0x013422, 0x013500, 0x013673, 0x013703, 0x013800, 0x013903, 0x013A01, 0x013B40, 0x013C00,
    0x013D01, 0x013E03, 0x013F02, 0x014009, 0x014100, 0x014200, 0x014331, 0x0144FF, 0x01457F, 0x014618,
    0x01471A, 0x014806, 0x014946, 0x014A06, 0x014B06, 0x014C00, 0x014D00, 0x014EC0, 0x014F7F, 0x015013,
    0x015102, 0x015200, 0x015300, 0x01547D, 0x015500, 0x01567D, 0x015703, 0x0158C0, 0x015907, 0x015AD0,
    0x015BDA, 0x015C20, 0x015D00, 0x015E00, 0x015F3E, 0x016000, 0x016119, 0x016244, 0x016300, 0x016400,
    0x0165A0, 0x0171AA, 0x017202, 0x017C15, 0x017D33, 0x016600, 0x016700, 0x0168C0, 0x016959, 0x016A20,
    0x016B00, 0x016C00, 0x016D00, 0x016E1B, 0x017300, 0x1FFD00, 0x1FFE00, 0x1FFF53
};

static const uint32_t LMX2594_491_52[] = {
    0x700000, 0x6F0000, 0x6E0000, 0x6D0000, 0x6C0000, 0x6B0000, 0x6A0000, 0x690021, 0x680000, 0x670000,
    0x663F80, 0x650011, 0x640000, 0x630000, 0x620200, 0x610888, 0x600000, 0x5F0000, 0x5E0000, 0x5D0000,
    0x5C0000, 0x5B0000, 0x5A0000, 0x590000, 0x580000, 0x570000, 0x560000, 0x55D300, 0x540001, 0x530000,
    0x521E00, 0x510000, 0x506666, 0x4F0026, 0x4E00E5, 0x4D0000, 0x4C000C, 0x4B0940, 0x4A0000, 0x49003F,
    0x480001, 0x470081, 0x46C350, 0x450000, 0x4403E8, 0x430000, 0x4201F4, 0x410000, 0x401388, 0x3F0000,
    0x3E0322, 0x3D00A8, 0x3C0000, 0x3B0001, 0x3A8001, 0x390020, 0x380000, 0x370000, 0x360000, 0x350000,
    0x340820, 0x330080, 0x320000, 0x314180, 0x300300, 0x2F0300, 0x2E07FC, 0x2DC0DF, 0x2C1FA0, 0x2B0000,
    0x2A0000, 0x290000, 0x280000, 0x270001, 0x260000, 0x250104, 0x240140, 0x230004, 0x220000, 0x211E21,
    0x200393, 0x1F43EC, 0x1E318C, 0x1D318C, 0x1C0488, 0x1B0002, 0x1A0DB0, 0x190624, 0x18071A, 0x17007C,
    0x160001, 0x150401, 0x14C848, 0x1327B7, 0x120064, 0x110117, 0x100080, 0x0F064F, 0x0E1E40, 0x0D4000,
    0x0C5001, 0x0B00A8, 0x0A10D8, 0x090604, 0x082000, 0x0740B2, 0x06C802, 0x0500C8, 0x040C43, 0x030642,
    0x020500, 0x010809, 0x00241C
};

// The 24-bit words to send to a chip, in order
std::vector<uint32_t> rfClockWords(bool lmx) {
    if (!lmx) {
        return std::vector<uint32_t>(std::begin(LMK04828_245_76), std::end(LMK04828_245_76));
    }
    // Reset, remove the reset, then the registers. R0, the last, goes twice so that the VCO calibration runs from a stable state.
    std::vector<uint32_t> words = { 0x020000, 0x000000 };
    words.insert(words.end(), std::begin(LMX2594_491_52), std::end(LMX2594_491_52));
    words.push_back(words.back());
    return words;
}

namespace fs = std::filesystem;

static void writeSysfs(const fs::path &path, const std::string &value) {
    std::ofstream f(path);
    f << value;
    f.flush();
    if (!f) { throw std::runtime_error("ERROR: could not write " + path.string() + "; run as root"); }
}

// Returns the /dev node of an SPI device, binding it to the spidev driver if needed
static std::string spidevNode(const fs::path &dev) {
    if (!fs::exists(dev / "spidev")) {
        if (fs::exists(dev / "driver")) {
            writeSysfs(dev / "driver" / "unbind", dev.filename().string());
        }
        writeSysfs(dev / "driver_override", "spidev");
        writeSysfs("/sys/bus/spi/drivers/spidev/bind", dev.filename().string());
    }
    for (const auto &entry : fs::directory_iterator(dev / "spidev")) {
        return "/dev/" + entry.path().filename().string();
    }
    throw std::runtime_error("ERROR: no spidev node for " + dev.string());
}

static void writeChip(const std::string &node, const std::vector<uint32_t> &words) {
    int fd = open(node.c_str(), O_RDWR | O_CLOEXEC);
    if (fd < 0) { throw std::runtime_error("ERROR: could not open " + node + "; run as root"); }
    for (uint32_t word : words) {
        uint8_t bytes[3] = { (uint8_t) (word >> 16), (uint8_t) (word >> 8), (uint8_t) word };
        if (write(fd, bytes, 3) != 3) {
            close(fd);
            throw std::runtime_error("ERROR: an SPI write to " + node + " failed: " + strerror(errno));
        }
    }
    close(fd);
}

// The LMK feeds the LMXs, so it goes first
void rfClockProgram() {
    std::vector<fs::path> lmk, lmx;
    for (const auto &entry : fs::directory_iterator("/sys/bus/spi/devices")) {
        std::ifstream f(entry.path() / "of_node" / "compatible");
        std::string compatible;
        std::getline(f, compatible, '\0');
        if (compatible == "ti,lmk04828") { lmk.push_back(entry.path()); }
        if (compatible == "ti,lmx2594") { lmx.push_back(entry.path()); }
    }
    if (lmk.size() != 1 || lmx.empty()) {
        throw std::runtime_error("ERROR: did not find the ZCU216 clock chips (one LMK04828 and LMX2594s) in the device tree");
    }
    std::sort(lmx.begin(), lmx.end());

    writeChip(spidevNode(lmk[0]), rfClockWords(false));
    for (const auto &dev : lmx) {
        writeChip(spidevNode(dev), rfClockWords(true));
    }
}

}
