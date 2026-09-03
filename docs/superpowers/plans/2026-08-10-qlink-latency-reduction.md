# QLINK Latency Reduction (Stages 1–4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce QLINK's measured one-way latency from 289 ns toward ~150–180 ns by
removing fabric clock crossings, shortening the GT PCS path, and raising the user
clock — without losing the protocol's correctness guarantees.

**Architecture:** Four independent stages, each ending in one bitstream and one
hardware measurement. Stage 1 is IP configuration only. Stage 2 moves the protocol
datapath onto the GT's own clocks and deletes both fabric CDC FIFOs. Stage 3 doubles
the GT word width and raises the line rate, with the framer acting as a 32→64-bit
gearbox so the protocol core is untouched. Stage 4 replaces automatic comma alignment
with a manual RXSLIDE FSM so the GT's alignment block can be bypassed.

**Tech Stack:** SystemVerilog, Vivado 2025.1, `gtwizard_ultrascale` v1.7 (GTYE4),
Coyote shell (U280), xsim for regression, `qlink` host app for measurement.

## Global Constraints

- **`qlink_link.sv` must contain no Coyote types.** No `AXI4S`, no `lynx_pkg`, no
  `axi_ctrl` — plain `logic` ports only. It is copied verbatim to a bare RFSoC
  project. Everything Coyote-specific lives in `vfpga_top.svh`.
- **`qlink_framer.sv` is the module the testbench exercises AND the module
  `qlink_phy_gty` instantiates.** Never copy framing logic back into
  `qlink_phy_gty` — the simulation would silently stop testing the real design.
- **Run `examples/16_qlink/sim/run.sh` before every bitgen.** It takes ~7 seconds
  against ~3 hours for a build. No exceptions.
- **GT IP config must be applied as ONE `set_property -dict`.** Individual
  `set_property` calls are validated against a half-configured state and fail with
  a bare "failed due to earlier errors".
- **`RX_COMMA_ALIGN_WORD` must equal the GT datapath width in bytes.** At 32-bit
  it is 4. If the width changes, this changes with it, or the comma lands in a lane
  the framer never inspects and no SOF is ever detected (`rx_frames=0` AND
  `rx_errors=0`, which reads as a dead link).
- **CDC FIFO depth must exceed the longest frame** (`1 + MAX_WORDS + 1`). They are
  `FIFO_MODE 2` (packet mode) and cannot release a frame larger than they hold.
- **`CHANNEL_ENABLE` is `X0Y44`** — part-specific to the U280 QSFP1 quad lane 0.
- Both cards must be programmed with the same bitstream before measuring.

## Baseline and Measurement Protocol

Every stage is judged against this measured baseline (RX buffer bypass build,
100 iterations per size):

```
RTT = 578 ns + 8.87 ns/word          one-way = 289 ns
d=11 (4 words): 612 ns RTT
protocol (from sim)   ~35 ns one-way
2 fabric CDC crossings ~50 ns
wire                   ~10 ns
GT silicon            ~194 ns
```

**Measurement procedure, identical every stage:**

```bash
# rose  (/scratch/anubhav/Coyote)      — reflector, leave running
sudo ./qlink echo
# clara (/scratch/anubhav/Coyote-test) — sweep
sudo ./qlink bench --iters 1000
```

Record `rtt_min`/`rtt_med` at 1, 4 and 32 words, plus `lost`. A stage is a success
only if `lost=0` and "Payloads matched throughout" still hold.

**Rollback for every stage:** `git revert` the stage's commit and rebuild. Each
stage is one commit for exactly this reason.

**Corroboration from AMD's low-latency-for-fintech blog** (2019), which quotes
per-feature costs for the same silicon family:
- TX buffer crossing without phase alignment: **7.7–10.9 ns** (we bypass it)
- RX buffer crossing without phase alignment: **13.2–17.1 ns** (we bypass it;
  our measured saving was 22 ns one-way — same order, slightly higher, plausibly
  because the packet FIFO interaction folded in)
- "~13 ns from a 16-bit internal datapath" — **NOT available to us.** Verified
  against the wizard: with 8B/10B the internal width must be a multiple of 10 and
  only **40** is offered. `int=20` is rejected at every user width. A 16-bit
  internal path implies raw (non-8B/10B) mode, i.e. owning scrambling and frame
  sync — Stage 5, out of scope here.
- Sub-3 ns RAW-mode figures are the **GTF** transceiver on the UL3524, a
  different transceiver from GTY. Not applicable.

Consequence for Task 3: the only way to shorten the internal period is to raise
the line rate while holding internal width at 40. RXUSRCLK is
`line_rate / int_width`, so 10.3125 G → 258 MHz (3.88 ns) versus 25.78 G →
644 MHz (1.55 ns). That is a 2.5x shorter internal period, better than the 0.80x
originally estimated from the *fabric* clock — the internal clock is the one that
sets GT pipeline latency.

## File Structure

| File | Responsibility | Stages touching it |
|---|---|---|
| `scripts/ip_inst/qlink_infrastructure.tcl` | GT + FIFO IP configuration | 1, 2, 3, 4 |
| `hw/hdl/qlink/qlink_framer.sv` | K-char framing, GT-width gearbox | 3, 4 |
| `hw/hdl/qlink/qlink_phy_gty.sv` | GT instance, clocking, bring-up FSM | 2, 3, 4 |
| `hw/hdl/qlink/qlink_gty_wrapper.sv` | shell glue, CDC FIFOs, CSR crossing | 2 |
| `examples/16_qlink/hw/src/hdl/qlink_link.sv` | protocol core (split in 2a) | 2a |
| `examples/16_qlink/hw/src/hdl/qlink_link_tx.sv` | TX half (new, stage 2a) | 2a, 2b |
| `examples/16_qlink/hw/src/hdl/qlink_link_rx.sv` | RX half (new, stage 2a) | 2a, 2b |
| `examples/16_qlink/hw/src/vfpga_top.svh` | CSRs, generator, checker, RTT | 2b |
| `examples/16_qlink/sim/tb_qlink.sv` | regression + latency measurement | 2a, 3 |

