#==============================================================
# Clock Domain Crossing - SDC Constraints
#
# Demonstrates:
#   - Multiple asynchronous clock definitions
#   - Clock groups for unrelated domains
#   - False paths for single-bit CDC synchronizers
#   - max_delay for Gray code FIFO pointers
#   - Difference between false_path and max_delay for CDC
#
# Design: Async FIFO crossing between two clock domains
#==============================================================

#--------------------------------------------------------------
# Clock Definitions
#--------------------------------------------------------------

# Write domain clock: 100 MHz
create_clock -name wr_clk -period 10.000 [get_ports wr_clk]

# Read domain clock: 75 MHz
create_clock -name rd_clk -period 13.333 [get_ports rd_clk]

derive_clock_uncertainty

#--------------------------------------------------------------
# Clock Groups
#--------------------------------------------------------------
# The write and read clocks are asynchronous -- they come from
# independent oscillators with no phase relationship.

set_clock_groups -asynchronous \
    -group {wr_clk} \
    -group {rd_clk}

#--------------------------------------------------------------
# Gray Code Pointer Synchronization (max_delay approach)
#--------------------------------------------------------------
# For the async FIFO, Gray code pointers cross between domains.
# Gray code guarantees only 1 bit changes per clock cycle,
# making it safe for CDC with double-flop synchronizers.
#
# We use set_max_delay instead of set_false_path to ensure
# the routing delay between all bits of the Gray pointer
# is bounded. This prevents excessive skew between bits
# that could cause a 2-bit change to be seen at the
# destination (which would corrupt the pointer value).
#
# Max delay = one period of the destination clock

# Write pointer -> Read domain synchronizer
set_max_delay -from [get_registers {async_fifo:*|wr_ptr_gray[*]}] \
              -to   [get_registers {async_fifo:*|wr_ptr_gray_sync1[*]}] 13.333

# Read pointer -> Write domain synchronizer
set_max_delay -from [get_registers {async_fifo:*|rd_ptr_gray[*]}] \
              -to   [get_registers {async_fifo:*|rd_ptr_gray_sync1[*]}] 10.000

#--------------------------------------------------------------
# Single-Bit Signal Synchronizers (false path approach)
#--------------------------------------------------------------
# For single-bit level signals, a simple false path is
# sufficient because there's only one bit -- no skew concern.

# False path to the metastability register of the synchronizer
set_false_path -to [get_registers {cdc_single_bit:*|meta_reg}]

#--------------------------------------------------------------
# Reset False Paths
#--------------------------------------------------------------

set_false_path -from [get_ports wr_rst_n]
set_false_path -from [get_ports rd_rst_n]

#--------------------------------------------------------------
# I/O Constraints
#--------------------------------------------------------------

# Write side inputs
set_input_delay -clock wr_clk -max 5.000 [get_ports {wr_data[*]}]
set_input_delay -clock wr_clk -min 1.000 [get_ports {wr_data[*]}]
set_input_delay -clock wr_clk -max 5.000 [get_ports wr_en]
set_input_delay -clock wr_clk -min 1.000 [get_ports wr_en]

# Write side output (full flag)
set_output_delay -clock wr_clk -max 4.000 [get_ports wr_full]
set_output_delay -clock wr_clk -min 0.000 [get_ports wr_full]

# Read side inputs
set_input_delay -clock rd_clk -max 5.000 [get_ports rd_en]
set_input_delay -clock rd_clk -min 1.000 [get_ports rd_en]

# Read side outputs
set_output_delay -clock rd_clk -max 4.000 [get_ports {rd_data[*]}]
set_output_delay -clock rd_clk -min 0.000 [get_ports {rd_data[*]}]
set_output_delay -clock rd_clk -max 4.000 [get_ports rd_empty]
set_output_delay -clock rd_clk -min 0.000 [get_ports rd_empty]

#--------------------------------------------------------------
# Why max_delay Instead of false_path for Multi-Bit CDC?
#--------------------------------------------------------------
# Consider a 4-bit Gray code pointer: 0110 -> 0100
# Only bit[1] changes. If the routing delay to bit[1] is
# much longer than to other bits, the synchronizer might
# briefly see 0100 (correct new value) on some bits and
# 0110 (old value) on others, potentially creating 0010
# (a completely wrong value).
#
# set_max_delay ensures all bits arrive within a bounded
# time window, preventing this scenario.
#
# For single-bit signals, there's no skew concern, so
# set_false_path is perfectly fine.
