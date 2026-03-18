# ============================================================
# SDC Constraints for data_processor.v
# ============================================================
# This SDC file demonstrates a complete, real-world constraint
# set for the data_processor design. It covers:
#   - PLL clocking
#   - Source-synchronous ADC input
#   - Async FIFO CDC
#   - SPI slave interface
#   - SRAM interface
#   - LED/switch false paths
# ============================================================

# ============================================================
# 1. Primary Clock Definitions
# ============================================================

# 50 MHz board oscillator -> PLL input
create_clock -name clk_50m -period 20.0 [get_ports CLK_50M]

# ADC clock (from ADC oscillator, independent of board clock)
create_clock -name adc_clk -period 32.0 [get_ports ADC_CLK]

# SPI clock (from external MCU, independent)
create_clock -name spi_sclk -period 100.0 [get_ports SPI_SCLK]

# ============================================================
# 2. PLL Output Clocks
# ============================================================

derive_pll_clocks

# After derive_pll_clocks, the following clocks exist:
#   pll_inst|c0  -> 100 MHz (pll_100m)
#   pll_inst|c1  -> 200 MHz (pll_200m)
#   pll_inst|c2  ->  25 MHz (pll_25m)

# ============================================================
# 3. Clock Uncertainty
# ============================================================

derive_clock_uncertainty

# ============================================================
# 4. Clock Groups (Asynchronous Relationships)
# ============================================================

# Three independent clock domains:
#   1. Board oscillator and all PLL derivatives
#   2. ADC clock (separate oscillator on ADC board)
#   3. SPI clock (from external microcontroller)
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m pll_inst|*c0 pll_inst|*c1 pll_inst|*c2}] \
    -group [get_clocks adc_clk] \
    -group [get_clocks spi_sclk]

# ============================================================
# 5. ADC Input Interface (Source-Synchronous to adc_clk)
# ============================================================

# ADC chip datasheet:
#   Tco_max = 12ns, Tco_min = 4ns
#   Board trace delay: ~0.3ns
set_input_delay -clock adc_clk -max 12.3 [get_ports {adc_data[*]}]
set_input_delay -clock adc_clk -min  4.3 [get_ports {adc_data[*]}]
set_input_delay -clock adc_clk -max 12.3 [get_ports adc_valid]
set_input_delay -clock adc_clk -min  4.3 [get_ports adc_valid]

# ============================================================
# 6. SPI Slave Interface
# ============================================================

# MOSI input (MCU drives MOSI, FPGA captures on SPI_SCLK rising edge)
# MCU Tco = 8ns max, 2ns min from SCLK falling edge
set_input_delay -clock spi_sclk -max 8.5 -clock_fall [get_ports SPI_MOSI]
set_input_delay -clock spi_sclk -min 2.5 -clock_fall [get_ports SPI_MOSI]

# CS_N input
set_input_delay -clock spi_sclk -max 10.0 [get_ports SPI_CS_N]
set_input_delay -clock spi_sclk -min  2.0 [get_ports SPI_CS_N]

# MISO output (FPGA drives on SCLK falling edge, MCU samples on rising)
# MCU Tsu = 5ns, Th = 5ns, Board = 0.5ns
set_output_delay -clock spi_sclk -max  5.5 [get_ports SPI_MISO]
set_output_delay -clock spi_sclk -min -4.5 [get_ports SPI_MISO]

# ============================================================
# 7. Processed Data Output (100 MHz domain)
# ============================================================

# Downstream device: Tsu = 2ns, Th = 1ns, Board = 0.3ns
set_output_delay -clock pll_inst|*c0 -max  2.3 [get_ports {proc_data_out[*]}]
set_output_delay -clock pll_inst|*c0 -min -0.7 [get_ports {proc_data_out[*]}]
set_output_delay -clock pll_inst|*c0 -max  2.3 [get_ports proc_valid_out]
set_output_delay -clock pll_inst|*c0 -min -0.7 [get_ports proc_valid_out]

# ============================================================
# 8. SRAM Interface (100 MHz domain)
# ============================================================

# SRAM timing: Tsu = 2ns, Th = 0.5ns, Tco = 8ns, Board = 0.3ns
set_output_delay -clock pll_inst|*c0 -max  2.3 [get_ports {sram_addr[*]}]
set_output_delay -clock pll_inst|*c0 -min -0.2 [get_ports {sram_addr[*]}]

set_output_delay -clock pll_inst|*c0 -max  2.3 [get_ports {sram_we_n sram_oe_n sram_ce_n}]
set_output_delay -clock pll_inst|*c0 -min -0.2 [get_ports {sram_we_n sram_oe_n sram_ce_n}]

# SRAM DQ (bidirectional)
set_output_delay -clock pll_inst|*c0 -max  2.3 [get_ports {sram_dq[*]}]
set_output_delay -clock pll_inst|*c0 -min -0.2 [get_ports {sram_dq[*]}]

set_input_delay -clock pll_inst|*c0 -max 8.3 [get_ports {sram_dq[*]}]
set_input_delay -clock pll_inst|*c0 -min 3.3 [get_ports {sram_dq[*]}]

# ============================================================
# 9. CDC Constraints (ADC FIFO Synchronizer Paths)
# ============================================================

# Write pointer gray code -> Read domain synchronizer
# Constrain to 1 period of the read (destination) clock = 10ns
set_max_delay 10.0 -datapath_only \
    -from [get_registers {adc_fifo|wr_ptr_gray[*]}] \
    -to   [get_registers {adc_fifo|rd_sync_ff1[*]}]

# Read pointer gray code -> Write domain synchronizer
# Constrain to 1 period of the write (destination) clock = 32ns
set_max_delay 32.0 -datapath_only \
    -from [get_registers {adc_fifo|rd_ptr_gray[*]}] \
    -to   [get_registers {adc_fifo|wr_sync_ff1[*]}]

# ============================================================
# 10. Timing Exceptions
# ============================================================

# Asynchronous reset
set_false_path -from [get_ports RST_N]

# PLL lock signal (quasi-static)
set_false_path -from [get_pins pll_inst|locked]

# LED outputs (human-visible, no timing requirement)
set_false_path -to [get_ports {LED[*]}]

# DIP switch inputs (static configuration)
set_false_path -from [get_ports {DIP_SW[*]}]

# Configuration register crossing from SPI domain to processing domain
# (config_gain is written rarely and read continuously)
set_false_path \
    -from [get_registers {spi_slave|config_gain[*]}] \
    -to   [get_registers {data_processor|config_gain[*]}]
