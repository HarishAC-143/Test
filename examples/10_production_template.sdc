# ==============================================================
# Example 10: Production-Quality SDC Template
# ==============================================================
# Target: Cyclone V 5CEBA4F23C7
# Clocks: CLK_50 (50 MHz), CLK_25 (25 MHz)
# PLL:    pll_sys generates 100 MHz, 200 MHz, 50 MHz (90°)
# Interfaces: SPI, UART, GPIO, external SRAM
# ==============================================================


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 1: BASE CLOCKS                                   ║
# ╚════════════════════════════════════════════════════════════╝

create_clock -name clk_50  -period 20.0 [get_ports CLK_50]
create_clock -name clk_25  -period 40.0 [get_ports CLK_25]


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 2: PLL / GENERATED CLOCKS                        ║
# ╚════════════════════════════════════════════════════════════╝

derive_pll_clocks


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 3: CLOCK UNCERTAINTY                              ║
# ╚════════════════════════════════════════════════════════════╝

derive_clock_uncertainty


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 4: CLOCK GROUPS                                   ║
# ╚════════════════════════════════════════════════════════════╝

# clk_50 and clk_25 are from independent oscillators
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50}] \
    -group [get_clocks {clk_25}]

# JTAG
create_clock -name altera_reserved_tck \
    -period 100.0 \
    [get_ports altera_reserved_tck]

set_clock_groups -asynchronous \
    -group {altera_reserved_tck}


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 5: INPUT CONSTRAINTS                             ║
# ╚════════════════════════════════════════════════════════════╝

# --- 5a. Asynchronous inputs (no timing requirement) ---
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -from [get_ports RST_N]

# --- 5b. SRAM data bus (read path, 100 MHz domain) ---
# SRAM Tco_max = 10 ns, Tco_min = 3 ns, board delay ~ 1 ns
set_input_delay -clock clk_50 -max 11.0 [get_ports sram_dq[*]]
set_input_delay -clock clk_50 -min  4.0 [get_ports sram_dq[*]]

# --- 5c. SPI MISO (25 MHz virtual SPI clock) ---
create_clock -name virt_spi -period 40.0
set_input_delay -clock virt_spi -max 9.0 [get_ports spi_miso]
set_input_delay -clock virt_spi -min 2.5 [get_ports spi_miso]


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 6: OUTPUT CONSTRAINTS                            ║
# ╚════════════════════════════════════════════════════════════╝

# --- 6a. Display / indicator outputs (no timing) ---
set_false_path -to [get_ports {LED[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*]}]

# --- 6b. SRAM address/data/control (write path) ---
# SRAM Tsu = 8 ns, Th = 2 ns, board delay ~ 1 ns
set_output_delay -clock clk_50 -max 9.0  [get_ports {sram_addr[*] sram_dq[*] sram_we_n sram_oe_n sram_ce_n}]
set_output_delay -clock clk_50 -min -1.0 [get_ports {sram_addr[*] sram_dq[*] sram_we_n sram_oe_n sram_ce_n}]

# --- 6c. SPI outputs ---
set_output_delay -clock virt_spi -max 6.0  [get_ports {spi_mosi spi_cs_n}]
set_output_delay -clock virt_spi -min -1.5 [get_ports {spi_mosi spi_cs_n}]
set_false_path -to [get_ports spi_sclk]

# --- 6d. UART (asynchronous) ---
set_false_path -from [get_ports uart_rx]
set_false_path -to   [get_ports uart_tx]

# --- 6e. I2C (asynchronous, slow protocol) ---
set_false_path -to   [get_ports {i2c_scl i2c_sda}]
set_false_path -from [get_ports {i2c_scl i2c_sda}]


# ╔════════════════════════════════════════════════════════════╗
# ║  SECTION 7: TIMING EXCEPTIONS                             ║
# ╚════════════════════════════════════════════════════════════╝

# --- 7a. CDC synchronizer paths ---
# Constrain routing to the first synchronizer FF
set_max_delay \
    -from [get_registers {*cdc_src*}] \
    -to   [get_registers {*cdc_sync_ff[0]*}] \
    10.0

set_min_delay \
    -from [get_registers {*cdc_src*}] \
    -to   [get_registers {*cdc_sync_ff[0]*}] \
    0.0

# --- 7b. Multicycle: slow configuration register ---
# Config registers update every 8 clock cycles
set_multicycle_path -setup -end \
    -from [get_registers {config_ctrl|cfg_reg[*]}] \
    -to   [get_registers {core|cfg_shadow[*]}] \
    8
set_multicycle_path -hold -end \
    -from [get_registers {config_ctrl|cfg_reg[*]}] \
    -to   [get_registers {core|cfg_shadow[*]}] \
    7

# --- 7c. Multicycle: DSP pipeline ---
# 3-stage pipeline in DSP block
set_multicycle_path -setup -end \
    -from [get_registers {dsp_block|stage1_reg[*]}] \
    -to   [get_registers {dsp_block|stage3_reg[*]}] \
    3
set_multicycle_path -hold -end \
    -from [get_registers {dsp_block|stage1_reg[*]}] \
    -to   [get_registers {dsp_block|stage3_reg[*]}] \
    2

# --- 7d. SPI clock domain ---
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50}] \
    -group [get_clocks {virt_spi}]


# ╔════════════════════════════════════════════════════════════╗
# ║  END OF CONSTRAINTS                                        ║
# ╚════════════════════════════════════════════════════════════╝
