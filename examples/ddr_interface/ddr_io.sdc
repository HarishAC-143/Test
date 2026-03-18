#==============================================================
# DDR I/O Interface - SDC Constraints
#
# Demonstrates:
#   - Source-synchronous clocking constraints
#   - DDR (Double Data Rate) input/output constraints
#   - Center-aligned vs edge-aligned clocking
#   - Using -clock_fall and -add_delay for DDR
#   - Generated clock for output source-synchronous clock
#
# This example shows a generic DDR interface (not SDRAM-specific)
# applicable to LVDS, RGMII, or custom DDR protocols.
#==============================================================

#--------------------------------------------------------------
# System Clock
#--------------------------------------------------------------

create_clock -name sys_clk -period 10.000 [get_ports sys_clk]
derive_clock_uncertainty

#--------------------------------------------------------------
# DDR Input Clock (Source-Synchronous)
#--------------------------------------------------------------
# The incoming DDR clock accompanies the data.
# Data changes on BOTH rising and falling edges of this clock.

create_clock -name ddr_clk_in -period 10.000 [get_ports ddr_clk_in]

#--------------------------------------------------------------
# DDR Input Data Constraints (Center-Aligned)
#--------------------------------------------------------------
# In center-aligned mode, the clock edge arrives at the CENTER
# of the data valid window. This means data is valid for
# approximately half a period on either side of the clock edge.
#
# Timing diagram (center-aligned):
#
#   Data:  ──╱ D0 valid ╲──╱ D1 valid ╲──╱ D2 valid ╲──
#   Clock: ─────────┐         ┌─────────┐         ┌──
#                    └─────────┘         └─────────┘
#                    ▲ samples D0        ▲ samples D1
#
# Data valid window relative to clock = ±(T/2 - skew)
# With T = 10 ns and skew = 0.3 ns:
#   max_input_delay = skew = 0.3 ns
#   min_input_delay = -skew = -0.3 ns

# Rising edge captures
set_input_delay -clock ddr_clk_in -max  0.300 [get_ports {ddr_dq_in[*]}]
set_input_delay -clock ddr_clk_in -min -0.300 [get_ports {ddr_dq_in[*]}]

# Falling edge captures (-clock_fall -add_delay)
# The -add_delay flag prevents overwriting the rising edge constraint
set_input_delay -clock ddr_clk_in -max  0.300 -clock_fall -add_delay [get_ports {ddr_dq_in[*]}]
set_input_delay -clock ddr_clk_in -min -0.300 -clock_fall -add_delay [get_ports {ddr_dq_in[*]}]

#--------------------------------------------------------------
# DDR Output Clock (Generated, Source-Synchronous)
#--------------------------------------------------------------
# The FPGA generates a forwarded clock alongside the TX data.
# This is modeled as a generated clock from sys_clk.

create_generated_clock -name ddr_clk_out \
    -source [get_ports sys_clk] \
    -divide_by 1 \
    [get_ports ddr_clk_out]

#--------------------------------------------------------------
# DDR Output Data Constraints
#--------------------------------------------------------------
# For the output DDR interface, the receiving device sees data
# center-aligned with ddr_clk_out.
#
# Downstream device:
#   Tsu = 0.4 ns (setup time)
#   Th  = 0.4 ns (hold time)
#
# output_delay_max = Tsu = 0.4 ns
# output_delay_min = -Th = -0.4 ns

# Rising edge data
set_output_delay -clock ddr_clk_out -max  0.400 [get_ports {ddr_dq_out[*]}]
set_output_delay -clock ddr_clk_out -min -0.400 [get_ports {ddr_dq_out[*]}]

# Falling edge data
set_output_delay -clock ddr_clk_out -max  0.400 -clock_fall -add_delay [get_ports {ddr_dq_out[*]}]
set_output_delay -clock ddr_clk_out -min -0.400 -clock_fall -add_delay [get_ports {ddr_dq_out[*]}]

#--------------------------------------------------------------
# Clock Domain Relationships
#--------------------------------------------------------------
# The incoming DDR clock is asynchronous to the system clock
# (it originates from an external device).
# The DDR input data is first captured in the ddr_clk_in domain
# and then transferred to sys_clk via registers (quasi-CDC).

set_clock_groups -asynchronous \
    -group {sys_clk ddr_clk_out} \
    -group {ddr_clk_in}

#--------------------------------------------------------------
# Reset
#--------------------------------------------------------------

set_false_path -from [get_ports rst_n]

#--------------------------------------------------------------
# Internal I/O (sys_clk domain signals)
#--------------------------------------------------------------

# TX data input
set_input_delay -clock sys_clk -max 4.000 [get_ports {tx_data_rise[*] tx_data_fall[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {tx_data_rise[*] tx_data_fall[*]}]
set_input_delay -clock sys_clk -max 4.000 [get_ports tx_valid]
set_input_delay -clock sys_clk -min 1.000 [get_ports tx_valid]

# RX data output
set_output_delay -clock sys_clk -max 3.000 [get_ports {rx_data_rise[*] rx_data_fall[*]}]
set_output_delay -clock sys_clk -min 0.000 [get_ports {rx_data_rise[*] rx_data_fall[*]}]
set_output_delay -clock sys_clk -max 3.000 [get_ports rx_valid]
set_output_delay -clock sys_clk -min 0.000 [get_ports rx_valid]
