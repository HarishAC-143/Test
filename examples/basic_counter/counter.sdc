#==============================================================
# Basic Counter - SDC Constraints
#
# This is a beginner-friendly example showing the minimum set
# of constraints needed for a simple synchronous design.
#
# Design: 8-bit counter on Cyclone V FPGA
# Board:  DE1-SoC (50 MHz oscillator on CLOCK_50 pin)
#==============================================================

#--------------------------------------------------------------
# 1. Clock Definition
#--------------------------------------------------------------
# The FPGA board has a 50 MHz oscillator connected to the
# 'clk' input port. Period = 1/50MHz = 20 ns.

create_clock -name sys_clk -period 20.000 [get_ports clk]

#--------------------------------------------------------------
# 2. Derive Clock Uncertainty
#--------------------------------------------------------------
# Accounts for PLL jitter and clock network skew.
# No PLLs in this design, but it's good practice to always
# include this command.

derive_clock_uncertainty

#--------------------------------------------------------------
# 3. Input Constraints
#--------------------------------------------------------------
# External timing for signals coming INTO the FPGA.
#
# Assumptions for this example:
#   - All inputs come from a register clocked by sys_clk
#   - External device Tco_max = 8 ns, Tco_min = 2 ns
#   - Board trace delay max = 2 ns, min = 0.5 ns
#
# Input delay max = Tco_max + Tboard_max = 8 + 2 = 10 ns
# Input delay min = Tco_min + Tboard_min = 2 + 0.5 = 2.5 ns

set_input_delay -clock sys_clk -max 10.000 [get_ports {load_data[*]}]
set_input_delay -clock sys_clk -min  2.500 [get_ports {load_data[*]}]

set_input_delay -clock sys_clk -max 10.000 [get_ports enable]
set_input_delay -clock sys_clk -min  2.500 [get_ports enable]

set_input_delay -clock sys_clk -max 10.000 [get_ports load]
set_input_delay -clock sys_clk -min  2.500 [get_ports load]

#--------------------------------------------------------------
# 4. Output Constraints
#--------------------------------------------------------------
# External timing for signals going OUT of the FPGA.
#
# Assumptions:
#   - Downstream device Tsu = 3 ns, Th = 1 ns
#   - Board trace delay max = 2 ns, min = 0.5 ns
#
# Output delay max = Tsu + Tboard_max = 3 + 2 = 5 ns
# Output delay min = -Th + Tboard_min = -1 + 0.5 = -0.5 ns

set_output_delay -clock sys_clk -max  5.000 [get_ports {count[*]}]
set_output_delay -clock sys_clk -min -0.500 [get_ports {count[*]}]

set_output_delay -clock sys_clk -max  5.000 [get_ports overflow]
set_output_delay -clock sys_clk -min -0.500 [get_ports overflow]

#--------------------------------------------------------------
# 5. Asynchronous Reset (False Path)
#--------------------------------------------------------------
# The reset signal is asynchronous and must be synchronized
# in RTL (or by the reset controller). We tell TimeQuest not
# to analyze timing for the reset input.

set_false_path -from [get_ports rst_n]
