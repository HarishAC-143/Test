# ==============================================================
# Example 04: Timing Exceptions
# ==============================================================
# Demonstrates: set_false_path, set_multicycle_path,
#               set_max_delay, set_min_delay
# ==============================================================

create_clock -name clk -period 10.0 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty

# ==============================================================
# A. FALSE PATHS
# ==============================================================

# --- A1. Asynchronous reset ---
# The reset signal is asynchronous and has no timing
# relationship to the clock domain. Its effect is handled
# by asynchronous reset recovery/removal checks (which
# the tool performs separately when appropriately constrained).
set_false_path -from [get_ports rst_n]

# --- A2. Push-button and DIP-switch inputs ---
# These are human-speed inputs — far slower than any clock.
set_false_path -from [get_ports {KEY[*] SW[*]}]

# --- A3. LED and 7-segment outputs ---
# Display outputs have no downstream timing requirements.
set_false_path -to [get_ports {LED[*] HEX0[*] HEX1[*]}]

# --- A4. Static configuration register ---
# This register is loaded once at startup and never changes
# during normal operation.
set_false_path -from [get_registers {cfg_ctrl|mode_reg[*]}]

# --- A5. Between two specific asynchronous domains ---
# Use when set_clock_groups is too broad.
# These paths are handled by a 2FF synchronizer.
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
set_false_path -from [get_clocks clk_b] -to [get_clocks clk_a]


# ==============================================================
# B. MULTICYCLE PATHS
# ==============================================================

# --- B1. 2-cycle path: slow computation ---
# Architecture guarantees result_reg samples data_reg every
# 2nd clock cycle (enabled by ce_2x).
set_multicycle_path -setup -end \
    -from [get_registers {compute|data_reg[*]}] \
    -to   [get_registers {compute|result_reg[*]}] \
    2
set_multicycle_path -hold -end \
    -from [get_registers {compute|data_reg[*]}] \
    -to   [get_registers {compute|result_reg[*]}] \
    1

# --- B2. 4-cycle path: DSP accumulator ---
# A multiply-accumulate takes 4 cycles before the
# output is valid.
set_multicycle_path -setup -end \
    -from [get_registers {dsp|mult_out[*]}] \
    -to   [get_registers {dsp|accum_reg[*]}] \
    4
set_multicycle_path -hold -end \
    -from [get_registers {dsp|mult_out[*]}] \
    -to   [get_registers {dsp|accum_reg[*]}] \
    3

# --- B3. Cross-domain multicycle (slow → fast) ---
# clk_slow = 50 MHz, clk_fast = 200 MHz (4× ratio).
# Data launched on clk_slow is captured on the 4th
# rising edge of clk_fast.
set_multicycle_path -setup -end \
    -from [get_clocks clk_slow] \
    -to   [get_clocks clk_fast] \
    4
set_multicycle_path -hold -end \
    -from [get_clocks clk_slow] \
    -to   [get_clocks clk_fast] \
    3


# ==============================================================
# C. MAX/MIN DELAY OVERRIDES
# ==============================================================

# --- C1. CDC synchronizer constraint ---
# Instead of false-pathing a CDC crossing, constrain
# the first synchronizer stage to one destination clock
# period.  This ensures the routing is short enough
# that metastability has time to resolve.
set_max_delay \
    -from [get_registers {cdc|src_reg}] \
    -to   [get_registers {cdc|sync_ff[0]}] \
    10.0

# Relax the hold check — the path is inherently
# asynchronous so hold is meaningless.
set_min_delay \
    -from [get_registers {cdc|src_reg}] \
    -to   [get_registers {cdc|sync_ff[0]}] \
    -1.0

# --- C2. Combinational output with absolute requirement ---
# An external device requires data no later than 8 ns
# after the clock edge, regardless of clock period.
set_max_delay -to [get_ports fast_out] 8.0
