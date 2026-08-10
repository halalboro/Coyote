# BRAID Latency Reduction (Stages 1–4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce BRAID's measured one-way latency from 289 ns toward ~150–180 ns by
removing fabric clock crossings, shortening the GT PCS path, and raising the user
clock — without losing the protocol's correctness guarantees.

**Architecture:** Four independent stages, each ending in one bitstream and one
hardware measurement. Stage 1 is IP configuration only. Stage 2 moves the protocol
datapath onto the GT's own clocks and deletes both fabric CDC FIFOs. Stage 3 doubles
the GT word width and raises the line rate, with the framer acting as a 32→64-bit
gearbox so the protocol core is untouched. Stage 4 replaces automatic comma alignment
with a manual RXSLIDE FSM so the GT's alignment block can be bypassed.

**Tech Stack:** SystemVerilog, Vivado 2025.1, `gtwizard_ultrascale` v1.7 (GTYE4),
Coyote shell (U280), xsim for regression, `braid` host app for measurement.

## Global Constraints

- **`braid_link.sv` must contain no Coyote types.** No `AXI4S`, no `lynx_pkg`, no
  `axi_ctrl` — plain `logic` ports only. It is copied verbatim to a bare RFSoC
  project. Everything Coyote-specific lives in `vfpga_top.svh`.
- **`braid_framer.sv` is the module the testbench exercises AND the module
  `braid_phy_gty` instantiates.** Never copy framing logic back into
  `braid_phy_gty` — the simulation would silently stop testing the real design.
- **Run `examples/16_braid/sim/run.sh` before every bitgen.** It takes ~7 seconds
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
sudo ./braid echo
# clara (/scratch/anubhav/Coyote-test) — sweep
sudo ./braid bench --iters 1000
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
| `scripts/ip_inst/braid_infrastructure.tcl` | GT + FIFO IP configuration | 1, 2, 3, 4 |
| `hw/hdl/braid/braid_framer.sv` | K-char framing, GT-width gearbox | 3, 4 |
| `hw/hdl/braid/braid_phy_gty.sv` | GT instance, clocking, bring-up FSM | 2, 3, 4 |
| `hw/hdl/braid/braid_gty_wrapper.sv` | shell glue, CDC FIFOs, CSR crossing | 2 |
| `examples/16_braid/hw/src/hdl/braid_link.sv` | protocol core (split in 2a) | 2a |
| `examples/16_braid/hw/src/hdl/braid_link_tx.sv` | TX half (new, stage 2a) | 2a, 2b |
| `examples/16_braid/hw/src/hdl/braid_link_rx.sv` | RX half (new, stage 2a) | 2a, 2b |
| `examples/16_braid/hw/src/vfpga_top.svh` | CSRs, generator, checker, RTT | 2b |
| `examples/16_braid/sim/tb_braid.sv` | regression + latency measurement | 2a, 3 |

---

### Task 1: PCS configuration only (Stage 1)

Lowest-risk stage. No RTL changes at all, so the simulation result must be
byte-identical to before — that is itself the check that nothing else moved.

**Files:**
- Modify: `scripts/ip_inst/braid_infrastructure.tcl`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new. GT behaviour only.

- [ ] **Step 1: Record the pre-change simulation output**

```bash
cd /scratch/anubhav/Coyote/examples/16_braid/sim
./run.sh > /tmp/sim_before.txt 2>&1 || true
grep -A3 "Test 3" /tmp/sim_before.txt
```

Expected: the protocol latency table (`1 word → 10 cycles`, `32 → 41 cycles`).

- [ ] **Step 2: Add the two documented latency settings**

In the `set_property -dict` block for `braid_gty`, after
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
cd /scratch/anubhav/Coyote/examples/16_braid/sim
./run.sh > /tmp/sim_after.txt 2>&1 || true
diff <(grep -E "PASS|FAIL|cycles" /tmp/sim_before.txt) \
     <(grep -E "PASS|FAIL|cycles" /tmp/sim_after.txt) && echo "IDENTICAL"