---

### Task 1: PCS configuration only (Stage 1)

Lowest-risk stage. No RTL changes at all, so the simulation result must be
byte-identical to before — that is itself the check that nothing else moved.

**Files:**
- Modify: `scripts/ip_inst/qlink_infrastructure.tcl`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new. GT behaviour only.

- [ ] **Step 1: Record the pre-change simulation output**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/sim
./run.sh > /tmp/sim_before.txt 2>&1 || true
grep -A3 "Test 3" /tmp/sim_before.txt
```

Expected: the protocol latency table (`1 word → 10 cycles`, `32 → 41 cycles`).

- [ ] **Step 2: Add the two documented latency settings**

In the `set_property -dict` block for `qlink_gty`, after
`CONFIG.RX_COMMA_ALIGN_WORD  4 \`, add:

```tcl
            CONFIG.RX_COMMA_SHOW_REALIGN_ENABLE false \
            CONFIG.RX_EQ_MODE           LPM \
```

And above the dict, extend the comment block with:

```tcl
        ## SHOW_REALIGN_COMMA=FALSE is documented in UG578 as "This setting
        ## reduces RX datapath latency" -- the realignment comma is not brought
        ## out to the RX interface. We never inspect it, so it is free.
        ##
        ## RX_EQ_MODE=LPM: UG578 recommends LPM for channels with <14 dB loss at
        ## Nyquist. A 1-3 m QSFP28 DAC is well inside that. No documented latency
        ## claim -- this is here to be measured, and to be reverted if the error
        ## counters move at all.
```

- [ ] **Step 3: Verify the simulation is unchanged**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/sim
./run.sh > /tmp/sim_after.txt 2>&1 || true
diff <(grep -E "PASS|FAIL|cycles" /tmp/sim_before.txt) \
     <(grep -E "PASS|FAIL|cycles" /tmp/sim_after.txt) && echo "IDENTICAL"
```

Expected: `IDENTICAL`. This stage touches no RTL, so any difference means
something unintended changed.

- [ ] **Step 4: Build and program both cards**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/hw/build
make project && make bitgen
```

`make project` is required, not just `bitgen` — the IP configuration changed.

- [ ] **Step 5: Measure**

Run the measurement procedure. Record `rtt_med` at 1, 4, 32 words.

Expected: a small reduction, single-digit to ~20 ns RTT. `lost=0` and payloads
matched are mandatory. **If `rx_errors` becomes non-zero, revert `RX_EQ_MODE` to
`AUTO` and rebuild** — LPM adaptation is the only plausible cause and it is the
speculative half of this change.

- [ ] **Step 6: Commit**

```bash
cd /scratch/anubhav/Coyote
git add scripts/ip_inst/qlink_infrastructure.tcl
git commit -m "qlink: PCS low-latency settings (SHOW_REALIGN off, LPM equalisation)"
```

---

### Task 2a: Split `qlink_link` into TX and RX halves (Stage 2, part 1)

Pure refactor, fully verifiable in simulation, no bitgen. This exists so that
Task 2b — which changes clocking and CSR access at the same time — is not also
changing the protocol core.

The TX and RX FSMs in `qlink_link` already share no state except the counters and
`clr`. Splitting is mechanical.

**Files:**
- Create: `examples/16_qlink/hw/src/hdl/qlink_link_tx.sv`
- Create: `examples/16_qlink/hw/src/hdl/qlink_link_rx.sv`
- Delete: `examples/16_qlink/hw/src/hdl/qlink_link.sv`
- Modify: `examples/16_qlink/sim/tb_qlink.sv`
- Modify: `examples/16_qlink/hw/src/vfpga_top.svh`

**Interfaces:**
- Produces:
  - `qlink_link_tx #(N_STAB, N_CORR) (clk, rstn, link_up, clr, syn_bits[N_STAB-1:0], syn_valid, syn_round[19:0], syn_words_sel[7:0], corr_bits[N_CORR-1:0], corr_valid, phy_tx_data[31:0], phy_tx_valid, phy_tx_last, phy_tx_ready, tx_frames[31:0], tx_dropped[31:0])`
  - `qlink_link_rx #(N_STAB, N_CORR) (clk, rstn, link_up, clr, syn_out_bits[N_STAB-1:0], syn_out_valid, syn_out_round[31:0], syn_out_gap, corr_out_bits[N_CORR-1:0], corr_out_valid, phy_rx_data[31:0], phy_rx_valid, phy_rx_last, phy_rx_err, rx_frames[31:0], rx_errors[31:0], rx_gaps[31:0])`

- [x] **Step 1: Create `qlink_link_tx.sv`**

Copy the header comment, the `SYN_WORDS`/`CORR_WORDS`/`MAX_WORDS` localparams, the
`TYPE_SYN`/`TYPE_CORR` localparams, the `cks_pack` function, and the entire TX
`always_ff` block from `qlink_link.sv` verbatim. Port list exactly as in
**Interfaces** above. Keep the portability rule comment — this file is still
copied to the RFSoC.

- [x] **Step 2: Create `qlink_link_rx.sv`**

Same treatment for the RX `always_ff` block, the `rx_*` declarations, and
`cks_pack` (duplicated — the two files must not depend on each other).

- [x] **Step 3: Update the testbench to instantiate both halves**

Replace each `qlink_link` instance with a `qlink_link_tx` + `qlink_link_rx` pair
on the same clock. For instance A:

