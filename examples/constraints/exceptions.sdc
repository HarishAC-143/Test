# =============================================================================
# exceptions.sdc — Timing exceptions (false paths, multicycle paths)
# =============================================================================
# Defines paths that should be excluded from or relaxed in timing analysis.
# Every exception must be documented with a justification.
# =============================================================================

# ---------------------------------------------------------------------------
# False paths
# ---------------------------------------------------------------------------

# Asynchronous reset — reset is asserted/de-asserted asynchronously.
# The design uses an async reset with synchronous de-assertion internally,
# so the reset-to-register paths do not need to meet clock timing.
set_false_path -from [get_ports {rst_n}]

# ---------------------------------------------------------------------------
# Multicycle paths (uncomment and modify as needed)
# ---------------------------------------------------------------------------

# Example: A signal that is valid for 2 clock cycles before being sampled.
# The setup check can be relaxed to 2 cycles, but hold must still be checked
# at the launch edge (hence -hold 1).
#
# set_multicycle_path 2 -setup -from [get_registers {*slow_enable*}]
# set_multicycle_path 1 -hold  -from [get_registers {*slow_enable*}]

# Example: ALU multiplication result is used over 2 cycles (pipelined).
# This is only valid if the downstream logic actually samples 2 clocks later.
#
# set_multicycle_path 2 -setup -from [get_registers {u_alu|mul_reg*}] \
#                               -to   [get_registers {u_alu|result_reg*}]
# set_multicycle_path 1 -hold  -from [get_registers {u_alu|mul_reg*}] \
#                               -to   [get_registers {u_alu|result_reg*}]

# ---------------------------------------------------------------------------
# Clock domain crossings (CDC)
# ---------------------------------------------------------------------------

# If the design had multiple clock domains, CDC paths would be constrained
# here. For single-clock designs, this section is empty.
#
# Example: False path between two asynchronous clock domains
# (crossing is handled by a synchronizer chain)
#
# set_false_path -from [get_clocks {clk_a}] -to [get_clocks {clk_b}]
# set_false_path -from [get_clocks {clk_b}] -to [get_clocks {clk_a}]

# ---------------------------------------------------------------------------
# Max delay constraints (for async interfaces)
# ---------------------------------------------------------------------------

# Example: Constrain an asynchronous interface to a maximum delay
# without requiring it to meet a specific clock relationship.
#
# set_max_delay 5.000 -from [get_ports {async_data[*]}] \
#                      -to   [get_registers {async_sync_reg[0]}]
