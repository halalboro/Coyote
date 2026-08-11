# Coyote Example 15: AMC ping (Phase A AMC bringup)

First-light test for the AVED Management Controller (AMC) firmware running on
the V80's RPU/R5. Validates that:

1. The V80 bitstream built with `EN_AMC=1` programs successfully
2. `amc.elf` is loaded into DDR4 at boot and starts FreeRTOS
3. AMC writes its partition-table magic (`0x564D5230` = "VMR0") into shared
   memory at `HAL_RPU_SHARED_MEMORY_BASE_ADDR = 0x00100000` (Coyote-patched
   from AVED-canonical `0x38000000` so it fits inside our 32 MB BAR4 window)
4. Host can read that magic over PCIe via BAR4

This is **NOT** full GCQ ping-pong — that's deferred to Phase B work once boot
is confirmed.

## Build

### Hardware

```bash
cd examples/15_amc_ping/hw
mkdir -p build && cd build
cmake ../ -DFDEV_NAME=v80 -DEN_AMC=1 -DBUILD_STATIC=1
make project    # ~30-45 min  (rebuilds static BD with DDR4 + GCQ + rpu_sc, builds amc.elf)
make bitgen     # ~4-6 h      (full synth + impl + bitstream + amc.elf into PDI)
```

The static rebuild is mandatory — the shipped V80 static checkpoint does not
include DDR4 / GCQ / rpu_sc. `make bitgen` invokes `scripts/fw/build_amc.sh`
automatically after the routed checkpoint is ready, producing
`build/bitstreams/static_files/amc.elf` and injecting it into the BIF via the
extended `fix_bif.py`.

### Software

```bash
cd examples/15_amc_ping/sw
mkdir -p build && cd build
cmake ../
make
```

Produces `build/test`.

## Run

```bash
# Program the V80 (PDI includes amc.elf as an LPD partition; PMC loads it onto R5)
cd /scratch/anubhav/Coyote
./program_fpga.sh examples/15_amc_ping/hw/build/bitstreams/cyt_top

# Wait ~2s for AMC FreeRTOS to start + write partition table.
# Then load Coyote driver and run the host test:
sudo insmod driver/build/coyote_driver.ko
cd examples/15_amc_ping/sw/build
sudo ./test
```

Expected output:
```
=== Coyote Example 15: AMC Ping ===
Mapping BAR4 (0x0208_0000_0000 .. 0x0208_1000_0000) via /dev/coyote
Reading AMC partition-table magic at DDR4 offset 0x00100000
  (PCIe view: BAR4 + 32 MB high window, host offset 0x00100000)
  Got: 0x564D5230   "VMR0"
*** PASS: AMC firmware booted and wrote partition table ***
```

If you see `0xFFFFFFFF` or `0x00000000`, AMC didn't boot — check:
- Was `amc.elf` actually built? (look for `build/fw/amc.elf` and `build/bitstreams/static_files/amc.elf`)
- Did `fix_bif.py` inject the AMC partition? (`grep amc.elf build/bitstreams/cyt_top.bif`)
- Did PMC successfully load the R5 partition? (look at `dmesg` after program)

## What this does NOT test

- The GCQ submission/completion-queue protocol itself
- AMI command/response framing
- Sensors / OSPI / SMBus paths (not enabled in Phase A)

Those are Phase B+ work and require a real GCQ host-side driver (TODO).

## Files

- `hw/CMakeLists.txt` — example build config (`EN_AMC=1`, `BUILD_STATIC=1`)
- `hw/src/vfpga_top.svh` — placeholder vFPGA (Phase A doesn't need user logic, but Coyote requires at least one vFPGA per build)
- `sw/src/main.cpp` — host test: BAR4 read of `0x00100000` for the magic word
- `sw/CMakeLists.txt` — links against Coyote runtime
