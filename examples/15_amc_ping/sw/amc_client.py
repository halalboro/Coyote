#!/usr/bin/env python3
# AMC mailbox client that reaches the AMC THROUGH the loaded coyote_driver
# (via the MMAP_AMC region of a vFPGA device), so the host can use the vFPGA
# and the AMC at the same time — no BAR-detach hack.
#
# Contrast with gcq_ping.py, which raw-mmaps sysfs resource4 and therefore
# needs coyote_driver unloaded. This one keeps the driver loaded.
#
# The driver maps BAR4 + 0x0A000000 (the AMC DDR4 window) at mmap offset
# MMAP_AMC*PAGE_SIZE on /dev/coyote_fpga_<n>_v<m>. So in the mapping:
#   partition table @ +0x00100000, GCQ ring @ +0x00101000, status @ +0x00102000
#
# Uses in-memory GCQ pointers (AMC built with GCQ_FLAGS_TYPE_IN_MEM_PTR_ENABLE):
# submit = write SQ-produced @ring+36, poll = read CQ-produced @ring+40. All DDR.

import mmap, struct, os, sys, time, glob

PAGE      = 4096
MMAP_AMC  = 0x4
AMC_SIZE  = 0x02000000            # 32 MB (matches driver AMC_DDR_SIZE)

SHMEM     = 0x00100000            # AMC shared-mem base within the DDR window
PT        = SHMEM                 # partition table (mapping starts at DDR 0x0)
RING      = PT + 0x1000
STATUS    = PT + 0x2000

PT_MAGIC  = 0x564D5230            # "VMR0"
GCQ_MAGIC = 0x5847513F
OP_HEARTBEAT = 0x2

# ring-header offsets
H_MAGIC, H_VER, H_SLOTS, H_SQOFF, H_SQSZ, H_CQOFF, H_SQCONS, H_CQCONS, \
    H_FLAGS, H_SQPROD, H_CQPROD = 0,4,8,12,16,20,24,28,32,36,40


def find_dev():
    for p in sorted(glob.glob("/dev/coyote_fpga_*_v*")):
        return p
    return None


def main():
    dev = sys.argv[1] if len(sys.argv) > 1 else find_dev()
    if not dev or not os.path.exists(dev):
        print("ERROR: no coyote vFPGA device (is coyote_driver loaded?)"); return 1
    print("Using Coyote device: %s (driver loaded, vFPGA usable in parallel)" % dev)

    fd = os.open(dev, os.O_RDWR | os.O_SYNC)
    m  = mmap.mmap(fd, AMC_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE,
                   offset=MMAP_AMC * PAGE)
    def rd(o):    return struct.unpack("<I", m[o:o+4])[0]
    def wr(o, v): m[o:o+4] = struct.pack("<I", v & 0xFFFFFFFF)

    if rd(PT) != PT_MAGIC:
        print("FAIL: no VMR0 at AMC window (got 0x%08X)" % rd(PT)); return 1
    if rd(RING+H_MAGIC) != GCQ_MAGIC:
        print("FAIL: GCQ ring not ready (0x%08X)" % rd(RING+H_MAGIC)); return 1
    slots = rd(RING+H_SLOTS); mask = slots - 1
    sqoff = rd(RING+H_SQOFF); sqsz = rd(RING+H_SQSZ); cqoff = rd(RING+H_CQOFF)
    print("AMC alive via driver: VMR0 + GCQ ring (slots=%d)" % slots)

    sq_prod = rd(RING+H_SQPROD); cq_cons = rd(RING+H_CQCONS); cq_prod = rd(RING+H_CQPROD)
    if cq_prod != cq_cons:
        cq_cons = cq_prod; wr(RING+H_CQCONS, cq_cons)

    cid, count = 0x00C0, 0x42
    slot = RING + sqoff + (sq_prod & mask) * sqsz
    for i in range(0, sqsz, 4): wr(slot+i, 0)
    wr(slot+0, OP_HEARTBEAT); wr(slot+4, cid); wr(slot+8, count)
    _ = rd(slot + sqsz - 4)
    sq_prod += 1
    wr(RING+H_SQPROD, sq_prod); _ = rd(RING+H_SQPROD)
    print("submitted HEARTBEAT via driver mmap: cid=0x%04X count=0x%02X" % (cid, count))

    deadline = time.time() + 5.0
    while time.time() < deadline:
        if rd(RING+H_CQPROD) != cq_cons: break
        time.sleep(0.001)
    else:
        print("FAIL: no completion (cq_prod stayed %d)" % cq_cons); return 1

    cq = RING + cqoff + (cq_cons & mask) * 16
    w0, w1, w3 = rd(cq), rd(cq+4), rd(cq+12)
    cq_cons += 1; wr(RING+H_CQCONS, cq_cons)
    ok = ((w0 & 0xFFFF) == cid and ((w0>>16)&0x3FFF) == 0 and w3 == 0 and (w1 & 0xFF) == count)
    print("response: cid=0x%04X state=%d echo=0x%02X rcode=%d"
          % (w0 & 0xFFFF, (w0>>16)&0x3FFF, w1 & 0xFF, w3))
    print("*** %s ***" % ("PASS — AMC reachable WITH driver loaded (vFPGA + AMC coexist)"
                          if ok else "CHECK response"))
    m.close(); os.close(fd)
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
