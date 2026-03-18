# Chapter 2: Clock Constraints

## Table of Contents

- [The Importance of Clock Definitions](#the-importance-of-clock-definitions)
- [create_clock](#create_clock)
- [create_generated_clock](#create_generated_clock)
- [Virtual Clocks](#virtual-clocks)
- [Clock Groups](#clock-groups)
- [derive_pll_clocks](#derive_pll_clocks)
- [Clock Latency and Uncertainty](#clock-latency-and-uncertainty)
- [Practical Examples](#practical-examples)

---

## The Importance of Clock Definitions

Clocks are the foundation of all timing analysis. Every timing path is analyzed relative to its launch and capture clocks. If a clock is not defined, **all paths driven by that clock are unconstrained** and will not be analyzed or optimized.

**Rule**: Every clock entering your FPGA, and every internally generated clock, must be defined in your SDC file.

## create_clock

The `create_clock` command defines a primary clock source on a port or pin.

### Syntax

```tcl
create_clock -name <clock_name> \
             -period <period_ns> \
             [-waveform {<rise_time> <fall_time>}] \
             [<source>]
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-name` | Yes | Unique name for the clock |
| `-period` | Yes | Clock period in nanoseconds |
| `-waveform` | No | Rise and fall edges (default: `{0 half_period}`) |
| `<source>` | Yes* | Port or pin where the clock exists |

### Examples

#### Standard 50 MHz Clock

```tcl
# 50 MHz clock on input port CLK
# Period = 1/50MHz = 20 ns
# Default waveform: rises at 0 ns, falls at 10 ns (50% duty cycle)
create_clock -name clk_50mhz -period 20.000 [get_ports CLK]
```

#### 100 MHz Clock with Explicit Waveform

```tcl
# Explicitly specify rise at 0 ns, fall at 5 ns
create_clock -name clk_100mhz \
             -period 10.000 \
             -waveform {0.000 5.000} \
             [get_ports CLK_100]
```

#### Non-50% Duty Cycle Clock

```tcl
# 25 MHz clock with 30% duty cycle
# Period = 40 ns, high for 12 ns (30%), low for 28 ns (70%)
create_clock -name clk_asym \
             -period 40.000 \
             -waveform {0.000 12.000} \
             [get_ports CLK_ASYM]
```

#### Clock with Phase Offset

```tcl
# 100 MHz clock shifted by 90 degrees (2.5 ns)
create_clock -name clk_90deg \
             -period 10.000 \
             -waveform {2.500 7.500} \
             [get_ports CLK_SHIFTED]
```

#### Multiple Clocks on the Same Design

```tcl
# System clock
create_clock -name sys_clk -period 20.000 [get_ports SYS_CLK]

# Memory interface clock
create_clock -name mem_clk -period 8.000 [get_ports MEM_CLK]

# Slow peripheral clock
create_clock -name peri_clk -period 100.000 [get_ports PERI_CLK]
```

## create_generated_clock

A generated clock is derived from an existing clock through logic in the design (dividers, multipliers, multiplexers). Use `create_generated_clock` when the clock is **not** produced by an Altera PLL/MMCM (those are handled by `derive_pll_clocks`).

### Syntax

```tcl
create_generated_clock -name <clock_name> \
                       -source <master_pin> \
                       [-divide_by <factor>] \
                       [-multiply_by <factor>] \
                       [-duty_cycle <percent>] \
                       [-phase <degrees>] \
                       [-edges {<edge_list>}] \
                       [-edge_shift {<shift_list>}] \
                       [-invert] \
                       <target>
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| `-source` | The pin/port of the master (parent) clock |
| `-divide_by` | Frequency division factor |
| `-multiply_by` | Frequency multiplication factor |
| `-edges` | Specific edges from the master clock to derive waveform |
| `-edge_shift` | Shift specified edges by given amounts |
| `-invert` | Invert the generated clock |

### Examples

#### Divide-by-2 Clock (Register-Based Divider)

If you have a flip-flop whose output toggles every clock cycle, creating a divide-by-2 clock:

```verilog
// Verilog: simple clock divider
always @(posedge clk_100mhz)
    clk_50mhz_reg <= ~clk_50mhz_reg;
```

```tcl
# The parent clock
create_clock -name clk_100mhz -period 10.000 [get_ports CLK_100]

# Generated divide-by-2 clock on the register output
create_generated_clock -name clk_50mhz_div \
                       -source [get_ports CLK_100] \
                       -divide_by 2 \
                       [get_registers clk_50mhz_reg]
```

#### Divide-by-4 Clock

```tcl
create_generated_clock -name clk_25mhz \
                       -source [get_ports CLK_100] \
                       -divide_by 4 \
                       [get_registers counter_reg[1]]
```

#### Clock Derived Using Edges

The `-edges` parameter specifies which edges of the master clock form the generated clock. Edges are numbered sequentially: 1 = first rising, 2 = first falling, 3 = second rising, etc.

```tcl
# Divide-by-3 clock using edge specification
# Master clock edges: 1(rise) 2(fall) 3(rise) 4(fall) 5(rise) 6(fall) 7(rise)
# Generated clock: rise at edge 1, fall at edge 4, next rise at edge 7
create_generated_clock -name clk_div3 \
                       -source [get_ports CLK] \
                       -edges {1 4 7} \
                       [get_registers div3_reg]
```

#### Inverted Clock

```tcl
create_generated_clock -name clk_inv \
                       -source [get_ports CLK] \
                       -divide_by 1 \
                       -invert \
                       [get_pins clk_inv_buf|o]
```

#### Clock Multiplexer

When a design has a clock mux, you must define a generated clock for each possible source:

```tcl
# Two source clocks
create_clock -name clk_fast -period 10.000 [get_ports CLK_FAST]
create_clock -name clk_slow -period 40.000 [get_ports CLK_SLOW]

# Generated clocks at the mux output -- one for each input
create_generated_clock -name mux_fast \
                       -source [get_ports CLK_FAST] \
                       -divide_by 1 \
                       [get_pins clk_mux|combout]

create_generated_clock -name mux_slow \
                       -source [get_ports CLK_SLOW] \
                       -divide_by 1 \
                       -add \
                       [get_pins clk_mux|combout]

# Tell TimeQuest these clocks are mutually exclusive
set_clock_groups -physically_exclusive -group {mux_fast} -group {mux_slow}
```

## Virtual Clocks

A virtual clock exists **only as a timing reference** and is not connected to any physical port or pin in the design. Virtual clocks are used to constrain I/O timing when the external interface clock is not present in the FPGA.

### When to Use Virtual Clocks

- The external device's clock is not routed to the FPGA
- You want to constrain I/O ports relative to an off-chip clock
- System-synchronous interfaces where the board clock feeds both FPGA and external device

### Syntax

```tcl
# A virtual clock has no source target
create_clock -name virt_clk -period 20.000
```

### Example: System-Synchronous Input Interface

```
  Board Clock (100 MHz)
       │
       ├──► FPGA (CLK_100 pin)
       │
       └──► External ADC ──data──► FPGA (DATA pins)
```

```tcl
# Physical clock entering the FPGA
create_clock -name fpga_clk -period 10.000 [get_ports CLK_100]

# Virtual clock representing the clock at the ADC
# (same frequency, but the FPGA doesn't receive the ADC's clock)
create_clock -name adc_clk -period 10.000

# Constrain data from ADC relative to the virtual adc_clk
set_input_delay -clock adc_clk -max 3.5 [get_ports {ADC_DATA[*]}]
set_input_delay -clock adc_clk -min 1.0 [get_ports {ADC_DATA[*]}]
```

## Clock Groups

When the design has multiple clocks, TimeQuest analyzes all possible cross-clock paths by default. Use `set_clock_groups` to tell the analyzer which clocks are related and which are not.

### Types of Clock Group Relationships

| Relationship | Meaning | Usage |
|-------------|---------|-------|
| `-asynchronous` | Clocks have no known phase relationship | Unrelated clock domains |
| `-exclusive` | Clocks never coexist (logically) | Clock mux outputs |
| `-physically_exclusive` | Clocks cannot physically coexist | Same pin, different modes |

### Examples

#### Asynchronous Clock Domains

```tcl
create_clock -name clk_sys  -period 20.000 [get_ports SYS_CLK]
create_clock -name clk_usb  -period 16.667 [get_ports USB_CLK]
create_clock -name clk_eth  -period  8.000 [get_ports ETH_CLK]

# System clock is asynchronous to USB and Ethernet clocks
set_clock_groups -asynchronous \
    -group {clk_sys} \
    -group {clk_usb} \
    -group {clk_eth}
```

This tells TimeQuest **not to analyze** timing paths between these clock domains. You must still ensure proper CDC (clock domain crossing) synchronization in your RTL.

#### Exclusive Clocks (Mux)

```tcl
set_clock_groups -exclusive \
    -group {mux_clk_a} \
    -group {mux_clk_b}
```

### Important Warning

> **Never use `set_clock_groups` to "fix" timing violations between clock domains.** If paths exist between domains, you must have proper synchronizers in your RTL. Use `set_clock_groups` only when you genuinely know the clocks are unrelated or mutually exclusive. Misuse hides real timing bugs.

## derive_pll_clocks

The `derive_pll_clocks` command is an Intel/Altera-specific command that automatically creates generated clock constraints for all PLL outputs based on the PLL configuration in your design.

### Usage

```tcl
# Automatically derive all PLL output clocks
derive_pll_clocks

# With optional multiply/divide override
derive_pll_clocks -create_base_clocks
```

### What It Does

1. Scans the design for all Altera PLL/ALTPLL/ALTERA_PLL instances
2. Reads the PLL configuration (multiplication, division, phase shift)
3. Creates `create_generated_clock` commands for each PLL output
4. Links each generated clock back to the PLL input clock

### Example

If your design has an ALTPLL configured as:

- Input: 50 MHz (from `CLK_50` port)
- Output c0: 100 MHz
- Output c1: 25 MHz, 90° phase shift

Then `derive_pll_clocks` automatically creates:

```tcl
# These are created automatically -- you do NOT write these manually
create_generated_clock -name {pll_inst|altpll_component|auto_generated|pll1|clk[0]} \
    -source [get_pins {pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
    -multiply_by 2 -duty_cycle 50.00 \
    [get_pins {pll_inst|altpll_component|auto_generated|pll1|clk[0]}]

create_generated_clock -name {pll_inst|altpll_component|auto_generated|pll1|clk[1]} \
    -source [get_pins {pll_inst|altpll_component|auto_generated|pll1|inclk[0]}] \
    -divide_by 2 -duty_cycle 50.00 -phase 90.00 \
    [get_pins {pll_inst|altpll_component|auto_generated|pll1|clk[1]}]
```

### Best Practice

Always place `derive_pll_clocks` **after** your base clock definitions:

```tcl
# 1. Define base clocks
create_clock -name clk_50mhz -period 20.000 [get_ports CLK_50]

# 2. Let Quartus handle PLL outputs
derive_pll_clocks

# 3. Then derive uncertainty
derive_clock_uncertainty
```

## Clock Latency and Uncertainty

### Clock Uncertainty

Clock uncertainty accounts for jitter, skew, and other variations. Quartus can calculate this automatically:

```tcl
derive_clock_uncertainty
```

Or you can specify it manually:

```tcl
# Setup uncertainty of 200 ps between sys_clk and itself
set_clock_uncertainty -setup 0.200 \
    -from [get_clocks sys_clk] \
    -to [get_clocks sys_clk]

# Hold uncertainty of 100 ps
set_clock_uncertainty -hold 0.100 \
    -from [get_clocks sys_clk] \
    -to [get_clocks sys_clk]
```

### Clock Latency

Clock latency is the delay from the clock source to the clock pin. In FPGAs, network latency (on-chip) is computed by the tool, but you may need to specify **source latency** for off-chip delays:

```tcl
# Board-level clock trace delay of 1.2 ns
set_clock_latency -source -early 1.0 [get_clocks sys_clk]
set_clock_latency -source -late  1.4 [get_clocks sys_clk]
```

## Practical Examples

### Example 1: Multi-Clock FPGA Design

```tcl
#--------------------------------------------------
# Constraints for a design with three clock domains
#--------------------------------------------------

# Primary system clock (50 MHz oscillator)
create_clock -name clk_sys -period 20.000 [get_ports OSC_50MHZ]

# High-speed transceiver reference clock (125 MHz)
create_clock -name clk_ref_125 -period 8.000 [get_ports REFCLK_125]

# Low-speed management clock (10 MHz)
create_clock -name clk_mgmt -period 100.000 [get_ports MGMT_CLK]

# PLL-derived clocks
derive_pll_clocks

# Clock uncertainty
derive_clock_uncertainty

# These three clocks are all asynchronous to each other
set_clock_groups -asynchronous \
    -group {clk_sys} \
    -group {clk_ref_125} \
    -group {clk_mgmt}
```

### Example 2: Cascaded Clock Dividers

```tcl
# Base clock: 200 MHz
create_clock -name clk_200 -period 5.000 [get_ports CLK_200MHZ]

# First divider: 200 MHz -> 100 MHz (divide by 2)
create_generated_clock -name clk_100 \
    -source [get_ports CLK_200MHZ] \
    -divide_by 2 \
    [get_registers div2_reg]

# Second divider: 100 MHz -> 50 MHz (divide by 2, from clk_100)
create_generated_clock -name clk_50 \
    -source [get_registers div2_reg] \
    -divide_by 2 \
    [get_registers div4_reg]

# Third divider: 50 MHz -> 25 MHz
create_generated_clock -name clk_25 \
    -source [get_registers div4_reg] \
    -divide_by 2 \
    [get_registers div8_reg]

derive_clock_uncertainty
```

### Example 3: Clock Domain with Clock Enable

A clock enable does **not** create a new clock domain. The registers are still clocked by the original clock; the enable simply gates the data path. Do NOT create a generated clock for a clock enable.

```verilog
// This is NOT a new clock -- it's a clock enable
always @(posedge clk)
    if (clk_en)
        data_out <= data_in;
```

```tcl
# CORRECT: Only the real clock is defined
create_clock -name sys_clk -period 20.000 [get_ports CLK]

# If the enabled path has more time to propagate, use multicycle:
set_multicycle_path -setup -from [get_registers {*data_src*}] \
                           -to   [get_registers {*data_out*}] 2
set_multicycle_path -hold  -from [get_registers {*data_src*}] \
                           -to   [get_registers {*data_out*}] 1
```

---

**Previous: [Chapter 1 - Introduction](01_introduction.md)** | **Next: [Chapter 3 - I/O Timing Constraints](03_io_constraints.md)**
