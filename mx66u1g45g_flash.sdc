#===============================================================================
#
#  SDC Timing Constraints
#  Macronix MX66U1G45G — 1.8 V, 1 Gb Serial NOR Flash
#  Target FPGA : Intel (Altera) — Quartus Prime Timing Analyzer
#
#  Datasheet   : MX66U1G45G, Rev 1.2 (August 2020)
#  Interface   : SPI / Dual-SPI / Quad-SPI, STR & DTR modes
#
#===============================================================================
#
#  TIMING MODEL
#  ============
#
#  The FPGA is the SPI bus master.  It generates SCLK, drives CS#, and
#  exchanges data with the flash on up to four I/O lines.
#
#      FPGA                 Board Traces              MX66U1G45G
#    +--------+                                      +----------+
#    |        |---SCLK----[Tbd_clk]----------------->|  CLK     |
#    |  REG   |---IO[3:0]-[Tbd_data]---------------->|  SI/IO   |  (write)
#    |        |<--IO[3:0]-[Tbd_data]-----------------| SO/IO    |  (read)
#    |        |---CS#-----[Tbd_cs]------------------>|  CS#     |
#    +--------+                                      +----------+
#
#  SPI Mode 0 (CPOL=0, CPHA=0) — default for MX66U1G45G:
#    * FPGA shifts out data on the falling edge of SCLK.
#    * Flash captures data on the rising edge of SCLK.
#    * Flash shifts out data on the falling edge of SCLK.
#    * FPGA captures data on the rising edge of SCLK.
#
#  The generated clock on the SCLK output port is the timing reference
#  for both input and output delay constraints.
#
#===============================================================================


#-------------------------------------------------------------------------------
#  Section 1 — User-Configurable Parameters
#-------------------------------------------------------------------------------
#  Adjust the values below to match your design and PCB layout.
#-------------------------------------------------------------------------------

# ---- FPGA reference clock frequency (MHz) -----------------------------------
set SYS_CLK_FREQ_MHZ       100.0

# ---- SPI clock frequency (MHz) ----------------------------------------------
#  STR limits : 50 MHz (normal read), 133 MHz (fast read / quad read)
#  DTR limit  : 83 MHz clock  =  166 MT/s effective
set SPI_CLK_FREQ_MHZ        50.0

# ---- Board trace delays (ns) ------------------------------------------------
#  Estimate ~0.14 ns/inch for outer-layer microstrip.
#  Separate min/max values capture manufacturing and length-matching tolerance.
set BOARD_CLK_DELAY_MAX      1.0
set BOARD_CLK_DELAY_MIN      0.5
set BOARD_DATA_DELAY_MAX     1.0
set BOARD_DATA_DELAY_MIN     0.5
set BOARD_CS_DELAY_MAX       1.0
set BOARD_CS_DELAY_MIN       0.5

# ---- SPI transfer mode : "STR" or "DTR" -------------------------------------
set SPI_TRANSFER_MODE       "STR"


#-------------------------------------------------------------------------------
#  Section 2 — MX66U1G45G AC Timing Parameters (from datasheet)
#-------------------------------------------------------------------------------
#  All values in nanoseconds.  The variable names follow Macronix conventions.
#
#  Symbol     | Description                               | STR   | DTR
#  -----------+-------------------------------------------+-------+------
#  tCLQV      | CLK falling to output valid (max)         | 7.0   | 6.0
#  tCLQX      | Output hold from CLK falling (min)        | 0.0   | 0.0
#  tDVCH      | Data-in setup to CLK rising (min)         | 3.0   | 1.5
#  tCHDX      | Data-in hold from CLK rising (min)        | 3.0   | 1.5
#  tSLCH      | CS# active-low to first CLK edge (min)    | 5.0   | 5.0
#  tCHSL      | Last CLK edge to CS# deassert (min)       | 5.0   | 5.0
#  tSHSL      | CS# deselect time (min)                   | 30.0  | 30.0
#  tCHSH      | CLK high time (min) — see datasheet       | 3.6   | 2.7
#  tCLSH      | CLK low time (min) — see datasheet        | 3.6   | 2.7
#-------------------------------------------------------------------------------

