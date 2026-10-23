###
### V80 QSFP0 — 200G DCMAC reference clock pins
###
### Only the reference clock pair needs constraining. The GT serial lanes
### (gt0_rxp_in/rxn_in/txp_out/txn_out) are resolved implicitly from the GT
### quad, which is anchored by CONFIG.DCMAC_LOCATION_C0 = DCMAC_X1Y1 in
### hw/bd/versal/cr_dcmac.tcl — Vivado's UCIO-1 check does not flag them. The
### reference clock is different: it enters through an IBUFDS_GTME5, which is a
### separately placeable element, so its port needs an explicit site LOC or
### bitstream generation fails with:
###
###   ERROR: [DRC UCIO-1] Unconstrained Logical Port: ... Problem ports:
###   gt0_refclk_n, and gt0_refclk_p.
###
### Both DCMAC indices are constrained here. They use different port names, and
### only the selected index's ports exist in any given build, so the other pair
### simply warns (see the note on control flow below).
###
###   EN_NET_0 -> index 0 = DCMAC_X1Y1 -> GTM_QUAD_X1Y7, bank 209 -> qsfp0
###   EN_NET_1 -> index 1 = DCMAC_X0Y2 -> GTM_QUAD_X0Y9, bank 111 -> qsfp3
###
### Pin values verified against the device database for xcv80-lsva4737-2MHP-e-S
### (`get_property PIN_FUNC [get_package_pins ...]`, `DIFF_PAIR_PIN`):
###
###   AR51  GTM_REFCLKP0_209   BANK 209      AR52  GTM_REFCLKN0_209
###   AL17  GTM_REFCLKP0_111   BANK 111      AL16  GTM_REFCLKN0_111
###
### and cross-checked against AVED's board pin file
### (amd_v80_gen5x8_25.1/src/constraints/impl.pins.xdc), which names AR51
### "qsfp0_322mhz_clk_p ;# Bank 209" and AL17 "qsfp2_322mhz_clk_p ;# Bank 111".
### AVED lists no separate reference clock for qsfp1 or qsfp3, so each of these
### two inputs feeds both cages of its DCMAC.
###
### Bank assignment confirmed with
### `get_iobanks -of_objects [get_sites GTM_QUAD_X1Y7]` -> 209 and
### `... [get_sites GTM_QUAD_X0Y9]` -> 111.
###
### NO CONTROL FLOW HERE. XDC is a restricted Tcl subset and Vivado rejects
### `if` with "[Designutils 20-1307] Command 'if' is not supported in the xdc
### constraint file", then silently skips the body — which looks exactly like
### the constraint having no effect. scripts/impl/link.tcl.in adds this whole
### directory unconditionally, so on a V80 build with EN_NET=0 these two lines
### produce "[Vivado 12-584] No ports matched" plus "[Common 17-55]
### 'set_property' expects at least one object". That is expected and harmless:
### v80_shell_ddr_0.xdc alongside does the same thing when EN_AMC=0.
###

# DCMAC index 0 — bank 209, qsfp0
set_property PACKAGE_PIN AR51 [get_ports gt0_refclk_p]
set_property PACKAGE_PIN AR52 [get_ports gt0_refclk_n]

# DCMAC index 1 — bank 111, qsfp3
set_property PACKAGE_PIN AL17 [get_ports gt1_refclk_p]
set_property PACKAGE_PIN AL16 [get_ports gt1_refclk_n]
