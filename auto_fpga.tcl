set bitpath [lindex $::argv 0]
puts "$bitpath"

# Pick image extension: .pdi (Versal, e.g. V80) takes precedence over .bit (UltraScale+)
if { [file exists ${bitpath}.pdi] } {
  set imgfile ${bitpath}.pdi
} elseif { [file exists ${bitpath}.bit] } {
  set imgfile ${bitpath}.bit
} else {
  puts "ERROR: no .pdi or .bit found at ${bitpath}"
  exit 1
}
puts "Programming image: $imgfile"

# Rose has TWO JTAG cables, one per card:
#   - U280 cable serial: 217702174005A   (programs *.bit)
#   - V80  cable serial: XFL1EZVSAG4S    (programs *.pdi)
# Pick the right cable based on the image extension; fall back to first cable.
if { [string match *.pdi $imgfile] } {
  set target_pat "*XFL1EZVSAG4S*"
} else {
  set target_pat "*217702174005A*"
}

open_hw_manager
connect_hw_server -allow_non_jtag

set targets [get_hw_targets $target_pat]
if { [llength $targets] == 0 } {
  puts "WARNING: no hw_target matched $target_pat — falling back to first cable"
  set chosen_target [lindex [get_hw_targets] 0]
} else {
  set chosen_target [lindex $targets 0]
}
puts "Selected hw_target: $chosen_target"
current_hw_target $chosen_target
open_hw_target $chosen_target

# Pick the actual programmable FPGA on this cable (skip non-FPGA JTAG nodes
# like arm_dap_0 on Versal). Match by part name.
if { [string match *.pdi $imgfile] } {
  set part_pat "xcv80*"
} else {
  set part_pat "xcu*"
}
set Device ""
foreach d [get_hw_devices] {
  if { [string match $part_pat [get_property PART $d]] } {
    set Device $d
    break
  }
}
if { $Device eq "" } {
  puts "WARNING: no device with part matching $part_pat — falling back to first hw_device"
  set Device [lindex [get_hw_devices] 0]
}
puts "Selected device: $Device  part=[get_property PART $Device]"

current_hw_device $Device
refresh_hw_device -update_hw_probes false $Device
refresh_hw_device $Device
# check if probes file exists
if { [file exists ${bitpath}.ltx] == 1} {
  puts "found ltx file"
  set_property PROBES.FILE ${bitpath}.ltx $Device
  set_property FULL_PROBES.FILE ${bitpath}.ltx $Device
} else {
  set_property PROBES.FILE {} $Device
  set_property FULL_PROBES.FILE {} $Device
}
set_property PROGRAM.FILE $imgfile $Device
program_hw_devices $Device
refresh_hw_device $Device
exit
