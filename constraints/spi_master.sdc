# ==============================================================================
# Altera/Intel FPGA — SPI Master IP Core Timing Constraints
# ==============================================================================
#
# Target  : Quartus Prime Timing Analyzer (TimeQuest)
# Format  : Synopsys Design Constraints (SDC)
# Scope   : SPI Master interface (FPGA drives SCLK, MOSI, SS_n; samples MISO)
#
# HOW TO USE
# ----------
#   1. Copy this file into your Quartus project directory.
#   2. Adjust the parameters in Section 0 to match your design.
#   3. Add the file to your project:
#        Assignments -> Settings -> Timing Analyzer -> SDC files
#   4. Run "Update Timing Netlist" and review the reports.
#
# ==============================================================================


# ==============================================================================
# SECTION 0 — USER-CONFIGURABLE PARAMETERS
# ==============================================================================
# Modify these values to match your design and board.

# ---- Clock Frequencies ----
set sys_clk_freq_mhz    50.0       ;# System clock frequency in MHz
set spi_clk_freq_mhz    25.0       ;# SPI SCLK frequency in MHz

# ---- SPI Mode (CPOL / CPHA) ----
#   Mode 0: CPOL=0, CPHA=0  —  idle low,  sample on rising,  shift on falling
#   Mode 1: CPOL=0, CPHA=1  —  idle low,  sample on falling, shift on rising
#   Mode 2: CPOL=1, CPHA=0  —  idle high, sample on falling, shift on rising
#   Mode 3: CPOL=1, CPHA=1  —  idle high, sample on rising,  shift on falling
set spi_cpol             0
set spi_cpha             0

# ---- Board / Trace Delays (ns) ----
# These represent the PCB trace propagation delay between the FPGA and the
# external SPI slave device.  Measure or estimate from your board layout.
set board_delay_max      1.5       ;# Maximum one-way board trace delay (ns)
set board_delay_min      0.5       ;# Minimum one-way board trace delay (ns)

# ---- External SPI Slave Device Timing (ns) ----
# Obtain these values from the slave device datasheet.
set slave_tsu            5.0       ;# Slave input setup time (data before SCLK edge)
set slave_th             2.0       ;# Slave input hold time  (data after  SCLK edge)
set slave_tco_max       10.0       ;# Slave clock-to-output max (MISO valid after SCLK)
set slave_tco_min        2.0       ;# Slave clock-to-output min (MISO valid after SCLK)

# ---- FPGA Pin Names ----
# Adjust these to match your top-level port names or pin assignments.
set spi_sclk_pin         "spi_sclk"
set spi_mosi_pin         "spi_mosi"
set spi_miso_pin         "spi_miso"
set spi_ss_n_pin         "spi_ss_n"
set sys_clk_pin          "sys_clk"

# ---- Number of Slave Select Lines ----
set num_ss_lines         1         ;# Set >1 if you have multiple SS_n pins


# ==============================================================================
# SECTION 1 — DERIVED VALUES (do not edit)
# ==============================================================================

set sys_clk_period_ns    [expr {1000.0 / $sys_clk_freq_mhz}]
set spi_clk_period_ns    [expr {1000.0 / $spi_clk_freq_mhz}]
set spi_clk_half_period  [expr {$spi_clk_period_ns / 2.0}]


# ==============================================================================
# SECTION 2 — SYSTEM CLOCK DEFINITION
# ==============================================================================
# The system clock drives the SPI master IP core's internal logic.  All register
# transfers inside the core are synchronous to this clock.
#
# If your system clock is already defined elsewhere (e.g., by a PLL IP), you may
# comment this out or verify the name matches.

create_clock -name sys_clk \
             -period $sys_clk_period_ns \
             [get_ports $sys_clk_pin]


# ==============================================================================
# SECTION 3 — SPI OUTPUT CLOCK (SCLK) AS GENERATED CLOCK
# ==============================================================================
# The FPGA generates SCLK from the system clock via a clock divider inside the
# SPI master IP.  We model this as a generated clock so the Timing Analyzer can
# track the phase relationship between sys_clk and SCLK.
#
# IMPORTANT: The -source should reference the register or PLL output that
# actually drives the SCLK pin.  If the IP core uses a simple toggle register,
# point -source at that register's clock pin.  The divide_by ratio must match
# the actual clock divider configuration.
#
# For CPOL=1 modes, the clock is inverted (idle high).  We model this with a
# phase shift of 180 degrees.

if {$spi_cpol == 0} {
    set sclk_phase 0
} else {
    set sclk_phase 180
}

set sclk_divide_ratio [expr {int($sys_clk_freq_mhz / $spi_clk_freq_mhz)}]

