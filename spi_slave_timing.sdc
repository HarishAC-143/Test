# ==============================================================================
#  Altera SPI Slave IP Core — Timing Constraints (SDC)
#  Target Board  : Terasic DE10 (Intel Cyclone V — 5CSXFC6D6F31C6N)
#  Tool          : Intel Quartus Prime (TimeQuest / Timing Analyzer)
#  Applicable to : altera_avalon_spi (SPI Slave configuration)
# ==============================================================================
#
#  OVERVIEW
#  --------
#  When the Altera SPI IP core is configured as a *slave*, the FPGA receives
#  SCLK, MOSI, and SS_n from an external master, and drives MISO back.
#
#  The critical difference from master-mode constraints:
#    • SCLK is an *input* clock — it arrives at an FPGA pin and must be
#      defined with create_clock (not create_generated_clock).
#    • MOSI and SS_n are *inputs* synchronous to the incoming SCLK.
#    • MISO is an *output* that the FPGA must drive in time for the external
#      master to sample it.
#
#  Because the external SCLK is asynchronous to the FPGA's system clock, a
#  clock-domain crossing (CDC) exists inside the SPI slave core.  This file
#  addresses both the SPI-domain constraints and the CDC paths.
#
#  SPI MODE REFERENCE
#  ------------------
#    Mode  CPOL  CPHA  Slave Samples On  Slave Shifts On
#    ----  ----  ----  ----------------  ----------------
#      0     0     0   Rising  edge      Falling edge
#      1     0     1   Falling edge      Rising  edge
#      2     1     0   Falling edge      Rising  edge
#      3     1     1   Rising  edge      Falling edge
#
#  The constraints below target Mode 0 (CPOL=0, CPHA=0).  Adjustment notes
#  for other modes are included inline.
#
# ==============================================================================


# ==============================================================================
#  SECTION 1 — USER-TUNABLE PARAMETERS
# ==============================================================================

# System (Avalon-MM) clock — the internal FPGA clock that drives the Avalon
# bus fabric and the non-SPI side of the slave IP core.
set SYS_CLK_FREQ_MHZ        50.0
set SYS_CLK_PERIOD_NS       [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]  ;# 20.0 ns

# SPI clock (SCLK) frequency — dictated by the external SPI master.
# Must match the master's actual SCLK rate for accurate analysis.
set SPI_CLK_FREQ_MHZ         5.0
set SPI_CLK_PERIOD_NS        [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]  ;# 200.0 ns

# Board-level trace delays (one-way, nanoseconds).
set BOARD_DELAY_MAX_NS       1.5
set BOARD_DELAY_MIN_NS       0.5

# External SPI master output timing (from the master's datasheet).
# These describe when the master drives MOSI and SS_n relative to SCLK.
#   Tco_max : maximum clock-to-output of the master (MOSI valid latest)
#   Tco_min : minimum clock-to-output of the master (MOSI valid earliest)
set MASTER_TCO_MAX_NS        8.0
set MASTER_TCO_MIN_NS        0.0

# External SPI master input timing (from the master's datasheet).
# These are the master's setup and hold requirements for sampling MISO.
set MASTER_TSU_NS            5.0
set MASTER_TH_NS             2.0


# ==============================================================================
#  SECTION 2 — SYSTEM (AVALON-MM) BASE CLOCK
# ==============================================================================
#  Same as the master-mode file.  Comment out if already defined elsewhere.

create_clock -name {sys_clk} \
             -period $SYS_CLK_PERIOD_NS \
             [get_ports {CLOCK_50}]


# ==============================================================================
#  SECTION 3 — INCOMING SCLK DEFINITION
# ==============================================================================
#  Unlike master mode, SCLK is an *input* port.  We use create_clock (not
#  create_generated_clock) because it originates outside the FPGA and has no
#  frequency relationship to the system clock that the Timing Analyzer can
#  derive automatically.
#
#  The -waveform argument defines the ideal rising and falling edges.  For
#  Mode 0 (CPOL=0): rising edge at 0, falling edge at half-period.
#  For Mode 2 / Mode 3 (CPOL=1): swap the edges so the idle state is high.

