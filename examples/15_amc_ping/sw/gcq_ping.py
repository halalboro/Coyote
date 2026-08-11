#!/usr/bin/env python3
# Phase B: minimal GCQ mailbox client — send ONE AMI command to the AMC on the
# V80's R5 and read its reply, over PCIe BAR4. Proves bidirectional host<->R5.
#
# Protocol (validated against firmware + live HW):
#   Host is the GCQ *producer* (gcq_m2r/S00 @ BAR4+0x08000000). The R5/AMC is the
#   consumer. The ring lives in DDR4 shared memory (BAR4+0x0A101000); payload is
#   in-band in the slots. Polling mode (no interrupts).
#
#   Producer registers (host):
#     +0x0000  SQ_TAIL  (RW) write new SQ-produced index = SUBMIT DOORBELL
#                            (reads return IP identity 0x000FF1CE, so track locally)
#     +0x0100  CQ_TAIL  (RO) read = CQ-produced index = poll for COMPLETION
#   Ring header (44B) @ ring base: magic, version, slotNum, SQoff, SQslot, CQoff,
#     SQconsumed(+24, AMC writes), CQconsumed(+28, host writes to release).
#   Slots: N=4, SQ=512B @ ring+44+i*512, CQ=16B @ ring+2092+i*16 (i = idx & 3).
#
#   AMI request  (SQ slot, 512B): w0=opcode|count<<16|state<<31, w1=cid, payload@+8
#   AMI response (CQ slot, 16B):  w0=cid|cstate<<16, w1..2=payload, w3=rcode(0=OK)
#   Heartbeat (opcode 0x2): payload byte @ +8 is a count the AMC echoes in w1.
#
# Run as root with coyote_driver detached, e.g. via amc_test-style wrapper.

import mmap, os, struct, sys, time

BDF        = sys.argv[1] if len(sys.argv) > 1 else "0000:61:00.0"
RES        = "/sys/bus/pci/devices/%s/resource4" % BDF
BAR_SIZE   = 0x10000000

GCQ_BASE   = 0x08000000                 # gcq_m2r/S00 producer regs
DDR_WIN    = 0x0A000000                 # BAR4 offset of DDR4 window (maps DDR 0x0)
SHMEM      = 0x00100000                 # AMC shared-mem base in DDR4
PT         = DDR_WIN + SHMEM            # partition table
RING       = PT + 0x1000               # GCQ ring buffer
STATUS     = PT + 0x2000               # AMI-comms status word

SQ_TAIL_DOORBELL = 0x0000              # producer SQ tail (write to submit)
CQ_TAIL_POLL     = 0x0100              # producer CQ tail (read to poll)

# ring-header field offsets (HAL_PARTITION_TABLE / GCQ_HEADER_TYPE)
H_MAGIC, H_VER, H_SLOTS, H_SQOFF, H_SQSZ, H_CQOFF, H_SQCONS, H_CQCONS, \
    H_FLAGS, H_SQPROD, H_CQPROD = \
    0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40
# In-memory-pointer mode (AMC built with GCQ_FLAGS_TYPE_IN_MEM_PTR_ENABLE): the
# produced pointers live in the DDR ring header, NOT the GCQ registers. The host
# submits by writing H_SQPROD and polls completions by reading H_CQPROD — all in
# DDR. This bypasses gcq_m2r/S00, whose register WRITES the host interconnect
# drops (reads work). Must match the AMC's xFlags (fw_if_gcq_amc.c).

PT_MAGIC  = 0x564D5230
GCQ_MAGIC = 0x5847513F
IDENTITY  = 0x000FF1CE

# AMI opcodes
OP_HEARTBEAT = 0x2
CQ_SLOT_SIZE = 16


