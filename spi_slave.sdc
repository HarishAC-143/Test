# ==============================================================================
# SDC Constraints for Altera (Intel) SPI Slave IP Core
# ==============================================================================
#
# Description:
#   Timing constraints for the Altera/Intel FPGA SPI Slave peripheral IP.
#   In slave mode the FPGA receives SCLK from an external master. SCLK is
#   therefore an input clock, which is fundamentally different from the
#   master configuration where SCLK is an output generated clock.
#
# SPI Signal Summary (Slave perspective):
#   SCLK  - Serial Clock       (input,  driven by the external master)
#   MOSI  - Master Out Slave In (input,  data driven by the external master)
#   MISO  - Master In Slave Out (output, data driven by this slave)
#   SS_n  - Slave Select        (input,  directly controlled by the master)
#
# SPI Modes (CPOL/CPHA):
#   Mode 0 (CPOL=0, CPHA=0): SCLK idles low,  data sampled on rising  edge
#   Mode 1 (CPOL=0, CPHA=1): SCLK idles low,  data sampled on falling edge
#   Mode 2 (CPOL=1, CPHA=0): SCLK idles high, data sampled on rising  edge
#   Mode 3 (CPOL=1, CPHA=1): SCLK idles high, data sampled on falling edge
#
# Key Difference from Master:
#   The slave does NOT generate SCLK -- it receives it. SCLK must be defined
#   as a primary input clock (create_clock), not a generated clock. The slave
#   has no control over SCLK frequency or phase, so timing closure depends
#   on correctly constraining the interface relative to the incoming SCLK.
#
# Usage:
#   1. Adjust the parameter section below to match your design.
#   2. Update pin/port/instance names to match your Quartus project hierarchy.
#   3. Source this file in Quartus via: Project > Settings > Timing Analyzer
#      > SDC files, or include it in your project's .qsf file.
#
# Target Tool: Intel Quartus Prime Timing Analyzer (TimeQuest)
# ==============================================================================


# ==============================================================================
# Section 1: Design Parameters -- Adjust these to match your design
# ==============================================================================

# System clock frequency (Hz) -- the FPGA's internal clock domain
# This is the clock used by the Avalon-MM interface and internal register logic.
set SYS_CLK_FREQ_MHZ       50.0
set SYS_CLK_PERIOD_NS      [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]

# SPI serial clock frequency (Hz) -- defined by the EXTERNAL master
# The slave has no control over this frequency; it is determined by the master.
set SPI_CLK_FREQ_MHZ       12.5
set SPI_CLK_PERIOD_NS      [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]

# Board-level trace delays (nanoseconds) -- measure or estimate from PCB layout
# These represent the propagation delay on the PCB traces between master and
# slave for each SPI signal.
set BOARD_DELAY_MAX         1.5   ;# Maximum PCB trace propagation delay
set BOARD_DELAY_MIN         0.5   ;# Minimum PCB trace propagation delay

# External SPI Master timing parameters (from the master device datasheet)
# These describe how the master drives and samples SPI signals.
set MASTER_TCO_MAX          7.0   ;# Master max clock-to-output for MOSI
set MASTER_TCO_MIN          1.0   ;# Master min clock-to-output for MOSI
set MASTER_TSU              5.0   ;# Master setup time for sampling MISO
set MASTER_TH               2.0   ;# Master hold time for sampling MISO
set MASTER_SS_TCO_MAX       7.0   ;# Master max clock-to-output for SS_n
set MASTER_SS_TCO_MIN       1.0   ;# Master min clock-to-output for SS_n

# Quartus hierarchy path to the SPI slave IP instance
set SPI_SLAVE_INST          "u_spi_slave"


# ==============================================================================
# Section 2: System (Reference) Clock Definition
# ==============================================================================

# Define the primary system clock used by the FPGA's internal logic,
# Avalon-MM bus interface, and SPI slave register file.
create_clock \
    -name sys_clk \
    -period $SYS_CLK_PERIOD_NS \
    [get_ports clk]


# ==============================================================================
# Section 3: SPI Input Clock Definition (SCLK)
# ==============================================================================

# SCLK is driven by the external SPI master and enters the FPGA as an input.
# Unlike the master configuration, SCLK is a PRIMARY clock (not a generated
# clock) because the FPGA has no internal clock from which it is derived.
#
# This is the most critical difference between master and slave SDC constraints.
# The period must match the maximum expected SCLK frequency from the master.

create_clock \
    -name spi_sclk \
    -period $SPI_CLK_PERIOD_NS \
    [get_ports spi_clk]


# ==============================================================================
# Section 4: Clock Uncertainty and Jitter
# ==============================================================================

# System clock uncertainty -- accounts for PLL jitter and on-chip variation
set_clock_uncertainty -setup 0.2 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.1 [get_clocks sys_clk]

# SPI clock uncertainty -- higher than system clock because SCLK travels over
# the PCB and is subject to board-level jitter, reflections, and noise.
# Use a larger value to add margin for the externally-sourced clock.
set_clock_uncertainty -setup 0.5 [get_clocks spi_sclk]
set_clock_uncertainty -hold  0.2 [get_clocks spi_sclk]


