# ==============================================================================
# SDC Timing Constraints for Altera (Intel) SPI Master IP Core
# ==============================================================================
#
# Target Device : Intel (Altera) FPGA (Cyclone / Stratix / Arria / MAX families)
# IP Core       : altera_avalon_spi (SPI Master mode)
# Author        : Auto-generated SDC
# Description   : Timing constraints for an SPI master interface.  The master
#                 drives SCLK, MOSI, and SS_n as outputs and samples MISO as
#                 an input.  Constraints are parameterised so that board-level
#                 trace delays and slave device timing can be adjusted in one
#                 place.
#
# SPI Signal Summary (Master perspective):
#   SCLK  - Generated clock output (directly drives the SPI bus clock)
#   MOSI  - Data output from master to slave
#   MISO  - Data input  from slave to master
#   SS_n  - Slave-select output (active-low chip-select)
#
# Revision History:
#   1.0  - Initial release with full timing constraints
#
# ==============================================================================


# ==============================================================================
# Section 1 : User-Tunable Parameters
# ==============================================================================
# Adjust these values to match your board layout and target SPI slave datasheet.
# All delay values are in nanoseconds.

# System clock frequency driving the SPI master logic (MHz)
set SYS_CLK_FREQ_MHZ       100.0

# SPI serial clock frequency (MHz) - must be an integer divisor of SYS_CLK_FREQ_MHZ
set SPI_SCLK_FREQ_MHZ      25.0

# Board-level PCB trace delays (one-way, in ns)
set BOARD_DELAY_MAX         1.0
set BOARD_DELAY_MIN         0.2

# SPI slave device timing parameters (from slave datasheet, in ns)
#   tSU  : Slave setup time for MOSI data before SCLK sampling edge
#   tHD  : Slave hold time for MOSI data after SCLK sampling edge
#   tCO  : Slave clock-to-output time for MISO after SCLK driving edge
#   tDIS : Slave MISO disable time after SS_n de-assertion
set SLAVE_TSU               5.0
set SLAVE_THD               5.0
set SLAVE_TCO_MAX           8.0
set SLAVE_TCO_MIN           0.0

# SPI port names (adjust to match your design hierarchy)
set SPI_MASTER_INST         "u_spi_master"
set PIN_SCLK                "spi_sclk"
set PIN_MOSI                "spi_mosi"
set PIN_MISO                "spi_miso"
set PIN_SS_N                "spi_ss_n"


# ==============================================================================
# Section 2 : System Clock Definition
# ==============================================================================
# The main system clock feeds the Avalon-MM interface and the SPI shift-register
# logic inside the IP core.  It is assumed to already be constrained elsewhere
# (e.g., by the Platform Designer / Qsys generated constraints).  If not,
# uncomment the line below.

# create_clock -name sys_clk -period [expr {1000.0 / $SYS_CLK_FREQ_MHZ}] [get_ports clk]


# ==============================================================================
# Section 3 : SPI Generated Clock (SCLK)
# ==============================================================================
# SCLK is generated inside the SPI master by dividing the system clock.
# The division factor is SYS_CLK_FREQ / SPI_SCLK_FREQ.
# We model SCLK as a generated clock so that the Timing Analyzer can
# accurately compute launch/latch relationships for output and input delays.

set sclk_period [expr {1000.0 / $SPI_SCLK_FREQ_MHZ}]
set sclk_div    [expr {int($SYS_CLK_FREQ_MHZ / $SPI_SCLK_FREQ_MHZ)}]

create_generated_clock \
    -name spi_sclk_clk \
    -source [get_pins ${SPI_MASTER_INST}|sclk_reg|q] \
    -divide_by $sclk_div \
    [get_ports $PIN_SCLK]

# Derive PLL clocks if any PLLs are present in the design
derive_pll_clocks -create_base_clocks


# ==============================================================================
# Section 4 : Output Delay Constraints — MOSI & SS_n
# ==============================================================================
# MOSI and SS_n are launched by the master on one SCLK edge.  The slave samples
# MOSI on the opposite edge (half-period later for CPOL=0 / CPHA=0).
#
# Output delay accounts for:
#   max = board delay (master-to-slave) + slave setup time
#   min = board delay min (master-to-slave) - slave hold time (negative = hold margin)
#
# These constraints tell the Timing Analyzer how much of the SCLK period is
# consumed by board propagation and slave input timing requirements, so it can
# verify the master launches data early enough.

set output_delay_max [expr {$BOARD_DELAY_MAX + $SLAVE_TSU}]
set output_delay_min [expr {$BOARD_DELAY_MIN - $SLAVE_THD}]

# MOSI output delay (data driven by master, sampled by slave)
set_output_delay -clock spi_sclk_clk -max $output_delay_max [get_ports $PIN_MOSI]
set_output_delay -clock spi_sclk_clk -min $output_delay_min [get_ports $PIN_MOSI]

# MOSI falling-edge analysis (for SPI modes where data changes on falling edge)
set_output_delay -clock spi_sclk_clk -max $output_delay_max [get_ports $PIN_MOSI] \
    -clock_fall -add_delay

