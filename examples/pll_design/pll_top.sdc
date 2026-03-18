#==============================================================
# PLL-Based Multi-Clock Design - SDC Constraints
#
# Demonstrates:
#   - derive_pll_clocks for automatic PLL constraint generation
#   - Clock relationships between PLL outputs
#   - Constraining I/O on different PLL-derived clock domains
#   - CDC synchronizer between PLL output domains
#   - When PLL outputs are related vs. asynchronous
#
# Design: PLL generating 200 MHz, 25 MHz, and 100 MHz (90 deg)
#         from a 50 MHz input
#==============================================================

#--------------------------------------------------------------
# 1. Base Clock Definition
#--------------------------------------------------------------
# The 50 MHz oscillator feeds the PLL input

create_clock -name clk_50mhz -period 20.000 [get_ports clk_50mhz]

#--------------------------------------------------------------
# 2. PLL Output Clocks
#--------------------------------------------------------------
# derive_pll_clocks automatically creates generated clock
# constraints for all PLL output clocks based on the PLL
# configuration stored in the design.
#
# After running derive_pll_clocks, the following clocks exist:
#   pll_inst|...|clk[0]  ->  200 MHz (multiply by 4)
#   pll_inst|...|clk[1]  ->   25 MHz (divide by 2)
#   pll_inst|...|clk[2]  ->  100 MHz, 90° (multiply by 2, phase 90)
#
# These names are automatically generated. Use report_clocks
# after compilation to see the exact names.

derive_pll_clocks

#--------------------------------------------------------------
# 3. Clock Uncertainty
#--------------------------------------------------------------
# derive_clock_uncertainty accounts for:
#   - PLL output jitter
#   - Clock network skew within the FPGA
#   - Inter-clock transfer uncertainty
# Always place AFTER derive_pll_clocks.

derive_clock_uncertainty

#--------------------------------------------------------------
# 4. Clock Relationships
#--------------------------------------------------------------
# PLL outputs from the SAME PLL are RELATED (not asynchronous):
#   - They share the same reference clock
#   - The PLL maintains a deterministic phase relationship
#   - TimeQuest WILL analyze cross-domain paths between them
#
# This is correct behavior. The PLL guarantees phase alignment,
# so timing between PLL outputs should be checked.
#
# NOTE: Do NOT set_clock_groups -asynchronous between PLL
# outputs from the same PLL! They are phase-related.

# However, if a CDC synchronizer exists between domains
# (belt-and-suspenders approach), false-path the synchronizer:
set_false_path -to [get_registers {*done_sync_meta}]

#--------------------------------------------------------------
# 5. Fast Domain I/O (200 MHz)
#--------------------------------------------------------------
# Use a variable for the PLL clock name to keep constraints
# readable and maintainable.
#
# IMPORTANT: The actual clock name depends on your PLL instance
# name. Run 'report_clocks' after compilation and update these
# variables with the correct auto-generated names.

set fast_clk {pll_inst|altpll_component|auto_generated|pll1|clk[0]}

# Fast data input (external device Tco = 1 ns, board = 0.5 ns)
set_input_delay -clock $fast_clk -max 1.500 [get_ports {fast_data_in[*]}]
set_input_delay -clock $fast_clk -min 0.300 [get_ports {fast_data_in[*]}]

# Fast data output (external Tsu = 0.8 ns, Th = 0.3 ns, board = 0.5 ns)
set_output_delay -clock $fast_clk -max 1.300 [get_ports {fast_data_out[*]}]
set_output_delay -clock $fast_clk -min 0.200 [get_ports {fast_data_out[*]}]

#--------------------------------------------------------------
# 6. Slow Domain I/O (25 MHz)
#--------------------------------------------------------------

set slow_clk {pll_inst|altpll_component|auto_generated|pll1|clk[1]}

# Slow data input (relaxed timing, Tco = 12 ns, board = 3 ns)
set_input_delay -clock $slow_clk -max 15.000 [get_ports {slow_data_in[*]}]
set_input_delay -clock $slow_clk -min  3.000 [get_ports {slow_data_in[*]}]

# Slow data output (Tsu = 5 ns, Th = 2 ns, board = 3 ns)
set_output_delay -clock $slow_clk -max  8.000 [get_ports {slow_data_out[*]}]
set_output_delay -clock $slow_clk -min  1.000 [get_ports {slow_data_out[*]}]

# Processing done output (from slow domain)
set_output_delay -clock $slow_clk -max  8.000 [get_ports processing_done]
set_output_delay -clock $slow_clk -min  1.000 [get_ports processing_done]

#--------------------------------------------------------------
# 7. Reset
#--------------------------------------------------------------

set_false_path -from [get_ports rst_n]

#--------------------------------------------------------------
# Key Takeaways
#--------------------------------------------------------------
#
# 1. derive_pll_clocks saves you from manually calculating
#    PLL output frequencies, phases, and duty cycles.
#
# 2. PLL outputs from the SAME PLL are RELATED clocks.
#    TimeQuest correctly analyzes paths between them.
#
# 3. If you have PLL outputs from DIFFERENT PLLs with
#    independent reference clocks, those ARE asynchronous
#    and need set_clock_groups -asynchronous.
#
# 4. Always use derive_clock_uncertainty AFTER derive_pll_clocks
#    to properly account for PLL jitter.
#
# 5. Store PLL clock names in variables for readability.
#    Update after first compilation using report_clocks output.
