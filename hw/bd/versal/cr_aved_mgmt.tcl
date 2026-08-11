######################################################################################
# This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
#
# Copyright (c) 2026, Systems Group, ETH Zurich
# All rights reserved.
######################################################################################
#
# AVED-derived management block — Phase A: GCQ only.
#
# Adds the Generic Command Queue (GCQ, xilinx.com:ip:cmd_queue) and the RPU-side
# SmartConnect (rpu_sc) from AVED into the V80 shell BD. AMC firmware on the R5
# (RPU0) consumes the GCQ via M_AXI_LPD; the host produces SQ entries via PCIe.
#
# Mirrors AVED's amd_v80_gen5x8_25.1 base_logic hierarchy:
#   - gcq_m2r          ← create_bd_design.tcl:466
#   - rpu_sc           ← create_bd_design.tcl:406-412
#   - M_AXI_LPD ➜ rpu_sc/S00 ➜ gcq_m2r/S01    create_bd_design.tcl:476, 1009
#   - pl0_ref_clk ➜ m_axi_lpd_aclk + rpu_sc   create_bd_design.tcl:1032-1033
#   - irq_sq    ➜ pl_ps_irq0 (replaces const_0 tie-off)
#
# Topology:
#   PCIe  ─► axi_noc_0 ─► smartconnect_1 ─► M00 ─► axi_main (shrunk to 128 MB)
#                                       └─► M01 ─► gcq_m2r/S00     (producer)
#   M_AXI_FPD ────────────────────────► smartconnect_1/S01          (unchanged path)
#   M_AXI_LPD ────────────────────────► rpu_sc/S00 ──► gcq_m2r/S01  (consumer, R5-only)
#
# Address map (Phase A, V80):
#   PCIe view (BAR4 @ 0x0208_0000_0000, 256 MB):
#     axi_main       : 0x0208_0000_0000 .. 0x0208_07FF_FFFF   (128 MB, was 256 MB)
#     gcq_m2r/S00    : 0x0208_0800_0000 + 64 KB                (producer regs)
#   R5 view (M_AXI_LPD, 32-bit address space):
#     gcq_m2r/S01    : 0x8001_0000 + 4 KB                      (consumer regs — AVED-canonical)
#
# This proc must be called AFTER cr_bd_design_static has finished building the BD,
# because it assumes smartconnect_1 exists and versal_cips_0/pl_ps_irq0 has a
# const_0 driver to disconnect. Gated by cnfg(fdev)==v80 && cnfg(en_amc)==1.

