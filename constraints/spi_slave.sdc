# ==============================================================================
# Altera/Intel FPGA — SPI Slave IP Core Timing Constraints
# ==============================================================================
#
# Target  : Quartus Prime Timing Analyzer (TimeQuest)
# Format  : Synopsys Design Constraints (SDC)
# Scope   : SPI Slave interface (external master drives SCLK, MOSI, SS_n;
#            FPGA drives MISO)
#
# In slave mode the FPGA does NOT generate SCLK — it receives SCLK from the
# external master.  This fundamentally changes how clocks are modelled:
#   - SCLK is an input clock (create_clock on the SCLK input port).
#   - MOSI and SS_n are inputs synchronous to the incoming SCLK.
#   - MISO is an output synchronous to the incoming SCLK.
#   - A clock domain crossing exists between SCLK and the internal sys_clk.
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

# ---- Clock Frequencies ----
set sys_clk_freq_mhz     50.0      ;# Internal system/bus clock frequency (MHz)
set spi_clk_freq_mhz     25.0      ;# Maximum expected SPI SCLK frequency (MHz)

# ---- SPI Mode (CPOL / CPHA) ----
#   Mode 0: CPOL=0, CPHA=0  —  idle low,  sample on rising,  shift on falling
#   Mode 1: CPOL=0, CPHA=1  —  idle low,  sample on falling, shift on rising
#   Mode 2: CPOL=1, CPHA=0  —  idle high, sample on falling, shift on rising
#   Mode 3: CPOL=1, CPHA=1  —  idle high, sample on rising,  shift on falling
set spi_cpol              0
set spi_cpha              0

# ---- Board / Trace Delays (ns) ----
# One-way PCB trace delay between external SPI master and the FPGA.
set board_delay_max       1.5      ;# Maximum trace delay (ns)
set board_delay_min       0.5      ;# Minimum trace delay (ns)

# ---- External SPI Master Device Timing (ns) ----
# The master shifts MOSI relative to SCLK.  These values describe how
# early/late MOSI may arrive at the FPGA relative to the SCLK edge
# that the FPGA uses to sample it.
set master_tco_max       10.0      ;# Master SCLK-to-MOSI output delay max (ns)
set master_tco_min        2.0      ;# Master SCLK-to-MOSI output delay min (ns)
set master_tsu            5.0      ;# Master MISO setup time requirement (ns)
set master_th             2.0      ;# Master MISO hold  time requirement (ns)

# ---- FPGA Pin Names ----
set spi_sclk_pin          "spi_sclk"
set spi_mosi_pin          "spi_mosi"
set spi_miso_pin          "spi_miso"
set spi_ss_n_pin          "spi_ss_n"
set sys_clk_pin           "sys_clk"


# ==============================================================================
# SECTION 1 — DERIVED VALUES (do not edit)
# ==============================================================================

set sys_clk_period_ns     [expr {1000.0 / $sys_clk_freq_mhz}]
set spi_clk_period_ns     [expr {1000.0 / $spi_clk_freq_mhz}]
set spi_clk_half_period   [expr {$spi_clk_period_ns / 2.0}]


# ==============================================================================
# SECTION 2 — SYSTEM CLOCK DEFINITION
# ==============================================================================
# The internal system clock that drives the SPI slave IP core's register
# interface (e.g., Avalon-MM or AXI bus interface).

create_clock -name sys_clk \
             -period $sys_clk_period_ns \
             [get_ports $sys_clk_pin]


# ==============================================================================
# SECTION 3 — SPI SCLK AS AN INPUT CLOCK
# ==============================================================================
# In slave mode, SCLK is received from the external master.  We create a
# real clock on the SCLK input port.  The period must match (or be at least
# as fast as) the fastest SCLK the master will produce.
#
# Unlike master mode, we do NOT use create_generated_clock because SCLK is
# not derived from any FPGA-internal clock — it originates externally.

create_clock -name spi_sclk_in \
             -period $spi_clk_period_ns \
             [get_ports $spi_sclk_pin]


# ==============================================================================
# SECTION 4 — VIRTUAL CLOCK FOR EXTERNAL SPI MASTER
# ==============================================================================
# A virtual clock represents SCLK at the external master's pin (before board
# propagation delay).  We reference input/output delays against this clock
# to account for the PCB trace delay between master and slave.

create_clock -name virtual_spi_sclk \
             -period $spi_clk_period_ns