# ==============================================================================
# Section 5: Clock Domain Crossing (CDC) -- sys_clk <-> spi_sclk
# ==============================================================================

# SCLK and sys_clk are asynchronous to each other since SCLK originates from
# an external master device. The SPI slave IP uses internal synchronization
# (double-flop or handshake) to safely transfer data between these two
# unrelated clock domains.
#
# Mark the crossing as a false path so that TimeQuest does not attempt to
# time paths between these asynchronous domains. The synchronizer logic
# inside the IP handles metastability.

set_false_path -from [get_clocks sys_clk]   -to [get_clocks spi_sclk]
set_false_path -from [get_clocks spi_sclk]  -to [get_clocks sys_clk]

# IMPORTANT: If your SPI slave IP uses a FIFO or dual-clock bridge with
# gray-coded pointers (rather than simple double-flop synchronizers),
# you should replace the above false paths with set_max_delay constraints
# to ensure the gray-code bits arrive within one clock period:
#
# set_max_delay -from [get_clocks sys_clk]  -to [get_clocks spi_sclk] $SPI_CLK_PERIOD_NS
# set_max_delay -from [get_clocks spi_sclk] -to [get_clocks sys_clk]  $SYS_CLK_PERIOD_NS


# ==============================================================================
# Section 6: MOSI Input Constraints (Data FROM the external master)
# ==============================================================================

# MOSI is driven by the external SPI master relative to SCLK. The slave
# samples MOSI on the appropriate SCLK edge (rising or falling, depending
# on the SPI mode).
#
# Input delay = board_delay + master_clock_to_output
#
# -max: longest time after SCLK edge before valid MOSI arrives at FPGA pin
# -min: shortest time after SCLK edge before MOSI changes at FPGA pin

# --- Maximum input delay (for setup analysis) ---
set_input_delay \
    -clock spi_sclk \
    -max [expr {$BOARD_DELAY_MAX + $MASTER_TCO_MAX}] \
    [get_ports spi_mosi]

# --- Minimum input delay (for hold analysis) ---
set_input_delay \
    -clock spi_sclk \
    -min [expr {$BOARD_DELAY_MIN + $MASTER_TCO_MIN}] \
    [get_ports spi_mosi]

# For SPI Mode 1 or Mode 3 (CPHA=1), where the master launches MOSI on the
# rising edge and the slave captures on the falling edge, add -clock_fall:
#
# set_input_delay -clock spi_sclk -clock_fall \
#     -max [expr {$BOARD_DELAY_MAX + $MASTER_TCO_MAX}] \
#     [get_ports spi_mosi]
#
# set_input_delay -clock spi_sclk -clock_fall \
#     -min [expr {$BOARD_DELAY_MIN + $MASTER_TCO_MIN}] \
#     [get_ports spi_mosi]


# ==============================================================================
# Section 7: SS_n Input Constraints (Slave Select FROM the external master)
# ==============================================================================

# SS_n (Slave Select, active-low) is driven by the external master. The slave
# uses SS_n to know when it is selected for a transaction. SS_n must be stable
# before the first SCLK edge and held after the last SCLK edge.
#
# Constrain SS_n input delay relative to SCLK, similar to MOSI.

# --- Maximum input delay for SS_n ---
set_input_delay \
    -clock spi_sclk \
    -max [expr {$BOARD_DELAY_MAX + $MASTER_SS_TCO_MAX}] \
    [get_ports spi_ss_n]

# --- Minimum input delay for SS_n ---
set_input_delay \
    -clock spi_sclk \
    -min [expr {$BOARD_DELAY_MIN + $MASTER_SS_TCO_MIN}] \
    [get_ports spi_ss_n]


# ==============================================================================
# Section 8: MISO Output Constraints (Data TO the external master)
# ==============================================================================

# The slave drives MISO and the external master samples it. The output delay
# must account for board trace delay and the master's setup/hold requirements.
#
# set_output_delay -max = board_delay + master_setup_time
#   (MISO must arrive at master input this long BEFORE the sampling edge)
#
# set_output_delay -min = -(board_delay_min - master_hold_time)
#   (MISO must be held this long AFTER the sampling edge)

# --- Maximum output delay (for setup analysis at the master) ---
set_output_delay \
    -clock spi_sclk \
    -max [expr {$BOARD_DELAY_MAX + $MASTER_TSU}] \
    [get_ports spi_miso]

# --- Minimum output delay (for hold analysis at the master) ---
set_output_delay \
    -clock spi_sclk \
    -min [expr {$BOARD_DELAY_MIN - $MASTER_TH}] \
    [get_ports spi_miso]

# For SPI Mode 0 or Mode 2 (CPHA=0), the slave launches MISO on the falling
# SCLK edge and the master captures on the rising edge. Add -clock_fall:
#
# set_output_delay -clock spi_sclk -clock_fall \
#     -max [expr {$BOARD_DELAY_MAX + $MASTER_TSU}] \
#     [get_ports spi_miso]
#
# set_output_delay -clock spi_sclk -clock_fall \
#     -min [expr {$BOARD_DELAY_MIN - $MASTER_TH}] \
#     [get_ports spi_miso]


