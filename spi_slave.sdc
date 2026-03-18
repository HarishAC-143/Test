# ==============================================================================
# SDC Timing Constraints for Altera (Intel) SPI Slave IP
# ==============================================================================
#
# Target Device  : Intel (Altera) FPGA (Cyclone / Arria / Stratix families)
# IP             : Altera SPI Slave Core (ALTSERIAL_SPI / Intel SPI Slave)
# Tool           : Quartus Prime (Standard / Pro Edition)
#
# Description    : This SDC file defines the complete set of timing constraints
#                  required for correct static timing analysis of an SPI slave
#                  controller implemented in an Intel FPGA. The SPI slave
#                  receives the serial clock (SCLK) from an external master,
#                  samples MOSI, drives MISO, and monitors chip-select (SS_n).
#
# Key Difference : Unlike the SPI master, the slave does NOT generate SCLK.
#   (vs. Master)   SCLK is an external input clock that must be constrained
#                  as a primary clock. The FPGA must meet setup/hold times
#                  relative to an externally supplied clock edge.
#
# SPI Protocol   : Supports all four SPI modes (0-3) via CPOL/CPHA settings.
#
# Revision       : 1.0
# ==============================================================================


# ==============================================================================
#  Section 1 : User-Configurable Parameters
# ==============================================================================
# Adjust these values to match your design. All times are in nanoseconds (ns),
# all frequencies in megahertz (MHz).

# System clock frequency driving the SPI slave internal logic / register file
set SYS_CLK_FREQ_MHZ       100.0

# Maximum SPI serial clock (SCLK) frequency expected from the external master
set SPI_CLK_FREQ_MHZ       25.0

# Board-level trace / flight-time delays (PCB routing in ns)
set BOARD_DELAY_MAX         1.5
set BOARD_DELAY_MIN         0.5

# External SPI master timing parameters (from the master device datasheet)
set MASTER_TCO_MAX          7.0   ;# Master clock-to-output (MOSI) max delay
set MASTER_TCO_MIN          1.5   ;# Master clock-to-output (MOSI) min delay
set MASTER_TSU              5.0   ;# Master setup time requirement for MISO
set MASTER_TH               2.0   ;# Master hold time requirement for MISO

# FPGA I/O buffer delays (from Quartus Timing Analyzer or device datasheet)
set FPGA_OUT_DELAY_MAX      3.0   ;# FPGA output buffer delay max
set FPGA_OUT_DELAY_MIN      1.0   ;# FPGA output buffer delay min
set FPGA_IN_DELAY_MAX       2.5   ;# FPGA input buffer delay max
set FPGA_IN_DELAY_MIN       0.8   ;# FPGA input buffer delay min

# Pin names — update these to match your Quartus pin assignments
set PIN_SCLK                "spi_sclk"
set PIN_MOSI                "spi_mosi"
set PIN_MISO                "spi_miso"
set PIN_SS_N                "spi_ss_n"
set SYS_CLK_PIN             "sys_clk"


# ==============================================================================
#  Section 2 : System Clock Definition
# ==============================================================================
# The primary system clock that drives the internal SPI slave logic (register
# interface, FIFOs, status generation, interrupt logic, etc.).

set SYS_CLK_PERIOD [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]

create_clock -name sys_clk \
             -period $SYS_CLK_PERIOD \
             [get_ports $SYS_CLK_PIN]


# ==============================================================================
#  Section 3 : SPI Serial Clock (SCLK) — External Input Clock
# ==============================================================================
# Unlike the SPI master, the slave RECEIVES SCLK from the external master.
# SCLK must be defined as a primary clock on the FPGA input pin.
# This clock has inherent jitter and uncertainty because it originates
# off-chip — account for this via set_clock_uncertainty.

set SPI_CLK_PERIOD [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]

create_clock -name spi_sclk \
             -period $SPI_CLK_PERIOD \
             [get_ports $PIN_SCLK]

# Apply clock uncertainty to account for SCLK jitter from the external master,
# board-level clock tree skew, and FPGA input buffer variation.
set_clock_uncertainty -setup 0.3 [get_clocks spi_sclk]
set_clock_uncertainty -hold  0.15 [get_clocks spi_sclk]


# ==============================================================================
#  Section 4 : Input Delay Constraints — MOSI (Master Out, Slave In)
# ==============================================================================
# MOSI is driven by the external SPI master and captured by the slave (FPGA)
# on the appropriate SCLK edge. The input delay represents how long after the
# SCLK edge the data becomes valid at the FPGA pin.
#
# input_delay = master_tco + board_delay
#
# The -clock reference is spi_sclk because the FPGA captures MOSI relative
# to the incoming SPI clock.

# --- Maximum input delay (for setup analysis) ---
# Longest time from SCLK edge to valid MOSI at the FPGA input pin.
set MOSI_INPUT_DELAY_MAX [expr {$MASTER_TCO_MAX + $BOARD_DELAY_MAX}]