```

Expected: `IDENTICAL`. This stage touches no RTL, so any difference means
something unintended changed.

- [ ] **Step 4: Build and program both cards**

```bash
cd /scratch/anubhav/Coyote/examples/16_braid/hw/build
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
git add scripts/ip_inst/braid_infrastructure.tcl
git commit -m "braid: PCS low-latency settings (SHOW_REALIGN off, LPM equalisation)"
```

---

### Task 2a: Split `braid_link` into TX and RX halves (Stage 2, part 1)

Pure refactor, fully verifiable in simulation, no bitgen. This exists so that
Task 2b — which changes clocking and CSR access at the same time — is not also
changing the protocol core.

The TX and RX FSMs in `braid_link` already share no state except the counters and
`clr`. Splitting is mechanical.

**Files:**
- Create: `examples/16_braid/hw/src/hdl/braid_link_tx.sv`
- Create: `examples/16_braid/hw/src/hdl/braid_link_rx.sv`
- Delete: `examples/16_braid/hw/src/hdl/braid_link.sv`
- Modify: `examples/16_braid/sim/tb_braid.sv`
- Modify: `examples/16_braid/hw/src/vfpga_top.svh`

**Interfaces:**
- Produces:
  - `braid_link_tx #(N_STAB, N_CORR) (clk, rstn, link_up, clr, syn_bits[N_STAB-1:0], syn_valid, syn_round[19:0], syn_words_sel[7:0], corr_bits[N_CORR-1:0], corr_valid, phy_tx_data[31:0], phy_tx_valid, phy_tx_last, phy_tx_ready, tx_frames[31:0], tx_dropped[31:0])`
  - `braid_link_rx #(N_STAB, N_CORR) (clk, rstn, link_up, clr, syn_out_bits[N_STAB-1:0], syn_out_valid, syn_out_round[31:0], syn_out_gap, corr_out_bits[N_CORR-1:0], corr_out_valid, phy_rx_data[31:0], phy_rx_valid, phy_rx_last, phy_rx_err, rx_frames[31:0], rx_errors[31:0], rx_gaps[31:0])`

- [ ] **Step 1: Create `braid_link_tx.sv`**

Copy the header comment, the `SYN_WORDS`/`CORR_WORDS`/`MAX_WORDS` localparams, the
`TYPE_SYN`/`TYPE_CORR` localparams, the `cks_pack` function, and the entire TX
`always_ff` block from `braid_link.sv` verbatim. Port list exactly as in
**Interfaces** above. Keep the portability rule comment — this file is still
copied to the RFSoC.

- [ ] **Step 2: Create `braid_link_rx.sv`**

Same treatment for the RX `always_ff` block, the `rx_*` declarations, and
`cks_pack` (duplicated — the two files must not depend on each other).

- [ ] **Step 3: Update the testbench to instantiate both halves**

Replace each `braid_link` instance with a `braid_link_tx` + `braid_link_rx` pair
on the same clock. For instance A:

```systemverilog
    braid_link_tx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_tx (
        .clk(clk), .rstn(rstn), .link_up(1'b1), .clr(1'b0),
        .syn_bits(a_syn_bits), .syn_valid(a_syn_valid), .syn_round(a_syn_round),
        .syn_words_sel(a_words), .corr_bits('0), .corr_valid(1'b0),
        .phy_tx_data(a_ptx_data), .phy_tx_valid(a_ptx_valid),
        .phy_tx_last(a_ptx_last), .phy_tx_ready(a_ptx_ready),
        .tx_frames(a_txf), .tx_dropped(a_txd)
    );

    braid_link_rx #(.N_STAB(N_STAB), .N_CORR(N_CORR)) u_link_a_rx (
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

- [ ] **Step 4: Update `run.sh` to compile both files**

```bash
xvlog -sv tb_braid.sv \
      ../hw/src/hdl/braid_link_tx.sv \
      ../hw/src/hdl/braid_link_rx.sv \
      ../../../hw/hdl/braid/braid_framer.sv
