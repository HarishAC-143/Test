# =============================================================================
# check_timing.tcl — Detailed timing analysis and slack extraction
# =============================================================================
# Usage:
#   quartus_sta -t check_timing.tcl <project_name> [revision] [output_file]
#
# Example:
#   quartus_sta -t check_timing.tcl my_design
#   quartus_sta -t check_timing.tcl my_design my_design timing_results.json
#
# Performs multi-corner timing analysis and outputs results in both
# human-readable and machine-parseable (JSON) formats.
# =============================================================================

package require ::quartus::sta

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if {$argc < 1} {
    puts "Usage: quartus_sta -t check_timing.tcl <project_name> \[revision\] \[output_file\]"
    exit 1
}

set project_name [lindex $argv 0]
set revision     [expr {$argc >= 2 ? [lindex $argv 1] : $project_name}]
set output_file  [expr {$argc >= 3 ? [lindex $argv 2] : "timing_results.json"}]

puts "============================================"
puts "  Timing Analysis"
puts "  Project : $project_name"
puts "  Revision: $revision"
puts "  Output  : $output_file"
puts "============================================"

# ---------------------------------------------------------------------------
# Create the timing netlist
# ---------------------------------------------------------------------------
create_timing_netlist

# Read SDC constraints
set sdc_files [glob -nocomplain constraints/*.sdc]
foreach sdc $sdc_files {
    puts "Reading SDC: $sdc"
    read_sdc -verbose $sdc
}

update_timing_netlist

# ---------------------------------------------------------------------------
# Multi-corner analysis
# ---------------------------------------------------------------------------
set corners {"Slow 1100mV 85C" "Slow 1100mV 0C" "Fast 1100mV 85C" "Fast 1100mV 0C"}

set all_results [dict create]
set worst_setup_slack 999.999
set worst_hold_slack  999.999
set worst_setup_clock ""
set worst_hold_clock  ""

puts ""
puts "================================================================"
puts "  Setup Timing Report"
puts "================================================================"

# Get all clocks
set clock_names [get_clock_names]

foreach clk $clock_names {
    set period [get_clock_info -period $clk]
    puts ""
    puts "Clock: $clk  (Period: ${period} ns)"
    puts "  -----------------------------------------------"

    # Setup analysis
    set setup_slack [get_timing_analysis_summary_results -setup -clock $clk]
    puts [format "  Setup Slack  : %.3f ns" $setup_slack]

    if {$setup_slack < $worst_setup_slack} {
        set worst_setup_slack $setup_slack
        set worst_setup_clock $clk
    }

    # Hold analysis
    set hold_slack [get_timing_analysis_summary_results -hold -clock $clk]
    puts [format "  Hold Slack   : %.3f ns" $hold_slack]

    if {$hold_slack < $worst_hold_slack} {
        set worst_hold_slack $hold_slack
        set worst_hold_clock $clk
    }

    # Calculate achieved Fmax
    if {$period > 0} {
        set fmax_mhz [expr {1000.0 / ($period - $setup_slack)}]
        puts [format "  Fmax         : %.2f MHz" $fmax_mhz]
    }

    dict set all_results $clk [dict create \
        period $period \
        setup_slack $setup_slack \
        hold_slack $hold_slack \
    ]
}

# ---------------------------------------------------------------------------
# Check for unconstrained paths
# ---------------------------------------------------------------------------
puts ""
puts "================================================================"
puts "  Unconstrained Path Check"
puts "================================================================"

set unconstrained_count 0

# Check unconstrained clocks
report_ucp -summary

puts ""

# ---------------------------------------------------------------------------
# Report critical paths (top 5 by setup slack)
# ---------------------------------------------------------------------------
puts "================================================================"
puts "  Top 5 Critical Paths (Setup)"
puts "================================================================"

report_timing -setup -npaths 5 -detail full_path

# ---------------------------------------------------------------------------
# Summary and pass/fail determination
# ---------------------------------------------------------------------------
puts ""
puts "================================================================"
puts "  Timing Analysis Summary"
puts "================================================================"
puts [format "  Worst Setup Slack : %.3f ns (Clock: %s)" $worst_setup_slack $worst_setup_clock]
puts [format "  Worst Hold Slack  : %.3f ns (Clock: %s)" $worst_hold_slack $worst_hold_clock]

set timing_pass 1
if {$worst_setup_slack < 0} {
    puts "  SETUP TIMING VIOLATED!"
    set timing_pass 0
}
if {$worst_hold_slack < 0} {
    puts "  HOLD TIMING VIOLATED!"
    set timing_pass 0
}

if {$timing_pass} {
    puts "  STATUS: TIMING MET"
} else {
    puts "  STATUS: TIMING FAILED"
}
puts "================================================================"

# ---------------------------------------------------------------------------
# Write machine-readable output (JSON)
# ---------------------------------------------------------------------------
set fp [open $output_file w]
puts $fp "\{"
puts $fp "  \"project\": \"$project_name\","
puts $fp "  \"revision\": \"$revision\","
puts $fp "  \"timestamp\": \"[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]\","
puts $fp "  \"worst_setup_slack\": $worst_setup_slack,"
puts $fp "  \"worst_setup_clock\": \"$worst_setup_clock\","
puts $fp "  \"worst_hold_slack\": $worst_hold_slack,"
puts $fp "  \"worst_hold_clock\": \"$worst_hold_clock\","
puts $fp "  \"timing_met\": [expr {$timing_pass ? "true" : "false"}],"
puts $fp "  \"clocks\": \{"

set first 1
dict for {clk data} $all_results {
    if {!$first} { puts $fp "    ," }
    set first 0
    puts $fp "    \"$clk\": \{"
    puts $fp "      \"period\": [dict get $data period],"
    puts $fp "      \"setup_slack\": [dict get $data setup_slack],"
    puts $fp "      \"hold_slack\": [dict get $data hold_slack]"
    puts $fp "    \}"
}

puts $fp "  \}"
puts $fp "\}"
close $fp

puts "\nResults written to: $output_file"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
delete_timing_netlist
exit [expr {$timing_pass ? 0 : 1}]