```systemverilog
    qlink_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(a_syn_bits), .syn_valid(a_syn_valid), .syn_round(a_syn_round),
        .syn_words_sel(a_words), .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    qlink_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_out_bits(a_syn_out), .syn_out_valid(a_syn_out_valid),
        .syn_out_round(a_syn_out_round), .syn_out_gap(a_syn_out_gap),
        .corr_out_bits(a_corr_out), .corr_out_valid(a_corr_out_valid),
        .phy_rx_data(a_prx_data), .phy_rx_valid(a_prx_valid),
        .phy_rx_last(a_prx_last), .phy_rx_err(a_prx_err),
        .rx_frames(a_rxf), .rx_errors(a_rxe), .rx_gaps(a_rxg)
    );
```

Repeat for instance B with the `b_` signals.

- [x] **Step 4: Update `run.sh` to compile both files**

```bash
xvlog -sv tb_qlink.sv \
      ../hw/src/hdl/qlink_link_tx.sv \
      ../hw/src/hdl/qlink_link_rx.sv \
      ../../../hw/hdl/qlink/qlink_framer.sv
```

- [x] **Step 5: Run the simulation and compare against the recorded baseline**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/sim && ./run.sh 2>&1 | tail -25
```

Expected, unchanged from before the split:

```
Test 1: PASS   (64 delivered, 0 mismatches)
Test 2: PASS   (0 delivered, frames rejected)
Test 3: 1 word -> 10 cycles ... 32 words -> 41 cycles
```

**If the Test 3 cycle counts changed, the split altered behaviour — stop and
find out why before proceeding.**

- [x] **Step 6: Update `vfpga_top.svh` to instantiate both halves**

Replace the single `qlink_link` instance with the `_tx` and `_rx` pair, both on
`aclk`, wired to the same signals as before.

- [x] **Step 7: Commit**

```bash
git add examples/16_qlink/hw/src/hdl/ examples/16_qlink/sim/ \
        examples/16_qlink/hw/src/vfpga_top.svh
git commit -m "qlink: split qlink_link into independent TX and RX halves"
```

---

### Task 2b: Move the datapath onto the GT clocks (Stage 2, part 2)

Deletes both fabric CDC FIFOs. **Expected saving ~50 ns one-way — the largest
single known quantity in the budget.**

After this task the only `aclk` logic left in the vFPGA is the AXI4-Lite CSR
block. Control bits cross into the GT domains; counters cross back as event
pulses counted in `aclk`.

**Files:**
- Modify: `hw/hdl/qlink/qlink_gty_wrapper.sv`
- Modify: `examples/16_qlink/hw/src/vfpga_top.svh`
- Modify: `scripts/ip_inst/qlink_infrastructure.tcl` (delete both FIFO IPs)

**Interfaces:**
- Consumes: `qlink_link_tx` / `qlink_link_rx` from Task 2a.
- Produces: `qlink_gty_wrapper` gains ports
  `tx_clk`, `rx_clk`, `tx_rstn`, `rx_rstn` (outputs), and the 32-bit word ports
  `phy_tx_data/valid/last/ready`, `phy_rx_data/valid/last/err` replace the
  256-bit AXIS pair.

- [x] **Step 1: Change the wrapper to expose GT clocks and 32-bit word ports**

Delete `axis_data_fifo_qlink_tx`/`_rx` instances and the `AXI4S` ports. Expose
instead:

```systemverilog
    output logic          tx_clk,     // txusrclk, 257.8125 MHz
    output logic          rx_clk,     // recovered clock
    output logic          tx_rstn,
    output logic          rx_rstn,

    input  logic [31:0]   phy_tx_data,
    input  logic          phy_tx_valid,
    input  logic          phy_tx_last,
    output logic          phy_tx_ready,
    output logic [31:0]   phy_rx_data,
    output logic          phy_rx_valid,
    output logic          phy_rx_last,
    output logic          phy_rx_err,
```

wired straight through to `qlink_phy_gty`. `channel_up`/`lane_up` keep their
existing `aclk` synchronisers.

- [x] **Step 2: Widen the shell→vFPGA plumbing**

The templates currently carry a 256-bit AXIS pair. Reuse those wires for the
32-bit word ports rather than adding new ones: in
`hw/templates/common/shell_top_tmplt.txt`, the QLINK branch drives
`aurora_rx.tdata[31:0]` / `aurora_tx.tdata[31:0]` and uses `tvalid`/`tlast`/
`tready` as the word handshake. Add `tx_clk`/`rx_clk`/`tx_rstn`/`rx_rstn` as four
new signals through `dynamic_top` → `user_wrapper` → `user_logic`, gated by
`cnfg.en_qlink_gty`, following the pattern already used for
`aurora_channel_up`.

- [x] **Step 3: Move the generator, checker and RTT counter in `vfpga_top.svh`**

- `qlink_link_tx` + syndrome generator + `cyc_cnt` + `t_start`: clocked by `tx_clk`.
- `qlink_link_rx` + checker: clocked by `rx_clk`.
- RTT capture: keep `cyc_cnt` on `tx_clk`. Cross `syn_out_valid` from `rx_clk`
  with `xpm_cdc_pulse`, and capture `rtt_cycles <= cyc_cnt - t_start` in the
  `tx_clk` domain.

```systemverilog
    // The RTT end event originates in the RX domain. Crossing it costs a fixed
    // ~4 cycles (~16 ns) that is INCLUDED in every reported RTT. It is constant,
    // so it does not distort the slope -- subtract it if you need absolute
    // one-way numbers.
    xpm_cdc_pulse #(.DEST_SYNC_FF(4), .REG_OUTPUT(1))
        inst_rtt_end (.src_clk(rx_clk), .src_rst(~rx_rstn), .src_pulse(syn_out_valid),
                      .dest_clk(tx_clk), .dest_rst(~tx_rstn), .dest_pulse(rtt_end_tx));
