# ==============================================================
# Example 01: Basic Clock Constraints
# ==============================================================
# Scenario:
#   - Cyclone V FPGA with two oscillator inputs:
#       CLK_50  = 50 MHz main system clock
#       CLK_25  = 25 MHz auxiliary clock
#   - A single PLL generates higher-frequency clocks from CLK_50.
# ==============================================================

# ----------------------------------------------------------
# 1. Primary (base) clocks
# ----------------------------------------------------------

# 50 MHz oscillator — main system clock
create_clock -name clk_50 -period 20.0 [get_ports CLK_50]

# 25 MHz oscillator — auxiliary / low-speed peripherals
create_clock -name clk_25 -period 40.0 [get_ports CLK_25]

# ----------------------------------------------------------
# 2. PLL-generated clocks
# ----------------------------------------------------------
# derive_pll_clocks automatically creates generated clocks
# for every PLL output in the design.  It reads the PLL
# configuration (multiply/divide factors, phase shifts) and
# creates the correct create_generated_clock commands.
derive_pll_clocks

# ----------------------------------------------------------
# 3. Clock uncertainty
# ----------------------------------------------------------
# derive_clock_uncertainty computes jitter, PLL phase error,
# and inter-clock transfer uncertainty from device models.
derive_clock_uncertainty

# ----------------------------------------------------------
# 4. Clock groups
# ----------------------------------------------------------
# CLK_50 and CLK_25 come from independent oscillators.
# They are asynchronous — no phase relationship exists.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50}] \
    -group [get_clocks {clk_25}]
