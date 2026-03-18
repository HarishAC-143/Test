# ==============================================================
# Example 02: Generated Clocks — PLL, Dividers, and Muxes
# ==============================================================
# Scenario:
#   - 50 MHz input clock drives a PLL with three outputs:
#       PLL out[0] = 100 MHz (×2)
#       PLL out[1] = 25 MHz  (÷2)
#       PLL out[2] = 50 MHz, 90° phase shift
#   - An RTL-based divide-by-4 clock divider
#   - A clock mux that selects between clk_25 and clk_100
# ==============================================================

# ----------------------------------------------------------
# 1. Base clock
# ----------------------------------------------------------
create_clock -name clk_50 -period 20.0 [get_ports CLK_50]

# ----------------------------------------------------------
# 2a. PLL clocks — automatic (recommended)
# ----------------------------------------------------------
# Uncomment the line below to let Quartus handle everything:
# derive_pll_clocks

# ----------------------------------------------------------
# 2b. PLL clocks — manual (when you need custom names)
# ----------------------------------------------------------

# 100 MHz: source clock multiplied by 2
create_generated_clock -name pll_clk_100 \
    -source [get_pins pll_inst|inclk[0]] \
    -multiply_by 2 \
    [get_pins pll_inst|clk[0]]

# 25 MHz: source clock divided by 2
create_generated_clock -name pll_clk_25 \
    -source [get_pins pll_inst|inclk[0]] \
    -divide_by 2 \
    [get_pins pll_inst|clk[1]]

# 50 MHz, 90° phase shift
create_generated_clock -name pll_clk_50_90 \
    -source [get_pins pll_inst|inclk[0]] \
    -phase 90.0 \
    [get_pins pll_inst|clk[2]]

# ----------------------------------------------------------
# 3. RTL-based clock divider (divide-by-4)
# ----------------------------------------------------------
# Verilog RTL:
#   reg [1:0] cnt;
#   reg clk_div4;
#   always @(posedge clk_50) begin
#       cnt <= cnt + 1;
#       if (cnt == 2'b11) clk_div4 <= ~clk_div4;
#   end
#
# The tool cannot automatically infer this is a clock.
# You must define it manually:

create_generated_clock -name clk_div4 \
    -source [get_ports CLK_50] \
    -divide_by 4 \
    [get_registers clk_div4_reg]

# ----------------------------------------------------------
# 4. Clock multiplexer
# ----------------------------------------------------------
# A 2:1 mux selects between pll_clk_25 and pll_clk_100.
# Both possible output clocks must be defined; -add keeps
# the first definition when the second is added.

create_generated_clock -name mux_out_slow \
    -source [get_pins pll_inst|clk[1]] \
    -master_clock pll_clk_25 \
    [get_pins clk_mux|combout]

create_generated_clock -name mux_out_fast \
    -source [get_pins pll_inst|clk[0]] \
    -master_clock pll_clk_100 \
    -add \
    [get_pins clk_mux|combout]

# The two mux outputs are physically exclusive — only one
# can be active at any time.
set_clock_groups -physically_exclusive \
    -group {mux_out_slow} \
    -group {mux_out_fast}

# ----------------------------------------------------------
# 5. Uncertainty
# ----------------------------------------------------------
derive_clock_uncertainty
