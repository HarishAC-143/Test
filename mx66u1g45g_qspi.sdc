# ==============================================================================
# SDC Timing Constraints for Macronix MX66U1G45G QSPI Flash
# Target: Intel (Altera) FPGA
# ==============================================================================
#
# Device:   Macronix MX66U1G45G  (1.8V, 1Gb Serial NOR Flash)
# Modes:    SPI / Dual-IO / Quad-IO (STR), Quad-IO DTR
# Max Freq: 133 MHz (STR), 166 MHz (DTR)
#
# Datasheet timing parameters used (from MX66U1G45G rev 1.2):
#
#   STR (Single Transfer Rate) Mode:
#     tCLQV  = 6.0 ns max   (clock-to-output valid, SCK falling to SO valid)
#     tCLQX  = 0.5 ns min   (clock-to-output hold,  SCK falling to SO invalid)
#     tDVCH  = 2.0 ns min   (data-in setup time,    SI valid to SCK rising)
#     tCHDX  = 2.0 ns min   (data-in hold time,     SCK rising to SI invalid)
#     tSLCH  = 5.0 ns min   (CS# low  to SCK rising edge)
#     tCHSL  = 5.0 ns min   (SCK rising edge to CS# high)
#     tSHSL  = 10  ns min   (CS# high time between operations)
#
#   DTR (Double Transfer Rate) Mode:
#     tCLQV  = 5.5 ns max   (clock-to-output valid)
#     tCLQX  = 0.5 ns min   (clock-to-output hold)
#     tDVCH  = 1.5 ns min   (data-in setup time, both edges)
#     tCHDX  = 1.5 ns min   (data-in hold time, both edges)
#
# Adapt the port names, clock name, and board delays to your design.
# ==============================================================================


# ==============================================================================
# Section 1: User-Configurable Parameters
# ==============================================================================
# Modify these variables to match your design.

# --- FPGA reference clock driving the QSPI controller ---
set SYS_CLK_NAME      "sys_clk"
set SYS_CLK_FREQ_MHZ  100.0
set SYS_CLK_PERIOD_NS [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]

# --- QSPI operating clock frequency (must not exceed flash max) ---
set QSPI_CLK_FREQ_MHZ 50.0
set QSPI_CLK_PERIOD   [expr {1000.0 / $QSPI_CLK_FREQ_MHZ}]

# --- QSPI operating mode: "STR" or "DTR" ---
set QSPI_MODE "STR"

# --- FPGA port names (adjust to match your top-level port names) ---
set QSPI_CLK_PORT     "qspi_sclk"
set QSPI_CS_PORT      "qspi_cs_n"
set QSPI_DATA_PORTS   "qspi_io[*]"

# --- Board-level trace delays (PCB routing, ns) ---
# Measure or estimate from your PCB layout. Symmetry between CLK and DATA
# traces is assumed here; adjust if your board has significant skew.
set BOARD_DELAY_MAX    1.0
set BOARD_DELAY_MIN    0.2


# ==============================================================================
# Section 2: Flash Timing Parameters (from MX66U1G45G datasheet)
# ==============================================================================

if {$QSPI_MODE eq "DTR"} {
    # DTR mode timing
    set TCLQV       5.5
    set TCLQX       0.5
    set TDVCH       1.5
    set TCHDX       1.5
} else {
    # STR mode timing (default)
    set TCLQV       6.0
    set TCLQX       0.5
    set TDVCH       2.0
    set TCHDX       2.0
}

set TSLCH           5.0
set TCHSL           5.0
set TSHSL           10.0


# ==============================================================================
# Section 3: System Clock Constraint
# ==============================================================================
# Define or reference the system clock that feeds the QSPI controller.
# If the clock is already constrained elsewhere in your project, comment
# this out and adjust SYS_CLK_NAME above to match.

create_clock -name $SYS_CLK_NAME -period $SYS_CLK_PERIOD_NS [get_ports $SYS_CLK_NAME]


# ==============================================================================
# Section 4: QSPI Output Clock (Generated Clock)
# ==============================================================================
# The FPGA drives SCLK to the flash. Model it as a generated clock derived
# from the system clock through the QSPI controller logic.
#
# The -source should point to the register or PLL output that ultimately
# drives the SCLK pin. Adjust the -divide_by ratio to match your design's
# clock divider. For a 100 MHz sys_clk producing a 50 MHz SCLK, divide by 2.

set CLK_DIV_RATIO [expr {int($SYS_CLK_FREQ_MHZ / $QSPI_CLK_FREQ_MHZ)}]

create_generated_clock \
    -name qspi_sclk_out \
    -source [get_pins -compatibility_mode {*|clk}] \
    -divide_by $CLK_DIV_RATIO \
    [get_ports $QSPI_CLK_PORT]


