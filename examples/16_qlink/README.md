# Coyote Example 16: QLINK

A quantum-error-correction interconnect, built for latency rather than throughput.

Low-latency transport for QEC syndromes between two FPGAs: a dense stabilizer
bitmap per measurement round in one direction, corrections in the other, over a
single full-duplex serial link.

Where a general-purpose link like Aurora has to connect arbitrary machines
carrying arbitrary traffic, QLINK assumes the opposite: both ends are ours, every
message is the same fixed size (set by the code distance), and each one carries a
hard deadline, because a syndrome that arrives late has already lost its round.
Every layer it strips out of the transceiver follows from that.

## Why this exists separately from example 14

Example 14 proved Aurora point-to-point works (402 ns round trip, 96.7 Gbps).
But it is a bandwidth demo wired into Coyote, and the real target is different:

| | Example 14 | QLINK |
|---|---|---|
| Optimised for | throughput | **latency** |
| Payload | counter pattern | stabilizer bitmap per round |
| Both ends | Coyote / Alveo | **RFSoC ↔ Alveo** |
| Target | works | **< 100 ns one-way** |

An RFSoC cannot run Coyote — `FindCoyoteHW.cmake` supports only `u55c`, `u250`,
`u280`, `v80`, `enzian`. So the protocol core must be shell-independent.

## Structure

vFPGA side (this example):
```
hw/src/hdl/qlink_link_tx.sv    protocol core, TX half -- PORTABLE, no Coyote types
hw/src/hdl/qlink_link_rx.sv    protocol core, RX half -- PORTABLE, no Coyote types
hw/src/hdl/qlink_cdc_event.sv  atomic value crossing (rx_clk -> tx_clk, and to aclk)
hw/src/hdl/qlink_phy_shim.sv   32-bit words <-> the shell's 256-bit AXIS
hw/src/vfpga_top.svh           CSRs, syndrome generator, checker, CDC layer
sw/src/main.cpp                host app (send / recv / bench / status)
```

Shell side (Coyote tree, gated by `EN_QLINK_GTY`):
```
hw/hdl/qlink/qlink_phy_gty.sv      GTY + bring-up FSM + K-char framing
hw/hdl/qlink/qlink_gty_wrapper.sv  refclk buffer, GT clock export, status
scripts/ip_inst/qlink_infrastructure.tcl        GT Wizard
hw/constraints/u280/.../u280_shell_zqlink_1.xdc lane 0 pins on QSFP1
```

The GT lives in the shell because its pins are top-level. The wrapper presents
the **same** 256-bit AXIS interface the Aurora integration used, so the
`dynamic_top` / `user_wrapper` / `user_logic` templates needed only their
existing `en_aurora_1` gates widened to `en_aurora_1 or en_qlink_gty`, plus four
clock/reset wires and a loopback control added for QLINK alone.

### The streams are not in aclk

Read this before wiring anything to them. `axis_aurora_tx` is in
`qlink_tx_clk` and `axis_aurora_rx` is in `qlink_rx_clk`, both 257.8125 MHz,
and the receive one is *recovered from the far card* so it is not even the same
clock as the transmit one. Only the AXI4-Lite CSR block still runs in `aclk`.

The two fabric CDC FIFOs that used to make everything `aclk` cost ~25 ns per
crossing, with four of them on a round trip. Removing them is the single
largest latency saving available in this design. The price is that an `AXI4S`
interface object carries no clock of its own, so attaching `aclk` logic to
these streams produces no warning from any tool — it just corrupts data
occasionally.

**The protocol cores must never acquire a Coyote type.** No `AXI4S`, no
`lynx_pkg`, no `axi_ctrl` — plain `logic` ports only. That is what makes the
RFSoC port a file copy instead of a rewrite, and it is the constraint most
likely to be broken by a well-meaning cleanup.

## PHY-agnostic by design

The core speaks 32-bit words to an abstract PHY port. That lets the protocol be
validated on hardware that already works before any risky bring-up:

- **Phase 1 (this example)** — `qlink_phy_aurora`, over the proven Aurora path.
  ~200 ns one-way. Validates framing, checksums, round counting, gap detection.
- **Phase 2** — `qlink_phy_gty`, raw GTY with 8B/10B and TX/RX buffer bypass.
  Targets 60–95 ns. **The protocol core does not change.**

8B/10B rather than 64B/66B because the 64B/66B gearbox has to accumulate 66-bit
blocks across 64-bit words, and that buffering is pure latency. The 25% line
overhead is free here: even d=25 at 1 µs rounds is ~600 Mbps against 10 Gbps.

## Frame format

| Word (32b) | Contents |
|---|---|
| 0 | `type[3:0]` · `n_words[7:0]` · `round[19:0]` |
| 1..N | dense bitmap, `ceil(N_STAB/32)` words |
| N+1 | checksum `{ck_b[15:0], ck_a[15:0]}` |

`type` demuxes syndrome (1) from correction (2), so one symmetric core carries
both directions. `n_words` catches an `N_STAB` mismatch between the two builds,
which would otherwise present as data corruption.

The checksum is Fletcher-style, not CRC: a 32-bit-wide CRC unrolls to ~32 XOR
levels and will not close timing at the raw-GTY word rate. Strong single-bit
detection comes from the PHY instead — 8B/10B disparity and not-in-table errors
in phase 2.

## Error policy: detect and flag, never retry

**In real-time QEC there is no time to retransmit.** A NACK cannot reach the
source before the decode window closes. So there is no ARQ:

- bad checksum → frame dropped, `rx_errors++`
- skipped round → `syn_out_gap`, `rx_gaps++`

The decoder learns exactly which rounds it lost and can degrade deliberately.
Silently delivering a corrupted syndrome yields a confidently wrong correction,
which is strictly worse than a flagged gap.

Likewise a round offered while the link is busy is **dropped and counted**, never
queued. A queued syndrome is a stale syndrome.

## Build and run

```bash
cd hw && mkdir -p build && cd build
cmake ../ -DFDEV_NAME=u280 && make project && make bitgen

cd ../../sw && mkdir -p build && cd build
cmake ../ && make
```

Program both cards, cable QSFP1 ↔ QSFP1, then:

```bash
sudo ./qlink recv     # one card
sudo ./qlink send     # the other
sudo ./qlink status   # either, read-only
```

Defaults generate 100,000 rounds at one per 400 aclk cycles (1 µs at 400 MHz,
i.e. a realistic surface-code round rate). `--rounds 0` free-runs.

## Configuration

`N_STAB` in `hw/src/vfpga_top.svh` sets stabilizers per round — 120 by default,
roughly d=11. Both ends must be built with the same value; a mismatch is caught
by the `n_words` field and reported as `rx_errors` rather than silent corruption.

## Status

Written, **not yet synthesised or hardware-tested**.

Expect roughly **120–160 ns** from this build, not the <100 ns target. The two
CDC FIFOs in `qlink_gty_wrapper` (GT user clock 257.8125 MHz ↔ `aclk` 400 MHz)
cost ~25 ns each. That is a deliberate trade: it makes the link testable
without moving `qlink_link` into the shell, and it isolates the GT PHY's own
contribution so it can be measured. Moving the protocol core into the wrapper,
running on `user_clk` so no CDC sits in the syndrome path, is the follow-up if
the last ~50 ns is actually needed.

One line to check first if the link will not come up: the `BUFG_GT` `DIV(3'd0)`
in `qlink_phy_gty.sv`. It is the most version-sensitive thing in the design;
compare against the GT Wizard's generated example design.

Full design, latency budget and phase plan:
`docs/superpowers/specs/2026-08-05-syndrome-link-design.md`
