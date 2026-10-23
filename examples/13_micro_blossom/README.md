# Coyote Example 13: Micro Blossom QEC Decoder

Wraps the [Micro Blossom](https://github.com/yuewuo/micro-blossom) hardware
MWPM decoder as a Coyote vFPGA. This first iteration is a host-driven smoke
test that reads Micro Blossom's version register over the standard Coyote
PCIe control path.

The example targets **V80** (Versal HBM). It depends on the static layer
having an `M_AXI_FPD` route into the shell AXI fabric (already in the
shipped `static_routed_locked_v80_gen5.dcp` for this branch), but only
exercises the host PCIe path here.

## Architecture

```
Host x86 ──PCIe──► Coyote BAR ──► axi_main ──► shell ──► axi_ctrl (AXI4-Lite, 64b)
                                                              │
                                                              ▼ (AXI4-Lite, 64b data, 23b addr)
                                                  MicroBlossomBus.s0_*
                                                              │
                                                              ▼
                                              Micro Blossom decoder core
```

- `axi_ctrl` (Coyote's per-vFPGA AXI4-Lite slave) connects **directly**
  to Micro Blossom's AXI4-Lite slave. Both sides are 64-bit-data
  AXI4-Lite, so no protocol bridge is needed.
- Only the low 23 bits of `axi_ctrl.awaddr` / `araddr` are routed (Micro
  Blossom's address space is 8 MiB; the upper bits are aliased).
- Both `clk` and `slow_clk` are tied to Coyote's `aclk` — requires the
  `MicroBlossomBus.v` to have been generated with `--clock-divide-by 1`.
- Reset is inverted (Micro Blossom is active-high; Coyote is active-low).

**Note on bus type:** Earlier iterations tried `--bus-type Axi4` (full
AXI4 with bursts/IDs) plus an `axi_protocol_converter` Vivado IP, but
that IP isn't available for Versal HBM. `--bus-type AxiLite4` matches
Coyote's `axi_ctrl` natively — simpler, fewer moving parts.

## Prerequisites

1. **Regenerate `MicroBlossomBus.v` with `--bus-type AxiLite4` and
   `--clock-divide-by 1`** and place it under `hw/src/hdl/`:

   ```bash
   cd /scratch/anubhav/micro-blossom
   nix-shell --pure -p jdk11 sbt --run '
     sbt --java-home "$JAVA_HOME" "runMain microblossom.MicroBlossomBusGenerator \
         --graph ./resources/graphs/example_code_capacity_d3.json \
         --bus-type AxiLite4 \
         --language-hdl verilog \
         --output-dir ./gen \
         --clock-divide-by 1"
   '
   cp gen/MicroBlossomBus.v \
      /scratch/anubhav/Coyote/examples/13_micro_blossom/hw/src/hdl/
   ```

   (A pre-built copy is checked in; rerun only if regenerating with a
   different graph or different options.)

2. **The active static checkpoint must include the M_AXI_FPD route.**
   This is `hw/checkpoints/static_routed_locked_v80_gen5.dcp` on the
   `versal-shell` / `v80-apu` branch of this repo. (Roll back to
   `…shipped.dcp` if you don't need the APU path.)

## Build

```bash
cd examples/13_micro_blossom/hw
mkdir -p build && cd build
cmake ../ -DFDEV_NAME=v80
make project
make bitgen
```

Output: `build/bitstreams/cyt_top.pdi`.

## Program

```bash
cd ../../..    # back to Coyote root
./program_fpga.sh examples/13_micro_blossom/hw/build/bitstreams/cyt_top
```

## Run smoke test

```bash
cd examples/13_micro_blossom/sw
mkdir -p build && cd build
cmake ../
make
sudo ./test
```

Expected:

```
Version register (offset 0x08): 0x240123c0
Context depth   (offset 0x0C): 0x1
Expected version             : 0x240123c0
Timer reg sample 1: 0x...
Timer reg sample 2: 0x...

Version OK:        yes
Timer increments:  yes

*** MICRO BLOSSOM V80 SMOKE TEST PASSED ***
```

## What this validates

| Component | Validated by |
|---|---|
| Coyote shell + driver come up on V80 | `program_fpga.sh` succeeds, `/dev/coyote_fpga_0_v0` exists |
| Host PCIe → vFPGA control path | `getCSR()` returns a non-garbage value |
| AXI4-Lite → AXI4 bridge | Read response from a register inside Micro Blossom |
| `MicroBlossomBus.v` synth + timing | bitgen completes; reads return expected static values |
| Micro Blossom internal logic alive | Timer register monotonically increments |

## Host-driven full decode (MVP)

The `decode` target runs the **complete heterogeneous MWPM decode**: the
primal (blossom-tree) algorithm on the **host x86 CPU**, the dual
accelerator in the **V80 vFPGA**, talking over the Coyote PCIe control
path. Latency is not a goal here (every instruction is a blocking PCIe
MMIO round-trip); the goal is end-to-end **correctness** while the V80
on-chip-core path is built out separately.

```
Host x86 ──PCIe──► axi_ctrl (64b AXI4-Lite, 64 KiB window)
   │                    │
   │  primal loop       ▼  (address remap: 0x8000 ⇄ 0x2_0000 readout block)
   │  (Rust, reused)    MicroBlossomBus.s0 ──► dual accelerator
   ▼
 mb_csr shim (getCSR/setCSR) ◄── readouts / instructions
```

**Reuse, not re-port.** The primal + control loop is the Micro Blossom
Rust `blossom` crate, unchanged. We add one driver
(`dual_module_coyote.rs`) that swaps the verilator-TCP transport for
Coyote CSRs, plus a one-call C ABI entry (`ffi_coyote.rs::mb_decode_and_check`).
The host program supplies the transport via a tiny C++ shim
(`sw/src/mb_csr.{h,cpp}`) over `cThread::getCSR/setCSR`.

**Readout address remap (why the SV wrapper changed).** Coyote's per-vFPGA
user-control window is only **64 KiB**, so the host can reach MB byte
offsets `0x0000..0xFFFF` — enough for the control regs (`0x00..0x30`) and
the 64-bit instruction port (`0x1000`), but **not** MB's per-context
readout block at `0x2_0000`. `hw/src/vfpga_top.svh` now aliases
`[0x8000,0x8080) → [0x2_0000,0x2_0080)` (context 0) for both reads and
writes, so the readouts become reachable through the standard CSR path.
`mb_csr.cpp` mirrors that alias and divides byte addresses by 8 to form
the CSR index.

### Build & run the decoder

```bash
# 1. Re-synthesize the bitstream after the vfpga_top.svh remap edit, then program.
cd examples/13_micro_blossom/hw/build && make project && make bitgen
cd ../../../.. && ./program_fpga.sh examples/13_micro_blossom/hw/build/bitstreams/cyt_top

# 2. Build the SW (needs the Rust toolchain pinned by the blossom crate).
cd examples/13_micro_blossom/sw && mkdir -p build && cd build
cmake ../            # builds both `test` (smoke) and `decode`
make
sudo ./test          # smoke test still passes (verifies remap didn't break pass-through)
sudo ./decode        # full host-driven d3 decode vs. software reference
```

`decode` runs a handful of known d3 syndromes; for each it decodes on the
hardware and on the in-repo software reference (`SolverDualComb`) and
asserts the subgraphs match. Expected tail:

```
*** MICRO BLOSSOM HOST-DRIVEN d3 DECODE PASSED ***
```

**Build caveat (linkage).** `libmicro_blossom.a` declares the VMK180
`binding.c` MMIO symbols (`execute_instruction`, `get_hardware_info`, …)
as `extern "C"` imports. The Coyote path never calls them, so the linker
should garbage-collect those references. If the link instead reports them
undefined, add trivial stub definitions to `mb_csr.cpp` (match the
signatures in `micro-blossom/src/cpu/embedded/src/binding.rs`).

## Next steps (deferred)

- Validate the APU/A72 path (same vFPGA reachable at `0x4_0000_0000`
  via M_AXI_FPD once A72 Linux is up) — moves the primal loop on-chip.
- Multi-context: extend the SV alias span by 128 B per context (watch the
  64 KiB window ceiling) for batched/pipelined decoding.
- Larger graphs (d5, d9) for performance characterization, and a real
  latency number (will be PCIe-MMIO bound on this host-driven path).