if {$SPI_TRANSFER_MODE eq "STR"} {
    set FLASH_TCLQV      7.0
    set FLASH_TCLQX      0.0
    set FLASH_TDVCH      3.0
    set FLASH_TCHDX      3.0
} elseif {$SPI_TRANSFER_MODE eq "DTR"} {
    set FLASH_TCLQV      6.0
    set FLASH_TCLQX      0.0
    set FLASH_TDVCH      1.5
    set FLASH_TCHDX      1.5
} else {
    error "Invalid SPI_TRANSFER_MODE \"$SPI_TRANSFER_MODE\": must be STR or DTR"
}

set FLASH_TSLCH      5.0
set FLASH_TCHSL      5.0
set FLASH_TSHSL     30.0


#-------------------------------------------------------------------------------
#  Section 3 — Port / Signal Naming
#-------------------------------------------------------------------------------
#  Change these to match the actual top-level port names in your design.
#-------------------------------------------------------------------------------

set SYS_CLK_PORT        sys_clk

set SPI_CLK_PORT        spi_clk
set SPI_CS_N_PORT       spi_cs_n
set SPI_IO_PORTS        {spi_io[0] spi_io[1] spi_io[2] spi_io[3]}


#-------------------------------------------------------------------------------
#  Section 4 — System Reference Clock
#-------------------------------------------------------------------------------

set SYS_CLK_PERIOD_NS  [expr {1000.0 / $SYS_CLK_FREQ_MHZ}]
set SPI_CLK_PERIOD_NS  [expr {1000.0 / $SPI_CLK_FREQ_MHZ}]

create_clock \
    -name        sys_clk \
    -period      $SYS_CLK_PERIOD_NS \
    [get_ports   $SYS_CLK_PORT]


#-------------------------------------------------------------------------------
#  Section 5 — SPI Generated Clock
#-------------------------------------------------------------------------------
#  The SPI clock is derived from the system clock inside the FPGA.
#  Define a generated clock on the SCLK output port so that Timing Analyzer
#  knows the relationship between the internal clock and the external SCLK.
#
#  Option A:  SCLK comes from a PLL output driving an output register.
#             Uncomment the PLL-based block and set the PLL output pin name.
#
#  Option B:  SCLK is produced by toggling a register (clock divider) or by
#             using an ALTDDIO_OUT primitive fed with 1/0 data.
#             This is the default below.
#
#  In both cases, set -divide_by to the actual division ratio.
#-------------------------------------------------------------------------------

#-- Option B : register-based SCLK (default) ----------------------------------
#  Replace "spi_clk_reg" with the register instance that drives SCLK.

create_generated_clock \
    -name        spi_clk_out \
    -source      [get_pins {spi_clk_reg|clk}] \
    -divide_by   [expr {int($SYS_CLK_FREQ_MHZ / $SPI_CLK_FREQ_MHZ)}] \
    [get_ports   $SPI_CLK_PORT]

#-- Option A : PLL-based SCLK (uncomment and adjust if using a PLL) -----------
# create_generated_clock \
#     -name        spi_clk_out \
#     -source      [get_pins {pll_inst|altpll_component|auto_generated|pll1|clk[1]}] \
#     [get_ports   $SPI_CLK_PORT]


#-------------------------------------------------------------------------------
#  Section 6 — Input Delay Constraints  (Flash → FPGA, Read Path)
#-------------------------------------------------------------------------------
#  During a read command the flash outputs data on the FALLING edge of SCLK.
#  The FPGA captures that data on the next RISING edge.
#
#  Input delay = board_clk_delay + tCLQV + board_data_delay   (max)
#  Input delay = board_clk_delay + tCLQX + board_data_delay   (min)
#
#  The -clock_fall flag tells the Timing Analyzer that the data launch reference
#  is the falling edge of spi_clk_out.
#-------------------------------------------------------------------------------

