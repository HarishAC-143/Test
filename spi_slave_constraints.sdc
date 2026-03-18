# ==============================================================================
# Altera SPI IP Core — Slave Mode Timing Constraints
# ==============================================================================
#
# Target IP    : altera_avalon_spi (Intel/Altera Embedded Peripherals)
# Interface    : SPI Slave
# SDC Version  : Synopsys Design Constraints (IEEE 1735 / Quartus Prime)
#
# When the FPGA acts as an SPI slave, the clock (SCLK) is an INPUT driven
# by the external master.  This fundamentally changes the constraint
# strategy compared to master mode:
#
#   SCLK  — Serial Clock        (input,  driven by external master)
#   MOSI  — Master Out Slave In (input,  driven by external master)
#   MISO  — Master In Slave Out (output, driven by FPGA)
#   SS_n  — Slave Select         (input,  driven by external master)
#
# Because SCLK is an external, asynchronous clock, the Altera SPI slave
# core typically synchronises SCLK, MOSI, and SS_n through a double
# flip-flop (2FF) synchroniser clocked by the system clock.  This means
# the actual data capture happens in the sys_clk domain, NOT on the raw
# SCLK edge.
#
# Two constraint approaches are provided:
#   A) Direct SCLK-domain constraints (Sections 3–6) — use when the
#      IP core latches data directly on SCLK edges.
#   B) Synchroniser-based constraints (Section 7) — use when SCLK/MOSI
#      pass through 2FF synchronisers into the sys_clk domain.
#
# ==============================================================================

# ==============================================================================
# Section 1 — User-Configurable Parameters
# ==============================================================================
#
# SPI_CLK_FREQ_MHZ  : Maximum SCLK frequency the external master will drive.
# SYS_CLK_FREQ_MHZ  : System (Avalon) clock frequency.
#
# Board propagation delays (nanoseconds, one-way):
#   BOARD_DELAY_MAX  : Maximum PCB trace + connector propagation delay.
#   BOARD_DELAY_MIN  : Minimum PCB trace + connector propagation delay.
#
# External master timing characteristics (from master datasheet or known
# FPGA outputs if the master is another FPGA):
#   MASTER_TCO_MAX   : Master clock-to-output max for MOSI.
#   MASTER_TCO_MIN   : Master clock-to-output min for MOSI.
#   MASTER_SS_TSU    : Master SS_n assertion to first SCLK edge (setup).
#
# FPGA slave output requirements (how quickly the master needs MISO):
#   MASTER_TSU       : Master setup time requirement for MISO.
#   MASTER_TH        : Master hold time requirement for MISO.
# ==============================================================================

set SPI_CLK_FREQ_MHZ     25.0
set SYS_CLK_FREQ_MHZ    100.0

set BOARD_DELAY_MAX        1.5
set BOARD_DELAY_MIN        0.2

set MASTER_TCO_MAX         7.0
set MASTER_TCO_MIN         1.0
set MASTER_SS_TSU          5.0

set MASTER_TSU             5.0
set MASTER_TH              2.0

# Derived periods
set SPI_CLK_PERIOD   [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]
set SYS_CLK_PERIOD   [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]


# ==============================================================================
# Section 2 — System Clock Definition
# ==============================================================================
#
# The system clock drives the Avalon-MM bus interface of the SPI slave IP
# core.  It is typically defined by the PLL or top-level clock assignment.
# Uncomment if not already defined elsewhere.
# ==============================================================================

# create_clock -name sys_clk -period $SYS_CLK_PERIOD [get_ports clk]


# ==============================================================================
# Section 3 — External SCLK Clock Definition
# ==============================================================================
#
# SCLK is an input clock driven by the external SPI master.  It must be
# declared with create_clock so the timing analyser recognises it.
#
# Because SCLK is asynchronous to sys_clk, we also declare them in
# separate clock groups (Section 7).
#
# The period is set to the maximum SCLK frequency the design must support.
# ==============================================================================

create_clock -name spi_sclk_in -period $SPI_CLK_PERIOD [get_ports SPI_SCLK]


