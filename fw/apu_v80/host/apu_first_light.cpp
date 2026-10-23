/**
 * A72 (APU) first-light reader — host side.
 *
 * The A72 publishes a status block straight into DDR at 0x01FE_0000. The host
 * sees it through the driver's MMAP_AMC region, which maps BAR4+AMC_DDR_OFFS
 * onto DDR 0x0 (a 64 MB window when EN_APU=1). Nothing relays for the APU: it
 * reaches DDR itself over FPD_CCI_NOC, so a failure here points at the A72 boot
 * and nothing else.
 *
 * (MMAP_AMC is a historical name — the window is shared, not AMC-specific.)
 *
 * Build:  versal-shell -c 'g++ -std=c++17 -O2 -Wall -o apu_first_light apu_first_light.cpp'
 * Run:    sudo ./apu_first_light
 */
#include <cstdint>
#include <cstdio>
#include <ctime>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <glob.h>
#include <string>

static constexpr long     PAGE        = 4096;
static constexpr long     MMAP_AMC    = 0x4;
static constexpr size_t   WIN_SIZE    = 0x04000000;   // 64 MB DDR window (EN_APU)
static constexpr uint32_t STATUS_DDR  = 0x01FE0000;   // written by the A72 itself
static constexpr uint32_t STATUS_MAGIC= 0xA72F1157;

// Word layout, must match fw/apu_v80/src/first_light.c
enum { ST_MAGIC = 0, ST_HEARTBEAT = 1, ST_UART0 = 2, ST_UART1 = 3 };

static std::string find_dev() {
    glob_t g; std::string r;
    if (glob("/dev/coyote_fpga_*_v*", 0, nullptr, &g) == 0 && g.gl_pathc) r = g.gl_pathv[0];
    globfree(&g);
    return r;
}

int main() {
    std::string dev = find_dev();
    if (dev.empty()) { fprintf(stderr, "no coyote device (/dev/coyote_fpga_*_v*)\n"); return 2; }

    int fd = open(dev.c_str(), O_RDWR | O_SYNC);
    if (fd < 0) { perror("open"); return 2; }

    volatile uint8_t *base = (volatile uint8_t *) mmap(
        nullptr, WIN_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, MMAP_AMC * PAGE);
    if (base == MAP_FAILED) { perror("mmap MMAP_AMC"); close(fd); return 2; }

    auto st = [&](int w){ return *(volatile uint32_t *)(base + STATUS_DDR + 4 * w); };

    uint32_t magic = st(ST_MAGIC);
    printf("A72 first light — status block @ DDR 0x%08X\n", STATUS_DDR);

    if (magic != STATUS_MAGIC) {
        printf("  magic     : 0x%08X (expected 0x%08X)\n\n", magic, STATUS_MAGIC);
        printf("FAIL: the A72 never wrote its status block.\n"
               "  Either the a72-0 partition did not start, or it started but\n"
               "  cannot reach DDR. To tell the two apart, attach XSDB over JTAG\n"
               "  and read the OCM copy at 0xFFFD_0000: present there but absent\n"
               "  here means the core ran and the DDR path is at fault.\n");
        munmap((void *) base, WIN_SIZE); close(fd);
        return 3;
    }

    // The A72 writes the magic last, so the rest of the block is valid by now.
    uint32_t beat1 = st(ST_HEARTBEAT);
    uint32_t u0 = st(ST_UART0), u1 = st(ST_UART1);

    // The heartbeat is SLOW: with the MMU and caches off, the A72's delay loop
    // takes ~4.6 s per beat (measured on clara). A single 1 s sample reports a
    // healthy core as STALLED, so poll for up to MAX_WAIT_S for it to advance.
    static constexpr int MAX_WAIT_S = 20;
    uint32_t beat2 = beat1;
    int waited = 0;
    struct timespec ts { 1, 0 };
    while (waited < MAX_WAIT_S && beat2 == beat1) {
        nanosleep(&ts, nullptr);
        waited++;
        beat2 = st(ST_HEARTBEAT);
    }

    printf("  magic     : 0x%08X (ok)\n", magic);
    printf("  heartbeat : %u -> %u after %d s  %s\n", beat1, beat2, waited,
           beat2 != beat1 ? "(RUNNING)" : "(STALLED: no change in 20 s)");
    printf("  uart0     : %u chars accepted\n", u0);
    printf("  uart1     : %u chars accepted\n", u1);

    bool pass = (beat2 != beat1);
    printf("\n%s\n", pass ? "PASS: the A72 booted and is running, and reached DDR on its own"
                          : "FAIL: the A72 wrote its block but the heartbeat is not advancing");

    if (u0 && u1)
        printf("Console: both PS UARTs accepted output (clara V80: they appear on ttyUSB2/ttyUSB3)\n");
    else if (u0 || u1)
        printf("Console: only UART%d accepted output\n", u0 ? 0 : 1);
    else
        printf("Console: neither PS UART accepted output -- no serial console on this card;\n"
               "         Linux will need HVC over JTAG DCC or a DDR ring-buffer console.\n");

    munmap((void *) base, WIN_SIZE); close(fd);
    return pass ? 0 : 3;
}
