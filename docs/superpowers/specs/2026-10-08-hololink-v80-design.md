# Hololink on the V80 — an NVQLink-compatible FPGA→GPU RoCE path

**Date:** 2026-10-08
**Status:** design, not yet implemented
**Goal:** run NVIDIA's Holoscan Sensor Bridge IP (`HOLOLINK_top`) inside a Coyote vFPGA on
the Alveo V80, writing over a 200G link into H100 VRAM via a ConnectX-7, so that our
FPGA work can speak the NVQLink ecosystem's protocol rather than a private one.

---

## 1. Problem

NVQLink couples a QPU controller FPGA to a GPU at microsecond scale, and the quantum
control community is standardising on it — LBNL's QubiC has an NVQLink integration
running at ~4 µs round trip on an RFSoC. We have a QEC stack (QLINK at 54.7 ns one-way,
micro-blossom in a V80 vFPGA) and no way to talk to a GPU decoder in anybody's standard
dialect.

NVQLink is not a new link technology. It is **RoCE v2 RDMA WRITE from the FPGA into GPU
VRAM**, through a ConnectX-7 or BlueField on the GPU host, landing via dmabuf. The FPGA
side is NVIDIA's Holoscan Sensor Bridge (HSB) IP. NVIDIA quotes `<4.0 µs` round trip
FPGA→GPU→FPGA at up to 400 Gb/s.

So "put Hololink on our FPGAs" means: get `HOLOLINK_top` running on the V80 with its host
interface attached to a 200G MAC. Everything else — CUDA-Q, `cudaq-realtime` — sits above
that and is host-side.

## 2. What we are starting from

| Piece | Where | State |
|---|---|---|
| HSB IP RTL | `/scratch/anubhav/holoscan-sensor-bridge` @ `release-2.6.0`, `fpga/nv_hsb_ip/` | 117 SystemVerilog files, Apache-2.0, public |
| Xilinx reference design | `fpga/pynq/rfsoc-pynq/` | **Works today** on `xczu48dr` (RFSoC 4x2), Vivado 2024.1, 100G CMAC |
| V80 200G MAC bring-up | Coyote `examples/16_dcmac` | **Works today**, DCMAC at 200G on QSFP56, `EN_NET_RAW=1` |
| GPU host | jamie: H100L 94GB + ConnectX-7 | exists |
| FPGA host | clara (V80) — confirm BDF and that `ami` loads | per `project_v80_setup` |
| 200G cable clara↔jamie | — | **unverified, see Phase 0** |

The decisive fact is the second row. NVIDIA ships a *Xilinx* reference design, so the
question is not "does this IP work on Xilinx" — it demonstrably synthesizes and runs in
Vivado. Our exposure is the narrower one: **UltraScale+ → Versal, and Vivado 2024.1 →
2025.1.**

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | New Coyote example `17_hololink`, forked from `16_dcmac` | `16_dcmac` already pays every V80-specific cost: DCMAC block design, GT quad, reset FSM, QSFP56 cage power via `ami_tool`, a safe build that keeps host PCIe alive |
| D2 | `HOLOLINK_top` lives in `vfpga_top.svh`, replacing the MAC-swap echo | The `EN_NET_RAW` seam is already raw Ethernet frames on a 512-bit AXI-Stream — exactly Hololink's host interface |
| D3 | HIF runs on Coyote's `aclk` at 400 MHz. **No datapath CDC.** | Width is an exact match (512 b both sides); 400 × 512 = 204.8 Gb/s covers the 200 Gb/s line rate. `HIF_CLK_FREQ` is a define for timer calculation, and the host software already parameterises it per board |
| D4 | APB at 50 MHz and PTP at 100 MHz from a clocking wizard, `SYNC_CLK_*` left at 0 | The documented, well-travelled clocking model — every shipped HSB design uses independent APB/PTP. See R3 |
| D5 | Data source for first light is NVIDIA's own `ram_player` + `nv_hsb_ip/data_gen` | The RFSoC reference design has no sensor either; it is already "arbitrary payload → GPU", which is our use case. Keeps our logic out of the path while debugging the port |
| D6 | Static flat build: `BUILD_STATIC=1`, `EN_SHELL_PBLOCK=0` | Not a preference — the DCMAC hard block cannot sit in a reconfigurable partition, and CMake rejects the alternative. Upside: no pblock, so the whole device is available |
| D7 | Our own xsim testbench, run before every bitgen | The IP ships **no** testbenches. Follows the `16_qlink/sim/run.sh` pattern: seconds of sim against a multi-hour build |

## 4. Architecture

