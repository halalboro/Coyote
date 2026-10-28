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

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
######################################################################################

# Static layer for Zynq UltraScale+ (MPSoC/RFSoC) platforms (experimental)
#
# Equivalent of hw/bd/ultrascale_plus/cr_pci.tcl, with the PS taking the place of the XDMA core:
#   - axi_main (256 MB) on M_AXI_HPM0_FPD at 0xA000_0000 and axi_cnfg (1 MB) on M_AXI_HPM1_FPD at 0xB000_0000;
#     in the driver, these are the equivalents of the bypass and AXI-Lite BARs, respectively
#   - axi_hdma_<i> (one per host channel, driven by zynq_dma_wrapper) on the coherent S_AXI_HPC0_FPD (channel 0)
#     and S_AXI_HPC1_FPD (remaining channels) ports
#   - usr_irq_0 and usr_irq_1 on pl_ps_irq0 and pl_ps_irq1 (GIC SPI 89-96 and 104-111); level-sensitive, active-high
#   - All clocks are generated from pl_clk0, which must be 100 MHz
#
# All PS ports are kept at their default width (128 bits), since the AXI port widths are programmed
# at boot time and may not be updated when the bitstream is loaded at runtime from Linux
proc cr_bd_design_static { parentCell } {
  upvar #0 cfg cnfg

  # CHANGE DESIGN NAME HERE
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
  xilinx.com:ip:zynq_ultra_ps_e\
  xilinx.com:ip:smartconnect\
  xilinx.com:ip:clk_wiz\
  xilinx.com:ip:proc_sys_reset\
  xilinx.com:ip:util_vector_logic\
  "

   set list_ips_missing ""
   common::send_msg_id "BD_TCL-006" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all "$ip_vlnv:*"]
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

  # Static config
  set axi_cnfg [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_cnfg ]
  set_property -dict [ list \
    CONFIG.ADDR_WIDTH {64} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.PROTOCOL {AXI4LITE} \
  ] $axi_cnfg

  # Control main
  # The ID width must match AXI_ID_BITS of the shell; the SmartConnect compacts the (16-bit) IDs of the PS
  set cmd "set axi_main \[ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_main ]
          set_property -dict \[ list \
            CONFIG.ADDR_WIDTH {64} \
            CONFIG.DATA_WIDTH {512} \
            CONFIG.ID_WIDTH {6} \
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
          ] \$axi_main"
  eval $cmd

  # Host DMA, one per host channel (see hw/hdl/static/zynq_dma_wrapper.sv)
  for {set i 0}  {$i < $cnfg(n_hchan)} {incr i} {
    set cmd "set axi_hdma_$i \[ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_hdma_$i ]
            set_property -dict \[ list \
              CONFIG.ADDR_WIDTH {64} \
              CONFIG.DATA_WIDTH {512} \
              CONFIG.ID_WIDTH {6} \
              CONFIG.HAS_BRESP {1} \
              CONFIG.HAS_BURST {1} \
              CONFIG.HAS_CACHE {1} \
              CONFIG.HAS_LOCK {1} \
              CONFIG.HAS_PROT {1} \
              CONFIG.HAS_QOS {0} \
              CONFIG.HAS_REGION {0} \
              CONFIG.HAS_RRESP {1} \
              CONFIG.HAS_WSTRB {1} \
              CONFIG.ARUSER_WIDTH {0} \
              CONFIG.AWUSER_WIDTH {0} \
              CONFIG.RUSER_WIDTH {0} \
              CONFIG.WUSER_WIDTH {0} \
              CONFIG.BUSER_WIDTH {0} \
              CONFIG.NUM_READ_OUTSTANDING {16} \
              CONFIG.NUM_WRITE_OUTSTANDING {16} \
              CONFIG.PROTOCOL {AXI4} \
              CONFIG.READ_WRITE_MODE {READ_WRITE} \
            ] \$axi_hdma_$i"
    eval $cmd
  }