# --- Minimum input delay (for hold analysis) ---
# Shortest time from SCLK edge to MOSI changing at the FPGA input pin.
set MOSI_INPUT_DELAY_MIN [expr {$MASTER_TCO_MIN + $BOARD_DELAY_MIN}]

set_input_delay -clock spi_sclk \
                -max $MOSI_INPUT_DELAY_MAX \
                [get_ports $PIN_MOSI]

set_input_delay -clock spi_sclk \
                -min $MOSI_INPUT_DELAY_MIN \
                [get_ports $PIN_MOSI]

# For SPI Mode 1 or Mode 2 where data is captured on the falling edge of SCLK,
# add the -clock_fall flag:
#
# set_input_delay -clock spi_sclk -clock_fall \
#                 -max $MOSI_INPUT_DELAY_MAX \
#                 [get_ports $PIN_MOSI]
#
# set_input_delay -clock spi_sclk -clock_fall \
#                 -min $MOSI_INPUT_DELAY_MIN \
#                 [get_ports $PIN_MOSI]


# ==============================================================================
#  Section 5 : Input Delay Constraints — SS_n (Chip Select)
# ==============================================================================
# SS_n is an active-low signal driven by the external master to select this
# slave. It is typically sampled by the SCLK domain logic to gate the shift
# register and manage frame boundaries.
#
# Constrain SS_n as an input synchronized to spi_sclk so that the timing
# analyzer verifies it is stable around SCLK edges.

set SS_INPUT_DELAY_MAX [expr {$MASTER_TCO_MAX + $BOARD_DELAY_MAX}]
set SS_INPUT_DELAY_MIN [expr {$MASTER_TCO_MIN + $BOARD_DELAY_MIN}]

set_input_delay -clock spi_sclk \
                -max $SS_INPUT_DELAY_MAX \
                [get_ports $PIN_SS_N]

set_input_delay -clock spi_sclk \
                -min $SS_INPUT_DELAY_MIN \
                [get_ports $PIN_SS_N]

# If SS_n is used asynchronously (latched independently of SCLK), it may be
# more appropriate to constrain it relative to the system clock or declare
# it as a false path with respect to spi_sclk. See Section 9.


# ==============================================================================
#  Section 6 : Output Delay Constraints — MISO (Master In, Slave Out)
# ==============================================================================
# MISO is driven by the SPI slave (FPGA) and captured by the external master
# on the appropriate SCLK edge. The master has setup and hold requirements
# that the slave's output timing must satisfy.
#
# output_delay_max = board_delay_max + master_setup
# output_delay_min = board_delay_min
#
# The -clock reference is spi_sclk because the master captures MISO relative
# to the SPI clock that it generates.

# --- Maximum output delay (setup analysis at the master) ---
set MISO_OUTPUT_DELAY_MAX [expr {$BOARD_DELAY_MAX + $MASTER_TSU}]

# --- Minimum output delay (hold analysis at the master) ---
set MISO_OUTPUT_DELAY_MIN [expr {$BOARD_DELAY_MIN}]

set_output_delay -clock spi_sclk \
                 -max $MISO_OUTPUT_DELAY_MAX \
                 [get_ports $PIN_MISO]

set_output_delay -clock spi_sclk \
                 -min $MISO_OUTPUT_DELAY_MIN \
                 [get_ports $PIN_MISO]

# For SPI Mode 1 or Mode 2 where data is launched on the falling edge:
#
# set_output_delay -clock spi_sclk -clock_fall \
#                  -max $MISO_OUTPUT_DELAY_MAX \
#                  [get_ports $PIN_MISO]
#
# set_output_delay -clock spi_sclk -clock_fall \
#                  -min $MISO_OUTPUT_DELAY_MIN \
#                  [get_ports $PIN_MISO]


# ==============================================================================
#  Section 7 : Clock Groups — Asynchronous Clock Domain Crossing
# ==============================================================================
# The system clock (sys_clk) and the SPI clock (spi_sclk) are asynchronous
# because spi_sclk originates from an external master with no phase/frequency
# relationship to the FPGA's system clock.
#
# Declaring them as asynchronous prevents the timing analyzer from reporting
# false violations on cross-domain paths. The actual domain crossing must be
# handled in RTL via synchronizers, FIFOs, or handshake circuits.

set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks spi_sclk]


# ==============================================================================
#  Section 8 : Multicycle Path Constraints
# ==============================================================================
# If the SPI slave uses multi-stage synchronizers to transfer data from the
# spi_sclk domain to the sys_clk domain, multicycle path constraints can
# relax the timing requirements on those paths.
#
# Common scenario: a 2-stage synchronizer on control signals crossing from
# the SPI clock domain into the system clock domain.

