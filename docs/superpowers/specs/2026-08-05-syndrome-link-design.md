# Syndrome Link — low-latency FPGA↔FPGA syndrome transport

**Date:** 2026-08-05
**Status:** design, not yet implemented
**Goal:** carry QEC syndromes from an RFSoC to a decoder FPGA in under 100 ns one-way,
with corrections returned on the same link.

---

## 1. Problem

Real-time QEC decoding needs syndromes off the readout chain and into the decoder
inside the measurement round budget (~1 µs for superconducting qubits). The
existing Aurora link (Coyote example 14) delivers ~200 ns one-way, which is
adequate but consumes a fifth of the budget. Target here is <100 ns.

The two ends are different silicon:

| End | Device | Shell |
|---|---|---|
| Syndrome source | RFSoC (Zynq UltraScale+) | bare Vivado project, **no Coyote** |
| Decoder | Alveo U280 (later V80) | Coyote vFPGA |

Coyote supports only `u55c`, `u250`, `u280`, `v80`, `enzian`
(`cmake/FindCoyoteHW.cmake:405-465`). An RFSoC cannot run it. This is the
constraint that shapes everything below.

## 2. Decisions

| Decision | Choice | Why |
|---|---|---|
| Wire format | Dense bitmap per round | Fixed-size frames, constant latency, trivial decode |
| Stabilizer count | Parameterisable (`N_STAB`) | One core covers d=3 through d=25+ |
| Direction | Bidirectional | Syndromes out, corrections back |
| Lanes / rate | 1 lane @ 10.3125 Gbps | ~600 Mbps needed at d=25; 4 lanes is 40× over-provisioned |
| Line coding | **8B/10B** | No gearbox. 25% overhead is free at these data rates |
| Transceiver | **Raw GTY via GT Wizard, not Aurora** | Aurora's framing, bonding and init cost latency we cannot afford |
| Buffers | TX and RX buffer bypass | Where most of the remaining GT latency lives |
| Core interface | Parallel `valid`/`data` | No AXI. Wires into bare RFSoC logic and a vFPGA alike |
| CDC | **None inside the core** | User ports are synchronous to the recovered domain |
| Error policy | Detect and flag, never retry | See §6 |

## 3. Architecture

```
   RFSoC (bare Vivado)                        U280 (Coyote vFPGA)
 +---------------------+                    +---------------------+
 | syndrome source     |                    | micro-blossom       |
 |   syn_bits/valid    |                    |   LoadDefectsExternal|
 +----------+----------+                    +----------^----------+
            |                                          |
 +----------v----------+     1 lane 10.3125G      +----v----------------+
 |   syndrome_link.sv  |  ==================>     |   syndrome_link.sv  |
 |   (identical file)  |  <==================     |   (identical file)  |
 +----------+----------+       corrections        +----------+----------+
            |                                                 |
        GTY (bypass)  <---- shared reference clock ---->  GTY (bypass)
```

**Hard rule: `syndrome_link.sv` contains no Coyote types.** No `AXI4S`, no
`lynx_pkg`, no `axi_ctrl`, plain `logic` ports only. This is what makes the
RFSoC port a file copy. It is also the constraint most likely to be violated by
accident during integration — everything Coyote-specific belongs in a wrapper.

### Interface

```systemverilog
module syndrome_link #(
    parameter int N_STAB = 120,      // stabilizers per round
    parameter int N_CORR = 64        // correction bits returned
)(
    output logic                 user_clk,       // ~258 MHz, core's own domain
    output logic                 link_up,

    input  logic [N_STAB-1:0]    syn_bits,       // syndrome out (source end)
    input  logic                 syn_valid,

    output logic [N_STAB-1:0]    syn_out_bits,   // syndrome in (decoder end)
    output logic                 syn_out_valid,
    output logic [31:0]          syn_out_round,
    output logic                 syn_out_gap,    // a round was missed

    input  logic [N_CORR-1:0]    corr_bits,      // corrections, reverse direction
    input  logic                 corr_valid,
    output logic [N_CORR-1:0]    corr_out_bits,
    output logic                 corr_out_valid,

    output logic [31:0]          rx_frames,
    output logic [31:0]          rx_errors,
    /* GT reference clock and serial pins */
);
```

All user ports are synchronous to `user_clk`. There is deliberately **no CDC
inside the core**: each crossing costs ~25 ns, which is a quarter of the entire
budget. The RFSoC side should run its syndrome logic on `user_clk` directly. The
Coyote decoder side needs a crossing to `aclk` — that lives in the wrapper,
where its cost is visible rather than hidden.

### Clocking

10.3125 Gbps ÷ 10 bits per 8B/10B character = 1.03125 Gchar/s.
32-bit datapath (4 characters) → **`user_clk` = 257.8 MHz**, 3.88 ns per word.

`refclk` = 156.25 MHz. Note this is the rate the U280 boards appear to actually
deliver on QSFP1 (inferred from the example-14 throughput measurement), so no
clock generator reprogramming should be needed.

## 4. Wire protocol