########################################################################################################
# Create ports
########################################################################################################

  # Main bd reset
  set xresetn [ create_bd_port -dir O -type rst xresetn ]

  # Main bd clock
  set cmd "set xclk \[ create_bd_port -dir O -type clk xclk ]
          set_property -dict \[ list \
              CONFIG.ASSOCIATED_BUSIF {axi_main:axi_cnfg"
              for {set i 0}  {$i < $cnfg(n_hchan)} {incr i} {
                append cmd ":axi_hdma_$i"
              }
              append cmd "} \
              CONFIG.FREQ_HZ {250000000} \
              ] \$xclk"
  eval $cmd

  # PR reset
  set presetn [ create_bd_port -dir O -type rst presetn ]

  # PR clock
  set cmd "set pclk \[ create_bd_port -dir O -type clk pclk ]
          set_property -dict \[ list \
              CONFIG.ASSOCIATED_RESET {presetn} \
              CONFIG.FREQ_HZ {200000000} \
          ] \$pclk"
  eval $cmd

  # Debug reset
  set dresetn [ create_bd_port -dir O -type rst dresetn ]

  # Debug clock
  set cmd "set dclk \[ create_bd_port -dir O -type clk dclk ]
          set_property -dict \[ list \
              CONFIG.ASSOCIATED_RESET {dresetn} \
              CONFIG.FREQ_HZ {100000000} \
          ] \$dclk"
  eval $cmd

  # System reset
  set sresetn [ create_bd_port -dir O -type rst sresetn ]

  # User interrupts; split in two, since each PL-to-PS interrupt port is 8 bits wide
  create_bd_port -dir I -from 7 -to 0 -type intr usr_irq_0
  create_bd_port -dir I -from 7 -to 0 -type intr usr_irq_1
  set_property CONFIG.SENSITIVITY LEVEL_HIGH [get_bd_ports usr_irq_0]
  set_property CONFIG.SENSITIVITY LEVEL_HIGH [get_bd_ports usr_irq_1]

  # Locked
  set lckresetn [ create_bd_port -dir O -type rst lckresetn ]

  # Dynamic reset
  create_bd_port -dir I -type rst eos_resetn
  set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports eos_resetn]
  set_property CONFIG.ASSOCIATED_RESET {xresetn:sresetn:eos_resetn} [get_bd_ports /xclk]

########################################################################################################
# Create interconnect and components
########################################################################################################

  # Processing system
  set zynq_ultra_ps_e_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0 ]

  # Board presets (DDR, MIO etc.), if the board files are installed; see cr_static.tcl
  if { [get_property board_part [current_project]] ne "" } {
    apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $zynq_ultra_ps_e_0
  }

  set_property -dict [ list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__USE__M_AXI_GP1 {1} \
    CONFIG.PSU__MAXIGP1__DATA_WIDTH {128} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP0 {1} \
    CONFIG.PSU__SAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__USE__S_AXI_GP1 {1} \
    CONFIG.PSU__SAXIGP1__DATA_WIDTH {128} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__USE__IRQ1 {1} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
  ] $zynq_ultra_ps_e_0

  # Clocks; xclk (250 MHz), pclk (200 MHz), dclk (100 MHz)
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
    CONFIG.NUM_OUT_CLKS {3} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {250.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000} \
  ] $clk_wiz_0

  # Resets
  set proc_sys_reset_s [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_s ]
  set proc_sys_reset_x [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_x ]
  set proc_sys_reset_p [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_p ]
  set proc_sys_reset_d [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_d ]

  create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic util_vector_logic_0
  set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {and}] [get_bd_cells util_vector_logic_0]

  # Control path; also compacts the IDs and converts the width (128 -> 512) and the protocol (AXI4 -> AXI4-Lite)
  set smartconnect_main [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_main ]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smartconnect_main

  set smartconnect_cnfg [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_cnfg ]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smartconnect_cnfg

  # Host DMA path; channel 0 (host streams) has the HPC0 port to itself, the remaining channels share HPC1
  set smartconnect_hpc0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_hpc0 ]
  set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $smartconnect_hpc0

  set smartconnect_hpc1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect smartconnect_hpc1 ]
  set_property -dict [list CONFIG.NUM_SI [expr {$cnfg(n_hchan) - 1}] CONFIG.NUM_MI {1}] $smartconnect_hpc1

########################################################################################################
# Create interface connections
########################################################################################################

  # Control lines
  connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins smartconnect_main/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_main/M00_AXI] [get_bd_intf_ports axi_main]
  connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM1_FPD] [get_bd_intf_pins smartconnect_cnfg/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_cnfg/M00_AXI] [get_bd_intf_ports axi_cnfg]

  # Data lines
  connect_bd_intf_net [get_bd_intf_ports axi_hdma_0] [get_bd_intf_pins smartconnect_hpc0/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_hpc0/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC0_FPD]
  for {set i 1}  {$i < $cnfg(n_hchan)} {incr i} {
    set cmd "connect_bd_intf_net \[get_bd_intf_ports axi_hdma_$i] \[get_bd_intf_pins smartconnect_hpc1/S[format "%02d" [expr {$i - 1}]]_AXI]"
    eval $cmd
  }
  connect_bd_intf_net [get_bd_intf_pins smartconnect_hpc1/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HPC1_FPD]

