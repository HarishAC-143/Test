# ==============================================================
# Example 03: SPI Master Interface Constraints
# ==============================================================
# Scenario:
#   - FPGA acts as SPI master at 25 MHz (SCLK period = 40 ns).
#   - System clock: 100 MHz on port SYS_CLK.
#   - SPI signals: spi_sclk (output), spi_mosi (output),
#                  spi_miso (input), spi_cs_n (output).
#   - External SPI slave:
#       Tsu  = 5 ns (setup time for MOSI)
#       Th   = 2 ns (hold time for MOSI)
#       Tco  = 8 ns max, 2 ns min (clock-to-output for MISO)
#   - Board trace delay ~ 1 ns each way.
# ==============================================================

# ----------------------------------------------------------
# 1. System clock
# ----------------------------------------------------------
create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]

derive_pll_clocks
derive_clock_uncertainty

# ----------------------------------------------------------
# 2. Virtual SPI clock
# ----------------------------------------------------------
# SCLK is generated internally (not a true clock input).
# A virtual clock represents the SPI timing domain.
create_clock -name virt_spi_clk -period 40.0

# ----------------------------------------------------------
# 3. Output constraints — MOSI, CS_N
# ----------------------------------------------------------
# max output delay = Tsu_slave + Tbd = 5 + 1 = 6 ns
# min output delay = -(Th_slave) + Tbd_min = -2 + 0.5 = -1.5 ns

set_output_delay -clock virt_spi_clk -max 6.0  [get_ports {spi_mosi spi_cs_n}]
set_output_delay -clock virt_spi_clk -min -1.5  [get_ports {spi_mosi spi_cs_n}]

# ----------------------------------------------------------
# 4. Input constraints — MISO
# ----------------------------------------------------------
# max input delay = Tco_max + Tbd_max = 8 + 1 = 9 ns
# min input delay = Tco_min + Tbd_min = 2 + 0.5 = 2.5 ns

set_input_delay -clock virt_spi_clk -max 9.0  [get_ports spi_miso]
set_input_delay -clock virt_spi_clk -min 2.5  [get_ports spi_miso]

# ----------------------------------------------------------
# 5. SCLK output — false path
# ----------------------------------------------------------
# spi_sclk is the clock signal itself, not data.
# There is no meaningful setup/hold relationship to constrain.
set_false_path -to [get_ports spi_sclk]

# ----------------------------------------------------------
# 6. Clock groups
# ----------------------------------------------------------
# The virtual SPI clock is unrelated to sys_clk.
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks virt_spi_clk]
