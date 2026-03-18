# ============================================================================
# Example 08: Complete Real-World Design
# ============================================================================
# Design: Video Processing System
# Target: Altera Cyclone V (5CSEMA5F31C6)
#
# Block diagram:
#   +----------+    +----------+    +---------+    +----------+
#   | Camera   |--->| Image    |--->| Frame   |--->| HDMI     |
#   | Input    |    | Pipeline |    | Buffer  |    | Output   |
#   | (25 MHz) |    | (100 MHz)|    | (DDR3)  |    | (148.5MHz)|
#   +----------+    +----------+    +---------+    +----------+
#                        |                              |
#                   +---------+                    +---------+
#                   | Config  |                    | Status  |
#                   | (I2C)   |                    | (UART)  |
#                   +---------+                    +---------+
#
# Clocks:
#   clk_osc     : 50 MHz oscillator
#   cam_pclk    : 25 MHz pixel clock from camera (external, async)
#   PLL outputs : 100 MHz (core), 148.5 MHz (HDMI), 100 MHz -phase 90 (DDR3)
# ============================================================================

# ============================
# Section 1: Clock Definitions
# ============================

# Primary oscillator
create_clock -name clk_osc -period 20.000 [get_ports clk_50mhz]

# Camera pixel clock (sourced by camera module)
create_clock -name cam_pclk -period 40.000 [get_ports cam_pixel_clk]

# PLL auto-derivation
derive_pll_clocks
derive_clock_uncertainty

# After PLL derivation, expected clocks:
#   core_clk  = u_sys_pll|*|clk[0]   (100 MHz)
#   hdmi_clk  = u_sys_pll|*|clk[1]   (148.5 MHz)
#   ddr3_clk  = u_sys_pll|*|clk[2]   (100 MHz, phase = 90 deg)

# ============================
# Section 2: Clock Groups
# ============================

# Camera clock is asynchronous to everything else.
# PLL clocks are synchronous to each other (same source PLL).
set_clock_groups -asynchronous \
    -group [get_clocks {cam_pclk}] \
    -group [get_clocks {clk_osc u_sys_pll|*|clk[0] u_sys_pll|*|clk[1] u_sys_pll|*|clk[2]}]

# ============================
# Section 3: Camera Input (cam_pclk domain)
# ============================

# Camera module (OV5640) timing from datasheet:
#   Tco (max) = 9 ns, Tco (min) = 1 ns
#   Board trace: 0.5 ns to 1.0 ns
set_input_delay -clock cam_pclk -max 10.0 [get_ports {cam_data[*] cam_vsync cam_hsync cam_de}]
set_input_delay -clock cam_pclk -min  1.5 [get_ports {cam_data[*] cam_vsync cam_hsync cam_de}]

# ============================
# Section 4: HDMI Output (hdmi_clk domain)
# ============================

# HDMI transmitter (ADV7513) timing:
#   Tsu = 1.0 ns, Th = 0.7 ns
#   Board trace: 0.3 ns to 0.6 ns
set hdmi_clk_name "u_sys_pll|*|clk[1]"

set_output_delay -clock $hdmi_clk_name -max  1.6 [get_ports {hdmi_d[*] hdmi_de hdmi_hsync hdmi_vsync}]
set_output_delay -clock $hdmi_clk_name -min -0.7 [get_ports {hdmi_d[*] hdmi_de hdmi_hsync hdmi_vsync}]

# HDMI pixel clock output
set_output_delay -clock $hdmi_clk_name -max 0.5 [get_ports hdmi_clk_out]
set_output_delay -clock $hdmi_clk_name -min 0.0 [get_ports hdmi_clk_out]

# ============================
# Section 5: DDR3 SDRAM Interface
# ============================

# Note: For production DDR3 designs on Cyclone V, use the UniPHY/EMIF IP
# which generates its own SDC constraints. Below is a simplified example.

set ddr3_clk_name "u_sys_pll|*|clk[2]"

# Address/Command (SDR, referenced to ddr3_clk rising edge)
set_output_delay -clock $ddr3_clk_name -max 1.5 \
    [get_ports {ddr3_a[*] ddr3_ba[*] ddr3_ras_n ddr3_cas_n ddr3_we_n ddr3_cs_n[*] ddr3_cke[*] ddr3_odt[*]}]
set_output_delay -clock $ddr3_clk_name -min 0.3 \
    [get_ports {ddr3_a[*] ddr3_ba[*] ddr3_ras_n ddr3_cas_n ddr3_we_n ddr3_cs_n[*] ddr3_cke[*] ddr3_odt[*]}]

# ============================
# Section 6: Slow / Async Interfaces
# ============================

# I2C configuration interface (100 kHz -- no meaningful timing)
set_false_path -to   [get_ports {i2c_scl i2c_sda}]
set_false_path -from [get_ports {i2c_sda}]

# UART debug port (115200 baud)
set_false_path -to   [get_ports uart_tx]
set_false_path -from [get_ports uart_rx]

# ============================
# Section 7: Resets and Misc
# ============================

# Async resets
set_false_path -from [get_ports {rst_n cam_rst_n}]

# User buttons and switches
set_false_path -from [get_ports {btn[*] sw[*]}]

# LEDs and 7-segment display
set_false_path -to [get_ports {led[*] hex0[*] hex1[*] hex2[*] hex3[*]}]

# ============================
# Section 8: Multicycle Paths
# ============================

# Image processing pipeline: some filter stages take 2 cycles per pixel
set_multicycle_path 2 -setup \
    -from [get_registers {u_img_pipe|filter_stage1|*}] \
    -to   [get_registers {u_img_pipe|filter_stage2|*}]
set_multicycle_path 1 -hold \
    -from [get_registers {u_img_pipe|filter_stage1|*}] \
    -to   [get_registers {u_img_pipe|filter_stage2|*}]

# Configuration registers (written once via I2C, read by core logic)
set_multicycle_path 4 -setup -from [get_registers {u_i2c_slave|config_regs|*}]
set_multicycle_path 3 -hold  -from [get_registers {u_i2c_slave|config_regs|*}]

# ============================
# Section 9: Timing Verification Checklist
# ============================
# After applying these constraints, run in TimeQuest:
#
#   check_timing                    -- Verify all paths are constrained
#   report_clocks                   -- Confirm clock definitions
#   report_timing -setup -npaths 20 -- Check worst setup paths
#   report_timing -hold  -npaths 20 -- Check worst hold paths
#   report_ucd                      -- Find unconstrained paths
#   report_clock_transfers          -- Verify CDC handling