def main():
    fd = os.open(RES, os.O_RDWR | os.O_SYNC)
    m  = mmap.mmap(fd, BAR_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)
    def rd(off):      return struct.unpack("<I", m[off:off+4])[0]
    def wr(off, v):   m[off:off+4] = struct.pack("<I", v & 0xFFFFFFFF)

    # --- 1. AMC alive + comms enabled -------------------------------------
    if rd(PT) != PT_MAGIC:
        print("FAIL: partition-table magic 0x%08X (expected VMR0)" % rd(PT)); return 1
    st = rd(STATUS)
    print("AMC: VMR0 present, status=0x%08X (%s)" %
          (st, "AMI-comms enabled" if (st & 0xFF) else "comms NOT enabled"))

    # --- 2. GCQ ring header ----------------------------------------------
    if rd(RING+H_MAGIC) != GCQ_MAGIC:
        print("FAIL: GCQ ring magic 0x%08X (expected 0x5847513F)" % rd(RING+H_MAGIC)); return 1
    ver   = rd(RING+H_VER); slots = rd(RING+H_SLOTS)
    sqoff = rd(RING+H_SQOFF); sqsz = rd(RING+H_SQSZ); cqoff = rd(RING+H_CQOFF)
    mask  = slots - 1
    print("GCQ: magic OK, ver=%d.%d slots=%d SQ(off=%d size=%d) CQ(off=%d size=%d)"
          % (ver >> 16, ver & 0xFFFF, slots, sqoff, sqsz, cqoff, CQ_SLOT_SIZE))
    ident = rd(GCQ_BASE + SQ_TAIL_DOORBELL)
    print("GCQ IP identity (read of doorbell reg) = 0x%08X %s"
          % (ident, "OK" if ident == IDENTITY else "(unexpected)"))

    # --- 3. sync indices (in-memory pointers, all in DDR) -----------------
    sq_prod = rd(RING+H_SQPROD)          # host owns SQ-produced, kept in DDR header
    cq_cons = rd(RING+H_CQCONS)
    cq_prod = rd(RING+H_CQPROD)          # AMC writes CQ-produced into DDR header
    print("sync: sq_prod=%d sq_cons=%d cq_prod=%d cq_cons=%d"
          % (sq_prod, rd(RING+H_SQCONS), cq_prod, cq_cons))
    if cq_prod != cq_cons:
        print("note: %d stale completion(s) pending; draining." % (cq_prod - cq_cons))
        cq_cons = cq_prod
        wr(RING+H_CQCONS, cq_cons)

    # --- 4. build + submit a HEARTBEAT command ----------------------------
    cid   = 0x00A5
    count = 0x5A
    sq_slot = RING + sqoff + (sq_prod & mask) * sqsz
    for i in range(0, sqsz, 4):          # zero the whole slot
        wr(sq_slot + i, 0)
    wr(sq_slot + 0, OP_HEARTBEAT)        # w0: opcode=2, count=0, state=0
    wr(sq_slot + 4, cid)                 # w1: cid
    wr(sq_slot + 8, count)               # payload byte 0 = heartbeat count
    _ = rd(sq_slot + sqsz - 4)           # read-back barrier: flush slot to DDR first
    sq_prod += 1
    wr(RING+H_SQPROD, sq_prod)           # doorbell: bump SQ-produced in DDR header
    _ = rd(RING+H_SQPROD)                # flush the pointer write
    print("submitted HEARTBEAT: cid=0x%04X count=0x%02X (sq_prod->%d, in DDR header)"
          % (cid, count, sq_prod))

    # --- 5. poll for completion (CQ-produced in DDR header) --------------
    deadline = time.time() + 5.0
    while time.time() < deadline:
        cq_prod = rd(RING+H_CQPROD)
        if cq_prod != cq_cons:
            break
        time.sleep(0.001)
    else:
        print("FAIL: timed out waiting for AMC completion (cq_prod stayed %d)" % cq_cons)
        return 1

    cq_slot = RING + cqoff + (cq_cons & mask) * CQ_SLOT_SIZE
    w0, w1, w2, w3 = (rd(cq_slot), rd(cq_slot+4), rd(cq_slot+8), rd(cq_slot+12))
    cq_cons += 1
    wr(RING+H_CQCONS, cq_cons)           # release the CQ slot back to the AMC

    r_cid   = w0 & 0xFFFF
    r_state = (w0 >> 16) & 0x3FFF
    r_echo  = w1
    r_rcode = w3
    print("response: cid=0x%04X state=%d payload0=0x%08X rcode=%d"
          % (r_cid, r_state, r_echo, r_rcode))

    ok = (r_cid == cid and r_state == 0 and r_rcode == 0 and (r_echo & 0xFF) == count)
    print("*** %s: AMC replied to heartbeat (echoed 0x%02X) ***"
          % ("PASS — host<->R5 mailbox works" if ok else "CHECK", r_echo & 0xFF))
    m.close(); os.close(fd)
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
