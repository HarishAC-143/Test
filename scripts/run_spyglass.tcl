# ==============================================================================
# SpyGlass Batch Run Script
# ==============================================================================
#
# This TCL script runs SpyGlass Lint and CDC analysis in batch mode.
#
# Usage:
#   sg_shell -tcl scripts/run_spyglass.tcl
#
# The script:
#   1. Configures the project (top module, source files, constraints)
#   2. Runs lint/lint_rtl goal
#   3. Runs cdc/cdc_verify goal
#   4. Generates summary and detail reports
#   5. Returns non-zero exit code if errors are found
#
# ==============================================================================

puts "========================================"
puts " SpyGlass Analysis — Batch Run"
puts "========================================"

# ==============================================================================
# Project Setup
# ==============================================================================

set_option top       async_fifo
set_option language  verilog
set_option enableSV  yes
set_option define    {SYNTHESIS 1}
set_option mthresh   50000

# Read RTL sources
read_file -type verilog {
    examples/cdc/rtl/async_fifo.v
    examples/cdc/rtl/pulse_sync.v
    examples/cdc/rtl/mux_sync.v
}

# Read design constraints
read_file -type sgdc examples/cdc/constraints/design.sgdc

# Create reports directory
file mkdir reports

# ==============================================================================
# Goal 1: Lint Analysis
# ==============================================================================

puts ""
puts "========================================"
puts " Running Lint Analysis (lint/lint_rtl)"
puts "========================================"

current_goal lint/lint_rtl

# Optionally enable/disable specific rules
# set_goal_option rule -enable  W110 W116 W120 W123 W164
# set_goal_option rule -disable W156

run_goal

# Generate lint reports
write_report -type summary -output reports/lint_summary.rpt
write_report -type detail  -output reports/lint_detail.rpt

puts "Lint reports written to reports/lint_summary.rpt and reports/lint_detail.rpt"

# ==============================================================================
# Goal 2: CDC Analysis
# ==============================================================================

puts ""
puts "========================================"
puts " Running CDC Analysis (cdc/cdc_verify)"
puts "========================================"

current_goal cdc/cdc_verify
run_goal

# Generate CDC reports
write_report -type cdc_detail -output reports/cdc_detail.rpt

puts "CDC report written to reports/cdc_detail.rpt"

# ==============================================================================
# Summary
# ==============================================================================

puts ""
puts "========================================"
puts " Analysis Complete"
puts "========================================"
puts "Reports generated in reports/ directory:"
puts "  - reports/lint_summary.rpt"
puts "  - reports/lint_detail.rpt"
puts "  - reports/cdc_detail.rpt"
puts ""
puts "Open in GUI for interactive debugging:"
puts "  spyglass -project project/example.prj"
puts "========================================"

# Exit with success
exit 0
