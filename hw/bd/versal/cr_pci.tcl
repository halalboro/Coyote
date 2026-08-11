######################################################################################
# This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
# 
# MIT Licence
# Copyright (c) 2025, Systems Group, ETH Zurich
# All rights reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
######################################################################################

# Source AMC helpers (defines cr_bd_design_aved_mgmt + cr_bd_design_ddr4_v80).
# Procs are only *called* when cnfg(en_amc) == 1 — sourcing is unconditional.
source "[file dirname [info script]]/cr_aved_mgmt.tcl" -notrace
source "[file dirname [info script]]/cr_ddr4_v80.tcl" -notrace

# Static layer
proc cr_bd_design_static { parentCell } {
  upvar #0 cfg cnfg

  set design_name design_static

  common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

  create_bd_design $design_name

  set bCheckIPsPassed 1
  ########################################################################################################
  # CHECK IPs
  ########################################################################################################
  set bCheckIPs 1
  if { $bCheckIPs == 1 } {
    set list_check_ips "\ 
      xilinx.com:ip:proc_sys_reset:5.0\
      xilinx.com:ip:util_vector_logic:2.0\
      xilinx.com:ip:versal_cips:3.4\
      xilinx.com:ip:axi_noc:1.1\
      xilinx.com:ip:smartconnect:1.0\
      xilinx.com:ip:xlconstant:1.1\
    "

    set list_ips_missing ""
    common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

    foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
        lappend list_ips_missing $ip_vlnv
      }
    }

    if { $list_ips_missing ne "" } {
      catch {common::send_msg_id "BD_TCL-115" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
    }
  }

  if { $bCheckIPsPassed != 1 } {
    common::send_msg_id "BD_TCL-1003" "WARNING" "Will not continue with creation of design due to the error(s) above."
    return 3
  }

  variable script_folder

  if { $parentCell eq "" } {
    set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
    catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
    return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
    catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
    return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

########################################################################################################
########################################################################################################
# STATIC
########################################################################################################
########################################################################################################

########################################################################################################
# Create interface ports
########################################################################################################
  # Shell config
  set axi_main [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_main ]
  set_property -dict [ list \
    CONFIG.ADDR_WIDTH {64} \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.HAS_BRESP {1} \
    CONFIG.HAS_BURST {1} \
    CONFIG.HAS_CACHE {1} \
    CONFIG.HAS_LOCK {1} \
    CONFIG.HAS_PROT {1} \
    CONFIG.HAS_QOS {1} \
    CONFIG.HAS_REGION {1} \
    CONFIG.HAS_RRESP {1} \
    CONFIG.HAS_WSTRB {1} \
    CONFIG.NUM_READ_OUTSTANDING {8} \
    CONFIG.NUM_WRITE_OUTSTANDING {8} \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.READ_WRITE_MODE {READ_WRITE} \
  ] $axi_main

  # Static config
  set axi_cnfg [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_cnfg ]
  set_property -dict [ list \
    CONFIG.ADDR_WIDTH {64} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.PROTOCOL {AXI4LITE} \
  ] $axi_cnfg

  # Debug Hub IP control
  set axi_debug_hub [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_debug_hub ]
  set_property -dict [ list \
    CONFIG.ADDR_WIDTH {64} \
    CONFIG.DATA_WIDTH {128} \
    CONFIG.PROTOCOL {AXI4} \
  ] $axi_debug_hub

  # QDMA status
  set h2c_status [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:eqdma_qsts_rtl:1.0 h2c_status ]
  set c2h_status [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:qdma_c2h_status_rtl:1.0 c2h_status ]

  # PCIe
  set pcie_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_clk ]
  set_property -dict [ list \
    CONFIG.FREQ_HZ {100000000} \
  ] $pcie_clk
  set pcie_gt [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 pcie_gt ]

  # Data streams
  set s_axis_c2h [ create_bd_intf_port -mode Slave -vlnv xilinx.com:display_eqdma:s_axis_c2h_rtl:1.0 s_axis_c2h ]
  set m_axis_h2c [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_eqdma:m_axis_h2c_rtl:1.0 m_axis_h2c ]

  # Command streams
  set dsc_bypass_h2c [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:qdma_dsc_byp_rtl:1.0 dsc_bypass_h2c ]
  set dsc_bypass_c2h [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:qdma_dsc_byp_rtl:1.0 dsc_bypass_c2h ]

  # PR descriptor
  set dsc_pr [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:qdma_dsc_byp_rtl:1.0 dsc_pr ]

  # User interrupts
  set usr_irq [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:qdma_usr_irq_rtl:1.0 usr_irq ]

########################################################################################################
# Create ports
########################################################################################################

  # Shell reset
  set xresetn [ create_bd_port -dir O -type rst xresetn ]

  # Static layer reset
  set sresetn [ create_bd_port -dir O -type rst sresetn ]

  # Reset after PR
  create_bd_port -dir I -type rst eos_resetn
  set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports eos_resetn]

  # Main clock
  set xclk [ create_bd_port -dir O -type clk xclk ]
  set_property -dict [ list \
    CONFIG.ASSOCIATED_BUSIF {m_axis_h2c:s_axis_c2h:axi_cnfg:axi_main:axi_debug_hub} \
    CONFIG.ASSOCIATED_RESET {xresetn:sresetn:eos_resetn} \
  ] $xclk

  # End-of-startup signal from PMC (asserted after parcial reconfiguration is done)
  set eos_pmc [ create_bd_port -dir O -type rst eos_pmc ]