# ==============================================================================
# SECTION 5 — INPUT DELAY CONSTRAINTS (MOSI, SS_n)
# ==============================================================================
# MOSI and SS_n are driven by the external master.  The master shifts data
# on one SCLK edge; the FPGA slave samples data on the opposite edge.
#
# The input delay is the total time from the SCLK launch edge (at the master)
# to when the data arrives at the FPGA input pin:
#
#   input_delay = master_tco + board_delay
#
# For SPI Mode 0 (CPOL=0, CPHA=0):
#   - Master shifts MOSI on the falling edge of SCLK.
#   - Slave (FPGA) samples MOSI on the rising edge of SCLK.
#   - Data has a full half-period to travel from master to slave.
#
# For SPI Mode 1 (CPOL=0, CPHA=1):
#   - Master shifts MOSI on the rising edge.
#   - Slave samples on the falling edge.
#
# We constrain with -max (for setup analysis) and -min (for hold analysis).

set mosi_input_delay_max [expr {$board_delay_max + $master_tco_max}]
set mosi_input_delay_min [expr {$board_delay_min + $master_tco_min}]

# Determine which edge MOSI is launched on (opposite of sampling edge)
# CPHA=0: sample on leading edge  → launch on trailing edge → use -clock_fall
# CPHA=1: sample on trailing edge → launch on leading edge  → no -clock_fall
if {($spi_cpol == 0 && $spi_cpha == 0) || ($spi_cpol == 1 && $spi_cpha == 1)} {
    # Modes 0 and 3: FPGA samples on rising edge (of spi_sclk_in)
    # Master launches on falling edge

    set_input_delay -clock spi_sclk_in \
                    -max $mosi_input_delay_max \
                    -clock_fall \
                    [get_ports $spi_mosi_pin]

    set_input_delay -clock spi_sclk_in \
                    -min $mosi_input_delay_min \
                    -clock_fall \
                    [get_ports $spi_mosi_pin]

    set_input_delay -clock spi_sclk_in \
                    -max $mosi_input_delay_max \
                    -clock_fall \
                    [get_ports $spi_ss_n_pin]

    set_input_delay -clock spi_sclk_in \
                    -min $mosi_input_delay_min \
                    -clock_fall \
                    [get_ports $spi_ss_n_pin]
} else {
    # Modes 1 and 2: FPGA samples on falling edge (of spi_sclk_in)
    # Master launches on rising edge

    set_input_delay -clock spi_sclk_in \
                    -max $mosi_input_delay_max \
                    [get_ports $spi_mosi_pin]

    set_input_delay -clock spi_sclk_in \
                    -min $mosi_input_delay_min \
                    [get_ports $spi_mosi_pin]

    set_input_delay -clock spi_sclk_in \
                    -max $mosi_input_delay_max \
                    [get_ports $spi_ss_n_pin]

    set_input_delay -clock spi_sclk_in \
                    -min $mosi_input_delay_min \
                    [get_ports $spi_ss_n_pin]
}


# ==============================================================================
# SECTION 6 — OUTPUT DELAY CONSTRAINTS (MISO)
# ==============================================================================
# MISO is driven by the FPGA slave.  The external master samples MISO on a
# specific SCLK edge.  We must ensure the FPGA presents valid data with
# enough setup and hold margin at the master's input.
#
# Because SCLK originates at the master, the timing picture is:
#
#   Master drives SCLK ──→ [board_delay] ──→ SCLK at FPGA (spi_sclk_in)
#                                              ↓
#                                         FPGA shifts MISO
#                                              ↓
#   MISO at FPGA pin ──→ [board_delay] ──→ MISO at master
#
# The master sees MISO arrive with a total delay of:
#   SCLK board_delay (master→FPGA) + FPGA_tco + MISO board_delay (FPGA→master)
#
# Since the Timing Analyzer already accounts for FPGA internal delays
# (register-to-output), we only need to specify the external portion:
#
#   output_delay_max = board_delay_max + master_tsu
#   output_delay_min = -(board_delay_max - board_delay_min)
#
# The -min value accounts for the hold requirement at the master.  A negative
# value means the data can arrive slightly before the clock edge and still
# satisfy hold.

set miso_output_delay_max [expr {$board_delay_max + $master_tsu}]
set miso_output_delay_min [expr {-($board_delay_max - $board_delay_min)}]

# Determine which edge master samples MISO on:
# CPHA=0: master samples on leading  → shift on trailing
# CPHA=1: master samples on trailing → shift on leading
if {($spi_cpol == 0 && $spi_cpha == 0) || ($spi_cpol == 1 && $spi_cpha == 1)} {
    # Modes 0 and 3: Master samples MISO on rising edge
    # FPGA shifts MISO on falling edge — constrain against rising edge at master

    set_output_delay -clock spi_sclk_in \
                     -max $miso_output_delay_max \
                     [get_ports $spi_miso_pin]

    set_output_delay -clock spi_sclk_in \
                     -min $miso_output_delay_min \
                     [get_ports $spi_miso_pin]
} else {
    # Modes 1 and 2: Master samples MISO on falling edge
    # FPGA shifts MISO on rising edge — constrain against falling edge at master

    set_output_delay -clock spi_sclk_in \
                     -max $miso_output_delay_max \
                     -clock_fall \
                     [get_ports $spi_miso_pin]

    set_output_delay -clock spi_sclk_in \
                     -min $miso_output_delay_min \
                     -clock_fall \
                     [get_ports $spi_miso_pin]
}


