# ============================================================
# Example 5: SDRAM Memory Interface
# ============================================================
# Design: 16-bit SDRAM controller for IS42S16320D (133 MHz, CL2)
#
# Board Topology:
#
#   FPGA (Cyclone V)                    SDRAM (IS42S16320D)
#   ┌──────────────┐                   ┌──────────────┐
#   │              │── SDRAM_CLK ────>│ CLK          │
#   │              │                   │              │
#   │              │── sdram_addr ───>│ ADDR[12:0]   │
#   │              │── sdram_ba ─────>│ BA[1:0]      │
#   │              │── sdram_cs_n ──>│ CS#          │
#   │              │── sdram_ras_n ─>│ RAS#         │
#   │              │── sdram_cas_n ─>│ CAS#         │
#   │              │── sdram_we_n ──>│ WE#          │
#   │              │── sdram_dqm ──>│ DQM[1:0]     │
#   │              │── sdram_cke ──>│ CKE          │
#   │              │                   │              │
#   │              │<=> sdram_dq <==>│ DQ[15:0]     │
#   │              │                   │              │
#   └──────────────┘                   └──────────────┘
#
# PLL Configuration:
#   Input:  50 MHz from board oscillator
#   Output: clk[0] = 133 MHz, 0°    (internal logic)
#           clk[1] = 133 MHz, -63°  (SDRAM clock, shifted to
#                                     compensate for board delay)
#
# SDRAM Timing (from IS42S16320D datasheet, -7 speed grade):
#   Tac  = 5.4ns (max access time from clock)
#   Toh  = 2.5ns (output hold from clock)
#   Tsu  = 1.5ns (input setup to clock)
#   Th   = 0.8ns (input hold from clock)
#
# Board Timing:
#   Trace delay (each way): ~0.2ns
#   Round trip: ~0.4ns
#
# ============================================================

# ============================================================
# Section 1: Clock Definitions
# ============================================================

# Board oscillator (PLL input)
create_clock -name clk_50m -period 20.0 [get_ports CLK_50M]

# Derive PLL clocks automatically
derive_pll_clocks
derive_clock_uncertainty

# ============================================================
# Section 2: SDRAM Forwarded Clock
# ============================================================

# The SDRAM_CLK pin is driven by PLL clk[1] (phase-shifted).
# This creates the clock domain seen by the SDRAM chip.
create_generated_clock -name sdram_clk \
    -source [get_pins sdram_pll|clk[1]] \
    [get_ports SDRAM_CLK]

# ============================================================
# Section 3: SDRAM Command/Address Output Timing
# ============================================================

# These are unidirectional outputs from FPGA to SDRAM.
# SDRAM sees them relative to SDRAM_CLK (sdram_clk).
#
# output_delay_max = Tsu + Tboard = 1.5 + 0.2 = 1.7ns
# output_delay_min = -(Th - Tboard) = -(0.8 - 0.2) = -0.6ns

# Address bus
set_output_delay -clock sdram_clk -max  1.7 [get_ports {sdram_addr[*]}]
set_output_delay -clock sdram_clk -min -0.6 [get_ports {sdram_addr[*]}]

# Bank address
set_output_delay -clock sdram_clk -max  1.7 [get_ports {sdram_ba[*]}]
set_output_delay -clock sdram_clk -min -0.6 [get_ports {sdram_ba[*]}]

# Command signals
set_output_delay -clock sdram_clk -max  1.7 [get_ports {sdram_cs_n sdram_ras_n sdram_cas_n sdram_we_n}]
set_output_delay -clock sdram_clk -min -0.6 [get_ports {sdram_cs_n sdram_ras_n sdram_cas_n sdram_we_n}]

# Data mask
set_output_delay -clock sdram_clk -max  1.7 [get_ports {sdram_dqm[*]}]
set_output_delay -clock sdram_clk -min -0.6 [get_ports {sdram_dqm[*]}]

# Clock enable
set_output_delay -clock sdram_clk -max  1.7 [get_ports sdram_cke]
set_output_delay -clock sdram_clk -min -0.6 [get_ports sdram_cke]

# ============================================================
# Section 4: SDRAM DQ Bidirectional Timing
# ============================================================

# --- Write Path (FPGA -> SDRAM) ---
# Same timing as command/address
set_output_delay -clock sdram_clk -max  1.7 [get_ports {sdram_dq[*]}]
set_output_delay -clock sdram_clk -min -0.6 [get_ports {sdram_dq[*]}]

# --- Read Path (SDRAM -> FPGA) ---
# SDRAM output data referenced to SDRAM_CLK at the SDRAM pin.
# input_delay_max = Tac + Tboard = 5.4 + 0.2 = 5.6ns
# input_delay_min = Toh + Tboard = 2.5 + 0.2 = 2.7ns
#
# With 133 MHz (7.519ns period) and input_delay_max of 5.6ns,
# only 1.9ns remains for FPGA internal path -- very tight!
# This is why the PLL phase shift on SDRAM_CLK is critical.
set_input_delay -clock sdram_clk -max 5.6 [get_ports {sdram_dq[*]}]
set_input_delay -clock sdram_clk -min 2.7 [get_ports {sdram_dq[*]}]

# ============================================================
# Section 5: Multicycle for SDRAM Read Data
# ============================================================

# CAS latency = 2 means data appears 2 clock cycles after
# the read command. The SDRAM controller FSM accounts for this.
# The data capture register has 2 cycles to set up.
set_multicycle_path 2 -setup -end \
    -from [get_ports {sdram_dq[*]}] \
    -to   [get_registers {sdram_ctrl|rd_data_reg[*]}]
set_multicycle_path 1 -hold -end \
    -from [get_ports {sdram_dq[*]}] \
    -to   [get_registers {sdram_ctrl|rd_data_reg[*]}]

# ============================================================
# Section 6: General Timing Exceptions
# ============================================================

# Async reset
set_false_path -from [get_ports RST_N]

# PLL lock signal (static once PLL is locked)
set_false_path -from [get_pins sdram_pll|locked]
