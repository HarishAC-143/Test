# ============================================================================
# Example 06: Clock Groups and Clock Relationships
# ============================================================================
# Scenario:
#   - System clock: 100 MHz
#   - Ethernet PHY RX clock: 125 MHz (from PHY chip, asynchronous)
#   - USB PHY clock: 60 MHz (from USB PHY, asynchronous)
#   - PLL generating 200 MHz and 50 MHz from the system clock
#   - Multiplexed clock: either 100 MHz or 125 MHz selected at boot
#
# This example shows set_clock_groups for asynchronous and exclusive clocks.
# ============================================================================

# ---------------------------------------------------------------------------
# Primary Clocks
# ---------------------------------------------------------------------------
create_clock -name sys_clk     -period 10.000 [get_ports clk_100]
create_clock -name eth_rx_clk  -period  8.000 [get_ports eth_rxc]
create_clock -name usb_clk     -period 16.667 [get_ports usb_clk60]

# ---------------------------------------------------------------------------
# PLL Clocks (from sys_clk)
# ---------------------------------------------------------------------------
derive_pll_clocks
derive_clock_uncertainty

# Assume PLL creates:
#   pll_clk_200  (200 MHz, synchronous to sys_clk)
#   pll_clk_50   (50 MHz, synchronous to sys_clk)

# ---------------------------------------------------------------------------
# Asynchronous Clock Groups
# ---------------------------------------------------------------------------
# Group 1: sys_clk and its PLL derivatives (all synchronous to each other)
# Group 2: eth_rx_clk (from external PHY, no phase relationship)
# Group 3: usb_clk (from external PHY, no phase relationship)
#
# TimeQuest will NOT analyze timing between different groups.
# Within each group, timing is fully analyzed.
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk u_pll|*|clk[0] u_pll|*|clk[1]}] \
    -group [get_clocks {eth_rx_clk}] \
    -group [get_clocks {usb_clk}]

# ---------------------------------------------------------------------------
# Exclusive (Multiplexed) Clocks
# ---------------------------------------------------------------------------
# A clock mux selects between two clock sources at boot time.
# Both clocks are defined on the same input pin, but only one is
# active at any time.
create_clock -name mux_clk_a -period 10.000 [get_ports clk_mux_in] -add
create_clock -name mux_clk_b -period  8.000 [get_ports clk_mux_in] -add

# Tell TimeQuest these clocks never coexist:
set_clock_groups -exclusive \
    -group {mux_clk_a} \
    -group {mux_clk_b}

# ---------------------------------------------------------------------------
# Why use set_clock_groups instead of set_false_path?
# ---------------------------------------------------------------------------
# set_clock_groups -asynchronous -group {A} -group {B}
# is equivalent to:
#   set_false_path -from [get_clocks A] -to [get_clocks B]
#   set_false_path -from [get_clocks B] -to [get_clocks A]
#
# Advantages of set_clock_groups:
#   1. Scales better: N groups need N*(N-1)/2 false paths otherwise
#   2. Self-documenting: clearly states the architectural intent
#   3. Automatically handles new clocks added to a group
#   4. Less error-prone: symmetric by definition

# ---------------------------------------------------------------------------
# Other constraints
# ---------------------------------------------------------------------------
set_false_path -from [get_ports {rst_n}]
