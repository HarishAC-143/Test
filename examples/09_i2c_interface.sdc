# ==============================================================
# Example 09: I2C Interface Constraints
# ==============================================================
# Scenario:
#   - FPGA implements an I2C master at standard mode (100 kHz)
#     and fast mode (400 kHz).
#   - I2C signals: i2c_scl (bidirectional clock),
#                  i2c_sda (bidirectional data).
#   - System clock: 50 MHz on CLK_50.
#   - I2C is so slow relative to the FPGA clock that all
#     paths are false-pathed.
# ==============================================================

create_clock -name clk_50 -period 20.0 [get_ports CLK_50]
derive_pll_clocks
derive_clock_uncertainty

# ----------------------------------------------------------
# I2C signals — false paths
# ----------------------------------------------------------
# I2C operates at 100–400 kHz (period = 2500–10000 ns).
# No meaningful timing relationship to the FPGA clock.
# The internal I2C controller handles timing in firmware/RTL.

set_false_path -to   [get_ports i2c_scl]
set_false_path -from [get_ports i2c_scl]
set_false_path -to   [get_ports i2c_sda]
set_false_path -from [get_ports i2c_sda]
