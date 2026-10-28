##
## STATIC IPs FOR ZYNQ-BASED PLATFORMS
##

# Host DMA; one AXI DataMover per host channel, taking the place of the XDMA descriptor bypass on PCIe platforms
# MM2S (memory-to-stream) serves host-to-card (H2C) reads, S2MM (stream-to-memory) serves card-to-host (C2H) writes
# Same configuration as axi_datamover_mem_unaligned in network_infrastructure.tcl; the DREs are needed since host buffers can be unaligned
# See hw/hdl/static/zynq_dma_wrapper.sv for details
create_ip -name axi_datamover -vendor xilinx.com -library ip -version 5.1 -module_name axi_datamover_hdma
set_property -dict [list CONFIG.c_mm2s_stscmd_is_async {true} CONFIG.c_mm2s_include_sf {false} CONFIG.c_m_axi_mm2s_id_width {6} CONFIG.c_m_axi_s2mm_id_width {6} CONFIG.c_m_axi_mm2s_data_width {512} CONFIG.c_m_axis_mm2s_tdata_width {512} CONFIG.c_include_mm2s_dre {true} CONFIG.c_mm2s_burst_size {64} CONFIG.c_mm2s_btt_used {23} CONFIG.c_s2mm_stscmd_is_async {true} CONFIG.c_m_axi_s2mm_data_width {512} CONFIG.c_s_axis_s2mm_tdata_width {512} CONFIG.c_include_s2mm_dre {true} CONFIG.c_s2mm_burst_size {64} CONFIG.c_s2mm_btt_used {23} CONFIG.c_s2mm_include_sf {false} CONFIG.c_addr_width {64}] [get_ips axi_datamover_hdma]