set INPUT_DELAY_MAX  [expr {$BOARD_CLK_DELAY_MAX + $FLASH_TCLQV + $BOARD_DATA_DELAY_MAX}]
set INPUT_DELAY_MIN  [expr {$BOARD_CLK_DELAY_MIN + $FLASH_TCLQX + $BOARD_DATA_DELAY_MIN}]

set_input_delay \
    -max         $INPUT_DELAY_MAX \
    -clock       spi_clk_out \
    -clock_fall \
    [get_ports   $SPI_IO_PORTS]

set_input_delay \
    -min         $INPUT_DELAY_MIN \
    -clock       spi_clk_out \
    -clock_fall \
    -add_delay \
    [get_ports   $SPI_IO_PORTS]

#-- DTR mode: data is also launched on the rising edge -------------------------
if {$SPI_TRANSFER_MODE eq "DTR"} {
    set_input_delay \
        -max         $INPUT_DELAY_MAX \
        -clock       spi_clk_out \
        -add_delay \
        [get_ports   $SPI_IO_PORTS]

    set_input_delay \
        -min         $INPUT_DELAY_MIN \
        -clock       spi_clk_out \
        -add_delay \
        [get_ports   $SPI_IO_PORTS]
}


#-------------------------------------------------------------------------------
#  Section 7 — Output Delay Constraints  (FPGA → Flash, Write / Command Path)
#-------------------------------------------------------------------------------
#  The flash samples data on the RISING edge of SCLK.
#  FPGA shifts out data so that it meets the flash setup (tDVCH) and hold
#  (tCHDX) requirements at the flash input.
#
#  output_delay_max =  tDVCH + board_data_delay - board_clk_delay  (setup)
#  output_delay_min = -tCHDX + board_data_delay - board_clk_delay  (hold)
#
#  Board-delay difference models trace-length mismatch (skew).
#-------------------------------------------------------------------------------

set OUTPUT_DELAY_MAX [expr {$FLASH_TDVCH  + $BOARD_DATA_DELAY_MAX - $BOARD_CLK_DELAY_MIN}]
set OUTPUT_DELAY_MIN [expr {-$FLASH_TCHDX + $BOARD_DATA_DELAY_MIN - $BOARD_CLK_DELAY_MAX}]

set_output_delay \
    -max         $OUTPUT_DELAY_MAX \
    -clock       spi_clk_out \
    [get_ports   $SPI_IO_PORTS]

set_output_delay \
    -min         $OUTPUT_DELAY_MIN \
    -clock       spi_clk_out \
    -add_delay \
    [get_ports   $SPI_IO_PORTS]

#-- DTR mode: flash also samples on the falling edge ---------------------------
if {$SPI_TRANSFER_MODE eq "DTR"} {
    set_output_delay \
        -max         $OUTPUT_DELAY_MAX \
        -clock       spi_clk_out \
        -clock_fall \
        -add_delay \
        [get_ports   $SPI_IO_PORTS]

    set_output_delay \
        -min         $OUTPUT_DELAY_MIN \
        -clock       spi_clk_out \
        -clock_fall \
        -add_delay \
        [get_ports   $SPI_IO_PORTS]
}


#-------------------------------------------------------------------------------
#  Section 8 — CS# Output Delay Constraints
#-------------------------------------------------------------------------------
#  CS# must be asserted at least tSLCH before the first SCLK edge and held
#  at least tCHSL after the last SCLK edge.
#
#  These are modelled as output delays relative to the generated SCLK.
#  The setup side ensures CS# is driven early enough; the hold side ensures
#  it stays asserted long enough.
#-------------------------------------------------------------------------------

set CS_OUTPUT_DELAY_MAX [expr {$FLASH_TSLCH + $BOARD_CS_DELAY_MAX - $BOARD_CLK_DELAY_MIN}]
set CS_OUTPUT_DELAY_MIN [expr {-$FLASH_TCHSL + $BOARD_CS_DELAY_MIN - $BOARD_CLK_DELAY_MAX}]