```

- [ ] **Step 5: Run the simulation and compare against the recorded baseline**

```bash
cd /scratch/anubhav/Coyote/examples/16_braid/sim && ./run.sh 2>&1 | tail -25
```

Expected, unchanged from before the split:

```
Test 1: PASS   (64 delivered, 0 mismatches)
Test 2: PASS   (0 delivered, frames rejected)
Test 3: 1 word -> 10 cycles ... 32 words -> 41 cycles
```

**If the Test 3 cycle counts changed, the split altered behaviour — stop and
find out why before proceeding.**

- [ ] **Step 6: Update `vfpga_top.svh` to instantiate both halves**

Replace the single `braid_link` instance with the `_tx` and `_rx` pair, both on
`aclk`, wired to the same signals as before.

- [ ] **Step 7: Commit**

```bash
git add examples/16_braid/hw/src/hdl/ examples/16_braid/sim/ \
        examples/16_braid/hw/src/vfpga_top.svh
git commit -m "braid: split braid_link into independent TX and RX halves"
```

---

### Task 2b: Move the datapath onto the GT clocks (Stage 2, part 2)

Deletes both fabric CDC FIFOs. **Expected saving ~50 ns one-way — the largest
single known quantity in the budget.**

After this task the only `aclk` logic left in the vFPGA is the AXI4-Lite CSR
block. Control bits cross into the GT domains; counters cross back as event
pulses counted in `aclk`.

**Files:**
- Modify: `hw/hdl/braid/braid_gty_wrapper.sv`
- Modify: `examples/16_braid/hw/src/vfpga_top.svh`
- Modify: `scripts/ip_inst/braid_infrastructure.tcl` (delete both FIFO IPs)

**Interfaces:**
- Consumes: `braid_link_tx` / `braid_link_rx` from Task 2a.
- Produces: `braid_gty_wrapper` gains ports
  `tx_clk`, `rx_clk`, `tx_rstn`, `rx_rstn` (outputs), and the 32-bit word ports
  `phy_tx_data/valid/last/ready`, `phy_rx_data/valid/last/err` replace the
  256-bit AXIS pair.

- [ ] **Step 1: Change the wrapper to expose GT clocks and 32-bit word ports**

Delete `axis_data_fifo_braid_tx`/`_rx` instances and the `AXI4S` ports. Expose
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

wired straight through to `braid_phy_gty`. `channel_up`/`lane_up` keep their
existing `aclk` synchronisers.

- [ ] **Step 2: Widen the shell→vFPGA plumbing**

The templates currently carry a 256-bit AXIS pair. Reuse those wires for the
32-bit word ports rather than adding new ones: in
`hw/templates/common/shell_top_tmplt.txt`, the BRAID branch drives
`aurora_rx.tdata[31:0]` / `aurora_tx.tdata[31:0]` and uses `tvalid`/`tlast`/
`tready` as the word handshake. Add `tx_clk`/`rx_clk`/`tx_rstn`/`rx_rstn` as four
new signals through `dynamic_top` → `user_wrapper` → `user_logic`, gated by
`cnfg.en_braid_gty`, following the pattern already used for
`aurora_channel_up`.

- [ ] **Step 3: Move the generator, checker and RTT counter in `vfpga_top.svh`**

- `braid_link_tx` + syndrome generator + `cyc_cnt` + `t_start`: clocked by `tx_clk`.
- `braid_link_rx` + checker: clocked by `rx_clk`.
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

- [ ] **Step 4: Add the CSR crossing layer**

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

- [ ] **Step 5: Delete the FIFO IPs**

Remove both `create_ip ... axis_data_fifo_braid_tx` and `..._rx` blocks and their
comment from `braid_infrastructure.tcl`.

- [ ] **Step 6: Run the simulation**

```bash
cd /scratch/anubhav/Coyote/examples/16_braid/sim && ./run.sh 2>&1 | tail -20
```

Expected: all three tests unchanged. The testbench does not model the CDC layer,
so this only confirms the protocol core is still intact after the edits.

- [ ] **Step 7: Build, program both cards, measure**

Expected: **RTT fixed term ~478 ns** (578 − ~100), one-way ~239 ns.
`lost=0`, payloads matched.

If `rtt_med` drops by materially less than 80 ns, the ~50 ns/direction CDC
estimate was wrong and the remaining stages should be re-costed before starting
Task 3.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "braid: run protocol datapath on GT clocks, delete fabric CDC FIFOs"
```

---

