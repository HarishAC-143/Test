# ==============================================================================
# Altera SPI IP Core — All Four SPI Modes: Unified Timing Constraints
# ==============================================================================
#
# This file provides a unified constraint template that covers all four SPI
# modes in a single SDC.  It uses Tcl conditionals so you can select the
# active mode by changing one variable.
#
# SPI Modes recap:
#   Mode 0: CPOL=0, CPHA=0 — Idle LOW,  sample on RISING,  shift on FALLING
#   Mode 1: CPOL=0, CPHA=1 — Idle LOW,  sample on FALLING, shift on RISING
#   Mode 2: CPOL=1, CPHA=0 — Idle HIGH, sample on FALLING, shift on RISING
#   Mode 3: CPOL=1, CPHA=1 — Idle HIGH, sample on RISING,  shift on FALLING
#
# ==============================================================================

# ==============================================================================
# SELECT YOUR SPI MODE HERE (0, 1, 2, or 3)
# ==============================================================================
set SPI_MODE 0

# ==============================================================================
# Parameters — adjust to match your design
# ==============================================================================
set SPI_CLK_FREQ_MHZ     25.0
set SYS_CLK_FREQ_MHZ    100.0

set BOARD_DELAY_MAX        1.5
set BOARD_DELAY_MIN        0.2

# For Master mode: external slave timing
set SLAVE_TSU              5.0
set SLAVE_TH               2.0
set SLAVE_TCO_MAX          8.0
set SLAVE_TCO_MIN          1.0

set SPI_CLK_PERIOD   [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]
set SYS_CLK_PERIOD   [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]

# ==============================================================================
# Derive edge selection from SPI_MODE
# ==============================================================================
#
# The sampling and shifting edges depend on the SPI mode:
#
#   Mode | CPOL | CPHA | Master samples MISO on | Master shifts MOSI on
#   -----|------|------|------------------------|----------------------
#     0  |   0  |   0  |  RISING                |  FALLING
#     1  |   0  |   1  |  FALLING               |  RISING
#     2  |   1  |   0  |  FALLING               |  RISING
#     3  |   1  |   1  |  RISING                |  FALLING
#
# For set_input_delay (MISO) we reference the LAUNCH edge (slave's shift edge).
# For set_output_delay (MOSI) we reference the CAPTURE edge (slave's sample edge).
#
# -clock_fall flag is used when the reference edge is the falling edge.
# ==============================================================================

# Determine which edge the slave samples MOSI (= master's output capture edge)
# and which edge the slave shifts MISO (= master's input launch edge).
if {$SPI_MODE == 0 || $SPI_MODE == 3} {
    # Slave samples on RISING  → MOSI output_delay references rising (no -clock_fall)
    # Slave shifts  on FALLING → MISO input_delay references falling (-clock_fall)
    set MOSI_CLOCK_FALL_FLAG ""
    set MISO_CLOCK_FALL_FLAG "-clock_fall"
} else {
    # Mode 1 or Mode 2
    # Slave samples on FALLING → MOSI output_delay references falling (-clock_fall)
    # Slave shifts  on RISING  → MISO input_delay references rising (no -clock_fall)
    set MOSI_CLOCK_FALL_FLAG "-clock_fall"
    set MISO_CLOCK_FALL_FLAG ""
}

# CPOL affects SCLK idle state and therefore the generated clock phase
if {$SPI_MODE == 0 || $SPI_MODE == 1} {
    set CPOL 0
} else {
    set CPOL 1
}

# ==============================================================================
# Clock Definitions
# ==============================================================================

set CLK_DIVIDE_FACTOR [expr {int($SYS_CLK_FREQ_MHZ / $SPI_CLK_FREQ_MHZ)}]

# For CPOL=1 the SCLK output is inverted.  Model this with -phase 180.
if {$CPOL == 0} {
    create_generated_clock \
        -name spi_sclk \
        -source [get_pins {spi_master|sclk_reg|clk}] \
        -divide_by $CLK_DIVIDE_FACTOR \
        [get_ports SPI_SCLK]
} else {
    create_generated_clock \
        -name spi_sclk \
        -source [get_pins {spi_master|sclk_reg|clk}] \
        -divide_by $CLK_DIVIDE_FACTOR \
        -phase 180 \
        [get_ports SPI_SCLK]
}

create_clock -name spi_sclk_virtual -period $SPI_CLK_PERIOD

# ==============================================================================
# Output Constraints: MOSI
# ==============================================================================

set MOSI_OUTPUT_DELAY_MAX [expr {$BOARD_DELAY_MAX + $SLAVE_TSU}]
set MOSI_OUTPUT_DELAY_MIN [expr {-($SLAVE_TH - $BOARD_DELAY_MIN)}]

eval set_output_delay -clock spi_sclk_virtual \
    -max $MOSI_OUTPUT_DELAY_MAX \
    $MOSI_CLOCK_FALL_FLAG \
    [get_ports SPI_MOSI]

eval set_output_delay -clock spi_sclk_virtual \
    -min $MOSI_OUTPUT_DELAY_MIN \
    $MOSI_CLOCK_FALL_FLAG \
    [get_ports SPI_MOSI]

# ==============================================================================
# Output Constraints: SS_n
# ==============================================================================

eval set_output_delay -clock spi_sclk_virtual \
    -max $MOSI_OUTPUT_DELAY_MAX \
    $MOSI_CLOCK_FALL_FLAG \
    [get_ports SPI_SS_n]

eval set_output_delay -clock spi_sclk_virtual \
    -min $MOSI_OUTPUT_DELAY_MIN \
    $MOSI_CLOCK_FALL_FLAG \
    [get_ports SPI_SS_n]

# ==============================================================================
# Input Constraints: MISO
# ==============================================================================

set MISO_INPUT_DELAY_MAX [expr {2 * $BOARD_DELAY_MAX + $SLAVE_TCO_MAX}]
set MISO_INPUT_DELAY_MIN [expr {2 * $BOARD_DELAY_MIN + $SLAVE_TCO_MIN}]

eval set_input_delay -clock spi_sclk_virtual \
    -max $MISO_INPUT_DELAY_MAX \
    $MISO_CLOCK_FALL_FLAG \
    [get_ports SPI_MISO]

eval set_input_delay -clock spi_sclk_virtual \
    -min $MISO_INPUT_DELAY_MIN \
    $MISO_CLOCK_FALL_FLAG \
    [get_ports SPI_MISO]

# ==============================================================================
# Clock Uncertainty
# ==============================================================================

set_clock_uncertainty -setup 0.200 [get_clocks spi_sclk]
set_clock_uncertainty -hold  0.050 [get_clocks spi_sclk]
set_clock_uncertainty -setup 0.200 [get_clocks spi_sclk_virtual]
set_clock_uncertainty -hold  0.050 [get_clocks spi_sclk_virtual]

# ==============================================================================
# False Paths
# ==============================================================================

set_false_path -from [get_ports SPI_MISO] -to [get_ports SPI_MOSI]
set_false_path -from [get_ports SPI_MISO] -to [get_ports SPI_SS_n]
set_false_path -from [get_ports SPI_MISO] -to [get_ports SPI_SCLK]

# ==============================================================================
# End of SPI Multimode Timing Constraints
# ==============================================================================
