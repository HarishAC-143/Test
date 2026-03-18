# =============================================================================
# SDC Constraints for Macronix MX66U1G45G (1.8V, 1Gb Serial NOR Flash)
# Target: Altera (Intel) FPGA
# =============================================================================
#
# Part:       MX66U1G45G
# Interface:  SPI / Dual SPI / Quad SPI (QPI) with DTR support
# Voltage:    1.65V - 2.0V (1.8V nominal)
# Max Freq:   166 MHz (Quad I/O STR), 83 MHz (DTR)
#
# Reference:  Macronix MX66U1G45G Datasheet v1.2
#
# This file provides timing constraints for the FPGA-to-flash SPI interface.
# The FPGA acts as the SPI master generating SCLK, CS#, and driving/receiving
# data on the IO lines.
#
# IMPORTANT: Adjust the following parameters to match your board design:
#   - SPI_CLK_FREQ_MHZ : Operating SPI clock frequency
#   - BOARD_DELAY_MAX  : Maximum PCB trace propagation delay (one-way)
#   - BOARD_DELAY_MIN  : Minimum PCB trace propagation delay (one-way)
#   - Pin names in [get_ports ...] must match your FPGA design
# =============================================================================


# =============================================================================
# Section 1: User-Configurable Parameters
# =============================================================================

# SPI clock frequency in MHz (choose one based on your operating mode)
#   54 MHz  - Standard READ command
#  104 MHz  - FAST_READ (SPI mode)
#  133 MHz  - FAST_READ (Quad I/O STR, conservative)
#  166 MHz  - FAST_READ (Quad I/O STR, maximum)
#   83 MHz  - DTR mode (data on both edges, effective 166 Mbps)
set SPI_CLK_FREQ_MHZ       133.0

set SPI_CLK_PERIOD_NS      [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]
set SPI_HALF_PERIOD_NS     [expr {$SPI_CLK_PERIOD_NS / 2.0}]

# PCB board trace delays (one-way, FPGA pad to flash pad)
# Estimate: ~170 ps/inch for FR4, typical 1-3 inches trace
set BOARD_DELAY_MAX         0.60
set BOARD_DELAY_MIN         0.10

# Clock skew between SCLK trace and data traces on PCB
set BOARD_CLK_SKEW          0.15


# =============================================================================
# Section 2: MX66U1G45G AC Timing Parameters (from datasheet)
# =============================================================================

# --- Flash Output Timing (Read path: Flash -> FPGA) ---
# tCLQV : Clock Low to Output Valid (max), applies to STR mode
#         Data is launched by flash on the falling edge of SCLK
set FLASH_TCLQV_MAX        6.000

# tCLQX : Clock Low to Output Hold (min)
#         Minimum time flash holds previous data after clock edge
set FLASH_TCLQX_MIN        0.500

# --- Flash Input Timing (Write/Command path: FPGA -> Flash) ---
# tSI : Data Input Setup Time (min) before rising edge of SCLK
set FLASH_TSI_MIN           2.000

# tHI : Data Input Hold Time (min) after rising edge of SCLK
set FLASH_THI_MIN           2.000

# --- DTR Mode Timing ---
# tCLQV for DTR mode (data transitions on both SCLK edges)
set FLASH_DTR_TCLQV_MAX    6.000

# tSI for DTR mode
set FLASH_DTR_TSI_MIN      1.500

# tHI for DTR mode
set FLASH_DTR_THI_MIN      1.500

# --- SCLK Timing ---
# tCH : SCLK High Time (min)
set FLASH_TCH_MIN           2.700

# tCL : SCLK Low Time (min)
set FLASH_TCL_MIN           2.700

# --- Chip Select Timing ---
# tSLCH : CS# Active (Low) Setup to SCLK Rising Edge (min)
set FLASH_TSLCH_MIN         5.000

# tCHSH : SCLK Rising Edge to CS# Inactive (High) Hold (min)
set FLASH_TCHSH_MIN         5.000

# tSHSL : CS# Deselect Time / CS# High Time between commands (min)
set FLASH_TSHSL_MIN        10.000


# =============================================================================
# Section 3: FPGA Pin Names
# =============================================================================
# Modify these to match the port names in your RTL design.

set FLASH_SCLK_PIN         "flash_sclk"
set FLASH_CS_N_PIN         "flash_cs_n"