########################################################################################################
# Create interconnect and components
########################################################################################################

  # Reset controllers
  set proc_sys_reset_s [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_s ]
  set proc_sys_reset_x [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_x ]

  # Constants
  set const_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_0 ]
  set_property CONFIG.CONST_VAL {0} $const_0

  set const_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_1 ]
  set_property CONFIG.CONST_VAL {1} $const_1

  # CIPS
  if {$cnfg(fdev) eq "v80"} {
    # If using a single Gen5x8 QDMA controller, PCIE1 must be selected to ensure compliance with PCI SIG
    # For more details, see: https://xilinx.github.io/AVED/latest/AVED%2BV80%2B-%2BCIPS%2BConfiguration.html#cpm5-basic-configuration
    if {$cnfg(pcie_gen) eq 5} {
      set versal_cips_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.4 versal_cips_0 ]
      set_property -dict [list \
        CONFIG.BOOT_MODE {Custom} \
        CONFIG.CLOCK_MODE {Custom} \
        CONFIG.CPM_CONFIG { \
          CPM_PCIE0_MODES {None} \
          CPM_PCIE1_DMA_INTF {AXI_MM_and_AXI_Stream} \
          CPM_PCIE1_DSC_BYPASS_RD {1} \
          CPM_PCIE1_DSC_BYPASS_WR {1} \
          CPM_PCIE1_LANE_REVERSAL_EN {0} \
          CPM_PCIE1_MODES {DMA} \
          CPM_PCIE1_MODE_SELECTION {Advanced} \
          CPM_PCIE1_PF0_BAR0_QDMA_64BIT {1} \
          CPM_PCIE1_PF0_BAR0_QDMA_AXCACHE {0} \
          CPM_PCIE1_PF0_BAR0_QDMA_PREFETCHABLE {1} \
          CPM_PCIE1_PF0_BAR0_QDMA_SCALE {Megabytes} \
          CPM_PCIE1_PF0_BAR0_QDMA_SIZE {1} \
          CPM_PCIE1_PF0_BAR0_QDMA_STEERING {CPM_PCIE_NOC_0} \
          CPM_PCIE1_PF0_BAR0_QDMA_TYPE {AXI_Bridge_Master} \
          CPM_PCIE1_PF0_BAR1_QDMA_AXCACHE {0} \
          CPM_PCIE1_PF0_BAR2_QDMA_AXCACHE {0} \
          CPM_PCIE1_PF0_BAR2_QDMA_64BIT {1} \
          CPM_PCIE1_PF0_BAR2_QDMA_ENABLED {1} \
          CPM_PCIE1_PF0_BAR2_QDMA_TYPE {DMA} \
          CPM_PCIE1_PF0_BAR3_QDMA_AXCACHE {0} \
          CPM_PCIE1_PF0_BAR4_QDMA_64BIT {1} \
          CPM_PCIE1_PF0_BAR4_QDMA_AXCACHE {0} \
          CPM_PCIE1_PF0_BAR4_QDMA_ENABLED {1} \
          CPM_PCIE1_PF0_BAR4_QDMA_PREFETCHABLE {1} \
          CPM_PCIE1_PF0_BAR4_QDMA_SCALE {Megabytes} \
          CPM_PCIE1_PF0_BAR4_QDMA_SIZE {256} \
          CPM_PCIE1_PF0_BAR4_QDMA_STEERING {CPM_PCIE_NOC_0} \
          CPM_PCIE1_PF0_BAR5_QDMA_AXCACHE {0} \
          CPM_PCIE1_PF0_MSIX_CAP_TABLE_SIZE {0x1F} \
          CPM_PCIE1_PF0_PCIEBAR2AXIBAR_QDMA_0 {0x020100000000} \
          CPM_PCIE1_PF0_PCIEBAR2AXIBAR_QDMA_2 {0x0} \
          CPM_PCIE1_PF0_PCIEBAR2AXIBAR_QDMA_4 {0x020800000000} \
          CPM_PCIE1_PL_LINK_CAP_MAX_LINK_WIDTH {X8} \
          CPM_PCIE1_MAX_LINK_SPEED {32.0_GT/s} \
          CPM_PCIE1_REF_CLK_FREQ {100_MHz} \
          PS_USE_PS_NOC_PCI_1 {1} \
        } \
        CONFIG.DEVICE_INTEGRITY_MODE {Custom} \
        CONFIG.PS_PMC_CONFIG { \
          BOOT_MODE {Custom} \
          CLOCK_MODE {Custom} \
          DDR_MEMORY_MODE {Custom} \
          DESIGN_MODE {1} \
          DEVICE_INTEGRITY_MODE {Custom} \
          IO_CONFIG_MODE {Custom} \
          PCIE_APERTURES_DUAL_ENABLE {0} \
          PCIE_APERTURES_SINGLE_ENABLE {1} \
          PMC_BANK_1_IO_STANDARD {LVCMOS3.3} \
          PMC_CRP_OSPI_REF_CTRL_FREQMHZ {200} \
          PMC_CRP_PL0_REF_CTRL_FREQMHZ {33.3333333} \
          PMC_CRP_PL1_REF_CTRL_FREQMHZ {33.3333333} \
          PMC_CRP_PL2_REF_CTRL_FREQMHZ {250} \
          PMC_GLITCH_CONFIG {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.88}} \
          PMC_GLITCH_CONFIG_1 {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.88}} \
          PMC_GLITCH_CONFIG_2 {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.88}} \
          PMC_GPIO_EMIO_PERIPHERAL_ENABLE {0} \
          PMC_MIO11 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO12 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO13 {{AUX_IO 0} {DIRECTION inout} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
          PMC_MIO17 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO26 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO27 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO28 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO29 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO30 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO31 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO32 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO33 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO34 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO35 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO36 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO37 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO38 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO39 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO40 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO41 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO42 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO43 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO44 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO48 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO49 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO50 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO51 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO_EN_FOR_PL_PCIE {0} \
          PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
          PMC_QSPI_PERIPHERAL_ENABLE {0} \
          PMC_REF_CLK_FREQMHZ {33.333333} \
          PMC_SD0 {{CD_ENABLE 0} {CD_IO {PMC_MIO 24}} {POW_ENABLE 0} {POW_IO {PMC_MIO 17}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 17}} {WP_ENABLE 0} {WP_IO {PMC_MIO 25}}} \
          PMC_SD0_DATA_TRANSFER_MODE {8Bit} \
          PMC_SD0_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x00} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x1E} {CLK_50_DDR_OTAP_DLY 0x5} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x5} {ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
          PMC_SD0_SLOT_TYPE {eMMC} \
          PMC_USE_NOC_PMC_AXI0 {1} \
          PMC_USE_PMC_NOC_AXI0 {1} \
          PS_BANK_2_IO_STANDARD {LVCMOS3.3} \
          PS_BOARD_INTERFACE {Custom} \
          PS_CRL_CPM_TOPSW_REF_CTRL_FREQMHZ {1000} \
          PS_GEN_IPI0_ENABLE {0} \
          PS_GEN_IPI1_ENABLE {0} \
          PS_GEN_IPI2_ENABLE {0} \
          PS_GEN_IPI3_ENABLE {1} \
          PS_GEN_IPI3_MASTER {R5_0} \
          PS_GEN_IPI4_ENABLE {1} \
          PS_GEN_IPI4_MASTER {R5_0} \
          PS_GEN_IPI5_ENABLE {1} \
          PS_GEN_IPI5_MASTER {R5_1} \
          PS_GEN_IPI6_ENABLE {1} \
          PS_GEN_IPI6_MASTER {R5_1} \
          PS_GPIO_EMIO_PERIPHERAL_ENABLE {0} \
          PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 2 .. 3}}} \
          PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 1}}} \
          PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 0} {CH11 0} {CH12 0} {CH13 0} {CH14 0} {CH15 0} {CH2 0} {CH3 0} {CH4 0} {CH5 0} {CH6 0} {CH7 0} {CH8 0} {CH9 0}} \
          PS_KAT_ENABLE {0} \
          PS_KAT_ENABLE_1 {0} \
          PS_KAT_ENABLE_2 {0} \
          PS_MIO10 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO11 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO12 {{AUX_IO 0} {DIRECTION inout} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
          PS_MIO13 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO14 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO18 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO19 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO22 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO23 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO24 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO25 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO4 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO5 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO6 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO7 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO8 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
          PS_MIO9 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 1} {SLEW slow} {USAGE Reserved}} \
          PS_M_AXI_FPD_DATA_WIDTH {64} \
          PS_M_AXI_LPD_DATA_WIDTH {32} \
          PS_NUM_FABRIC_RESETS {1} \
          PS_PCIE1_PERIPHERAL_ENABLE {0} \
          PS_PCIE2_PERIPHERAL_ENABLE {1} \
          PS_PCIE_EP_RESET1_IO {PMC_MIO 24} \
          PS_PCIE_EP_RESET2_IO {PMC_MIO 25} \
          PS_PCIE_RESET {{ENABLE 1}} \
          PS_PL_CONNECTIVITY_MODE {Custom} \
          PS_SPI0 {{GRP_SS0_ENABLE 1} {GRP_SS0_IO {PS_MIO 15}} {GRP_SS1_ENABLE 0} {GRP_SS1_IO {PMC_MIO 14}} {GRP_SS2_ENABLE 0} {GRP_SS2_IO {PMC_MIO 13}} {PERIPHERAL_ENABLE 1} {PERIPHERAL_IO {PS_MIO 12 .. 17}}} \
          PS_SPI1 {{GRP_SS0_ENABLE 0} {GRP_SS0_IO {PS_MIO 9}} {GRP_SS1_ENABLE 0} {GRP_SS1_IO {PS_MIO 8}} {GRP_SS2_ENABLE 0} {GRP_SS2_IO {PS_MIO 7}} {PERIPHERAL_ENABLE 0} {PERIPHERAL_IO {PS_MIO 6 .. 11}}} \
          PS_TTC0_PERIPHERAL_ENABLE {1} \
          PS_TTC1_PERIPHERAL_ENABLE {1} \
          PS_TTC2_PERIPHERAL_ENABLE {1} \
          PS_TTC3_PERIPHERAL_ENABLE {1} \
          PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 8 .. 9}}} \
          PS_UART1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 20 .. 21}}} \
          PS_USE_FPD_CCI_NOC {0} \
          PS_USE_M_AXI_FPD {1} \
          PS_USE_M_AXI_LPD {1} \
          PS_USE_NOC_LPD_AXI0 {1} \
          PS_USE_PMCPL_CLK0 {1} \
          PS_USE_PMCPL_CLK1 {1} \
          PS_USE_PMCPL_CLK2 {1} \
          PS_USE_S_AXI_LPD {0} \
          PS_USE_STARTUP {1} \
          SMON_ALARMS {Set_Alarms_On} \
          SMON_ENABLE_TEMP_AVERAGING {0} \
          SMON_MEAS100 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_500} {SUPPLY_NUM 9}} \
          SMON_MEAS101 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_501} {SUPPLY_NUM 10}} \
          SMON_MEAS102 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_502} {SUPPLY_NUM 11}} \
          SMON_MEAS103 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_503} {SUPPLY_NUM 12}} \
          SMON_MEAS104 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_700} {SUPPLY_NUM 13}} \
          SMON_MEAS105 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_701} {SUPPLY_NUM 14}} \
          SMON_MEAS106 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_702} {SUPPLY_NUM 15}} \
          SMON_MEAS118 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PMC} {SUPPLY_NUM 0}} \
          SMON_MEAS119 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PSFP} {SUPPLY_NUM 1}} \
          SMON_MEAS120 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PSLP} {SUPPLY_NUM 2}} \
          SMON_MEAS121 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_RAM} {SUPPLY_NUM 3}} \
          SMON_MEAS122 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_SOC} {SUPPLY_NUM 4}} \
          SMON_MEAS47 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_104} {SUPPLY_NUM 20}} \
          SMON_MEAS48 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_105} {SUPPLY_NUM 21}} \
          SMON_MEAS64 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_104} {SUPPLY_NUM 18}} \
          SMON_MEAS65 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_105} {SUPPLY_NUM 19}} \
          SMON_MEAS81 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_104} {SUPPLY_NUM 22}} \
          SMON_MEAS82 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_105} {SUPPLY_NUM 23}} \
          SMON_MEAS96 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX} {SUPPLY_NUM 6}} \
          SMON_MEAS97 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX_PMC} {SUPPLY_NUM 7}} \
          SMON_MEAS98 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX_SMON} {SUPPLY_NUM 8}} \
          SMON_MEAS99 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCINT} {SUPPLY_NUM 5}} \
          SMON_OT {{THRESHOLD_LOWER -25} {THRESHOLD_UPPER 125}} \
          SMON_TEMP_AVERAGING_SAMPLES {0} \
          SMON_USER_TEMP {{THRESHOLD_LOWER 0} {THRESHOLD_UPPER 125} {USER_ALARM_TYPE window}} \
          SMON_VOLTAGE_AVERAGING_SAMPLES {8} \
        } \
      ] $versal_cips_0
    } elseif {$cnfg(pcie_gen) eq 4} {
      # And, if using a Gen4x16 QDMA controller, PCIE0 must be selected
      set versal_cips_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips:3.4 versal_cips_0 ]
      set_property -dict [list \
        CONFIG.BOOT_MODE {Custom} \
        CONFIG.CLOCK_MODE {Custom} \
        CONFIG.CPM_CONFIG { \
          CPM_PCIE1_MODES {None} \
          CPM_PCIE0_DMA_INTF {AXI_MM_and_AXI_Stream} \
          CPM_PCIE0_DSC_BYPASS_RD {1} \
          CPM_PCIE0_DSC_BYPASS_WR {1} \
          CPM_PCIE0_LANE_REVERSAL_EN {0} \
          CPM_PCIE0_MODES {DMA} \
          CPM_PCIE0_MODE_SELECTION {Advanced} \
          CPM_PCIE0_PF0_BAR0_QDMA_64BIT {1} \
          CPM_PCIE0_PF0_BAR0_QDMA_AXCACHE {0} \
          CPM_PCIE0_PF0_BAR0_QDMA_PREFETCHABLE {1} \
          CPM_PCIE0_PF0_BAR0_QDMA_SCALE {Megabytes} \
          CPM_PCIE0_PF0_BAR0_QDMA_SIZE {1} \
          CPM_PCIE0_PF0_BAR0_QDMA_STEERING {CPM_PCIE_NOC_0} \
          CPM_PCIE0_PF0_BAR0_QDMA_TYPE {AXI_Bridge_Master} \
          CPM_PCIE0_PF0_BAR1_QDMA_AXCACHE {0} \
          CPM_PCIE0_PF0_BAR2_QDMA_AXCACHE {0} \
          CPM_PCIE0_PF0_BAR2_QDMA_64BIT {1} \
          CPM_PCIE0_PF0_BAR2_QDMA_ENABLED {1} \
          CPM_PCIE0_PF0_BAR2_QDMA_TYPE {DMA} \
          CPM_PCIE0_PF0_BAR3_QDMA_AXCACHE {0} \
          CPM_PCIE0_PF0_BAR4_QDMA_64BIT {1} \
          CPM_PCIE0_PF0_BAR4_QDMA_AXCACHE {0} \
          CPM_PCIE0_PF0_BAR4_QDMA_ENABLED {1} \
          CPM_PCIE0_PF0_BAR4_QDMA_PREFETCHABLE {1} \
          CPM_PCIE0_PF0_BAR4_QDMA_SCALE {Megabytes} \
          CPM_PCIE0_PF0_BAR4_QDMA_SIZE {256} \
          CPM_PCIE0_PF0_BAR4_QDMA_STEERING {CPM_PCIE_NOC_0} \
          CPM_PCIE0_PF0_BAR5_QDMA_AXCACHE {0} \
          CPM_PCIE0_PF0_MSIX_CAP_TABLE_SIZE {0x1F} \
          CPM_PCIE0_PF0_PCIEBAR2AXIBAR_QDMA_0 {0x020100000000} \
          CPM_PCIE0_PF0_PCIEBAR2AXIBAR_QDMA_2 {0x0} \
          CPM_PCIE0_PF0_PCIEBAR2AXIBAR_QDMA_4 {0x020800000000} \
          CPM_PCIE0_PL_LINK_CAP_MAX_LINK_WIDTH {X16} \
          CPM_PCIE0_MAX_LINK_SPEED {16.0_GT/s} \
          CPM_PCIE0_REF_CLK_FREQ {100_MHz} \
          PS_USE_PS_NOC_PCI_1 {1} \
        } \
        CONFIG.DEVICE_INTEGRITY_MODE {Custom} \
        CONFIG.PS_PMC_CONFIG { \
          BOOT_MODE {Custom} \
          CLOCK_MODE {Custom} \
          DDR_MEMORY_MODE {Custom} \
          DESIGN_MODE {1} \
          DEVICE_INTEGRITY_MODE {Custom} \
          IO_CONFIG_MODE {Custom} \
          PCIE_APERTURES_DUAL_ENABLE {0} \
          PCIE_APERTURES_SINGLE_ENABLE {1} \
          PMC_BANK_1_IO_STANDARD {LVCMOS3.3} \
          PMC_CRP_OSPI_REF_CTRL_FREQMHZ {200} \
          PMC_CRP_PL0_REF_CTRL_FREQMHZ {33.3333333} \
          PMC_CRP_PL1_REF_CTRL_FREQMHZ {33.3333333} \
          PMC_CRP_PL2_REF_CTRL_FREQMHZ {250} \
          PMC_GLITCH_CONFIG {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.88}} \
          PMC_GLITCH_CONFIG_1 {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.88}} \
          PMC_GLITCH_CONFIG_2 {{DEPTH_SENSITIVITY 1} {MIN_PULSE_WIDTH 0.5} {TYPE CUSTOM} {VCC_PMC_VALUE 0.88}} \
          PMC_GPIO_EMIO_PERIPHERAL_ENABLE {0} \
          PMC_MIO11 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO12 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO13 {{AUX_IO 0} {DIRECTION inout} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
          PMC_MIO17 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO26 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO27 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO28 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO29 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO30 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO31 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO32 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO33 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO34 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO35 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO36 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO37 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO38 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO39 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO40 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO41 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO42 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO43 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO44 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO48 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO49 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO50 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO51 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PMC_MIO_EN_FOR_PL_PCIE {0} \
          PMC_OSPI_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
          PMC_QSPI_PERIPHERAL_ENABLE {0} \
          PMC_REF_CLK_FREQMHZ {33.333333} \
          PMC_SD0 {{CD_ENABLE 0} {CD_IO {PMC_MIO 24}} {POW_ENABLE 0} {POW_IO {PMC_MIO 17}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 17}} {WP_ENABLE 0} {WP_IO {PMC_MIO 25}}} \
          PMC_SD0_DATA_TRANSFER_MODE {8Bit} \
          PMC_SD0_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x00} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x1E} {CLK_50_DDR_OTAP_DLY 0x5} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x5} {ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
          PMC_SD0_SLOT_TYPE {eMMC} \
          PMC_USE_NOC_PMC_AXI0 {1} \
          PMC_USE_PMC_NOC_AXI0 {1} \
          PS_BANK_2_IO_STANDARD {LVCMOS3.3} \
          PS_BOARD_INTERFACE {Custom} \
          PS_CRL_CPM_TOPSW_REF_CTRL_FREQMHZ {1000} \
          PS_GEN_IPI0_ENABLE {0} \
          PS_GEN_IPI1_ENABLE {0} \
          PS_GEN_IPI2_ENABLE {0} \
          PS_GEN_IPI3_ENABLE {1} \
          PS_GEN_IPI3_MASTER {R5_0} \
          PS_GEN_IPI4_ENABLE {1} \
          PS_GEN_IPI4_MASTER {R5_0} \
          PS_GEN_IPI5_ENABLE {1} \
          PS_GEN_IPI5_MASTER {R5_1} \
          PS_GEN_IPI6_ENABLE {1} \
          PS_GEN_IPI6_MASTER {R5_1} \
          PS_GPIO_EMIO_PERIPHERAL_ENABLE {0} \
          PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 2 .. 3}}} \
          PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 1}}} \
          PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 0} {CH11 0} {CH12 0} {CH13 0} {CH14 0} {CH15 0} {CH2 0} {CH3 0} {CH4 0} {CH5 0} {CH6 0} {CH7 0} {CH8 0} {CH9 0}} \
          PS_KAT_ENABLE {0} \
          PS_KAT_ENABLE_1 {0} \
          PS_KAT_ENABLE_2 {0} \
          PS_MIO10 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO11 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO12 {{AUX_IO 0} {DIRECTION inout} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
          PS_MIO13 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO14 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO18 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO19 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO22 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO23 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO24 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO25 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO4 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO5 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO6 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO7 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
          PS_MIO8 {{AUX_IO 0} {DIRECTION in} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE Reserved}} \
          PS_MIO9 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA default} {PULL pullup} {SCHMITT 1} {SLEW slow} {USAGE Reserved}} \
          PS_M_AXI_FPD_DATA_WIDTH {64} \
          PS_M_AXI_LPD_DATA_WIDTH {32} \
          PS_NUM_FABRIC_RESETS {1} \
          PS_PCIE1_PERIPHERAL_ENABLE {1} \
          PS_PCIE2_PERIPHERAL_ENABLE {0} \
          PS_PCIE_EP_RESET1_IO {PMC_MIO 24} \
          PS_PCIE_EP_RESET2_IO {PMC_MIO 25} \
          PS_PCIE_RESET {{ENABLE 1}} \
          PS_PL_CONNECTIVITY_MODE {Custom} \
          PS_SPI0 {{GRP_SS0_ENABLE 1} {GRP_SS0_IO {PS_MIO 15}} {GRP_SS1_ENABLE 0} {GRP_SS1_IO {PMC_MIO 14}} {GRP_SS2_ENABLE 0} {GRP_SS2_IO {PMC_MIO 13}} {PERIPHERAL_ENABLE 1} {PERIPHERAL_IO {PS_MIO 12 .. 17}}} \
          PS_SPI1 {{GRP_SS0_ENABLE 0} {GRP_SS0_IO {PS_MIO 9}} {GRP_SS1_ENABLE 0} {GRP_SS1_IO {PS_MIO 8}} {GRP_SS2_ENABLE 0} {GRP_SS2_IO {PS_MIO 7}} {PERIPHERAL_ENABLE 0} {PERIPHERAL_IO {PS_MIO 6 .. 11}}} \
          PS_TTC0_PERIPHERAL_ENABLE {1} \
          PS_TTC1_PERIPHERAL_ENABLE {1} \
          PS_TTC2_PERIPHERAL_ENABLE {1} \
          PS_TTC3_PERIPHERAL_ENABLE {1} \
          PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 8 .. 9}}} \
          PS_UART1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 20 .. 21}}} \
          PS_USE_FPD_CCI_NOC {0} \
          PS_USE_M_AXI_FPD {1} \
          PS_USE_M_AXI_LPD {1} \
          PS_USE_NOC_LPD_AXI0 {1} \
          PS_USE_PMCPL_CLK0 {1} \
          PS_USE_PMCPL_CLK1 {1} \
          PS_USE_PMCPL_CLK2 {1} \
          PS_USE_S_AXI_LPD {0} \
          PS_USE_STARTUP {1} \
          SMON_ALARMS {Set_Alarms_On} \
          SMON_ENABLE_TEMP_AVERAGING {0} \
          SMON_MEAS100 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_500} {SUPPLY_NUM 9}} \
          SMON_MEAS101 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_501} {SUPPLY_NUM 10}} \
          SMON_MEAS102 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_502} {SUPPLY_NUM 11}} \
          SMON_MEAS103 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 4.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {4 V unipolar}} {NAME VCCO_503} {SUPPLY_NUM 12}} \
          SMON_MEAS104 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_700} {SUPPLY_NUM 13}} \
          SMON_MEAS105 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_701} {SUPPLY_NUM 14}} \
          SMON_MEAS106 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCO_702} {SUPPLY_NUM 15}} \
          SMON_MEAS118 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PMC} {SUPPLY_NUM 0}} \
          SMON_MEAS119 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PSFP} {SUPPLY_NUM 1}} \
          SMON_MEAS120 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_PSLP} {SUPPLY_NUM 2}} \
          SMON_MEAS121 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_RAM} {SUPPLY_NUM 3}} \
          SMON_MEAS122 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCC_SOC} {SUPPLY_NUM 4}} \
          SMON_MEAS47 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_104} {SUPPLY_NUM 20}} \
          SMON_MEAS48 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCCAUX_105} {SUPPLY_NUM 21}} \
          SMON_MEAS64 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_104} {SUPPLY_NUM 18}} \
          SMON_MEAS65 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVCC_105} {SUPPLY_NUM 19}} \
          SMON_MEAS81 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_104} {SUPPLY_NUM 22}} \
          SMON_MEAS82 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME GTYP_AVTT_105} {SUPPLY_NUM 23}} \
          SMON_MEAS96 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX} {SUPPLY_NUM 6}} \
          SMON_MEAS97 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX_PMC} {SUPPLY_NUM 7}} \
          SMON_MEAS98 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCAUX_SMON} {SUPPLY_NUM 8}} \
          SMON_MEAS99 {{ALARM_ENABLE 1} {ALARM_LOWER 0.00} {ALARM_UPPER 2.00} {AVERAGE_EN 0} {ENABLE 1} {MODE {2 V unipolar}} {NAME VCCINT} {SUPPLY_NUM 5}} \
          SMON_OT {{THRESHOLD_LOWER -25} {THRESHOLD_UPPER 125}} \
          SMON_TEMP_AVERAGING_SAMPLES {0} \
          SMON_USER_TEMP {{THRESHOLD_LOWER 0} {THRESHOLD_UPPER 125} {USER_ALARM_TYPE window}} \
          SMON_VOLTAGE_AVERAGING_SAMPLES {8} \
        } \
      ] $versal_cips_0
    } else {
      puts "ERROR: Unsupported PCIe configuration: Gen$cnfg(pcie_gen). Supported configurations for V80 are Gen4x16 and Gen5x8."
      exit 1
    }   
  } else {
    puts "ERROR: Unsupported FPGA part: $cnfg(fdev)"
    exit 1
  }

  # Coyote AMC bringup: mark the PS/PMC configuration as user-applied.
  #
  # Without this flag the CIPS treats PS_PMC_CONFIG as a minimal, PL-oriented
  # setup and emits a subsystem/PMC CDO that does NOT grant the R5 TCM banks to
  # an R5-0 subsystem. Booting amc.elf on core=r5-0 then fails at partition load
  # with PLM Error Major 0x347 (XLOADER_ERR_PM_DEV_TCM_0_A) and DONE stays LOW.
  #
  # AVED's reference V80 design (hw/amd_v80_gen5x8_25.1) sets exactly this sibling
  # property; it is the only CIPS difference vs. the stock Coyote config (their
  # PS_PMC_CONFIG key set is otherwise a subset of ours). Setting it makes CIPS
  # finalize the R5-0 subsystem with TCM_0_A/B ownership in the generated CDO.
  #
  # AMC-only (V80): leave non-AMC builds on the stock CIPS behaviour.
  if {$cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1} {
    set_property -dict [list CONFIG.PS_PMC_CONFIG_APPLIED {1}] $versal_cips_0
  }

  # AXI NoC
  # The NoC is used to route AXI-MM interfaces from the QDMA to the shell
  # Additionally, it will perform clock-domain crossing, reducing the frequency from 1000 MHz to shell frequency
  set axi_noc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_noc:1.1 axi_noc_0 ]
  # Base config: 3 NoC AXI slaves (PCIe shell ctrl, PCIe DMA data, PMC debug),
  # 4 NoC AXI masters (mgmt SC, shell ctrl SC, NOC_PMC_AXI, debug hub), 5 clocks.
  # When EN_AMC=1 on V80, this gets bumped to also route LPD↔DDR4 — see below.
  set _noc_num_si   3
  set _noc_num_clks 5
  set _noc_num_nmi  0
  if {$cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1} {
    # +S03 for CIPS LPD_AXI_NOC_0 (R5 master into the NoC)
    # +M00_INI for routing to axi_noc_mc_ddr4_0 (single path: Versal allows
    #   at most one S->MC connection per DDR controller, [BD 41-3265])
    # +aclk5 for the LPD slave domain (pl0_ref_clk @ 100 MHz)
    set _noc_num_si   4
    set _noc_num_clks 6
    set _noc_num_nmi  1
  }
  set_property -dict [list \
    CONFIG.MI_SIDEBAND_PINS {0} \
    CONFIG.NUM_CLKS         $_noc_num_clks \
    CONFIG.NUM_HBM_BLI      {0} \
    CONFIG.NUM_MI           {4} \
    CONFIG.NUM_SI           $_noc_num_si \
    CONFIG.NUM_NMI          $_noc_num_nmi \
    CONFIG.SI_SIDEBAND_PINS {} \
  ] $axi_noc_0

  set_property -dict [ list \
    CONFIG.APERTURES {{0x201_0000_0000 1G}} \
    CONFIG.CATEGORY {pl} \
  ] [get_bd_intf_pins /axi_noc_0/M00_AXI]

  set_property -dict [ list \
    CONFIG.APERTURES {{0x208_0000_0000 1G}} \
    CONFIG.CATEGORY {pl} \
  ] [get_bd_intf_pins /axi_noc_0/M01_AXI]

  set_property -dict [ list \
    CONFIG.DATA_WIDTH {128} \
    CONFIG.AWUSER_WIDTH {0} \
    CONFIG.ARUSER_WIDTH {0} \
    CONFIG.CATEGORY {ps_pmc} \
  ] [get_bd_intf_pins /axi_noc_0/M02_AXI]

  set_property -dict [ list \
    CONFIG.APERTURES {{0x202_4000_0000 1G}} \
    CONFIG.DATA_WIDTH {128} \
    CONFIG.AWUSER_WIDTH {0} \
    CONFIG.ARUSER_WIDTH {0} \
    CONFIG.CATEGORY {pl} \
  ] [get_bd_intf_pins /axi_noc_0/M03_AXI]

  # CPM_PCIE_NOC_0 is used for shell and static layer registers
  set_property -dict [ list \
    CONFIG.CONNECTIONS [expr {($cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1) ? \
        {M00_AXI {read_bw {8} write_bw {8} read_avg_burst {4} write_avg_burst {4}} M01_AXI {read_bw {8} write_bw {8} read_avg_burst {4} write_avg_burst {4}} M00_INI {read_bw {200} write_bw {200} read_avg_burst {16} write_avg_burst {16}}} : \
        {M00_AXI {read_bw {8} write_bw {8} read_avg_burst {4} write_avg_burst {4}} M01_AXI {read_bw {8} write_bw {8} read_avg_burst {4} write_avg_burst {4}}}}] \
    CONFIG.DEST_IDS [expr {($cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1) ? \
        {M01_AXI:0x0:M00_AXI:0x40:M00_INI:0x140} : \
        {M01_AXI:0x0:M00_AXI:0x40}}] \
    CONFIG.REMAPS [expr {($cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1) ? \
        {M00_INI {{0x2080A000000 0x00000000 0x02000000}}} : \
        {}}] \
    CONFIG.NOC_PARAMS {} \
    CONFIG.CATEGORY {ps_pcie} \
  ] [get_bd_intf_pins /axi_noc_0/S00_AXI]

  # CPM_PCIE_NOC_1 is used for QDMA MM data transfers
  set_property -dict [ list \
    CONFIG.CONNECTIONS {M02_AXI {read_bw {6400} write_bw {6400} read_avg_burst {64} write_avg_burst {64}}} \
    CONFIG.DEST_IDS {M02_AXI:0x80} \
    CONFIG.NOC_PARAMS {} \
    CONFIG.CATEGORY {ps_pcie} \
  ] [get_bd_intf_pins /axi_noc_0/S01_AXI]

  # PMC_NOC is used for configuring the Debug Hub IP (which sets up ILAs, VIOs etc.)
  set_property -dict [ list \
    CONFIG.CONNECTIONS {M03_AXI {read_bw {1500} write_bw {1500} read_avg_burst {4} write_avg_burst {4}}} \
    CONFIG.DEST_IDS {M03_AXI:0x120} \
    CONFIG.NOC_PARAMS {} \
    CONFIG.CATEGORY {ps_pmc} \
  ] [get_bd_intf_pins /axi_noc_0/S02_AXI]

  set_property -dict [ list \
    CONFIG.ASSOCIATED_BUSIF {S00_AXI} \
  ] [get_bd_pins /axi_noc_0/aclk0]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S01_AXI} \
  ] [get_bd_pins /axi_noc_0/aclk1]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S02_AXI} \
  ] [get_bd_pins /axi_noc_0/aclk2]

  set_property -dict [ list \
    CONFIG.ASSOCIATED_BUSIF {M00_AXI:M01_AXI:M03_AXI} \
  ] [get_bd_pins /axi_noc_0/aclk3]

  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {M02_AXI} \
  ] [get_bd_pins /axi_noc_0/aclk4]

  ########################################################################################################
  # AMC additions: S03 = CIPS LPD master into NoC; M00_INI = single route to DDR4 MC
  ########################################################################################################
  if {$cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1} {
    # S03_AXI: CIPS LPD_NOC_AXI_0 — R5 master traffic into the NoC. Single
    # path to M00_INI (DDR4 ctrl S00_INI); a second path through M01_INI
    # is rejected by validate_bd_design ([BD 41-3265] — max 1 NoC slave port
    # per DDR MC) because we only have NUM_MC=1 on axi_noc_mc_ddr4_0.
    set_property -dict [ list \
      CONFIG.CONNECTIONS {M00_INI {read_bw {800} write_bw {800} read_avg_burst {16} write_avg_burst {16}}} \
      CONFIG.DEST_IDS {M00_INI:0xC0} \
      CONFIG.NOC_PARAMS {} \
      CONFIG.CATEGORY {ps_rpu} \
    ] [get_bd_intf_pins /axi_noc_0/S03_AXI]

    # S02_AXI (PMC master): the PLM DMA-loads amc.elf during boot, and amc.elf's
    # second load segment targets 0x4000_0000 (DDR4, see lscript.ld). The PMC
    # therefore needs a NoC route to the DDR4 controller, not just to the debug
    # hub. Without it the PLM's partition-load DMA to 0x4000_0000 has no route
    # and the boot hangs ("PLM stalled", DONE LOW) — the R5's own runtime path
    # (S03/LPD) is not enough, because loading happens on the PMC master.
    # Add M00_INI alongside the existing M03_AXI (debug hub) connection. Both
    # S02 (PMC) and S03 (LPD) share the single M00_INI -> DDR4/S00_INI path
    # (dest id 0xC0), which stays within the "1 slave port per DDR MC" rule.
    set_property -dict [ list \
      CONFIG.CONNECTIONS {M03_AXI {read_bw {1500} write_bw {1500} read_avg_burst {4} write_avg_burst {4}} M00_INI {read_bw {200} write_bw {200} read_avg_burst {16} write_avg_burst {16}}} \
      CONFIG.DEST_IDS {M03_AXI:0x120 M00_INI:0xC0} \
      CONFIG.NOC_PARAMS {} \
      CONFIG.CATEGORY {ps_pmc} \
    ] [get_bd_intf_pins /axi_noc_0/S02_AXI]

    # M00_INI: INI master port out to DDR4 MC. Aperture is in the POST-REMAP
    # (DDR4-local) address space, so 4G at 0 covers all of DDR4.
    set_property -dict [ list \
      CONFIG.APERTURES {{0x0_0000_0000 4G}} \
      CONFIG.CATEGORY {pl_to_ddrmc} \
    ] [get_bd_intf_pins /axi_noc_0/M00_INI]

    # aclk5: LPD slave clock domain (pl0_ref_clk, 100 MHz)
    set_property -dict [ list \
      CONFIG.ASSOCIATED_BUSIF {S03_AXI} \
    ] [get_bd_pins /axi_noc_0/aclk5]
  }

  # AXI SmartSwitch, connecting the NoC outputs to BD output interfaces
  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property CONFIG.NUM_SI {1} $smartconnect_0
  set_property CONFIG.ADVANCED_PROPERTIES {__experimental_features__ {disable_low_area_mode 1} __view__ {functional {S00_Entry {SUPPORTS_WRAP 1 SUPPORTS_NARROW_BURST 1}}}} $smartconnect_0
  
  # smartconnect_1 has two slave interfaces: S00 from PCIe (CPM_PCIE_NOC_0)
  # and S01 from the APU/R5 via M_AXI_FPD. Both are merged into a single
  # axi_main master that feeds the shell's vFPGA control fabric.
  set smartconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_1 ]
  set_property CONFIG.NUM_SI {2} $smartconnect_1
  set_property CONFIG.NUM_CLKS {1} $smartconnect_1
  set_property CONFIG.ADVANCED_PROPERTIES {__experimental_features__ {disable_low_area_mode 1} __view__ {functional {S00_Entry {SUPPORTS_WRAP 1 SUPPORTS_NARROW_BURST 1}}}} $smartconnect_1

  # Main clock gen
  create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard:1.0 clk_wiz_0
  set cmd "set_property -dict \[list \
    CONFIG.CLKOUT_DRIVES {BUFG} \
    CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {[expr {$cnfg(sclk_f)}]} \
    CONFIG.CLKOUT_USED {true} \
    CONFIG.PRIM_SOURCE {Global_Buffer} \
  ] \[get_bd_cells clk_wiz_0]"
  eval $cmd

