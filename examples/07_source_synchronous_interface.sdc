# ============================================================================
# Example 07: Source-Synchronous Interface (SDR and DDR)
# ============================================================================
# Scenario:
#   A source-synchronous interface where the clock travels alongside the
#   data on the PCB. Two sub-examples:
#
#   (A) SDR (Single Data Rate) - data sampled on rising edge only
#       External device sends: clk_src + data_sdr[7:0]
#       Skew between clock and data: -0.3 ns to +0.5 ns
#
#   (B) DDR (Double Data Rate) - data sampled on both edges
#       External device sends: clk_ddr + data_ddr[3:0]
#       Skew: -0.2 ns to +0.4 ns on both edges
#
# In a source-synchronous interface, the input delay values represent
# the skew between the data and its accompanying clock, NOT the
# absolute delay from some external reference.
# ============================================================================

# ===========================================================================
# (A) SDR Source-Synchronous Input
# ===========================================================================

# The forwarded clock arrives at the FPGA pin
create_clock -name sdr_clk -period 10.000 [get_ports clk_src]

# Data is launched by the external device's rising edge of clk_src.
# The max skew (data arrives 0.5 ns AFTER clock) becomes the max input delay.
# The min skew (data arrives 0.3 ns BEFORE clock) means min input delay = -0.3 ns.
set_input_delay -clock sdr_clk -max  0.5 [get_ports {data_sdr[*]}]
set_input_delay -clock sdr_clk -min -0.3 [get_ports {data_sdr[*]}]

# Timing budget for SDR:
#   Setup slack = Period - input_delay_max - Tco_FPGA_input - internal_delay
#   Hold  slack = input_delay_min + Tco_FPGA_input - Th
#
# If setup is tight, you can use PLL phase shifting to center the
# sampling edge within the data valid window:
#
#   create_generated_clock -name sdr_clk_shifted \
#       -source [get_ports clk_src] -phase 180 \
#       [get_pins u_pll|*|clk[0]]

# ===========================================================================
# (B) DDR Source-Synchronous Input
# ===========================================================================

# The DDR forwarded clock
create_clock -name ddr_clk -period 5.000 [get_ports clk_ddr]

# Rising edge data
set_input_delay -clock ddr_clk -max  0.4 [get_ports {data_ddr[*]}]
set_input_delay -clock ddr_clk -min -0.2 [get_ports {data_ddr[*]}]

# Falling edge data (use -clock_fall and -add_delay)
set_input_delay -clock ddr_clk -max  0.4 -clock_fall -add_delay [get_ports {data_ddr[*]}]
set_input_delay -clock ddr_clk -min -0.2 -clock_fall -add_delay [get_ports {data_ddr[*]}]

# IMPORTANT: -add_delay prevents the falling-edge constraint from
# overwriting the rising-edge constraint. Without it, only the
# falling-edge analysis would be performed.

# ===========================================================================
# Source-Synchronous Output
# ===========================================================================
# When the FPGA is the source of both clock and data:

# The FPGA outputs a forwarded clock
create_generated_clock -name tx_clk_out \
    -source [get_pins {u_pll|altpll_component|auto_generated|pll1|clk[1]}] \
    [get_ports tx_clk]

# External device receiving the data:
#   Tsu = 1.5 ns, Th = 0.8 ns
#   Board skew between clock and data: 0 to 0.3 ns
set_output_delay -clock tx_clk_out -max 1.8 [get_ports {tx_data[*]}]
set_output_delay -clock tx_clk_out -min -0.8 [get_ports {tx_data[*]}]

# ---------------------------------------------------------------------------
# Clock groups
# ---------------------------------------------------------------------------
set_clock_groups -asynchronous \
    -group {sdr_clk} \
    -group {ddr_clk} \
    -group {tx_clk_out}

derive_clock_uncertainty