### Task 3: Raise rate and width to 25.78 Gbps / 64-bit (Stage 3)

GT pipeline latency in nanoseconds scales with the **internal** clock period
(`RXUSRCLK = line_rate / internal_width`), not the fabric clock. Holding internal
width at 40 (the only value 8B/10B allows) and raising the rate takes RXUSRCLK
from 258 MHz to 644 MHz — a **2.5x shorter internal period**. The fabric side
lands at 322 MHz with a 64-bit user width.

Verified legal by probe: `user=64, int=40` is accepted; `int=20` is rejected at
every user width.

**The protocol stays on 32-bit words.** `braid_framer` becomes a 32↔64-bit gearbox,
so `braid_link_tx`/`_rx` are untouched. Frames with an odd word count are padded
with one idle word, which the receiver discards because it is a K-character.

**Files:**
- Modify: `scripts/ip_inst/braid_infrastructure.tcl`
- Modify: `hw/hdl/braid/braid_framer.sv`
- Modify: `examples/16_braid/sim/tb_braid.sv`

- [ ] **Step 1: Update the GT IP configuration**

```tcl
            CONFIG.TX_LINE_RATE         25.78125 \
            CONFIG.RX_LINE_RATE         25.78125 \
            CONFIG.TX_USER_DATA_WIDTH   64 \
            CONFIG.RX_USER_DATA_WIDTH   64 \
            CONFIG.RX_COMMA_ALIGN_WORD  8 \
```

**`RX_COMMA_ALIGN_WORD` becomes 8 — it must equal the datapath width in bytes.**
Leaving it at 4 lets the comma land in lane 4 as well as lane 0, and the framer
inspects only lane 0.

**Verify the dict is accepted before spending a bitgen.** Write this to
`/tmp/verify25g.tcl` and run it via the Vivado MCP (`source /tmp/verify25g.tcl`),
then read `/tmp/verify25g_out.txt`:

```tcl
set fh [open /tmp/verify25g_out.txt w]
proc say {fh m} { puts $fh $m; flush $fh }
catch {close_project}
create_project -force v25 /tmp/v25 -part xcu55c-fsvh2892-2L-e
create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name g25
set ip [get_ips g25]
# CHANNEL_ENABLE X0Y0 because xcu55c is the probe part; X0Y44 is a U280 site.
if {[catch {set_property -dict [list \
    CONFIG.GT_TYPE GTY CONFIG.CHANNEL_ENABLE X0Y0 \
    CONFIG.TX_MASTER_CHANNEL X0Y0 CONFIG.RX_MASTER_CHANNEL X0Y0 \
    CONFIG.TX_LINE_RATE 25.78125 CONFIG.RX_LINE_RATE 25.78125 \
    CONFIG.TX_REFCLK_FREQUENCY 156.25 CONFIG.RX_REFCLK_FREQUENCY 156.25 \
    CONFIG.TX_DATA_ENCODING 8B10B CONFIG.RX_DATA_DECODING 8B10B \
    CONFIG.TX_USER_DATA_WIDTH 64 CONFIG.RX_USER_DATA_WIDTH 64 \
    CONFIG.TX_BUFFER_MODE 0 CONFIG.RX_BUFFER_MODE 0 \
    CONFIG.RX_COMMA_P_ENABLE true CONFIG.RX_COMMA_M_ENABLE true \
    CONFIG.RX_COMMA_PRESET K28.5 CONFIG.RX_COMMA_ALIGN_WORD 8 \
    CONFIG.RX_COMMA_SHOW_REALIGN_ENABLE false \
    CONFIG.FREERUN_FREQUENCY 100 ] $ip} e]} {
    say $fh "FAILED: [string range $e 0 300]"
} else {
    say $fh "DICT OK"
    foreach p {CONFIG.TX_LINE_RATE CONFIG.TX_USER_DATA_WIDTH CONFIG.TX_INT_DATA_WIDTH \
               CONFIG.RX_COMMA_ALIGN_WORD} { catch {say $fh "  $p = [get_property $p $ip]"} }
}
if {[catch {generate_target {instantiation_template} $ip} e]} {
    say $fh "generate FAILED"
} else { say $fh "generate ok" }
close $fh
```

