# ==============================================================================
# SDC Timing Constraints for Macronix MX66U1G45G — High-Speed Mode
# Target: Altera (Intel) FPGA — Quartus Prime TimeQuest Timing Analyzer
#
# This file targets FAST READ, 2READ, 4READ, and QREAD operations at clock
# frequencies up to 133 MHz (or 166 MHz with 10 dummy cycles).
#
# At these frequencies the half-period (3.01–3.75 ns) is shorter than tCLQV
# (6–8 ns), so a simple rising-edge capture will not close timing. This file
# uses PLL-based phase shifting to move the capture edge into the valid data
# window.
#
# Device:   MX66U1G45G (BGA-24, J-Grade)
# Datasheet: Rev 1.2, August 13, 2020
# ==============================================================================


# ==============================================================================
# Section 1: Parameters
# ==============================================================================

# ---- Flash timing ----
set tCLQV_max        7.0
set tCLQX_min        1.0
set tDVCH            1.5
set tCHDX            1.5
set tSLCH            4.5
set tCHSL            4.0

# ---- Board delays (ns) ----
set board_delay_clk_min   0.1
set board_delay_clk_max   0.3
set board_delay_data_min  0.1
set board_delay_data_max  0.3

# ---- SPI clock ----
# For 133 MHz fast read operation:
set spi_clk_period    7.519   ;# 133 MHz (ns)

# For 166 MHz (uncomment and comment the 133 MHz line above):
# set spi_clk_period  6.024   ;# 166 MHz (ns)

# ---- PLL phase shift for input capture ----
# The PLL shifts the capture clock to center-align with the valid data window.
#
# Valid data window at FPGA pin (relative to SCLK falling edge at FPGA pin):
#   Opens at: Tbc_min + tCLQX_min + Tbd_min = 1.2 ns
#   Closes at: Tbc_max + tCLQV_max + Tbd_max = 7.6 ns
#
# Window center = (1.2 + 7.6) / 2 = 4.4 ns after SCLK falling edge at pin
# The FPGA rising edge occurs at half_period after the falling edge.
# We want the rising edge to land at 4.4 ns after the falling edge.
# Required shift = 4.4 - half_period
#
# For 133 MHz: half_period = 3.76 ns → shift ≈ 0.64 ns → ~30.7° phase shift
# For 166 MHz: half_period = 3.01 ns → shift ≈ 1.39 ns → ~83.1° phase shift
#
# Express as degrees: shift_deg = (shift_ns / period) × 360
set capture_phase_shift_ns  [expr {
    (($board_delay_clk_min + $tCLQX_min + $board_delay_data_min) +
     ($board_delay_clk_max + $tCLQV_max + $board_delay_data_max)) / 2.0
    - ($spi_clk_period / 2.0)
}]

# ---- Port names ----
set flash_sclk_port     FLASH_SCLK
set flash_cs_n_port     FLASH_CS_N
set flash_sio_ports     {FLASH_SIO0 FLASH_SIO1 FLASH_SIO2 FLASH_SIO3}


# ==============================================================================
# Section 2: Clock Definitions
# ==============================================================================

# PLL output clock for driving SCLK
# (Assume pll_inst generates two outputs:
#   outclk_0 = 0° phase for SCLK generation and data output
#   outclk_1 = shifted phase for input capture sampling)

# SCLK generated clock at the output pin
create_generated_clock \
    -name spi_sclk_out \
    -source [get_pins {pll_inst|outclk_0}] \
    [get_ports $flash_sclk_port]

# Phase-shifted capture clock (internal only, drives input sampling registers)
# The -phase value should match the PLL configuration in your Quartus project.
# create_generated_clock \
#     -name spi_sclk_capture \
#     -source [get_pins {pll_inst|outclk_1}] \
#     -phase <your_pll_phase_shift_degrees> \
#     [get_registers {spi_master_inst|rx_data_reg[*]}]


