# ============================================================
# Example 10: Complete SoC-Style Design
# ============================================================
# Design: Nios II-based SoC with multiple peripherals
#
# This example demonstrates a realistic, comprehensive SDC
# file for a complete System-on-Chip design on an Altera FPGA.
#
# Architecture:
#
#   CLK_50M ──> PLL ──┬── cpu_clk  (100 MHz) - Nios II + Bus
#                      ├── ddr_clk  (200 MHz) - DDR controller
#                      ├── vga_clk  (25.175 MHz) - VGA pixel clock
#                      └── sdram_clk(100 MHz, -3ns phase) - SDRAM
#
#   ETH_REFCLK ──> PHY RGMII interface (125 MHz)
#
#   USB_CLK ──> USB controller (48 MHz)
#
#   SD_CLK ──> SD card interface (25 MHz generated)
#
# ============================================================

# ============================================================
# 1. PRIMARY CLOCKS
# ============================================================

# Board oscillator
create_clock -name clk_50m -period 20.0 [get_ports CLK_50M]

# Ethernet PHY reference clock
create_clock -name eth_refclk -period 8.0 [get_ports ETH_REFCLK]

# USB PHY clock
create_clock -name usb_clk -period 20.833 [get_ports USB_CLK]

# JTAG clock (for Nios II debug)
create_clock -name altera_reserved_tck -period 100.0 [get_ports altera_reserved_tck]

# ============================================================
# 2. PLL-DERIVED CLOCKS
# ============================================================

derive_pll_clocks

# Expected PLL outputs:
#   sys_pll|clk[0] = 100 MHz   (cpu_clk)
#   sys_pll|clk[1] = 200 MHz   (ddr_clk)
#   sys_pll|clk[2] = 25.175 MHz (vga_clk)
#   sys_pll|clk[3] = 100 MHz, -3ns phase (sdram_clk output)

# ============================================================
# 3. CLOCK UNCERTAINTY
# ============================================================

derive_clock_uncertainty

# ============================================================
# 4. CLOCK GROUPS
# ============================================================

# PLL outputs are all related (derived from clk_50m).
# Ethernet, USB, and JTAG are from independent sources.
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m sys_pll|*clk[0] sys_pll|*clk[1] sys_pll|*clk[2] sys_pll|*clk[3]}] \
    -group [get_clocks {eth_refclk}] \
    -group [get_clocks {usb_clk}] \
    -group [get_clocks {altera_reserved_tck}]

# ============================================================
# 5. SDRAM INTERFACE (100 MHz, sys_pll|clk[0] domain)
# ============================================================

create_generated_clock -name sdram_clk_out \
    -source [get_pins sys_pll|clk[3]] \
    [get_ports SDRAM_CLK]

# SDRAM output timing (IS42S16320D-7, Tsu=1.5ns, Th=0.8ns, board=0.3ns)
set_output_delay -clock sdram_clk_out -max  1.8 [get_ports {SDRAM_ADDR[*] SDRAM_BA[*] SDRAM_DQM[*]}]
set_output_delay -clock sdram_clk_out -min -0.5 [get_ports {SDRAM_ADDR[*] SDRAM_BA[*] SDRAM_DQM[*]}]
set_output_delay -clock sdram_clk_out -max  1.8 [get_ports {SDRAM_CS_N SDRAM_RAS_N SDRAM_CAS_N SDRAM_WE_N SDRAM_CKE}]
set_output_delay -clock sdram_clk_out -min -0.5 [get_ports {SDRAM_CS_N SDRAM_RAS_N SDRAM_CAS_N SDRAM_WE_N SDRAM_CKE}]

# SDRAM DQ bidirectional
set_output_delay -clock sdram_clk_out -max  1.8 [get_ports {SDRAM_DQ[*]}]
set_output_delay -clock sdram_clk_out -min -0.5 [get_ports {SDRAM_DQ[*]}]
set_input_delay  -clock sdram_clk_out -max  5.8 [get_ports {SDRAM_DQ[*]}]
set_input_delay  -clock sdram_clk_out -min  1.0 [get_ports {SDRAM_DQ[*]}]

