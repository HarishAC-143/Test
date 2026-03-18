##============================================================================
## run_lint.tcl -- SpyGlass Lint Batch Script
##
## Runs structural Lint analysis on the design and generates a report.
##
## Usage:
##   spyglass -tcl run_lint.tcl
##
## Customize the file list, top module, and report paths as needed.
##============================================================================

puts "================================================================"
puts " SpyGlass Lint -- Batch Run"
puts "================================================================"

##----------------------------------------------
## 1. Read design files
##----------------------------------------------
read_file -type verilog {
    ../examples/lint/lint_violations_fixed.v
}

##----------------------------------------------
## 2. Set top module
##----------------------------------------------
set_option top lint_violations_fixed

##----------------------------------------------
## 3. Enable SystemVerilog (if needed)
##----------------------------------------------
set_option enableSV yes
set_option language_mode mixed

##----------------------------------------------
## 4. Read waivers (optional)
##----------------------------------------------
read_file -type waiver ../waivers/lint_waivers.swl

##----------------------------------------------
## 5. Run Lint goal
##----------------------------------------------
## lint/lint_rtl         -- Basic structural lint
## lint/lint_rtl_enhanced -- Extended rule set (more checks)

current_goal lint/lint_rtl
run_goal

##----------------------------------------------
## 6. Save report
##----------------------------------------------
save_report -file ../reports/lint_report.rpt

puts ""
puts " Lint run complete. Report saved to ../reports/lint_report.rpt"
puts "================================================================"

##----------------------------------------------
## 7. Exit
##----------------------------------------------
exit
