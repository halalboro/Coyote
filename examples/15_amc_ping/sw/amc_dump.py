#!/usr/bin/env python3
# Dump live AMC state from V80 shared memory over PCIe BAR4.
# Parses HAL_PARTITION_TABLE and prints the AMC's log-message buffer + status.
import mmap, struct, os, sys, string

BDF   = sys.argv[1] if len(sys.argv) > 1 else "0000:61:00.0"
DEV   = "/sys/bus/pci/devices/%s" % BDF
DDR_WINDOW = 0x0A000000          # BAR4 offset of the DDR4 window (maps DDR4 0x0)
SHMEM_BASE = 0x00100000          # AMC HAL_RPU_SHARED_MEMORY_BASE_ADDR (in DDR4)
PT = DDR_WINDOW + SHMEM_BASE      # partition table @ BAR4+0x0A100000

def u32(m, off): return struct.unpack("<I", m[off:off+4])[0]

fd = os.open(DEV + "/resource4", os.O_RDWR | os.O_SYNC)
m  = mmap.mmap(fd, 0x10000000, mmap.MAP_SHARED, mmap.PROT_READ)

magic = u32(m, PT)
print("Partition-table magic : 0x%08X (%s)" %
      (magic, "VMR0 — AMC ALIVE" if magic == 0x564D5230 else "BAD"))
if magic != 0x564D5230:
    sys.exit(1)

rb_off, rb_len   = u32(m, PT+0x04), u32(m, PT+0x08)
st_off, st_len   = u32(m, PT+0x0C), u32(m, PT+0x10)
lg_idx           = u32(m, PT+0x14)
lg_off, lg_len   = u32(m, PT+0x18), u32(m, PT+0x1C)
d_start, d_end   = u32(m, PT+0x20), u32(m, PT+0x24)
print("Ring buffer  : off=0x%06X len=0x%X   (host<->R5 GCQ mailbox payload)" % (rb_off, rb_len))
print("Status region: off=0x%06X len=0x%X" % (st_off, st_len))
print("Log buffer   : off=0x%06X len=0x%X  index=%d" % (lg_off, lg_len, lg_idx))
print("Data region  : 0x%06X .. 0x%06X" % (d_start, d_end))

# Status words
print("\n--- Status region (first 16 words) ---")
for i in range(0, 64, 4):
    print("  status+0x%02X = 0x%08X" % (i, u32(m, DDR_WINDOW + SHMEM_BASE + st_off + i)))

# Log message buffer -> printable text (the AMC's FreeRTOS log)
print("\n--- AMC log-message buffer (printable) ---")
raw = m[DDR_WINDOW + SHMEM_BASE + lg_off : DDR_WINDOW + SHMEM_BASE + lg_off + min(lg_len, 0x4000)]
txt = "".join(chr(b) if chr(b) in (string.printable) else "." for b in raw)
# collapse long runs of dots
import re
txt = re.sub(r"\.{4,}", " … ", txt)
print(txt.strip()[:3000] if txt.strip(".… \n\t") else "(log buffer empty / all filler)")
m.close(); os.close(fd)