# Quad I/O data pins
set FLASH_IO0_PIN          "flash_io[0]"
set FLASH_IO1_PIN          "flash_io[1]"
set FLASH_IO2_PIN          "flash_io[2]"
set FLASH_IO3_PIN          "flash_io[3]"

# Grouped data ports for convenience
set FLASH_DATA_PINS        [list $FLASH_IO0_PIN $FLASH_IO1_PIN \
                                 $FLASH_IO2_PIN $FLASH_IO3_PIN]

# Reference clock name from FPGA PLL / clock network that drives the SPI logic
set FPGA_SYS_CLK           "sys_clk"


# =============================================================================
# Section 4: Clock Definitions
# =============================================================================

# 4a. System clock (should already be defined; uncomment if needed)
# create_clock -name $FPGA_SYS_CLK -period <SYS_CLK_PERIOD_NS> [get_ports <sys_clk_pin>]

# 4b. Generated SPI clock on the SCLK output pin
# The SPI clock is generated from the FPGA system clock via PLL or clock divider.
# Adjust -source and -divide_by to match your clock generation logic.
create_generated_clock \
    -name spi_sclk \
    -source [get_pins -compatibility_mode {spi_clk_reg|clk}] \
    -divide_by 1 \
    [get_ports $FLASH_SCLK_PIN]

# 4c. Virtual clock representing the SPI clock at the flash device
# Used for I/O delay constraints. Accounts for the fact that the clock
# arriving at the flash is delayed by board trace propagation.
create_clock \
    -name spi_sclk_virtual \
    -period $SPI_CLK_PERIOD_NS


# =============================================================================
# Section 5: Input Delay Constraints (Flash -> FPGA, Read Path)
# =============================================================================
# In SPI Mode 0 (CPOL=0, CPHA=0):
#   - Flash launches data on the FALLING edge of SCLK
#   - FPGA captures data on the RISING edge of SCLK
#
# Input delay = flash_output_delay + board_delay
# The -clock_fall flag indicates data is launched on the falling edge.
# Quartus will automatically check setup against the next rising edge.

# --- STR (Single Transfer Rate) Mode ---

# Maximum input delay: worst-case flash output delay + worst-case board delay
set INPUT_DELAY_MAX [expr {$FLASH_TCLQV_MAX + $BOARD_DELAY_MAX + $BOARD_CLK_SKEW}]

# Minimum input delay: best-case flash output hold + best-case board delay
set INPUT_DELAY_MIN [expr {$FLASH_TCLQX_MIN + $BOARD_DELAY_MIN - $BOARD_CLK_SKEW}]

foreach pin $FLASH_DATA_PINS {
    set_input_delay \
        -max $INPUT_DELAY_MAX \
        -clock spi_sclk_virtual \
        -clock_fall \
        [get_ports $pin]

    set_input_delay \
        -min $INPUT_DELAY_MIN \
        -clock spi_sclk_virtual \
        -clock_fall \
        [get_ports $pin]
}


# =============================================================================
# Section 6: Output Delay Constraints (FPGA -> Flash, Write/Command Path)
# =============================================================================
# In SPI Mode 0:
#   - FPGA launches data on the FALLING edge of SCLK
#   - Flash captures data on the RISING edge of SCLK
#
# Output delay is specified relative to the clock edge at the destination:
#   set_output_delay -max = tSI (setup) + board_delay
#   set_output_delay -min = -(tHI (hold)) + board_delay
#
# Using -clock_fall because FPGA launches data on falling edge.

# Maximum output delay: flash setup requirement + board delay
set OUTPUT_DELAY_MAX [expr {$FLASH_TSI_MIN + $BOARD_DELAY_MAX + $BOARD_CLK_SKEW}]

# Minimum output delay: negative of flash hold requirement + minimum board delay
set OUTPUT_DELAY_MIN [expr {-$FLASH_THI_MIN + $BOARD_DELAY_MIN - $BOARD_CLK_SKEW}]

foreach pin $FLASH_DATA_PINS {
    set_output_delay \
        -max $OUTPUT_DELAY_MAX \
        -clock spi_sclk_virtual \
        -clock_fall \
        [get_ports $pin]

    set_output_delay \
        -min $OUTPUT_DELAY_MIN \
        -clock spi_sclk_virtual \
        -clock_fall \
        [get_ports $pin]
}

