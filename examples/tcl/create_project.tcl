# =============================================================================
# create_project.tcl — Create a Quartus Prime project from scratch
# =============================================================================
# Usage:
#   quartus_sh -t create_project.tcl <project_name> <device> <top_module> [src_dir]
#
# Example:
#   quartus_sh -t create_project.tcl my_design 5CEBA4F23C7 top_wrapper ./rtl
# =============================================================================

package require ::quartus::project
package require ::quartus::flow

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
proc usage {} {
    puts "Usage: quartus_sh -t create_project.tcl <project_name> <device> <top_module> \[src_dir\]"
    puts ""
    puts "Arguments:"
    puts "  project_name  - Name of the Quartus project to create"
    puts "  device        - Target FPGA part number (e.g., 5CEBA4F23C7)"
    puts "  top_module    - Top-level entity name"
    puts "  src_dir       - Directory containing RTL sources (default: ./rtl)"
    exit 1
}

if {$argc < 3} {
    usage
}

set project_name [lindex $argv 0]
set device       [lindex $argv 1]
set top_module   [lindex $argv 2]
set src_dir      [expr {$argc >= 4 ? [lindex $argv 3] : "./rtl"}]

puts "============================================"
puts "  Creating Quartus Project"
puts "  Project : $project_name"
puts "  Device  : $device"
puts "  Top     : $top_module"
puts "  Sources : $src_dir"
puts "============================================"

# ---------------------------------------------------------------------------
# Create the project (overwrite if exists)
# ---------------------------------------------------------------------------
if {[project_exists $project_name]} {
    puts "WARNING: Project '$project_name' already exists. Removing..."
    file delete -force ${project_name}.qpf
    file delete -force ${project_name}.qsf
    file delete -force db
    file delete -force incremental_db
    file delete -force output_files
}

project_new $project_name -overwrite

# ---------------------------------------------------------------------------
# Device and top-level settings
# ---------------------------------------------------------------------------
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name DEVICE $device
set_global_assignment -name TOP_LEVEL_ENTITY $top_module
set_global_assignment -name ORIGINAL_QUARTUS_VERSION "23.1.0"
set_global_assignment -name PROJECT_CREATION_TIME_DATE [clock format [clock seconds] -format "%H:%M:%S %B %d, %Y"]

# ---------------------------------------------------------------------------
# Add source files
# ---------------------------------------------------------------------------
set sv_files [glob -nocomplain -directory $src_dir *.sv]
set v_files  [glob -nocomplain -directory $src_dir *.v]

foreach f [concat $sv_files $v_files] {
    set ext [file extension $f]
    if {$ext eq ".sv"} {
        set_global_assignment -name SYSTEMVERILOG_FILE $f
        puts "  Added SystemVerilog: $f"
    } else {
        set_global_assignment -name VERILOG_FILE $f
        puts "  Added Verilog: $f"
    }
}

if {[llength $sv_files] == 0 && [llength $v_files] == 0} {
    puts "WARNING: No source files found in $src_dir"
}

# ---------------------------------------------------------------------------
# Add constraint files (SDC)
# ---------------------------------------------------------------------------
set sdc_dir "./constraints"
if {[file isdirectory $sdc_dir]} {
    set sdc_files [glob -nocomplain -directory $sdc_dir *.sdc]
    foreach f $sdc_files {
        set_global_assignment -name SDC_FILE $f
        puts "  Added SDC: $f"
    }
}

# ---------------------------------------------------------------------------
# Compilation settings
# ---------------------------------------------------------------------------
set_global_assignment -name OPTIMIZATION_MODE "BALANCED"
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85

# Timing-driven synthesis
set_global_assignment -name OPTIMIZE_HOLD_TIMING "ALL PATHS"
set_global_assignment -name OPTIMIZE_MULTI_CORNER_TIMING ON
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"

# Generate timing reports in TXT format
set_global_assignment -name TIMEQUEST_REPORT_SCRIPT_INCLUDE_DEFAULT_ANALYSIS ON
set_global_assignment -name TIMEQUEST_MULTICORNER_ANALYSIS ON

# EDA tool settings for ModelSim simulation
set_global_assignment -name EDA_SIMULATION_TOOL "ModelSim (SystemVerilog)"
set_global_assignment -name EDA_OUTPUT_DATA_FORMAT "SYSTEMVERILOG HDL" -section_id eda_simulation
set_global_assignment -name EDA_TIME_SCALE "1 ps" -section_id eda_simulation

# Output directory
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

# ---------------------------------------------------------------------------
# Close the project
# ---------------------------------------------------------------------------
export_assignments
project_close

puts ""
puts "Project '$project_name' created successfully."
puts "============================================"
