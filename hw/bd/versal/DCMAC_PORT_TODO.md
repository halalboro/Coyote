# Versal DCMAC port — status

Ported from [fpgasystems/Versal-DCMAC](https://github.com/fpgasystems/Versal-DCMAC)
on 2026-06-23; integrated into the shell on 2026-08-04.

## Relationship to upstream

`hw/hdl/network/dcmac/*`, `cr_dcmac.tcl` and `board_config.tcl` are kept
byte-identical to the upstream package so future pulls stay a plain `cp`.
Verify with:

```
diff -rq hw/hdl/network/dcmac <upstream>/hdl
diff -q  hw/bd/versal/cr_dcmac.tcl <upstream>/tcl/dcmac.tcl
diff -q  hw/bd/versal/board_config.tcl <upstream>/tcl/board_config.tcl
```

One deliberate divergence, made in **both** trees so they stay in sync and the
change can go upstream as a PR: `bd_dcmac` now exposes bring-up status at the
block design boundary — `rst_state_dbg[4:0]`, `rst_done`, `gt_rst_done_tx`,
`gt_rst_done_rx`. Without them the block design offers no way to tell whether
the link came up. This touches `dcmac_reset_ctrl.sv`,
`dcmac_reset_ctrl_wrapper.v` and `dcmac.tcl`.

Second divergence (2026-10-23, `cr_dcmac.tcl` only, **not yet mirrored
upstream**):
- `bd_dcmac` / `create_hier_cell_dcmac_wrapper` take a new trailing
  `dcmac_mon` argument (default 0, so `bd_dcmac_qsfp` and old callers are
  unchanged). With it, the QSFP 0 segmented-interface nets are tapped out as
  `mon_rx_*` / `mon_tx_*` (dclk), the DCMAC AXIS clock and the APB clock leave
  the block design as `mon_dclk` / `mon_apb_clk`, and the four statistics tick
  pins become inputs instead of being tied to `const_0`. A routed-checkpoint
  query showed the hard block times the tick pins against `APB3_CLK`, which is
  `clk_wizard_dcmac` clkout3 (sys_clk).
- The `dcmac_axil=1` path changed. Upstream ran the DCMAC's `s_axi_aclk` (also
  its APB3 clock) on `aclk` (nclk, 400 MHz here). It now stays on sys_clk
  (~100 MHz, the IP's default `FREQ_HZ`, and what the tied-off path already
  used), and the SmartConnect gets `NUM_CLKS 2` to cross from `aclk`.
  `s_axi_aresetn` is held high as in the tied-off case. The boundary `s_axi` is
  pinned to 32-bit AXI4-Lite, and in standalone mode the DCMAC's 64 KiB `Reg`
  segment is assigned at offset 0.

`cr_shell.tcl.in` now calls `bd_dcmac "" $idx 0 1 <board> <nclk_f> 1`.
Offline validation (2026-10-23, standalone BD in a scratch project):
`validate_bd_design` passes both with the new arguments and with the old
`0 0`. The only critical warnings, BD 41-737 read-only boundary params and
BD 41-1343 core-reset association, also appear with the old arguments; monitor
mode removes the BD 41-2383 tick-pin width-mismatch ones.

Coyote-authored glue lives in `hw/hdl/network/dcmac_cyt/`, deliberately outside
the vendored directory.

**`board_config.tcl` must keep that exact name and sit next to `cr_dcmac.tcl`.**
`cr_dcmac.tcl:84` sources it itself, resolved relative to its own location:

```tcl
source [file join [file dirname [info script]] board_config.tcl]
```

It was briefly renamed to `board_config_dcmac.tcl` for clarity, which broke the
build. Only `cr_dcmac.tcl` is renamed from upstream (`dcmac.tcl`), and that is
safe because it is sourced by path from `cr_shell.tcl.in`. Nothing should source
`board_config.tcl` explicitly — `cr_dcmac.tcl` already has.

## What is wired up