########################################################################################################
# Create interface connections
########################################################################################################
  if {$cnfg(pcie_gen) eq 5} {
    # QDMA
    connect_bd_intf_net [get_bd_intf_ports pcie_clk] [get_bd_intf_pins versal_cips_0/gt_refclk1]
    connect_bd_intf_net [get_bd_intf_ports pcie_gt] [get_bd_intf_pins versal_cips_0/PCIE1_GT] 

    # Descriptor status
    connect_bd_intf_net [get_bd_intf_ports c2h_status] [get_bd_intf_pins versal_cips_0/dma1_axis_c2h_status]
    connect_bd_intf_net [get_bd_intf_ports h2c_status] [get_bd_intf_pins versal_cips_0/dma1_qsts_out]

    # Data lines
    connect_bd_intf_net [get_bd_intf_ports s_axis_c2h] [get_bd_intf_pins versal_cips_0/dma1_s_axis_c2h]
    connect_bd_intf_net [get_bd_intf_ports m_axis_h2c] [get_bd_intf_pins versal_cips_0/dma1_m_axis_h2c]

    # Command lines
    connect_bd_intf_net [get_bd_intf_ports dsc_bypass_c2h] [get_bd_intf_pins versal_cips_0/dma1_c2h_byp_in_st_csh]
    connect_bd_intf_net [get_bd_intf_ports dsc_bypass_h2c] [get_bd_intf_pins versal_cips_0/dma1_h2c_byp_in_st]

    # PR
    connect_bd_intf_net [get_bd_intf_ports dsc_pr] [get_bd_intf_pins versal_cips_0/dma1_h2c_byp_in_mm_0]

    # Interrupts
    connect_bd_intf_net [get_bd_intf_ports usr_irq] [get_bd_intf_pins versal_cips_0/dma1_usr_irq]
  
  } elseif {$cnfg(pcie_gen) eq 4} {
    # QDMA
    connect_bd_intf_net [get_bd_intf_ports pcie_clk] [get_bd_intf_pins versal_cips_0/gt_refclk0]
    connect_bd_intf_net [get_bd_intf_ports pcie_gt] [get_bd_intf_pins versal_cips_0/PCIE0_GT] 

    # Descriptor status
    connect_bd_intf_net [get_bd_intf_ports c2h_status] [get_bd_intf_pins versal_cips_0/dma0_axis_c2h_status]
    connect_bd_intf_net [get_bd_intf_ports h2c_status] [get_bd_intf_pins versal_cips_0/dma0_qsts_out]

    # Data lines
    connect_bd_intf_net [get_bd_intf_ports s_axis_c2h] [get_bd_intf_pins versal_cips_0/dma0_s_axis_c2h]
    connect_bd_intf_net [get_bd_intf_ports m_axis_h2c] [get_bd_intf_pins versal_cips_0/dma0_m_axis_h2c]

    # Command lines
    connect_bd_intf_net [get_bd_intf_ports dsc_bypass_c2h] [get_bd_intf_pins versal_cips_0/dma0_c2h_byp_in_st_csh]
    connect_bd_intf_net [get_bd_intf_ports dsc_bypass_h2c] [get_bd_intf_pins versal_cips_0/dma0_h2c_byp_in_st]

    # PR
    connect_bd_intf_net [get_bd_intf_ports dsc_pr] [get_bd_intf_pins versal_cips_0/dma0_h2c_byp_in_mm_0]

    # Interrupts
    connect_bd_intf_net [get_bd_intf_ports usr_irq] [get_bd_intf_pins versal_cips_0/dma0_usr_irq]
  } else {
    puts "ERROR: Unsupported PCIe configuration: Gen$cnfg(pcie_gen). Supported configurations for V80 are Gen4x16 and Gen5x8."
    exit 1
  }
  
  # NoC
  connect_bd_intf_net [get_bd_intf_pins axi_noc_0/S00_AXI] [get_bd_intf_pins versal_cips_0/CPM_PCIE_NOC_0]
  connect_bd_intf_net [get_bd_intf_pins axi_noc_0/S01_AXI] [get_bd_intf_pins versal_cips_0/CPM_PCIE_NOC_1]
  connect_bd_intf_net [get_bd_intf_pins axi_noc_0/S02_AXI] [get_bd_intf_pins versal_cips_0/PMC_NOC_AXI_0]
  connect_bd_intf_net [get_bd_intf_pins axi_noc_0/M02_AXI] [get_bd_intf_pins versal_cips_0/NOC_PMC_AXI_0]

  # AMC path: CIPS LPD master into the NoC (only when EN_AMC=1 on V80).
  # PS_USE_NOC_LPD_AXI0=1 in the CIPS config exposes LPD_AXI_NOC_0 as a 128-bit
  # NoC slave port; we drop it into axi_noc_0/S03_AXI for routing to DDR4.
  if {$cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1} {
    connect_bd_intf_net [get_bd_intf_pins versal_cips_0/LPD_AXI_NOC_0] [get_bd_intf_pins axi_noc_0/S03_AXI]
  }

  # Shell config & control --- axi_main
  connect_bd_intf_net [get_bd_intf_pins smartconnect_1/S00_AXI] [get_bd_intf_pins axi_noc_0/M01_AXI]
  # APU/R5 path: M_AXI_FPD from CIPS into the shell control fabric (S01)
  connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_FPD] [get_bd_intf_pins smartconnect_1/S01_AXI]
  connect_bd_intf_net [get_bd_intf_ports axi_main] [get_bd_intf_pins smartconnect_1/M00_AXI]

  # Static config --- axi_cnfg
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/S00_AXI] [get_bd_intf_pins axi_noc_0/M00_AXI]
  connect_bd_intf_net [get_bd_intf_ports axi_cnfg] [get_bd_intf_pins smartconnect_0/M00_AXI]

  # Debug Hub config
  connect_bd_intf_net [get_bd_intf_pins axi_noc_0/M03_AXI] [get_bd_intf_ports axi_debug_hub]
