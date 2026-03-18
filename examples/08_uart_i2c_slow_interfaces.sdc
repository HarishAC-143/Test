# ============================================================
# Example 8: UART and I2C Slow Interfaces
# ============================================================
# Design: Microcontroller-style system with slow serial interfaces
#
# Demonstrates constraining interfaces that are much slower
# than the system clock, and how to handle them efficiently.
#
# System clock: 50 MHz
# UART baud rate: 115200 (8.68 us per bit)
# I2C frequency: 400 kHz (2.5 us per bit)
#
# These interfaces are SO much slower than the system clock
# that I/O timing constraints are trivially met. However,
# proper SDC practice requires constraining them anyway,
# or explicitly marking them as false paths.
#
# ============================================================

# ============================================================
# Section 1: Clock Definition
# ============================================================

create_clock -name sys_clk -period 20.0 [get_ports CLK_50M]
derive_clock_uncertainty

# ============================================================
# Section 2: UART Interface
# ============================================================

# UART is asynchronous by nature: no clock relationship between
# the transmitter and receiver. Data is oversampled (typically 16x).
#
# Approach 1 (Recommended): Use virtual clock + relaxed I/O delay
#
# Create a virtual clock representing the UART "bit clock."
# At 115200 baud, the bit period is ~8680ns. We can use a much
# shorter period since we only care about the oversampled capture.
# With 16x oversampling at 50 MHz: sample period = 20ns (sys_clk).
# The UART input just needs to be stable for one sys_clk cycle.
#
# Since there is no external clock, use a virtual clock:

create_clock -name uart_virt_clk -period 20.0

# UART RX: data changes asynchronously, but is oversampled.
# A generous input_delay ensures the tool doesn't waste effort
# optimizing these trivially-met paths.
set_input_delay -clock uart_virt_clk -max 15.0 [get_ports UART_RXD]
set_input_delay -clock uart_virt_clk -min  0.0 [get_ports UART_RXD]

# UART TX: output changes at the system clock rate.
set_output_delay -clock uart_virt_clk -max 5.0 [get_ports UART_TXD]
set_output_delay -clock uart_virt_clk -min 0.0 [get_ports UART_TXD]

# UART flow control (optional)
set_input_delay  -clock uart_virt_clk -max 15.0 [get_ports UART_CTS_N]
set_input_delay  -clock uart_virt_clk -min  0.0 [get_ports UART_CTS_N]
set_output_delay -clock uart_virt_clk -max  5.0 [get_ports UART_RTS_N]
set_output_delay -clock uart_virt_clk -min  0.0 [get_ports UART_RTS_N]

#
# Approach 2 (Simpler): Just false-path them
#
# set_false_path -from [get_ports UART_RXD]
# set_false_path -to   [get_ports UART_TXD]
# set_false_path -from [get_ports UART_CTS_N]
# set_false_path -to   [get_ports UART_RTS_N]
#
# Approach 2 is simpler but provides no constraint coverage at all.
# Approach 1 is preferred for formal verification completeness.

# ============================================================
# Section 3: I2C Interface
# ============================================================

# I2C is an open-drain bidirectional interface with external pull-ups.
# At 400 kHz, the bit period is 2500ns.
# Rise time with pull-ups: ~300ns (worst case for 400 kHz)
# Fall time: ~30ns
#
# These are extremely slow compared to any FPGA clock.
# No meaningful I/O timing analysis is possible.

# Approach: false-path (most common for I2C)
set_false_path -from [get_ports {I2C_SDA I2C_SCL}]
set_false_path -to   [get_ports {I2C_SDA I2C_SCL}]

# ============================================================
# Section 4: GPIO / Misc Slow I/O
# ============================================================

# General-purpose I/O pins (directly controlled by software)
# These change on microsecond timescales, so false-path is appropriate.
set_false_path -from [get_ports {GPIO[*]}]
set_false_path -to   [get_ports {GPIO[*]}]

# Push buttons (active-low with debouncing in RTL)
set_false_path -from [get_ports {BUTTON[*]}]

# LEDs
set_false_path -to [get_ports {LED[*]}]

# 7-segment display
set_false_path -to [get_ports {SEG7_DATA[*] SEG7_SEL[*]}]

# Buzzer / PWM output
set_false_path -to [get_ports BUZZER]

# ============================================================
# Section 5: Reset
# ============================================================

set_false_path -from [get_ports RST_N]

# ============================================================
# Notes on Slow Interface Constraining Strategy
# ============================================================
#
# For interfaces much slower than the system clock, you have
# three valid approaches:
#
# 1. Virtual clock + I/O delay:
#    Pros: Full constraint coverage, check_timing is clean
#    Cons: Slightly more complex
#
# 2. set_false_path:
#    Pros: Simplest approach
#    Cons: check_timing shows unconstrained endpoints (acceptable)
#
# 3. set_max_delay / set_min_delay:
#    Pros: Provides a bound without needing a clock relationship
#    Cons: Unusual for truly slow interfaces
#
#    Example:
#    set_max_delay 20.0 -from [get_ports UART_RXD] -to [get_registers uart|rx_sync*]
#    set_max_delay 20.0 -from [get_registers uart|tx_reg] -to [get_ports UART_TXD]
#
# Choose based on your project's constraint coverage requirements.
# ============================================================