########################################################################################################
# Create port connections
########################################################################################################

  # Interrupts
  connect_bd_net [get_bd_ports usr_irq_0] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
  connect_bd_net [get_bd_ports usr_irq_1] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq1]

  # Clocks
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins clk_wiz_0/clk_in1]
  connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins clk_wiz_0/resetn]

  connect_bd_net [get_bd_ports xclk] [get_bd_pins clk_wiz_0/clk_out1]
  connect_bd_net [get_bd_ports pclk] [get_bd_pins clk_wiz_0/clk_out2]
  connect_bd_net [get_bd_ports dclk] [get_bd_pins clk_wiz_0/clk_out3]
  connect_bd_net [get_bd_ports lckresetn] [get_bd_pins clk_wiz_0/locked]

  foreach pin {maxihpm0_fpd_aclk maxihpm1_fpd_aclk saxihpc0_fpd_aclk saxihpc1_fpd_aclk} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins zynq_ultra_ps_e_0/$pin]
  }
  foreach sc {smartconnect_main smartconnect_cnfg smartconnect_hpc0 smartconnect_hpc1} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins $sc/aclk]
    connect_bd_net [get_bd_pins proc_sys_reset_s/interconnect_aresetn] [get_bd_pins $sc/aresetn]
  }

  # Resets; all held until the clocks are locked
  foreach rst {proc_sys_reset_s proc_sys_reset_x proc_sys_reset_p proc_sys_reset_d} {
    connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins $rst/dcm_locked]
  }

  connect_bd_net [get_bd_pins proc_sys_reset_s/slowest_sync_clk] [get_bd_pins clk_wiz_0/clk_out1]
  connect_bd_net [get_bd_pins proc_sys_reset_s/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]
  connect_bd_net [get_bd_ports sresetn] [get_bd_pins proc_sys_reset_s/peripheral_aresetn]

  connect_bd_net [get_bd_pins proc_sys_reset_x/slowest_sync_clk] [get_bd_pins clk_wiz_0/clk_out1]
  connect_bd_net [get_bd_pins util_vector_logic_0/Op1] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]
  connect_bd_net [get_bd_pins util_vector_logic_0/Op2] [get_bd_ports eos_resetn]
  connect_bd_net [get_bd_pins util_vector_logic_0/Res] [get_bd_pins proc_sys_reset_x/ext_reset_in]
  connect_bd_net [get_bd_ports xresetn] [get_bd_pins proc_sys_reset_x/peripheral_aresetn]

  connect_bd_net [get_bd_pins proc_sys_reset_p/slowest_sync_clk] [get_bd_pins clk_wiz_0/clk_out2]
  connect_bd_net [get_bd_pins proc_sys_reset_p/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]
  connect_bd_net [get_bd_ports presetn] [get_bd_pins proc_sys_reset_p/peripheral_aresetn]

  connect_bd_net [get_bd_pins proc_sys_reset_d/slowest_sync_clk] [get_bd_pins clk_wiz_0/clk_out3]
  connect_bd_net [get_bd_pins proc_sys_reset_d/ext_reset_in] [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0]
  connect_bd_net [get_bd_ports dresetn] [get_bd_pins proc_sys_reset_d/peripheral_aresetn]

########################################################################################################
# Create address segments
########################################################################################################

  # Control windows; the shell only decodes the lower address bits (AXI_BPSS_BAR_BITS for axi_main)
  assign_bd_address -offset 0xA0000000 -range 256M -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_main/Reg]
  assign_bd_address -offset 0xB0000000 -range 1M -target_address_space [get_bd_addr_spaces zynq_ultra_ps_e_0/Data] [get_bd_addr_segs axi_cnfg/Reg]

  # Host DMA; maps the whole PS address space (DDR low and high, OCM etc.) as seen from the HPC ports
  assign_bd_address

  validate_bd_design

  # A wider ID would be silently truncated in static_top, breaking response routing
  set main_id_width [get_property CONFIG.ID_WIDTH [get_bd_intf_ports axi_main]]
  if { $main_id_width > 6 } {
    error "axi_main has an ID width of $main_id_width, but the shell supports at most 6 (AXI_ID_BITS)"
  }

  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
  close_bd_design $design_name

  return 0
}
# End of cr_bd_design_static()