- `cr_shell.tcl.in` calls `bd_dcmac "" 0 0 0 v80 $cfg(nclk_f)` in the shell
  project, and adds both `hdl/network/dcmac` and `hdl/network/dcmac_cyt`.
  **It closes any current block design first, and asserts that it did.**
  `bd_dcmac` picks its boundary style by probing `current_bd_design`: nothing
  open means standalone (its own BD with external ports, which is what
  `dcmac_axis_wrapper.sv` instantiates); something open means inline (pins on a
  caller-supplied hier cell). `cr_bd_design_ctrl` and `cr_bd_dyn_xbar` do close
  their own designs, but the `set_property SYNTH_CHECKPOINT_MODE` calls on those
  `.bd` files reopen them — so without the guard `bd_dcmac` silently takes the
  inline path and fails on its first boundary call with
  `ERROR: [BD 5-253] Please change the current instance to a hierarchical cell`.
  The tell in the log is the *absence* of
  `INFO: [BD_TCL-3] Currently there is no design <dcmac_0_versal_axis_wrapper>
  in project, so creating one...`.
- `dcmac_axis_wrapper.sv` instantiates the block design, pads runt frames on TX
  (`eth_frame_padder_512.sv`, replacing the HLS IP the CMAC path uses), and
  synchronises the status pins into `nclk`.
- `network_module.sv` branches on `` `FPGA_ARCH_VERSAL ``: DCMAC on Versal,
  CMAC on UltraScale+. On Versal `rclk` is `nclk` and `rresetn` is gated on the
  reset FSM reaching `ST_DONE`.
- `network_top.sv` gained `` `EN_NET_RAW ``, which bypasses `network_stack`
  entirely and crosses the raw 512-bit stream from `nclk` into `aclk` for a
  single vFPGA.
- `shell_clk_tmplt.txt` declares the GT reference clock at 3.103 ns
  (322.265625 MHz), replacing the old 6.206 ns CMAC placeholder.
- `FindCoyoteHW.cmake` adds `EN_NET_RAW` / `NET_RAW_VFPGA_ID`, folds the former
  into the derived `EN_NET`, raises `NCLK_F` to 400 on Versal network builds,
  skips the `hw/services/network` submodule in raw mode, and rejects the
  configurations that cannot work (see below).
- `network_infrastructure.tcl` returns early on Versal after creating a single
  IP (`axis_data_fifo_net_ccross_early_512`). Several IPs further down are not
  offered for Versal parts at all — `vio` 3.0 and the legacy `axis_interconnect`
  1.1 — and fail at `create_ip` even though nothing instantiates them. An early
  return rather than per-IP guards, so this is one decision instead of a series
  of failed builds. Verified not to change the UltraScale+ IP set (95 IPs before
  and after for `EN_RDMA=1 EN_TCP=1`).
- `cr_shell.tcl.in` disables `network_stack.sv` and `network_packet_sniffer.sv`
  on Versal (`is_enabled false`). Neither is instantiated in raw mode, but both
  reference IPs that do not exist there.
- `examples/16_dcmac` exercises the whole path with a MAC-swap echo.

Pin constraints: the GT **serial** lanes need none — `CONFIG.DCMAC_LOCATION_C0`
anchors the quad and Vivado resolves `gt0_rxp_in`/`rxn_in`/`txp_out`/`txn_out`
from it, with no UCIO-1 complaint. The **reference clock** does need explicit
LOCs, because it enters through an IBUFDS_GTME5 that is separately placeable;
without them bitgen fails with `[DRC UCIO-1] ... Problem ports: gt0_refclk_n,
and gt0_refclk_p`. They live in
[hw/constraints/v80/dynamic/impl/v80_shell_net_0.xdc](../../constraints/v80/dynamic/impl/v80_shell_net_0.xdc)
(`AR51`/`AR52`, bank 209), which `scripts/impl/link.tcl.in` picks up with the
rest of that directory.

The V80 has no `qsfp0_*` sideband pins in this design — that cage belongs to
the AVED satellite controller.

## Enforced constraints

- `EN_NET` on Versal requires `EN_NET_RAW=1`. The stack's four HLS cores come
  from the `fpga-network-stack` submodule and are not built for Versal parts.
