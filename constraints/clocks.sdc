#=============================================================================
# SDC Clock Definitions
#
# Defines all clocks in the design using industry-standard SDC format.
# SpyGlass uses these definitions to build clock domain maps for
# both lint (clock-related checks) and CDC analysis.
#=============================================================================

#--- Primary Clocks ---

# Domain A: 100 MHz system clock
create_clock -name clk_a -period 10.0 -waveform {0.0 5.0} [get_ports clk_a]

# Domain B: 133 MHz peripheral clock
create_clock -name clk_b -period 7.5 -waveform {0.0 3.75} [get_ports clk_b]

#--- Generated Clocks (examples for reference) ---

# Divided clock: clk_a / 2 = 50 MHz
# create_generated_clock -name clk_a_div2 \
#     -source [get_ports clk_a] \
#     -divide_by 2 \
#     [get_pins clk_divider/clk_out]

# PLL output: clk_a * 3 = 300 MHz
# create_generated_clock -name clk_pll \
#     -source [get_ports clk_a] \
#     -multiply_by 3 \
#     [get_pins pll_inst/clk_out]

#--- Clock Relationships ---

# Declare clk_a and clk_b as asynchronous (no known phase relationship)
# This is essential for CDC analysis — without it, SpyGlass may treat
# all crossings as synchronous and miss real CDC violations
set_clock_groups -asynchronous \
    -group [get_clocks clk_a] \
    -group [get_clocks clk_b]

#--- Clock Uncertainty (optional, for more accurate analysis) ---

# Setup uncertainty includes jitter and skew
# set_clock_uncertainty -setup 0.2 [get_clocks clk_a]
# set_clock_uncertainty -setup 0.2 [get_clocks clk_b]

# Hold uncertainty
# set_clock_uncertainty -hold  0.05 [get_clocks clk_a]
# set_clock_uncertainty -hold  0.05 [get_clocks clk_b]