# ==============================================================================
# Section 5: Virtual Clock for Flash Return Data
# ==============================================================================
# A virtual clock represents the "clock" as seen at the flash device output.
# This accounts for the round-trip delay: FPGA→board→flash→board→FPGA.

create_clock -name qspi_flash_vclk -period $QSPI_CLK_PERIOD


# ==============================================================================
# Section 6: Output Constraints (FPGA → Flash: CS#, Data Out)
# ==============================================================================
# The flash latches data on the rising edge of SCLK (STR) or both edges (DTR).
# set_output_delay constrains how early/late FPGA outputs can change relative
# to the launch clock edge.
#
# Formula (system-synchronous output):
#   set_output_delay -max = board_delay_max + tDVCH  (setup requirement)
#   set_output_delay -min = board_delay_min - tCHDX  (hold requirement)
#
# The -max value ensures the data arrives at the flash with enough setup time.
# The -min value (negative is typical) ensures data is held long enough.

set OUT_DELAY_MAX [expr {$BOARD_DELAY_MAX + $TDVCH}]
set OUT_DELAY_MIN [expr {$BOARD_DELAY_MIN - $TCHDX}]

# --- Data outputs (MOSI / IO[3:0]) ---
set_output_delay -clock qspi_sclk_out -max $OUT_DELAY_MAX \
    [get_ports $QSPI_DATA_PORTS]
set_output_delay -clock qspi_sclk_out -min $OUT_DELAY_MIN \
    [get_ports $QSPI_DATA_PORTS]

# --- Chip Select (active-low) ---
# CS# must be asserted tSLCH before the first SCK rising edge and held
# tCHSL after the last SCK rising edge. We constrain it similarly to data.
set CS_OUT_DELAY_MAX [expr {$BOARD_DELAY_MAX + $TSLCH}]
set CS_OUT_DELAY_MIN [expr {$BOARD_DELAY_MIN - $TCHSL}]

set_output_delay -clock qspi_sclk_out -max $CS_OUT_DELAY_MAX \
    [get_ports $QSPI_CS_PORT]
set_output_delay -clock qspi_sclk_out -min $CS_OUT_DELAY_MIN \
    [get_ports $QSPI_CS_PORT]

if {$QSPI_MODE eq "DTR"} {
    # In DTR mode, the flash latches data on both clock edges.
    set_output_delay -clock qspi_sclk_out -max $OUT_DELAY_MAX \
        -clock_fall -add_delay \
        [get_ports $QSPI_DATA_PORTS]
    set_output_delay -clock qspi_sclk_out -min $OUT_DELAY_MIN \
        -clock_fall -add_delay \
        [get_ports $QSPI_DATA_PORTS]
}


# ==============================================================================
# Section 7: Input Constraints (Flash → FPGA: Data In)
# ==============================================================================
# The flash drives data valid after tCLQV from the falling edge of SCLK (STR)
# or from both edges (DTR). The FPGA captures this data on the next rising
# edge (STR) or the opposite edge (DTR).
#
# Formula (source-synchronous input with loopback clock):
#   set_input_delay -max = board_delay_max + tCLQV
#   set_input_delay -min = board_delay_min + tCLQX
#
# We reference the virtual clock because the data delay is measured from the
# clock edge as seen at the flash (after board propagation of SCLK).

set IN_DELAY_MAX [expr {$BOARD_DELAY_MAX + $TCLQV}]
set IN_DELAY_MIN [expr {$BOARD_DELAY_MIN + $TCLQX}]

# In STR mode, flash shifts data on the falling edge of SCLK, FPGA captures
# on the rising edge. Use -clock_fall to reference the flash's launch edge.
set_input_delay -clock qspi_sclk_out -max $IN_DELAY_MAX \
    -clock_fall \
    [get_ports $QSPI_DATA_PORTS]
set_input_delay -clock qspi_sclk_out -min $IN_DELAY_MIN \
    -clock_fall \
    [get_ports $QSPI_DATA_PORTS]

if {$QSPI_MODE eq "DTR"} {
    # In DTR mode, flash also shifts data on the rising edge.
    set_input_delay -clock qspi_sclk_out -max $IN_DELAY_MAX \
        -add_delay \
        [get_ports $QSPI_DATA_PORTS]
    set_input_delay -clock qspi_sclk_out -min $IN_DELAY_MIN \
        -add_delay \
        [get_ports $QSPI_DATA_PORTS]
}


# ==============================================================================
# Section 8: Multicycle Path Adjustments
# ==============================================================================
# When the QSPI clock is divided down from the system clock, the FPGA-internal
# logic has multiple system clock cycles to set up data before SCLK toggles.
# A multicycle exception prevents the timing analyzer from over-constraining
# these paths.

