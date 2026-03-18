# ============================================================
# Example 9: Clock Multiplexer with Exclusive Clock Groups
# ============================================================
# Design: System with switchable clock sources
#
# Some designs allow runtime clock source selection (e.g.,
# switching between a local oscillator and a recovered clock).
# SDC must model all possible clock sources but indicate that
# only one is active at any time.
#
# Architecture:
#
#   CLK_LOCAL (100 MHz, local oscillator)
#       │
#       ├──> ALTCLKCTRL (clock mux)──> clk_selected ──> logic
#       │         ^
#       │         │ sel
#   CLK_RECOV (100 MHz, recovered clock from SerDes)
#       │
#       └──> ALTCLKCTRL
#
# ============================================================

# ============================================================
# Section 1: Primary Clock Definitions
# ============================================================

# Local oscillator (always available)
create_clock -name clk_local -period 10.0 [get_ports CLK_LOCAL]

# Recovered clock from SerDes CDR (same frequency, different source)
create_clock -name clk_recovered -period 10.0 [get_ports CLK_RECOV]

# ============================================================
# Section 2: Generated Clocks on Mux Output
# ============================================================

# The clock mux output can carry either clock.
# We define both as generated clocks on the same pin, using -add.
# This tells the tool that this output pin can carry either clock.

create_generated_clock -name mux_out_local \
    -source [get_ports CLK_LOCAL] \
    -combinational \
    [get_pins clk_mux_inst|outclk]

create_generated_clock -name mux_out_recov \
    -source [get_ports CLK_RECOV] \
    -combinational \
    -add \
    [get_pins clk_mux_inst|outclk]

# ============================================================
# Section 3: Clock Groups (Exclusive)
# ============================================================

# These clocks are mutually exclusive: only one drives the mux
# output at any given time. The tool should not check timing
# between them.
set_clock_groups -exclusive \
    -group [get_clocks mux_out_local] \
    -group [get_clocks mux_out_recov]

# The two source clocks themselves are also from independent
# oscillators, so they are asynchronous.
set_clock_groups -asynchronous \
    -group [get_clocks clk_local] \
    -group [get_clocks clk_recovered]

# ============================================================
# Section 4: PLL After the Mux
# ============================================================

# If a PLL sits after the clock mux, its output clocks inherit
# the exclusive relationship.

derive_pll_clocks
derive_clock_uncertainty

# ============================================================
# Section 5: Clock Selection Logic
# ============================================================

# The clock selection control signal is quasi-static (changes
# only during a controlled switchover sequence).
set_false_path -from [get_registers {clk_switch_ctrl|sel_reg}]

# During switchover, the design uses a glitch-free clock
# switching technique (e.g., ALTCLKCTRL with enable).
# The sel_reg value is synchronized and the mux uses
# clock-enable-based switching to avoid glitches.

# ============================================================
# Section 6: I/O Constraints
# ============================================================

# Data interface runs from whichever clock is selected.
# Constrain against both generated clocks (tool will analyze
# both, but only one matters due to exclusive groups).

# Input data
set_input_delay -clock mux_out_local -max 4.0 [get_ports {data_in[*]}]
set_input_delay -clock mux_out_local -min 1.0 [get_ports {data_in[*]}]

set_input_delay -clock mux_out_recov -max 4.0 -add_delay [get_ports {data_in[*]}]
set_input_delay -clock mux_out_recov -min 1.0 -add_delay [get_ports {data_in[*]}]

# Output data
set_output_delay -clock mux_out_local -max 3.0 [get_ports {data_out[*]}]
set_output_delay -clock mux_out_local -min -1.0 [get_ports {data_out[*]}]

set_output_delay -clock mux_out_recov -max 3.0 -add_delay [get_ports {data_out[*]}]
set_output_delay -clock mux_out_recov -min -1.0 -add_delay [get_ports {data_out[*]}]

# ============================================================
# Section 7: General Exceptions
# ============================================================

set_false_path -from [get_ports RST_N]
set_false_path -to   [get_ports {LED[*]}]
