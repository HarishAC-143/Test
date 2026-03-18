# ============================================================
# Example 2: Multi-Clock Design with PLL
# ============================================================
# Design: Video processing system with multiple clock domains
# Board:  50 MHz oscillator, 25 MHz ADC clock
#
# Clock Architecture:
#
#   CLK_50M (50 MHz)
#       │
#       └─── PLL ──┬── clk[0] = 100 MHz (main processing)
#                   ├── clk[1] = 200 MHz (fast compute)
#                   └── clk[2] =  25 MHz (slow I/O control)
#
#   ADC_CLK (25 MHz, independent oscillator)
#       └─── ADC data capture domain
#
# ============================================================

# ============================================================
# Section 1: Primary Clock Definitions
# ============================================================

# 50 MHz board oscillator (PLL reference input)
create_clock -name clk_50m -period 20.0 [get_ports CLK_50M]

# 25 MHz ADC reference clock (separate oscillator on ADC board)
create_clock -name adc_clk -period 40.0 [get_ports ADC_CLK]

# ============================================================
# Section 2: PLL-Derived Clocks
# ============================================================

# Automatically derive all PLL output clocks.
# This reads the PLL megafunction configuration and creates
# create_generated_clock constraints for each output.
derive_pll_clocks

# Alternatively, if you want explicit control:
#
# create_generated_clock -name pll_100m \
#     -source [get_pins pll_inst|inclk[0]] \
#     -multiply_by 2 \
#     [get_pins pll_inst|clk[0]]
#
# create_generated_clock -name pll_200m \
#     -source [get_pins pll_inst|inclk[0]] \
#     -multiply_by 4 \
#     [get_pins pll_inst|clk[1]]
#
# create_generated_clock -name pll_25m \
#     -source [get_pins pll_inst|inclk[0]] \
#     -divide_by 2 \
#     [get_pins pll_inst|clk[2]]

# ============================================================
# Section 3: Clock Uncertainty
# ============================================================

derive_clock_uncertainty

# ============================================================
# Section 4: Clock Groups
# ============================================================

# PLL outputs are all derived from clk_50m, so they are
# "related" clocks (the tool computes their phase relationship).
# ADC_CLK is from a separate oscillator: truly asynchronous.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m pll_inst|*clk[0] pll_inst|*clk[1] pll_inst|*clk[2]}] \
    -group [get_clocks adc_clk]

# ============================================================
# Section 5: Input Constraints
# ============================================================

# --- 100 MHz Domain Inputs ---
# External FPGA sending processed data at 100 MHz
# Remote FPGA Tco = 4ns, Board = 0.8ns
set_input_delay -clock pll_inst|*clk[0] -max 4.8 [get_ports {fast_data_in[*]}]
set_input_delay -clock pll_inst|*clk[0] -min 1.5 [get_ports {fast_data_in[*]}]

# Sync/valid signal from same source
set_input_delay -clock pll_inst|*clk[0] -max 4.8 [get_ports data_valid_in]
set_input_delay -clock pll_inst|*clk[0] -min 1.5 [get_ports data_valid_in]

# --- 25 MHz Domain Inputs ---
# Slow control bus from microcontroller
# MCU Tco = 15ns, Board = 1ns
set_input_delay -clock pll_inst|*clk[2] -max 16.0 [get_ports {slow_data_in[*]}]
set_input_delay -clock pll_inst|*clk[2] -min  4.0 [get_ports {slow_data_in[*]}]

# --- ADC Domain Inputs ---
# ADC chip: Tco = 12ns (max), 5ns (min), Board = 0.5ns
set_input_delay -clock adc_clk -max 12.5 [get_ports {adc_data[*]}]
set_input_delay -clock adc_clk -min  5.5 [get_ports {adc_data[*]}]

# ============================================================
# Section 6: Output Constraints
# ============================================================

# --- 100 MHz Domain Outputs ---
# Video DAC: Tsu = 2ns, Th = 1ns, Board = 0.5ns
set_output_delay -clock pll_inst|*clk[0] -max  2.5 [get_ports {fast_data_out[*]}]
set_output_delay -clock pll_inst|*clk[0] -min -0.5 [get_ports {fast_data_out[*]}]

# Hsync/Vsync outputs
set_output_delay -clock pll_inst|*clk[0] -max  2.5 [get_ports {hsync vsync}]
set_output_delay -clock pll_inst|*clk[0] -min -0.5 [get_ports {hsync vsync}]

# --- 25 MHz Domain Outputs ---
# Status register output to MCU
set_output_delay -clock pll_inst|*clk[2] -max  8.0 [get_ports {slow_data_out[*]}]
set_output_delay -clock pll_inst|*clk[2] -min -2.0 [get_ports {slow_data_out[*]}]

# ============================================================
# Section 7: Timing Exceptions
# ============================================================

# Async reset (active-low)
set_false_path -from [get_ports RST_N]

# LED/debug outputs
set_false_path -to [get_ports {LED[*]}]

# Multicycle: 200 MHz compute engine writes results to 100 MHz domain.
# Data is valid for 2 cycles of the fast clock (= 1 cycle of slow clock).
# The -end flag means "reference the destination (100 MHz) clock."
# Since 200 MHz and 100 MHz are related (2:1), the default setup check
# uses 1 fast cycle (5ns). With MCP=2, we get 2 fast cycles = 10ns,
# which matches 1 slow cycle.
set_multicycle_path 2 -setup -end \
    -from [get_clocks pll_inst|*clk[1]] \
    -to   [get_clocks pll_inst|*clk[0]]
set_multicycle_path 1 -hold -end \
    -from [get_clocks pll_inst|*clk[1]] \
    -to   [get_clocks pll_inst|*clk[0]]

# Static configuration registers written by the 25 MHz MCU bus
# and read in the 100 MHz processing domain.
# These change very rarely (only during configuration) so we false-path them.
set_false_path \
    -from [get_registers {mcu_ctrl|config_reg[*]}] \
    -to   [get_registers {video_proc|cfg_*}]
