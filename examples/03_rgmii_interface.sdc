# ============================================================
# Example 3: RGMII Ethernet Interface (Source-Synchronous DDR)
# ============================================================
# Design: Gigabit Ethernet using RGMII PHY interface
# RGMII operates at 125 MHz DDR (data on both clock edges)
#
# Interface:
#
#   PHY (e.g., Marvell 88E1111)          FPGA (Cyclone V)
#   ┌──────────────────────┐            ┌──────────────────┐
#   │                      │            │                  │
#   │  TX_CLK  <-----------│------------│-- RGMII_TX_CLK   │
#   │  TXD[3:0]<-----------│------------│-- rgmii_txd[3:0] │
#   │  TX_CTL  <-----------│------------│-- rgmii_tx_ctl   │
#   │                      │            │                  │
#   │  RX_CLK  -----------│------------>│-- RGMII_RX_CLK   │
#   │  RXD[3:0]-----------│------------>│-- rgmii_rxd[3:0] │
#   │  RX_CTL  -----------│------------>│-- rgmii_rx_ctl   │
#   │                      │            │                  │
#   └──────────────────────┘            └──────────────────┘
#
# Key RGMII Timing:
#   - 125 MHz clock, DDR -> 250 Mbps per pin
#   - Data is center-aligned with clock at the SOURCE
#   - At the receiver, data arrives edge-aligned (board delay shifts it)
#   - RGMII spec: Data valid window = +/- 0.5ns around clock edge
#
# ============================================================

# ============================================================
# Section 1: System Clocks
# ============================================================

create_clock -name sys_clk -period 20.0 [get_ports CLK_50M]
derive_pll_clocks
derive_clock_uncertainty

# ============================================================
# Section 2: RGMII RX Path (PHY -> FPGA)
# ============================================================

# The PHY sends RX_CLK along with RX data.
# This is a source-synchronous interface: clock co-routed with data.
create_clock -name rgmii_rx_clk -period 8.0 [get_ports RGMII_RX_CLK]

# RGMII RX timing (from PHY datasheet):
# Data transitions are center-aligned at the PHY output.
# After board trace, data arrives approximately edge-aligned at FPGA.
#
# PHY output skew spec: -0.5ns to +0.5ns between data and clock.
# Board skew between data and clock traces: assumed matched (< 50ps).
#
# We use the skew values directly as input_delay:
#   input_delay_max = +0.5ns (data arrives 0.5ns AFTER clock)
#   input_delay_min = -0.5ns (data arrives 0.5ns BEFORE clock)

# Rising edge data capture
set_input_delay -clock rgmii_rx_clk -max  0.5 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min -0.5 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]

# Falling edge data capture (DDR - must use -add_delay!)
set_input_delay -clock rgmii_rx_clk -max  0.5 -clock_fall -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min -0.5 -clock_fall -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]

# Note: The FPGA typically uses an internal PLL to phase-shift
# the RX clock by ~90 degrees (2ns at 125 MHz) to sample
# at the center of the data eye. This PLL-shifted clock is
# used internally; the create_clock above is for the input pin.

# ============================================================
# Section 3: RGMII TX Path (FPGA -> PHY)
# ============================================================

# The FPGA generates TX_CLK using a PLL output, phase-shifted
# to center the clock in the data eye at the PHY input.
# Typically -90 degrees (or +90 degrees depending on implementation).
create_generated_clock -name rgmii_tx_clk \
    -source [get_pins tx_pll|clk[0]] \
    [get_ports RGMII_TX_CLK]

# PHY input requirements (from PHY datasheet):
#   Tsu = 1.0ns (data must be stable 1.0ns before clock edge)
#   Th  = 1.0ns (data must be stable 1.0ns after clock edge)
#
# Board delay difference between data and clock: ~0ns (matched traces)
#
# output_delay_max = Tsu + Tboard_data - Tboard_clk = 1.0 + 0 = 1.0
# output_delay_min = -(Th - (Tboard_data - Tboard_clk)) = -(1.0 - 0) = -1.0

# Rising edge TX data
set_output_delay -clock rgmii_tx_clk -max  1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -min -1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]

# Falling edge TX data (DDR)
set_output_delay -clock rgmii_tx_clk -max  1.0 -clock_fall -add_delay [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -min -1.0 -clock_fall -add_delay [get_ports {rgmii_txd[*] rgmii_tx_ctl}]

# ============================================================
# Section 4: Clock Groups
# ============================================================

# System clock domain and RGMII RX clock are asynchronous
# (RGMII RX clock comes from the PHY's crystal, not our PLL)
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk tx_pll|* rgmii_tx_clk}] \
    -group [get_clocks {rgmii_rx_clk}]

# ============================================================
# Section 5: CDC Constraints (System <-> RX Domain)
# ============================================================

# Data crosses from RX domain to system domain through an async FIFO.
# The FIFO uses gray-coded pointers with double-FF synchronizers.
# Constrain the synchronizer paths to one destination clock period.
set_max_delay 10.0 -datapath_only \
    -from [get_registers {eth_rx_fifo|wr_ptr_gray[*]}] \
    -to   [get_registers {eth_rx_fifo|rd_sync_wr_ptr[0][*]}]

set_max_delay 8.0 -datapath_only \
    -from [get_registers {eth_rx_fifo|rd_ptr_gray[*]}] \
    -to   [get_registers {eth_rx_fifo|wr_sync_rd_ptr[0][*]}]

# ============================================================
# Section 6: General Exceptions
# ============================================================

# Async reset
set_false_path -from [get_ports RST_N]

# MDIO management interface (very slow, ~2.5 MHz bit-banged)
set_false_path -to   [get_ports {ETH_MDC ETH_MDIO}]
set_false_path -from [get_ports ETH_MDIO]

# PHY reset output (static during normal operation)
set_false_path -to [get_ports ETH_RST_N]

# LED link status indicators
set_false_path -to [get_ports {LED_LINK LED_ACT}]