# CS# output delay constraints (active low, directly driven by FPGA)
set_output_delay \
    -max $OUTPUT_DELAY_MAX \
    -clock spi_sclk_virtual \
    -clock_fall \
    [get_ports $FLASH_CS_N_PIN]

set_output_delay \
    -min $OUTPUT_DELAY_MIN \
    -clock spi_sclk_virtual \
    -clock_fall \
    [get_ports $FLASH_CS_N_PIN]


# =============================================================================
# Section 7: DTR (Double Transfer Rate) Mode Constraints
# =============================================================================
# In DTR mode, data is transferred on BOTH edges of SCLK.
# The flash launches and captures data on both rising and falling edges.
# Max frequency in DTR mode is 83 MHz (effective 166 MT/s).
#
# Uncomment this section if operating in DTR mode. When using DTR,
# comment out the STR constraints in Sections 5 and 6 above.

# set DTR_CLK_FREQ_MHZ     83.0
# set DTR_CLK_PERIOD_NS    [expr {1000.0 / $DTR_CLK_FREQ_MHZ}]
#
# create_clock \
#     -name spi_sclk_dtr_virtual \
#     -period $DTR_CLK_PERIOD_NS
#
# set DTR_INPUT_DELAY_MAX  [expr {$FLASH_DTR_TCLQV_MAX + $BOARD_DELAY_MAX + $BOARD_CLK_SKEW}]
# set DTR_INPUT_DELAY_MIN  [expr {$FLASH_TCLQX_MIN + $BOARD_DELAY_MIN - $BOARD_CLK_SKEW}]
#
# set DTR_OUTPUT_DELAY_MAX [expr {$FLASH_DTR_TSI_MIN + $BOARD_DELAY_MAX + $BOARD_CLK_SKEW}]
# set DTR_OUTPUT_DELAY_MIN [expr {-$FLASH_DTR_THI_MIN + $BOARD_DELAY_MIN - $BOARD_CLK_SKEW}]
#
# foreach pin $FLASH_DATA_PINS {
#     # Rising edge launch/capture
#     set_input_delay \
#         -max $DTR_INPUT_DELAY_MAX \
#         -clock spi_sclk_dtr_virtual \
#         [get_ports $pin]
#
#     set_input_delay \
#         -min $DTR_INPUT_DELAY_MIN \
#         -clock spi_sclk_dtr_virtual \
#         [get_ports $pin]
#
#     # Falling edge launch/capture (add_delay preserves the rising-edge constraint)
#     set_input_delay \
#         -max $DTR_INPUT_DELAY_MAX \
#         -clock spi_sclk_dtr_virtual \
#         -clock_fall -add_delay \
#         [get_ports $pin]
#
#     set_input_delay \
#         -min $DTR_INPUT_DELAY_MIN \
#         -clock spi_sclk_dtr_virtual \
#         -clock_fall -add_delay \
#         [get_ports $pin]
#
#     # Output delays for both edges
#     set_output_delay \
#         -max $DTR_OUTPUT_DELAY_MAX \
#         -clock spi_sclk_dtr_virtual \
#         [get_ports $pin]
#
#     set_output_delay \
#         -min $DTR_OUTPUT_DELAY_MIN \
#         -clock spi_sclk_dtr_virtual \
#         [get_ports $pin]
#
#     set_output_delay \
#         -max $DTR_OUTPUT_DELAY_MAX \
#         -clock spi_sclk_dtr_virtual \
#         -clock_fall -add_delay \
#         [get_ports $pin]
#
#     set_output_delay \
#         -min $DTR_OUTPUT_DELAY_MIN \
#         -clock spi_sclk_dtr_virtual \
#         -clock_fall -add_delay \
#         [get_ports $pin]
# }


# =============================================================================
# Section 8: Clock Uncertainty & Jitter
# =============================================================================
# Account for PLL jitter in the FPGA and clock network uncertainty.
# Adjust these values based on your FPGA family and PLL configuration.

set_clock_uncertainty -setup 0.200 [get_clocks spi_sclk_virtual]
set_clock_uncertainty -hold  0.100 [get_clocks spi_sclk_virtual]


