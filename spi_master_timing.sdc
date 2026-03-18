# ==============================================================================
#  Altera SPI Master IP Core — Timing Constraints (SDC)
#  Target Board  : Terasic DE10 (Intel Cyclone V — 5CSXFC6D6F31C6N)
#  Tool          : Intel Quartus Prime (TimeQuest / Timing Analyzer)
#  Applicable to : altera_avalon_spi (SPI Master configuration)
# ==============================================================================
#
#  OVERVIEW
#  --------
#  When the Altera SPI IP core is configured as a *master*, the FPGA drives
#  SCLK, MOSI, and SS_n, while sampling the incoming MISO signal.  Correct
#  timing closure requires:
#
#    1. A base clock definition for the system (Avalon) clock.
#    2. A generated clock on the SCLK output pin so the Timing Analyzer knows
#       the frequency relationship between the system clock and the SPI clock.
#    3. set_output_delay on MOSI and SS_n so that the tool verifies data is
#       stable when the external slave samples it on the appropriate SCLK edge.
#    4. set_input_delay on MISO so that the tool verifies the FPGA can capture
#       data returned by the external slave.
#    5. Multicycle, false-path, and max/min-delay exceptions where appropriate.
#
#  SPI MODE REFERENCE
#  ------------------
#    Mode  CPOL  CPHA  Data Sampled On   Data Shifted On
#    ----  ----  ----  ----------------  ----------------
#      0     0     0   Rising  edge      Falling edge
#      1     0     1   Falling edge      Rising  edge
#      2     1     0   Falling edge      Rising  edge
#      3     1     1   Rising  edge      Falling edge
#
#  The constraints below are written for Mode 0 (CPOL=0, CPHA=0), which is
#  the most common configuration.  Comments indicate what to change for other
#  modes.
#
# ==============================================================================


# ==============================================================================
#  SECTION 1 — USER-TUNABLE PARAMETERS
# ==============================================================================
#  Centralising numeric values makes it easy to adapt this file to different
#  board revisions or SPI clock rates without hunting through every constraint.

# System (Avalon-MM) clock frequency — must match the PLL / oscillator on
# your board.  The DE10 provides a 50 MHz oscillator on PIN_AF14.
set SYS_CLK_FREQ_MHZ       50.0
set SYS_CLK_PERIOD_NS       [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]  ;# 20.0 ns

# SPI clock (SCLK) frequency — set by the clock divider in the IP
# parameterisation GUI.  The IP divides the system clock by an even integer
# (the "clockPhase" register value × 2).  Example: 50 MHz / 10 = 5 MHz.
set SPI_CLK_FREQ_MHZ         5.0
set SPI_CLK_PERIOD_NS        [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]  ;# 200.0 ns
set SPI_CLK_DIV              [expr {int($SYS_CLK_FREQ_MHZ / $SPI_CLK_FREQ_MHZ)}]

# Board-level trace delays (one-way, in nanoseconds).
# Measure or estimate from PCB stack-up; 150 ps/inch is typical for FR-4.
set BOARD_DELAY_MAX_NS       1.5   ;# worst-case (slow corner, long trace)
set BOARD_DELAY_MIN_NS       0.5   ;# best-case  (fast corner, short trace)

# External SPI slave device timing (from its datasheet).
# These are *slave* setup/hold times that constrain how early/late the master
# may toggle MOSI relative to SCLK.
set SLAVE_TSU_NS             5.0   ;# slave input setup time
set SLAVE_TH_NS              2.0   ;# slave input hold  time

# External SPI slave output timing — the min/max time after SCLK that valid
# data appears on MISO (clock-to-output of the slave device).
set SLAVE_TCO_MAX_NS         8.0   ;# max clock-to-output
set SLAVE_TCO_MIN_NS         0.0   ;# min clock-to-output


# ==============================================================================
#  SECTION 2 — SYSTEM (AVALON-MM) BASE CLOCK
# ==============================================================================
#  The base clock drives the entire Qsys / Platform Designer interconnect and
#  clocks all registers inside the SPI IP.  It is the timing reference for
#  every path that starts or ends at an Avalon-side register.
#
#  If the clock comes from a PLL, Quartus usually creates the clock
#  automatically from the PLL megafunction.  The line below is included as a
#  reference; comment it out if your PLL already defines this clock.

create_clock -name {sys_clk} \
             -period $SYS_CLK_PERIOD_NS \
             [get_ports {CLOCK_50}]
# The -period is in nanoseconds.  50 MHz → 20 ns.
# Replace CLOCK_50 with the actual top-level port name on your design.


