/**
 * Coyote Example 15 — AMC + vFPGA coexistence demo.
 *
 * One host program that exercises BOTH, with coyote_driver loaded:
 *   1) the vFPGA:  host -> vFPGA -> host DMA loopback through perf_local, which
 *                  increments each 32-bit word by 1 (verified: dst == src + 1).
 *   2) the AMC:    an AMI heartbeat over the GCQ mailbox, reached via the driver's
 *                  MMAP_AMC region (BAR4 DDR window) — no BAR-detach hack.
 *
 * Proves the AMC (R5 management) and a functional vFPGA (user datapath) coexist
 * on the same card, driven together from one process.
 */

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <glob.h>
#include <boost/program_options.hpp>

#include <coyote/cThread.hpp>

// ---- AMC / GCQ (must match driver coyote_defs.h + AMC firmware) ------------
static constexpr long   PAGE       = 4096;
static constexpr long   MMAP_AMC   = 0x4;
static constexpr size_t AMC_SIZE   = 0x02000000;     // 32 MB
static constexpr uint32_t SHMEM    = 0x00100000;     // AMC shared-mem base in the window
static constexpr uint32_t RING     = SHMEM + 0x1000; // GCQ ring header
static constexpr uint32_t PT_MAGIC = 0x564D5230;     // "VMR0"
static constexpr uint32_t GCQ_MAGIC= 0x5847513F;
static constexpr uint32_t OP_HEARTBEAT = 0x2;
// ring-header offsets
enum { H_MAGIC=0,H_VER=4,H_SLOTS=8,H_SQOFF=12,H_SQSZ=16,H_CQOFF=20,
       H_SQCONS=24,H_CQCONS=28,H_FLAGS=32,H_SQPROD=36,H_CQPROD=40 };

static std::string find_dev() {
    glob_t g; std::string r;
    if (glob("/dev/coyote_fpga_*_v*", 0, nullptr, &g) == 0 && g.gl_pathc)
        r = g.gl_pathv[0];
    globfree(&g);
    return r;
}

// Send one heartbeat over the GCQ mailbox via the driver's MMAP_AMC region.
static bool amc_heartbeat() {
    std::string dev = find_dev();
    if (dev.empty()) { std::cerr << "  no coyote device\n"; return false; }
    int fd = open(dev.c_str(), O_RDWR | O_SYNC);
    if (fd < 0) { std::cerr << "  open " << dev << " failed\n"; return false; }
    volatile uint8_t *base = (volatile uint8_t *) mmap(
        nullptr, AMC_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, MMAP_AMC * PAGE);
    if (base == MAP_FAILED) { std::cerr << "  mmap MMAP_AMC failed\n"; close(fd); return false; }
    auto rd = [&](uint32_t o){ return *(volatile uint32_t *)(base + o); };
    auto wr = [&](uint32_t o, uint32_t v){ *(volatile uint32_t *)(base + o) = v; };

    bool ok = false;
    if (rd(SHMEM) != PT_MAGIC)       { std::cerr << "  no VMR0\n"; }
    else if (rd(RING+H_MAGIC) != GCQ_MAGIC) { std::cerr << "  GCQ not ready\n"; }
    else {
        uint32_t slots = rd(RING+H_SLOTS), mask = slots-1;
        uint32_t sqoff = rd(RING+H_SQOFF), sqsz = rd(RING+H_SQSZ), cqoff = rd(RING+H_CQOFF);
        uint32_t sq_prod = rd(RING+H_SQPROD), cq_cons = rd(RING+H_CQCONS);
        if (rd(RING+H_CQPROD) != cq_cons) { cq_cons = rd(RING+H_CQPROD); wr(RING+H_CQCONS, cq_cons); }

        uint32_t cid = 0x00E5, count = 0x7C;
        uint32_t slot = RING + sqoff + (sq_prod & mask) * sqsz;
        for (uint32_t i = 0; i < sqsz; i += 4) wr(slot+i, 0);
        wr(slot+0, OP_HEARTBEAT); wr(slot+4, cid); wr(slot+8, count);
        (void) rd(slot + sqsz - 4);
        sq_prod += 1; wr(RING+H_SQPROD, sq_prod); (void) rd(RING+H_SQPROD);

        for (int t = 0; t < 5000 && rd(RING+H_CQPROD) == cq_cons; ++t) usleep(1000);
        if (rd(RING+H_CQPROD) != cq_cons) {
            uint32_t cq = RING + cqoff + (cq_cons & mask) * 16;
            uint32_t w0 = rd(cq), w1 = rd(cq+4), w3 = rd(cq+12);
            cq_cons += 1; wr(RING+H_CQCONS, cq_cons);
            ok = ((w0 & 0xFFFF) == cid && ((w0>>16)&0x3FFF) == 0 && w3 == 0 && (w1 & 0xFF) == count);
            std::cout << "  AMC heartbeat -> cid=0x" << std::hex << (w0 & 0xFFFF)
                      << " echo=0x" << (w1 & 0xFF) << " rcode=" << std::dec << w3 << "\n";
        } else std::cerr << "  AMC heartbeat timeout\n";
    }
    munmap((void*)base, AMC_SIZE); close(fd);
    return ok;
}

