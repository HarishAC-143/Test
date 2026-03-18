# ==============================================================================
# SDC Timing Constraints for Altera (Intel) SPI Slave IP Core
# ==============================================================================
#
# Target Device : Intel (Altera) FPGA (Cyclone / Stratix / Arria / MAX families)
# IP Core       : altera_avalon_spi (SPI Slave mode)
# Author        : Auto-generated SDC
# Description   : Timing constraints for an SPI slave interface.  The slave
#                 receives SCLK, MOSI, and SS_n as inputs and drives MISO as
#                 an output.  The SCLK is sourced by an external master and
#                 enters the FPGA as a port-level clock, so it must be
#                 explicitly created.
#
# SPI Signal Summary (Slave perspective):
#   SCLK  - Clock input received from the external SPI master
#   MOSI  - Data input  from master to slave (this FPGA)
#   MISO  - Data output from slave (this FPGA) to master
#   SS_n  - Slave-select input (active-low chip-select from master)
#
# Revision History:
#   1.0  - Initial release with full timing constraints
#
# ==============================================================================


# ==============================================================================
# Section 1 : User-Tunable Parameters
# ==============================================================================
# Adjust these values to match your board layout and the external SPI master
# timing specifications.  All delay values are in nanoseconds.

# System clock frequency driving the slave Avalon-MM logic (MHz)
set SYS_CLK_FREQ_MHZ       100.0

# SPI serial clock frequency from the external master (MHz)
set SPI_SCLK_FREQ_MHZ      25.0

# Board-level PCB trace delays (one-way, in ns)
set BOARD_DELAY_MAX         1.0
set BOARD_DELAY_MIN         0.2

# External SPI master timing parameters (from master datasheet, in ns)
#   tCO_MOSI_MAX : Master clock-to-output delay for MOSI (max)
#   tCO_MOSI_MIN : Master clock-to-output delay for MOSI (min)
#   tSU_MISO     : Master setup time requirement for MISO before sampling edge
#   tHD_MISO     : Master hold time requirement for MISO after sampling edge
#   tCO_SS_MAX   : Master clock-to-output delay for SS_n assertion (max)
#   tCO_SS_MIN   : Master clock-to-output delay for SS_n assertion (min)
set MASTER_TCO_MOSI_MAX     7.0
set MASTER_TCO_MOSI_MIN     0.0
set MASTER_TSU_MISO         5.0
set MASTER_THD_MISO         5.0
set MASTER_TCO_SS_MAX       7.0
set MASTER_TCO_SS_MIN       0.0

# FPGA internal clock uncertainty / jitter (ns)
set CLK_UNCERTAINTY         0.2

# SPI port names (adjust to match your design hierarchy)
set SPI_SLAVE_INST          "u_spi_slave"
set PIN_SCLK                "spi_sclk"
set PIN_MOSI                "spi_mosi"
set PIN_MISO                "spi_miso"
set PIN_SS_N                "spi_ss_n"


# ==============================================================================
# Section 2 : System Clock Definition
# ==============================================================================
# The Avalon-MM system clock is assumed to be constrained by the Platform
# Designer / Qsys generated SDC.  If not, uncomment below.

# create_clock -name sys_clk -period [expr {1000.0 / $SYS_CLK_FREQ_MHZ}] [get_ports clk]


# ==============================================================================
# Section 3 : SPI Clock (SCLK) — External Input Clock
# ==============================================================================
# Unlike the master, the SPI slave receives SCLK from an external source.
# We create it as a primary clock on the SCLK input port.  The Timing Analyzer
# needs this clock to analyse setup/hold for MOSI input and clock-to-output
# for MISO.

set sclk_period [expr {1000.0 / $SPI_SCLK_FREQ_MHZ}]

create_clock \
    -name spi_sclk_clk \
    -period $sclk_period \
    [get_ports $PIN_SCLK]

# Apply clock uncertainty to account for jitter on the externally-sourced SCLK
set_clock_uncertainty -setup $CLK_UNCERTAINTY [get_clocks spi_sclk_clk]
set_clock_uncertainty -hold  $CLK_UNCERTAINTY [get_clocks spi_sclk_clk]

# Derive PLL clocks if any PLLs are present in the design
derive_pll_clocks -create_base_clocks

