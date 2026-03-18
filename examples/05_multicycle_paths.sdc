# ============================================================================
# Example 05: Multicycle Path Constraints
# ============================================================================
# Scenario:
#   - 200 MHz core clock
#   - An 8-cycle pipelined multiplier (result valid every 8 clock cycles)
#   - A register-enable-based slow path (data sampled every 4 clocks)
#   - Cross-frequency transfer: 50 MHz -> 200 MHz with data held 4 fast cycles
#
# This example demonstrates multicycle path constraints and their
# hold companions.
# ============================================================================

# ---------------------------------------------------------------------------
# Clocks
# ---------------------------------------------------------------------------
create_clock -name clk_fast -period  5.000 [get_ports clk_200]
create_clock -name clk_slow -period 20.000 [get_ports clk_50]
derive_clock_uncertainty

# ===========================================================================
# Multicycle Case 1: Pipelined Multiplier (Same Clock Domain)
# ===========================================================================
#
# The multiplier has an 8-stage pipeline. Data enters at stage 0 and
# the result is captured at stage 7 after 8 clock cycles.
#
# Without the multicycle constraint, TimeQuest expects the data to
# arrive within 1 cycle (5 ns) and will report timing violations.
# The multicycle constraint tells it that 8 cycles (40 ns) are available.
#
#   Setup: data has 8 clock cycles to propagate
#   Hold:  companion value = 8 - 1 = 7
#
set_multicycle_path 8 -setup \
    -from [get_registers {u_mult|operand_a_reg[*] u_mult|operand_b_reg[*]}] \
    -to   [get_registers {u_mult|result_reg[*]}]

set_multicycle_path 7 -hold \
    -from [get_registers {u_mult|operand_a_reg[*] u_mult|operand_b_reg[*]}] \
    -to   [get_registers {u_mult|result_reg[*]}]

# ===========================================================================
# Multicycle Case 2: Enable-Based Slow Sampling (Same Clock Domain)
# ===========================================================================
#
# A counter generates a "valid" pulse every 4 clock cycles.
# The downstream register only captures data when "valid" is high.
#
# RTL pattern:
#   always @(posedge clk_fast)
#       if (valid_pulse)
#           slow_data_reg <= computed_data;
#
#   The combinational path from computed_data sources to slow_data_reg
#   has 4 clock cycles to settle.
#
set_multicycle_path 4 -setup \
    -from [get_registers {u_proc|compute_reg[*]}] \
    -to   [get_registers {u_proc|slow_data_reg[*]}]

set_multicycle_path 3 -hold \
    -from [get_registers {u_proc|compute_reg[*]}] \
    -to   [get_registers {u_proc|slow_data_reg[*]}]

# ===========================================================================
# Multicycle Case 3: Cross-Frequency Transfer (Slow -> Fast)
# ===========================================================================
#
# Data from the 50 MHz domain is held stable for 4 fast clock cycles
# before being captured in the 200 MHz domain.
#
#   -end flag: multiplier is expressed in destination (fast) clock periods
#
#   Setup: 4 fast clock cycles = 4 * 5 ns = 20 ns (one slow clock period)
#   Hold:  companion = 4 - 1 = 3
#
set_multicycle_path 4 -setup -end \
    -from [get_clocks clk_slow] \
    -to   [get_clocks clk_fast]

set_multicycle_path 3 -hold -end \
    -from [get_clocks clk_slow] \
    -to   [get_clocks clk_fast]

# ===========================================================================
# Understanding -start vs -end
# ===========================================================================
#
#   -end  (default for setup): multiplier is in terms of destination clock
#   -start (default for hold): multiplier is in terms of source clock
#
# For same-clock-domain multicycles, -start and -end are equivalent
# because both clocks have the same period.
#
# For cross-domain multicycles, the choice matters:
#
#   clk_slow (20 ns) -> clk_fast (5 ns)
#   set_multicycle_path 4 -setup -end
#     Means: 4 * 5 ns = 20 ns available (one slow period)
#
#   set_multicycle_path 1 -setup -start
#     Means: 1 * 20 ns = 20 ns available (same result, different expression)

# ---------------------------------------------------------------------------
# Other constraints
# ---------------------------------------------------------------------------
set_false_path -from [get_ports rst_n]
