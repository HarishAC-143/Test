# ==============================================================
# Example 06: DDR3 Memory Interface Constraints
# ==============================================================
# Scenario:
#   - DDR3 running at 400 MHz (800 MT/s, period = 2.5 ns)
#   - FPGA has a memory controller with PLL generating the
#     DDR clock and DQS strobe
#   - System clock: 100 MHz on SYS_CLK
# ==============================================================

# ----------------------------------------------------------
# 1. System clock
# ----------------------------------------------------------
create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]

derive_pll_clocks
derive_clock_uncertainty

# ----------------------------------------------------------
# 2. Virtual DDR clock (memory side)
# ----------------------------------------------------------
# Represents the clock as seen by the DDR3 device.
create_clock -name virt_ddr_clk -period 2.5

# ----------------------------------------------------------
# 3. DQS input clock (read path)
# ----------------------------------------------------------
# DQS is a source-synchronous clock that accompanies read data.
# There is one DQS per byte lane.
create_clock -name ddr3_dqs_0 -period 2.5 [get_ports ddr3_dqs[0]]
create_clock -name ddr3_dqs_1 -period 2.5 [get_ports ddr3_dqs[1]]

# ----------------------------------------------------------
# 4. DQ data input — DDR, both edges
# ----------------------------------------------------------
# DDR3 spec: data valid ±350 ps around DQS edge (typical
# for a well-routed board).

# Byte lane 0
set_input_delay -clock ddr3_dqs_0 -max 0.35  [get_ports {ddr3_dq[0] ddr3_dq[1] ddr3_dq[2] ddr3_dq[3] ddr3_dq[4] ddr3_dq[5] ddr3_dq[6] ddr3_dq[7]}]
set_input_delay -clock ddr3_dqs_0 -max 0.35  -clock_fall -add_delay [get_ports {ddr3_dq[0] ddr3_dq[1] ddr3_dq[2] ddr3_dq[3] ddr3_dq[4] ddr3_dq[5] ddr3_dq[6] ddr3_dq[7]}]
set_input_delay -clock ddr3_dqs_0 -min -0.35 [get_ports {ddr3_dq[0] ddr3_dq[1] ddr3_dq[2] ddr3_dq[3] ddr3_dq[4] ddr3_dq[5] ddr3_dq[6] ddr3_dq[7]}]
set_input_delay -clock ddr3_dqs_0 -min -0.35 -clock_fall -add_delay [get_ports {ddr3_dq[0] ddr3_dq[1] ddr3_dq[2] ddr3_dq[3] ddr3_dq[4] ddr3_dq[5] ddr3_dq[6] ddr3_dq[7]}]

# Byte lane 1
set_input_delay -clock ddr3_dqs_1 -max 0.35  [get_ports {ddr3_dq[8] ddr3_dq[9] ddr3_dq[10] ddr3_dq[11] ddr3_dq[12] ddr3_dq[13] ddr3_dq[14] ddr3_dq[15]}]
set_input_delay -clock ddr3_dqs_1 -max 0.35  -clock_fall -add_delay [get_ports {ddr3_dq[8] ddr3_dq[9] ddr3_dq[10] ddr3_dq[11] ddr3_dq[12] ddr3_dq[13] ddr3_dq[14] ddr3_dq[15]}]
set_input_delay -clock ddr3_dqs_1 -min -0.35 [get_ports {ddr3_dq[8] ddr3_dq[9] ddr3_dq[10] ddr3_dq[11] ddr3_dq[12] ddr3_dq[13] ddr3_dq[14] ddr3_dq[15]}]
set_input_delay -clock ddr3_dqs_1 -min -0.35 -clock_fall -add_delay [get_ports {ddr3_dq[8] ddr3_dq[9] ddr3_dq[10] ddr3_dq[11] ddr3_dq[12] ddr3_dq[13] ddr3_dq[14] ddr3_dq[15]}]

# ----------------------------------------------------------
# 5. DQ data output — write path
# ----------------------------------------------------------
set_output_delay -clock virt_ddr_clk -max 0.35  [get_ports ddr3_dq[*]]
set_output_delay -clock virt_ddr_clk -max 0.35  -clock_fall -add_delay [get_ports ddr3_dq[*]]
set_output_delay -clock virt_ddr_clk -min -0.35 [get_ports ddr3_dq[*]]
set_output_delay -clock virt_ddr_clk -min -0.35 -clock_fall -add_delay [get_ports ddr3_dq[*]]

# ----------------------------------------------------------
# 6. Address and command — SDR (rising edge only)
# ----------------------------------------------------------
# Address setup/hold relative to CK: ±600 ps typical
set_output_delay -clock virt_ddr_clk -max 0.6  [get_ports {ddr3_addr[*] ddr3_ba[*] ddr3_ras_n ddr3_cas_n ddr3_we_n ddr3_cs_n ddr3_odt ddr3_cke}]
set_output_delay -clock virt_ddr_clk -min -0.4 [get_ports {ddr3_addr[*] ddr3_ba[*] ddr3_ras_n ddr3_cas_n ddr3_we_n ddr3_cs_n ddr3_odt ddr3_cke}]

# ----------------------------------------------------------
# 7. DM (data mask) — DDR like DQ
# ----------------------------------------------------------
set_output_delay -clock virt_ddr_clk -max 0.35  [get_ports ddr3_dm[*]]
set_output_delay -clock virt_ddr_clk -max 0.35  -clock_fall -add_delay [get_ports ddr3_dm[*]]
set_output_delay -clock virt_ddr_clk -min -0.35 [get_ports ddr3_dm[*]]
set_output_delay -clock virt_ddr_clk -min -0.35 -clock_fall -add_delay [get_ports ddr3_dm[*]]

# ----------------------------------------------------------
# 8. Clock groups
# ----------------------------------------------------------
# DDR domain is asynchronous to system domain.
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk}] \
    -group [get_clocks {virt_ddr_clk ddr3_dqs_0 ddr3_dqs_1}]

# ----------------------------------------------------------
# 9. DDR reset and misc — false paths
# ----------------------------------------------------------
set_false_path -to [get_ports ddr3_reset_n]