# ============================================================
# 6. ETHERNET RGMII INTERFACE
# ============================================================

# RX (PHY -> FPGA)
create_clock -name rgmii_rx_clk -period 8.0 [get_ports RGMII_RX_CLK]

set_input_delay -clock rgmii_rx_clk -max  0.5 [get_ports {RGMII_RXD[*] RGMII_RX_CTL}]
set_input_delay -clock rgmii_rx_clk -min -0.5 [get_ports {RGMII_RXD[*] RGMII_RX_CTL}]
set_input_delay -clock rgmii_rx_clk -max  0.5 -clock_fall -add_delay [get_ports {RGMII_RXD[*] RGMII_RX_CTL}]
set_input_delay -clock rgmii_rx_clk -min -0.5 -clock_fall -add_delay [get_ports {RGMII_RXD[*] RGMII_RX_CTL}]

# TX (FPGA -> PHY)
create_generated_clock -name rgmii_tx_clk \
    -source [get_pins eth_pll|clk[0]] \
    [get_ports RGMII_TX_CLK]

set_output_delay -clock rgmii_tx_clk -max  1.0 [get_ports {RGMII_TXD[*] RGMII_TX_CTL}]
set_output_delay -clock rgmii_tx_clk -min -1.0 [get_ports {RGMII_TXD[*] RGMII_TX_CTL}]
set_output_delay -clock rgmii_tx_clk -max  1.0 -clock_fall -add_delay [get_ports {RGMII_TXD[*] RGMII_TX_CTL}]
set_output_delay -clock rgmii_tx_clk -min -1.0 -clock_fall -add_delay [get_ports {RGMII_TXD[*] RGMII_TX_CTL}]

# MDIO (management, very slow)
set_false_path -to   [get_ports {ETH_MDC ETH_MDIO}]
set_false_path -from [get_ports ETH_MDIO]

# Ethernet clock groups
set_clock_groups -asynchronous \
    -group [get_clocks {rgmii_rx_clk}] \
    -group [get_clocks {rgmii_tx_clk eth_pll|*}]

# ============================================================
# 7. VGA INTERFACE (25.175 MHz pixel clock)
# ============================================================

# VGA DAC: Tsu = 2ns, Th = 2ns, board = 0.3ns
set_output_delay -clock sys_pll|*clk[2] -max  2.3 [get_ports {VGA_R[*] VGA_G[*] VGA_B[*]}]
set_output_delay -clock sys_pll|*clk[2] -min -1.7 [get_ports {VGA_R[*] VGA_G[*] VGA_B[*]}]
set_output_delay -clock sys_pll|*clk[2] -max  2.3 [get_ports {VGA_HS VGA_VS}]
set_output_delay -clock sys_pll|*clk[2] -min -1.7 [get_ports {VGA_HS VGA_VS}]
set_output_delay -clock sys_pll|*clk[2] -max  2.3 [get_ports VGA_BLANK_N]
set_output_delay -clock sys_pll|*clk[2] -min -1.7 [get_ports VGA_BLANK_N]

# ============================================================
# 8. SD CARD INTERFACE
# ============================================================

# SD clock generated from system clock (divider)
create_generated_clock -name sd_clk_out \
    -source [get_pins sys_pll|clk[0]] \
    -divide_by 4 \
    [get_ports SD_CLK]

# SD card timing (conservative values for SD mode)
set_output_delay -clock sd_clk_out -max  5.0 [get_ports {SD_CMD SD_DAT[*]}]
set_output_delay -clock sd_clk_out -min -2.0 [get_ports {SD_CMD SD_DAT[*]}]
set_input_delay  -clock sd_clk_out -max 10.0 [get_ports {SD_CMD SD_DAT[*]}]
set_input_delay  -clock sd_clk_out -min  2.0 [get_ports {SD_CMD SD_DAT[*]}]

# ============================================================
# 9. UART (async serial)
# ============================================================

set_false_path -from [get_ports UART_RXD]
set_false_path -to   [get_ports UART_TXD]

# ============================================================
# 10. I2C (slow, open-drain)
# ============================================================

set_false_path -from [get_ports {I2C_SDA I2C_SCL}]
set_false_path -to   [get_ports {I2C_SDA I2C_SCL}]