# ==============================================================================
#  SECTION 3 — GENERATED CLOCK ON SCLK OUTPUT
# ==============================================================================
#  The SPI IP synthesises SCLK by toggling a register on every Nth system
#  clock edge (where N = SYS_CLK_FREQ / SPI_CLK_FREQ / 2).  The resulting
#  output is a *generated* (divided) clock.
#
#  Why this matters:
#    • Without this constraint the Timing Analyzer treats SCLK_OUT as ordinary
#      data and cannot compute meaningful output-delay or input-delay checks
#      against it.
#    • The -source is the register clock pin (sys_clk), and -divide_by tells
#      the tool the exact frequency relationship.
#
#  IMPORTANT — the "get_ports" name must match your top-level SCLK output pin.
#  In the Altera SPI IP the signal is typically named spi_SCLK or
#  spi_master_0_external_SCLK.  Adjust to match your system.

create_generated_clock -name {spi_sclk} \
                       -source [get_ports {CLOCK_50}] \
                       -divide_by $SPI_CLK_DIV \
                       [get_ports {SPI_SCLK}]


# ==============================================================================
#  SECTION 4 — OUTPUT DELAY CONSTRAINTS (MOSI, SS_n)
# ==============================================================================
#  set_output_delay tells the Timing Analyzer how much of the SCLK period is
#  consumed *outside* the FPGA — board trace delay plus the slave's setup/hold
#  requirement.  The tool then checks that the FPGA drives data early enough
#  (setup) and holds it long enough (hold) for the slave to capture it.
#
#  Formula (launch-edge relative):
#    max output delay  =  board_delay_max + slave_Tsu
#    min output delay  =  board_delay_min - slave_Th   (can be negative)
#
#  For SPI Mode 0, the slave samples MOSI on the *rising* SCLK edge, so
#  the master must shift data out on the *falling* edge.  We therefore
#  reference these constraints to the generated spi_sclk clock and let the
#  Timing Analyzer use the correct launch/latch relationship.
#
#  For Mode 1 / Mode 2 / Mode 3, swap -clock_fall as needed (see notes).

# — MOSI —
set_output_delay -clock {spi_sclk} \
                 -max [expr {$BOARD_DELAY_MAX_NS + $SLAVE_TSU_NS}] \
                 [get_ports {SPI_MOSI}]

set_output_delay -clock {spi_sclk} \
                 -min [expr {$BOARD_DELAY_MIN_NS - $SLAVE_TH_NS}] \
                 [get_ports {SPI_MOSI}]

# — SS_n (active-low slave select) —
# Slave-select is asserted well before SCLK activity begins, but we still
# constrain it so the Timing Analyzer verifies it meets the slave's setup
# requirement relative to the first SCLK edge.
set_output_delay -clock {spi_sclk} \
                 -max [expr {$BOARD_DELAY_MAX_NS + $SLAVE_TSU_NS}] \
                 [get_ports {SPI_SS_n}]

set_output_delay -clock {spi_sclk} \
                 -min [expr {$BOARD_DELAY_MIN_NS - $SLAVE_TH_NS}] \
                 [get_ports {SPI_SS_n}]

# NOTE — Mode 1 or Mode 2 (CPHA=1 or CPOL=1):
#   The slave samples on the opposite edge.  Add  -clock_fall  to the
#   set_output_delay calls above so the tool references the falling SCLK
#   edge instead of the rising edge.


# ==============================================================================
#  SECTION 5 — INPUT DELAY CONSTRAINTS (MISO)
# ==============================================================================
#  set_input_delay tells the Timing Analyzer when valid data arrives at the
#  FPGA's MISO pin, measured from the SCLK edge that caused the slave to
#  drive it.
#
#  Formula:
#    max input delay  =  board_delay_max + slave_Tco_max
#    min input delay  =  board_delay_min + slave_Tco_min
#
#  For SPI Mode 0, the slave shifts data on the *falling* SCLK edge, and
#  the master samples on the *rising* edge.  We use -clock_fall to tell the
#  tool that the launch edge (slave side) is the falling edge of spi_sclk.

set_input_delay  -clock {spi_sclk} \
                 -max [expr {$BOARD_DELAY_MAX_NS + $SLAVE_TCO_MAX_NS}] \
                 -clock_fall \
                 [get_ports {SPI_MISO}]

set_input_delay  -clock {spi_sclk} \
                 -min [expr {$BOARD_DELAY_MIN_NS + $SLAVE_TCO_MIN_NS}] \
                 -clock_fall \
                 [get_ports {SPI_MISO}]

# NOTE — Mode 1 or Mode 3 (CPHA=1):
#   The master samples on the falling edge and the slave shifts on rising.
#   Remove  -clock_fall  so the launch edge becomes the rising SCLK edge.


# ==============================================================================
#  SECTION 6 — MULTICYCLE PATH EXCEPTIONS
# ==============================================================================
#  The SPI IP core contains synchronisation registers between the Avalon
#  clock domain and the (slower) SPI clock domain.  Data transferred across
#  this boundary has multiple system clock periods to propagate.
#
#  Without multicycle declarations the Timing Analyzer would try to close
#  timing in a single system clock period, resulting in spurious violations.
#
#  The multiplier equals the clock division ratio: if SCLK = sys_clk / 10,
#  then data launched by sys_clk has 10 system periods before it must be
#  captured on the SPI side.