Expected: `DICT OK`, `TX_INT_DATA_WIDTH = 80` (8 chars x 10 bits), `generate ok`.
**If 25.78125 Gbps with 8B/10B is rejected, this stage is not available** — GTY
8B/10B has a rate ceiling. Fall back to keeping 10.3125 Gbps and taking only the
64-bit width (user clock 128.9 MHz — which would be SLOWER, so in that case skip
Task 3 entirely and go to Task 4).

- [ ] **Step 2: Widen the framer's GT ports and add the gearbox**

`gt_txdata`/`gt_rxdata` become `[63:0]`, `gt_txctrl2` `[7:0]` (all 8 lanes used),
`gt_rxctrl0` `[15:0]` (bits 7:0 used).

Control words keep exactly one K in lane 0:

```systemverilog
    localparam logic [63:0] W_IDLE = {{7{D16_2}}, K28_5};
    localparam logic [63:0] W_SOF  = {{7{D16_2}}, K27_7};
    localparam logic [63:0] W_EOF  = {{7{D16_2}}, K29_7};
    localparam logic [7:0]  CTRL_K = 8'b0000_0001;
```

TX gearbox: hold the first protocol word, emit `{word1, word0}` when the second
arrives. If `phy_tx_last` lands on an odd word, emit `{W_IDLE[63:32], word}` with
`gt_txctrl2 = 8'b1111_0000` so the padding half is K-characters.

RX gearbox: on each 64-bit data word, emit `gt_rxdata[31:0]` then
`gt_rxdata[63:32]`, suppressing the second if its `rxctrl0` bits mark it as
control (the odd-length pad).

- [ ] **Step 3: Update the testbench for 64-bit GT words**

Widen `a_txdata`/`b_rxdata` to `[63:0]` and the misalignment model to shift by
1–7 bytes. Keep the same three tests.

- [ ] **Step 4: Run the simulation**

Expected: Tests 1 and 2 pass unchanged. **Test 3's cycle counts should roughly
halve for multi-word payloads** because two protocol words now ride per GT cycle.

- [ ] **Step 5: Build, program both cards, measure**

Expected: RTT fixed term down a further ~60–80 ns, and the slope roughly halved.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "braid: 25.78 Gbps, 64-bit GT datapath with 32-bit protocol gearbox"
```

---

### Task 4: Manual RXSLIDE alignment (Stage 4)

UG578: `RXSLIDE_MODE=PMA` *"provides minimal latency with minimum variation of
latency compared to PCS mode"*, and `RXCOMMADETEN=0` *"reduces RX datapath
latency"*. Saving is not quantified in the spec — this stage is measured, not
predicted.

**Files:**
- Modify: `scripts/ip_inst/braid_infrastructure.tcl`
- Modify: `hw/hdl/braid/braid_phy_gty.sv`

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

- [ ] **Step 3: Add the alignment FSM to `braid_phy_gty`**

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
git commit -m "braid: manual RXSLIDE alignment, comma detect block bypassed once locked"
```

---

## Expected Cumulative Result

| stage | change | expected one-way |
|---|---|---|
| baseline | RX buffer bypass | 289 ns |
| 1 | PCS config | ~280 ns |
| 2 | no fabric CDC | ~239 ns |
| 3 | 25.78 G / 64-bit | ~150-180 ns |
| 4 | manual alignment | ~165 ns |

Against Aurora's measured 201 ns one-way. **Sub-100 ns is not reachable on U280
GTY** — the remaining floor is GT silicon latency.

## Risks

| risk | mitigation |
|---|---|
| Task 2b's CSR crossing layer is the biggest bug surface, and the sim does not cover it | Counters cross as event pulses, `rtt_cycles` via handshake — never plain multi-bit synchronisers |
| Task 3's `RX_COMMA_ALIGN_WORD` left at 4 | Explicit step; symptom is `rx_frames=0` AND `rx_errors=0` |
| Task 4 alignment never converges | Bounded retries, previous bitstream retained |
| LPM equalisation degrades the channel | Revert to `AUTO` if `rx_errors` moves at all |
| A stage regresses and it is unclear which | One commit per stage, `git revert` to roll back |