# ==============================================================================
# SECTION 7 — CLOCK DOMAIN CROSSING: SCLK ↔ SYS_CLK
# ==============================================================================
# The SPI slave IP core operates in two clock domains:
#   1. spi_sclk_in — Shift register, bit counter, edge detection
#   2. sys_clk     — Register interface (Avalon-MM / AXI), FIFOs, interrupts
#
# Data transfers between these domains pass through synchronizer flip-flops
# (typically 2-3 stages).  We have two options:
#
# OPTION A: set_false_path (simpler, suitable when synchronizers are present)
#   Completely exclude cross-domain paths from timing analysis.
#
# OPTION B: set_max_delay (stricter, limits synchronizer latency)
#   Constrain the combinational delay to a bounded value without requiring
#   a full setup/hold relationship.
#
# Choose ONE option below.  Option A is recommended for most designs.

# --- OPTION A: False Path (recommended) ---
set_false_path -from [get_clocks spi_sclk_in] -to [get_clocks sys_clk]
set_false_path -from [get_clocks sys_clk]     -to [get_clocks spi_sclk_in]

# --- OPTION B: Max Delay (uncomment to use instead of Option A) ---
# set_max_delay -from [get_clocks spi_sclk_in] -to [get_clocks sys_clk] \
#               $sys_clk_period_ns
# set_min_delay -from [get_clocks spi_sclk_in] -to [get_clocks sys_clk] \
#               0
# set_max_delay -from [get_clocks sys_clk]     -to [get_clocks spi_sclk_in] \
#               $sys_clk_period_ns
# set_min_delay -from [get_clocks sys_clk]     -to [get_clocks spi_sclk_in] \
#               0


# ==============================================================================
# SECTION 8 — FALSE PATH FOR ASYNCHRONOUS SIGNALS
# ==============================================================================

# 8a. SS_n as an asynchronous reset/enable
# In many SPI slave designs, SS_n acts as an asynchronous enable that gates
# the shift register.  If SS_n does not have a synchronous timing relationship
# to SCLK data transfers, declare it as a false path to any SCLK-domain
# registers.
# Uncomment if applicable:
# set_false_path -from [get_ports $spi_ss_n_pin] \
#                -to [get_clocks spi_sclk_in]

# 8b. Asynchronous reset
# Uncomment and adjust pin name:
# set_false_path -from [get_ports reset_n]


# ==============================================================================
# SECTION 9 — CLOCK GROUPS
# ==============================================================================
# If the SPI SCLK domain is completely asynchronous to other clock domains
# in the design (besides sys_clk, which is already handled above), declare
# them as asynchronous groups.
#
# NOTE: Do not put spi_sclk_in and sys_clk in asynchronous groups if you
# are using set_max_delay (Option B above) instead of set_false_path.

# set_clock_groups -asynchronous \
#     -group [get_clocks spi_sclk_in] \
#     -group [get_clocks {other_clk_1 other_clk_2}]


# ==============================================================================
# SECTION 10 — CLOCK UNCERTAINTY
# ==============================================================================
# For the incoming SCLK, uncertainty is typically higher than for PLL-derived
# clocks because external clocks have unknown jitter characteristics.

set_clock_uncertainty -setup 0.100 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.050 [get_clocks sys_clk]

set_clock_uncertainty -setup 0.300 [get_clocks spi_sclk_in]
set_clock_uncertainty -hold  0.150 [get_clocks spi_sclk_in]


# ==============================================================================
# SECTION 11 — INPUT DELAY ON SCLK PIN (optional, advanced)
# ==============================================================================
# The SCLK input itself has board propagation delay.  This is implicitly
# accounted for by the Timing Analyzer when you place create_clock on the
# SCLK port (the clock arrives at the input buffer, and the tool accounts
# for the buffer + routing delay to the first register).
#
# If you want to explicitly model the board delay on SCLK for more accurate
# analysis, you can use set_clock_latency:
#
# set_clock_latency -source -late  $board_delay_max [get_clocks spi_sclk_in]
# set_clock_latency -source -early $board_delay_min [get_clocks spi_sclk_in]


# ==============================================================================
# END OF SPI SLAVE TIMING CONSTRAINTS
# ==============================================================================