```

- [x] **Step 4: Add the CSR crossing layer**

Control bits `aclk` → `tx_clk` and `aclk` → `rx_clk`:

```systemverilog
    xpm_cdc_array_single #(.DEST_SYNC_FF(4), .SRC_INPUT_REG(1), .WIDTH(4))
        inst_ctrl_tx (.src_clk(aclk), .src_in({echo_mode, clr, arm, run}),
                      .dest_clk(tx_clk), .dest_out(ctrl_tx));
```

`n_rounds`, `interval` and `syn_words` are written while stopped, so cross them
with `xpm_cdc_array_single` too and document that they must be set before `RUN`.

Counters `tx_clk`/`rx_clk` → `aclk`: convert each increment to a pulse, cross with
`xpm_cdc_pulse`, and count in `aclk`.

```systemverilog
    // Counters are counted in aclk from crossed event pulses rather than
    // crossing the 32-bit values. A multi-bit counter crossed with plain
    // synchronisers tears mid-count and produces impossible readings.
```

`rtt_cycles` is stable between updates, so cross it with `xpm_cdc_handshake`
(WIDTH 32) rather than an array of synchronisers.

- [x] **Step 5: Delete the FIFO IPs**

Remove both `create_ip ... axis_data_fifo_qlink_tx` and `..._rx` blocks and their
comment from `qlink_infrastructure.tcl`.

- [x] **Step 6: Run the simulation**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/sim && ./run.sh 2>&1 | tail -20
```

Expected: all three tests unchanged. The testbench does not model the CDC layer,
so this only confirms the protocol core is still intact after the edits.

- [ ] **Step 7: Build, program both cards, measure**

THE PREDICTION, sharpened by simulation after the RTL landed. `tb_qlink_sys`
now models both architectures and reports one-way at 4 words as **140.0 ns
pre-2b, 91.0 ns post-2b**. `tb_qlink_cdc` measures the one crossing that
remains at **18.1 ns mean**, and a round trip contains two of them.

So the round trip should read:

| if the 166 ns/direction unaccounted term is... | predicted RTT |
|---|---|
| real and untouched by 2b — our GT is genuinely slow (A) | ~550 ns |
| an artefact of an optimistic FIFO model (B) | ~220 ns |

Measured pre-2b was 612 ns. Anything near 550 says the FIFOs were never the
problem and Task 3 (rate and width) is the only remaining lever. Anything near
220 says sub-100 ns one-way is live.

**These are distinguishable by 330 ns.** That is the point of this task: not to
save latency, but to find out where it is.

Then, on the same bitstream and without a peer or a cable:

```
qlink bench -l 2      # near-end PMA loopback: our fabric + our GT alone
qlink bench           # peer echoing: the whole path
```

The difference is cable plus far card. If `-l 2` alone accounts for most of the
RTT, the transceiver is the problem and no amount of fabric work will fix it.

- [x] **Step 8: Commit**

```bash
git add -A
git commit -m "qlink: run protocol datapath on GT clocks, delete fabric CDC FIFOs"
```

---

### Deviations from the plan as written (Task 2b)

Four, all found while implementing:

1. **Counters cross with `xpm_cdc_gray`, not pulse-counted in aclk.** The plan
   said convert each increment to a pulse and count in aclk. That LOSES counts:
   `tx_dropped` increments every cycle when the link is down and the generator
   is free-running at `INTERVAL=0`, far faster than a pulse crossing can
   forward. Gray-coding the counter itself cannot lose an increment.

2. **The echo path needs a crossing the plan did not mention.** `qlink_link_tx`
   must be clocked by the local transmit clock, so a received syndrome cannot be
   reflected without changing domain. It is the only crossing left on the
   syndrome path, down from four, and it is a measurement artefact — the real
   decoder consumes syndromes in the receive domain and never pays it.

3. **`N_STAB` drops from 1024 to 992 (31 words).** That crossing must carry
   `{round, payload}` atomically and `xpm_cdc_handshake` caps at 1024 bits;
   992 + 20 fits, 1024 + 20 does not. Splitting across two handshakes would
   break the atomicity that makes it correct.

4. **Runtime `LOOPBACK` control added (register 13).** Not in the plan. It costs
   ~20 lines and it is the only way to weigh our own transceiver without a
   second bitstream — which is precisely the question this task exists to
   answer. Changing it resets the GT, so the link drops and returns.

New coverage: `sim/tb_qlink_cdc.sv` exercises the crossing at its real 1012-bit
width against genuinely unrelated 257.8125/400 MHz clocks. The plan called the
CSR crossing layer the biggest bug surface with no simulation; it has one now.
`sim/run.sh` runs all three testbenches.

---

## Design space, probed exhaustively (2026-08-11)

A calibrated model, then every legal GT configuration measured against it.

```
protocol = (F + P) x T_w     T_w = W*1.25/R (8B/10B)  or  W/R (raw)
GT       = K x I / R         K = 14.3 internal pipeline stages
```

F = 9 fixed protocol cycles (tb_qlink: 10 cycles at 1 word, 1 cycle/word).
K = 14.3 calibrated from the measured 55.6 ns at I=40, R=10.3125.
On today's build the model predicts 117.5 ns against 117.9 measured, so it is
trustworthy for extrapolation.

**I, the INTERNAL datapath width, is the term nobody had touched.** We run I=40,
the widest option, and it accounts for most of the GT's 55.6 ns.

### Negative result: raw mode is not worth it

AMD's fintech note gets ~13 ns of GT latency from a **16-bit internal
datapath**. Probed on GTYE4 in Vivado 2025.1:

- **8B/10B is locked to I=40.** I=20 rejected at every rate and user width;
  user width 16 rejected outright.
- **Raw mode bottoms out at I=32.** I=16 rejected at every rate and width.

