######################################################################################
# This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
#
# Copyright (c) 2026, Systems Group, ETH Zurich
# All rights reserved.
######################################################################################
#
# V80 onboard DDR4 (4 GB) controller — hard NoC-attached.
#
# Instantiates `axi_noc_mc_ddr4_0` as a separate axi_noc IP that wraps the
# integrated DDR4 memory controller (DDRMC). The main NoC (`axi_noc_0`) routes
# requests into this controller via INI master port M00_INI (single path —
# Versal allows max one S->MC connection per DDR controller, [BD 41-3265]).
#
# Config and pin map vendored from AVED `amd_v80_gen5x8_25.1`:
#   - create_bd_design.tcl:912-938 (controller config)
#   - create_bd_design.tcl:998-999, 1002 (main NoC ↔ DDR4 INI wiring)
#   - constraints/impl.pins.xdc (DDR4 PHY pins; mirrored in v80_shell_ddr_0.xdc)
#
# Memory layout (address map assigned by callers in cr_pci.tcl):
#   DDR_LOW0 region : 0x000_0000_0000 .. 0x000_FFFF_FFFF  (4 GB, first half)
#   DDR_CH1  region : 0x500_8000_0000 .. 0x500_FFFF_FFFF  (4 GB upper half)
#   AMC linker script expects code at 0x40000000 (inside DDR_LOW0).
#
# Must be called from cr_bd_design_static AFTER axi_noc_0 has been created
# and the CIPS instance has the LPD AXI port enabled.

proc cr_bd_design_ddr4_v80 { parentCell } {
  variable script_folder
  upvar #0 cfg cnfg

  if { $parentCell eq "" } { set parentCell [get_bd_cells /] }
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj eq "" } { return }
  if { [get_property TYPE $parentObj] ne "hier" } { return }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  puts "  ** Instantiating V80 onboard DDR4 controller (axi_noc_mc_ddr4_0)"

  ########################################################################################################
  # External BD ports for DDR4 PHY and system clock
  ########################################################################################################
  # The CH0_DDR4_0_0 interface exposes the full DDR4 PHY: act_n, adr[16:0],
  # ba[1:0], bg[0], ck_t/_c, cke, cs_n, odt, reset_n, dm_n[8:0], dq[71:0],
  # dqs_t/_c[8:0]. Pin assignments live in v80_shell_ddr_0.xdc.
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 CH0_DDR4_0_0
  # 200 MHz LVDS system clock used by the DDRMC for calibration / refresh
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk0_0
  set_property -dict [list \
    CONFIG.FREQ_HZ {200000000} \
  ] [get_bd_intf_ports sys_clk0_0]

  ########################################################################################################
  # axi_noc_mc_ddr4_0 — DDR4 memory controller wrapper
  ########################################################################################################
  set axi_noc_mc_ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc axi_noc_mc_ddr4_0 ]
  set_property -dict [list \
    CONFIG.CONTROLLERTYPE              {DDR4_SDRAM} \
    CONFIG.MC_CHAN_REGION1             {DDR_CH1} \
    CONFIG.MC_COMPONENT_WIDTH          {x16} \
    CONFIG.MC_DATAWIDTH                {72} \
    CONFIG.MC_DM_WIDTH                 {9} \
    CONFIG.MC_DQS_WIDTH                {9} \
    CONFIG.MC_DQ_WIDTH                 {72} \
    CONFIG.MC_INIT_MEM_USING_ECC_SCRUB {true} \
    CONFIG.MC_INPUTCLK0_PERIOD         {5000} \
    CONFIG.MC_MEMORY_DEVICETYPE        {Components} \
    CONFIG.MC_MEMORY_SPEEDGRADE        {DDR4-3200AA(22-22-22)} \
    CONFIG.MC_NO_CHANNELS              {Single} \
    CONFIG.MC_RANK                     {1} \
    CONFIG.MC_ROWADDRESSWIDTH          {16} \
    CONFIG.MC_STACKHEIGHT              {1} \
    CONFIG.MC_SYSTEM_CLOCK             {Differential} \
    CONFIG.NUM_CLKS                    {0} \
    CONFIG.NUM_MC                      {1} \
    CONFIG.NUM_MCP                     {4} \
    CONFIG.NUM_MI                      {0} \
    CONFIG.NUM_NMI                     {0} \
    CONFIG.NUM_NSI                     {1} \
    CONFIG.NUM_SI                      {0} \
  ] $axi_noc_mc_ddr4_0

  # Per-NSI connection profile: 800 MB/s read+write each, 64-byte avg burst.
  # Matches AVED's bandwidth allocation; can be tuned if profiling shows headroom.
  # Single NSI/NMI path (parallel paths rejected by [BD 41-3265]).
  set_property -dict [ list \
    CONFIG.CONNECTIONS { MC_0 {read_bw {800} write_bw {800} read_avg_burst {64} write_avg_burst {64} } } \
  ] [get_bd_intf_pins /axi_noc_mc_ddr4_0/S00_INI]

  ########################################################################################################
  # Interconnect: main NoC INI master port → DDR4 controller INI slave port
  ########################################################################################################
  # axi_noc_0 must have NUM_NMI >= 1 (set in cr_pci.tcl when EN_AMC=1).
  connect_bd_intf_net [get_bd_intf_pins axi_noc_0/M00_INI] [get_bd_intf_pins axi_noc_mc_ddr4_0/S00_INI]

  # PHY pins out to the board
  connect_bd_intf_net [get_bd_intf_pins axi_noc_mc_ddr4_0/CH0_DDR4_0] [get_bd_intf_ports CH0_DDR4_0_0]
  connect_bd_intf_net [get_bd_intf_pins axi_noc_mc_ddr4_0/sys_clk0]    [get_bd_intf_ports sys_clk0_0]

  current_bd_instance $oldCurInst
}
