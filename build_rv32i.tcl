set part xc7s50csga324-2
set top  soc_top_rv32i
set proj vivado_rv32i
set rep  reports_rv32i

set srcs {rtl/soc_top_rv32i.v rtl/rv32i_core.v rtl/rv32i_decoder.v rtl/rv32i_immgen.v
          rtl/rv32i_regfile.v rtl/rv32i_alu.v rtl/rv32i_branch_cmp.v rtl/rv32i_lsu.v
          rtl/ram_lutram.v rtl/uart_tx.v rtl/uart_rx.v rtl/seg7_driver.v rtl/mul32.v}
foreach f [concat $srcs {firmware/firmware.hex constraints/urbana.xdc}] {
    if {![file exists $f]} { error "$f missing" }
}

file mkdir $rep
if {[file exists $proj]} { file delete -force $proj }
file copy -force firmware/firmware.hex rtl/firmware.hex

create_project phase1 ./$proj -part $part -force
set_property target_language Verilog [current_project]
foreach f $srcs { add_files $f }
add_files -norecurse firmware/firmware.hex
add_files -fileset constrs_1 constraints/urbana.xdc
set_property top $top [current_fileset]
update_compile_order -fileset sources_1
file copy -force firmware/firmware.hex [get_property DIRECTORY [current_project]]/firmware.hex

launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { error "Synthesis failed" }
open_run synth_1
report_utilization -file $rep/post_synth_utilization.rpt

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} { error "Implementation failed" }
open_run impl_1
report_utilization -file $rep/post_impl_utilization.rpt
report_timing_summary -file $rep/post_impl_timing_summary.rpt
report_timing -max_paths 1 -path_type full -file $rep/critical_path.rpt
puts "Bitstream: $proj/phase1.runs/impl_1/$top.bit"
