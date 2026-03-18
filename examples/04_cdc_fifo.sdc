# ============================================================
# Example 4: Clock Domain Crossing with Async FIFO
# ============================================================
# Design: Dual-clock asynchronous FIFO between unrelated domains
#
# Architecture:
#
#   Write Domain (100 MHz)        Read Domain (133 MHz)
#   ┌─────────────────────┐      ┌─────────────────────┐
#   │                     │      │                     │
#   │  wr_data ──> RAM    │      │    RAM ──> rd_data  │
#   │                     │      │                     │
#   │  wr_ptr (binary)    │      │  rd_ptr (binary)    │
#   │     │               │      │     │               │
#   │  wr_ptr_gray ───────│──────│──> rd_sync_ff1 ──>  │
#   │                     │      │    rd_sync_ff2      │
#   │                     │      │     │               │
#   │  wr_sync_ff1 <──────│──────│── rd_ptr_gray       │
#   │  wr_sync_ff2        │      │                     │
#   │     │               │      │                     │
#   │  full logic         │      │  empty logic        │
#   │                     │      │                     │
#   └─────────────────────┘      └─────────────────────┘
#
# The gray-coded pointers cross clock domains through
# double-FF synchronizers. Only 1 bit changes at a time
# in gray code, preventing metastability-induced corruption.
#
# ============================================================

# ============================================================
# Section 1: Clock Definitions
# ============================================================

# Write domain clock (100 MHz, from on-board oscillator #1)
create_clock -name wr_clk -period 10.0 [get_ports WR_CLK]

# Read domain clock (133 MHz, from on-board oscillator #2)
create_clock -name rd_clk -period 7.519 [get_ports RD_CLK]

# Clock uncertainty
derive_clock_uncertainty

# ============================================================
# Section 2: Clock Relationship
# ============================================================

# These clocks are from independent oscillators: truly asynchronous.
# set_clock_groups removes all timing arcs between the groups.
set_clock_groups -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]

# ============================================================
# Section 3: CDC Path Constraints
# ============================================================

# Even though we declared the clocks asynchronous, we want to
# add max_delay constraints on the synchronizer paths.
# This ensures the gray-coded pointer bits arrive at the
# synchronizer FFs within a reasonable time, limiting the
# impact of routing delay on MTBF.
#
# Rule of thumb: set_max_delay to one period of the
# destination clock, using -datapath_only to ignore clock skew
# (since the clocks are unrelated anyway).

# --- Write pointer -> Read domain synchronizer ---
# wr_ptr_gray changes in wr_clk domain,
# captured by rd_sync_ff1 in rd_clk domain.
# Constrain to 1 rd_clk period (7.519ns).
set_max_delay 7.519 -datapath_only \
    -from [get_registers {async_fifo|wr_ptr_gray[*]}] \
    -to   [get_registers {async_fifo|rd_sync_ff1[*]}]

# --- Read pointer -> Write domain synchronizer ---
# rd_ptr_gray changes in rd_clk domain,
# captured by wr_sync_ff1 in wr_clk domain.
# Constrain to 1 wr_clk period (10.0ns).
set_max_delay 10.0 -datapath_only \
    -from [get_registers {async_fifo|rd_ptr_gray[*]}] \
    -to   [get_registers {async_fifo|wr_sync_ff1[*]}]

# ============================================================
# Section 4: Additional CDC Paths
# ============================================================

# Reset synchronizer crossing (if async reset is used)
# The reset deassertion is synchronized in each domain.
set_false_path -from [get_ports ASYNC_RST_N]

# FIFO status flags crossing domains (optional, architecture-dependent)
# If fifo_full is used in the read domain or fifo_empty in the write
# domain, these also need CDC constraints.
# In a well-designed FIFO, status is derived from the synchronized
# pointers, so no additional constraints are needed.

# ============================================================
# Section 5: I/O Constraints
# ============================================================

# Write-side data input (synchronous to wr_clk)
set_input_delay -clock wr_clk -max 6.0 [get_ports {wr_data[*]}]
set_input_delay -clock wr_clk -min 2.0 [get_ports {wr_data[*]}]
set_input_delay -clock wr_clk -max 5.0 [get_ports wr_en]
set_input_delay -clock wr_clk -min 1.0 [get_ports wr_en]

# Read-side data output (synchronous to rd_clk)
set_output_delay -clock rd_clk -max 3.0 [get_ports {rd_data[*]}]
set_output_delay -clock rd_clk -min -1.0 [get_ports {rd_data[*]}]
set_output_delay -clock rd_clk -max 3.0 [get_ports rd_valid]
set_output_delay -clock rd_clk -min -1.0 [get_ports rd_valid]

# Status outputs
set_output_delay -clock wr_clk -max 3.0 [get_ports fifo_full]
set_output_delay -clock wr_clk -min -1.0 [get_ports fifo_full]
set_output_delay -clock rd_clk -max 3.0 [get_ports fifo_empty]
set_output_delay -clock rd_clk -min -1.0 [get_ports fifo_empty]

# Read enable (synchronous to rd_clk)
set_input_delay -clock rd_clk -max 4.0 [get_ports rd_en]
set_input_delay -clock rd_clk -min 1.0 [get_ports rd_en]