if {$CLK_DIV_RATIO > 1} {
    set_multicycle_path -setup -from [get_clocks $SYS_CLK_NAME] \
        -to [get_clocks qspi_sclk_out] $CLK_DIV_RATIO
    set_multicycle_path -hold  -from [get_clocks $SYS_CLK_NAME] \
        -to [get_clocks qspi_sclk_out] [expr {$CLK_DIV_RATIO - 1}]

    set_multicycle_path -setup -from [get_clocks qspi_sclk_out] \
        -to [get_clocks $SYS_CLK_NAME] $CLK_DIV_RATIO
    set_multicycle_path -hold  -from [get_clocks qspi_sclk_out] \
        -to [get_clocks $SYS_CLK_NAME] [expr {$CLK_DIV_RATIO - 1}]
}


# ==============================================================================
# Section 9: False Paths
# ==============================================================================
# CS# is an asynchronous control signal relative to the data path timing.
# If your design manages CS# with dedicated state-machine logic and does not
# require cycle-accurate timing to the data clock, declare a false path to
# avoid unnecessary timing failures. Remove this if CS# timing is critical.

# set_false_path -to [get_ports $QSPI_CS_PORT]

# If the virtual clock is only used for analysis bookkeeping and has no
# physical clock domain crossing, cut paths between virtual and real clocks:
set_false_path -from [get_clocks qspi_flash_vclk] -to [get_clocks $SYS_CLK_NAME]
set_false_path -from [get_clocks $SYS_CLK_NAME]   -to [get_clocks qspi_flash_vclk]


# ==============================================================================
# Section 10: I/O Standard & Drive Strength
# ==============================================================================
# The MX66U1G45G operates at 1.8V. Set the FPGA I/O bank accordingly.
# These are Quartus-specific assignment commands, not pure SDC, but included
# here for completeness. They can also be set in the QSF file.
#
# Uncomment and adapt if you prefer to keep everything in one constraints file:
#
# set_instance_assignment -name IO_STANDARD "1.8 V" -to $QSPI_CLK_PORT
# set_instance_assignment -name IO_STANDARD "1.8 V" -to $QSPI_CS_PORT
# set_instance_assignment -name IO_STANDARD "1.8 V" -to qspi_io[0]
# set_instance_assignment -name IO_STANDARD "1.8 V" -to qspi_io[1]
# set_instance_assignment -name IO_STANDARD "1.8 V" -to qspi_io[2]
# set_instance_assignment -name IO_STANDARD "1.8 V" -to qspi_io[3]
#
# set_instance_assignment -name CURRENT_STRENGTH_NEW "4MA" -to $QSPI_CLK_PORT
# set_instance_assignment -name CURRENT_STRENGTH_NEW "4MA" -to $QSPI_CS_PORT
# set_instance_assignment -name CURRENT_STRENGTH_NEW "4MA" -to qspi_io[0]
# set_instance_assignment -name CURRENT_STRENGTH_NEW "4MA" -to qspi_io[1]
# set_instance_assignment -name CURRENT_STRENGTH_NEW "4MA" -to qspi_io[2]
# set_instance_assignment -name CURRENT_STRENGTH_NEW "4MA" -to qspi_io[3]
#
# set_instance_assignment -name SLEW_RATE 1 -to $QSPI_CLK_PORT
# set_instance_assignment -name SLEW_RATE 1 -to $QSPI_CS_PORT
# set_instance_assignment -name SLEW_RATE 1 -to qspi_io[0]
# set_instance_assignment -name SLEW_RATE 1 -to qspi_io[1]
# set_instance_assignment -name SLEW_RATE 1 -to qspi_io[2]
# set_instance_assignment -name SLEW_RATE 1 -to qspi_io[3]


# ==============================================================================
# Section 11: Timing Reports (informational)
# ==============================================================================
# After compilation, verify timing with:
#   quartus_sta <project> --sdc=mx66u1g45g_qspi.sdc
#
# Check the following in the Timing Analyzer:
#   1. Setup slack on all QSPI input paths  (Flash → FPGA)
#   2. Hold  slack on all QSPI input paths  (Flash → FPGA)
#   3. Setup slack on all QSPI output paths (FPGA → Flash)
#   4. Hold  slack on all QSPI output paths (FPGA → Flash)
#   5. Clock summary shows qspi_sclk_out at the expected frequency
#
# Negative slack on QSPI paths indicates a timing violation; either
# reduce QSPI_CLK_FREQ_MHZ, optimize PCB routing, or adjust FPGA
# placement/timing closure strategies.
# ==============================================================================