```
 H100 VRAM  <--dmabuf--  ConnectX-7 (jamie)
                              ^
                              | 200G, RoCE v2 WRITE / WRITE_IMM
                              v
   +---------------------- V80 (clara) -----------------------+
   |  DCMAC_X1Y1 @ QSFP56   (Coyote shell, static)            |
   |        ^                                                  |
   |        | axis_net_raw_rx / _tx : 512 b, aclk 400 MHz      |
   |        v                                                  |
   |  +--------------- vfpga_top.svh ----------------------+   |
   |  |  HOLOLINK_top                                       |  |
   |  |    i_hif_* / o_hif_*  <- 512 b host IF (aclk)       |  |
   |  |    i_sif_* / o_sif_*  <- 512 b sensor IF            |  |
   |  |    APB master (50 MHz) -> ram_player, user regs     |  |
   |  |    PTP (100 MHz, free-running for now)              |  |
   |  |    SPI / I2C / GPIO -> tied off                     |  |
   |  +-----------------------------------------------------+  |
   +----------------------------------------------------------+
```

### The seam

`examples/16_dcmac/hw/src/vfpga_top.svh:10-11` gives the vFPGA:

- `axis_net_raw_rx` — 512-bit AXI4-Stream of received frames, `aclk` domain
- `axis_net_raw_tx` — 512-bit AXI4-Stream of frames to send, `aclk` domain

with `tdata`/`tkeep`/`tlast`/`tvalid`/`tready` and **no `tuser`**. Hololink carries
`tuser` on both host streams, so:

- `i_hif_axis_tuser` ← tie to `'0` (the RFSoC design's CMAC drives RX `tuser` as an error
  flag; with no equivalent from Coyote's DCMAC wrapper we lose error indication, not
  function)
- `o_hif_axis_tuser` → leave unconnected

One hard constraint from `docs/user_guide/known_limitations.md`:

> The Host TX & RX AXI-stream supports TKEEP not equal to all 1's only when TLAST is
> high. TKEEP must be all 1's when TLAST is low.

Coyote's RX path should satisfy this naturally — a MAC delivers full beats until the last
one — but it is unverified, and a violation would corrupt frames in a way that looks like
a protocol bug. **The testbench asserts it** (see Phase 2).

### Clocking and reset

| Clock | Freq | Source | Hololink define |
|---|---|---|---|
| `i_hif_clk` | 400 MHz | Coyote `aclk` directly | `HIF_CLK_FREQ 400000000` |
| `i_apb_clk` | 50 MHz | clocking wizard off `aclk` | `APB_CLK_FREQ 50000000` |
| `i_ptp_clk` | 100 MHz | clocking wizard off `aclk` | `PTP_CLK_FREQ 100000000` |

`i_sys_rst` comes from Coyote's `aresetn`, inverted — Hololink resets are active high and
`HOLOLINK_top` generates its own per-domain resets (`o_apb_rst`, `o_hif_rst`, `o_ptp_rst`)
from it. We do **not** reuse the reference design's `rst.sv`, which gates reset on CMAC
`pll_locked`/`aligned`; Coyote's DCMAC wrapper owns that sequencing and exposes it as
`mac_status`.

`NCLK_F`/`ACLK_F` note: `cmake/FindCoyoteHW.cmake:264` defaults `ACLK_F` to 400, and
`:1013-1025` auto-raises `NCLK_F` from 250 to 400 on Versal networking, warning below
391 MHz because `NCLK_F × 512 b < 200 Gb/s` loses frames on a path with no drop logic.

## 5. The Versal porting surface

This is the part worth being precise about, because it is where the work actually is.

**What is *not* a problem.** `grep` across all 117 files of `fpga/nv_hsb_ip/` for
`LATTICE|XILINX|ALTERA|MICROCHIP|pmi_|RAMB|URAM|altsyncram|EBR|SB_` returns **zero hits**.
Every `ifdef` is functional (`SENSOR_RX_IF_INST`, `SPI_INST`, `SIMULATION`, …) — there are
no vendor switches. No `always_latch`, and **zero** synthesis-visible `initial`
blocks — the only two (`misc/dc_fifo_generic.sv:99`, `misc/sc_fifo.sv:61`) are FIFO
pointer priming inside `ifdef SIMULATION`.
The IP is pure inferred RTL.

**What is a problem, in descending order:**