int main(int argc, char *argv[]) {
    unsigned int size; int vfid;
    boost::program_options::options_description opt("Example 15: AMC + vFPGA demo");
    opt.add_options()
        ("vfid,i", boost::program_options::value<int>(&vfid)->default_value(0), "vFPGA id")
        ("size,s", boost::program_options::value<unsigned int>(&size)->default_value(4096), "transfer size [B]");
    boost::program_options::variables_map vm;
    boost::program_options::store(boost::program_options::parse_command_line(argc, argv, opt), vm);
    boost::program_options::notify(vm);

    std::cout << "=== Example 15: AMC + vFPGA coexistence ===\n";

    // ---- 1) vFPGA loopback (+1 per 32-bit word) ----------------------------
    std::cout << "[vFPGA] host->vFPGA->host loopback, " << size << " B\n";
    coyote::cThread coyote_thread(vfid, getpid());
    int *src = (int *) coyote_thread.getMem({coyote::CoyoteAllocType::HPF, size});
    int *dst = (int *) coyote_thread.getMem({coyote::CoyoteAllocType::HPF, size});
    if (!src || !dst) { std::cerr << "getMem failed\n"; return 1; }
    for (unsigned i = 0; i < size/sizeof(int); ++i) { src[i] = (int)(i*2654435761u); dst[i] = 0; }

    coyote::localSg src_sg = { .addr = src, .len = size, .stream = true };
    coyote::localSg dst_sg = { .addr = dst, .len = size, .stream = true };
    coyote_thread.clearCompleted();
    coyote_thread.invoke(coyote::CoyoteOper::LOCAL_TRANSFER, src_sg, dst_sg);
    while (coyote_thread.checkCompleted(coyote::CoyoteOper::LOCAL_TRANSFER) != 1) {}

    bool vfpga_ok = true;
    for (unsigned i = 0; i < size/sizeof(int); ++i)
        if ((uint32_t)dst[i] != (uint32_t)src[i] + 1) { vfpga_ok = false;
            std::cerr << "  mismatch @" << i << ": dst=" << dst[i] << " expected " << src[i]+1 << "\n"; break; }
    std::cout << "[vFPGA] " << (vfpga_ok ? "PASS — dst == src + 1 (vFPGA processed the data)" : "FAIL") << "\n";

    // ---- 2) AMC heartbeat, driver still loaded, vFPGA still open -----------
    std::cout << "[AMC] heartbeat via MMAP_AMC (driver loaded, cThread alive)\n";
    bool amc_ok = amc_heartbeat();
    std::cout << "[AMC] " << (amc_ok ? "PASS — R5 replied" : "FAIL") << "\n";

    std::cout << "\n*** " << ((vfpga_ok && amc_ok)
        ? "PASS — vFPGA datapath + AMC management coexist on one card ***"
        : "FAIL ***") << "\n";
    return (vfpga_ok && amc_ok) ? 0 : 1;
}
