# Example 15: R5 Co-processor Provider

Exercises the on-card **R5 ↔ vFPGA** channel over the merged co-processor
provider (R5-as-master, M_AXI_LPD), superseding the earlier OCM/`S_AXI_LPD`
self-test.

## Roles

- **R5 = master/orchestrator.** After the host binds the provider, the R5
  firmware (`fw/r5_provider_v80`, bare-metal) runs a self-test: for each opcode
  (PING/INC/ADD/SUM) it sends a request packet, receives the result, checks and
  times it, then mirrors a verdict into the vFPGA MMIO aperture.
- **vFPGA = co-processor slave.** `coprocessor_slave.sv` computes the opcodes on
  the AXIS request/response ports and holds the verdict register file, which it
  also exposes read-only on `axi_ctrl` so the host can read it over BAR.
- **Host** binds endpoint 1 → port 0 via the co-processor control target, then
  reads the verdict.

## Success criterion

The host reads the vFPGA verdict MAGIC (`0x52355650` "R5VP") and **PASS** on all
four opcodes, with plausible R5-cycle latencies.

## Build

```bash
cd hw && mkdir -p build && cd build
cmake ../ -DFDEV_NAME=v80 -DBUILD_STATIC=1
make project    # rebuilds the static layer with the bare R5-0 platform + provider
make bitgen     # full synth/impl/bitstream; builds r5_provider.elf and combines
                # it into the PDI as a delay-handoff core=r5-0 image (like AMC)
```

The config (`EN_V80_R5_PLATFORM=1`, `EN_V80_R5_PROVIDER=1`, `N_COPROCESSOR_PORTS=1`,
nets off, host streams on) is set in `hw/CMakeLists.txt` — only `FDEV_NAME` and
`BUILD_STATIC` are passed on the command line. Do **not** pass `EN_AMC` (mutually
exclusive with the R5 platform) and `make platform` is not needed (the firmware
is freestanding, no XSA/BSP).

## Run (after programming the bitstream)

```bash
cd sw && mkdir -p build && cd build
cmake .. && make
# `test` reaches the control target via the raw BAR4 resource (BAR4+0x2000), so the
# Coyote driver must be UNBOUND from the V80 first (it otherwise claims the BAR):
sudo sh -c 'echo 0000:81:00.0 > /sys/bus/pci/drivers/coyote_driver/unbind'
sudo ./test        # binds the provider, then prints PASS/FAIL + latencies
```

The control target lives on the shell `axi_cnfg` bus at `axi_main + 0x2000` (BAR4+0x2000),
the verdict on vFPGA 0 `axi_ctrl` at BAR4+0x120000. `test` reads the control-target MAGIC
first and aborts on an all-ones read — a wrongly-addressed read of this shell wedged the
PCIe bus and hard-reset the host once (2026-09-16).

## Files

- `hw/CMakeLists.txt` — build config (`EN_V80_R5_PLATFORM/PROVIDER`, `BUILD_STATIC`).
- `hw/src/vfpga_top.svh` — vFPGA body: `perf_local` host loopback + `coprocessor_slave`.
- `hw/src/hdl/coprocessor_slave.sv`, `coprocessor_abi.svh` — the co-processor slave + shared ABI.
- `fw/r5_provider_v80/` — freestanding R5-0 provider firmware (`main.c` service loop, `start.S`, `lscript.ld`, `build_r5_provider.sh`).
- `sw/src/main.cpp`, `sw/src/coprocessor_verdict.hpp` — host: bind + verdict read.

The packet + MMIO + control-target ABI is mirrored across `coprocessor_abi.svh`
(RTL), `fw/r5_provider_v80/src/coprocessor_abi.h` (firmware), and
`sw/src/coprocessor_verdict.hpp` (host) — keep the three in lock-step.