1. **The XDC clock groups.** `fpga/pynq/rfsoc-pynq/build/constraints/constraints.xdc:67-69`
   is three `set_clock_groups -asynchronous` statements, and they are what make the design
   close — they declare the MMCM/CMAC domains asynchronous so Vivado does not time across
   them. Every path is hardcoded to UltraScale+ hierarchy: `gtwizard_gtye4_top`,
   `GTYE4_CHANNEL_PRIM_INST`, `mmcme4_adv_inst`. **All three must be rewritten** against
   the Versal DCMAC/GTM hierarchy and our clocking wizard. Get it wrong in one direction
   and timing fails loudly; in the other, the design works on the bench and fails
   intermittently in the field. D3 helps here: putting HIF on `aclk` removes one of the
   three domain crossings outright.

2. **Two unprotected CDC synchronizers.** The IP's main synchronizer,
   `nv_hsb_ip/misc/data_sync.sv:31`, is correctly dual-annotated:
   `(* DONT_TOUCH = "TRUE" *) (* ASYNC_REG = "TRUE" *)` for Vivado alongside the Synplify
   pragma. But `misc/reset_sync.sv:32` and `misc/reg_cdc.sv` roll their own flops, do not
   instantiate `data_sync`, and carry **no** `ASYNC_REG`. `reset_sync.sv` is an async
   reset synchronizer — the textbook case that must be `ASYNC_REG`'d or Vivado may retime
   or merge it. Fix: add the attributes locally. Small, safe, and ours to maintain.

3. **Stale Synplify pragmas Vivado silently ignores.** The code carries two dialects:
   12 × `(* ram_style *)` and 12 × `(* keep *)` (Vivado), alongside
   8 × `/*synthesis syn_ramstyle = "distributed"*/`, 4 × `syn_ramstyle = "block_ram"`,
   6 × `/* synthesis noprune */` and 5 × `syn_keep=1` (Synplify/Lattice). Vivado treats
   the latter as comments. Consequence: RAM style choices intended by NVIDIA will not be
   honoured in ~12 places, so Vivado picks its own. Mostly benign, occasionally a timing
   or resource surprise. Worth a look at the utilisation report, not worth pre-emptive
   patching.

4. **400 MHz on the HIF datapath.** The IP closes at 322.265625 MHz on UltraScale+ `-2`;
   we are asking for 400 MHz on Versal across a 512-bit path containing the RoCE ICRC LFSR
   (`roce/roce_icrc.sv`, `roce/lfsr_hc.sv`). Versal is faster silicon, so this is
   plausible rather than safe. Escape hatches, in order: pipeline the ICRC; drop
   `ACLK_F`/`NCLK_F` and accept sub-line-rate (harmless for Phase 3, where `data_gen` is
   rate-controlled at 10 µs spacing); last resort, a 322 MHz island with CDC FIFOs.

5. **`rst_pb_debounce.sv:34`** is `always_ff @(posedge clk or posedge pb_synced[1])` — a
   flop asynchronously reset by a *data* bit. It is the board push-button path, which we
   do not instantiate. Noted so nobody wires it up by reflex.

## 6. Host side

jamie: H100L 94GB + ConnectX-7. The template is
`holoscan-sensor-bridge/examples/gpu_roce_loopback.py`, which needs
`cuda.bindings.driver`, the `hololink` Python module, and an ibverbs device name. Its
`DataGen` class drives exactly the blocks we are instantiating:

| What | Address |
|---|---|
| `ram_player` window size / number / timer / enable | `0x5000_0000` + `0x0C` / `0x10` / `0x08` / `0x04` |
| sensor TX packet processor enable | `0x0120_0000` ← also our `init_reg[0]` |

and it already carries a per-board HIF clock constant —
`322 * DATA_GEN_SPACING_US if BOARD == "RFSoC" else 201 * ...` — confirming HIF frequency
is an expected axis of variation. Ours becomes `400`.

