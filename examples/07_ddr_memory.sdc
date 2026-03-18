# ============================================================
# Example 7: DDR2/DDR3 Memory Interface (Advanced)
# ============================================================
# Design: DDR2-800 x16 memory interface using Altera UniPHY IP
#
# DDR interfaces are the most timing-critical interfaces in
# most FPGA designs. Altera's UniPHY or EMIF IP handles most
# of the complexity, but understanding the constraints is key.
#
# Clock Architecture:
#
#   CLK_50M (board osc)
#       │
#       └── Memory PLL ──┬── afi_clk     (200 MHz, half-rate)
#                         ├── afi_clk_2x  (400 MHz, full-rate)
#                         ├── dqs_clk     (400 MHz, 90° shift)
#                         └── addr_cmd_clk(400 MHz, specific phase)
#
# DDR2-800 Timing:
#   tCK   = 2.5ns (400 MHz)
#   tDQSQ = 0.3ns (DQ-DQS skew at output)
#   tQHS  = 0.4ns (DQ-DQS hold at output)
#   tDS   = 0.15ns (DQ setup to DQS)
#   tDH   = 0.2ns  (DQ hold from DQS)
#
# ============================================================

# ============================================================
# Section 1: Reference Clock
# ============================================================

create_clock -name clk_50m -period 20.0 [get_ports CLK_50M]

# ============================================================
# Section 2: Memory PLL Clocks
# ============================================================

derive_pll_clocks
derive_clock_uncertainty

# ============================================================
# Section 3: DDR2 DQS Clocks (Source-Synchronous)
# ============================================================

# DQS strobes are bidirectional: they serve as clocks during reads.
# During writes, the FPGA generates DQS; during reads, the DRAM generates DQS.

# Read DQS clocks (from memory chip)
# These are treated as source-synchronous clocks at the FPGA input.
create_clock -name ddr2_dqs0_in -period 2.5 [get_ports {ddr2_dqs[0]}]
create_clock -name ddr2_dqs1_in -period 2.5 [get_ports {ddr2_dqs[1]}]

# ============================================================
# Section 4: Write Path Constraints
# ============================================================

# --- DQ Write Timing ---
# DQ data is launched from the FPGA relative to DQS (also from FPGA).
# DQS is phase-shifted by 90° from DQ at the FPGA output.
# At the DRAM: DQ must meet tDS and tDH relative to DQS.
#
# Create a virtual write DQS clock for the output constraints.
create_generated_clock -name ddr2_dqs0_out \
    -source [get_pins mem_pll|clk[2]] \
    [get_ports {ddr2_dqs[0]}]

create_generated_clock -name ddr2_dqs1_out \
    -source [get_pins mem_pll|clk[2]] \
    [get_ports {ddr2_dqs[1]}]

# DQ output delay relative to DQS output
# output_delay_max = tDS + board_skew = 0.15 + 0.05 = 0.20
# output_delay_min = -(tDH - board_skew) = -(0.20 - 0.05) = -0.15
set_output_delay -clock ddr2_dqs0_out -max  0.20 [get_ports {ddr2_dq[7:0]}]
set_output_delay -clock ddr2_dqs0_out -min -0.15 [get_ports {ddr2_dq[7:0]}]
set_output_delay -clock ddr2_dqs0_out -max  0.20 -clock_fall -add_delay [get_ports {ddr2_dq[7:0]}]
set_output_delay -clock ddr2_dqs0_out -min -0.15 -clock_fall -add_delay [get_ports {ddr2_dq[7:0]}]

set_output_delay -clock ddr2_dqs1_out -max  0.20 [get_ports {ddr2_dq[15:8]}]
set_output_delay -clock ddr2_dqs1_out -min -0.15 [get_ports {ddr2_dq[15:8]}]
set_output_delay -clock ddr2_dqs1_out -max  0.20 -clock_fall -add_delay [get_ports {ddr2_dq[15:8]}]
set_output_delay -clock ddr2_dqs1_out -min -0.15 -clock_fall -add_delay [get_ports {ddr2_dq[15:8]}]

# --- Address/Command Write Timing ---
# Address and command use the CK/CK# output clock as reference.
create_generated_clock -name ddr2_ck \
    -source [get_pins mem_pll|clk[3]] \
    [get_ports ddr2_ck]

# DRAM address setup/hold: tIS = 0.35ns, tIH = 0.35ns
set_output_delay -clock ddr2_ck -max  0.40 [get_ports {ddr2_addr[*] ddr2_ba[*] ddr2_ras_n ddr2_cas_n ddr2_we_n ddr2_cs_n ddr2_cke ddr2_odt}]
set_output_delay -clock ddr2_ck -min -0.40 [get_ports {ddr2_addr[*] ddr2_ba[*] ddr2_ras_n ddr2_cas_n ddr2_we_n ddr2_cs_n ddr2_cke ddr2_odt}]

# ============================================================
# Section 5: Read Path Constraints
# ============================================================

# During reads, the DRAM sends DQS along with DQ.
# DQ is edge-aligned with DQS at the DRAM output.
# After board delay, they arrive approximately aligned at FPGA.
#
# input_delay_max = tDQSQ + board_skew = 0.30 + 0.05 = 0.35
# input_delay_min = -(tQHS - board_skew) = -(0.40 - 0.05) = -0.35

set_input_delay -clock ddr2_dqs0_in -max  0.35 [get_ports {ddr2_dq[7:0]}]
set_input_delay -clock ddr2_dqs0_in -min -0.35 [get_ports {ddr2_dq[7:0]}]
set_input_delay -clock ddr2_dqs0_in -max  0.35 -clock_fall -add_delay [get_ports {ddr2_dq[7:0]}]
set_input_delay -clock ddr2_dqs0_in -min -0.35 -clock_fall -add_delay [get_ports {ddr2_dq[7:0]}]

set_input_delay -clock ddr2_dqs1_in -max  0.35 [get_ports {ddr2_dq[15:8]}]
set_input_delay -clock ddr2_dqs1_in -min -0.35 [get_ports {ddr2_dq[15:8]}]
set_input_delay -clock ddr2_dqs1_in -max  0.35 -clock_fall -add_delay [get_ports {ddr2_dq[15:8]}]
set_input_delay -clock ddr2_dqs1_in -min -0.35 -clock_fall -add_delay [get_ports {ddr2_dq[15:8]}]

# ============================================================
# Section 6: Clock Groups
# ============================================================

# Write and read DQS are never active simultaneously
# (DDR protocol: read and write are separate operations)
set_clock_groups -exclusive \
    -group [get_clocks {ddr2_dqs0_in ddr2_dqs1_in}] \
    -group [get_clocks {ddr2_dqs0_out ddr2_dqs1_out}]

# System clock is asynchronous to DQS input clocks
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m mem_pll|*}] \
    -group [get_clocks {ddr2_dqs0_in ddr2_dqs1_in}]

# ============================================================
# Section 7: General Exceptions
# ============================================================

set_false_path -from [get_ports RST_N]
set_false_path -from [get_pins mem_pll|locked]