# Example: 2-cycle multicycle path for synchronizer stages
# set_multicycle_path -setup 2 \
#     -from [get_clocks spi_sclk] \
#     -to   [get_clocks sys_clk]
#
# set_multicycle_path -hold 1 \
#     -from [get_clocks spi_sclk] \
#     -to   [get_clocks sys_clk]

# Example: Multicycle for the TX data load path (data loaded into shift
# register from sys_clk domain while SS_n is asserted but before first
# SCLK edge). This path has a full SPI frame period to settle.
#
# set_multicycle_path -setup 2 \
#     -from [get_clocks sys_clk] \
#     -to   [get_clocks spi_sclk] \
#     -through [get_pins {*spi_slave*|tx_shift_reg*|d}]
#
# set_multicycle_path -hold 1 \
#     -from [get_clocks sys_clk] \
#     -to   [get_clocks spi_sclk] \
#     -through [get_pins {*spi_slave*|tx_shift_reg*|d}]


# ==============================================================================
#  Section 9 : False Path Constraints
# ==============================================================================
# Certain paths do not carry timing-critical data and should be excluded
# from timing analysis to avoid false violations and improve analysis runtime.

# --- Asynchronous reset path ---
# If the SPI slave has an asynchronous active-low reset, exclude it from
# timing analysis. The reset recovery/removal check is handled separately
# by the tool if needed.

# set_false_path -from [get_ports reset_n]

# --- Static configuration registers ---
# SPI mode (CPOL/CPHA), data width, and other configuration registers that
# are written by firmware and remain stable during SPI transactions.

# set_false_path -from [get_registers {*spi_slave*|cpol_reg}]
# set_false_path -from [get_registers {*spi_slave*|cpha_reg}]

# --- SS_n used as an asynchronous enable ---
# If SS_n is only used as an asynchronous gate (not sampled by a clock edge),
# declare it as a false path with respect to timing analysis.

# set_false_path -from [get_ports $PIN_SS_N] \
#                -to   [get_registers {*spi_slave*|shift_reg*}]


# ==============================================================================
#  Section 10 : Maximum / Minimum Delay Constraints (Optional)
# ==============================================================================
# For high-speed SPI interfaces, you may want to directly constrain the
# maximum propagation delay on specific paths.

# Constrain max delay on the MISO output path to guarantee the slave's
# clock-to-output time meets the master's setup requirement.
# set_max_delay -from [get_registers {*spi_slave*|miso_reg}] \
#               -to   [get_ports $PIN_MISO] \
#               [expr {$SPI_CLK_PERIOD / 2.0 - $MASTER_TSU - $BOARD_DELAY_MAX}]

# Constrain min delay on MISO to ensure hold time at the master.
# set_min_delay -from [get_registers {*spi_slave*|miso_reg}] \
#               -to   [get_ports $PIN_MISO] \
#               [expr {$MASTER_TH + $BOARD_DELAY_MIN}]


# ==============================================================================
#  Section 11 : Clock Latency (Optional)
# ==============================================================================
# Model external clock source latency if known. This helps the timing
# analyzer account for the delay from the master's clock source to the
# FPGA SCLK input pin.
#
# -source latency: delay inside the clock source (master oscillator to pad)
# -early / -late: min/max bounds on the latency

# set_clock_latency -source -early 0.5 [get_clocks spi_sclk]
# set_clock_latency -source -late  2.0 [get_clocks spi_sclk]


# ==============================================================================
#  Section 12 : Input / Output Transition Times (Optional)
# ==============================================================================
# Specify the slew rate (transition time) of external signals arriving at
# the FPGA pins. Slower transitions increase uncertainty in the sampling
# point and should be accounted for in timing analysis.

# MOSI and SS_n from external master — typical 1-4 ns transitions
# set_input_transition -max 4.0 [get_ports "$PIN_MOSI $PIN_SS_N"]
# set_input_transition -min 1.0 [get_ports "$PIN_MOSI $PIN_SS_N"]

# SCLK transition time — external clock edge rate
# set_input_transition -max 2.0 [get_ports $PIN_SCLK]
# set_input_transition -min 0.5 [get_ports $PIN_SCLK]


# ==============================================================================
#  Section 13 : MISO Tri-State / High-Impedance Handling
# ==============================================================================
# When SS_n is deasserted (high), the SPI slave must tri-state its MISO
# output to allow other slaves on a shared bus to drive. The tri-state
# control path is not timing-critical relative to SCLK because it only
# changes state between transactions.

# set_false_path -from [get_registers {*spi_slave*|miso_oe_reg}] \
#                -to   [get_ports $PIN_MISO]

# If MISO uses the FPGA's output enable (OE) control and the enable is
# directly tied to SS_n, you can also false-path the OE:
# set_false_path -from [get_ports $PIN_SS_N] \
#                -to   [get_pins {*spi_slave*|miso_obuf|oe}]


# ==============================================================================
#  End of SPI Slave SDC Constraints
# ==============================================================================