Continuous transmission — the link always sends, idling with K28.5 commas when
there is no payload. This keeps the CDR locked and comma alignment maintained
without a separate training phase.

| Word | Contents |
|---|---|
| SOF | K28.1 start-of-frame character |
| 0 | `type[3:0]` · `n_words[7:0]` · `round[19:0]` |
| 1..N | payload bitmap, `ceil(N_STAB/32)` words |
| CRC | CRC-16 over words 0..N |

`type` demuxes syndrome (1) from correction (2), so one symmetric core carries
both directions. `n_words` catches an `N_STAB` mismatch between the two builds —
cheap insurance against a bug that would otherwise present as data corruption.

The wire carries `round[19:0]` (~1.05 s of rounds at 1 µs before wrapping), which
is ample for gap detection and keeps word 0 to exactly 32 bits. The receiver
counts wraps and presents the full 32-bit `syn_out_round` for logging.

At N_STAB=120: 4 payload words, 7 words total, 27 ns of serialisation.

## 5. Latency budget

| Stage | Estimate |
|---|---|
| Framing logic (TX) | 8 ns (2 words) |
| GTY TX PCS + PMA, buffer bypassed | 15–25 ns |
| Cable, 1–3 m DAC | 5–15 ns |
| GTY RX PMA (CDR) + PCS, buffer bypassed | 25–40 ns |
| Framing logic (RX) | 8 ns |
| **Total one-way** | **~60–95 ns** |

<100 ns is achievable but not comfortable. Sub-50 ns would need heroics.

**These are estimates, not measurements.** See §8 — the first task is to make
them measurable.

## 6. Error handling: detect and flag, never retry

In real-time QEC there is no time to retransmit: by the time a NACK reaches the
source, the decode window has passed. The core therefore implements no ARQ.

- CRC failure → `rx_errors++`, frame dropped, no `syn_out_valid` asserted
- `round` counter skip → `syn_out_gap` raised with the next good frame

The decoder learns exactly which rounds are missing and can degrade sensibly.
Silently delivering a corrupted syndrome would yield a confidently wrong
correction, which is strictly worse than a flagged gap.

## 7. Critical dependency: shared reference clock

**RX buffer bypass is only safe if both ends run from the same reference.** With
independent oscillators, ppm drift forces an elastic buffer and clock-correction
sequences — and that elastic buffer is precisely what we are deleting. Without a
shared clock the design degrades to roughly Aurora 8B/10B performance (~100–130
ns) and the raw-GT effort is largely wasted.

QEC control stacks normally distribute a common 10 MHz / 156.25 MHz reference
already. **Confirm the distribution can reach the decoder FPGA's QSFP refclk
input before implementation starts.** If it cannot, revisit the tier choice.

## 8. Phases

**Phase 0 — measure the existing link.** Add GT loopback control to example 14
and run the RTT benchmark at near-end PCS, near-end PMA, and far-end loopback.
This decomposes the current ~200 ns into framing / GT / wire and turns §5 from
estimates into numbers. It also validates each Tier 3 saving as it lands, rather
than at the end. Verify the Aurora IP exposes `loopback` — with
`SupportLevel=1` it may not.

**Phase 1 — GT bring-up.** GT Wizard, single lane, 8B/10B, buffer bypass per
UG578 alignment procedures. Own init/lock FSM. Prove on rose ↔ clara.

**Phase 2 — protocol and core.** `syndrome_link.sv` with the framing above,
synthetic syndrome generator and checker, error/gap counters.

**Phase 3 — Coyote wrapper.** `examples/16_syndrome_link`, thin vFPGA wrapper
exposing `link_up` / `rx_frames` / `rx_errors` over CSR, plus the `user_clk`→
`aclk` crossing. Example 14 stays untouched as a working reference.

**Phase 4 — micro-blossom hookup.** Receiver drives `LoadDefectsExternal`
(`Architecture.scala:20`, `Time[14:0] | Channel[10:0]`) into `MicroBlossomBus`
directly, so no software sits in the syndrome path.

**Phase 5 — RFSoC port.** New Vivado project, same core file, new GT pinout.
Both ends are UltraScale+ GTY, so the wizard configuration should largely carry
over.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Buffer bypass alignment is fiddly and board-dependent | Phase 1 proves it on real hardware before anything is built on top |
| No shared reference clock available | Blocking — confirm in Phase 0, fall back to Tier 2 (Aurora 8B/10B) |
| Debug is harder without Aurora status signals | Budget for ILA on the GT from the start |
| Custom protocol becomes a maintenance burden | Accepted cost of <100 ns; example 14 remains as a working fallback |
| GTY 8B/10B rate limits | 10.3125 Gbps is well inside GTY's 8B/10B range; confirm in the wizard |

## 10. Open questions

1. Can the lab clock distribution reach both FPGAs' QSFP refclk inputs? (§7, blocking)
2. What is `N_STAB` for the first target code distance?
3. Are corrections needed in the first cut, or is Phase 5 syndromes-only?
4. Does the Aurora IP expose `loopback` for Phase 0, or does that need a rebuild
   with `SupportLevel=0`?
