#=============================================================================
# SpyGlass CDC Flow Script
#
# Usage:
#   sg_shell -tcl scripts/run_cdc.tcl -batch
#
# This script runs both CDC setup and CDC verify goals on the
# example CDC design files. The constraint file defines clock domains
# and their relationships — this is critical for accurate CDC analysis.
#=============================================================================

puts "=========================================="
puts " SpyGlass CDC Flow"
puts "=========================================="

#--- Project Setup ---
new_project cdc_example -force

set_option projectwdir  ./spyglass_output/cdc
set_option language_mode mixed
set_option enableSV     yes
set_option sort_rpt     yes

#--- Read Source Files ---
# CDC basics
read_file -type verilog examples/cdc_basics/missing_sync.v
read_file -type verilog examples/cdc_basics/two_ff_sync.v
read_file -type verilog examples/cdc_basics/multibit_cdc.v
read_file -type verilog examples/cdc_basics/cdc_top.v

# Synchronizer library
read_file -type verilog examples/cdc_synchronizers/sync_2ff.v
read_file -type verilog examples/cdc_synchronizers/sync_pulse.v
read_file -type verilog examples/cdc_synchronizers/sync_handshake.v
read_file -type verilog examples/cdc_synchronizers/sync_gray_fifo.v

# Advanced CDC scenarios
read_file -type verilog examples/cdc_advanced/reconvergence.v
read_file -type verilog examples/cdc_advanced/combo_on_cdc.v
read_file -type verilog examples/cdc_advanced/reset_cdc.v

#--- Set Top Module ---
set_option top cdc_top

#--- Read Constraints (CRITICAL for CDC) ---
# SDC defines clocks; SGDC defines domain relationships
read_file -type sdc  constraints/clocks.sdc
read_file -type sgdc constraints/cdc_constraints.sgdc

#--- Stage 1: CDC Setup ---
# Verifies that constraints are correct and clocks are properly defined.
# Fix any issues here before proceeding to cdc_verify.
puts "\n--- Stage 1: CDC Setup Check ---"
current_goal cdc/cdc_setup
run_goal

write_report -output spyglass_output/cdc/cdc_setup_report.rpt -report summary

#--- Stage 2: CDC Verify ---
# Performs full crossing analysis: finds unsynchronized crossings,
# reconvergence, multi-bit issues, combo on CDC, etc.
puts "\n--- Stage 2: CDC Verify ---"
current_goal cdc/cdc_verify

# Uncomment to enable Reset Domain Crossing (RDC) analysis:
# set_goal_option rdc yes

run_goal

#--- Generate Reports ---
puts "\nGenerating reports..."
write_report -output spyglass_output/cdc/cdc_summary.rpt      -report summary
write_report -output spyglass_output/cdc/cdc_violations.rpt   -report violations
write_report -output spyglass_output/cdc/cdc_crossings.rpt    -report crossings
write_report -output spyglass_output/cdc/cdc_clock_domains.rpt -report clock_domains

#--- Print Summary ---
puts "\n=========================================="
puts " CDC Run Complete"
puts " Reports: spyglass_output/cdc/"
puts "=========================================="

#--- Cleanup ---
save_project
close_project