create_generated_clock -name spi_sclk_out \
                       -source [get_ports $sys_clk_pin] \
                       -divide_by $sclk_divide_ratio \
                       -phase $sclk_phase \
                       [get_ports $spi_sclk_pin]


# ==============================================================================
# SECTION 4 — VIRTUAL CLOCK FOR EXTERNAL SPI SLAVE
# ==============================================================================
# A virtual clock represents the SCLK as seen at the external slave device.
# It has the same frequency and phase as spi_sclk_out, but it is "virtual"
# (not connected to any FPGA pin) because it models the clock domain at the
# far end of the PCB trace.
#
# We use this virtual clock as the reference for set_input_delay (MISO) and
# set_output_delay (MOSI, SS_n) constraints.

create_clock -name virtual_spi_sclk \
             -period $spi_clk_period_ns


# ==============================================================================
# SECTION 5 — OUTPUT DELAY CONSTRAINTS (MOSI, SS_n)
# ==============================================================================
# MOSI and SS_n are outputs from the FPGA.  The external slave samples them
# on a specific SCLK edge.  We must ensure that MOSI arrives at the slave
# with enough setup and hold margin relative to the sampling edge.
#
# Timing budget (center-aligned):
#
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  SCLK at FPGA  ──→ [board_delay] ──→  SCLK at slave           │
#   │  MOSI at FPGA  ──→ [board_delay] ──→  MOSI at slave           │
#   │                                                                │
#   │  set_output_delay -max = board_delay_max + slave_tsu           │
#   │    (Data must arrive slave_tsu BEFORE the sampling clock edge)  │
#   │                                                                │
#   │  set_output_delay -min = -(board_delay_min + slave_th)         │
#   │    (Data must remain valid slave_th AFTER the sampling edge,   │
#   │     but since SCLK and MOSI travel together, the relative      │
#   │     delay is the difference, which can be negative)            │
#   └─────────────────────────────────────────────────────────────────┘
#
# Because both SCLK and MOSI travel across the same PCB traces (approximately),
# the board delays partially cancel.  However, trace length mismatches and
# parasitics cause residual skew, so we use worst-case bounds.

set output_delay_max [expr {$board_delay_max + $slave_tsu}]
set output_delay_min [expr {-($board_delay_max - $board_delay_min)}]

# MOSI output delay
set_output_delay -clock virtual_spi_sclk \
                 -max $output_delay_max \
                 [get_ports $spi_mosi_pin]

set_output_delay -clock virtual_spi_sclk \
                 -min $output_delay_min \
                 [get_ports $spi_mosi_pin]

# SS_n output delay — SS_n must be asserted well before the first SCLK edge
# and deasserted after the last edge.  We constrain it the same way as MOSI,
# though its timing is typically far less critical.
if {$num_ss_lines == 1} {
    set_output_delay -clock virtual_spi_sclk \
                     -max $output_delay_max \
                     [get_ports $spi_ss_n_pin]

    set_output_delay -clock virtual_spi_sclk \
                     -min $output_delay_min \
                     [get_ports $spi_ss_n_pin]
} else {
    for {set i 0} {$i < $num_ss_lines} {incr i} {
        set_output_delay -clock virtual_spi_sclk \
                         -max $output_delay_max \
                         [get_ports "${spi_ss_n_pin}\[$i\]"]

        set_output_delay -clock virtual_spi_sclk \
                         -min $output_delay_min \
                         [get_ports "${spi_ss_n_pin}\[$i\]"]
    }
}


# ==============================================================================
# SECTION 6 — INPUT DELAY CONSTRAINTS (MISO)
# ==============================================================================
# MISO is driven by the external slave device.  The slave clocks data out on
# one SCLK edge, and the FPGA samples it on the opposite edge (giving a full
# half-period of margin).
#
# Timing budget:
#
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  SCLK at slave (launch edge)                                   │
#   │    + slave_tco  → MISO valid at slave pin                      │
#   │    + board_delay → MISO arrives at FPGA pin                    │
#   │                                                                │
#   │  set_input_delay -max = board_delay_max + slave_tco_max        │
#   │  set_input_delay -min = board_delay_min + slave_tco_min        │
#   └─────────────────────────────────────────────────────────────────┘
#
# The FPGA latches MISO on the next (opposite) SCLK edge, giving a full
# half-period minus these delays as the available setup window.

set input_delay_max [expr {$board_delay_max + $slave_tco_max}]
set input_delay_min [expr {$board_delay_min + $slave_tco_min}]

set_input_delay -clock virtual_spi_sclk \
                -max $input_delay_max \
                [get_ports $spi_miso_pin]

