# `fw/apu_v80` — A72 (APU) firmware for the Coyote V80 shell

Phase **A0** of *Linux on the A72*
(`docs/superpowers/specs/2026-08-18-a72-linux-vfpga-design.md`). Linux itself lives in
[`a2/`](a2) and [`a3/`](a3); see "Booting Linux" at the end.

`apu_first_light.elf` is a bare-metal program that proves the PLM will start an
`a72-0` partition inside Coyote's combine PDI alongside the R5/AMC, and that
identifies which PS UART reaches the host.

## Building

```bash
versal-shell -c 'bash fw/apu_v80/build.sh'
```

`versal-shell` is **required**: the Xilinx gcc wrappers under
`/share/xilinx/2025.1/gnu/aarch64/lin/` are `#!/bin/bash` scripts, and NixOS has
no `/bin/bash`, so invoking them outside the FHS environment fails with
`bad interpreter`.

`make bitgen` builds and stages this automatically when `EN_APU=1`.

## The `max-page-size` trap

The build **must** pass `-Wl,-z,max-page-size=4096`. With the toolchain default of
64 KB, an ELF whose entry is `0xFFFC_1000` produces a LOAD segment starting at
`0xFFFC_0000` — 4 KB lower than intended. Verify after every change:

```bash
versal-shell -c 'readelf -l fw/apu_v80/build/apu_first_light.elf | grep LOAD'
```

The VirtAddr must read `0xfffc1000`, not `0xfffc0000`.

## OCM map

The APU shares OCM with the R5 and the vFPGA, so the boundaries are hard
constraints, not conventions:

```
0xFFFC_0000 - 0xFFFC_1000    4 KB   unused (the back-alignment trap above)
0xFFFC_1000 - 0xFFFD_0000   60 KB   this app
0xFFFD_0000 - 0xFFFD_1000    4 KB   A72 <-> R5 handshake block
0xFFFD_1000 - 0xFFFE_0000   60 KB   free
0xFFFE_0000 - 0xFFFF_F000  124 KB   TF-A BL31 (phase A2)
0xFFFF_F000 - 0xFFFF_FFFF    4 KB   vFPGA ocm_mbx mailbox -- DO NOT TOUCH
```

The mailbox is the R5<->vFPGA channel that already works; nothing here may grow
into it. TF-A is kept clear of it by building with
`VERSAL_ATF_MEM_BASE=0xFFFE0000 VERSAL_ATF_MEM_SIZE=0x1F000` rather than by
moving the mailbox.

## Handshake block (`0xFFFD_0000`, 4 x uint32)

| Offset | Field |
|---|---|
| `+0x0` | magic `0xA72F1157` |
| `+0x4` | heartbeat counter, increments forever |
| `+0x8` | characters accepted by UART0 (`0xFF00_0000`) |
| `+0xC` | characters accepted by UART1 (`0xFF01_0000`) |

`vApuFirstLightMirror()` in `fw/amc_v80/src/amc.c` samples this and mirrors it to
DDR `0x01FE_0000`, which the host reads with
`examples/15_amc_ping/sw/src/apu_first_light.cpp`.

## Why the UARTs are written without being configured

Versal PS UARTs are **ARM PL011 PrimeCell** (`arm,pl011`), not ZynqMP's Cadence
`xuartps`: data register at `+0x00`, flag register at `+0x18`, TXFF is bit 5.

The app only pushes bytes into the TX FIFO — it never touches the baud generator
or line control. So it inherits whatever the PLM or AMC already configured and
cannot disturb either owner. If a UART was never initialised, the writes simply
produce nothing; the bounded spin means a dead or unclocked UART cannot hang the
core. The per-UART character counts in the handshake block are what identify the
live console.

## Booting Linux (phases A2 + A3)

```bash
bash fw/apu_v80/a2/build_a2.sh                                 # TF-A + U-Boot + board DTB
bash fw/apu_v80/a2/recombine_a2.sh examples/15_amc_ping/hw/build_apu   # -> bitstreams/cyt_top_a2.pdi (no bitgen)
bash fw/apu_v80/a3/build_a3.sh                                 # kernel + Linux DTB + busybox initramfs
# program cyt_top_a2 (U-Boot waits at `Versal>` on ttyUSB2), then:
sudo python3 fw/apu_v80/a3/boot_a3.py --selftest               # push over PCIe, boot, check DDR + vFPGA
```

On the A72 shell, `a72_vfpga` (baked into the initramfs) is an on-target utility that reaches
hardware via `/dev/mem`:

```
a72_vfpga info        # read vFPGA 0 axi_ctrl (R5VP magic + verdict registers) at 0x4_0012_0000
a72_vfpga mbox [N]    # serve N host<->A72 shared-DDR mailbox exchanges (resp = req + 1)
```

Drive the mailbox from the host with `boot_a3.py --mailbox N` (it runs `a72_vfpga mbox N` on the
A72, then exchanges N request/response words over the shared DDR window and verifies each).

The shell is on UART0 (`/dev/ttyUSB2` on clara), e.g. `picocom -b 115200 /dev/ttyUSB2`. Three rules:

- **Linux RAM is `0x0200_0000`-`0x4000_0000`.** DDR below it is shared with the host (64 MB PCIe
  window = DDR 0x0). Linux reaches it through `/dev/mem`, which maps it non-cacheable. Never let the host write into Linux
  RAM while the A72 runs: the A72's D-cache neither sees such writes nor keeps them.
- `boot_a3.py` runs `dcache off` in U-Boot before pushing, for the same reason.
- The vFPGA's control registers appear to Linux at `0x4_0000_0000` (the host's BAR4+0), so vFPGA 0
  `axi_ctrl` is `0x4_0012_0000`.
