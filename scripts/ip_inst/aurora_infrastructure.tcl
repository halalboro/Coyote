##
## Aurora 64B/66B wrapper — shell-level IP generation
##
## Sits in parallel to network_infrastructure.tcl (which creates CMAC).
## Gated by cfg(en_aurora_1). Consumed by hw/hdl/aurora/aurora_module.sv.
##
## Target: U280, 4 lanes @ 25.78125 Gbps = 103.125 Gbps gross.
## Reference clock: 161.1328125 MHz on QSFP1 cage.
## User-side: 256-bit AXI4-Stream @ Aurora-generated user_clk (~390 MHz).
##

if {$cfg(en_aurora_1) eq 1} {

    if {$cfg(fdev) eq "u280"} {
        # Aurora 64B/66B IP — 4 lanes bonded on QSFP1's GTY quad.
        # GT pin locking happens via the u280_shell_zaurora_1.xdc constraints file;
        # the IP itself is configured generically here.
        create_ip -name aurora_64b66b -vendor xilinx.com -library ip \
            -module_name aurora_loopback_ip
        # SupportLevel=1  -> include shared logic (QPLL, init) in the core.
        # SupportLevel=0 in Vivado 2023.2 exposes external QPLL/user clocks.
        # drp_mode=Native is the no-AXI4-Lite DRP option in Vivado 2023.2.
        set_property -dict [list \
            CONFIG.C_AURORA_LANES       {4} \
            CONFIG.C_LINE_RATE          {25.78125} \
            CONFIG.C_REFCLK_FREQUENCY   {161.1328125} \
            CONFIG.C_INIT_CLK           {100.0} \
            CONFIG.dataflow_config      {Duplex} \
            CONFIG.interface_mode       {Framing} \
            CONFIG.SupportLevel         {1} \
            CONFIG.drp_mode             {Native} \
        ] [get_ips aurora_loopback_ip]
    }

    # AXI4-Stream clock-domain crossing FIFOs used by aurora_module.sv to bridge
    # Aurora's ~390 MHz user_clk to Coyote's aclk. 256-bit data + tkeep + tlast.
    # Depth 1024 is a starting point; tune if backpressure / overrun is observed.
    create_ip -name axis_data_fifo -vendor xilinx.com -library ip \
        -module_name axis_data_fifo_aurora_tx
    set_property -dict [list \
        CONFIG.TDATA_NUM_BYTES        {32} \
        CONFIG.HAS_TLAST              {1} \
        CONFIG.HAS_TKEEP              {1} \
        CONFIG.FIFO_DEPTH             {1024} \
        CONFIG.IS_ACLK_ASYNC          {1} \
        CONFIG.SYNCHRONIZATION_STAGES {3} \
    ] [get_ips axis_data_fifo_aurora_tx]

    create_ip -name axis_data_fifo -vendor xilinx.com -library ip \
        -module_name axis_data_fifo_aurora_rx
    set_property -dict [list \
        CONFIG.TDATA_NUM_BYTES        {32} \
        CONFIG.HAS_TLAST              {1} \
        CONFIG.HAS_TKEEP              {1} \
        CONFIG.FIFO_DEPTH             {1024} \
        CONFIG.IS_ACLK_ASYNC          {1} \
        CONFIG.SYNCHRONIZATION_STAGES {3} \
    ] [get_ips axis_data_fifo_aurora_rx]
}
