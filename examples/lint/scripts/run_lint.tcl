##-- ==========================================================================
##-- SpyGlass Lint TCL Script
##-- ==========================================================================
##-- A more flexible TCL-based lint script that can be customized.
##-- Usage: spyglass -tcl run_lint.tcl -batch
##-- ==========================================================================

##-- Configure project
set_option projectwdir ./spyglass_work

##-- Read design files
read_file -type verilog ../rtl/counter_with_issues.v
read_file -type verilog ../rtl/fsm_with_issues.v
read_file -type verilog ../rtl/memory_controller.v

##-- Set top module
set_option top counter_with_issues

##-- Configure lint rules
##-- Disable overly noisy rules if needed (uncomment as needed)
# set_rule_status -disable W_0100
# set_rule_status -disable NamingConvention

##-- Enable additional rules (uncomment as needed)
# set_rule_status -enable W_0789

##-- Set reporting options
set_option report_severity {Error Warning}

##-- Run basic lint
current_goal lint/lint_rtl
run_goal

##-- Print summary
puts "=============================================="
puts " Lint analysis complete."
puts " Check spyglass_work/ for detailed reports."
puts "=============================================="

##-- Optional: run enhanced lint as well
# current_goal lint/lint_rtl_enhanced
# run_goal

##-- Exit
exit
