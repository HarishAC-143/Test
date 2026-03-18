# =============================================================================
# clocks.sdc — Clock definitions for FPGA regression test designs
# =============================================================================
# This file defines all clock domains used in the top_wrapper design.
# Apply these constraints before synthesis for accurate timing analysis.
# =============================================================================

# ---------------------------------------------------------------------------
# Primary system clock — 100 MHz (10 ns period)
# ---------------------------------------------------------------------------
create_clock -name sys_clk -period 10.000 [get_ports {clk}]

# ---------------------------------------------------------------------------
# Clock uncertainty (jitter + skew margin)
# ---------------------------------------------------------------------------
set_clock_uncertainty -setup 0.100 [get_clocks {sys_clk}]
set_clock_uncertainty -hold  0.050 [get_clocks {sys_clk}]

# ---------------------------------------------------------------------------
# Generated / PLL clocks (uncomment and modify as needed)
# ---------------------------------------------------------------------------

# Example: 200 MHz clock from PLL (2x system clock)
# create_generated_clock -name pll_clk_2x \
#     -source [get_ports {clk}] \
#     -multiply_by 2 \
#     [get_pins {u_pll|outclk_0}]

# Example: 50 MHz clock from PLL (divide-by-2)
# create_generated_clock -name pll_clk_div2 \
#     -source [get_ports {clk}] \
#     -divide_by 2 \
#     [get_pins {u_pll|outclk_1}]

# Example: Clock from counter bit (ripple clock — generally avoid)
# create_generated_clock -name cnt_clk \
#     -source [get_ports {clk}] \
#     -divide_by 256 \
#     [get_registers {u_counter|count[7]}]

# ---------------------------------------------------------------------------
# Virtual clocks (for I/O timing when no physical clock is available)
# ---------------------------------------------------------------------------

# Virtual clock matching system clock (for I/O constraints)
# create_clock -name virt_sys_clk -period 10.000
