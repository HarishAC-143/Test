##-- ==========================================================================
##-- SpyGlass CDC TCL Script
##-- ==========================================================================
##-- A flexible TCL-based CDC analysis script with multiple analysis modes.
##-- Usage: spyglass -tcl run_cdc.tcl -batch
##-- ==========================================================================

##-- Configure project
set_option projectwdir ./spyglass_work

##-- =========================================================================
##-- Read Design Files
##-- =========================================================================
read_file -type verilog ../rtl/cdc_sync_examples.v
read_file -type verilog ../rtl/async_fifo.v
read_file -type verilog ../rtl/pulse_synchronizer.v
read_file -type verilog ../rtl/handshake_sync.v

##-- =========================================================================
##-- Read Constraint Files
##-- =========================================================================
read_file -type sgdc ../constraints/clock_definitions.sgdc
read_file -type sgdc ../constraints/cdc_constraints.sgdc

##-- =========================================================================
##-- Set Top Module
##-- =========================================================================
set_option top async_fifo

##-- =========================================================================
##-- Run Structural CDC
##-- =========================================================================
puts "=============================================="
puts " Running CDC Structural Analysis..."
puts "=============================================="

current_goal cdc/cdc_verify_struct
run_goal

puts "=============================================="
puts " Structural CDC complete."
puts "=============================================="

##-- =========================================================================
##-- Run Full CDC Verification
##-- =========================================================================
puts "=============================================="
puts " Running Full CDC Verification..."
puts "=============================================="

current_goal cdc/cdc_verify
run_goal

puts "=============================================="
puts " Full CDC verification complete."
puts " Check spyglass_work/ for detailed reports."
puts "=============================================="

##-- =========================================================================
##-- Optional: Analyze the violations module
##-- =========================================================================
##-- Uncomment the following to also analyze the intentional violations:
##--
##-- read_file -type verilog ../rtl/cdc_violations.v
##-- set_option top cdc_violations_top
##-- current_goal cdc/cdc_verify_struct
##-- run_goal

##-- Exit
exit
