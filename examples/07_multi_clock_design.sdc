# ==============================================================
# Example 07: Multi-Clock Domain Design with CDC
# ==============================================================
# Scenario:
#   - Three independent clock domains:
#       clk_50  = 50 MHz  (peripheral bus)
#       clk_100 = 100 MHz (processing core)
#       clk_133 = 133 MHz (memory controller)
#   - Data crosses between domains through 2FF synchronizers
#     or async FIFOs.
#   - A PLL generates a 200 MHz internal clock from clk_100.
# ==============================================================

# ----------------------------------------------------------
# 1. Base clocks
# ----------------------------------------------------------
create_clock -name clk_50  -period 20.0 [get_ports CLK_50]
create_clock -name clk_100 -period 10.0 [get_ports CLK_100]
create_clock -name clk_133 -period 7.5  [get_ports CLK_133]

# ----------------------------------------------------------
# 2. PLL clocks
# ----------------------------------------------------------
derive_pll_clocks
derive_clock_uncertainty

# ----------------------------------------------------------
# 3. Clock groups — all three domains are asynchronous
# ----------------------------------------------------------
# This tells the Timing Analyzer to skip inter-domain
# timing checks.  CDC is handled by synchronizers/FIFOs.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50}] \
    -group [get_clocks {clk_100}] \
    -group [get_clocks {clk_133}]

# ----------------------------------------------------------
# 4. I/O constraints
# ----------------------------------------------------------

# Peripheral bus (50 MHz domain)
set_input_delay  -clock clk_50 -max 8.0  [get_ports periph_data_in[*]]
set_input_delay  -clock clk_50 -min 2.0  [get_ports periph_data_in[*]]
set_output_delay -clock clk_50 -max 7.0  [get_ports periph_data_out[*]]
set_output_delay -clock clk_50 -min -1.0 [get_ports periph_data_out[*]]

# Memory interface (133 MHz domain)
set_input_delay  -clock clk_133 -max 3.0  [get_ports mem_data_in[*]]
set_input_delay  -clock clk_133 -min 0.5  [get_ports mem_data_in[*]]
set_output_delay -clock clk_133 -max 2.5  [get_ports mem_data_out[*]]
set_output_delay -clock clk_133 -min -0.5 [get_ports mem_data_out[*]]

# ----------------------------------------------------------
# 5. CDC synchronizer path constraints (alternative approach)
# ----------------------------------------------------------
# Instead of relying solely on set_clock_groups, you may
# want to ensure that synchronizer paths have short routing.
# Use set_max_delay to constrain the path into the first
# synchronizer flip-flop.
#
# Naming convention: *_sync_ff[0] is the first stage of
# every synchronizer.

# 50 → 100 MHz crossing
set_max_delay \
    -from [get_clocks clk_50] \
    -to   [get_registers {*_sync_ff[0]}] \
    10.0

# 100 → 133 MHz crossing
set_max_delay \
    -from [get_clocks clk_100] \
    -to   [get_registers {*_sync_ff[0]}] \
    7.5

# 133 → 50 MHz crossing
set_max_delay \
    -from [get_clocks clk_133] \
    -to   [get_registers {*_sync_ff[0]}] \
    7.5

# ----------------------------------------------------------
# 6. Asynchronous reset
# ----------------------------------------------------------
set_false_path -from [get_ports RST_N]

# ----------------------------------------------------------
# 7. Debug / Status LEDs
# ----------------------------------------------------------
set_false_path -to [get_ports {LED[*]}]