########################################################################################################
# Create port connections
########################################################################################################

  if {$cnfg(pcie_gen) eq 5} {
    # QDMA unused ready signals are tied off to 1
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma1_st_rx_msg_tready]
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma1_tm_dsc_sts_rdy]
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma1_c2h_byp_out_ready]
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma1_h2c_byp_out_ready]

    # QDMA resetn is tied off to 1 (for now, keeping it consistent with rest of Coyote)
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma1_intrfc_resetn]
  
    # Tie off all MM descriptors other than host-to-card channel 0 for PR
    connect_bd_net  [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/dma1_h2c_byp_in_mm_1_valid]
    connect_bd_net  [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/dma1_c2h_byp_in_mm_1_valid]
    connect_bd_net  [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/dma1_c2h_byp_in_mm_0_valid]
  } elseif {$cnfg(pcie_gen) eq 4} {
    # QDMA unused ready signals are tied off to 1
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma0_st_rx_msg_tready]
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma0_tm_dsc_sts_rdy]
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma0_c2h_byp_out_ready]
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma0_h2c_byp_out_ready]

    # QDMA resetn is tied off to 1 (for now, keeping it consistent with rest of Coyote)
    connect_bd_net [get_bd_pins const_1/dout] [get_bd_pins versal_cips_0/dma0_intrfc_resetn]

    # Tie off all MM descriptors other than host-to-card channel 0 for PR
    connect_bd_net  [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/dma0_h2c_byp_in_mm_1_valid]
    connect_bd_net  [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/dma0_c2h_byp_in_mm_1_valid]
    connect_bd_net  [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/dma0_c2h_byp_in_mm_0_valid]
  } else {
    puts "ERROR: Unsupported PCIe configuration: Gen$cnfg(pcie_gen). Supported configurations for V80 are Gen4x16 and Gen5x8."
    exit 1
  }
  
  # QDMA CPM IRQ interfaces should be tied off to 0 (reserved for future use)
  connect_bd_net [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/cpm_irq0]
  connect_bd_net [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/cpm_irq1]

  # PL->PS interrupts unused in this iteration; tie low.
  # Reserved for future Micro Blossom completion notification.
  connect_bd_net [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/pl_ps_irq0]
  connect_bd_net [get_bd_pins const_0/dout] [get_bd_pins versal_cips_0/pl_ps_irq1]

  # NoC clocks
  connect_bd_net [get_bd_pins versal_cips_0/cpm_pcie_noc_axi0_clk] [get_bd_pins axi_noc_0/aclk0]
  connect_bd_net [get_bd_pins versal_cips_0/cpm_pcie_noc_axi1_clk] [get_bd_pins axi_noc_0/aclk1]
  connect_bd_net [get_bd_pins versal_cips_0/pmc_axi_noc_axi0_clk] [get_bd_pins axi_noc_0/aclk2]
  connect_bd_net [get_bd_pins versal_cips_0/noc_pmc_axi_axi0_clk] [get_bd_pins axi_noc_0/aclk4]

  # CIPS m_axi_lpd_aclk MUST be wired unconditionally because PS_USE_M_AXI_LPD
  # is set to 1 in the CIPS config dict above (regardless of EN_AMC). Leaving
  # m_axi_lpd_aclk floating causes validate_bd_design to fail with
  # "[BD 41-758] clock pins are not connected to a valid clock source".
  # cr_aved_mgmt.tcl also drives this for the rpu_sc path; idempotent.
  connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins versal_cips_0/m_axi_lpd_aclk]

  # LPD NoC slave clock is only used when AMC consumes LPD_AXI_NOC_0.
  # CIPS 3.4 (Vivado 2025.1) exposes a single shared `lpd_axi_noc_clk` for the
  # LPD-NoC interfaces, not a per-interface `lpd_noc_axi<N>_clk`.
  if {$cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1} {
    connect_bd_net [get_bd_pins versal_cips_0/lpd_axi_noc_clk] [get_bd_pins axi_noc_0/aclk5]
  }

  # Main shell clock
  connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins clk_wiz_0/clk_in1] 

  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_ports xclk]
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_noc_0/aclk3]
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins smartconnect_0/aclk]
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins smartconnect_1/aclk]
  # M_AXI_FPD runs on the shell clock
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins versal_cips_0/m_axi_fpd_aclk]
  if {$cnfg(pcie_gen) eq 5} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins versal_cips_0/dma1_intrfc_clk]
  } elseif {$cnfg(pcie_gen) eq 4} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins versal_cips_0/dma0_intrfc_clk]
  } else {
    puts "ERROR: Unsupported PCIe configuration: Gen$cnfg(pcie_gen). Supported configurations for V80 are Gen4x16 and Gen5x8."
    exit 1
  }

  # System reset
  connect_bd_net [get_bd_ports sresetn] [get_bd_pins proc_sys_reset_s/peripheral_aresetn]
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_s/slowest_sync_clk]

  if {$cnfg(pcie_gen) eq 5} {
    # System reset
    connect_bd_net [get_bd_pins versal_cips_0/dma1_axi_aresetn] [get_bd_pins proc_sys_reset_s/ext_reset_in] 
    
    # SmartConnect reset
    connect_bd_net [get_bd_pins versal_cips_0/dma1_axi_aresetn] [get_bd_pins smartconnect_0/aresetn]
    connect_bd_net [get_bd_pins versal_cips_0/dma1_axi_aresetn] [get_bd_pins smartconnect_1/aresetn]
  } elseif {$cnfg(pcie_gen) eq 4} {
    # System reset
    connect_bd_net [get_bd_pins versal_cips_0/dma0_axi_aresetn] [get_bd_pins proc_sys_reset_s/ext_reset_in] 
    
    # SmartConnect reset
    connect_bd_net [get_bd_pins versal_cips_0/dma0_axi_aresetn] [get_bd_pins smartconnect_0/aresetn]
    connect_bd_net [get_bd_pins versal_cips_0/dma0_axi_aresetn] [get_bd_pins smartconnect_1/aresetn]
  } else {
    puts "ERROR: Unsupported PCIe configuration: Gen$cnfg(pcie_gen). Supported configurations for V80 are Gen4x16 and Gen5x8."
    exit 1
  }

  # Shell reset
  connect_bd_net [get_bd_ports xresetn] [get_bd_pins proc_sys_reset_x/peripheral_aresetn]
  connect_bd_net [get_bd_ports eos_resetn] [get_bd_pins proc_sys_reset_x/ext_reset_in]
  connect_bd_net [get_bd_pins proc_sys_reset_x/slowest_sync_clk] [get_bd_pins clk_wiz_0/clk_out1]

  # EOS
  connect_bd_net [get_bd_pins versal_cips_0/eos] [get_bd_ports eos_pmc]

