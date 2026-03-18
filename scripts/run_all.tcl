#=============================================================================
# SpyGlass Combined Flow Script
#
# Usage:
#   sg_shell -tcl scripts/run_all.tcl -batch
#
# Runs lint and CDC checks sequentially on the full design.
# This is useful for CI/CD integration where both checks must pass.
#=============================================================================

puts "========================================================="
puts " SpyGlass Combined Flow: Lint + CDC"
puts "========================================================="

#--- Project Setup ---
new_project combined_analysis -force

set_option projectwdir  ./spyglass_output/combined
set_option language_mode mixed
set_option enableSV     yes
set_option sort_rpt     yes

#--- Read ALL Source Files ---

# Lint examples
read_file -type verilog examples/lint_basics/counter.v
read_file -type verilog examples/lint_basics/latch_inference.v
read_file -type verilog examples/lint_basics/width_mismatch.v
read_file -type verilog examples/lint_basics/blocking_nonblocking.v
read_file -type verilog examples/lint_basics/fsm.v
read_file -type verilog examples/lint_advanced/multidriven.v
read_file -type verilog examples/lint_advanced/array_index_oob.v
read_file -type verilog examples/lint_advanced/case_full_parallel.v

# CDC examples
read_file -type verilog examples/cdc_basics/missing_sync.v
read_file -type verilog examples/cdc_basics/two_ff_sync.v
read_file -type verilog examples/cdc_basics/multibit_cdc.v
read_file -type verilog examples/cdc_basics/cdc_top.v
read_file -type verilog examples/cdc_synchronizers/sync_2ff.v
read_file -type verilog examples/cdc_synchronizers/sync_pulse.v
read_file -type verilog examples/cdc_synchronizers/sync_handshake.v
read_file -type verilog examples/cdc_synchronizers/sync_gray_fifo.v
read_file -type verilog examples/cdc_advanced/reconvergence.v
read_file -type verilog examples/cdc_advanced/combo_on_cdc.v
read_file -type verilog examples/cdc_advanced/reset_cdc.v

#--- Set Top Module ---
set_option top cdc_top

#--- Read Constraints ---
read_file -type sdc    constraints/clocks.sdc
read_file -type sgdc   constraints/lint_constraints.sgdc
read_file -type sgdc   constraints/cdc_constraints.sgdc
read_file -type waiver waivers/lint_waivers.swl

#=================================================================
# Phase 1: Lint
#=================================================================
puts "\n========== Phase 1: Lint =========="
current_goal lint/lint_rtl
run_goal
write_report -output spyglass_output/combined/lint_report.rpt -report violations

#=================================================================
# Phase 2: CDC Setup
#=================================================================
puts "\n========== Phase 2: CDC Setup =========="
current_goal cdc/cdc_setup
run_goal
write_report -output spyglass_output/combined/cdc_setup_report.rpt -report summary

#=================================================================
# Phase 3: CDC Verify
#=================================================================
puts "\n========== Phase 3: CDC Verify =========="
current_goal cdc/cdc_verify
run_goal
write_report -output spyglass_output/combined/cdc_verify_report.rpt -report violations

#--- Final Summary ---
puts "\n========================================================="
puts " Combined Analysis Complete"
puts " Reports: spyglass_output/combined/"
puts "========================================================="

save_project
close_project
