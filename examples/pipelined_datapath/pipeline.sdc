#==============================================================
# Pipelined Datapath - SDC Constraints
#
# Demonstrates:
#   - Standard pipeline timing (single-cycle between stages)
#   - Multicycle paths for slowly-updated registers
#   - False paths for static configuration registers
#   - The N / N-1 rule for multicycle setup/hold
#   - When NOT to use multicycle paths
#
# Design: 4-stage pipeline at 200 MHz with static config
#         and a slow status interface
#==============================================================

#--------------------------------------------------------------
# Clock Definition
#--------------------------------------------------------------

create_clock -name sys_clk -period 5.000 [get_ports clk]
derive_clock_uncertainty

#--------------------------------------------------------------
# I/O Constraints
#--------------------------------------------------------------

# Data inputs (from upstream pipeline, also at 200 MHz)
set_input_delay -clock sys_clk -max 2.000 [get_ports {data_a[*] data_b[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {data_a[*] data_b[*]}]

set_input_delay -clock sys_clk -max 2.000 [get_ports input_valid]
set_input_delay -clock sys_clk -min 0.500 [get_ports input_valid]

# Data outputs
set_output_delay -clock sys_clk -max 1.500 [get_ports {result[*]}]
set_output_delay -clock sys_clk -min 0.000 [get_ports {result[*]}]

set_output_delay -clock sys_clk -max 1.500 [get_ports output_valid]
set_output_delay -clock sys_clk -min 0.000 [get_ports output_valid]

#--------------------------------------------------------------
# Static Configuration Registers (False Path)
#--------------------------------------------------------------
# config_mode and config_bypass are set once during system
# initialization and never change during operation.
# They don't need timing analysis.
#
# In the RTL, config_mode feeds directly into pipeline
# stage 2 and 3 combinational logic. Without a false path,
# TimeQuest would try to meet single-cycle timing from
# config_mode to pipe2_result, which is unnecessarily
# restrictive for a static signal.

set_false_path -from [get_ports {config_mode[*]}]
set_false_path -from [get_ports config_bypass]

#--------------------------------------------------------------
# Pipeline Stages - Standard Single-Cycle
#--------------------------------------------------------------
# The pipeline stages (pipe1 -> pipe2 -> pipe3 -> output)
# are standard single-cycle paths. Each stage has one clock
# cycle to propagate.
#
# NO special constraints needed for the pipeline itself.
# TimeQuest automatically analyzes them as single-cycle
# register-to-register paths within the sys_clk domain.
#
# If a pipeline stage were too deep for a single cycle,
# the proper fix is to add more pipeline stages in RTL,
# NOT to add multicycle constraints.

#--------------------------------------------------------------
# Slow Status Interface - Multicycle Path (4 Cycles)
#--------------------------------------------------------------
# The status outputs (status_count, status_overflow) are
# updated only every 4th clock cycle (controlled by
# status_div counter). The downstream consumer reads
# them at 1/4 the clock rate.
#
# Multicycle setup = 4: Data has 4 clock cycles to propagate
# Multicycle hold = 3: (N-1 rule) Hold check stays at the
#                      correct edge

# count_accum -> status_count (4-cycle path)
set_multicycle_path -setup \
    -from [get_registers {pipeline:*|count_accum[*]}] \
    -to   [get_registers {pipeline:*|status_count[*]}] 4

set_multicycle_path -hold \
    -from [get_registers {pipeline:*|count_accum[*]}] \
    -to   [get_registers {pipeline:*|status_count[*]}] 3

# count_accum -> status_overflow (4-cycle path)
set_multicycle_path -setup \
    -from [get_registers {pipeline:*|count_accum[*]}] \
    -to   [get_registers {pipeline:*|status_overflow}] 4

set_multicycle_path -hold \
    -from [get_registers {pipeline:*|count_accum[*]}] \
    -to   [get_registers {pipeline:*|status_overflow}] 3

# Status outputs to I/O (also relaxed timing)
set_output_delay -clock sys_clk -max 3.000 [get_ports {status_count[*]}]
set_output_delay -clock sys_clk -min 0.000 [get_ports {status_count[*]}]

set_output_delay -clock sys_clk -max 3.000 [get_ports status_overflow]
set_output_delay -clock sys_clk -min 0.000 [get_ports status_overflow]

#--------------------------------------------------------------
# Reset
#--------------------------------------------------------------

set_false_path -from [get_ports rst_n]

#--------------------------------------------------------------
# Constraint Rationale Summary
#--------------------------------------------------------------
#
# Path Type                | Constraint       | Why
# ─────────────────────────┼──────────────────┼─────────────────
# Pipeline stages          | (default)        | Single-cycle timing is correct
# Static config inputs     | false_path       | Never changes during operation
# Status counter (4-cycle) | multicycle 4/3   | Updated every 4th cycle by design
# Async reset              | false_path       | Asynchronous, synced in RTL
#
# Anti-patterns avoided:
# - NOT using multicycle on the pipeline (would mask real issues)
# - NOT false-pathing pipeline stages (they MUST be timed)
# - Properly pairing multicycle setup with hold (N-1 rule)
