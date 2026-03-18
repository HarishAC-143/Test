# ============================================================================
# Example 02: PLL-Based Clock Constraints
# ============================================================================
# Scenario:
#   - 50 MHz input oscillator
#   - Altera PLL ("u_pll") generates:
#       clk[0] = 100 MHz  (core logic)
#       clk[1] = 25 MHz   (peripheral bus)
#       clk[2] = 50 MHz, 90-degree phase shift (SDRAM interface)
#   - Active-low reset
#
# This example demonstrates derive_pll_clocks and clock groups.
# ============================================================================

# ---------------------------------------------------------------------------
# 1. Base clock
# ---------------------------------------------------------------------------
create_clock -name osc_50 -period 20.000 [get_ports clk_50mhz]

# ---------------------------------------------------------------------------
# 2. Auto-derive PLL output clocks
# ---------------------------------------------------------------------------
# derive_pll_clocks reads the PLL megafunction configuration and
# automatically generates create_generated_clock commands for each
# PLL output. This is the recommended approach for Altera designs.
derive_pll_clocks

# ---------------------------------------------------------------------------
# 3. Clock uncertainty
# ---------------------------------------------------------------------------
derive_clock_uncertainty

# ---------------------------------------------------------------------------
# 4. Verify what was created
# ---------------------------------------------------------------------------
# After running these constraints in TimeQuest, execute:
#   report_clocks
#
# Expected output (names vary by PLL instance path):
#   osc_50                                              Period: 20.000 ns
#   u_pll|altpll_component|auto_generated|pll1|clk[0]   Period: 10.000 ns
#   u_pll|altpll_component|auto_generated|pll1|clk[1]   Period: 40.000 ns
#   u_pll|altpll_component|auto_generated|pll1|clk[2]   Period: 20.000 ns

# ---------------------------------------------------------------------------
# 5. Reset
# ---------------------------------------------------------------------------
set_false_path -from [get_ports rst_n]
