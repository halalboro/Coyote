/*
 * a72_vfpga — Coyote V80 A72 (Linux) on-target vFPGA + host-mailbox utility.
 *
 * Runs on the A72 under Linux and reaches hardware through /dev/mem. It turns the
 * one-off `devmem` proof (phase A3) into a real on-target program:
 *
 *   a72_vfpga info        read vFPGA 0 axi_ctrl (R5VP magic + verdict registers)
 *   a72_vfpga mbox [N]    serve N host<->A72 shared-DDR mailbox exchanges (default 16)
 *   a72_vfpga             info, then mbox 16
 *
 * Addresses, in the A72's physical view:
 *   vFPGA 0 axi_ctrl user = 0x4_0012_0000
 *       M_AXI_FPD -> axi_main (0x4_0000_0000) + VFPGA_CTRL_OFFS 0x100000 + USER 0x20000.
 *       This is the SAME register file the host reads at BAR4 + 0x120000.
 *   host-shared mailbox   = 0x0000_01F0_0000
 *       DDR below Linux RAM (RAM starts 0x0200_0000), so /dev/mem maps it as device
 *       (non-cacheable) memory — which is exactly why it stays coherent with the host
 *       (the A2 finding: cached A72 mappings do NOT see host writes). The host reaches
 *       the same bytes at BAR4 + 0x0C000000 + 0x01F00000.
 *
 * Mailbox layout (host-written and A72-written words in separate 64-byte lines, tidy
 * but not load-bearing):
 *   +0x00  req        (host writes)   <- request line
 *   +0x04  req_seq    (host writes)
 *   +0x40  resp       (A72 writes)    <- response line
 *   +0x44  resp_seq   (A72 writes)
 * Host writes req then bumps req_seq; the A72 sees the new req_seq, computes
 * resp = req + 1, then echoes resp_seq = req_seq. This handshake needs no locks.
 *
 * The real subtlety (root-caused on HW 2026-09-20): right after the A72 writes its
 * response to this Device-mapped DDR, its next read of req_seq can return a transient
 * 0 (a read-after-write hazard on the FPD_CCI_NOC->DDR path; NOT caching, NOT the host,
 * NOT write-combining — all ruled out). The loop below rejects it by requiring req_seq
 * to be nonzero and stable across an immediate re-read.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <sys/mman.h>

#define VFPGA_CTRL_PHYS  0x400120000UL
#define MBOX_PHYS        0x001F00000UL
#define MAP_SZ           0x1000UL       /* one page each; both bases are page aligned */

/* Verdict register file (64-bit words), mirrors coprocessor_verdict.hpp. */
enum { VMAGIC = 0, VERD0, VERD1, VERD2, VERD3 };
#define R5VP_MAGIC 0x52355650u          /* "R5VP" */

/* Mailbox word indices (u32) within their cache lines. */
enum { REQ = 0, REQ_SEQ = 1 };          /* request line  @ +0x00 (host writes) */
enum { RESP = 0, RESP_SEQ = 1 };        /* response line @ +0x40 (A72 writes)  */
#define RESP_LINE_OFF 0x40              /* separate 64-byte cache line */

static volatile void *map_phys(int fd, unsigned long phys) {
    void *p = mmap(NULL, MAP_SZ, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)phys);
    if (p == MAP_FAILED) {
        fprintf(stderr, "mmap /dev/mem @ 0x%lx: %s\n", phys, strerror(errno));
        return NULL;
    }
    return p;
}

