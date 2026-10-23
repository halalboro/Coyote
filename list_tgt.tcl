open_hw_manager
connect_hw_server -allow_non_jtag
foreach t [get_hw_targets -quiet] { puts "TGT: $t" }
foreach t [get_hw_targets -quiet *XFL1A3A2MN3U*] { puts "V80: $t" }
disconnect_hw_server
