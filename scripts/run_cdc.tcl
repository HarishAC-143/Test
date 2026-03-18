##-----------------------------------------------------------------------------
## SpyGlass CDC — TCL Script for sg_shell
##-----------------------------------------------------------------------------
## Run with:  sg_shell -tcl scripts/run_cdc.tcl
##
## This script demonstrates a complete CDC analysis flow:
##   1. Read design and constraints
##   2. Run cdc_setup to verify clock tree
##   3. Run cdc_verify for full CDC analysis
##   4. Generate reports including CDC crossing matrix
##-----------------------------------------------------------------------------

puts "============================================================"
puts " SpyGlass CDC Analysis — Tutorial Examples"
puts "============================================================"

##=============================================================================
## Step 1: Read Design Files
##=============================================================================
puts "\n--- Reading design files ---"

read_file -type verilog examples/practical/reset_synchronizer.v
read_file -type verilog examples/practical/async_fifo.v
read_file -type verilog examples/practical/multi_clock_system.v

## Read constraint files — critical for CDC analysis
read_file -type sgdc constraints/cdc_constraints.sgdc
read_file -type sdc  constraints/timing.sdc

##=============================================================================
## Step 2: Set Top Module and Options
##=============================================================================
set_option top multi_clock_system
set_option projectwdir ./spyglass_output/cdc
set_option language_mode mixed
set_option enableSV yes

## Apply CDC waivers (if any)
# read_file -type waiver waivers/cdc_waivers.swl

##=============================================================================
## Step 3: CDC Setup — Verify Clock Tree
##=============================================================================
## cdc_setup validates that:
##   - All clocks are properly defined in constraints
##   - Clock relationships (sync/async) are specified
##   - No missing clock definitions
##
## Always run cdc_setup BEFORE cdc_verify!

puts "\n--- Running cdc/cdc_setup goal ---"
current_goal cdc/cdc_setup
set_goal_option default
run_goal

puts "\n--- CDC Setup Results ---"
report_results -type summary

##=============================================================================
## Step 4: CDC Verify — Full Analysis
##=============================================================================
## cdc_verify performs:
##   - Clock domain crossing identification
##   - Synchronizer detection and validation
##   - Multi-bit crossing scheme verification
##   - Reconvergence analysis
##   - Glitch detection

puts "\n--- Running cdc/cdc_verify goal ---"
current_goal cdc/cdc_verify
set_goal_option default
run_goal

##=============================================================================
## Step 5: Report Results
##=============================================================================
puts "\n--- CDC Verification Summary ---"
report_results -type summary

puts "\n--- CDC Violations (Errors and Warnings) ---"
report_results -type detail -severity {Error Warning}

## Write reports
puts "\n--- Writing reports ---"
write_report -type summary   -output spyglass_output/cdc/cdc_summary.rpt
write_report -type detail    -output spyglass_output/cdc/cdc_detail.rpt

## CDC crossing matrix — shows all domain crossings in tabular form
## Extremely useful for documentation and review
puts "\n--- Generating CDC crossing matrix ---"
# report_cdc_matrix -output spyglass_output/cdc/cdc_matrix.csv

## Clock tree report
puts "\n--- Clock tree ---"
# report_clock_tree

puts "\n============================================================"
puts " CDC analysis complete. Check spyglass_output/cdc/"
puts "============================================================"

## Exit sg_shell
exit