So the blog's headline configuration is not reachable on this transceiver
through this wizard at all. What raw mode actually buys is I=32 instead of 40
(1.25x) and no 25% line overhead (1.25x) — and both are exactly cancelled by
needing a 1.25x lower line rate to hold the same fabric clock:

| config | fabric | predicted one-way |
|---|---:|---:|
| 8B/10B 15.625 Gbps, W=32, I=40 | 390.6 MHz | **79.9 ns** |
| raw 12.5 Gbps, W=32, I=32 | 390.6 MHz | **79.9 ns** |
| raw 25.0 Gbps, W=64, I=64 | 390.6 MHz | 74.8 ns |
| raw 15.625 Gbps, W=32, I=32 | 488.3 MHz | 65.9 ns |

Identical to the decimal at the same fabric clock. Raw mode costs us our own
scrambler, our own block sync, RXSLIDE alignment and the loss of 8B/10B's
disparity and not-in-table error flags — **for nothing.** Do not do it.

The 488 MHz row is the theoretical edge and is not realistic in a DFX region.

### Where the remaining nanoseconds actually are

With I pinned at 40 and the fabric ceiling near 390 MHz, the transceiver is no
longer the cheapest target. Ranked by nanoseconds per unit of risk:

| step | delta | risk | why |
|---|---:|---|---|
| **shorter cable** | **-7** | none | ~9.6 ns of the budget is 2 m of DAC at 4.76 ns/m. A 0.5 m DAC is ~2.4 ns. This is a purchase, not a design. |
| rate to 15.625 Gbps | -38 | timing at 390.6 MHz | Task 3. Two config lines. |
| protocol F: 9 -> 5 | -10 | moderate, sim-verifiable | Task 5 below. |
| PMA RXSLIDE | -5? | high | Task 4. Drops the PCS comma aligner from the path. |

Cumulative: **~58 ns one-way**, with 8B/10B, at a 390 MHz fabric clock, no raw
mode and no exotic clocking.

**The single best ns-per-effort item in the entire budget is a shorter cable.**
It is 6% of the current one-way latency and costs nothing but a part.

---

### Task 3: Raise the line rate to 15.625 Gbps (Stage 3) — REVISED

**The original Task 3 (25.78 Gbps, 64-bit) is impossible.** The plan's own
"verify the dict before spending a bitgen" step earned its keep: probed on a
GTYE4 part in Vivado 2025.1, every 8B/10B combination at 25.78125 was rejected.
Two independent blockers:

1. **GTY 8B/10B tops out at 16.375 Gbps.** Accepted: 10.3125, 12.5, 15.0,
   15.625, 16.11328125. Rejected: 16.4355, 17.5, 18.75, 20.625, 25.0, 25.78125.
2. **25.78125 needs RAW encoding AND a 64-bit datapath**, and even then only
   from a 161.1328125 MHz reference. `RAW uw=64` was the single accepted
   combination at that rate.

Going there means owning comma alignment, DC balance and scrambling. That is a
different project, not a rate change.

**The plan also had the width backwards.** 64-bit is WORSE for latency, not
better. At a fixed line rate a wider word does not shorten serialisation — same
bits, same rate — but it lengthens every fixed FSM cycle, and our protocol
spends ~9 cycles on framing regardless of payload. Probed: at 15.625 Gbps,
32-bit gives 2.560 ns/word against 64-bit's 5.120. Stay at 32.

#### The reference clock, finally measured

`qlink clock -l 2` reports **257.808 MHz, 0.00% from 257.8125**. The board
delivers **156.25 MHz** and QLINK's GT declares 156.25, so it is correctly
configured and every latency figure in this document stands as measured.

Aurora (example 14) is the misconfigured one: it declares 161.1328125 against
the same cage, so it runs 25.0 Gbps/lane rather than 25.78125 — which is exactly
why its measured 2.648 ns/beat never matched the predicted 2.560. Worth ~3% to
example 14, unrelated to this plan.

`u280_static_base.xdc` constrains `gt1_refclk_p` at 6.206 ns (161.13 MHz) and
`u280_shell_base.xdc` at 3.103 ns. Both are wrong for a 156.25 MHz clock, but
both are FASTER than reality, so they over-constrain and are safe. Leave them:
they are shared with the Aurora and network builds.

#### The target

**15.625 Gbps = 156.25 x 100**, the largest multiplier under the 8B/10B ceiling
that the board's reference can reach. 32-bit user width, everything else
unchanged.

| | now | at 15.625 Gbps |
|---|---:|---:|
| line rate | 10.3125 Gbps | 15.625 Gbps |
| tx_clk | 257.8125 MHz | **390.625 MHz** |
| ns per word | 3.879 | 2.560 |
| protocol (13 cycles @ 4 words) | 50.4 | ~33 |
| GT | 55.6 | ~37 |
| TX PCS + cable | ~11.6 | ~11 |
| **one-way, d=11** | **117.9 measured** | **~81 predicted** |

The GT term is assumed to scale with the internal clock period, since the
pipeline is a fixed number of stages. That is the same assumption AMD's fintech
note relies on, and it is the single largest uncertainty in the projection. The
cable is incompressible.

**The risk moves from the transceiver to timing closure.** 390.625 MHz inside a
DFX region, on a recovered clock, is the hard part now — not the link.

**Files:**
- Modify: `scripts/ip_inst/qlink_infrastructure.tcl` (two values)
- Modify: `examples/16_qlink/sw/src/constants.hpp`
- Modify: `examples/16_qlink/sim/tb_qlink.sv`, `tb_qlink_sys.sv` (display only)
- Modify: `examples/16_qlink/hw/src/hdl/qlink_link_rx.sv`, `vfpga_top.svh`
  (echo length mirror, riding along)

- [ ] **Step 1: Change the line rate**