# Derive clock uncertainty for all clocks
derive_clock_uncertainty


# ==============================================================================
# Section 4 : Input Delay Constraints — MOSI
# ==============================================================================
# MOSI is driven by the external SPI master on one SCLK edge and must be
# sampled by the slave on the opposite edge (or same edge depending on CPHA).
#
# Input delay accounts for:
#   max = board delay (master-to-slave) + master Tco_max for MOSI
#   min = board delay min (master-to-slave) + master Tco_min for MOSI
#
# These constraints let the Timing Analyzer verify that the slave's input
# register has adequate setup and hold margin when sampling MOSI.

set mosi_input_delay_max [expr {$BOARD_DELAY_MAX + $MASTER_TCO_MOSI_MAX}]
set mosi_input_delay_min [expr {$BOARD_DELAY_MIN + $MASTER_TCO_MOSI_MIN}]

# MOSI input delay — rising edge (CPOL=0/CPHA=0: launched on falling by master,
# captured on rising by slave)
set_input_delay -clock spi_sclk_clk -max $mosi_input_delay_max [get_ports $PIN_MOSI]
set_input_delay -clock spi_sclk_clk -min $mosi_input_delay_min [get_ports $PIN_MOSI]

# MOSI input delay — falling edge analysis (for SPI modes 1 & 2 where data is
# launched on rising edge by master and captured on falling edge by slave)
set_input_delay -clock spi_sclk_clk -max $mosi_input_delay_max [get_ports $PIN_MOSI] \
    -clock_fall -add_delay

set_input_delay -clock spi_sclk_clk -min $mosi_input_delay_min [get_ports $PIN_MOSI] \
    -clock_fall -add_delay


# ==============================================================================
# Section 5 : Input Delay Constraints — SS_n (Slave Select)
# ==============================================================================
# SS_n is an asynchronous control signal driven by the master.  It gates the
# slave's SPI logic (enable transmit, load shift register, etc.).  We constrain
# it relative to SCLK so the analyser can verify it is sampled cleanly.

set ss_input_delay_max [expr {$BOARD_DELAY_MAX + $MASTER_TCO_SS_MAX}]
set ss_input_delay_min [expr {$BOARD_DELAY_MIN + $MASTER_TCO_SS_MIN}]

set_input_delay -clock spi_sclk_clk -max $ss_input_delay_max [get_ports $PIN_SS_N]
set_input_delay -clock spi_sclk_clk -min $ss_input_delay_min [get_ports $PIN_SS_N]


# ==============================================================================
# Section 6 : Output Delay Constraints — MISO
# ==============================================================================
# MISO is launched by the slave (this FPGA) on one SCLK edge and sampled by
# the master on the opposite edge.
#
# Output delay accounts for:
#   max = board delay (slave-to-master) + master setup time for MISO
#   min = board delay min (slave-to-master) - master hold time for MISO
#
# These constraints tell the Timing Analyzer how much of the SCLK period is
# consumed by board propagation and master input timing requirements, so it
# can verify the slave drives MISO early enough.

set miso_output_delay_max [expr {$BOARD_DELAY_MAX + $MASTER_TSU_MISO}]
set miso_output_delay_min [expr {$BOARD_DELAY_MIN - $MASTER_THD_MISO}]

# MISO output delay — rising edge (data launched on rising SCLK by slave)
set_output_delay -clock spi_sclk_clk -max $miso_output_delay_max [get_ports $PIN_MISO]
set_output_delay -clock spi_sclk_clk -min $miso_output_delay_min [get_ports $PIN_MISO]

# MISO output delay — falling edge analysis (for SPI modes where slave drives
# MISO on the falling SCLK edge)
set_output_delay -clock spi_sclk_clk -max $miso_output_delay_max [get_ports $PIN_MISO] \
    -clock_fall -add_delay

set_output_delay -clock spi_sclk_clk -min $miso_output_delay_min [get_ports $PIN_MISO] \
    -clock_fall -add_delay


# ==============================================================================
# Section 7 : Clock Groups — Asynchronous Domains
# ==============================================================================
# The external SPI clock (spi_sclk_clk) is asynchronous to the internal system
# clock because it originates from an external master.  Declaring them as
# asynchronous prevents the Timing Analyzer from reporting invalid cross-domain
# timing paths.