# ==============================================================================
# Section 4 — Input Constraints: MOSI and SS_n
# ==============================================================================
#
# MOSI and SS_n are driven by the external master synchronously with SCLK.
# The master shifts data on one edge and the slave captures on the opposite
# edge, giving half a clock period of margin.
#
# We express the timing budget at the FPGA input pin:
#
#   set_input_delay -max = MASTER_TCO_MAX + BOARD_DELAY_MAX
#       Total delay from master's SCLK edge to data arriving at FPGA.
#
#   set_input_delay -min = MASTER_TCO_MIN + BOARD_DELAY_MIN
#       Minimum version, used for hold analysis.
#
# Note on -clock_fall:
#   SPI Mode 0 / Mode 3 → master shifts on FALLING edge, slave samples
#   on RISING edge.  Use -clock_fall to reference the falling launch edge.
#
#   SPI Mode 1 / Mode 2 → master shifts on RISING edge, slave samples
#   on FALLING edge.  Remove -clock_fall to reference the rising launch edge.
# ==============================================================================

set MOSI_INPUT_DELAY_MAX [expr {$MASTER_TCO_MAX + $BOARD_DELAY_MAX}]
set MOSI_INPUT_DELAY_MIN [expr {$MASTER_TCO_MIN + $BOARD_DELAY_MIN}]

# --- SPI Mode 0 / Mode 3: Master shifts on FALLING, slave samples on RISING ---
set_input_delay -clock spi_sclk_in \
    -max $MOSI_INPUT_DELAY_MAX \
    -clock_fall \
    [get_ports SPI_MOSI]

set_input_delay -clock spi_sclk_in \
    -min $MOSI_INPUT_DELAY_MIN \
    -clock_fall \
    [get_ports SPI_MOSI]

# SS_n is asserted before SCLK starts and held throughout the transfer.
# Constrain it similarly to MOSI for completeness, though it is quasi-static.
set_input_delay -clock spi_sclk_in \
    -max $MOSI_INPUT_DELAY_MAX \
    [get_ports SPI_SS_n]

set_input_delay -clock spi_sclk_in \
    -min $MOSI_INPUT_DELAY_MIN \
    [get_ports SPI_SS_n]

# --- SPI Mode 1 / Mode 2: Master shifts on RISING, slave samples on FALLING ---
# Uncomment these and comment out the MOSI block above for Mode 1/2.
#
# set_input_delay -clock spi_sclk_in \
#     -max $MOSI_INPUT_DELAY_MAX \
#     [get_ports SPI_MOSI]
#
# set_input_delay -clock spi_sclk_in \
#     -min $MOSI_INPUT_DELAY_MIN \
#     [get_ports SPI_MOSI]


# ==============================================================================
# Section 5 — Output Constraints: MISO
# ==============================================================================
#
# MISO is driven by the FPGA slave and sampled by the external master.
# The master's setup and hold requirements must be met at the master's
# input pin.
#
# The output delay budget at the FPGA pin:
#
#   set_output_delay -max = BOARD_DELAY_MAX + MASTER_TSU
#       Time from SCLK edge (at FPGA) until data must be stable at master.
#
#   set_output_delay -min = -(MASTER_TH - BOARD_DELAY_MIN)
#       Negative value means the master can tolerate data changing this
#       much before the hold window closes, once trace delay is subtracted.
#
# Edge selection follows the same mode-dependent rules:
#   Mode 0/3: Slave shifts MISO on FALLING edge of SCLK.
#   Mode 1/2: Slave shifts MISO on RISING edge of SCLK.
# ==============================================================================

set MISO_OUTPUT_DELAY_MAX [expr {$BOARD_DELAY_MAX + $MASTER_TSU}]
set MISO_OUTPUT_DELAY_MIN [expr {-($MASTER_TH - $BOARD_DELAY_MIN)}]

# --- SPI Mode 0 / Mode 3: Slave shifts on FALLING edge ---
set_output_delay -clock spi_sclk_in \
    -max $MISO_OUTPUT_DELAY_MAX \
    -clock_fall \
    [get_ports SPI_MISO]

set_output_delay -clock spi_sclk_in \
    -min $MISO_OUTPUT_DELAY_MIN \
    -clock_fall \
    [get_ports SPI_MISO]

# --- SPI Mode 1 / Mode 2: Slave shifts on RISING edge ---
# Uncomment these and comment out the MISO block above for Mode 1/2.
#
# set_output_delay -clock spi_sclk_in \
#     -max $MISO_OUTPUT_DELAY_MAX \
#     [get_ports SPI_MISO]
#
# set_output_delay -clock spi_sclk_in \
#     -min $MISO_OUTPUT_DELAY_MIN \
#     [get_ports SPI_MISO]