# =============================================================================
# Section 9: Multicycle Path Exceptions
# =============================================================================
# If the SPI controller uses a slower internal clock and the SCLK is divided
# down from the system clock, multicycle paths may be needed.
# Uncomment and adjust if your SPI clock is a divided version of sys_clk.

# Example: SPI clock is sys_clk / 4
# set_multicycle_path -setup 4 -from [get_clocks $FPGA_SYS_CLK] -to [get_clocks spi_sclk_virtual]
# set_multicycle_path -hold  3 -from [get_clocks $FPGA_SYS_CLK] -to [get_clocks spi_sclk_virtual]


# =============================================================================
# Section 10: False Path Exceptions
# =============================================================================

# CS# deassertion is asynchronous to SCLK during idle (no data transfer).
# If your design deasserts CS# asynchronously, declare a false path.
# Uncomment if applicable:
# set_false_path -from [get_registers {*spi_ctrl*cs_idle*}] -to [get_ports $FLASH_CS_N_PIN]

# Cross-clock-domain paths (if SPI domain is asynchronous to system domain)
# set_false_path -from [get_clocks $FPGA_SYS_CLK] -to [get_clocks spi_sclk]
# set_false_path -from [get_clocks spi_sclk] -to [get_clocks $FPGA_SYS_CLK]

# If CDC synchronizers are used, constrain with set_max_delay instead:
# set_max_delay -from [get_clocks $FPGA_SYS_CLK] -to [get_clocks spi_sclk] $SPI_CLK_PERIOD_NS
# set_max_delay -from [get_clocks spi_sclk] -to [get_clocks $FPGA_SYS_CLK] $SPI_CLK_PERIOD_NS


# =============================================================================
# Section 11: SCLK Duty Cycle Validation
# =============================================================================
# The MX66U1G45G requires minimum high/low times on SCLK:
#   tCH >= 2.7 ns (SCLK high time)
#   tCL >= 2.7 ns (SCLK low time)
#
# At the maximum configured frequency, verify:
#   Half period = SPI_CLK_PERIOD_NS / 2.0
#
# If half period < 2.7 ns, the clock frequency is too high.

if {$SPI_HALF_PERIOD_NS < $FLASH_TCH_MIN} {
    post_message -type warning \
        "SPI clock half-period ([format %.2f $SPI_HALF_PERIOD_NS] ns) is less than \
         MX66U1G45G tCH minimum ($FLASH_TCH_MIN ns). Reduce SPI_CLK_FREQ_MHZ."
}

if {$SPI_HALF_PERIOD_NS < $FLASH_TCL_MIN} {
    post_message -type warning \
        "SPI clock half-period ([format %.2f $SPI_HALF_PERIOD_NS] ns) is less than \
         MX66U1G45G tCL minimum ($FLASH_TCL_MIN ns). Reduce SPI_CLK_FREQ_MHZ."
}


# =============================================================================
# Section 12: Timing Margin Report
# =============================================================================
# Print computed delay values for verification during constraint loading.

post_message -type info "=============================================="
post_message -type info "MX66U1G45G SDC Constraints Summary"
post_message -type info "=============================================="
post_message -type info "SPI Clock Frequency   : $SPI_CLK_FREQ_MHZ MHz"
post_message -type info "SPI Clock Period      : [format %.3f $SPI_CLK_PERIOD_NS] ns"
post_message -type info "SPI Half Period       : [format %.3f $SPI_HALF_PERIOD_NS] ns"
post_message -type info "----------------------------------------------"
post_message -type info "Input Delay Max (STR) : [format %.3f $INPUT_DELAY_MAX] ns"
post_message -type info "Input Delay Min (STR) : [format %.3f $INPUT_DELAY_MIN] ns"
post_message -type info "Output Delay Max      : [format %.3f $OUTPUT_DELAY_MAX] ns"
post_message -type info "Output Delay Min      : [format %.3f $OUTPUT_DELAY_MIN] ns"
post_message -type info "----------------------------------------------"
post_message -type info "Available Setup Margin: [format %.3f [expr {$SPI_HALF_PERIOD_NS - $INPUT_DELAY_MAX}]] ns"
post_message -type info "Board Delay Max       : $BOARD_DELAY_MAX ns"
post_message -type info "Board Delay Min       : $BOARD_DELAY_MIN ns"
post_message -type info "=============================================="


# =============================================================================
# End of MX66U1G45G SDC Constraints
# =============================================================================