- `EN_NET` on Versal requires `EN_SHELL_PBLOCK=0`, so `inst_shell` is never a
  reconfigurable partition and the DCMAC and its GT quad stay static silicon.
  Use `BUILD_STATIC=1` (flat link) or `EN_PR=1`.
- `EN_NET_RAW` is incompatible with `EN_RDMA`, `EN_TCP`, `EN_SNIFFER` and
  `EN_STATS` — all of them sit on the stack it removes.
- `EN_NET_0` and `EN_NET_1` are mutually exclusive (pre-existing check). On
  Versal they select the DCMAC site rather than a CMAC instance.

## V80 QSFP cage map

Derived from the device database (`get_iobanks -of_objects [get_sites ...]`,
`get_property PIN_FUNC [get_package_pins ...]`) and cross-checked with AVED's
`amd_v80_gen5x8_25.1/src/constraints/impl.pins.xdc`:

| AVED port | GTM quad | Bank | Refclk P/N | DCMAC site | Selected by |
|---|---|---|---|---|---|
| qsfp0 | `GTM_QUAD_X1Y7` | 209 | `AR51`/`AR52` | `DCMAC_X1Y1` | `EN_NET_0` |
| qsfp1 | `GTM_QUAD_X1Y8` | 210 | shares `AR51` | `DCMAC_X1Y1` | dual mode only |
| qsfp2 | `GTM_QUAD_X0Y10` | 112 | shares `AL17` | `DCMAC_X0Y2` | dual mode only |
| qsfp3 | `GTM_QUAD_X0Y9` | 111 | `AL17`/`AL16` | `DCMAC_X0Y2` | `EN_NET_1` |

With `dual_dcmac 0` each DCMAC uses the lower-numbered of its two quads, which
is why `EN_NET_0` lands on qsfp0 and `EN_NET_1` on qsfp3. **Both verified on
routed checkpoints** — index 0 placed `GTM_QUAD_X1Y7`, and index 1 (2026-08-09)
placed:

| Query | Result |
|---|---|
| `get_sites -filter {SITE_TYPE =~ "DCMAC*" && IS_USED}` | `DCMAC_X0Y2` |
| `get_sites -filter {SITE_TYPE =~ "GTM_QUAD*" && IS_USED}` | `GTM_QUAD_X0Y9` |
| `get_property LOC [get_cells -hier -filter {REF_NAME =~ "IBUFDS_GTME5*"}]` | `GTM_REFCLK_X0Y18` (bank 111) |
| `get_property PACKAGE_PIN [get_ports gt1_refclk_p]` | `AL17` |

Note that the router only logs a `Router swapped GT pin ... GTM_QUAD_*` line
when it has to *move* the reference clock, so with a correct LOC there is
nothing about the quad in the build log at all. Grepping the log is not a
verification; open the routed checkpoint and query the sites.

## Not done

1. **Dual-DCMAC / dual-QSFP56.** Upstream marks these experimental and
   hardware-unvalidated; `bd_dcmac` is called with `dual_dcmac 0`. This is what
   would be needed to reach qsfp1 (bank 210) or qsfp2 (bank 112) — the *second*
   quad of each DCMAC site.
3. ~~**AXI4-Lite to the DCMAC's PG369 registers.**~~ Done 2026-10-23, but
   not through Coyote's control address map. `dcmac_axis_wrapper` exposes a
   request/response register port (`dcmac_debug.sv`), and `network_top` and the
   templates thread it to the raw-Ethernet vFPGA as `mac_reg_*` (crossed by
   `common/ccross/reg_port_ccross.sv`). Example 16 drives it from CSRs 10-13.
4. **The full network stack on Versal.** Would require building `ip_handler`,
   `icmp_server`, `mac_ip_encode` and `arp_server_subnet` for a Versal part.
   That is a separate project from wiring up the MAC.

## External blocker: DCMAC IP licence

Bitstream generation requires a licence for the `dcmac` IP that is greater than
Design Linking. Synthesis, placement and routing all work without it; only
`write_device_image` fails:

