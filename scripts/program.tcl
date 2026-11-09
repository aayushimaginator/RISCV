set bit [expr {[llength $argv] > 0 ? [lindex $argv 0] : "vivado_phase0/phase0.runs/impl_1/soc_top.bit"}]
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7s50*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $bit $dev
program_hw_devices $dev
close_hw_manager