########################################################################################################
# Create address segments
########################################################################################################
  # Shell & static config (host PCIe view)
  assign_bd_address -offset 0x020100000000 -range 1M -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] [get_bd_addr_segs axi_cnfg/Reg] -force
  assign_bd_address -offset 0x020800000000 -range 256M -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] [get_bd_addr_segs axi_main/Reg] -force

  # APU/R5 view via M_AXI_FPD: vFPGA control regs at 0x4_0000_0000 (8G FPD window).
  # Only axi_main is reachable via smartconnect_1 (which now has S01 from M_AXI_FPD).
  # axi_cnfg lives behind smartconnect_0 and is intentionally not exposed to the APU
  # — it carries static-layer/host config registers that the APU shouldn't touch.
  assign_bd_address -offset 0x000400000000 -range 256M -target_address_space [get_bd_addr_spaces versal_cips_0/M_AXI_FPD] [get_bd_addr_segs axi_main/Reg] -force
  
  # PR control (SBI CSR) --- currently unused
  # assign_bd_address -offset 0x000101220000 -range 64K -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_1] [get_bd_addr_segs versal_cips_0/NOC_PMC_AXI_0/pspmc_0_psv_pmc_slave_boot] -force

  # PR data (address to write partial PDI to)
  assign_bd_address -offset 0x000102100000 -range 64K -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_1] [get_bd_addr_segs versal_cips_0/NOC_PMC_AXI_0/pspmc_0_psv_pmc_slave_boot_stream] -force

  # PMC_NOC_AXI_0 for configuring the Debug Hub IP
  assign_bd_address -offset 0x020240000000 -range 2M -target_address_space [get_bd_addr_spaces versal_cips_0/PMC_NOC_AXI_0] [get_bd_addr_segs axi_debug_hub/Reg] -force
  
  # Restore current instance
  current_bd_instance $oldCurInst

  # AMC enablement (V80 + EN_AMC=1):
  #   - DDR4 controller (provides backing memory for AMC binary at 0x40000000)
  #   - GCQ + rpu_sc (host↔R5 mailbox)
  # Order matters: DDR4 must be instantiated before address-map assignments that
  # reference axi_noc_mc_ddr4_0's segments, and before validate_bd_design.
  if {$cnfg(fdev) eq "v80" && $cnfg(en_amc) eq 1} {
    cr_bd_design_ddr4_v80 ""
    cr_bd_design_aved_mgmt ""

    # Address map: DDR4 visible from CIPS LPD master via NoC route.
    # AVED-canonical mapping: 2 GB window at 0x0_0000_0000..0x0_7FFF_FFFF in
    # the LPD address space. AMC's lscript.ld places code at 0x4000_0000 which
    # falls inside this window. Mirrors AVED create_bd_design.tcl:1135.
    assign_bd_address -offset 0x00000000 -range 2G \
        -target_address_space [get_bd_addr_spaces versal_cips_0/LPD_AXI_NOC_0] \
        [get_bd_addr_segs axi_noc_mc_ddr4_0/S00_INI/C0_DDR_LOW0] -force

    # PMC master view of DDR4 at 0x0..0x7FFF_FFFF (DDR_LOW0). The PLM DMA-loads
    # amc.elf's 0x4000_0000 segment through PMC_NOC_AXI_0; without this mapping
    # the load has no route and boot stalls. Mirrors the LPD mapping above; both
    # ride the shared S02/S03 -> M00_INI -> DDR4 path.
    assign_bd_address -offset 0x00000000 -range 2G \
        -target_address_space [get_bd_addr_spaces versal_cips_0/PMC_NOC_AXI_0] \
        [get_bd_addr_segs axi_noc_mc_ddr4_0/S00_INI/C0_DDR_LOW0] -force

    # Host-side PCIe window onto DDR4 (BAR4 + 32 MB high portion). Maps PCIe
    # 0x0208_0A00_0000..0x0208_0C00_0000 to DDR4 0x0..0x02000000. This is how
    # the host reaches AMC's partition table + GCQ ring buffers in shared mem
    # (AMC's HAL_RPU_SHARED_MEMORY_BASE_ADDR=0x00100000 lives inside this).
    # Address chosen to be 32 MB aligned (REMAPS requirement) and above the
    # axi_main (128 MB) + gcq_m2r (64 KB) regions.
    assign_bd_address -offset 0x02080A000000 -range 32M \
        -target_address_space [get_bd_addr_spaces versal_cips_0/CPM_PCIE_NOC_0] \
        [get_bd_addr_segs axi_noc_mc_ddr4_0/S00_INI/C0_DDR_LOW0] -force
  }

  validate_bd_design
  save_bd_design
  close_bd_design $design_name

  return 0
}
# End of cr_bd_design_static()