# ==============================================================================
# Section 6 — Clock Uncertainty (Jitter)
# ==============================================================================
#
# SCLK is an externally-generated clock, so its jitter characteristics
# depend on the master's oscillator.  Apply a conservative uncertainty.
# ==============================================================================

set_clock_uncertainty -setup 0.300 [get_clocks spi_sclk_in]
set_clock_uncertainty -hold  0.100 [get_clocks spi_sclk_in]


# ==============================================================================
# Section 7 — Clock Domain Crossing: SCLK ↔ sys_clk
# ==============================================================================
#
# SCLK is asynchronous to sys_clk.  Paths between these domains must be
# handled carefully.
#
# APPROACH A — Asynchronous clock groups (use when 2FF synchronisers exist)
# -------------------------------------------------------------------------
# The altera_avalon_spi slave core with synchronisers enabled passes SCLK,
# MOSI, and SS_n through double flip-flop synchronisers clocked by sys_clk.
# Because the synchronisers handle metastability, we declare the two clock
# domains as asynchronous.  This tells Quartus NOT to perform setup/hold
# analysis across the domain boundary.
#
# APPROACH B — set_max_delay (use for tighter deterministic latency control)
# -------------------------------------------------------------------------
# Instead of a blanket false path, you can use set_max_delay to bound the
# crossing latency while still allowing timing analysis.  This is useful
# when you need to guarantee a maximum synchronisation latency.
# ==============================================================================

# APPROACH A: Asynchronous clock groups (recommended for most designs)
set_clock_groups -asynchronous \
    -group [get_clocks spi_sclk_in] \
    -group [get_clocks {sys_clk}]

# APPROACH B: Bounded crossing delay (alternative, uncomment if needed)
# set_max_delay -from [get_clocks spi_sclk_in] \
#               -to   [get_clocks sys_clk] \
#               [expr {$SYS_CLK_PERIOD * 2}]
# set_min_delay -from [get_clocks spi_sclk_in] \
#               -to   [get_clocks sys_clk] \
#               0


# ==============================================================================
# Section 8 — Synchroniser-Based Constraint Override
# ==============================================================================
#
# When the SPI IP core uses synchronisers, the actual data capture happens
# in the sys_clk domain, not on SCLK edges.  In this mode the SCLK input
# is treated as a regular data signal, not a clock.
#
# If your design uses this architecture, you can:
#   1. Remove the create_clock on SPI_SCLK.
#   2. Treat SPI_SCLK, SPI_MOSI, and SPI_SS_n as asynchronous inputs
#      with set_false_path or set_input_delay relative to sys_clk.
#
# The set_false_path approach acknowledges that these signals are truly
# asynchronous and the synchroniser handles the timing closure.
# ==============================================================================

# Alternative: Treat SPI inputs as asynchronous (synchroniser architecture)
# Uncomment this section and remove Section 3-5 if using synchronised design.
#
# set_false_path -from [get_ports SPI_SCLK]
# set_false_path -from [get_ports SPI_MOSI]
# set_false_path -from [get_ports SPI_SS_n]
#
# For MISO output, if the synchroniser-based slave generates MISO from
# sys_clk domain logic, constrain it relative to sys_clk:
#
# set_output_delay -clock sys_clk \
#     -max [expr {$SYS_CLK_PERIOD * 0.6}] \
#     [get_ports SPI_MISO]
#
# set_output_delay -clock sys_clk \
#     -min 0.0 \
#     [get_ports SPI_MISO]


# ==============================================================================
# Section 9 — False Paths for Logically Impossible Paths
# ==============================================================================
#
# Certain paths are structurally impossible in an SPI slave:
#   - No combinational path from MOSI to MISO (data passes through registers)
#   - No direct path from SS_n to MISO without clock intervention
# ==============================================================================

set_false_path -from [get_ports SPI_MOSI] -to [get_ports SPI_MISO]
set_false_path -from [get_ports SPI_SS_n] -to [get_ports SPI_MISO]


# ==============================================================================
# Section 10 — Multi-Slave Select Constraints
# ==============================================================================
#
# If the FPGA has multiple SPI slave interfaces (each with its own SS_n),
# only one can be active at a time.  Declare false paths between
# different slave instances to prevent cross-analysis.
#
# Example for two slave instances:
#   set_false_path -from [get_ports SPI_SS0_n] -to [get_ports SPI_SS1_n]
# ==============================================================================

# ==============================================================================
# End of SPI Slave Timing Constraints
# ==============================================================================
