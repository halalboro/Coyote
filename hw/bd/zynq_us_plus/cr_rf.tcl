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

# RF data converter (EN_RF=1), zcu216: four RF-ADCs and four RF-DACs, the channels on the XM655's connectors JHC7 and JHC3
#   Channel 0: tile 2 block 0, channel 1: tile 2 block 2, channel 2: tile 3 block 0, channel 3: tile 3 block 2
# Only tile 2 receives reference clocks from the on-board clock chips; it passes them on to tile 3.
#
# Clocks: 245.76 MHz reference clocks; all converters sample at RF_RATE_KHZ (default 2.4576 GSPS), 8 samples (16 bits each) per fabric cycle.
# Each direction uses one fabric clock, from tile 2, for both tiles, so tile 2 has to run for tile 3 to pass data.
proc cr_bd_design_rf { parentCell } {
  upvar #0 cfg cnfg

  set rate_ghz [format %.6f [expr {$cnfg(rf_rate_khz) / 1000000.0}]]
  set fabric_mhz [format %.3f [expr {$cnfg(rf_rate_khz) / 8000.0}]]
  set fabric_hz [expr {$cnfg(rf_rate_khz) * 125}]

  set design_name design_rf
  create_bd_design $design_name

  # Control, from the shell's control crossbar
  set axi_rf [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 axi_rf ]
  set_property -dict [ list \
    CONFIG.ADDR_WIDTH {18} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.PROTOCOL {AXI4LITE} \
  ] $axi_rf

  set aclk [ create_bd_port -dir I -type clk aclk ]
  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF {axi_rf} CONFIG.ASSOCIATED_RESET {aresetn} CONFIG.FREQ_HZ [expr {$cnfg(aclk_f) * 1000000}] ] $aclk
  create_bd_port -dir I -type rst aresetn

  # Dedicated RF pins
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 adc2_clk
  set_property CONFIG.FREQ_HZ {245760000} [get_bd_intf_ports adc2_clk]
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac2_clk
  set_property CONFIG.FREQ_HZ {245760000} [get_bd_intf_ports dac2_clk]
  create_bd_intf_port -mode Slave -vlnv xilinx.com:display_usp_rf_data_converter:diff_pins_rtl:1.0 sysref_in
  foreach b {20 22 30 32} {
    create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin$b
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout$b
  }

  # Converter streams and clocks
  set busif_adc {}
  set busif_dac {}
  foreach ch {0 1 2 3} {
    set m_axis_adc [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_adc$ch ]
    set_property -dict [ list CONFIG.TDATA_NUM_BYTES {16} CONFIG.FREQ_HZ $fabric_hz ] $m_axis_adc
    set s_axis_dac [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_dac$ch ]
    set_property -dict [ list CONFIG.TDATA_NUM_BYTES {16} CONFIG.HAS_TREADY {1} CONFIG.HAS_TKEEP {0} CONFIG.HAS_TLAST {0} CONFIG.HAS_TSTRB {0} CONFIG.TUSER_WIDTH {0} CONFIG.TID_WIDTH {0} CONFIG.TDEST_WIDTH {0} CONFIG.FREQ_HZ $fabric_hz ] $s_axis_dac
    lappend busif_adc m_axis_adc$ch
    lappend busif_dac s_axis_dac$ch
  }
  set clk_adc2 [ create_bd_port -dir O -type clk clk_adc2 ]
  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF [join $busif_adc :] CONFIG.FREQ_HZ $fabric_hz ] $clk_adc2
  set clk_dac2 [ create_bd_port -dir O -type clk clk_dac2 ]
  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF [join $busif_dac :] CONFIG.FREQ_HZ $fabric_hz ] $clk_dac2

  # Converter
  set rfdc [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 rfdc ]
  set rf_config [ list CONFIG.Axiclk_Freq $cnfg(aclk_f) CONFIG.ADC0_Enable {0} CONFIG.ADC_Slice00_Enable {false} ]
  foreach t {2 3} {
    foreach {dir rate} {ADC Decimation DAC Interpolation} {
      lappend rf_config CONFIG.${dir}${t}_Enable {1} CONFIG.${dir}${t}_PLL_Enable {true} CONFIG.${dir}${t}_Refclk_Freq {245.760} \
        CONFIG.${dir}${t}_Sampling_Rate $rate_ghz CONFIG.${dir}${t}_Fabric_Freq $fabric_mhz CONFIG.${dir}${t}_Outclk_Freq $fabric_mhz
      foreach b {0 2} {
        lappend rf_config CONFIG.${dir}_Slice${t}${b}_Enable {true} CONFIG.${dir}_Data_Type${t}${b} {0} CONFIG.${dir}_Data_Width${t}${b} {8} \
          CONFIG.${dir}_${rate}_Mode${t}${b} {1} CONFIG.${dir}_Mixer_Type${t}${b} {1}
      }
    }
  }
  # Tile 3 takes its reference clock from tile 2
  lappend rf_config CONFIG.ADC3_Clock_Source {2} CONFIG.ADC2_Clock_Dist {1} CONFIG.DAC3_Clock_Source {6} CONFIG.DAC2_Clock_Dist {1}
  set_property -dict $rf_config $rfdc

  # Fabric resets; the tile clocks only run once the clock chips are programmed
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc2
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac2


  # Interfaces
  connect_bd_intf_net [get_bd_intf_ports axi_rf] [get_bd_intf_pins rfdc/s_axi]
  connect_bd_intf_net [get_bd_intf_ports adc2_clk] [get_bd_intf_pins rfdc/adc2_clk]
  connect_bd_intf_net [get_bd_intf_ports dac2_clk] [get_bd_intf_pins rfdc/dac2_clk]
  connect_bd_intf_net [get_bd_intf_ports sysref_in] [get_bd_intf_pins rfdc/sysref_in]
  foreach b {20 22 30 32} {
    connect_bd_intf_net [get_bd_intf_ports vin$b] [get_bd_intf_pins rfdc/vin$b]
    connect_bd_intf_net [get_bd_intf_ports vout$b] [get_bd_intf_pins rfdc/vout$b]
  }

  # Clocks and resets
  connect_bd_net [get_bd_ports aclk] [get_bd_pins rfdc/s_axi_aclk]
  connect_bd_net [get_bd_ports aresetn] [get_bd_pins rfdc/s_axi_aresetn] [get_bd_pins rst_adc2/ext_reset_in] [get_bd_pins rst_dac2/ext_reset_in]
  connect_bd_net [get_bd_pins rfdc/clk_adc2] [get_bd_pins rfdc/m2_axis_aclk] [get_bd_pins rfdc/m3_axis_aclk] [get_bd_pins rst_adc2/slowest_sync_clk]
  connect_bd_net [get_bd_pins rfdc/clk_dac2] [get_bd_pins rfdc/s2_axis_aclk] [get_bd_pins rfdc/s3_axis_aclk] [get_bd_pins rst_dac2/slowest_sync_clk]
  connect_bd_net [get_bd_pins rst_adc2/peripheral_aresetn] [get_bd_pins rfdc/m2_axis_aresetn] [get_bd_pins rfdc/m3_axis_aresetn]
  connect_bd_net [get_bd_pins rst_dac2/peripheral_aresetn] [get_bd_pins rfdc/s2_axis_aresetn] [get_bd_pins rfdc/s3_axis_aresetn]
  # Converter streams and their clocks, to rf_service in the shell
  foreach ch {0 1 2 3} b {20 22 30 32} {
    connect_bd_intf_net [get_bd_intf_ports m_axis_adc$ch] [get_bd_intf_pins rfdc/m${b}_axis]
    connect_bd_intf_net [get_bd_intf_ports s_axis_dac$ch] [get_bd_intf_pins rfdc/s${b}_axis]
  }
  connect_bd_net [get_bd_pins rfdc/clk_adc2] [get_bd_ports clk_adc2]
  connect_bd_net [get_bd_pins rfdc/clk_dac2] [get_bd_ports clk_dac2]

  assign_bd_address -offset 0x00000000 -range 256K -target_address_space [get_bd_addr_spaces /axi_rf] [get_bd_addr_segs rfdc/s_axi/Reg]

  validate_bd_design
  save_bd_design
  close_bd_design $design_name

  return 0
}