set_output_delay -clock spi_sclk_clk -min $output_delay_min [get_ports $PIN_MOSI] \
    -clock_fall -add_delay

# SS_n (slave select) has the same output timing requirement as MOSI because
# it must be stable before the first SCLK edge of a transaction.
set_output_delay -clock spi_sclk_clk -max $output_delay_max [get_ports $PIN_SS_N]
set_output_delay -clock spi_sclk_clk -min $output_delay_min [get_ports $PIN_SS_N]


# ==============================================================================
# Section 5 : Input Delay Constraints — MISO
# ==============================================================================
# MISO is driven by the slave on one SCLK edge and sampled by the master on the
# opposite edge.
#
# Input delay accounts for:
#   max = board delay (slave-to-master) + slave Tco_max
#   min = board delay min (slave-to-master) + slave Tco_min
#
# The Timing Analyzer uses these values to verify that MISO data arrives at the
# master's input register with adequate setup and hold margin relative to the
# sampling SCLK edge.

set input_delay_max [expr {$BOARD_DELAY_MAX + $SLAVE_TCO_MAX}]
set input_delay_min [expr {$BOARD_DELAY_MIN + $SLAVE_TCO_MIN}]

# MISO input delay — rising edge (CPOL=0/CPHA=0: data launched on falling,
# captured on rising)
set_input_delay -clock spi_sclk_clk -max $input_delay_max [get_ports $PIN_MISO]
set_input_delay -clock spi_sclk_clk -min $input_delay_min [get_ports $PIN_MISO]

# MISO input delay — falling edge analysis (for SPI modes 1 & 2)
set_input_delay -clock spi_sclk_clk -max $input_delay_max [get_ports $PIN_MISO] \
    -clock_fall -add_delay

set_input_delay -clock spi_sclk_clk -min $input_delay_min [get_ports $PIN_MISO] \
    -clock_fall -add_delay


# ==============================================================================
# Section 6 : Clock Groups and Asynchronous Clock Domains
# ==============================================================================
# If the SPI clock domain is asynchronous to other clock domains in the design,
# declare them as exclusive or asynchronous to prevent the Timing Analyzer from
# reporting false cross-domain paths.

# set_clock_groups -asynchronous \
#     -group [get_clocks sys_clk] \
#     -group [get_clocks spi_sclk_clk]


# ==============================================================================
# Section 7 : False Paths
# ==============================================================================
# Static control/configuration registers written through the Avalon-MM interface
# are typically synchronised inside the IP.  Mark the CDC paths as false paths
# to avoid over-constraining.

# False path on the SPI clock-polarity (CPOL) configuration register
# set_false_path -from [get_registers ${SPI_MASTER_INST}|cpol_reg] \
#                -to   [get_registers ${SPI_MASTER_INST}|sclk_reg]

# False path on slave-select decode register (active only between transactions)
# set_false_path -from [get_registers ${SPI_MASTER_INST}|ss_reg*] \
#                -to   [get_ports $PIN_SS_N]


# ==============================================================================
# Section 8 : Multicycle Paths
# ==============================================================================
# The SPI shift register inside the IP operates at the SCLK rate, which is
# slower than the system clock.  Paths from the system clock domain to the
# SCLK domain may legitimately take multiple system clock cycles.
# Declare multicycle paths to give the tools the correct timing budget.

set spi_multicycle $sclk_div

# Multicycle setup for paths from system clock domain to SPI SCLK domain
# set_multicycle_path -setup $spi_multicycle \
#     -from [get_clocks sys_clk] \
#     -to   [get_clocks spi_sclk_clk]

# Multicycle hold (setup - 1) to keep hold analysis referenced to the correct edge
# set_multicycle_path -hold [expr {$spi_multicycle - 1}] \
#     -from [get_clocks sys_clk] \
#     -to   [get_clocks spi_sclk_clk]


# ==============================================================================
# Section 9 : Maximum Skew Constraints
# ==============================================================================
# Constrain skew between SCLK, MOSI, and SS_n at the output pins to ensure they
# arrive at the slave within an acceptable window.

set_max_skew -from [get_ports $PIN_SCLK] -to [get_ports $PIN_MOSI] 0.5
set_max_skew -from [get_ports $PIN_SCLK] -to [get_ports $PIN_SS_N] 0.5


# ==============================================================================
# Section 10 : I/O Standard and Drive Strength (Informational)
# ==============================================================================
# These are typically set in the QSF (Quartus Settings File), but are noted here
# for reference.  Uncomment if you want to drive them from the SDC flow.
#
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_SCLK
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_MOSI
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_MISO
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $PIN_SS_N
# set_instance_assignment -name CURRENT_STRENGTH_NEW "8mA" -to $PIN_SCLK
# set_instance_assignment -name CURRENT_STRENGTH_NEW "8mA" -to $PIN_MOSI
# set_instance_assignment -name CURRENT_STRENGTH_NEW "8mA" -to $PIN_SS_N


# ==============================================================================
# End of Altera SPI Master SDC Constraints
# ==============================================================================
