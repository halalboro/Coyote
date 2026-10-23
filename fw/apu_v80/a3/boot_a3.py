#!/usr/bin/env python3
"""Coyote V80 APU phase A3: push Linux into DDR over PCIe and boot it from the A2 U-Boot prompt.

    sudo python3 fw/apu_v80/a3/boot_a3.py [--bdf 0000:81:00.0] [--tty /dev/ttyUSB2] [--selftest]
    sudo python3 fw/apu_v80/a3/boot_a3.py --selftest-only      # checks against an already-booted shell

Needs the A2 PDI (cyt_top_a2) programmed and U-Boot sitting at its `Versal>` prompt.

Host path: the raw BAR4 sysfs resource at +0x0C000000, which is the 64 MB window onto DDR 0x0.
It does not use the Coyote driver, so it works whether or not a driver is loaded and does not
depend on the driver's AMC_DDR_SIZE. Console path: UART0, which is /dev/ttyUSB2 on clara.

Sequence:
 1. Check that PCIe config space is live (the PDI load wipes the BARs; see project notes).
 2. Get the U-Boot prompt and run `dcache off`. The A72's D-cache does not see host writes to cached
    memory and writes stale copies back (proven on HW in A2), so it must be off before pushing.
 3. Write DTB, Image and initramfs through the window, then read back and compare on the host.
 4. U-Boot `crc32` over each image must match the host CRC, which proves the A72 sees the same bytes.
 5. Set initrd_high/fdt_high to all-ones (no relocation: U-Boot would move the initramfs to the top of
    its 2 GB, outside Linux RAM 0x02000000-0x40000000), then `booti`.
 6. Stream the console until the shell prompt appears. --selftest then (a) exchanges tokens with
    Linux through shared DDR below 0x02000000 using busybox devmem, and (b) reads the vFPGA 0
    control registers from Linux (M_AXI_FPD, 0x4_0012_0000) and compares them with the host's view
    (BAR4+0x120000). Offset 0 of example 15's axi_ctrl is the fixed magic 0x52355650 "R5VP".
"""
import argparse, mmap, os, random, re, select, struct, sys, time, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
WIN_OFFS = 0x0C000000          # BAR4 offset of the DDR window (driver AMC_DDR_OFFS)
WIN_SIZE = 0x04000000          # 64 MB -> DDR 0x0..0x03FFFFFF
RAM_BASE = 0x02000000          # Linux RAM starts here (v80-coyote-apu-linux.dts)
DTB_ADDR = RAM_BASE
IMG_ADDR = RAM_BASE + 0x200000 # 2 MB aligned (Image flags bit 3: may sit anywhere 2 MB aligned)
SHARED_TEST = 0x01F00000       # host/Linux token exchange, below Linux RAM (non-cacheable for Linux)
VFPGA_USER_BAR4 = 0x120000     # vFPGA 0 axi_ctrl: VFPGA_CTRL_OFFS 0x100000 + VFPGA_CTRL_USER_OFFS 0x20000
VFPGA_USER_A72 = 0x400000000 + VFPGA_USER_BAR4   # axi_main on M_AXI_FPD at 0x4_0000_0000
R5VP_MAGIC = 0x52355650
UBOOT_PROMPT = b"Versal> "
SHELL_PROMPT = b"coyote-a72:"


def align(x, a):
    return (x + a - 1) & ~(a - 1)


class Console:
    def __init__(self, path, log):
        self.fd = os.open(path, os.O_RDWR | os.O_NOCTTY)
        os.system(f"stty -F {path} 115200 raw -echo clocal -crtscts -hupcl")
        self.log = log

    def read_until(self, token, timeout, echo=True):
        buf, end = b"", time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([self.fd], [], [], 0.2)
            if r:
                chunk = os.read(self.fd, 4096)
                buf += chunk
                self.log.write(chunk)
                self.log.flush()
                if echo:
                    sys.stdout.write(chunk.decode(errors="replace").replace("\r", ""))
                    sys.stdout.flush()
                if token and token in buf:
                    return buf
        if token:
            raise TimeoutError(f"no {token!r} within {timeout}s")
        return buf

    def send(self, line):
        for ch in (line + "\r").encode():
            os.write(self.fd, bytes([ch]))
            time.sleep(0.003)   # U-Boot has no flow control; pace the characters

    def cmd(self, line, prompt, timeout=10, echo=True):
        self.send(line)
        return self.read_until(prompt, timeout, echo)