Control plane is over Ethernet (BOOTP for enumeration, then NVIDIA's ECB protocol), not
PCIe, so the host reaches the board by IP address. We keep Coyote's CSR path alive in
parallel for `mac_status` and counters, which is the main reason D1 beats a standalone
Vivado project.

## 7. Latency: what to expect, and what not to

**Phase 3 will not measure 4 µs, and that is not a failure.** From
`docs/user_guide/latency.md`, the Holoscan receive path costs ~120 µs for the CPU to wake
on end-of-frame and ~1 ms for the next pipeline operator to run. Those are *pipeline*
numbers, not link numbers.

NVIDIA's `<4 µs` comes from a different consumption model: data lands in VRAM and a
persistent CUDA kernel spins on it, which is what `cudaq-realtime` provides. The FPGA-side
RDMA write is identical in both cases. So:

- Phase 3 (Holoscan/`hololink` Python path) → expect ~100 µs–1 ms. Proves correctness.
- Phase 5 (polling CUDA kernel) → the real microsecond number.

For scale: QLINK is 54.7 ns one-way FPGA↔FPGA. Even a perfect 4 µs GPU loop is ~70× that,
and most of it is ConnectX + PCIe + GPU doorbell, none of which the V80 can improve. The
honest contribution here is a measured three-way comparison — fabric decoder vs. NVQLink
GPU decoder vs. raw link — not a latency win.

Also: we are not porting PTP sync (D4 leaves the PTP clock free-running), and HSB reports
its own latency via PTP timestamps. Phase 3 must therefore measure with host-side
timestamps instead.

## 8. Phases

Each phase ends in something observable. No phase depends on an unbuilt bitstream for its
own verification except where stated.

| # | Phase | Done when |
|---|---|---|
| 0 | **Confirm the physical path.** 200G cable or switch clara↔jamie; V80 BDF and `ami_tool` on clara; CX-7 ibverbs device and `nvidia-peermem`/dmabuf on jamie | `ami_tool` reports the cage; `ibv_devinfo` on jamie lists the CX-7; a cable is traced end to end |
| 1 | **Example skeleton.** Fork `16_dcmac` → `17_hololink`; add the 117 HSB sources to the HDL list; write our `HOLOLINK_def.svh`; clocking wizard for 50/100 MHz; `HOLOLINK_top` wired to the raw-net seam with SPI/I2C/GPIO tied off | `make project` elaborates clean; no inferred latches, no missing-module errors |
| 2 | **Simulation.** `examples/17_hololink/sim/run.sh`, xsim per `reference_xsim_recipe`: (a) ECB register read/write over a crafted host RX frame, (b) BOOTP enumeration reply, (c) `ram_player` → RoCE WRITE frame with correct ICRC, (d) assertion that Coyote's RX never presents `tkeep != all-1s` with `tlast` low | all four pass in seconds |
| 3 | **First light.** Bitgen; `gpu_roce_loopback.py` on jamie against the V80 | H100 VRAM contains `data_gen`'s pattern; frame counter advances; CRC clean |
| 4 | **Patch the CDC gaps and re-verify timing.** `ASYNC_REG` on `reset_sync.sv`/`reg_cdc.sv`; Versal clock groups reviewed against the real hierarchy | timing closed with the clock groups justified line by line, not copied |
| 5 | **The real latency number.** Replace the Holoscan receive path with a polling CUDA kernel on the H100 | one-way and round-trip figures with host-side timestamps, comparable against QLINK's 54.7 ns |
| 6 | *(separate spec)* QEC syndromes into the sensor port, micro-blossom on the H100 | — |

Phases 0–2 need no bitstream. Phase 0 is cheap and can invalidate everything, so it goes
first.

## 9. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| No 200G cable exists clara↔jamie | blocks everything | Phase 0, before any RTL work |
| 400 MHz HIF will not close | medium | pipeline ICRC; or drop `ACLK_F` and accept sub-line-rate for Phases 3–5 |
| Versal clock groups wrong → intermittent CDC failure | **high, silent** | Phase 4 reviews each one against the real hierarchy; never copy the UltraScale+ paths |
| Coyote RX violates the `tkeep`/`tlast` rule | medium | asserted in Phase 2 sim before bitgen |
| HSB IP needs PTP to enumerate | low | free-running 100 MHz should satisfy it; Phase 2 sim (b) proves enumeration without PTP sync |
| V80 card wedges on a bad bitstream | medium | `project_v80_setup`'s SBR + remove + rescan trick; rose is already wedged, so use clara |
| HOLOLINK_top does not fit alongside the Coyote shell | low | D6's flat build means no pblock; the whole device is available |

## 10. Open questions

1. **Is there a 200G cable or switch between an FPGA host and jamie?** Phase 0. Everything
   below is moot if not.
2. **Does Coyote's DCMAC wrapper expose an RX error flag** we could map to Hololink's
   `i_hif_axis_tuser`? If not we lose error indication on receive.
3. **Does `data_gen`/`ram_player` depend on the APB clock being slow?** It is driven over
   APB at 50 MHz in the reference design; we keep that, so this should be moot, but the
   timer constant (`322 * spacing`) is HIF-derived and needs re-deriving for 400 MHz.
4. **`SYNC_CLK_HIF_APB` / `SYNC_CLK_HIF_PTP`** (`HOLOLINK_top.sv:153-163`) would collapse
   the IP to a single clock domain and delete most of the CDC surface — the exact risk
   class in §5. They are **undocumented**: absent from the whole `docs/user_guide`, and no
   shipped reference design uses them. Attractive as a Phase 4+ simplification, backed by
   simulation. Not something to bet first light on.