Only these two lines in the GT dict. `RX_COMMA_ALIGN_WORD` STAYS AT 4 — the
datapath is still 4 bytes wide, and this is the value that cost three build
cycles when it was wrong.

```tcl
            CONFIG.TX_LINE_RATE         15.625 \
            CONFIG.RX_LINE_RATE         15.625 \
```

- [x] **Step 2: Check the BUFG_GT divider — DONE, no change needed**

Probed both rates in the wizard. It tracks the line rate by itself:

| | 10.3125 Gbps | 15.625 Gbps |
|---|---|---|
| `TX_OUTCLK_SOURCE` | TXPROGDIVCLK | TXPROGDIVCLK |
| `TXPROGDIV_FREQ_VAL` | 257.8125 | 390.625 |
| `RX_OUTCLK_SOURCE` | RXOUTCLKPMA | RXOUTCLKPMA |

TXOUTCLK is already the user clock at the new rate and RXOUTCLKPMA is
line_rate/40 = 390.625 MHz, so `DIV(3'd0)` (divide by 1) stays correct on both
sides. `qlink_phy_gty` needs no change.

Cross-check: the 10.3125 column predicts 257.8125 MHz, and `qlink clock`
measured 257.808 on silicon. The wizard's arithmetic and the board agree.

- [ ] **Step 3: Mirror the echo length (rides along, no separate build)**

The reflector transmits with its own SYN_WORDS instead of the received frame's
length, which makes every two-card RTT asymmetric. Expose `rx_words` from
`qlink_link_rx`, widen the echo crossing from `N_STAB+20` to `N_STAB+28` (1012
-> 1020, still inside the 1024-bit `xpm_cdc_handshake` cap), and drive
`qlink_link_tx.syn_words_sel` from it in echo mode.

- [ ] **Step 4: Update the software constants**

```cpp
constexpr double   TXCLK_MHZ            = 390.625;
constexpr uint64_t DEFAULT_INTERVAL     = 391;        // 1 us
constexpr double   TXCLK_IF_15625_MHZ   = 390.625;    // refclk 156.25 x100
constexpr double   TXCLK_IF_16113_MHZ   = 402.832;    // refclk 161.1328125 x100
```

- [ ] **Step 5: Run the simulation regression**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/sim && ./run.sh
```

The protocol is rate-independent, so tb_qlink's CYCLE counts must not change —
only the ns column, which is display. Update its `1000.0/257.8125` and
tb_qlink_sys's `UCLK_HALF` (1.9394 -> 1.28) and `GT_STAGES`.

**If a cycle count moves, the echo-length change in Step 3 broke something.**

- [ ] **Step 6: Build, then measure in this order**

```
sudo ./qlink clock -l 2      # FIRST. Must read ~390.6 MHz.
sudo ./qlink bench  -l 2     # our fabric + our GT, symmetric, no peer
sudo ./qlink echo   --words 4    # far card
sudo ./qlink bench  --words 4    # near card, symmetric
```

`clock` first, always. If it does not read 390.6 the rate did not take, and
every number after it is scaled by an unknown factor — which is precisely the
trap that cost a full analysis cycle at 10.3125.

- [ ] **Step 7: Fallback ladder if timing does not close**

Do not fight 390.625 MHz. Drop a rung and re-measure:

| rate | tx_clk | predicted one-way |
|---|---|---|
| 15.625 Gbps (x100) | 390.6 MHz | ~81 ns |
| 12.5 Gbps (x80) | 312.5 MHz | ~98 ns |
| 10.3125 Gbps (x66) | 257.8 MHz | 118 ns (today) |

12.5 Gbps still lands just under target and is a far easier close. Take it
rather than spending days on 390.

Watch these paths in the timing report: the 992-bit masked compare in the
checker, the 992-bit shift in `qlink_link_tx`, and the 1012-bit handshake.

- [ ] **Step 8: Also consider LPM**

At 15.625 Gbps the Nyquist frequency rises from 5.16 to 7.81 GHz, and LPM is
recommended only below ~14 dB of channel loss. If `rx_errors` moves at all,
switch `RX_EQ_MODE` to DFE before blaming anything else.


### Task 4: Manual RXSLIDE alignment (Stage 4)

UG578: `RXSLIDE_MODE=PMA` *"provides minimal latency with minimum variation of
latency compared to PCS mode"*, and `RXCOMMADETEN=0` *"reduces RX datapath
latency"*. Saving is not quantified in the spec — this stage is measured, not
predicted.

**Files:**
- Modify: `scripts/ip_inst/qlink_infrastructure.tcl`
- Modify: `hw/hdl/qlink/qlink_phy_gty.sv`

- [ ] **Step 1: Confirm the RXSLIDE port can be exposed**

Before writing RTL, verify via the Vivado MCP that
`CONFIG.ENABLE_OPTIONAL_PORTS {loopback_in rxbufstatus_out rxslide_in}` is
accepted and that `rxslide_in` appears in the generated `.veo`. **If it does not,
stop — this stage is not available and Task 4 should be dropped.**

- [ ] **Step 2: Set the IP options**

```tcl
            CONFIG.RXSLIDE_MODE         PMA \
```

`RXSLIDE_MODE=PMA` requires `SHOW_REALIGN_COMMA=FALSE` (already set in Task 1)
and `RXOUTCLK` sourced from `RXOUTCLKPMA` (already the case).

- [ ] **Step 3: Add the alignment FSM to `qlink_phy_gty`**

The framer already reports whether a K-character landed in lane 0
(`framer_dbg[0]`) or elsewhere (`framer_dbg[1]`). That is the alignment oracle.

```systemverilog
    // Manual alignment: pulse RXSLIDE until a K-char lands in lane 0. UG578
    // requires RXSLIDE high for >=2 RXUSRCLK2 cycles and low for >32 before it
    // may be reasserted, so the FSM below waits 64 cycles between attempts.
    // After ALIGN_TRIES failures we give up and leave the link down rather than
    // sliding forever.
