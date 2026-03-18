# ============================================================================
# Example 09: TimeQuest Analysis Scripts
# ============================================================================
# These are Tcl scripts you can run inside the TimeQuest Timing Analyzer
# console (or via quartus_sta) to verify your design's timing.
#
# Usage:
#   In TimeQuest GUI:  Tcl Console -> source this_file.tcl
#   Command line:      quartus_sta -t this_file.tcl my_project
# ============================================================================

# ============================================================================
# Script A: Basic Timing Summary Report
# ============================================================================
proc report_timing_summary {} {
    puts "============================================"
    puts " TIMING ANALYSIS SUMMARY"
    puts "============================================"

    puts "\n--- Defined Clocks ---"
    report_clocks

    puts "\n--- Setup Timing (20 Worst Paths) ---"
    report_timing -setup -npaths 20 -detail full_path

    puts "\n--- Hold Timing (20 Worst Paths) ---"
    report_timing -hold -npaths 20 -detail full_path

    puts "\n--- Minimum Pulse Width ---"
    report_min_pulse_width

    puts "\n--- Unconstrained Paths ---"
    report_ucd

    puts "\n--- Constraint Check ---"
    check_timing

    puts "\n============================================"
    puts " END OF SUMMARY"
    puts "============================================"
}

# ============================================================================
# Script B: Analyze Specific Clock Domain
# ============================================================================
proc analyze_clock_domain {clk_name {num_paths 10}} {
    puts "============================================"
    puts " Analysis for clock: $clk_name"
    puts "============================================"

    puts "\n--- Intra-domain Setup (worst $num_paths paths) ---"
    report_timing -setup -npaths $num_paths -detail full_path \
        -from_clock $clk_name -to_clock $clk_name

    puts "\n--- Intra-domain Hold (worst $num_paths paths) ---"
    report_timing -hold -npaths $num_paths -detail full_path \
        -from_clock $clk_name -to_clock $clk_name
}

# ============================================================================
# Script C: Find Critical Paths Between Two Registers
# ============================================================================
proc debug_path {from_pattern to_pattern} {
    puts "============================================"
    puts " Path from: $from_pattern"
    puts " Path to:   $to_pattern"
    puts "============================================"

    puts "\n--- Setup ---"
    report_timing -setup -npaths 5 -detail full_path \
        -from [get_registers $from_pattern] \
        -to   [get_registers $to_pattern]

    puts "\n--- Hold ---"
    report_timing -hold -npaths 5 -detail full_path \
        -from [get_registers $from_pattern] \
        -to   [get_registers $to_pattern]
}

# ============================================================================
# Script D: Check for Unconstrained I/O Ports
# ============================================================================
proc check_io_constraints {} {
    puts "============================================"
    puts " I/O CONSTRAINT VERIFICATION"
    puts "============================================"

    puts "\n--- All Ports and Their Constraints ---"

    set all_inputs  [get_ports -filter {direction == input}]
    set all_outputs [get_ports -filter {direction == output}]

    puts "\n  Input Ports:"
    foreach_in_collection port $all_inputs {
        set port_name [get_port_info -name $port]
        puts "    $port_name"
    }

    puts "\n  Output Ports:"
    foreach_in_collection port $all_outputs {
        set port_name [get_port_info -name $port]
        puts "    $port_name"
    }

    puts "\n--- Unconstrained I/O ---"
    check_timing
}

# ============================================================================
# Script E: Clock Domain Crossing Report
# ============================================================================
proc report_cdc {} {
    puts "============================================"
    puts " CLOCK DOMAIN CROSSING REPORT"
    puts "============================================"

    puts "\n--- Clock Transfers ---"
    report_clock_transfers

    puts "\n--- Inter-clock Setup Timing ---"
    set all_clocks [get_clocks *]
    foreach_in_collection clk_from $all_clocks {
        set from_name [get_clock_info -name $clk_from]
        foreach_in_collection clk_to $all_clocks {
            set to_name [get_clock_info -name $clk_to]
            if {$from_name ne $to_name} {
                set paths_exist [get_timing_paths \
                    -from_clock $from_name -to_clock $to_name -npaths 1]
                if {[get_collection_size $paths_exist] > 0} {
                    puts "\n  $from_name -> $to_name:"
                    report_timing -setup -npaths 3 \
                        -from_clock $from_name -to_clock $to_name
                }
            }
        }
    }
}

# ============================================================================
# Script F: Full Timing Closure Workflow
# ============================================================================
# Run this after a full Quartus compilation to get a complete timing picture.
#
# Usage: quartus_sta -t this_file.tcl
#        Then call: run_full_analysis "my_project"
# ============================================================================
proc run_full_analysis {project_name} {
    project_open $project_name

    create_timing_netlist
    read_sdc

    update_timing_netlist

    puts "\n=========================================="
    puts " FULL TIMING ANALYSIS: $project_name"
    puts "==========================================\n"

    report_timing_summary
    report_cdc

    set clocks [get_clocks *]
    foreach_in_collection clk $clocks {
        set clk_name [get_clock_info -name $clk]
        analyze_clock_domain $clk_name 5
    }

    delete_timing_netlist
    project_close
}

# ============================================================================
# Usage Instructions
# ============================================================================
# In the TimeQuest Tcl console, source this file and call the procs:
#
#   source timing_analysis_scripts.tcl
#
#   report_timing_summary
#   analyze_clock_domain "sys_clk" 20
#   debug_path "u_ctrl|state_reg*" "u_datapath|out_reg*"
#   check_io_constraints
#   report_cdc
#
# Or from the command line:
#   quartus_sta -t timing_analysis_scripts.tcl
#   Then the proc run_full_analysis can be called with the project name.
