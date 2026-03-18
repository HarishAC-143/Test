##-----------------------------------------------------------------------------
## SpyGlass Lint — TCL Script for sg_shell
##-----------------------------------------------------------------------------
## Run with:  sg_shell -tcl scripts/run_lint.tcl
##
## This script demonstrates how to set up and run SpyGlass Lint from the
## command line using sg_shell (SpyGlass interactive shell).
##-----------------------------------------------------------------------------

puts "============================================================"
puts " SpyGlass Lint Analysis — Tutorial Examples"
puts "============================================================"

##=============================================================================
## Step 1: Read Design Files
##=============================================================================
puts "\n--- Reading design files ---"

## Read all source files
read_file -type sourcelist scripts/filelist.f

## Alternatively, read files individually:
# read_file -type verilog examples/lint_issues/counter_with_issues.v
# read_file -type verilog examples/lint_issues/latch_and_combo.v
# read_file -type verilog examples/lint_issues/fsm_issues.v

##=============================================================================
## Step 2: Set Top Module
##=============================================================================
## Analyze "bad" examples to see violations:
set_option top counter_with_issues

## To analyze the fixed version instead, uncomment:
# set_option top counter_fixed

##=============================================================================
## Step 3: Configure Analysis
##=============================================================================
set_option projectwdir ./spyglass_output/lint
set_option language_mode mixed
set_option enableSV yes

## Treat certain warnings as errors (recommended for critical rules)
set_parameter handle_warns_as_errors {W_LATCH W_COMBO_LOOP W_MULTI_DRIVE}

## Optionally apply waivers
# read_file -type waiver waivers/lint_waivers.swl

##=============================================================================
## Step 4: Run Lint Goal
##=============================================================================
puts "\n--- Running lint/lint_rtl goal ---"
current_goal lint/lint_rtl
set_goal_option default
run_goal

##=============================================================================
## Step 5: Report Results
##=============================================================================
puts "\n--- Lint Summary ---"
report_results -type summary

puts "\n--- Detailed Results (Errors and Warnings) ---"
report_results -type detail -severity {Error Warning}

## Write reports to files
puts "\n--- Writing reports ---"
write_report -type summary   -output spyglass_output/lint/lint_summary.rpt
write_report -type detail    -output spyglass_output/lint/lint_detail.rpt

## Optional: Generate HTML report for review
# write_report -type html -output spyglass_output/lint/lint_report.html

puts "\n============================================================"
puts " Lint analysis complete. Check spyglass_output/lint/"
puts "============================================================"

## Exit sg_shell
exit
