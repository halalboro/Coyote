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

# Hosts have TWO JTAG cables, one per card, and the serials are PER HOST:
#   rose : U280 217702174005A   V80 XFL1EZVSAG4S
#   clara: U280 21770327N021    V80 XFL1A3A2MN3U
# Pick by image extension, trying every known serial for that card type.
# Override for a new host with:  CYT_JTAG_SERIAL=<serial> program_fpga.sh ...
if { [info exists ::env(CYT_JTAG_SERIAL)] } {
  set target_pats [list "*$::env(CYT_JTAG_SERIAL)*"]
} elseif { [string match *.pdi $imgfile] } {
  set target_pats {*XFL1EZVSAG4S* *XFL1A3A2MN3U*}
} else {
  set target_pats {*217702174005A* *21770327N021*}
}

open_hw_manager
connect_hw_server -allow_non_jtag

set chosen_target ""
foreach _pat $target_pats {
  # -quiet: get_hw_targets ERRORS on no-match instead of returning an empty
  # list, which would abort this loop on the first non-matching serial.
  set targets [get_hw_targets -quiet $_pat]
  if { [llength $targets] > 0 } { set chosen_target [lindex $targets 0]; break }
}
if { $chosen_target eq "" } {
  # Do NOT silently fall back to the first cable: on a two-cable host that can
  # select the U280 and then push a .pdi at it. Fail loudly with the options.
  puts "ERROR: no hw_target matched any of: $target_pats"
  puts "Available targets:"
  foreach t [get_hw_targets -quiet] { puts "  $t" }
  puts "Set CYT_JTAG_SERIAL=<serial> to select one explicitly."
  exit 1
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

# Debug-core / probe refresh is only needed to interact with ILA/VIO cores; it
# is NOT required to program a configuration image, and this is a program-and-
# exit flow with no ILA dashboard. On a card sitting in its base/golden
# personality (e.g. a V80 after a reboot wiped the PL), enumerating the base
# image's debug hub over DPC JTAG can hang:
#     ERROR: [Xicom 50-233] Failed to setup debug cores: Connection timed out
# That must never abort programming, so both refreshes are best-effort. The
# DPC JTAG link itself is already up by this point, and program_hw_devices
# drives the PMC/config path, which is independent of the debug cores.
if { [catch { refresh_hw_device -update_hw_probes false $Device } msg] } {
  puts "WARNING: refresh_hw_device (no probes) failed, continuing to program: $msg"
}
# check if probes file exists
if { [file exists ${bitpath}.ltx] == 1} {
  puts "found ltx file"
  if { [catch { refresh_hw_device $Device } msg] } {
    puts "WARNING: full refresh_hw_device failed (ILA probes unavailable this\
          session), continuing to program: $msg"
  }
  set_property PROBES.FILE ${bitpath}.ltx $Device
  set_property FULL_PROBES.FILE ${bitpath}.ltx $Device
} else {
  set_property PROBES.FILE {} $Device
  set_property FULL_PROBES.FILE {} $Device
}
set_property PROGRAM.FILE $imgfile $Device
program_hw_devices $Device
# NOTE: no post-program refresh_hw_device here. On Versal it races the device
# re-enumeration after program_hw_devices' PMC POR and segfaults Vivado 2025.1
# labtools (XHWCoreObserver::propertyUpdateEventHandler) during shutdown.
# Programming is already complete at this point (program_hw_devices reports
# "DONE bit: HIGH"). If you need ILA probes, refresh separately once the device
# has settled, or use program_recover.tcl.
exit