create_clock -name {spi_sclk_in} \
             -period $SPI_CLK_PERIOD_NS \
             -waveform [list 0.0 [expr {$SPI_CLK_PERIOD_NS / 2.0}]] \
             [get_ports {SPI_SCLK}]

# For CPOL=1 modes, change the waveform to:
#   -waveform [list [expr {$SPI_CLK_PERIOD_NS / 2.0}] $SPI_CLK_PERIOD_NS]


# ==============================================================================
#  SECTION 4 — INPUT DELAY CONSTRAINTS (MOSI, SS_n)
# ==============================================================================
#  These constrain the data arriving at the FPGA from the external master.
#
#  The slave samples MOSI on the rising SCLK edge (Mode 0).  The master
#  launched the data on the previous *falling* edge.  We express the input
#  delay relative to spi_sclk_in and use -clock_fall to indicate that the
#  launch event is the falling edge.
#
#  max input delay  =  board_delay_max + master_Tco_max
#  min input delay  =  board_delay_min + master_Tco_min
#
#  The Timing Analyzer uses these values together with the fabric delay to
#  determine whether setup and hold are met at the first slave-side register.

# — MOSI (data from master) —
set_input_delay  -clock {spi_sclk_in} \
                 -max [expr {$BOARD_DELAY_MAX_NS + $MASTER_TCO_MAX_NS}] \
                 -clock_fall \
                 [get_ports {SPI_MOSI}]

set_input_delay  -clock {spi_sclk_in} \
                 -min [expr {$BOARD_DELAY_MIN_NS + $MASTER_TCO_MIN_NS}] \
                 -clock_fall \
                 [get_ports {SPI_MISO}]

# — SS_n (slave select, directly from master) —
# SS_n is asserted before the first SCLK edge and de-asserted after the last.
# Constraining it to SCLK ensures the assertion is stable before the slave
# begins shifting.
set_input_delay  -clock {spi_sclk_in} \
                 -max [expr {$BOARD_DELAY_MAX_NS + $MASTER_TCO_MAX_NS}] \
                 -clock_fall \
                 [get_ports {SPI_SS_n}]

set_input_delay  -clock {spi_sclk_in} \
                 -min [expr {$BOARD_DELAY_MIN_NS + $MASTER_TCO_MIN_NS}] \
                 -clock_fall \
                 [get_ports {SPI_SS_n}]

# NOTE — For Mode 1 or Mode 3 (CPHA=1):
#   The slave samples on the falling edge and the master launches on rising.
#   Remove -clock_fall so the launch reference becomes the rising edge.


# ==============================================================================
#  SECTION 5 — OUTPUT DELAY CONSTRAINTS (MISO)
# ==============================================================================
#  The slave drives MISO, and the external master samples it.  We need to
#  ensure the FPGA delivers data with enough margin for the master's
#  setup/hold.
#
#  For Mode 0, the slave shifts MISO on the *falling* SCLK edge, and the
#  master captures on the *rising* edge.  We use -clock_fall to mark the
#  launch edge and let the tool latch against the next rising edge.
#
#  max output delay  =  board_delay_max + master_Tsu
#  min output delay  =  board_delay_min - master_Th

set_output_delay -clock {spi_sclk_in} \
                 -max [expr {$BOARD_DELAY_MAX_NS + $MASTER_TSU_NS}] \
                 -clock_fall \
                 [get_ports {SPI_MISO}]

set_output_delay -clock {spi_sclk_in} \
                 -min [expr {$BOARD_DELAY_MIN_NS - $MASTER_TH_NS}] \
                 -clock_fall \
                 [get_ports {SPI_MISO}]

# NOTE — For Mode 1 or Mode 3 (CPHA=1):
#   The slave shifts MISO on the rising edge.  Remove -clock_fall so the
#   tool uses the rising SCLK edge as the launch reference.


