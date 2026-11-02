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

# RF data converter (EN_RF=1), zcu216: one RF-ADC and one RF-DAC on tile 2 (the tiles that receive the reference clocks
# from the on-board clock chips, so no clock distribution between tiles is needed)
#
# Clocks: 245.76 MHz reference clocks, 2.4576 GSPS on both converters, 8 samples (16 bits each) per 307.2 MHz fabric cycle
#
# NOTE: The DAC data inputs are tied to zero and the ADC data is discarded, so this design cannot output a signal.
# Connecting them to the rest of the shell is future work, see docs/source/intro/zcu216-notes.rst
proc cr_bd_design_rf { parentCell } {
  upvar #0 cfg cnfg

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
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vin20
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 vout20

  # Converter streams and clocks
  set m_axis_adc [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_adc ]
  set_property -dict [ list CONFIG.TDATA_NUM_BYTES {16} CONFIG.FREQ_HZ {307200000} ] $m_axis_adc
  set s_axis_dac [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis_dac ]
  set_property -dict [ list CONFIG.TDATA_NUM_BYTES {16} CONFIG.HAS_TREADY {1} CONFIG.HAS_TKEEP {0} CONFIG.HAS_TLAST {0} CONFIG.HAS_TSTRB {0} CONFIG.TUSER_WIDTH {0} CONFIG.TID_WIDTH {0} CONFIG.TDEST_WIDTH {0} CONFIG.FREQ_HZ {307200000} ] $s_axis_dac
  set clk_adc2 [ create_bd_port -dir O -type clk clk_adc2 ]
  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF {m_axis_adc} CONFIG.FREQ_HZ {307200000} ] $clk_adc2
  set clk_dac2 [ create_bd_port -dir O -type clk clk_dac2 ]
  set_property -dict [ list CONFIG.ASSOCIATED_BUSIF {s_axis_dac} CONFIG.FREQ_HZ {307200000} ] $clk_dac2

  # Converter
  set rfdc [ create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter:2.6 rfdc ]
  set_property -dict [ list \
    CONFIG.Axiclk_Freq $cnfg(aclk_f) \
    CONFIG.ADC0_Enable {0} \
    CONFIG.ADC_Slice00_Enable {false} \
    CONFIG.ADC2_Enable {1} \
    CONFIG.ADC2_PLL_Enable {true} \
    CONFIG.ADC2_Refclk_Freq {245.760} \
    CONFIG.ADC2_Sampling_Rate {2.4576} \
    CONFIG.ADC2_Fabric_Freq {307.200} \
    CONFIG.ADC2_Outclk_Freq {307.200} \
    CONFIG.ADC_Slice20_Enable {true} \
    CONFIG.ADC_Data_Type20 {0} \
    CONFIG.ADC_Data_Width20 {8} \
    CONFIG.ADC_Decimation_Mode20 {1} \
    CONFIG.ADC_Mixer_Type20 {1} \
    CONFIG.DAC2_Enable {1} \
    CONFIG.DAC2_PLL_Enable {true} \
    CONFIG.DAC2_Refclk_Freq {245.760} \
    CONFIG.DAC2_Sampling_Rate {2.4576} \
    CONFIG.DAC2_Fabric_Freq {307.200} \
    CONFIG.DAC2_Outclk_Freq {307.200} \
    CONFIG.DAC_Slice20_Enable {true} \
    CONFIG.DAC_Data_Type20 {0} \
    CONFIG.DAC_Data_Width20 {8} \
    CONFIG.DAC_Interpolation_Mode20 {1} \
    CONFIG.DAC_Mixer_Type20 {1} \
  ] $rfdc

  # Fabric resets; the tile clocks only run once the clock chips are programmed
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_adc2
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_dac2


  # Interfaces
  connect_bd_intf_net [get_bd_intf_ports axi_rf] [get_bd_intf_pins rfdc/s_axi]
  connect_bd_intf_net [get_bd_intf_ports adc2_clk] [get_bd_intf_pins rfdc/adc2_clk]
  connect_bd_intf_net [get_bd_intf_ports dac2_clk] [get_bd_intf_pins rfdc/dac2_clk]
  connect_bd_intf_net [get_bd_intf_ports sysref_in] [get_bd_intf_pins rfdc/sysref_in]
  connect_bd_intf_net [get_bd_intf_ports vin20] [get_bd_intf_pins rfdc/vin20]
  connect_bd_intf_net [get_bd_intf_ports vout20] [get_bd_intf_pins rfdc/vout20]

  # Clocks and resets
  connect_bd_net [get_bd_ports aclk] [get_bd_pins rfdc/s_axi_aclk]
  connect_bd_net [get_bd_ports aresetn] [get_bd_pins rfdc/s_axi_aresetn] [get_bd_pins rst_adc2/ext_reset_in] [get_bd_pins rst_dac2/ext_reset_in]
  connect_bd_net [get_bd_pins rfdc/clk_adc2] [get_bd_pins rfdc/m2_axis_aclk] [get_bd_pins rst_adc2/slowest_sync_clk]
  connect_bd_net [get_bd_pins rfdc/clk_dac2] [get_bd_pins rfdc/s2_axis_aclk] [get_bd_pins rst_dac2/slowest_sync_clk]
  connect_bd_net [get_bd_pins rst_adc2/peripheral_aresetn] [get_bd_pins rfdc/m2_axis_aresetn]
  connect_bd_net [get_bd_pins rst_dac2/peripheral_aresetn] [get_bd_pins rfdc/s2_axis_aresetn]
  # Converter streams and their clocks, to rf_service in the shell
  connect_bd_intf_net [get_bd_intf_ports m_axis_adc] [get_bd_intf_pins rfdc/m20_axis]
  connect_bd_intf_net [get_bd_intf_ports s_axis_dac] [get_bd_intf_pins rfdc/s20_axis]
  connect_bd_net [get_bd_pins rfdc/clk_adc2] [get_bd_ports clk_adc2]
  connect_bd_net [get_bd_pins rfdc/clk_dac2] [get_bd_ports clk_dac2]

  assign_bd_address -offset 0x00000000 -range 256K -target_address_space [get_bd_addr_spaces /axi_rf] [get_bd_addr_segs rfdc/s_axi/Reg]

  validate_bd_design
  save_bd_design
  close_bd_design $design_name

  return 0
}