# ============================================================
# 11. USB INTERFACE
# ============================================================

# USB data (synchronous to usb_clk)
set_input_delay  -clock usb_clk -max 10.0 [get_ports {USB_DATA[*]}]
set_input_delay  -clock usb_clk -min  3.0 [get_ports {USB_DATA[*]}]
set_output_delay -clock usb_clk -max  5.0 [get_ports {USB_DATA[*]}]
set_output_delay -clock usb_clk -min -2.0 [get_ports {USB_DATA[*]}]

# USB control signals
set_input_delay  -clock usb_clk -max 10.0 [get_ports {USB_NXT USB_DIR}]
set_input_delay  -clock usb_clk -min  3.0 [get_ports {USB_NXT USB_DIR}]
set_output_delay -clock usb_clk -max  5.0 [get_ports {USB_STP}]
set_output_delay -clock usb_clk -min -2.0 [get_ports {USB_STP}]

# ============================================================
# 12. JTAG INTERFACE
# ============================================================

# JTAG is handled specially by Quartus. Minimal constraints needed.
set_input_delay  -clock altera_reserved_tck -max 10.0 [get_ports {altera_reserved_tdi altera_reserved_tms}]
set_input_delay  -clock altera_reserved_tck -min  2.0 [get_ports {altera_reserved_tdi altera_reserved_tms}]
set_output_delay -clock altera_reserved_tck -max 10.0 [get_ports altera_reserved_tdo]
set_output_delay -clock altera_reserved_tck -min  2.0 [get_ports altera_reserved_tdo]

# ============================================================
# 13. GENERAL FALSE PATHS
# ============================================================

# Async reset
set_false_path -from [get_ports RST_N]

# PLL lock signals
set_false_path -from [get_pins sys_pll|locked]
set_false_path -from [get_pins eth_pll|locked]

# LEDs, switches, buttons (human-speed I/O)
set_false_path -to   [get_ports {LED[*]}]
set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {SW[*]}]

# 7-segment displays
set_false_path -to [get_ports {HEX0[*] HEX1[*] HEX2[*] HEX3[*]}]

# GPIO headers (directly controlled, no timing requirement)
set_false_path -from [get_ports {GPIO_0[*] GPIO_1[*]}]
set_false_path -to   [get_ports {GPIO_0[*] GPIO_1[*]}]

# ============================================================
# 14. MULTICYCLE PATHS
# ============================================================

# Nios II software-accessible registers in the 100 MHz domain
# that are read by the 200 MHz compute accelerator. The Avalon
# bus bridge handles the domain crossing with a 2-cycle handshake.
set_multicycle_path 2 -setup -end \
    -from [get_clocks sys_pll|*clk[0]] \
    -to   [get_clocks sys_pll|*clk[1]]
set_multicycle_path 1 -hold -end \
    -from [get_clocks sys_pll|*clk[0]] \
    -to   [get_clocks sys_pll|*clk[1]]

# ============================================================
# 15. CDC SYNCHRONIZER CONSTRAINTS
# ============================================================

# Ethernet RX FIFO (rgmii_rx_clk -> cpu_clk)
set_max_delay 10.0 -datapath_only \
    -from [get_registers {eth_mac|rx_fifo|wr_ptr_gray[*]}] \
    -to   [get_registers {eth_mac|rx_fifo|rd_sync_ff1[*]}]

set_max_delay 8.0 -datapath_only \
    -from [get_registers {eth_mac|rx_fifo|rd_ptr_gray[*]}] \
    -to   [get_registers {eth_mac|rx_fifo|wr_sync_ff1[*]}]

# USB domain -> CPU domain FIFO
set_max_delay 10.0 -datapath_only \
    -from [get_registers {usb_ctrl|fifo|wr_ptr_gray[*]}] \
    -to   [get_registers {usb_ctrl|fifo|rd_sync_ff1[*]}]

set_max_delay 20.833 -datapath_only \
    -from [get_registers {usb_ctrl|fifo|rd_ptr_gray[*]}] \
    -to   [get_registers {usb_ctrl|fifo|wr_sync_ff1[*]}]