# ==============================================================================
#  SECTION 6 — CLOCK DOMAIN CROSSING (sys_clk ↔ spi_sclk_in)
# ==============================================================================
#  The incoming SPI clock and the system clock are asynchronous.  Inside the
#  SPI slave core, data passes between these two domains through
#  synchroniser flip-flops.  There are two recommended approaches:
#
#  OPTION A — Declare the clocks as asynchronous (simplest)
#  This tells the Timing Analyzer to skip all inter-domain paths.  It is
#  safe if the IP core uses proper synchronisation (which the Altera core
#  does).

set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk}] \
    -group [get_clocks {spi_sclk_in}]

#  OPTION B — Constrain with set_max_delay (stricter, optional)
#  Instead of ignoring the CDC paths, you can bound them.  This verifies
#  that synchroniser input data arrives within one destination-clock period,
#  ensuring the synchroniser only ever misses by at most one cycle.
#
#  Uncomment the lines below if you prefer Option B (and comment out
#  Option A above):
#
#  set_max_delay -from [get_clocks {spi_sclk_in}] \
#                -to   [get_clocks {sys_clk}] \
#                $SYS_CLK_PERIOD_NS
#
#  set_max_delay -from [get_clocks {sys_clk}] \
#                -to   [get_clocks {spi_sclk_in}] \
#                $SPI_CLK_PERIOD_NS


# ==============================================================================
#  SECTION 7 — FALSE PATHS
# ==============================================================================

# 7a. Asynchronous reset — assertion path is not synchronous
set_false_path -from [get_ports {RESET_n}]

# 7b. Static configuration registers (written once at initialisation)
# set_false_path -from [get_registers {*spi_slave*control_reg*}]


# ==============================================================================
#  SECTION 8 — CLOCK UNCERTAINTY / JITTER
# ==============================================================================
#  For the external SCLK, jitter depends on the master's oscillator quality.
#  Add a conservative uncertainty to account for it.

set_clock_uncertainty -setup 0.200 [get_clocks {sys_clk}]
set_clock_uncertainty -hold  0.100 [get_clocks {sys_clk}]

set_clock_uncertainty -setup 0.300 [get_clocks {spi_sclk_in}]
set_clock_uncertainty -hold  0.150 [get_clocks {spi_sclk_in}]

# The incoming SCLK gets slightly higher uncertainty than the on-chip system
# clock because it includes the external master's oscillator jitter plus any
# board-level coupling noise.


# ==============================================================================
#  SECTION 9 — INPUT / OUTPUT DELAY EXCEPTIONS FOR SS_n ACTIVE-HIGH PERIOD
# ==============================================================================
#  When SS_n is de-asserted (high), no SPI transfer is in progress.  The
#  slave ignores MOSI and tri-states MISO.  If the Timing Analyzer reports
#  violations on MOSI during these idle periods, you can add false-path
#  exceptions gated on the SS_n state.  This is typically unnecessary but
#  documented here for completeness.
#
#  set_false_path -from [get_ports {SPI_MOSI}] \
#                 -to   [get_registers {*spi_slave*shift*}] \
#                 -when {SPI_SS_n == 1}
#  (Note: SDC does not support -when directly; use case analysis or
#   set_case_analysis on SS_n if needed for static scenarios.)


# ==============================================================================
#  SECTION 10 — I/O STANDARD AND DRIVE STRENGTH REMINDERS
# ==============================================================================
#  Set in .qsf or Pin Planner — these affect I/O buffer delays:
#
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_SCLK
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_MOSI
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_MISO
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_SS_n
#
#    set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to SPI_MISO
#
#  For inputs (SCLK, MOSI, SS_n) you may also want:
#    set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SPI_SS_n
#  to keep SS_n high (inactive) when no master is connected.


# ==============================================================================
#  END OF SPI SLAVE TIMING CONSTRAINTS
# ==============================================================================