set_clock_groups -asynchronous \
    -group [get_clocks spi_sclk_clk] \
    -group [get_clocks {sys_clk}]


# ==============================================================================
# Section 8 : False Paths
# ==============================================================================
# Certain paths are logically excluded from timing analysis:
#
# 1. SS_n is an asynchronous enable and is typically synchronised with a
#    double-flop synchroniser inside the IP.  The raw input-to-first-flop path
#    has no meaningful timing relationship and can be marked false.
#
# 2. Static configuration registers that cross from the Avalon-MM (sys_clk)
#    domain into the SPI (sclk) domain are written only when SS_n is inactive.
#    They are effectively static during SPI transactions.

# False path on SS_n synchroniser (if present)
# set_false_path -from [get_ports $PIN_SS_N] \
#                -to   [get_registers ${SPI_SLAVE_INST}|ss_sync_reg[0]]

# False path on static configuration registers crossing clock domains
# set_false_path -from [get_registers ${SPI_SLAVE_INST}|cpol_reg] \
#                -to   [get_registers ${SPI_SLAVE_INST}|shift_reg*]

# False path on reset de-assertion crossing into SPI domain
# set_false_path -from [get_registers ${SPI_SLAVE_INST}|reset_sync*] \
#                -to   [get_clocks spi_sclk_clk]


# ==============================================================================
# Section 9 : Multicycle Paths
# ==============================================================================
# If the slave IP uses a multi-cycle data path (e.g., parallel load of shift
# register from Avalon-MM side that spans multiple SCLK cycles), multicycle
# path exceptions can relax the default single-cycle analysis.
#
# This is typically needed when the system clock is much faster than SCLK and
# the data transfer between domains is gated by SS_n.

# Multicycle setup from system clock to SPI clock domain
# set sclk_to_sys_ratio [expr {int($SYS_CLK_FREQ_MHZ / $SPI_SCLK_FREQ_MHZ)}]
# set_multicycle_path -setup $sclk_to_sys_ratio \
#     -from [get_clocks sys_clk] \
#     -to   [get_clocks spi_sclk_clk]
# set_multicycle_path -hold [expr {$sclk_to_sys_ratio - 1}] \
#     -from [get_clocks sys_clk] \
#     -to   [get_clocks spi_sclk_clk]


# ==============================================================================
# Section 10 : MISO Tri-state / High-Z Timing
# ==============================================================================
# When SS_n is de-asserted (high), the slave must tri-state its MISO output to
# release the bus for other slaves.  If the MISO pin uses an output-enable
# (tri-state) buffer, constrain the disable time so it does not conflict with
# another slave's drive.

# Maximum time from SS_n de-assertion to MISO going high-Z (ns)
set MISO_DISABLE_MAX 10.0

# set_max_delay $MISO_DISABLE_MAX \
#     -from [get_ports $PIN_SS_N] \
#     -to   [get_ports $PIN_MISO]


# ==============================================================================
# Section 11 : I/O Standard and Drive Strength (Informational)
# ==============================================================================
# These assignments are typically placed in the QSF file.  They are listed here
# for reference and completeness.
#
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_SCLK
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_MOSI
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_MISO
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_SS_N
# set_instance_assignment -name CURRENT_STRENGTH_NEW "8mA" -to $PIN_MISO


# ==============================================================================
# Section 12 : Report Commands (Optional — for Debug)
# ==============================================================================
# Uncomment these during timing closure to generate useful reports.
#
# report_timing -from [get_ports $PIN_MOSI] -setup -npaths 10 -panel_name "SPI MOSI Setup"
# report_timing -from [get_ports $PIN_MOSI] -hold  -npaths 10 -panel_name "SPI MOSI Hold"
# report_timing -to   [get_ports $PIN_MISO] -setup -npaths 10 -panel_name "SPI MISO Setup"
# report_timing -to   [get_ports $PIN_MISO] -hold  -npaths 10 -panel_name "SPI MISO Hold"
# report_clocks
# report_clock_transfers


# ==============================================================================
# End of Altera SPI Slave SDC Constraints
# ==============================================================================