def pci_check(bdf):
    dev = f"/sys/bus/pci/devices/{bdf}"
    with open(f"{dev}/config", "r+b") as f:
        cfg = f.read(0x28)
        ven, did, cmd = struct.unpack_from("<HHH", cfg, 0)
        bar4 = struct.unpack_from("<Q", cfg, 0x20)[0] & ~0xF
        if ven != 0x10EE:
            sys.exit(f"{bdf}: vendor {ven:#06x} is not Xilinx")
        res4 = int(open(f"{dev}/resource").read().splitlines()[4].split()[0], 16)
        if bar4 == 0 or bar4 != res4:
            sys.exit(f"{bdf}: BAR4 config {bar4:#x} != kernel {res4:#x} -- stale after a PDI load.\n"
                     "Recover: rmmod coyote_driver; echo 1 > reset; echo 1 > remove; echo 1 > /sys/bus/pci/rescan")
        if not cmd & 0x2:
            f.seek(4)
            f.write(struct.pack("<H", cmd | 0x2))   # memory decode on (no driver needed)
    drv = os.path.realpath(f"{dev}/driver") if os.path.exists(f"{dev}/driver") else None
    print(f"[host] {bdf} {ven:04x}:{did:04x} BAR4 {bar4:#x}  driver: {os.path.basename(drv) if drv else 'none'}")
    return f"{dev}/resource4"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bdf", default="0000:81:00.0")
    ap.add_argument("--tty", default="/dev/ttyUSB2")
    ap.add_argument("--build", default=os.path.join(HERE, "build"))
    ap.add_argument("--selftest", action="store_true", help="shared-DDR and vFPGA checks after boot")
    ap.add_argument("--selftest-only", action="store_true", help="run the checks against a running shell")
    ap.add_argument("--mailbox", type=int, default=0, metavar="N",
                    help="drive N host<->A72 shared-DDR mailbox exchanges against `a72_vfpga mbox`")
    args = ap.parse_args()

    if args.selftest_only:
        res = pci_check(args.bdf)
        con = Console(args.tty, open(os.path.join(args.build, "console.log"), "ab"))
        con.cmd("", SHELL_PROMPT, echo=False)
        fd = os.open(res, os.O_RDWR | os.O_SYNC)
        win = mmap.mmap(fd, WIN_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=WIN_OFFS)
        ok = selftest(con, win, res)
        if args.mailbox:
            ok = host_mailbox(con, win, args.mailbox) and ok
        sys.exit(0 if ok else 1)

    dtb = open(os.path.join(args.build, "v80-coyote-apu-linux.dtb"), "rb").read()
    img = open(os.path.join(args.build, "Image"), "rb").read()
    rd = open(os.path.join(args.build, "initramfs.cpio"), "rb").read()
    text_offset, image_size = struct.unpack_from("<QQ", img, 8)
    rd_addr = align(IMG_ADDR + max(image_size, len(img)), 0x100000)
    layout = [("dtb", DTB_ADDR, dtb), ("Image", IMG_ADDR, img), ("initramfs", rd_addr, rd)]
    for name, addr, data in layout:
        print(f"[host] {name:9s} @ {addr:#010x} .. {addr + len(data):#010x} ({len(data)} B)")
    if DTB_ADDR + len(dtb) + 0x3000 > IMG_ADDR:   # + CONFIG_SYS_FDT_PAD for in-place fixups
        sys.exit("DTB overlaps the kernel")
    if rd_addr + len(rd) > WIN_SIZE:
        sys.exit("initramfs does not fit in the 64 MB host window")

    res = pci_check(args.bdf)
    log = open(os.path.join(args.build, "console.log"), "ab")
    con = Console(args.tty, log)

    con.send("")
    try:
        con.read_until(UBOOT_PROMPT, 3)
    except TimeoutError:
        sys.exit("no U-Boot `Versal>` prompt on the console -- program cyt_top_a2 first")
    con.cmd("dcache off", UBOOT_PROMPT)

    fd = os.open(res, os.O_RDWR | os.O_SYNC)
    win = mmap.mmap(fd, WIN_SIZE, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=WIN_OFFS)
    t0 = time.time()
    for name, addr, data in layout:
        win[addr:addr + len(data)] = data
    for name, addr, data in layout:
        if win[addr:addr + len(data)] != data:
            sys.exit(f"[host] readback mismatch for {name}")
    print(f"\n[host] pushed + read back {sum(len(d) for _, _, d in layout)} B in {time.time() - t0:.1f} s")

    for name, addr, data in layout:
        out = con.cmd(f"crc32 {addr:x} {len(data):x}", UBOOT_PROMPT, timeout=120)
        m = re.search(rb"==>\s*([0-9a-f]{8})", out)
        want = zlib.crc32(data) & 0xFFFFFFFF
        if not m or int(m.group(1), 16) != want:
            sys.exit(f"[host] A72 crc32 of {name} != host {want:08x}")
        print(f"\n[host] {name}: A72 crc32 == host crc32 {want:08x}")

    con.cmd("setenv initrd_high 0xffffffffffffffff", UBOOT_PROMPT)
    con.cmd("setenv fdt_high 0xffffffffffffffff", UBOOT_PROMPT)
    t0 = time.time()
    con.send(f"booti {IMG_ADDR:x} {rd_addr:x}:{len(rd):x} {DTB_ADDR:x}")
    con.read_until(SHELL_PROMPT, 180)
    print(f"\n[host] Linux shell prompt after {time.time() - t0:.1f} s")

    for c in ["uname -a", "cat /proc/cmdline", "grep -c ^processor /proc/cpuinfo",
              "head -3 /proc/meminfo", "grep -i 'system ram' /proc/iomem"]:
        con.cmd(c, SHELL_PROMPT)

    ok = True
    if args.selftest:
        ok = selftest(con, win, res)
    if args.mailbox:
        ok = host_mailbox(con, win, args.mailbox) and ok
    if not ok:
        sys.exit(1)
    print("[host] done; the shell stays up on", args.tty)


