##============================================================================
## run_cdc.tcl -- SpyGlass CDC Batch Script
##
## Runs Clock Domain Crossing analysis on the design and generates a report.
##
## Usage:
##   spyglass -tcl run_cdc.tcl
##
## Customize the file list, constraints, and report paths as needed.
##============================================================================

puts "================================================================"
puts " SpyGlass CDC -- Batch Run"
puts "================================================================"

##----------------------------------------------
## 1. Read design files
##----------------------------------------------
read_file -type verilog {
    ../examples/cdc/cdc_violations_fixed.v
}

read_file -type systemverilog {
    ../examples/cdc/synchronizers/sync_2ff.sv
    ../examples/cdc/synchronizers/sync_pulse.sv
    ../examples/cdc/synchronizers/sync_bus_mux.sv
    ../examples/cdc/synchronizers/async_fifo.sv
    ../examples/cdc/synchronizers/reset_sync.sv
    ../examples/cdc/synchronizers/handshake_sync.sv
}

##----------------------------------------------
## 2. Set top module
##----------------------------------------------
set_option top cdc_violations_fixed

##----------------------------------------------
## 3. Enable SystemVerilog
##----------------------------------------------
set_option enableSV yes
set_option language_mode mixed

##----------------------------------------------
## 4. Read CDC constraints (SGDC)
##----------------------------------------------
read_file -type sgdc ../constraints/cdc.sgdc

##----------------------------------------------
## 5. Read waivers (optional)
##----------------------------------------------
read_file -type waiver ../waivers/cdc_waivers.swl

##----------------------------------------------
## 6. Run CDC goals
##----------------------------------------------
## cdc/cdc_verify        -- Full CDC verification (structural + protocol)
## cdc/cdc_verify_struct -- Structural-only (faster, fewer false positives)

current_goal cdc/cdc_verify_struct
run_goal

current_goal cdc/cdc_verify
run_goal

##----------------------------------------------
## 7. Save report
##----------------------------------------------
save_report -file ../reports/cdc_report.rpt

puts ""
puts " CDC run complete. Report saved to ../reports/cdc_report.rpt"
puts "================================================================"

##----------------------------------------------
## 8. Exit
##----------------------------------------------
exit
