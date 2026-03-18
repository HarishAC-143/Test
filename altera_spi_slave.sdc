# ==============================================================================
# SDC Timing Constraints for Altera (Intel) SPI Slave IP Core
# ==============================================================================
#
# Description:
#   This SDC file provides timing constraints for the Altera/Intel SPI Slave
#   IP core (altera_avalon_spi configured as slave). In slave mode, the FPGA
#   receives the serial clock (SCLK) from an external SPI master, captures
#   MOSI and SS_n as inputs, and drives MISO as an output.
#
# SPI Slave Signal Roles:
#   - SCLK : Serial clock, received from external SPI master (INPUT)
#   - MOSI : Master Out Slave In, data from master (INPUT)
#   - MISO : Master In Slave Out, data to master (OUTPUT)
#   - SS_n : Slave Select, active-low chip select from master (INPUT)
#
# Key Difference from SPI Master:
#   In slave mode the FPGA does NOT generate SCLK. Instead, SCLK is an
#   external input clock that must be constrained with create_clock. All
#   I/O timing is referenced to this external clock.
#
# SPI Modes (CPOL/CPHA combinations):
#   - Mode 0 (CPOL=0, CPHA=0): Data sampled on SCLK rising, shifted on falling
#   - Mode 1 (CPOL=0, CPHA=1): Data sampled on SCLK falling, shifted on rising
#   - Mode 2 (CPOL=1, CPHA=0): Data sampled on SCLK falling, shifted on rising
#   - Mode 3 (CPOL=1, CPHA=1): Data sampled on SCLK rising, shifted on falling
#
# Usage:
#   1. Adjust SPI_SLAVE_INST to match your design hierarchy
#   2. Set SPI_SCLK_FREQ_MHZ to the maximum SCLK frequency from the master
#   3. Update board-level delay values (Tpcb_*) based on your PCB layout
#   4. Set SPI_MODE to match the master's SPI mode configuration
#   5. Source this file in your Quartus project or include via .qsf assignment
#
# Target Device : Intel/Altera FPGAs (Cyclone, Arria, Stratix families)
# Tool Version  : Quartus Prime 18.0+ / TimeQuest Timing Analyzer
# ==============================================================================


# ==============================================================================
# Section 1: User-Configurable Parameters
# ==============================================================================

# Hierarchical instance path to the SPI slave IP in your design
set SPI_SLAVE_INST "u_spi_slave"

# System clock frequency (MHz) - the Avalon bus clock driving the SPI slave core
set SYS_CLK_FREQ_MHZ 50.0

# Maximum SPI serial clock frequency (MHz) expected from the external master.
# This is the fastest SCLK the slave must support. Use the maximum rate
# specified by the master device or your system design.
set SPI_SCLK_FREQ_MHZ 25.0

# SPI mode selection (0, 1, 2, or 3) -- must match the master's configuration
set SPI_MODE 0

# FPGA pin names (directly mapped to top-level ports)
set SCLK_PORT  "spi_sclk"
set MOSI_PORT  "spi_mosi"
set MISO_PORT  "spi_miso"
set SS_N_PORT  "spi_ss_n"

# ------------------------------------------------------------------------------
# Board-Level Trace / PCB Delay Parameters (nanoseconds)
# These values must be characterized from your PCB layout or signal-integrity
# analysis. They represent propagation delay on the PCB traces.
# ------------------------------------------------------------------------------

# PCB trace delay from master SCLK pin to FPGA SCLK pin (ns)
set Tpcb_sclk 0.5

# PCB trace delay from master MOSI pin to FPGA MOSI pin (ns)
set Tpcb_mosi 0.5

# PCB trace delay from FPGA MISO pin to master MISO pin (ns)
set Tpcb_miso 0.5

# PCB trace delay from master SS_n pin to FPGA SS_n pin (ns)
set Tpcb_ss_n 0.5

# SPI Master device timing parameters (from master device datasheet)
# These describe when the master launches MOSI data and expects MISO data.
#
# Tco_master_max : Master clock-to-output delay for MOSI (max, ns)
# Tco_master_min : Master clock-to-output delay for MOSI (min, ns)
# Tsu_master     : Master setup time requirement for MISO input (ns)
# Th_master      : Master hold time requirement for MISO input (ns)
# Tco_ss_max     : Master clock-to-output delay for SS_n assertion (max, ns)
# Tco_ss_min     : Master clock-to-output delay for SS_n assertion (min, ns)
set Tco_master_max  7.0
set Tco_master_min  0.0
set Tsu_master      5.0
set Th_master       2.0
set Tco_ss_max      8.0
set Tco_ss_min      0.0


# ==============================================================================
# Section 2: System Clock Definition
# ==============================================================================