def devmem_read(con, addr):
    out = con.cmd(f"devmem {addr:#x} 32", SHELL_PROMPT, echo=False)
    m = re.search(rb"\n\s*0x([0-9A-Fa-f]{8})", out)
    return int(m.group(1), 16) if m else None


def selftest(con, win, res):
    host_tok, a72_tok = 0xC0DEF00D, 0xA72B00B5
    struct.pack_into("<II", win, SHARED_TEST, host_tok, 0)
    seen = devmem_read(con, SHARED_TEST)
    con.cmd(f"devmem {SHARED_TEST + 4:#x} 32 {a72_tok:#x}", SHELL_PROMPT, echo=False)
    got = struct.unpack_from("<I", win, SHARED_TEST + 4)[0]
    ok1, ok2 = seen == host_tok, got == a72_tok
    print(f"[host] shared DDR {SHARED_TEST:#x}: host->Linux {'PASS' if ok1 else 'FAIL'}, "
          f"Linux->host {'PASS' if ok2 else 'FAIL'} (host read {got:#010x})")

    fd = os.open(res, os.O_RDONLY | os.O_SYNC)
    reg = mmap.mmap(fd, 0x1000, mmap.MAP_SHARED, mmap.PROT_READ, offset=VFPGA_USER_BAR4)
    offs = (0x0, 0x8, 0x10, 0x18, 0x20)
    host = [struct.unpack_from("<I", reg, o)[0] for o in offs]
    if host[0] != R5VP_MAGIC:   # never touch the A72 side if the host cannot see the vFPGA either:
        print(f"[host] vFPGA: host reads {host[0]:#010x}, not R5VP -- skipping the A72 read")
        return False            # a failed M_AXI_FPD read would SError and kill Linux
    a72 = [devmem_read(con, VFPGA_USER_A72 + o) for o in offs]
    fmt = lambda vs: " ".join(f"{v:08x}" if v is not None else "????????" for v in vs)
    ok3 = a72 == host
    print(f"[host] vFPGA axi_ctrl: host BAR4+{VFPGA_USER_BAR4:#x} [{fmt(host)}]")
    print(f"[host]                 A72  {VFPGA_USER_A72:#x} [{fmt(a72)}]  {'PASS' if ok3 else 'FAIL'}")
    return ok1 and ok2 and ok3


def host_mailbox(con, win, n):
    """Drive the on-target `a72_vfpga mbox N` server over the shared-DDR mailbox.

    Layout: +0x00 req  +0x04 req_seq (host writes) | +0x40 resp  +0x44 resp_seq (A72 writes).
    Host writes req then bumps req_seq (always nonzero); the A72 answers resp=req+1 and echoes
    resp_seq. The A72 side debounces a read-after-write transient-0 hazard (see a72_vfpga.c).
    """
    MB = SHARED_TEST
    REQ, REQ_SEQ, RESP, RESP_SEQ = MB + 0x00, MB + 0x04, MB + 0x40, MB + 0x44

    def w32(off, val):
        struct.pack_into("<I", win, off, val)
        return struct.unpack_from("<I", win, off)[0]   # read-back flushes the WC write buffer

    def r32(off):
        return struct.unpack_from("<I", win, off)[0]

    for off in (REQ, REQ_SEQ, RESP, RESP_SEQ):
        w32(off, 0)                                   # flushed clear before the A72 latches req_seq=0
    con.send(f"a72_vfpga mbox {n}")
    time.sleep(0.5)                                   # let the tool mmap and read the initial seq
    ok = 0
    for i in range(1, n + 1):
        req = random.getrandbits(32)
        w32(REQ, req)                                 # request value first (flushed) ...
        w32(REQ_SEQ, i)                               # ... then publish req_seq to trigger the A72
        deadline = time.time() + 5
        while r32(RESP_SEQ) != i and time.time() < deadline:
            pass
        resp = r32(RESP)
        good = (r32(RESP_SEQ) == i and resp == ((req + 1) & 0xFFFFFFFF))
        ok += good
        print(f"[host] mbox#{i}: req 0x{req:08x} -> resp 0x{resp:08x} {'ok' if good else 'FAIL'}")
    for tok in (b"mailbox done", SHELL_PROMPT):        # drain the A72's prints; non-fatal
        try:
            con.read_until(tok, 5, echo=False)
        except TimeoutError:
            pass
    print(f"[host] mailbox: {ok}/{n} exchanges verified")
    return ok == n


if __name__ == "__main__":
    main()