```
ERROR: [Common 17-69] Command failed: This design contains one or more cells for
which bitstream generation is not permitted:
  .../dcmac_wrapper/dcmac_0/inst/i_..._dcmac_0_0_top (<encrypted cellview>)
The following IP(s) require licenses greater than a Design Linking license to
generate bitstream: dcmac
```

This is a **no-charge licence that must still be generated**, not a purchase.
DCMAC has the same licensing shape as CMAC, which this site already holds:

| IP (2025.1 install) | `licenseKey` | `paymentRequired` |
|---|---|---|
| `dcmac_v3_0` | `dcmac@2025.05` | true |
| `cmac_usplus_v3_1` | `cmac_usplus@2020.05` | true |
| `axis_data_fifo_v2_0` | *(none)* | *(none)* |
| `gtwiz_versal_v1_0` | *(none)* | *(none)* |

`paymentRequired=true` distinguishes "requires a licence INCREMENT" from
genuinely licence-free IPs, which carry no `licenseKey` element at all. It does
not imply a fee.

As of 2026-08-05 the licence files on this machine (`~/.Xilinx/Xilinx_amy.lic`,
`/share/xilinx/Xilinx.lic`, `/share/xilinx/licenses/*.lic`) contain only
`INCREMENT cmac_usplus xilinxd 2024.08 permanent`. There is no `dcmac` feature
in any of them.

Generate one from AMD's product licensing site the same way the `cmac_usplus`
one was obtained, for host ID `84160ccd9910`. The INCREMENT version must be
**>= 2025.05**, since that is what `dcmac_v3_0` requires:

```
INCREMENT dcmac xilinxd 2025.05 permanent ...
```

Afterwards the DCMAC IP output products must be reset and regenerated, because
the routed netlist caches the licence status:

```tcl
open_project <build>/<proj>_shell/<proj>.xpr
reset_target all [get_files dcmac_0_versal_axis_wrapper.bd]
generate_target all [get_files dcmac_0_versal_axis_wrapper.bd]
```

then re-run synthesis and implementation.

## Timing

The first full run closed neither `aclk` nor `xclk` at 400 MHz
(WNS -1.536 ns, 26978 failing endpoints). This is not specific to DCMAC — every
example in this tree misses timing on the same clocks (13_micro_blossom -1.451,
14_aurora_loopback -0.776, 15_amc_ping -0.452, which also shows the identical
WPWS -0.357 pulse-width violation on one endpoint).

What matters for this work: **`nclk` passes** (WNS +0.029, 0 failing endpoints),
so the raw Ethernet path itself closes at 400 MHz. The failures are on `aclk`
(-1.360, 21541 endpoints) and `xclk` (-0.167, 3018).

Note the coupling when choosing clock frequencies: the raw stream is crossed
into `aclk` before it reaches the vFPGA, so **`ACLK_F` governs whether the user
side can absorb line rate, not just `NCLK_F`**. Both need >= 391 MHz for
512 b x f >= 200 Gb/s. Dropping `ACLK_F` to close timing means the vFPGA can no
longer keep up with a full-rate receive burst, and the RX crossing FIFO in
`network_top` will overflow — at which point frame-drop logic on the RX path
becomes necessary.

## Unverified assumptions

These could not be checked without a Vivado elaboration and should be the first
suspects if the build fails:

- ~~The flattened block design port names used in `dcmac_axis_wrapper.sv`~~ —
  **confirmed 2026-08-05**: the design synthesised, placed and routed, so
  `S_AXIS_0_*` / `M_AXIS_0_*`, `qsfp_gt_clk_clk_p/_n` and
  `qsfp_gt0_grx_p/_n` / `qsfp_gt0_gtx_p/_n` are all correct.
- That the DCMAC inserts the FCS and does not auto-pad, which is what sets
  `MIN_FRAME_BYTES=60` in `eth_frame_padder_512`. If it passes FCS through from
  the user side the parameter should be 64; if it pads by itself the padder is
  a no-op either way.