```

States: `A_WAIT` (rx_done) → `A_SLIDE` (2-cycle pulse) → `A_SETTLE` (64 cycles)
→ check `framer_dbg`; if lane-0 K seen and no other-lane K, go `A_LOCKED` and
drive `rxcommadeten = 0`; else back to `A_SLIDE`.

Gate `link_up` on `A_LOCKED` in place of the current `rx_byte_aligned` dwell.

- [ ] **Step 4: Run the simulation**

The testbench does not model RXSLIDE, so this only confirms the framer is
unchanged. All three tests must still pass.

- [ ] **Step 5: Build, program both cards, measure**

Expected: unquantified. `phy_dbg` must show `K_in_lane0=1`, `K_misaligned=0`
before any traffic — that now proves the manual FSM converged.

**Highest-risk stage: if alignment never converges the link stays down.** Keep
the previous bitstream to fall back to.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "qlink: manual RXSLIDE alignment, comma detect block bypassed once locked"
```

---

### Task 5: Cut the protocol's fixed cycle count (Stage 5) — NEW

With I pinned at 40 and the rate at 15.625 Gbps, the protocol's **fixed** cost
is the largest term we still control. F = 9 cycles at 2.56 ns is 23 ns, against
a GT that will be ~37.

Measured, not guessed: tb_qlink Test 3 gives 10 cycles at 1 word and 1 cycle per
word thereafter, so F = 9 exactly.

Four cuts, each independently verifiable in simulation with zero hardware time:

- [ ] **Step 1: Emit the header on `syn_valid` rather than a cycle later**

`qlink_link_tx` spends T_IDLE latching, then T_HDR emitting. The header is a
pure function of `{tx_type, tx_words, tx_round}`, all available on the
`syn_valid` cycle. Emit it directly and enter T_PAY. **-1 cycle.**

- [ ] **Step 2: Carry the checksum in the EOF word**

`qlink_framer` already sends a dedicated EOF word, `{3x D16.2, K29.7}` — three
data bytes doing nothing. Put the 16-bit Fletcher checksum in two of them and
delete the T_CKS state and the whole checksum word from the frame. **-1 cycle
on TX, -1 on RX**, and the frame gets a word shorter, which also shortens
serialisation.

- [ ] **Step 3: Cut-through RX**

`qlink_link_rx` asserts `syn_out_valid` only after validating the checksum. Emit
on the last payload word instead and raise a separate `syn_out_bad` one cycle
later if validation fails. **-1 cycle.**

This is a real design decision, not just an optimisation, so state it plainly:
the decoder starts on a syndrome that has not yet been checked, and is told a
cycle later if it was wrong. For real-time QEC that is the right trade — a
correction that arrives after the decode window has closed is worthless, so
starting early and retracting beats waiting and being certain. It is the same
reasoning that already makes this link drop-and-flag rather than retry. **If the
consuming decoder cannot retract, do not take this step.**

- [ ] **Step 4: Re-run the simulation and check the cycle counts moved**

```bash
cd /scratch/anubhav/Coyote/examples/16_qlink/sim && ./run.sh
```

Expected: tb_qlink Test 3 drops from 10 cycles at 1 word to ~6, and Test 1 and
Test 2 still pass unchanged. **Test 2 matters most here** — it is the
misalignment rejection test, and three of the four cuts touch framing.

Target F = 5, worth **~10 ns** at 15.625 Gbps.

---

### Task 6: Shorter cable (Stage 6) — NEW, and do it first

The two-card and loopback measurements differ by 11.6 ns, which is the output
driver, the pads, the cable and the input stage. At 4.76 ns/m in a DAC, the ~2 m
cable is ~9.6 ns of that — **8% of the current one-way latency.**

- [ ] **Step 1: Fit the shortest QSFP28 DAC that will physically reach**

0.5 m is standard and is ~2.4 ns. Saving ~7 ns.

- [ ] **Step 2: Re-measure and confirm the delta is real**

```
sudo ./qlink bench -l 2 --words 4     # unchanged -- loopback never used the cable
sudo ./qlink echo  --words 4          # far card
sudo ./qlink bench --words 4          # near card
```

The loopback number MUST NOT move. If it does, something other than the cable
changed and the comparison is void.

This requires no build, no RTL and no risk. It is the best nanoseconds per unit
of effort available anywhere in this plan, and it should be done before Task 3
so that Task 3's result is measured against the final channel.

---

## Levers closed out (2026-08-11)

Two of the three remaining levers are now off the table, one by measurement and
one by architecture. Recording both so nobody re-opens them.

### Lever 1 (GT low-latency settings): DEAD, not reachable

AMD's fintech note gets its transceiver latency from settings that
`gtwizard_ultrascale` does not expose. Probed on GTYE4:

| knob | result |
|---|---|
| `RX_SLIDE_MODE = PMA` | rejected, even with auto comma-align disabled. Only PCS/OFF. |
| `RXSYNC_SKIP_DA` | not a wizard property |
| `RX_XCLK_SEL` / `TX_XCLK_SEL` | not wizard properties |
| `RX_INT_DATA_WIDTH = 20` | rejected |

They are GT primitive attributes the wizard owns. Reaching them means
instantiating `GTYE4_CHANNEL` directly and taking over reset sequencing, CDR
bring-up and buffer-bypass control -- trading a working link for perhaps 7 ns.
Not worth it at this stage. **This also closes Task 4**, which assumed PMA-mode
RXSLIDE was available.

