# =============================================================================
# compile_design.tcl — Run full Quartus Prime compilation flow
# =============================================================================
# Usage:
#   quartus_sh -t compile_design.tcl <project_name> [revision]
#
# Example:
#   quartus_sh -t compile_design.tcl my_design
#   quartus_sh -t compile_design.tcl my_design rev2
#
# Runs: Analysis & Synthesis → Fitter → Timing Analysis → Assembler
# Returns non-zero exit code on any stage failure.
# =============================================================================

package require ::quartus::project
package require ::quartus::flow

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if {$argc < 1} {
    puts "Usage: quartus_sh -t compile_design.tcl <project_name> \[revision\]"
    exit 1
}

set project_name [lindex $argv 0]
set revision     [expr {$argc >= 2 ? [lindex $argv 1] : $project_name}]

# ---------------------------------------------------------------------------
# Utility: run a stage and check the result
# ---------------------------------------------------------------------------
proc run_stage {stage_name command project {extra_args ""}} {
    puts ""
    puts "================================================================"
    puts "  Stage: $stage_name"
    puts "  Time:  [clock format [clock seconds]]"
    puts "================================================================"

    set start_time [clock seconds]

    if {[catch {execute_flow -$command} result]} {
        set elapsed [expr {[clock seconds] - $start_time}]
        puts "FAILED: $stage_name after ${elapsed}s"
        puts "  Error: $result"
        return 1
    }

    set elapsed [expr {[clock seconds] - $start_time}]
    puts "PASSED: $stage_name completed in ${elapsed}s"
    return 0
}

# ---------------------------------------------------------------------------
# Utility: extract resource usage from the compilation report
# ---------------------------------------------------------------------------
proc report_resources {project revision} {
    puts ""
    puts "================================================================"
    puts "  Resource Usage Summary"
    puts "================================================================"

    if {[catch {
        load_package report
        load_report -file "${project}.fit.rpt"
    } err]} {
        puts "  (Could not load fitter report: $err)"
        return
    }

    set panels [get_report_panel_names]
    foreach panel $panels {
        if {[string match "*Fitter Summary*" $panel]} {
            set rows [get_number_of_rows -name $panel]
            for {set i 0} {$i < $rows} {incr i} {
                set name [get_report_panel_data -name $panel -row $i -col 0]
                set val  [get_report_panel_data -name $panel -row $i -col 1]
                puts [format "  %-40s : %s" $name $val]
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Open project
# ---------------------------------------------------------------------------
if {![project_exists $project_name]} {
    puts "ERROR: Project '$project_name' does not exist."
    exit 1
}

project_open $project_name -revision $revision
puts "Opened project: $project_name (revision: $revision)"

# ---------------------------------------------------------------------------
# Run compilation stages
# ---------------------------------------------------------------------------
set overall_status 0
set stage_results [dict create]

# Stage 1: Analysis & Synthesis
set rc [run_stage "Analysis & Synthesis" "analysis_and_synthesis" $project_name]
dict set stage_results "analysis_and_synthesis" $rc
if {$rc != 0} {
    set overall_status 1
    puts "\nAborting: Analysis & Synthesis failed."
    project_close
    exit $overall_status
}

# Stage 2: Fitter (Place & Route)
set rc [run_stage "Fitter" "fitter" $project_name]
dict set stage_results "fitter" $rc
if {$rc != 0} {
    set overall_status 1
    puts "\nAborting: Fitter failed."
    project_close
    exit $overall_status
}

# Stage 3: Timing Analysis
set rc [run_stage "Timing Analysis" "timing_analysis" $project_name]
dict set stage_results "timing_analysis" $rc
if {$rc != 0} {
    set overall_status 1
}

# Stage 4: Assembler
set rc [run_stage "Assembler" "assembler" $project_name]
dict set stage_results "assembler" $rc
if {$rc != 0} {
    set overall_status 1
}

# ---------------------------------------------------------------------------
# Report summary
# ---------------------------------------------------------------------------
report_resources $project_name $revision

puts ""
puts "================================================================"
puts "  Compilation Summary"
puts "================================================================"
dict for {stage rc} $stage_results {
    set status_str [expr {$rc == 0 ? "PASSED" : "FAILED"}]
    puts [format "  %-30s : %s" $stage $status_str]
}
puts "----------------------------------------------------------------"
if {$overall_status == 0} {
    puts "  OVERALL: PASSED"
} else {
    puts "  OVERALL: FAILED"
}
puts "================================================================"

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
project_close
exit $overall_status
