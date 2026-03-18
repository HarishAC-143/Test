# =============================================================================
# run_regression.tcl — Multi-configuration regression orchestrator
# =============================================================================
# Usage:
#   quartus_sh -t run_regression.tcl [config_file]
#
# Example:
#   quartus_sh -t run_regression.tcl regression_config.tcl
#
# Iterates over multiple device/parameter combinations, compiles each,
# and produces a summary report.
# =============================================================================

package require ::quartus::project
package require ::quartus::flow

# ---------------------------------------------------------------------------
# Default regression configuration
# ---------------------------------------------------------------------------

# Devices to test
set regression_devices {
    {cyclone_v   "5CEBA4F23C7"   "Cyclone V"}
}

# Parameter sweeps (each set creates a separate build)
set regression_params {
    {default     {COUNTER_WIDTH 8  FIFO_DEPTH 16 ALU_WIDTH 16}}
    {wide_data   {COUNTER_WIDTH 16 FIFO_DEPTH 16 ALU_WIDTH 32}}
    {deep_fifo   {COUNTER_WIDTH 8  FIFO_DEPTH 64 ALU_WIDTH 16}}
}

# Source files
set source_dir    "../rtl"
set constraint_dir "../constraints"
set top_module    "top_wrapper"

# Build directory root
set build_root    "./regression_builds"

# ---------------------------------------------------------------------------
# Load external config if provided
# ---------------------------------------------------------------------------
if {$argc >= 1} {
    set config_file [lindex $argv 0]
    if {[file exists $config_file]} {
        puts "Loading config: $config_file"
        source $config_file
    } else {
        puts "WARNING: Config file '$config_file' not found, using defaults."
    }
}

# ---------------------------------------------------------------------------
# Regression runner
# ---------------------------------------------------------------------------
set results [list]
set start_time [clock seconds]

puts "============================================"
puts "  FPGA Regression Test"
puts "  Time : [clock format $start_time]"
puts "  Top  : $top_module"
puts "============================================"

# Create build root
file mkdir $build_root

foreach dev_config $regression_devices {
    set dev_name  [lindex $dev_config 0]
    set dev_part  [lindex $dev_config 1]
    set dev_desc  [lindex $dev_config 2]

    foreach param_config $regression_params {
        set param_name [lindex $param_config 0]
        set params     [lindex $param_config 1]

        set build_name "${dev_name}_${param_name}"
        set build_dir  "${build_root}/${build_name}"

        puts ""
        puts "============================================"
        puts "  Build: $build_name"
        puts "  Device: $dev_part ($dev_desc)"
        puts "  Params: $params"
        puts "============================================"

        # Create build directory
        file mkdir $build_dir

        set test_start [clock seconds]
        set test_status "PASS"
        set error_msg ""

        # Create project in the build directory
        if {[catch {
            cd $build_dir

            # Create project
            if {[project_exists $build_name]} {
                project_open $build_name
            } else {
                project_new $build_name
            }

            # Device settings
            set_global_assignment -name FAMILY $dev_desc
            set_global_assignment -name DEVICE $dev_part
            set_global_assignment -name TOP_LEVEL_ENTITY $top_module

            # Add sources
            foreach f [glob -nocomplain -directory "../../$source_dir" *.sv *.v] {
                set ext [file extension $f]
                if {$ext eq ".sv"} {
                    set_global_assignment -name SYSTEMVERILOG_FILE $f
                } else {
                    set_global_assignment -name VERILOG_FILE $f
                }
            }

            # Add constraints
            foreach f [glob -nocomplain -directory "../../$constraint_dir" *.sdc] {
                set_global_assignment -name SDC_FILE $f
            }

            # Apply parameter overrides as Verilog macros
            dict for {pname pval} $params {
                set_global_assignment -name VERILOG_MACRO "${pname}=${pval}"
            }

            # Compilation settings
            set_global_assignment -name OPTIMIZATION_MODE "BALANCED"
            set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

            export_assignments

            # Run compilation
            if {[catch {execute_flow -compile} compile_result]} {
                set test_status "FAIL"
                set error_msg $compile_result
            }

            project_close
            cd ../..

        } overall_error]} {
            set test_status "FAIL"
            set error_msg $overall_error
            catch {project_close}
            catch {cd ../..}
        }

        set test_elapsed [expr {[clock seconds] - $test_start}]

        # Record result
        lappend results [list $build_name $dev_part $param_name $test_status $test_elapsed $error_msg]

        puts "  Result: $test_status (${test_elapsed}s)"
    }
}

# ---------------------------------------------------------------------------
# Summary report
# ---------------------------------------------------------------------------
set total_elapsed [expr {[clock seconds] - $start_time}]
set pass_count 0
set fail_count 0

puts ""
puts "================================================================"
puts "  Regression Summary"
puts "  Total time: ${total_elapsed}s"
puts "================================================================"
puts [format "  %-30s %-15s %-12s %-8s %s" "Build" "Device" "Config" "Status" "Time"]
puts "  -----------------------------------------------------------------------"

foreach r $results {
    set name   [lindex $r 0]
    set device [lindex $r 1]
    set config [lindex $r 2]
    set status [lindex $r 3]
    set elapsed [lindex $r 4]

    puts [format "  %-30s %-15s %-12s %-8s %ss" $name $device $config $status $elapsed]

    if {$status eq "PASS"} {
        incr pass_count
    } else {
        incr fail_count
    }
}

puts "  -----------------------------------------------------------------------"
puts [format "  Total: %d  |  Passed: %d  |  Failed: %d" \
    [expr {$pass_count + $fail_count}] $pass_count $fail_count]

if {$fail_count > 0} {
    puts ""
    puts "  ** REGRESSION FAILED **"
    puts ""
    puts "  Failed builds:"
    foreach r $results {
        if {[lindex $r 3] eq "FAIL"} {
            puts "    - [lindex $r 0]: [lindex $r 5]"
        }
    }
} else {
    puts ""
    puts "  ** REGRESSION PASSED **"
}
puts "================================================================"

# ---------------------------------------------------------------------------
# Write JSON results
# ---------------------------------------------------------------------------
set fp [open "${build_root}/regression_results.json" w]
puts $fp "\{"
puts $fp "  \"timestamp\": \"[clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}]\","
puts $fp "  \"total_time_s\": $total_elapsed,"
puts $fp "  \"pass_count\": $pass_count,"
puts $fp "  \"fail_count\": $fail_count,"
puts $fp "  \"results\": \["

set first 1
foreach r $results {
    if {!$first} { puts $fp "    ," }
    set first 0
    puts $fp "    \{"
    puts $fp "      \"build\": \"[lindex $r 0]\","
    puts $fp "      \"device\": \"[lindex $r 1]\","
    puts $fp "      \"config\": \"[lindex $r 2]\","
    puts $fp "      \"status\": \"[lindex $r 3]\","
    puts $fp "      \"elapsed_s\": [lindex $r 4],"
    puts $fp "      \"error\": \"[lindex $r 5]\""
    puts $fp "    \}"
}

puts $fp "  \]"
puts $fp "\}"
close $fp

puts "Results written to: ${build_root}/regression_results.json"

exit $fail_count
