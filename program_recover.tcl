# Refresh-skipping programmer: goes straight to program_hw_devices (which does a
# PMC POR) and does NOT call refresh_hw_device — that's the labtools property-
# update path that segfaulted on the wedged device. Usage:
#   run_vivado.sh -c "vivado -mode batch -source program_recover.tcl -tclargs <pdi-without-ext>"
set stem [lindex $::argv 0]
set pdi "${stem}.pdi"
if { ![file exists $pdi] } { puts "ERROR: $pdi not found"; exit 1 }
open_hw_manager
connect_hw_server -allow_non_jtag
set t [lindex [get_hw_targets *XFL1EZVSAG4S*] 0]
current_hw_target $t
open_hw_target $t
set dev ""
foreach d [get_hw_devices] { if { [string match xcv80* [get_property PART $d]] } { set dev $d; break } }
if { $dev eq "" } { set dev [lindex [get_hw_devices] 0] }
current_hw_device $dev
puts "Programming $pdi onto $dev (no pre-refresh)"
set_property PROBES.FILE {} $dev
set_property FULL_PROBES.FILE {} $dev
set_property PROGRAM.FILE $pdi $dev
program_hw_devices $dev
puts "DONE"
exit