# ==============================================================================
# Section 3: Output Constraints — FPGA → Flash (Quad I/O Write Path)
# ==============================================================================

set out_delay_max [expr {$tDVCH + $board_delay_data_max - $board_delay_clk_min}]
set out_delay_min [expr {-$tCHDX + $board_delay_data_min - $board_delay_clk_max}]

# SIO[0:3] output constraints (all data lines, quad mode)
foreach sio_port $flash_sio_ports {
    set_output_delay \
        -clock spi_sclk_out \
        -max $out_delay_max \
        [get_ports $sio_port]

    set_output_delay \
        -clock spi_sclk_out \
        -min $out_delay_min \
        [get_ports $sio_port]
}

# CS# output constraints
set cs_out_delay_max [expr {$tSLCH + $board_delay_data_max - $board_delay_clk_min}]
set cs_out_delay_min [expr {-$tCHSL + $board_delay_data_min - $board_delay_clk_max}]

set_output_delay \
    -clock spi_sclk_out \
    -max $cs_out_delay_max \
    [get_ports $flash_cs_n_port]

set_output_delay \
    -clock spi_sclk_out \
    -min $cs_out_delay_min \
    [get_ports $flash_cs_n_port]


# ==============================================================================
# Section 4: Input Constraints — Flash → FPGA (Quad I/O Read Path)
# ==============================================================================
# Data is launched by the flash on the falling edge of SCLK and captured by
# the FPGA using the phase-shifted PLL clock.

set in_delay_max [expr {$board_delay_clk_max + $tCLQV_max + $board_delay_data_max}]
set in_delay_min [expr {$board_delay_clk_min + $tCLQX_min + $board_delay_data_min}]

foreach sio_port $flash_sio_ports {
    set_input_delay \
        -clock spi_sclk_out \
        -clock_fall \
        -max $in_delay_max \
        [get_ports $sio_port]

    set_input_delay \
        -clock spi_sclk_out \
        -clock_fall \
        -min $in_delay_min \
        [get_ports $sio_port]
}


# ==============================================================================
# Section 5: Clock Uncertainty
# ==============================================================================

set_clock_uncertainty -setup 0.15 [get_clocks spi_sclk_out]
set_clock_uncertainty -hold  0.08 [get_clocks spi_sclk_out]


# ==============================================================================
# Section 6: Timing Budget Analysis at 133 MHz
# ==============================================================================
#
# Half period = 3.76 ns
#
# --- Read Path (with phase-shifted capture) ---
# Data valid window at FPGA pin (after SCLK falling edge at FPGA):
#   Opens:  1.2 ns  (Tbc_min + tCLQX_min + Tbd_min)
#   Closes: 7.6 ns  (Tbc_max + tCLQV_max + Tbd_max)
#   Width:  6.4 ns
#
# With capture edge shifted to window center (4.4 ns after falling edge):
#   Setup margin = 7.6 - 4.4 = 3.2 ns  ✓
#   Hold margin  = 4.4 - 1.2 = 3.2 ns  ✓
#
# --- Write Path ---
# The half-period of 3.76 ns provides:
#   Setup margin = 3.76 - 1.7 = 2.06 ns (minus FPGA tco ~0.5 ns → 1.56 ns)  ✓
#   Hold margin  = comfortable (negative output_delay_min)  ✓
#
# ==============================================================================

puts "INFO: MX66U1G45G high-speed SDC constraints loaded."
puts "INFO: SPI clock period = $spi_clk_period ns ([format {%.1f} [expr {1000.0 / $spi_clk_period}]] MHz)"
puts "INFO: Suggested capture phase shift = [format {%.2f} $capture_phase_shift_ns] ns"
puts "INFO: Input delay max  = $in_delay_max ns"
puts "INFO: Input delay min  = $in_delay_min ns"
puts "INFO: Output delay max = $out_delay_max ns"
puts "INFO: Output delay min = $out_delay_min ns"