# Define the primary system clock that drives the Avalon-MM interface of the
# SPI slave core. This is the FPGA's internal clock, independent of SCLK.
set sys_clk_period [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]

create_clock -name sys_clk \
    -period $sys_clk_period \
    [get_ports clk]


# ==============================================================================
# Section 3: External SPI SCLK Clock Definition
# ==============================================================================

# In slave mode, SCLK is an external clock driven by the SPI master.
# We define it as a primary clock on the SCLK input port. This clock
# is the timing reference for all SPI bus I/O constraints.
#
# IMPORTANT: Use the maximum expected SCLK frequency. If the master can
# operate at multiple frequencies, constrain for the fastest one to ensure
# the design meets timing under worst-case conditions.

set sclk_period [expr {1000.0 / $SPI_SCLK_FREQ_MHZ}]

create_clock -name spi_sclk_in \
    -period $sclk_period \
    [get_ports $SCLK_PORT]

# Optionally define the SCLK with explicit waveform edges for non-50% duty cycle.
# Default is 50% duty cycle: rising at 0, falling at period/2.
# Uncomment and adjust if the master generates a non-standard duty cycle.
# create_clock -name spi_sclk_in \
#     -period $sclk_period \
#     -waveform [list 0 [expr {$sclk_period / 2.0}]] \
#     [get_ports $SCLK_PORT]


# ==============================================================================
# Section 4: Clock Groups -- SPI Clock vs. System Clock
# ==============================================================================

# The external SPI SCLK and the internal system clock are asynchronous
# (they originate from different oscillators/sources). Declare them as
# asynchronous clock groups so the timing analyzer does not attempt
# cross-domain analysis between them.
#
# The SPI slave IP internally handles clock domain crossing between the
# SCLK domain and the system clock domain using synchronization logic.

set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks spi_sclk_in]


# ==============================================================================
# Section 5: Input Delay Constraints -- MOSI
# ==============================================================================

# MOSI is driven by the external SPI master and captured by the FPGA slave
# on the appropriate SCLK edge. The input delay represents the total delay
# from the SCLK launch edge (at the master) to MOSI arriving at the FPGA pin.
#
# Input delay components:
#   - Master clock-to-output delay (Tco_master_max / Tco_master_min)
#   - PCB trace delay for MOSI (Tpcb_mosi)
#   - PCB trace delay for SCLK (already accounted for by create_clock on SCLK port)
#
# Since we define the clock at the FPGA's SCLK input pin, the SCLK PCB
# delay is already absorbed into the clock definition. We only need to
# account for the master's Tco and the MOSI trace delay relative to SCLK.
#
# For set_input_delay -max (setup analysis):
#   delay_max = Tco_master_max + Tpcb_mosi - Tpcb_sclk
#
# For set_input_delay -min (hold analysis):
#   delay_min = Tco_master_min + Tpcb_mosi - Tpcb_sclk

set mosi_input_delay_max [expr {$Tco_master_max + $Tpcb_mosi - $Tpcb_sclk}]
set mosi_input_delay_min [expr {$Tco_master_min + $Tpcb_mosi - $Tpcb_sclk}]

set_input_delay -clock spi_sclk_in \
    -max $mosi_input_delay_max \
    [get_ports $MOSI_PORT]

set_input_delay -clock spi_sclk_in \
    -min $mosi_input_delay_min \
    [get_ports $MOSI_PORT]

# For SPI modes where MOSI is sampled on the falling edge of SCLK,
# add -clock_fall constraints.
if {$SPI_MODE == 1 || $SPI_MODE == 2} {
    set_input_delay -clock spi_sclk_in \
        -max $mosi_input_delay_max \
        -clock_fall \
        [get_ports $MOSI_PORT] -add_delay

    set_input_delay -clock spi_sclk_in \
        -min $mosi_input_delay_min \
        -clock_fall \
        [get_ports $MOSI_PORT] -add_delay
}


# ==============================================================================
# Section 6: Input Delay Constraints -- SS_n (Chip Select)
# ==============================================================================

# SS_n is driven by the external SPI master. It is asserted (low) before
# the start of a transaction and de-asserted (high) at the end. The slave
# uses SS_n to enable/disable its shift register and tri-state MISO.
#
# SS_n timing is constrained relative to SCLK to ensure the slave correctly
# recognizes the select/de-select events relative to clock edges.
#
# Input delay components:
#   - Master clock-to-output delay for SS_n (Tco_ss_max / Tco_ss_min)
#   - PCB trace delay for SS_n (Tpcb_ss_n)
#   - SCLK trace delay already absorbed into clock at FPGA pin