**Found on the way:** `RX_BUFFER_BYPASS_MODE` reads back `MULTI` when we ask for
`SINGLE`. It is the only one of the 23 properties qlink sets that does not take.
Almost certainly benign for latency -- it configures the bypass CONTROLLER, not
the datapath -- but it invalidates the assumption that our dict is what is in
the silicon, so verify readback rather than trusting set_property.

### Lever 3 (multi-lane striping): DROPPED by design

The four lanes of the QSFP cage are wanted for FOUR INDEPENDENT SYNDROME LINKS,
not for striping one syndrome. Those two uses are mutually exclusive, and the
independent-lane case is the intended end state.

So the structural goal is not "make one link use four lanes", it is **"make one
link cheap enough to instantiate four times"**. Fabric cost now counts 4x, which
raises the value of the streaming protocol beyond its latency saving.

### What is actually left, single lane

| lever | delta | note |
|---|---:|---|
| streaming protocol (F 5 -> 3) | -5 | Task 7 below |
| sparse syndrome encoding | -5 to -7 at d=11, more at high d | now the ONLY payload lever |
| shorter cable | -7 | a purchase |
| direct GTYE4_CHANNEL instantiation | -7 | high risk, large job |

The transceiver is a hard floor at ~32 ns: I is stuck at 40, and the rate is
capped by the 8B/10B ceiling and by the board reference being 156.25 MHz.
Single-lane floor is therefore roughly:

```
32.2 GT + 7.7 protocol + 10.2 payload + 12.5 cable = 62.6 ns
   with sparse encoding                            ~55 ns
   with sparse encoding and a 0.5 m cable          ~48 ns
```

---

## Pre-bitgen review (2026-08-12)

### Bug found by reading the FSM, not by simulating it

`phy_tx_cks` was driven combinationally from the running checksum registers.
The framer reads it one cycle AFTER `qlink_link_tx` has returned to T_IDLE, so
a round starting on that cycle overwrote `tx_cka`/`tx_ckb` before the trailer
went out: the frame was sent with the NEXT frame's partial checksum and the
receiver reported a perfectly good frame as corrupt. Fixed by latching the
value when the last payload word is issued.

**The first version of the test for it PASSED against the broken RTL.**
`send_rounds` pulses syn_valid every 2 cycles and a 4-word frame is 6 cycles, so
the phase is locked even and never lands on the one cycle that matters. Holding
syn_valid HIGH instead reproduces it immediately: 33 of 34 frames reported
corrupt. tb_qlink Test 5 now does that, and it was verified to fail without the
fix before being accepted as a test.

Lesson worth keeping: a one-cycle-wide window cannot be found with periodic
stimulus whose period shares a factor with the frame length.

### Rates above 15.625 Gbps: legal, but not taken

The board reference is 156.25 MHz and the 8B/10B ceiling is 16.375 Gbps, so
x101 through x104 are all reachable:

| multiple | rate | fabric | vs 15.625 |
|---|---|---|---|
| x100 | 15.625 Gbps | 390.6 MHz | 1.000 |
| x104 | 16.250 Gbps | 406.3 MHz | 1.040 |
| x104.8 | 16.375 Gbps | rejected | -- |

x104 is worth about 1.8 ns and costs 16 MHz of fabric clock on the build that
already carries the most timing risk in this plan. Take it only once 390.6 MHz
is known to close with margin. It is one value in
`scripts/ip_inst/qlink_infrastructure.tcl`.

### Known measurement-harness limitation

In echo mode the reflector marks frames with ITS OWN sparse bit rather than the
type it received, exactly as it uses its own SYN_WORDS. Harmless for latency
measurement -- nothing in the link interprets the payload -- but a two-card
sparse test needs the bit set on both cards, the same way `--words` has to be.

---

## Expected Cumulative Result

Measured, not projected, except the last row.

| stage | one-way at d=11 (4 words) | status |
|---|---:|---|
| baseline | 306 ns | measured |
| after Task 2b (GT clocks, no CDC FIFOs) | **117.9 ns** | measured, symmetric two-card |
| after Task 6 (0.5 m cable) | ~111 ns | projected, no build needed |
| after Task 3 (15.625 Gbps) | ~74 ns | projected |
| after Task 5 (protocol F 9->5) | ~64 ns | projected |
| after Task 4 (PMA RXSLIDE) | ~58 ns | projected, least certain |

The Task 2b figure is a direct symmetric measurement (`echo --words 4` /
`bench --words 4`, RTT 272 ns, minus two 18.1 ns echo crossings), and it agrees
to 0.3 ns with the independent reconstruction from near-end PMA loopback.

Budget as measured after Task 2b:

| term | ns | source |
|---|---:|---|
| protocol (qlink_link + both framers) | 50.4 | tb_qlink Test 3 |
| GT (TX PMA + RX full) | 55.6 | `bench -l 2`, flat to +/-0.5 over a 6x payload range |
| TX PCS + cable | 11.6 | residual |
| **one-way** | **117.9** | direct measurement |

Task 2b beat its own prediction by a wide margin: predicted ~98 ns off the round
trip, delivered 236 ns. The 166 ns/direction that was unaccounted for at the
start of this plan was mostly the CDC FIFO model being optimistic, not a slow
transceiver. What remains is ~55 ns of genuine GT latency, which is what Task 3
attacks.

## Risks

| risk | mitigation |
|---|---|
| Task 2b's CSR crossing layer is the biggest bug surface, and the sim does not cover it | Counters cross as event pulses, `rtt_cycles` via handshake — never plain multi-bit synchronisers |
| Task 3's `RX_COMMA_ALIGN_WORD` left at 4 | Explicit step; symptom is `rx_frames=0` AND `rx_errors=0` |
| Task 4 alignment never converges | Bounded retries, previous bitstream retained |
| LPM equalisation degrades the channel | Revert to `AUTO` if `rx_errors` moves at all |
| A stage regresses and it is unclear which | One commit per stage, `git revert` to roll back |
