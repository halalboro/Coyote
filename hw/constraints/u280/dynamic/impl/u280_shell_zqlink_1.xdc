###
### QLINK GTY on QSFP1 — single lane, 10.3125 Gbps, 8B/10B
###
### Sorts alphabetically AFTER u280_shell_net_1.xdc (hence the `zqlink` prefix)
### so its PACKAGE_PIN assignments win. Vivado warns on the override; the last
### assignment is the one that takes effect.
###
### Active when EN_QLINK_GTY=1. Mutually exclusive with EN_NET_1 and
### EN_AURORA_1 (all three want the QSFP1 cage) -- enforced in
### cmake/FindCoyoteHW.cmake.
###
### NOTE: the build adds the whole dynamic/impl directory unconditionally, so
### this file is also read during an Aurora build. That is harmless by
### construction: the lane-0 PACKAGE_PINs below are the same pins Aurora
### assigns to gt1_*[0], and the LOC filter matches *inst_qlink* with -quiet,
### so it is a no-op when no QLINK cell exists. The reverse holds for
### u280_shell_zaurora_1.xdc during a QLINK build. Keep it that way: if you add
### assignments here that differ from Aurora's, they WILL leak into Aurora
### builds, because "zqlink" sorts after "zaurora" and the last write wins.
###

# QSFP1 reference clock. 156.25 MHz feeds 10.3125 Gbps directly (x66), and the
# example-14 throughput measurement indicates this is the frequency the board
# actually delivers on these pins.
set_property PACKAGE_PIN M43 [get_ports gt1_refclk_n]
set_property PACKAGE_PIN M42 [get_ports gt1_refclk_p]

# Lane 0 only. The QSFP cage carries four lanes; driving one is fine over a
# normal QSFP28 DAC. Pins match example 14's gt1_*[0], which that build proved
# corresponds to GTYE4_CHANNEL_X0Y44.
# gt1_* are 4-bit vectors at the shell top level even though only lane 0 is
# driven; the remaining three are left unconnected.
set_property PACKAGE_PIN G54 [get_ports {gt1_rxn_in[0]}]
set_property PACKAGE_PIN G53 [get_ports {gt1_rxp_in[0]}]
set_property PACKAGE_PIN G49 [get_ports {gt1_txn_out[0]}]
set_property PACKAGE_PIN G48 [get_ports {gt1_txp_out[0]}]

# Setting only PACKAGE_PIN leaves the transceiver shape on the PCIe quad, so
# pin the channel explicitly. Same lesson as the Aurora integration: a linked
# checkpoint restores stale placement and these must be re-asserted after
# open_checkpoint in pnr_shell.tcl.
set_property LOC GTYE4_CHANNEL_X0Y44 [get_cells -hierarchical -quiet \
    -filter {NAME =~ *inst_qlink*GTYE4_CHANNEL_PRIM_INST}]
