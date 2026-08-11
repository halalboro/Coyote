/**
 * Coyote Example 15: AMC Ping — host-side first-light test.
 *
 * Reads AMC's partition-table magic from DDR4 via PCIe BAR4 mmap to confirm
 * the AMC firmware booted on R5 and wrote its data structures.
 *
 * BAR4 layout (V80 + EN_AMC=1):
 *   PCIe offset                  Target
 *   0x0000_0000 .. 0x07FF_FFFF   axi_main      (128 MB shell control)
 *   0x0800_0000 .. 0x0800_FFFF   gcq_m2r/S00   (64 KB host producer regs)
 *   0x0A00_0000 .. 0x0BFF_FFFF   DDR4 window   (32 MB → DDR4 0x0..0x2000000)
 *
 * Window starts at BAR4 + 160 MB rather than packed against the GCQ because
 * Versal NoC REMAPS requires the master base to be range-aligned (32 MB).
 *
 * AMC's HAL_RPU_SHARED_MEMORY_BASE_ADDR = 0x00100000 (DDR4 offset, Coyote-patched).
 * So host reads BAR4 + 0x0A00_0000 + 0x0010_0000 = BAR4 + 0x0A10_0000.
 *
 * AMC writes HAL_PARTITION_TABLE_MAGIC_NO = 0x564D5230 ("VMR0") as the first
 * 4 bytes of HAL_PARTITION_TABLE at SHARED_MEMORY_BASE_ADDR during boot
 * (see amc.c:1042-1063).
 */

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <cstring>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

#include <boost/program_options.hpp>

namespace po = boost::program_options;

constexpr uint32_t AMC_PARTITION_TABLE_MAGIC = 0x564D5230; // "VMR0"

// BAR4 layout
constexpr off_t  BAR4_SIZE             = 256ULL * 1024 * 1024;  // 256 MB
constexpr off_t  BAR4_OFF_DDR4_WINDOW  = 0x0A000000;            // DDR4 window: BAR4 + 160 MB (32 MB aligned, REMAPS constraint)
constexpr off_t  AMC_SHARED_MEM_DDR4   = 0x00100000;            // AMC HAL: shared mem base in DDR4
constexpr off_t  AMC_MAGIC_BAR4_OFF    = BAR4_OFF_DDR4_WINDOW + AMC_SHARED_MEM_DDR4;

int main(int argc, char* argv[]) {
    std::string bdf;
    int retries;
    int retry_ms;

    po::options_description desc("Coyote Example 15: AMC Ping");
    desc.add_options()
        ("bdf,b",     po::value<std::string>(&bdf)->default_value("0000:61:00.0"),
                      "PCIe BDF of the V80 (use `lspci -d 10ee:` to find)")
        ("retries,r", po::value<int>(&retries)->default_value(20),
                      "Number of times to retry the magic check (AMC may still be booting)")
        ("retry-ms",  po::value<int>(&retry_ms)->default_value(100),
                      "Milliseconds to sleep between retries");
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    std::cout << "=== Coyote Example 15: AMC Ping ===\n"
              << "BDF: " << bdf << "\n";

    // Open BAR4 via PCI sysfs resource interface
    std::string bar4_path = "/sys/bus/pci/devices/" + bdf + "/resource4";
    int fd = open(bar4_path.c_str(), O_RDWR | O_SYNC);
    if (fd < 0) {
        std::cerr << "ERROR: cannot open " << bar4_path << ": " << strerror(errno) << "\n";
        std::cerr << "       (need root, and the card must be PCI-visible)\n";
        return 1;
    }

    // Read-only mapping: this kernel rejects a writable mmap of the (non-WC)
    // PCIe BAR sysfs resource with EINVAL. The test only reads the magic.
    void* bar4 = mmap(nullptr, BAR4_SIZE, PROT_READ, MAP_SHARED, fd, 0);
    if (bar4 == MAP_FAILED) {
        std::cerr << "ERROR: mmap of BAR4 failed: " << strerror(errno) << "\n";
        close(fd);
        return 1;
    }
    std::cout << "Mapped BAR4 (256 MB) at host VA " << bar4 << "\n";
    std::cout << "Probing AMC partition-table magic at BAR4+0x" << std::hex
              << AMC_MAGIC_BAR4_OFF << std::dec
              << " (DDR4 offset 0x" << std::hex << AMC_SHARED_MEM_DDR4 << std::dec << ")\n";

    volatile uint32_t* magic_ptr =
        reinterpret_cast<volatile uint32_t*>(static_cast<uint8_t*>(bar4) + AMC_MAGIC_BAR4_OFF);

    uint32_t magic = 0;
    int attempt = 0;
    bool ok = false;
    for (attempt = 0; attempt < retries; attempt++) {
        magic = *magic_ptr;
        if (magic == AMC_PARTITION_TABLE_MAGIC) {
            ok = true;
            break;
        }
        usleep(retry_ms * 1000);
    }

    std::cout << "Read after " << (attempt + 1) << " attempts: 0x"
              << std::hex << std::setw(8) << std::setfill('0') << magic
              << std::dec << std::setfill(' ') << "\n";

    munmap(bar4, BAR4_SIZE);
    close(fd);

    if (ok) {
        std::cout << "*** PASS: AMC firmware booted and wrote partition table ***\n";
        return 0;
    }

    std::cout << "*** FAIL: expected 0x" << std::hex << AMC_PARTITION_TABLE_MAGIC
              << ", got 0x" << magic << std::dec << " ***\n";
    if (magic == 0xFFFFFFFF) {
        std::cout << "  Hint: 0xFFFFFFFF often means PCIe path returns no data — "
                  << "check that the BAR4→DDR4 address mapping was assigned and "
                  << "that DDR4 calibration succeeded (look for DDRMC errors in dmesg).\n";
    } else if (magic == 0x00000000) {
        std::cout << "  Hint: 0x00000000 often means DDR4 is reachable but AMC never "
                  << "wrote the partition table — check `dmesg` for PMC-side errors "
                  << "loading amc.elf, and verify amc.elf is in the PDI (`grep amc cyt_top.bif`).\n";
    }
    return 1;
}