set_input_delay -clock virtual_spi_sclk \
                -min $input_delay_min \
                [get_ports $spi_miso_pin]


# ==============================================================================
# SECTION 7 — MULTICYCLE PATH EXCEPTIONS
# ==============================================================================
# In many SPI master designs, the internal logic runs at the system clock
# frequency, which is much faster than SCLK.  The SPI shift register only
# updates once per SCLK period (or half-period), not every sys_clk cycle.
#
# Without multicycle constraints, the Timing Analyzer assumes all paths must
# meet single-cycle sys_clk timing (e.g. 20 ns at 50 MHz), which is overly
# pessimistic for paths that have a full SCLK period to settle.
#
# We relax the constraint by declaring these as multicycle paths.  The
# multiplier equals the ratio of SCLK period to sys_clk period.
#
# CAUTION: Only apply multicycle constraints to paths you have verified
# actually have multiple clock cycles to settle.  Mis-applied multicycle
# constraints will hide real timing violations.

set multicycle_count $sclk_divide_ratio

# Multicycle on MOSI output path (data changes once per SCLK period)
set_multicycle_path -setup -end $multicycle_count \
                    -to [get_ports $spi_mosi_pin]
set_multicycle_path -hold  -end [expr {$multicycle_count - 1}] \
                    -to [get_ports $spi_mosi_pin]

# Multicycle on MISO input path (data is sampled once per SCLK period)
set_multicycle_path -setup -end $multicycle_count \
                    -from [get_ports $spi_miso_pin]
set_multicycle_path -hold  -end [expr {$multicycle_count - 1}] \
                    -from [get_ports $spi_miso_pin]


# ==============================================================================
# SECTION 8 — FALSE PATH EXCEPTIONS
# ==============================================================================
# Certain paths in the SPI master design are either asynchronous or are
# never exercised during normal operation.  Declaring them as false paths
# prevents the Timing Analyzer from reporting spurious violations.

# 8a. SS_n to MISO — There is no direct timing relationship between the
# slave select assertion and the MISO data.  MISO is always referenced
# to SCLK, not to SS_n.
if {$num_ss_lines == 1} {
    set_false_path -from [get_ports $spi_ss_n_pin] -to [get_ports $spi_miso_pin]
}

# 8b. Reset paths — If your design has an asynchronous reset, constrain it
# as a false path.  The reset is not a synchronous data transfer.
# Uncomment and adjust the pin name as needed:
# set_false_path -from [get_ports reset_n]

# 8c. Clock domain crossing — If SPI status/data registers are read by
# logic in a different clock domain (e.g., an Avalon-MM bus clock), and
# proper synchronizers are in place, mark the crossing as a false path
# or use set_max_delay for more control.
# set_false_path -from [get_clocks spi_sclk_out] -to [get_clocks avalon_clk]
# set_false_path -from [get_clocks avalon_clk]   -to [get_clocks spi_sclk_out]


# ==============================================================================
# SECTION 9 — CLOCK GROUPS (ASYNCHRONOUS CLOCK DOMAINS)
# ==============================================================================
# If the SPI SCLK domain is truly asynchronous to other clock domains in
# your design (e.g., an Ethernet clock, a USB clock), declare them as
# exclusive or asynchronous clock groups.  This tells the Timing Analyzer
# not to analyze paths between these unrelated domains.
#
# Uncomment and adjust as needed:
# set_clock_groups -asynchronous \
#     -group [get_clocks sys_clk] \
#     -group [get_clocks {eth_rx_clk eth_tx_clk}]


# ==============================================================================
# SECTION 10 — CLOCK UNCERTAINTY
# ==============================================================================
# Clock uncertainty accounts for jitter, PLL jitter, and other clock
# distribution imperfections.  The Timing Analyzer typically derives this
# automatically from PLL specifications, but you may add extra margin.

set_clock_uncertainty -setup 0.100 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.050 [get_clocks sys_clk]

set_clock_uncertainty -setup 0.200 [get_clocks spi_sclk_out]
set_clock_uncertainty -hold  0.100 [get_clocks spi_sclk_out]


# ==============================================================================
# SECTION 11 — I/O STANDARD AND DRIVE STRENGTH (informational)
# ==============================================================================
# These are typically set in the QSF file, not SDC, but they affect timing.
# Ensure your QSF contains appropriate settings, for example:
#
#   set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to spi_sclk
#   set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to spi_mosi
#   set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to spi_miso
#   set_instance_assignment -name IO_STANDARD "3.3-V LVCMOS" -to spi_ss_n
#   set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to spi_sclk
#   set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to spi_mosi


# ==============================================================================
# END OF SPI MASTER TIMING CONSTRAINTS
# ==============================================================================
