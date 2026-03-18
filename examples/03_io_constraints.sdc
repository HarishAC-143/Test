# ============================================================================
# Example 03: Input and Output Delay Constraints
# ============================================================================
# Scenario:
#   - 100 MHz system clock
#   - 8-bit input data bus "data_in[7:0]" from an external ADC
#       ADC Tco (max) = 4.0 ns, Tco (min) = 1.5 ns
#       Board trace delay: 0.8 ns (min) to 1.2 ns (max)
#   - 8-bit output data bus "data_out[7:0]" to an external DAC
#       DAC Tsu = 3.0 ns, Th = 1.0 ns
#       Board trace delay: 0.8 ns (min) to 1.2 ns (max)
#   - Active-low reset
#   - Status LED
#
# This example shows how to calculate and apply I/O delay constraints.
# ============================================================================

# ---------------------------------------------------------------------------
# Clock
# ---------------------------------------------------------------------------
create_clock -name sys_clk -period 10.000 [get_ports clk_100]
derive_clock_uncertainty

# ---------------------------------------------------------------------------
# Input Delay Calculation (ADC -> FPGA)
# ---------------------------------------------------------------------------
#
#   input_delay_max = Board_delay_max + ADC_Tco_max
#                   = 1.2 + 4.0
#                   = 5.2 ns
#
#   input_delay_min = Board_delay_min + ADC_Tco_min
#                   = 0.8 + 1.5
#                   = 2.3 ns
#
set_input_delay -clock sys_clk -max 5.2 [get_ports {data_in[*]}]
set_input_delay -clock sys_clk -min 2.3 [get_ports {data_in[*]}]

# ---------------------------------------------------------------------------
# Output Delay Calculation (FPGA -> DAC)
# ---------------------------------------------------------------------------
#
#   output_delay_max = Board_delay_max + DAC_Tsu
#                    = 1.2 + 3.0
#                    = 4.2 ns
#
#   output_delay_min = -(Board_delay_max) + DAC_Th
#                    = -(1.2) + 1.0
#                    = -0.2 ns
#
#   Note: negative min output delay is normal and means the FPGA output
#   can change up to 0.2 ns BEFORE the clock edge arrives at the DAC.
#
set_output_delay -clock sys_clk -max  4.2 [get_ports {data_out[*]}]
set_output_delay -clock sys_clk -min -0.2 [get_ports {data_out[*]}]

# ---------------------------------------------------------------------------
# Timing budget verification
# ---------------------------------------------------------------------------
# For setup at 100 MHz (period = 10 ns):
#   Available time for FPGA internal path = Period - input_delay_max - output_delay_max
#                                         = 10.0 - 5.2 - 4.2
#                                         = 0.6 ns  (very tight!)
#
# If this is too tight, consider:
#   1. Reducing the clock frequency
#   2. Pipelining the data path
#   3. Using I/O registers (set_instance_assignment -name FAST_OUTPUT_REGISTER ON)
#   4. Optimizing board layout to reduce trace delays

# ---------------------------------------------------------------------------
# Non-timing-critical signals
# ---------------------------------------------------------------------------
set_false_path -from [get_ports rst_n]
set_false_path -to   [get_ports status_led]
