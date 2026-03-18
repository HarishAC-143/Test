##-----------------------------------------------------------------------------
## SDC Timing Constraints
##-----------------------------------------------------------------------------
## Standard Design Constraints (SDC) file for SpyGlass analysis.
## These constraints define clocks, I/O delays, and timing exceptions.
##
## SDC is the industry-standard constraint format also used by synthesis
## and STA (Static Timing Analysis) tools. SpyGlass reads SDC to
## supplement its SGDC constraints.
##-----------------------------------------------------------------------------

##=============================================================================
## Clock Definitions
##=============================================================================

## Core clock: 200 MHz, 50% duty cycle, no phase offset
create_clock -name clk_core -period 5.0 -waveform {0 2.5} [get_ports clk_core]

## Peripheral clock: 50 MHz
create_clock -name clk_peri -period 20.0 -waveform {0 10.0} [get_ports clk_peri]

## I/O clock: 33 MHz
create_clock -name clk_io -period 30.0 -waveform {0 15.0} [get_ports clk_io]

##=============================================================================
## Clock Relationships
##=============================================================================

## All clocks are asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks clk_core] \
    -group [get_clocks clk_peri] \
    -group [get_clocks clk_io]

##=============================================================================
## Clock Uncertainty
##=============================================================================
## Account for jitter and skew in clock distribution

set_clock_uncertainty 0.1 [get_clocks clk_core]
set_clock_uncertainty 0.2 [get_clocks clk_peri]
set_clock_uncertainty 0.3 [get_clocks clk_io]

##=============================================================================
## Input Delays
##=============================================================================
## Specify when input data arrives relative to the clock edge

## Core domain inputs
set_input_delay -clock clk_core -max 2.0 [get_ports core_data_in]
set_input_delay -clock clk_core -min 0.5 [get_ports core_data_in]
set_input_delay -clock clk_core -max 1.5 [get_ports core_wr_en]

## I/O domain inputs
set_input_delay -clock clk_io -max 10.0 [get_ports io_interrupt]

## Peripheral domain inputs
set_input_delay -clock clk_peri -max 8.0 [get_ports peri_rd_en]

##=============================================================================
## Output Delays
##=============================================================================
## Specify timing requirements for outputs

set_output_delay -clock clk_core -max 1.5 [get_ports core_fifo_full]
set_output_delay -clock clk_core -max 1.5 [get_ports system_ready]

set_output_delay -clock clk_peri -max 5.0 [get_ports peri_data_out]
set_output_delay -clock clk_peri -max 5.0 [get_ports peri_data_valid]
set_output_delay -clock clk_peri -max 5.0 [get_ports peri_fifo_empty]

set_output_delay -clock clk_io -max 8.0 [get_ports io_ack]

##=============================================================================
## False Paths
##=============================================================================
## Reset paths are handled by reset synchronizers; exclude from timing analysis

set_false_path -from [get_ports master_rst_n]

##=============================================================================
## Max Delay on CDC Paths
##=============================================================================
## For synchronizer paths, the max delay should be less than one period
## of the destination clock to ensure proper metastability resolution.

## These are typically set as max_delay constraints on CDC paths:
# set_max_delay 5.0 -from [get_clocks clk_core] -to [get_clocks clk_peri]
# set_max_delay 5.0 -from [get_clocks clk_peri] -to [get_clocks clk_core]
