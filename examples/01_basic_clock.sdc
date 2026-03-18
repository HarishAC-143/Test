# ============================================================================
# Example 01: Basic Clock Constraints
# ============================================================================
# Scenario:
#   - Single 50 MHz oscillator connected to FPGA pin "clk_50"
#   - Simple register-to-register design
#   - Active-low asynchronous reset on pin "rst_n"
#   - 8 LEDs on pins led[7:0]
#
# This is the minimal SDC file every Altera FPGA design needs.
# ============================================================================

# ---------------------------------------------------------------------------
# 1. Define the primary clock
# ---------------------------------------------------------------------------
# Period 20.000 ns = 50 MHz
# Default waveform: rising edge at 0 ns, falling edge at 10 ns (50% duty)
create_clock -name sys_clk -period 20.000 [get_ports clk_50]

# ---------------------------------------------------------------------------
# 2. Derive clock uncertainty
# ---------------------------------------------------------------------------
# This accounts for jitter and other uncertainty in the clock network.
# Always include this -- TimeQuest uses device-specific data to compute values.
derive_clock_uncertainty

# ---------------------------------------------------------------------------
# 3. Asynchronous reset: mark as false path
# ---------------------------------------------------------------------------
# The reset is asynchronous and does not need to meet setup/hold relative
# to sys_clk. Synchronizer registers handle metastability in the design.
set_false_path -from [get_ports rst_n]

# ---------------------------------------------------------------------------
# 4. LED outputs: mark as false path
# ---------------------------------------------------------------------------
# LEDs toggle slowly (human-visible) and have no timing requirements.
set_false_path -to [get_ports {led[*]}]