set ss_input_delay_max [expr {$Tco_ss_max + $Tpcb_ss_n - $Tpcb_sclk}]
set ss_input_delay_min [expr {$Tco_ss_min + $Tpcb_ss_n - $Tpcb_sclk}]

set_input_delay -clock spi_sclk_in \
    -max $ss_input_delay_max \
    [get_ports $SS_N_PORT]

set_input_delay -clock spi_sclk_in \
    -min $ss_input_delay_min \
    [get_ports $SS_N_PORT]


# ==============================================================================
# Section 7: Output Delay Constraints -- MISO
# ==============================================================================

# MISO is driven by the FPGA slave and captured by the external SPI master
# on the appropriate SCLK edge. The output delay represents the timing
# requirements from the FPGA output to the master's sampling point.
#
# Output delay accounts for:
#   1. PCB trace delay from FPGA MISO pin to master MISO pin (Tpcb_miso)
#   2. Master setup time for MISO data (Tsu_master)
#   3. Master hold time for MISO data (Th_master)
#   4. SCLK trace delay (already in clock definition at FPGA pin)
#
# Since the clock is defined at the FPGA SCLK pin, and the master samples
# MISO relative to its own SCLK (which differs from the FPGA's SCLK by
# the SCLK PCB trace delay), we need a virtual clock to represent SCLK
# at the master.
#
# For set_output_delay -max (setup analysis):
#   delay_max = Tpcb_miso + Tsu_master - Tpcb_sclk
#   (Data must arrive at master Tsu before the sampling SCLK edge)
#
# For set_output_delay -min (hold analysis):
#   delay_min = Tpcb_miso - Th_master - Tpcb_sclk
#   (Data must be held for Th after the previous SCLK edge at master)

# Virtual clock representing SCLK at the master side, for output analysis.
# This is needed because the FPGA drives MISO relative to its local SCLK,
# but the master samples MISO relative to the master-side SCLK.
create_clock -name spi_sclk_at_master \
    -period $sclk_period

set miso_output_delay_max [expr {$Tpcb_miso + $Tsu_master - $Tpcb_sclk}]
set miso_output_delay_min [expr {$Tpcb_miso - $Th_master  - $Tpcb_sclk}]

set_output_delay -clock spi_sclk_at_master \
    -max $miso_output_delay_max \
    [get_ports $MISO_PORT]

set_output_delay -clock spi_sclk_at_master \
    -min $miso_output_delay_min \
    [get_ports $MISO_PORT]

# For SPI modes where MISO is sampled on the falling edge by the master,
# add -clock_fall constraints.
if {$SPI_MODE == 0 || $SPI_MODE == 3} {
    set_output_delay -clock spi_sclk_at_master \
        -max $miso_output_delay_max \
        -clock_fall \
        [get_ports $MISO_PORT] -add_delay

    set_output_delay -clock spi_sclk_at_master \
        -min $miso_output_delay_min \
        -clock_fall \
        [get_ports $MISO_PORT] -add_delay
}


# ==============================================================================
# Section 8: False Paths
# ==============================================================================

# False path on static configuration registers. In the SPI slave core,
# certain registers (SPI mode config, interrupt enables, etc.) are written
# by software once during initialization and remain static during transfers.
# These registers do not need to be timed across clock domains since proper
# synchronization is handled by the IP.

# set_false_path -from [get_registers ${SPI_SLAVE_INST}|control_reg*]
# set_false_path -from [get_registers ${SPI_SLAVE_INST}|irq_enable_reg*]

# False path for reset synchronization.
# If a reset signal crosses from sys_clk to spi_sclk_in domain, constrain
# it as a false path since reset synchronizers handle the CDC.

# set_false_path -from [get_registers ${SPI_SLAVE_INST}|reset_sync*]

# SS_n is often used as an asynchronous reset/enable for the SPI shift
# register. If it is handled asynchronously within the IP core logic,
# the path from SS_n to internal registers may be a false path for STA.

# set_false_path -from [get_ports $SS_N_PORT] \
#     -to [get_registers ${SPI_SLAVE_INST}|shift_reg*]


# ==============================================================================
# Section 9: Multicycle Path Constraints
# ==============================================================================

# In slave mode, the SPI clock is external and the FPGA has no control over
# its frequency. If the system clock is much faster than the SPI clock,
# the internal CDC synchronizers may warrant multicycle constraints.
#
# However, multicycle paths in slave mode are less common because the FPGA
# must meet timing at the SPI clock rate (which is the constraint).
#
# If the Avalon-MM readback path from the receive register is known to have
# multiple system clock cycles available (e.g., software polling interval
# is much longer than the sys_clk period), a multicycle can be applied:

