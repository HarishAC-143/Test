# =============================================================================
# io_timing.sdc — I/O timing constraints for FPGA regression test designs
# =============================================================================
# Defines input and output delay constraints relative to the system clock.
# These constraints ensure that the fitter places I/O registers correctly
# and that timing analysis covers the board-level timing budget.
# =============================================================================

# ---------------------------------------------------------------------------
# Input delays
# ---------------------------------------------------------------------------
# Data arrives at the FPGA pin some time after the clock edge.
# max = longest path delay from board clock to FPGA input
# min = shortest path delay (for hold analysis)

# Counter inputs
set_input_delay -clock sys_clk -max 2.000 [get_ports {cnt_enable}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {cnt_enable}]

set_input_delay -clock sys_clk -max 2.000 [get_ports {cnt_load}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {cnt_load}]

set_input_delay -clock sys_clk -max 2.000 [get_ports {cnt_up_down}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {cnt_up_down}]

set_input_delay -clock sys_clk -max 2.000 [get_ports {cnt_load_val[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {cnt_load_val[*]}]

# FIFO inputs
set_input_delay -clock sys_clk -max 2.000 [get_ports {fifo_wr_en}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {fifo_wr_en}]

set_input_delay -clock sys_clk -max 2.000 [get_ports {fifo_rd_en}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {fifo_rd_en}]

set_input_delay -clock sys_clk -max 2.000 [get_ports {fifo_wr_data[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {fifo_wr_data[*]}]

# ALU inputs
set_input_delay -clock sys_clk -max 2.500 [get_ports {alu_a[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {alu_a[*]}]

set_input_delay -clock sys_clk -max 2.500 [get_ports {alu_b[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {alu_b[*]}]

set_input_delay -clock sys_clk -max 2.000 [get_ports {alu_op[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {alu_op[*]}]

# Reset (asynchronous — constrained separately in exceptions.sdc)
# set_input_delay not applied to rst_n since it's a false path

# ---------------------------------------------------------------------------
# Output delays
# ---------------------------------------------------------------------------
# Data must be valid at the FPGA output pin before the next clock edge,
# minus the setup time of the downstream device.

# Counter outputs
set_output_delay -clock sys_clk -max 3.000 [get_ports {cnt_value[*]}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {cnt_value[*]}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {cnt_overflow}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {cnt_overflow}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {cnt_underflow}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {cnt_underflow}]

# FIFO outputs
set_output_delay -clock sys_clk -max 3.000 [get_ports {fifo_rd_data[*]}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {fifo_rd_data[*]}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {fifo_full}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {fifo_full}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {fifo_empty}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {fifo_empty}]

# ALU outputs
set_output_delay -clock sys_clk -max 3.500 [get_ports {alu_result[*]}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {alu_result[*]}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {alu_zero}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {alu_zero}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {alu_carry}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {alu_carry}]

set_output_delay -clock sys_clk -max 3.000 [get_ports {alu_overflow}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {alu_overflow}]
