# ============================================================================
# Example 04: False Path Constraints
# ============================================================================
# Scenario:
#   - Two clock domains: clk_core (100 MHz) and clk_io (25 MHz)
#   - Clock domain crossing handled by dual-clock FIFO
#   - Static configuration registers written via I2C (very slow)
#   - Debug signals active only during lab testing
#   - Asynchronous reset
#
# This example demonstrates various legitimate uses of set_false_path.
# ============================================================================

# ---------------------------------------------------------------------------
# Clocks
# ---------------------------------------------------------------------------
create_clock -name clk_core -period 10.000 [get_ports clk_100]
create_clock -name clk_io   -period 40.000 [get_ports clk_25]
derive_clock_uncertainty

# ---------------------------------------------------------------------------
# False Path Type 1: Asynchronous Reset
# ---------------------------------------------------------------------------
# Reset is asynchronous to all clocks. The design uses a reset synchronizer
# to safely deassert reset in each clock domain.
set_false_path -from [get_ports {rst_n}]

# ---------------------------------------------------------------------------
# False Path Type 2: Clock Domain Crossing via FIFO
# ---------------------------------------------------------------------------
# The FIFO handles CDC internally using Gray-coded pointers and
# synchronizer registers. We false-path only the synchronizer inputs.
#
# PREFERRED approach: target the specific synchronizer registers
set_false_path -to [get_registers {u_cdc_fifo|rd_ptr_sync|meta_reg[*]}]
set_false_path -to [get_registers {u_cdc_fifo|wr_ptr_sync|meta_reg[*]}]

# ALTERNATIVE (less precise, but sometimes necessary):
# set_false_path -from [get_clocks clk_core] -to [get_clocks clk_io]
# set_false_path -from [get_clocks clk_io]   -to [get_clocks clk_core]
#
# WARNING: The clock-to-clock approach hides ALL paths between domains,
# not just the synchronizer paths. Use only when ALL crossing paths are
# properly synchronized.

# ---------------------------------------------------------------------------
# False Path Type 3: Static Configuration Registers
# ---------------------------------------------------------------------------
# These registers are written by I2C during initialization and never
# change during normal operation. Their outputs feed combinational
# logic in the core clock domain.
set_false_path -from [get_registers {u_i2c_cfg|config_reg[*]}]

# ---------------------------------------------------------------------------
# False Path Type 4: Debug / Test Signals
# ---------------------------------------------------------------------------
# Debug outputs go to test points on the board. Timing is irrelevant.
set_false_path -to [get_ports {debug_out[*] tp_clk tp_data}]

# ---------------------------------------------------------------------------
# False Path Type 5: Slow Human-Interface Signals
# ---------------------------------------------------------------------------
# Buttons and switches have debounce circuits; LEDs toggle slowly.
set_false_path -from [get_ports {btn[*] dip_sw[*]}]
set_false_path -to   [get_ports {led[*] seg7_dig[*] seg7_seg[*]}]