set_output_delay \
    -max         $CS_OUTPUT_DELAY_MAX \
    -clock       spi_clk_out \
    [get_ports   $SPI_CS_N_PORT]

set_output_delay \
    -min         $CS_OUTPUT_DELAY_MIN \
    -clock       spi_clk_out \
    -add_delay \
    [get_ports   $SPI_CS_N_PORT]


#-------------------------------------------------------------------------------
#  Section 9 — Clock Groups & False Paths
#-------------------------------------------------------------------------------
#  If additional clocks exist in the design that are asynchronous to the SPI
#  clock domain, declare them here to prevent spurious cross-domain timing
#  violations.
#-------------------------------------------------------------------------------

# set_clock_groups \
#     -asynchronous \
#     -group [get_clocks sys_clk] \
#     -group [get_clocks {other_async_clk}]


#-------------------------------------------------------------------------------
#  Section 10 — Multicycle Path Exceptions (Optional)
#-------------------------------------------------------------------------------
#  If the SPI controller takes multiple internal clock cycles to register
#  data from the flash (common when SPI_CLK << SYS_CLK), declare a
#  multicycle path to relax the timing requirement and prevent the analyzer
#  from over-constraining the path.
#
#  Example: SPI_CLK = SYS_CLK / N  →  N-cycle multicycle path
#-------------------------------------------------------------------------------

set SPI_CLK_DIV [expr {int($SYS_CLK_FREQ_MHZ / $SPI_CLK_FREQ_MHZ)}]

if {$SPI_CLK_DIV > 1} {
    set_multicycle_path \
        -setup $SPI_CLK_DIV \
        -from  [get_clocks spi_clk_out] \
        -to    [get_clocks sys_clk]

    set_multicycle_path \
        -hold  [expr {$SPI_CLK_DIV - 1}] \
        -from  [get_clocks spi_clk_out] \
        -to    [get_clocks sys_clk]

    set_multicycle_path \
        -setup $SPI_CLK_DIV \
        -from  [get_clocks sys_clk] \
        -to    [get_clocks spi_clk_out]

    set_multicycle_path \
        -hold  [expr {$SPI_CLK_DIV - 1}] \
        -from  [get_clocks sys_clk] \
        -to    [get_clocks spi_clk_out]
}


#-------------------------------------------------------------------------------
#  Section 11 — I/O Standard and Drive Strength (Informational)
#-------------------------------------------------------------------------------
#  These are typically set in the QSF file, not in SDC.  Listed here for
#  reference so the constraints file is self-documenting.
#
#  MX66U1G45G operates at 1.8 V (VCC = 1.65 V – 2.0 V).
#  Use a matching FPGA I/O standard:
#
#    set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_clk
#    set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_cs_n
#    set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[0]
#    set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[1]
#    set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[2]
#    set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[3]
#
#  For higher frequencies, consider:
#    set_instance_assignment -name CURRENT_STRENGTH_NEW "8MA" -to spi_clk
#    set_instance_assignment -name SLEW_RATE 1 -to spi_clk
#===============================================================================


#-------------------------------------------------------------------------------
#  Section 12 — Timing Reports (post-fit verification)
#-------------------------------------------------------------------------------
#  After compilation, verify timing closure with:
#
#    report_timing -from [get_ports $SPI_IO_PORTS] -setup -npaths 10
#    report_timing -from [get_ports $SPI_IO_PORTS] -hold  -npaths 10
#    report_timing -to   [get_ports $SPI_IO_PORTS] -setup -npaths 10
#    report_timing -to   [get_ports $SPI_IO_PORTS] -hold  -npaths 10
#    report_timing -to   [get_ports $SPI_CS_N_PORT] -setup -npaths 10
#    report_timing -to   [get_ports $SPI_CS_N_PORT] -hold  -npaths 10
#
#  All paths should report positive slack.
#===============================================================================