# ==============================================================================
# Section 9: MISO Tristate / High-Z Constraints
# ==============================================================================

# When SS_n is deasserted (high), the slave must tristate its MISO output to
# avoid bus contention in multi-slave topologies. The output enable (OE) for
# MISO is controlled by SS_n.
#
# If MISO has an output-enable register clocked by SCLK, constrain the OE
# path. Typically this is handled by the same output delay constraints above.
# If the OE is purely combinational from SS_n, it will be covered by the
# SS_n input constraints.
#
# No additional SDC constraints are usually needed for tristate behavior,
# but ensure your pin assignment has the correct output enable path.


# ==============================================================================
# Section 10: False Path Constraints
# ==============================================================================

# Asynchronous reset -- does not need to meet SPI clock timing
set_false_path -from [get_ports reset_n]

# If using an active-high reset:
# set_false_path -from [get_ports reset]

# Static configuration signals that are set once at initialization and do not
# change during SPI transactions (e.g., SPI mode selection bits).
#
# set_false_path \
#     -from [get_registers ${SPI_SLAVE_INST}|cpol_reg] \
#     -to [get_clocks spi_sclk]
#
# set_false_path \
#     -from [get_registers ${SPI_SLAVE_INST}|cpha_reg] \
#     -to [get_clocks spi_sclk]

# False path between SCLK and any unrelated clock domains (e.g., JTAG)
#
# set_false_path -from [get_clocks spi_sclk] -to [get_clocks altera_reserved_tck]
# set_false_path -from [get_clocks altera_reserved_tck] -to [get_clocks spi_sclk]


# ==============================================================================
# Section 11: Input Clock Latency (Optional, for board-level accuracy)
# ==============================================================================

# Since SCLK travels from the master across the PCB to the FPGA, it arrives
# with a delay relative to when the master drove it. Modeling this latency
# helps TimeQuest more accurately analyze the interface timing.
#
# set_clock_latency tells the tool about the external delay the clock
# experiences before reaching the FPGA clock input pin.
#
# -source: Latency before the clock reaches the FPGA pin (external/board)
# -late / -early: Pessimistic range for max/min analysis

set_clock_latency \
    -source \
    -late $BOARD_DELAY_MAX \
    [get_clocks spi_sclk]

set_clock_latency \
    -source \
    -early $BOARD_DELAY_MIN \
    [get_clocks spi_sclk]


# ==============================================================================
# Section 12: PLL and Derived Clock Handling
# ==============================================================================

# If the system clock is generated from a PLL, automatically derive all PLL
# output clocks so they are correctly constrained.

derive_pll_clocks

# Derive clock uncertainty from device and PLL characteristics.
# This Intel/Altera-specific command augments manual set_clock_uncertainty
# values with device-specific data.

derive_clock_uncertainty


# ==============================================================================
# Section 13: SCLK Gating and Glitch Considerations
# ==============================================================================

# SPI SCLK is inherently a gated clock -- it only toggles during a transaction
# and is idle between transactions. TimeQuest may flag warnings about clock
# gating. These warnings are expected for SPI and can be waived.
#
# If your FPGA fabric uses a global clock buffer for SCLK (recommended),
# ensure the pin assignment routes SCLK to a dedicated clock input pin.
# This minimizes clock skew across the FPGA.
#
# In Quartus, assign SCLK to a clock-capable pin:
#   set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to spi_clk
#   set_location_assignment PIN_XX -to spi_clk
#
# Where PIN_XX is a clock-capable input pin on your FPGA package.


# ==============================================================================
# Section 14: Multi-Slave Bus Topology Considerations
# ==============================================================================

# In a multi-slave SPI bus, each slave shares SCLK, MOSI, and MISO lines.
# Only the addressed slave (SS_n active) drives MISO; all others tristate.
#
# If multiple SPI slave instances exist in the FPGA (e.g., multiple SPI
# peripherals sharing one physical bus), each instance needs its own SS_n
# but shares the same SCLK, MOSI, and MISO port constraints.
#
# Example for a second slave instance:
#
# set_input_delay -clock spi_sclk \
#     -max [expr {$BOARD_DELAY_MAX + $MASTER_SS_TCO_MAX}] \
#     [get_ports spi_ss_n_2]
#
# set_input_delay -clock spi_sclk \
#     -min [expr {$BOARD_DELAY_MIN + $MASTER_SS_TCO_MIN}] \
#     [get_ports spi_ss_n_2]


# ==============================================================================
# Section 15: I/O Standard and Pin Assignments (Informational)
# ==============================================================================

# These are typically set in the .qsf file. Ensure SPI pins use the correct
# voltage standard and that SCLK is assigned to a clock-capable input pin.
#
# set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to spi_clk
# set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to spi_mosi
# set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to spi_miso
# set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to spi_ss_n
#
# Assign SCLK to a dedicated clock input pin for optimal clock distribution:
# set_location_assignment PIN_XX -to spi_clk


# ==============================================================================
# End of Altera SPI Slave SDC Constraints
# ==============================================================================