set_multicycle_path -setup -from [get_clocks {sys_clk}] \
                           -to   [get_clocks {spi_sclk}] \
                           $SPI_CLK_DIV

set_multicycle_path -hold  -from [get_clocks {sys_clk}] \
                           -to   [get_clocks {spi_sclk}] \
                           [expr {$SPI_CLK_DIV - 1}]

# The "-hold" value is one less than "-setup" (standard SDC practice).  This
# tells the tool to use the correct reference edges when checking hold.


# ==============================================================================
#  SECTION 7 — FALSE-PATH DECLARATIONS
# ==============================================================================
#  Some paths in the design are never sensitised simultaneously and should be
#  excluded from timing analysis so they don't cause false failures or distort
#  fmax reporting.

# 7a. Asynchronous reset
# The SPI IP's reset is an asynchronous assertion / synchronous de-assertion
# path.  The assertion leg does not need setup/hold analysis.
set_false_path -from [get_ports {RESET_n}]

# 7b. Static configuration registers
# The Avalon-side configuration registers (control, slave-select, baud-rate
# divider) are written once during initialisation and remain constant while
# SPI transfers are active.  Paths from these registers to the SPI clock
# domain are effectively static.
# Uncomment and adjust the -from specification to match your register paths:
# set_false_path -from [get_registers {*spi_master*control_reg*}] \
#                -to   [get_registers {*spi_master*shift*}]

# 7c. Clock-domain crossing (CDC) — if using FIFO-based bridging
# If you instantiate a dual-clock FIFO between the Avalon domain and the SPI
# domain, the gray-code pointer paths are inherently safe (single-bit
# transitions) and should be marked as false paths.
# set_false_path -from [get_registers {*dcfifo*wrptr_g*}] \
#                -to   [get_registers {*dcfifo*rdptr_g*}]


# ==============================================================================
#  SECTION 8 — CLOCK UNCERTAINTY / JITTER
# ==============================================================================
#  Clock uncertainty accounts for PLL jitter, board-level noise, and
#  intra-die variation.  Adding uncertainty tightens the timing window and
#  provides safety margin.
#
#  Typical values for Cyclone V on-chip PLLs:
#    Setup uncertainty : 100–200 ps
#    Hold  uncertainty :  50–100 ps
#
#  If the system clock is sourced directly from a crystal oscillator (no PLL),
#  use smaller values or omit this section entirely.

set_clock_uncertainty -setup 0.200 [get_clocks {sys_clk}]
set_clock_uncertainty -hold  0.100 [get_clocks {sys_clk}]

set_clock_uncertainty -setup 0.200 [get_clocks {spi_sclk}]
set_clock_uncertainty -hold  0.100 [get_clocks {spi_sclk}]


# ==============================================================================
#  SECTION 9 — MAXIMUM / MINIMUM DELAY OVERRIDES (OPTIONAL)
# ==============================================================================
#  In some designs you may want absolute min/max delay constraints on the SPI
#  signals rather than (or in addition to) the input/output delay method.
#  These are useful for signals that have hard real-time deadlines or for
#  constraining inter-chip interfaces on a multi-FPGA board.
#
#  Uncomment and adjust if needed:
#
# set_max_delay -from [get_ports {SPI_MISO}] \
#               -to   [get_registers {*spi*rxdata*}] \
#               [expr {$SPI_CLK_PERIOD_NS / 2.0}]
#
# set_min_delay -from [get_ports {SPI_MISO}] \
#               -to   [get_registers {*spi*rxdata*}] \
#               0.0


# ==============================================================================
#  SECTION 10 — CLOCK GROUPS (IF MULTIPLE UNRELATED CLOCKS EXIST)
# ==============================================================================
#  If your design has clocks that are completely unrelated (e.g., an
#  independent UART clock, a video pixel clock), declare them in separate
#  clock groups so the Timing Analyzer does not attempt cross-domain analysis
#  between them and the SPI clocks.
#
#  set_clock_groups -asynchronous \
#      -group [get_clocks {sys_clk spi_sclk}] \
#      -group [get_clocks {video_pix_clk}]


# ==============================================================================
#  SECTION 11 — I/O STANDARD AND DRIVE STRENGTH REMINDERS
# ==============================================================================
#  These are not SDC timing constraints, but they directly affect timing.
#  Set them in your .qsf file or Pin Planner:
#
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_SCLK
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_MOSI
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_MISO
#    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SPI_SS_n
#
#    set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to SPI_SCLK
#    set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to SPI_MOSI
#    set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to SPI_SS_n
#
#  Higher drive strength reduces output delay (faster edges) but increases
#  overshoot risk.  Match the I/O standard to the voltage level of the
#  external slave device.


# ==============================================================================
#  END OF SPI MASTER TIMING CONSTRAINTS
# ==============================================================================
