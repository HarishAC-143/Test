# ==============================================================
# Example 05: Advanced Constraints
# ==============================================================
# Demonstrates: JTAG, clock latency, set_max_skew,
#               set_disable_timing, I/O with LVDS
# ==============================================================

create_clock -name clk_50 -period 20.0 [get_ports CLK_50]
derive_pll_clocks
derive_clock_uncertainty

# ==============================================================
# A. JTAG CLOCK
# ==============================================================
# JTAG's TCK is asynchronous to all functional clocks.
# Constrain it with a pessimistic period (slow boundary-scan
# frequency) so that JTAG-internal paths are analyzed correctly.

create_clock -name altera_reserved_tck \
    -period 100.0 \
    [get_ports altera_reserved_tck]

set_clock_groups -asynchronous \
    -group {altera_reserved_tck}

# JTAG data pins — typically false-pathed because they
# operate in the TCK domain, which is already constrained.
set_false_path -from [get_ports altera_reserved_tdi]
set_false_path -to   [get_ports altera_reserved_tdo]
set_false_path -from [get_ports altera_reserved_tms]

# ==============================================================
# B. CLOCK LATENCY (source latency)
# ==============================================================
# The board-level clock buffer adds a propagation delay
# before the clock reaches the FPGA pin.  These values come
# from the board design / IBIS simulation.
#
#   Early path: 0.3 ns (fast corner)
#   Late  path: 0.8 ns (slow corner)

set_clock_latency -source -early 0.3 [get_clocks clk_50]
set_clock_latency -source -late  0.8 [get_clocks clk_50]

# ==============================================================
# C. BUS SKEW CONSTRAINT
# ==============================================================
# A 16-bit parallel data bus must arrive at the downstream
# device within a 500 ps window to meet the receiver's
# simultaneous-switching requirement.

set_max_skew -to [get_ports par_data[*]] 0.500

# ==============================================================
# D. DISABLE TIMING ARC
# ==============================================================
# A tristate buffer is used as a level shifter; the tool
# incorrectly infers a combinational path through its
# output-enable pin.  Disable that timing arc.

# set_disable_timing -from oe -to combout [get_cells lvl_shift_inst]

# ==============================================================
# E. LVDS INPUT WITH CENTER-ALIGNED CLOCK
# ==============================================================
# Scenario: high-speed LVDS serial data at 625 MHz (DDR,
# 1.25 Gbps effective).  Clock is center-aligned with data.

create_clock -name lvds_rx_clk -period 1.6 [get_ports lvds_clk_p]

# Data valid ±200 ps around clock edge
set_input_delay -clock lvds_rx_clk -max 0.2 [get_ports lvds_data_p[*]]
set_input_delay -clock lvds_rx_clk -min -0.2 [get_ports lvds_data_p[*]]
set_input_delay -clock lvds_rx_clk -max 0.2 -clock_fall -add_delay [get_ports lvds_data_p[*]]
set_input_delay -clock lvds_rx_clk -min -0.2 -clock_fall -add_delay [get_ports lvds_data_p[*]]

set_clock_groups -asynchronous \
    -group [get_clocks clk_50] \
    -group [get_clocks lvds_rx_clk]

# ==============================================================
# F. MANUAL CLOCK UNCERTAINTY
# ==============================================================
# Add extra margin for a critical inter-domain crossing
# (on top of derive_clock_uncertainty).

# set_clock_uncertainty -setup \
#     -from [get_clocks clk_50] \
#     -to   [get_clocks pll_clk_100] \
#     0.300
