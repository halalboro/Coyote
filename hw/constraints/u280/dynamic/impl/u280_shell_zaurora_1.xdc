###
### Aurora 64B/66B on QSFP1 — overrides QSFP1 reference clock pins to 161 MHz
###
### This file MUST sort alphabetically AFTER u280_shell_net_1.xdc (hence the
### `zaurora` prefix) so its PACKAGE_PIN assignments override net_1's 156 MHz
### settings. Vivado emits a warning on PACKAGE_PIN override but the last
### assignment wins.
###
### Active when EN_AURORA_1=1 in CMake. Verified mutually exclusive with
### EN_NET_1=1 by validation_checks_hw() in cmake/FindCoyoteHW.cmake.
###

# QSFP1 reference clock — 161.1328125 MHz (Aurora's required ref clock)
set_property PACKAGE_PIN M43 [get_ports gt1_refclk_n]
set_property PACKAGE_PIN M42 [get_ports gt1_refclk_p]

# QSFP1 transceiver lanes. These duplicate u280_shell_net_1.xdc's data-lane
# pinout because aurora_qsfp1 does not enable Coyote EN_NET_1, so net_1.xdc is
# intentionally skipped by the build flow.
set_property PACKAGE_PIN G54 [get_ports {gt1_rxn_in[0]}]
set_property PACKAGE_PIN F52 [get_ports {gt1_rxn_in[1]}]
set_property PACKAGE_PIN E54 [get_ports {gt1_rxn_in[2]}]
set_property PACKAGE_PIN D52 [get_ports {gt1_rxn_in[3]}]
set_property PACKAGE_PIN G53 [get_ports {gt1_rxp_in[0]}]
set_property PACKAGE_PIN F51 [get_ports {gt1_rxp_in[1]}]
set_property PACKAGE_PIN E53 [get_ports {gt1_rxp_in[2]}]
set_property PACKAGE_PIN D51 [get_ports {gt1_rxp_in[3]}]
set_property PACKAGE_PIN G49 [get_ports {gt1_txn_out[0]}]
set_property PACKAGE_PIN E49 [get_ports {gt1_txn_out[1]}]
set_property PACKAGE_PIN C49 [get_ports {gt1_txn_out[2]}]
set_property PACKAGE_PIN A50 [get_ports {gt1_txn_out[3]}]
set_property PACKAGE_PIN G48 [get_ports {gt1_txp_out[0]}]
set_property PACKAGE_PIN E48 [get_ports {gt1_txp_out[1]}]
set_property PACKAGE_PIN C48 [get_ports {gt1_txp_out[2]}]
set_property PACKAGE_PIN A49 [get_ports {gt1_txp_out[3]}]

# Be explicit about port LOC too. The generated Aurora GT XDC initially ties
# the transceiver shape to PCIe sites X1Y0..X1Y3; setting only PACKAGE_PIN is
# not enough to clear all restored physical port placement in the linked DCP.
set_property LOC G54 [get_ports {gt1_rxn_in[0]}]
set_property LOC F52 [get_ports {gt1_rxn_in[1]}]
set_property LOC E54 [get_ports {gt1_rxn_in[2]}]
set_property LOC D52 [get_ports {gt1_rxn_in[3]}]
set_property LOC G53 [get_ports {gt1_rxp_in[0]}]
set_property LOC F51 [get_ports {gt1_rxp_in[1]}]
set_property LOC E53 [get_ports {gt1_rxp_in[2]}]
set_property LOC D51 [get_ports {gt1_rxp_in[3]}]
set_property LOC G49 [get_ports {gt1_txn_out[0]}]
set_property LOC E49 [get_ports {gt1_txn_out[1]}]
set_property LOC C49 [get_ports {gt1_txn_out[2]}]
set_property LOC A50 [get_ports {gt1_txn_out[3]}]
set_property LOC G48 [get_ports {gt1_txp_out[0]}]
set_property LOC E48 [get_ports {gt1_txp_out[1]}]
set_property LOC C48 [get_ports {gt1_txp_out[2]}]
set_property LOC A49 [get_ports {gt1_txp_out[3]}]

# Note: the Aurora IP defines its own create_clock on the MGTREFCLK input via
# its packaged XDC (period 6.206 ns = 1/161.1328125 MHz). We do NOT redefine
# it here — doing so would conflict with the IP's internal constraint.

# Vivado 2023.2's Aurora 64B/66B customization for xcu280 emits core-level
# GTYE4_CHANNEL LOCs in the PCIe/XDMA quad (X1Y0..X1Y3). Override those LOCs
# after the IP XDC is read so the Aurora GTs land on the U280 QSFP1 group used
# by Coyote's gt1_* top-level pins.
# The Aurora generated channel instance indices are reversed relative to the
# gt1_* top-level lane numbering after PACKAGE_PIN placement on U280 bank 135:
#   gt1_*[0] -> channel instance [3] -> X0Y44
#   gt1_*[1] -> channel instance [2] -> X0Y45
#   gt1_*[2] -> channel instance [1] -> X0Y46
#   gt1_*[3] -> channel instance [0] -> X0Y47
set_property LOC GTYE4_CHANNEL_X0Y44 [get_cells -hierarchical -quiet -filter {NAME =~ *inst_aurora*gen_channel_container[24].*gen_gtye4_channel_inst[3].GTYE4_CHANNEL_PRIM_INST}]
set_property LOC GTYE4_CHANNEL_X0Y45 [get_cells -hierarchical -quiet -filter {NAME =~ *inst_aurora*gen_channel_container[24].*gen_gtye4_channel_inst[2].GTYE4_CHANNEL_PRIM_INST}]
set_property LOC GTYE4_CHANNEL_X0Y46 [get_cells -hierarchical -quiet -filter {NAME =~ *inst_aurora*gen_channel_container[24].*gen_gtye4_channel_inst[1].GTYE4_CHANNEL_PRIM_INST}]
set_property LOC GTYE4_CHANNEL_X0Y47 [get_cells -hierarchical -quiet -filter {NAME =~ *inst_aurora*gen_channel_container[24].*gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST}]