static uint64_t now_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int do_info(int fd) {
    volatile uint8_t *b = (volatile uint8_t *) map_phys(fd, VFPGA_CTRL_PHYS);
    if (!b) return 2;
    /* Registers are 64-bit but the fabric only handles 32-bit MMIO here (a 64-bit read
     * returns all-ones, verified on HW 2026-09-20); read each as two adjacent 32-bit words. */
    #define RD64(word) (((uint64_t)*(volatile uint32_t *)(b + (word) * 8 + 4) << 32) \
                        | *(volatile uint32_t *)(b + (word) * 8))
    uint32_t magic = (uint32_t) RD64(VMAGIC);
    printf("vFPGA 0 axi_ctrl @ 0x%09lx (M_AXI_FPD):\n", VFPGA_CTRL_PHYS);
    printf("  magic : 0x%08x %s\n", magic, magic == R5VP_MAGIC ? "(R5VP ok)" : "(MISMATCH)");
    uint64_t v0 = RD64(VERD0), v1 = RD64(VERD1), v2 = RD64(VERD2), v3 = RD64(VERD3);
    printf("  verd0 : passed=%u total=%u\n",     (uint32_t)v0, (uint32_t)(v0 >> 32));
    printf("  verd1 : first_fail=%u done=%u\n",  (uint32_t)v1, (uint32_t)(v1 >> 32));
    printf("  verd2 : lat_min=%u lat_max=%u\n",  (uint32_t)v2, (uint32_t)(v2 >> 32));
    printf("  verd3 : lat_avg=%u r5_mhz=%u\n",   (uint32_t)v3, (uint32_t)(v3 >> 32));
    if ((uint32_t)(v1 >> 32) == 0)
        printf("  (verdict done=0: the R5 self-test has not been run/bound by the host)\n");
    #undef RD64
    munmap((void *)b, MAP_SZ);
    return magic == R5VP_MAGIC ? 0 : 1;
}

static int do_mbox(int fd, int n) {
    volatile uint8_t *base = (volatile uint8_t *) map_phys(fd, MBOX_PHYS);
    if (!base) return 2;
    volatile uint32_t *req_line = (volatile uint32_t *)(base);                  /* host writes */
    volatile uint32_t *rsp_line = (volatile uint32_t *)(base + RESP_LINE_OFF);  /* A72 writes  */
    printf("mailbox @ 0x%09lx: serving %d exchange(s) (resp = req + 1)\n", MBOX_PHYS, n);
    uint32_t last_seq = req_line[REQ_SEQ];
    for (int i = 0; i < n; ++i) {
        uint64_t deadline = now_ms() + 15000;
        uint32_t seq;
        /* Read-after-write hazard: right after the A72 writes its response to this
         * Device-mapped DDR, the next read of req_seq can return a transient 0
         * (proven on HW 2026-09-20 — independent of the host). Valid sequences are
         * always nonzero and hold steady, so accept req_seq only when it is nonzero,
         * different from the last, AND stable across an immediate re-read. */
        for (;;) {
            seq = req_line[REQ_SEQ];
            if (seq != last_seq && seq != 0 && seq == req_line[REQ_SEQ]) break;
            if (now_ms() > deadline) { fprintf(stderr, "[a72] timeout waiting for request %d\n", i + 1); munmap((void *)base, MAP_SZ); return 1; }
        }
        uint32_t req = req_line[REQ];
        rsp_line[RESP] = req + 1;      /* publish the response (separate cache line) ... */
        rsp_line[RESP_SEQ] = seq;      /* ... then release it by echoing the sequence */
        last_seq = seq;
        printf("[a72] req#%u 0x%08x -> 0x%08x\n", seq, req, req + 1);
    }
    printf("[a72] mailbox done (%d served)\n", n);
    munmap((void *)base, MAP_SZ);
    return 0;
}

int main(int argc, char **argv) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { fprintf(stderr, "open /dev/mem: %s\n", strerror(errno)); return 2; }

    const char *cmd = argc > 1 ? argv[1] : "all";
    int rc = 0;
    if (!strcmp(cmd, "info")) {
        rc = do_info(fd);
    } else if (!strcmp(cmd, "mbox")) {
        rc = do_mbox(fd, argc > 2 ? atoi(argv[2]) : 16);
    } else if (!strcmp(cmd, "all")) {
        rc = do_info(fd);
        rc |= do_mbox(fd, 16);
    } else {
        fprintf(stderr, "usage: %s [info | mbox [N] | all]\n", argv[0]);
        rc = 2;
    }
    close(fd);
    return rc;
}
