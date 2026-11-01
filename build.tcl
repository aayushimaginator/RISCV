set part xc7s50csga324-2
set top  soc_top

if {![file exists third_party/picorv32/picorv32.v]} {
    error "third_party/picorv32/picorv32.v missing. Check your git submodule."
}

if {![file exists firmware/firmware.hex]} {
    error "firmware/firmware.hex missing. Run make -C firmware first."
}

file mkdir reports

if {[file exists vivado_phase0]} {
    file delete -force vivado_phase0
}

file copy -force firmware/firmware.hex rtl/firmware.hex

create_project phase0 ./vivado_phase0 -part $part -force

set_property target_language Verilog [current_project]

add_files rtl/ram_lutram.v
add_files rtl/uart_tx.v
add_files rtl/soc_top.v
add_files third_party/picorv32/picorv32.v

# CRITICAL FIX: add the hex file as a project source so Vivado can find it
add_files -norecurse firmware/firmware.hex

add_files -fileset constrs_1 constraints/urbana.xdc

set_property top $top [current_fileset]

update_compile_order -fileset sources_1

set proj_dir [get_property DIRECTORY [current_project]]
file copy -force firmware/firmware.hex $proj_dir/firmware.hex

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed"
}

open_run synth_1

report_utilization \
    -file reports/post_synth_utilization.rpt

report_utilization \
    -hierarchical \
    -hierarchical_depth 3 \
    -file reports/post_synth_utilization_hier.rpt

launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

open_run impl_1

report_utilization \
    -file reports/post_impl_utilization.rpt

report_utilization \
    -hierarchical \
    -hierarchical_depth 3 \
    -file reports/post_impl_utilization_hier.rpt

report_timing_summary \
    -file reports/post_impl_timing_summary.rpt

puts "Bitstream: vivado_phase0/phase0.runs/impl_1/soc_top.bit"
puts "Reports:   reports/"