# set_multicycle_path -setup -end 2 \
#     -from [get_registers ${SPI_SLAVE_INST}|rx_data_reg*] \
#     -to   [get_registers ${SPI_SLAVE_INST}|readdata_reg*]
# set_multicycle_path -hold -end 1 \
#     -from [get_registers ${SPI_SLAVE_INST}|rx_data_reg*] \
#     -to   [get_registers ${SPI_SLAVE_INST}|readdata_reg*]


# ==============================================================================
# Section 10: Clock Uncertainty
# ==============================================================================

# Clock uncertainty for the external SCLK accounts for:
#   - Jitter on the SPI master's clock source
#   - PCB trace skew between SCLK and data lines
#   - FPGA input clock buffer uncertainty
#
# Use conservative values. Consult the master device datasheet for jitter
# specifications and add margin for board-level effects.

# Setup uncertainty (pessimistic - tightens setup margin)
set_clock_uncertainty -setup 0.3 [get_clocks spi_sclk_in]

# Hold uncertainty (pessimistic - tightens hold margin)
set_clock_uncertainty -hold  0.15 [get_clocks spi_sclk_in]

# System clock uncertainty (adjust based on oscillator/PLL specifications)
set_clock_uncertainty -setup 0.2 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.1 [get_clocks sys_clk]

# Virtual clock at master side
set_clock_uncertainty -setup 0.3 [get_clocks spi_sclk_at_master]
set_clock_uncertainty -hold  0.15 [get_clocks spi_sclk_at_master]


# ==============================================================================
# Section 11: Clock Latency (Optional)
# ==============================================================================

# If you have accurate knowledge of the SCLK input clock tree latency
# within the FPGA (from the input buffer to the register clock pins),
# you can specify it to improve timing accuracy.
#
# Source latency: delay from the clock source (master) to the FPGA pin.
# This is typically the board trace delay, but since we define the clock
# at the FPGA pin, source latency is usually 0.
#
# Network latency: delay from the FPGA clock input pin through the clock
# tree to the register clock pins. The fitter usually calculates this
# automatically, so manual specification is rarely needed.

# set_clock_latency -source -early 0.0 [get_clocks spi_sclk_in]
# set_clock_latency -source -late  0.0 [get_clocks spi_sclk_in]


# ==============================================================================
# Section 12: MISO Tri-State / High-Impedance Constraints
# ==============================================================================

# When SS_n is de-asserted (high), the SPI slave must tri-state its MISO
# output to allow other slaves on a shared SPI bus to drive the line.
#
# The tri-state enable path from SS_n to the MISO output enable should be
# fast enough to avoid bus contention. This is typically handled by the
# FPGA's output enable logic and does not require SDC constraints, but
# you may want to verify the timing in the fitter report.
#
# If contention is a concern on a multi-slave bus, you can add a max_delay
# constraint on the tri-state path:

# set_max_delay -from [get_ports $SS_N_PORT] \
#     -to [get_ports $MISO_PORT] \
#     [expr {$sclk_period * 0.25}]


# ==============================================================================
# Section 13: I/O Standards and Pin Assignments
# ==============================================================================

# Set the I/O standard for SPI pins. Must match the voltage level of the
# external SPI master and the FPGA I/O bank voltage.
#
# Common standards:
#   3.3V: "3.3-V LVCMOS" or "3.3-V LVTTL"
#   2.5V: "2.5 V"
#   1.8V: "1.8 V"
#
# Uncomment and adjust to match your design.

# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $SCLK_PORT
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $MOSI_PORT
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $MISO_PORT
# set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to $SS_N_PORT

# For the MISO output pin, set drive strength to match the bus loading.
# Higher drive strength for long traces or heavily loaded buses.

# set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to $MISO_PORT

# Slew rate for MISO output
# set_instance_assignment -name SLEW_RATE 1 -to $MISO_PORT

# Enable internal pull-up on SS_n input to prevent floating when disconnected.
# This keeps the slave in de-selected state when no master is driving SS_n.

# set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to $SS_N_PORT


# ==============================================================================
# Section 14: Input Termination (Optional)
# ==============================================================================

# For high-speed SPI interfaces or long PCB traces, consider adding
# on-chip input termination to improve signal integrity on SCLK, MOSI,
# and SS_n inputs.

# set_instance_assignment -name INPUT_TERMINATION "PARALLEL 50 OHM WITH CALIBRATION" -to $SCLK_PORT
# set_instance_assignment -name INPUT_TERMINATION "PARALLEL 50 OHM WITH CALIBRATION" -to $MOSI_PORT
# set_instance_assignment -name INPUT_TERMINATION "PARALLEL 50 OHM WITH CALIBRATION" -to $SS_N_PORT


# ==============================================================================
# End of SPI Slave SDC Constraints
# ==============================================================================