proc cr_bd_design_aved_mgmt { parentCell } {
  variable script_folder

  # Match cr_pci.tcl convention: project-wide cfg dict is exposed as $cnfg
  upvar #0 cfg cnfg

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  puts "  ** Instantiating AVED management block (GCQ + rpu_sc) for R5 consumer path"

  ########################################################################################################
  # Instances
  ########################################################################################################

  # GCQ — AVED's host↔R5 mailbox. Dual-AXI4-Lite (S00 producer, S01 consumer).
  set gcq_m2r [ create_bd_cell -type ip -vlnv xilinx.com:ip:cmd_queue gcq_m2r ]

  # rpu_sc — SmartConnect between M_AXI_LPD (CIPS, R5 master) and GCQ S01.
  # NUM_CLKS=2 so the SmartConnect does CDC internally: slave side runs on
  # pl0_ref_clk (matches M_AXI_LPD), master side runs on the shell clock
  # (matches gcq_m2r/aclk). AVED ties both rpu_sc and gcq_m2r to clk_pl so
  # they share one domain and no CDC is needed; Coyote keeps gcq_m2r on the
  # shell clock for clean host-PCIe handoff, so the boundary lives here.
  # NUM_MI bumps to 2 later when SMBus lands.
  set rpu_sc [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect rpu_sc ]
  set_property -dict [list \
    CONFIG.NUM_CLKS {2} \
    CONFIG.NUM_MI   {1} \
    CONFIG.NUM_SI   {1} \
  ] $rpu_sc

  ########################################################################################################
  # Expand smartconnect_1 to add one master output for GCQ S00 (PCIe producer side)
  ########################################################################################################
  # smartconnect_1 today: NUM_SI=2 (PCIe NoC M01 + M_AXI_FPD), NUM_MI=1 (M00 → axi_main).
  # We add M01 → gcq_m2r/S00 so host PCIe writes can reach the producer regs.
  set_property -dict [list CONFIG.NUM_MI {2}] [get_bd_cells smartconnect_1]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_1/M01_AXI] [get_bd_intf_pins gcq_m2r/S00_AXI]

  ########################################################################################################
  # M_AXI_LPD ➜ rpu_sc ➜ GCQ S01
  ########################################################################################################
  # Enabled by PS_USE_M_AXI_LPD=1 in cr_pci.tcl. The 32-bit LPD master path
  # exists only when EN_AMC=1; otherwise the CIPS port is unconnected.
  connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_LPD] [get_bd_intf_pins rpu_sc/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins rpu_sc/M00_AXI] [get_bd_intf_pins gcq_m2r/S01_AXI]

  ########################################################################################################
  # Clocks
  ########################################################################################################
  # GCQ runs on the shell clock (clk_wiz_0/clk_out1, same as smartconnect_1) —
  # this gives the host-PCIe path a clean handoff. The S01 side is CDC'd by
  # rpu_sc (which is configured as a multi-clock SmartConnect, see above).
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins gcq_m2r/aclk]

  # rpu_sc aclk  (slave side) = pl0_ref_clk — matches M_AXI_LPD.
  # rpu_sc aclk1 (master side) = clk_wiz_0/clk_out1 — matches gcq_m2r/aclk.
  # SmartConnect with NUM_CLKS=2 propagates each input's CLK_DOMAIN to the
  # connected interfaces and performs CDC across the master/slave boundary.
  # cr_pci.tcl owns the versal_cips_0/m_axi_lpd_aclk wiring since it owns LPD enable.
  connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins rpu_sc/aclk]
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]        [get_bd_pins rpu_sc/aclk1]

  ########################################################################################################
  # Resets
  ########################################################################################################
  # GCQ aresetn: share the smartconnect_1 reset (PCIe dma{0,1}_axi_aresetn).
  # rpu_sc aresetn: same source, SmartConnect handles CDC internally between
  # the M_AXI_LPD pl0_ref_clk domain and the reset's source domain.
  if {$cnfg(pcie_gen) eq 5} {
    connect_bd_net [get_bd_pins versal_cips_0/dma1_axi_aresetn] [get_bd_pins gcq_m2r/aresetn]
    connect_bd_net [get_bd_pins versal_cips_0/dma1_axi_aresetn] [get_bd_pins rpu_sc/aresetn]
  } else {
    connect_bd_net [get_bd_pins versal_cips_0/dma0_axi_aresetn] [get_bd_pins gcq_m2r/aresetn]
    connect_bd_net [get_bd_pins versal_cips_0/dma0_axi_aresetn] [get_bd_pins rpu_sc/aresetn]
  }

  ########################################################################################################
  # IRQ wiring: irq_sq → versal_cips_0/pl_ps_irq0
  ########################################################################################################
  # pl_ps_irq0 was tied to const_0/dout by cr_pci.tcl. Disconnect that and route
  # GCQ's irq_sq there so AMC on R5 wakes on host doorbells. irq_cq stays open
  # for now — host polls; future work routes it to QDMA usr_irq.
  set old_net [get_bd_nets -of_objects [get_bd_pins versal_cips_0/pl_ps_irq0]]
  if {$old_net ne ""} {
    delete_bd_objs $old_net
  }
  connect_bd_net [get_bd_pins gcq_m2r/irq_sq] [get_bd_pins versal_cips_0/pl_ps_irq0]

  ########################################################################################################
  # Address map
  ########################################################################################################
  # Shrink axi_main from 256 MB to 128 MB on PCIe so upper-half BAR4 is free for GCQ S00.
  # The APU view via M_AXI_FPD stays at 256 MB unchanged.
  assign_bd_address -offset 0x020800000000 -range 128M \
      -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] \
      [get_bd_addr_segs axi_main/Reg] -force

  # GCQ S00 (producer regs) from PCIe view, upper half of BAR4
  assign_bd_address -offset 0x020808000000 -range 64K \
      -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] \
      [get_bd_addr_segs gcq_m2r/S00_AXI/S00_AXI_Reg] -force

  # GCQ S01 (consumer regs) in M_AXI_LPD address space — AVED-canonical offset.
  # The R5's AMC firmware references this exact address via the v80 profile HAL.
  assign_bd_address -offset 0x80010000 -range 4K \
      -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_LPD] \
      [get_bd_addr_segs gcq_m2r/S01_AXI/S01_AXI_Reg] -force

  current_bd_instance $oldCurInst
}
