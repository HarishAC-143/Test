#=============================================================================
# SpyGlass Lint Flow Script
#
# Usage:
#   sg_shell -tcl scripts/run_lint.tcl -batch
#
# This script runs basic lint checks (lint/lint_rtl goal) on the
# example design files. Modify the file list and top module for your
# own designs.
#=============================================================================

puts "=========================================="
puts " SpyGlass Lint Flow"
puts "=========================================="

#--- Project Setup ---
new_project lint_example -force

set_option projectwdir  ./spyglass_output/lint
set_option language_mode mixed
set_option enableSV     yes
set_option sort_rpt     yes

#--- Read Source Files ---
# Lint basics
read_file -type verilog examples/lint_basics/counter.v
read_file -type verilog examples/lint_basics/latch_inference.v
read_file -type verilog examples/lint_basics/width_mismatch.v
read_file -type verilog examples/lint_basics/blocking_nonblocking.v
read_file -type verilog examples/lint_basics/fsm.v

# Lint advanced
read_file -type verilog examples/lint_advanced/multidriven.v
read_file -type verilog examples/lint_advanced/array_index_oob.v
read_file -type verilog examples/lint_advanced/case_full_parallel.v

#--- Set Top Module ---
# Change this to match your design's top module
set_option top counter_top

#--- Read Constraints (Optional) ---
read_file -type sgdc constraints/lint_constraints.sgdc

#--- Select Goal ---
# lint/lint_rtl is the standard structural lint goal
# Other available goals:
#   lint/lint_turbo         - Faster, fewer rules
#   lint/lint_rtl_enhanced  - More thorough checks
#   lint/lint_abstract      - For IP black boxes
current_goal lint/lint_rtl

#--- Configure Goal Options ---
# Uncomment to customize severity handling:
# set_goal_option addrules  {W_116 W_164 W_240 W_287 W_391}
# set_goal_option delrules  {W_123}
# set_goal_option severity  {W_116=Error}

#--- Read Waivers ---
read_file -type waiver waivers/lint_waivers.swl

#--- Run ---
puts "\nRunning lint analysis..."
run_goal

#--- Generate Reports ---
puts "\nGenerating reports..."
write_report -output spyglass_output/lint/lint_summary.rpt    -report summary
write_report -output spyglass_output/lint/lint_violations.rpt -report violations
write_report -output spyglass_output/lint/lint_waivers.rpt    -report waiver

#--- Print Summary ---
puts "\n=========================================="
puts " Lint Run Complete"
puts " Reports: spyglass_output/lint/"
puts "=========================================="

#--- Cleanup ---
save_project
close_project
