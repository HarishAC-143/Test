# ============================================================
# Example 1: Single-Clock Data Processing Pipeline
# ============================================================
# Design: A data processing pipeline with external SRAM and DAC
# Board:  100 MHz oscillator on SYS_CLK pin
#
# Block Diagram:
#
#   ┌──────┐         ┌────────────┐         ┌──────┐
#   │ SRAM │<------->│   FPGA     │-------->│ DAC  │
#   │      │ data    │            │ data    │      │
#   └──────┘         │ Pipeline:  │         └──────┘
#                    │ Stage1 ->  │
#   ┌──────┐         │ Stage2 ->  │         ┌──────┐
#   │ Ctrl │-------->│ Stage3     │-------->│ LEDs │
#   │ FPGA │ ctrl    │            │ status  │      │
#   └──────┘         └────────────┘         └──────┘
#        |                  |
#        └──── SYS_CLK ─────┘ (shared 100 MHz)
#
# ============================================================

# ============================================================
# Section 1: Clock Definition
# ============================================================

# 100 MHz system clock from on-board oscillator
create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]

# Clock uncertainty (auto-computed based on device)
derive_clock_uncertainty

# ============================================================
# Section 2: Input Constraints
# ============================================================

# --- External SRAM Read Data ---
# SRAM datasheet: Tco = 8ns (max), 3ns (min)
# Board trace delay: ~0.5ns
# Total input_delay_max = 8.0 + 0.5 = 8.5ns
# Total input_delay_min = 3.0 + 0.5 = 3.5ns
#
# Timing budget check:
#   Available for FPGA = Period - input_delay_max = 10.0 - 8.5 = 1.5ns
#   This is tight but feasible for a Cyclone V at 100 MHz
set_input_delay -clock sys_clk -max 8.5 [get_ports {sram_data[*]}]
set_input_delay -clock sys_clk -min 3.5 [get_ports {sram_data[*]}]

# --- Control Inputs from upstream FPGA ---
# Upstream FPGA: Tco = 5ns (max), 2ns (min)
# Board trace: ~1.0ns
set_input_delay -clock sys_clk -max 6.0 [get_ports {ctrl_in[*]}]
set_input_delay -clock sys_clk -min 3.0 [get_ports {ctrl_in[*]}]

# --- Push button input (directly from debounce circuit) ---
set_input_delay -clock sys_clk -max 7.0 [get_ports {btn_start}]
set_input_delay -clock sys_clk -min 0.0 [get_ports {btn_start}]

# ============================================================
# Section 3: Output Constraints
# ============================================================

# --- DAC Data Output ---
# DAC datasheet: Tsu = 3ns, Th = 1.5ns
# Board trace: ~0.5ns
# output_delay_max = Tsu + Tboard = 3.0 + 0.5 = 3.5ns
# output_delay_min = -(Th - Tboard) = -(1.5 - 0.5) = -1.0ns
set_output_delay -clock sys_clk -max  3.5 [get_ports {dac_data[*]}]
set_output_delay -clock sys_clk -min -1.0 [get_ports {dac_data[*]}]

# --- SRAM Write Data ---
# SRAM datasheet: Tsu = 2ns, Th = 1ns
# Board trace: ~0.5ns
set_output_delay -clock sys_clk -max  2.5 [get_ports {sram_wr_data[*]}]
set_output_delay -clock sys_clk -min -0.5 [get_ports {sram_wr_data[*]}]

# --- SRAM Control Signals ---
set_output_delay -clock sys_clk -max  2.5 [get_ports {sram_we_n sram_oe_n sram_ce_n}]
set_output_delay -clock sys_clk -min -0.5 [get_ports {sram_we_n sram_oe_n sram_ce_n}]

# --- SRAM Address ---
set_output_delay -clock sys_clk -max  2.5 [get_ports {sram_addr[*]}]
set_output_delay -clock sys_clk -min -0.5 [get_ports {sram_addr[*]}]

# ============================================================
# Section 4: Timing Exceptions
# ============================================================

# Asynchronous reset (active-low, synced internally via reset synchronizer)
set_false_path -from [get_ports RST_N]

# LED outputs (updated at human-visible rates, not timing-critical)
set_false_path -to [get_ports {LED[*]}]

# DIP switch inputs (static configuration, not timing-critical)
set_false_path -from [get_ports {DIP_SW[*]}]

# ============================================================
# Section 5: Multicycle Paths (if any)
# ============================================================

# The pipeline stage3 -> output register path uses an enable that
# activates once every 2 clock cycles
# set_multicycle_path 2 -setup \
#     -from [get_registers {pipeline|stage3|*}] \
#     -to   [get_registers {pipeline|output_reg|*}]
# set_multicycle_path 1 -hold \
#     -from [get_registers {pipeline|stage3|*}] \
#     -to   [get_registers {pipeline|output_reg|*}]
