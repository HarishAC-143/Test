# ============================================================
# Example 11: TimeQuest Timing Analysis Tcl Script
# ============================================================
# Run this script in the Quartus TimeQuest Timing Analyzer
# Tcl console to generate comprehensive timing reports.
#
# Usage:
#   quartus_sta -t examples/11_timing_analysis_script.tcl <project_name>
#
# Or from the TimeQuest GUI:
#   Tcl Console > source examples/11_timing_analysis_script.tcl
#
# ============================================================

# ============================================================
# Configuration
# ============================================================

set PROJECT_NAME [lindex $quartus(args) 0]
set TOP_ENTITY   $PROJECT_NAME
set REPORT_DIR   "timing_reports"

# Create report directory
file mkdir $REPORT_DIR

puts "=========================================="
puts " TimeQuest Timing Analysis Script"
puts " Project: $PROJECT_NAME"
puts "=========================================="

# ============================================================
# Step 1: Create Timing Netlist
# ============================================================

puts "\n--- Creating Timing Netlist ---"
create_timing_netlist

# ============================================================
# Step 2: Read SDC Constraints
# ============================================================

puts "\n--- Reading SDC File ---"
read_sdc

# ============================================================
# Step 3: Update Timing Netlist
# ============================================================

puts "\n--- Updating Timing Netlist ---"
update_timing_netlist

# ============================================================
# Step 4: Check Constraint Coverage
# ============================================================

puts "\n--- Checking Timing Constraints ---"
set check_result [check_timing -include {no_clock unconstrained_endpoint no_input_delay no_output_delay}]
puts $check_result

# Write check_timing to file
set fp [open "$REPORT_DIR/check_timing.rpt" w]
puts $fp $check_result
close $fp

# ============================================================
# Step 5: Report All Clocks
# ============================================================

puts "\n--- Reporting Clocks ---"
set clk_report [report_clocks]
puts $clk_report

set fp [open "$REPORT_DIR/clocks.rpt" w]
puts $fp $clk_report
close $fp

# ============================================================
# Step 6: Report Clock Transfers
# ============================================================

puts "\n--- Reporting Clock Transfers ---"
set xfer_report [report_clock_transfers]
puts $xfer_report

set fp [open "$REPORT_DIR/clock_transfers.rpt" w]
puts $fp $xfer_report
close $fp

# ============================================================
# Step 7: Setup Timing Analysis (Worst 50 paths)
# ============================================================

puts "\n--- Setup Timing Analysis ---"

# Overall setup summary
set setup_summary [report_timing -setup -npaths 1 -detail summary]
puts $setup_summary

# Detailed worst 50 setup paths
set setup_detail [report_timing -setup -npaths 50 -detail full_path -multi_corner]
set fp [open "$REPORT_DIR/setup_timing.rpt" w]
puts $fp $setup_detail
close $fp

# Per-clock setup analysis
foreach_in_collection clk [get_clocks *] {
    set clk_name [get_clock_info -name $clk]
    set clk_report [report_timing -setup -npaths 10 \
        -from_clock $clk_name -to_clock $clk_name \
        -detail full_path]
    set fp [open "$REPORT_DIR/setup_${clk_name}.rpt" w]
    puts $fp $clk_report
    close $fp
}

# ============================================================
# Step 8: Hold Timing Analysis (Worst 50 paths)
# ============================================================

puts "\n--- Hold Timing Analysis ---"

set hold_detail [report_timing -hold -npaths 50 -detail full_path -multi_corner]
set fp [open "$REPORT_DIR/hold_timing.rpt" w]
puts $fp $hold_detail
close $fp

# ============================================================
# Step 9: Recovery/Removal Analysis
# ============================================================

puts "\n--- Recovery/Removal Analysis ---"

set recovery_report [report_timing -recovery -npaths 20 -detail full_path]
set fp [open "$REPORT_DIR/recovery_timing.rpt" w]
puts $fp $recovery_report
close $fp

set removal_report [report_timing -removal -npaths 20 -detail full_path]
set fp [open "$REPORT_DIR/removal_timing.rpt" w]
puts $fp $removal_report
close $fp

# ============================================================
# Step 10: Minimum Pulse Width Analysis
# ============================================================

puts "\n--- Minimum Pulse Width Analysis ---"

set mpw_report [report_min_pulse_width -npaths 20]
set fp [open "$REPORT_DIR/min_pulse_width.rpt" w]
puts $fp $mpw_report
close $fp

# ============================================================
# Step 11: Unconstrained Paths
# ============================================================

puts "\n--- Unconstrained Path Analysis ---"

set ucd_report [report_ucd -summary]
set fp [open "$REPORT_DIR/unconstrained.rpt" w]
puts $fp $ucd_report
close $fp

# ============================================================
# Step 12: Timing Summary
# ============================================================

puts "\n=========================================="
puts " TIMING SUMMARY"
puts "=========================================="

# Collect worst slack per clock
puts "\nSetup Slack Summary:"
puts [format "%-30s %10s %10s %10s" "Clock" "Required" "Actual" "Slack"]
puts [string repeat "-" 62]

foreach_in_collection clk [get_clocks *] {
    set clk_name [get_clock_info -name $clk]
    set period   [get_clock_info -period $clk]

    set paths [get_timing_paths -setup -npaths 1 \
        -from_clock $clk_name -to_clock $clk_name]

    if {[get_collection_size $paths] > 0} {
        foreach_in_collection path $paths {
            set slack [get_path_info -slack $path]
            set arrival [get_path_info -data_arrival_time $path]
            puts [format "%-30s %10.3f %10.3f %10.3f" \
                $clk_name $period $arrival $slack]
        }
    }
}

# ============================================================
# Step 13: Save Final Report
# ============================================================

puts "\n--- Reports saved to $REPORT_DIR/ ---"
puts "  check_timing.rpt"
puts "  clocks.rpt"
puts "  clock_transfers.rpt"
puts "  setup_timing.rpt"
puts "  hold_timing.rpt"
puts "  recovery_timing.rpt"
puts "  removal_timing.rpt"
puts "  min_pulse_width.rpt"
puts "  unconstrained.rpt"
puts "  setup_<clock_name>.rpt (per-clock)"

puts "\n=========================================="
puts " Analysis Complete"
puts "=========================================="
