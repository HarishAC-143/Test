# Altera FPGA Static Timing Analysis (SDC) -- Comprehensive Tutorial

## Table of Contents

1. [Introduction](#1-introduction)
2. [Fundamentals of Static Timing Analysis](#2-fundamentals-of-static-timing-analysis)
3. [SDC File Basics](#3-sdc-file-basics)
4. [Clock Constraints](#4-clock-constraints)
5. [Derived and Generated Clocks](#5-derived-and-generated-clocks)
6. [I/O Timing Constraints](#6-io-timing-constraints)
7. [Timing Exceptions](#7-timing-exceptions)
8. [Clock Groups and Relationships](#8-clock-groups-and-relationships)
9. [Advanced Constraints](#9-advanced-constraints)
10. [The TimeQuest Timing Analyzer](#10-the-timequest-timing-analyzer)
11. [Practical Examples](#11-practical-examples)
12. [Common Pitfalls and Best Practices](#12-common-pitfalls-and-best-practices)
13. [Quick Reference](#13-quick-reference)

---

## 1. Introduction

### What is Static Timing Analysis (STA)?

Static Timing Analysis is a method of validating the timing performance of a digital circuit without requiring dynamic simulation. Unlike functional simulation, STA exhaustively checks **every** timing path in the design by computing the worst-case delays through combinational logic, verifying that data arrives at flip-flop inputs before the clock edge (setup) and remains stable after the clock edge (hold).

### What is SDC?

**Synopsys Design Constraints (SDC)** is a Tcl-based constraint format originally developed by Synopsys. It has become the industry-standard language for specifying timing constraints across all major FPGA and ASIC tool flows. Intel (formerly Altera) uses SDC as the primary constraint format for its **TimeQuest Timing Analyzer** (in Quartus Prime).

### Why SDC Matters for Altera FPGAs

Without proper SDC constraints, the Quartus fitter has no guidance on:

- What clock frequencies you intend to run
- How your FPGA interfaces with external devices
- Which timing paths are critical and which can be relaxed
- How multiple clock domains relate to each other

A well-written SDC file is the difference between a design that "works on the bench" and one that is **guaranteed to work** across process, voltage, and temperature (PVT) corners.

### Altera/Intel FPGA Tool Flow

```
+------------------+     +------------------+     +------------------+
|   HDL Source     | --> |   Analysis &     | --> |    Fitter        |
|   (Verilog/VHDL) |     |   Synthesis      |     |   (Place & Route)|
+------------------+     +------------------+     +------------------+
                                 |                        |
                          +------+------+          +------+------+
                          |  SDC File   |          |  TimeQuest  |
                          | (Constraints)|          |  Analyzer   |
                          +-------------+          +-------------+
```

The SDC file feeds into both synthesis and the fitter. After place-and-route, the TimeQuest Timing Analyzer reads the same SDC file to produce detailed timing reports.

---

## 2. Fundamentals of Static Timing Analysis

### Key Timing Concepts

#### Setup Time (Tsu)

The minimum time **before** the active clock edge that data must be stable at the flip-flop input.

```
         ___________
CLK  ___|           |___________
         ^
         |<-- Tsu -->|
         |           ^
Data ----+===========+----------
         Must be stable here
```

#### Hold Time (Th)

The minimum time **after** the active clock edge that data must remain stable.

```
         ___________
CLK  ___|           |___________
         ^
         |           |<-- Th -->|
         ^           |          ^
Data ----+===========+==========+----
                     Must stay stable
```

#### Clock-to-Output (Tco)

The delay from the clock edge at a source register to when its output is valid.

#### Slack

**Slack** is the key metric in STA. It represents the margin by which a timing requirement is met or violated.

```
Setup Slack = Required Arrival Time - Actual Arrival Time

  Positive slack  --> Timing requirement MET (has margin)
  Zero slack      --> Timing requirement MET (no margin)
  Negative slack  --> Timing VIOLATION
```

#### Data Arrival Path

The path data takes from a source register (or input port) through combinational logic to a destination register (or output port):

```
Data Arrival Time = Launch Clock Edge
                  + Source Tco
                  + Combinational Logic Delay
                  + Routing Delay
```

#### Data Required Path

The latest time data is allowed to arrive at the destination:

```
Data Required Time = Latch Clock Edge
                   - Destination Tsu
                   - Clock Uncertainty
```

### Timing Path Categories

| Path Type | Source | Destination | Constrained By |
|---|---|---|---|
| Register-to-Register | Flip-flop | Flip-flop | `create_clock` |
| Input-to-Register | Input port | Flip-flop | `set_input_delay` |
| Register-to-Output | Flip-flop | Output port | `set_output_delay` |
| Input-to-Output | Input port | Output port | `set_max_delay` |

---

## 3. SDC File Basics

### File Structure

An SDC file (`.sdc`) is a Tcl script executed sequentially. Order matters -- constraints defined later can override earlier ones.

```tcl
# ============================================================================
# Project: My Altera Design
# File:    my_design.sdc
# Purpose: Timing constraints for TimeQuest
# ============================================================================

# ---- Clock Definitions ----
create_clock -name sys_clk -period 10.000 [get_ports clk]

# ---- I/O Constraints ----
set_input_delay  -clock sys_clk -max 3.0 [get_ports data_in]
set_output_delay -clock sys_clk -max 2.0 [get_ports data_out]

# ---- Timing Exceptions ----
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# ---- Multicycle Paths ----
set_multicycle_path 2 -setup -from [get_registers slow_reg*]
```

### Tcl Collections and Accessor Commands

SDC uses **collections** (not Tcl lists) to refer to design objects. The key accessor commands are:

| Command | Returns | Example |
|---|---|---|
| `get_ports` | Top-level I/O ports | `get_ports {clk rst data[*]}` |
| `get_pins` | Hierarchical instance pins | `get_pins {u_pll\|clk_out}` |
| `get_registers` | Register (flip-flop) nodes | `get_registers {data_reg[*]}` |
| `get_cells` | Design instances | `get_cells {u_fifo\|*}` |
| `get_clocks` | Defined clock objects | `get_clocks {sys_clk}` |
| `get_nets` | Net objects | `get_nets {bus[*]}` |

#### Wildcards

- `*` matches any sequence of characters (including none) within a hierarchy level
- `?` matches exactly one character
- Altera uses `|` as the hierarchy separator (not `/` as in some ASIC flows)

```tcl
# All registers whose name starts with "cnt_"
get_registers {cnt_*}

# All registers in instance u_ctrl
get_registers {u_ctrl|*}

# A specific bit
get_ports {data[3]}

# All bits of a bus
get_ports {data[*]}
```

### SDC Execution in Quartus

Quartus processes SDC files in a defined order:

1. SDC files listed in the `.qsf` (Quartus Settings File) via `set_global_assignment -name SDC_FILE`
2. Files are processed in the order they appear
3. If multiple SDC files contain conflicting constraints, the last one wins

```tcl
# In your .qsf file:
set_global_assignment -name SDC_FILE constraints/clocks.sdc
set_global_assignment -name SDC_FILE constraints/io.sdc
set_global_assignment -name SDC_FILE constraints/exceptions.sdc
```

---

## 4. Clock Constraints

Clock constraints are the most fundamental SDC commands. Without them, the TimeQuest Analyzer cannot analyze any register-to-register paths.

### create_clock

Defines a clock on a port or pin.

**Syntax:**

```tcl
create_clock -name <clock_name> -period <period_ns> [-waveform {<rise> <fall>}] <targets>
```

**Parameters:**

| Parameter | Description | Default |
|---|---|---|
| `-name` | Clock object name | Same as target name |
| `-period` | Clock period in nanoseconds | Required |
| `-waveform` | Rise and fall edges (ns) | `{0 half_period}` |
| `targets` | Port or pin to attach clock | Required |

#### Example 1: Simple 100 MHz Clock

```tcl
create_clock -name sys_clk -period 10.000 [get_ports clk]
```

This creates a clock named `sys_clk` with:
- Period: 10 ns (100 MHz)
- Rising edge at 0 ns
- Falling edge at 5 ns (default 50% duty cycle)

#### Example 2: Clock with Custom Duty Cycle

```tcl
# 100 MHz clock with 60/40 duty cycle
create_clock -name sys_clk -period 10.000 -waveform {0 6.0} [get_ports clk]
```

Rising edge at 0 ns, falling edge at 6 ns (60% high, 40% low).

#### Example 3: Clock with Phase Offset

```tcl
# 100 MHz clock with 90-degree phase shift
create_clock -name clk_90 -period 10.000 -waveform {2.5 7.5} [get_ports clk_shifted]
```

#### Example 4: Virtual Clock

A virtual clock is not attached to any physical port. It represents an external device clock used as a reference for I/O timing.

```tcl
create_clock -name virt_clk -period 8.000
```

No target specified -- this clock exists only as a timing reference.

### Multiple Clocks on the Same Port

When a port can receive different clock frequencies (e.g., a multiplexed clock input):

```tcl
create_clock -name clk_fast -period 5.000  [get_ports clk_mux] -add
create_clock -name clk_slow -period 20.000 [get_ports clk_mux] -add
```

The `-add` flag prevents the second definition from overriding the first. TimeQuest will analyze timing against **both** clocks.

---

## 5. Derived and Generated Clocks

### create_generated_clock

Generated clocks are derived from a master clock through frequency division, multiplication, or phase shifting. PLLs and clock dividers produce generated clocks.

**Syntax:**

```tcl
create_generated_clock -name <name> -source <master_pin> \
    [-divide_by <factor>] [-multiply_by <factor>] \
    [-duty_cycle <percent>] [-phase <degrees>] \
    [-offset <ns>] <targets>
```

#### Example 1: PLL Output Clocks (Altera PLL)

When you instantiate an Altera PLL (e.g., `altpll` or `altera_pll`), Quartus **automatically** creates generated clock constraints. You can verify these with:

```tcl
# In TimeQuest console:
report_clocks
```

However, for manual PLL output constraints or custom clock management:

```tcl
# PLL with 100 MHz input producing 200 MHz and 50 MHz outputs
create_clock -name pll_inclk -period 10.000 [get_ports clk_in]

create_generated_clock -name pll_clk_200 \
    -source [get_pins {u_pll|altpll_component|auto_generated|pll1|inclk[0]}] \
    -multiply_by 2 \
    [get_pins {u_pll|altpll_component|auto_generated|pll1|clk[0]}]

create_generated_clock -name pll_clk_50 \
    -source [get_pins {u_pll|altpll_component|auto_generated|pll1|inclk[0]}] \
    -divide_by 2 \
    [get_pins {u_pll|altpll_component|auto_generated|pll1|clk[1]}]
```

#### Example 2: Clock Divider in RTL

If you divide a clock in your RTL logic:

```verilog
// Verilog: divide-by-2 clock
always @(posedge clk) begin
    clk_div2 <= ~clk_div2;
end
```

You must constrain the divided clock:

```tcl
create_generated_clock -name clk_div2 \
    -source [get_ports clk] \
    -divide_by 2 \
    [get_registers clk_div2]
```

#### Example 3: Ripple Clock Chain

```tcl
# A 3-stage ripple divider: clk -> /2 -> /4 -> /8
create_clock -name base_clk -period 10.000 [get_ports clk]

create_generated_clock -name clk_div2 \
    -source [get_ports clk] \
    -divide_by 2 \
    [get_registers div2_reg]

create_generated_clock -name clk_div4 \
    -source [get_registers div2_reg] \
    -divide_by 2 \
    [get_registers div4_reg]

create_generated_clock -name clk_div8 \
    -source [get_registers div4_reg] \
    -divide_by 2 \
    [get_registers div8_reg]
```

### derive_pll_clocks

Altera provides a convenience command that automatically creates generated clock constraints for all PLL outputs:

```tcl
derive_pll_clocks
```

This is the **recommended approach** for most Altera designs. It reads the PLL configuration and creates appropriate `create_generated_clock` constraints for each output.

**With an uncertainty override:**

```tcl
derive_pll_clocks -create_base_clocks
```

The `-create_base_clocks` option also creates `create_clock` constraints for PLL input clocks that are not yet constrained.

---

## 6. I/O Timing Constraints

I/O constraints tell the timing analyzer about the timing relationship between the FPGA and external devices.

### set_input_delay

Specifies the arrival time of data at an FPGA input port relative to a clock.

**Syntax:**

```tcl
set_input_delay -clock <clock_name> -max <max_delay> [-min <min_delay>] \
    [-clock_fall] [-add_delay] <port_list>
```

**Concept:**

```
External Device                        FPGA
+-----------+      +--------+      +-----------+
|   Reg Q   |----->| Board  |----->| Input Pin |---> FPGA Reg D
|           |      | Trace  |      |           |
+-----------+      +--------+      +-----------+
     Tco        +  Tboard     =    Input Delay
```

The input delay represents the total delay from the external clock edge to the FPGA input port: `input_delay = Tco_external + Tboard_trace`.

#### Example 1: Simple Input Delay

```tcl
# External device: Tco_max = 2.5 ns, Board delay max = 1.0 ns
# input_delay_max = 2.5 + 1.0 = 3.5 ns
set_input_delay -clock sys_clk -max 3.5 [get_ports {data_in[*]}]
set_input_delay -clock sys_clk -min 1.0 [get_ports {data_in[*]}]
```

#### Example 2: System Synchronous Input (Source Synchronous)

In a source-synchronous interface, the clock travels alongside the data:

```tcl
# Source synchronous DDR input (e.g., memory interface)
create_clock -name src_clk -period 5.000 [get_ports dqs]

# Data arrives within +/- 0.5 ns of the clock edge
set_input_delay -clock src_clk -max  0.5 [get_ports {dq[*]}]
set_input_delay -clock src_clk -min -0.5 [get_ports {dq[*]}]

# For the falling edge data (DDR)
set_input_delay -clock src_clk -max  0.5 -clock_fall -add_delay [get_ports {dq[*]}]
set_input_delay -clock src_clk -min -0.5 -clock_fall -add_delay [get_ports {dq[*]}]
```

#### Example 3: Input Delay Referenced to Virtual Clock

When the FPGA receives data from a system with a clock not connected to the FPGA:

```tcl
create_clock -name virt_ext_clk -period 20.000

set_input_delay -clock virt_ext_clk -max 8.0 [get_ports sensor_data]
set_input_delay -clock virt_ext_clk -min 2.0 [get_ports sensor_data]
```

### set_output_delay

Specifies the timing requirement at an FPGA output port relative to a clock.

**Syntax:**

```tcl
set_output_delay -clock <clock_name> -max <max_delay> [-min <min_delay>] \
    [-clock_fall] [-add_delay] <port_list>
```

**Concept:**

```
        FPGA                            External Device
+-----------+      +--------+      +-----------+
| FPGA Reg Q|----->| Board  |----->| Input Pin |---> Ext Reg D
|           |      | Trace  |      |   Tsu/Th  |
+-----------+      +--------+      +-----------+
                     Tboard    +     Tsu_ext    =    Output Delay (max)
                   - Tboard    +     Th_ext     =    Output Delay (min)
```

#### Example 1: Simple Output Delay

```tcl
# External device: Tsu = 2.0 ns, Th = 0.5 ns, Board delay = 1.0 ns
# output_delay_max = Tboard + Tsu = 1.0 + 2.0 = 3.0 ns
# output_delay_min = -Tboard + Th = -(1.0) + 0.5 = -0.5 ns  (or use Th directly)
set_output_delay -clock sys_clk -max  3.0 [get_ports {data_out[*]}]
set_output_delay -clock sys_clk -min -0.5 [get_ports {data_out[*]}]
```

#### Example 2: DDR Output (Double Data Rate)

```tcl
# Output data changes on both rising and falling edges
create_clock -name ddr_clk -period 5.000 [get_ports ddr_clk_out]

# Rising edge data
set_output_delay -clock ddr_clk -max 1.2 [get_ports {ddr_dq[*]}]
set_output_delay -clock ddr_clk -min 0.3 [get_ports {ddr_dq[*]}]

# Falling edge data
set_output_delay -clock ddr_clk -max 1.2 -clock_fall -add_delay [get_ports {ddr_dq[*]}]
set_output_delay -clock ddr_clk -min 0.3 -clock_fall -add_delay [get_ports {ddr_dq[*]}]
```

### derive_clock_uncertainty

Automatically applies clock-to-clock transfer uncertainty (jitter) based on device characterization data:

```tcl
derive_clock_uncertainty
```

This is **strongly recommended** for all Altera designs. It accounts for:
- PLL jitter
- Inter-clock transfer uncertainty
- Intra-clock transfer uncertainty

---

## 7. Timing Exceptions

Timing exceptions override the default timing analysis behavior for specific paths.

### set_false_path

Declares that certain timing paths should not be analyzed. Use for paths that are functionally impossible or where timing is irrelevant.

**Syntax:**

```tcl
set_false_path [-from <source>] [-through <through>] [-to <destination>]
```

#### Example 1: Asynchronous Clock Domain Crossing

```tcl
# Two unrelated clocks -- crossing is handled by a synchronizer
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
set_false_path -from [get_clocks clk_b] -to [get_clocks clk_a]
```

#### Example 2: Reset Path

```tcl
# Asynchronous reset -- timing not critical
set_false_path -from [get_ports rst_n]
```

#### Example 3: Static Configuration Registers

```tcl
# Configuration registers written once at startup
set_false_path -from [get_registers {config_reg[*]}]
```

#### Example 4: False Path Through a Mux Select

```tcl
# Data path through a debug mux that is only used during testing
set_false_path -through [get_pins {u_debug_mux|sel}]
```

> **Warning:** Over-using `set_false_path` is dangerous. If you false-path a real timing path, the tools will not optimize it, and your design may fail in hardware.

### set_multicycle_path

Specifies that a timing path has more than one clock cycle to propagate.

**Syntax:**

```tcl
set_multicycle_path <path_multiplier> [-setup|-hold] \
    [-from <source>] [-to <destination>] [-through <through>] \
    [-start|-end]
```

**Key rules for multicycle paths:**

| Constraint | Effect |
|---|---|
| `set_multicycle_path N -setup` | Data has N clock cycles to propagate (setup check) |
| `set_multicycle_path N-1 -hold` | Typically accompanies setup MCP to keep hold check correct |

#### Example 1: 2x Multicycle Path (Same Clock Domain)

A computation that takes two clock cycles:

```verilog
// RTL: result is only sampled every 2 cycles (enabled by valid pulse)
always @(posedge clk) begin
    if (phase == 1'b0)
        result <= a * b;   // Multiplication takes 2 cycles
end
```

```tcl
set_multicycle_path 2 -setup -from [get_registers {a_reg[*] b_reg[*]}] \
                              -to   [get_registers {result[*]}]
set_multicycle_path 1 -hold  -from [get_registers {a_reg[*] b_reg[*]}] \
                              -to   [get_registers {result[*]}]
```

#### Example 2: Multicycle Between Different Frequency Clocks

When a slow clock domain sends data to a fast clock domain:

```tcl
# 50 MHz -> 100 MHz transfer, data held for 2 fast clock cycles
create_clock -name clk_slow -period 20.000 [get_ports clk_50]
create_clock -name clk_fast -period 10.000 [get_ports clk_100]

set_multicycle_path 2 -setup -end \
    -from [get_clocks clk_slow] \
    -to   [get_clocks clk_fast]
set_multicycle_path 1 -hold -end \
    -from [get_clocks clk_slow] \
    -to   [get_clocks clk_fast]
```

The `-end` flag means the multiplier is in terms of the destination (latch) clock.

#### Example 3: Multicycle for a Pipelined Data Path

```tcl
# A 4-stage pipeline where each stage takes 1 cycle,
# but the overall path from input to output register has 4 cycles
set_multicycle_path 4 -setup -from [get_registers {pipe_stage0[*]}] \
                              -to   [get_registers {pipe_stage3[*]}]
set_multicycle_path 3 -hold  -from [get_registers {pipe_stage0[*]}] \
                              -to   [get_registers {pipe_stage3[*]}]
```

### set_max_delay / set_min_delay

Overrides the clock-based timing for a specific path with an explicit delay requirement.

```tcl
# Input-to-output combinational path: must be less than 15 ns
set_max_delay 15.0 -from [get_ports data_in] -to [get_ports data_out]

# Minimum delay requirement (useful for hold-critical paths)
set_min_delay 2.0 -from [get_registers reg_a] -to [get_registers reg_b]
```

---

## 8. Clock Groups and Relationships

### set_clock_groups

Defines the relationship between clocks. This is often more appropriate than `set_false_path` for clock domain crossings.

**Syntax:**

```tcl
set_clock_groups -asynchronous|-exclusive \
    -group {<clock_list_1>} \
    -group {<clock_list_2>} \
    [-group {<clock_list_N>}]
```

| Mode | Meaning |
|---|---|
| `-asynchronous` | Clocks have no known phase relationship; no timing analysis between groups |
| `-exclusive` | Clocks never coexist (e.g., muxed clocks); no timing analysis between groups |

#### Example 1: Asynchronous Clock Domains

```tcl
# Three independent clock domains
set_clock_groups -asynchronous \
    -group {sys_clk} \
    -group {eth_rx_clk eth_tx_clk} \
    -group {usb_clk}
```

This is equivalent to writing `set_false_path` between every pair, but is cleaner and less error-prone.

#### Example 2: Mutually Exclusive Clocks (Clock Mux)

```tcl
# A clock mux selects between clk_a and clk_b
create_clock -name clk_a -period 10.0 [get_ports clk_mux] -add
create_clock -name clk_b -period 8.0  [get_ports clk_mux] -add

set_clock_groups -exclusive -group {clk_a} -group {clk_b}
```

#### Example 3: PLL Outputs and External Clocks

```tcl
# PLL-generated clocks are synchronous to each other but async to an external clock
derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous \
    -group [get_clocks {u_pll|*|clk[0] u_pll|*|clk[1] u_pll|*|clk[2]}] \
    -group [get_clocks {ext_clk}]
```

---

## 9. Advanced Constraints

### Clock Latency

Specifies the delay of the clock signal from its source to the FPGA input.

```tcl
# External clock source has 1.2 ns of board-level delay
set_clock_latency -source -max 1.5 [get_clocks sys_clk]
set_clock_latency -source -min 1.0 [get_clocks sys_clk]
```

### Clock Uncertainty (Jitter)

Manually set clock uncertainty (overrides `derive_clock_uncertainty`):

```tcl
# Add 200 ps of setup uncertainty, 50 ps of hold uncertainty
set_clock_uncertainty -setup 0.200 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.050 [get_clocks sys_clk]

# Inter-clock uncertainty
set_clock_uncertainty -setup 0.300 \
    -from [get_clocks clk_a] -to [get_clocks clk_b]
```

### Disable Timing on Specific Pins

```tcl
# Disable timing arcs through an asynchronous clear pin
set_disable_timing -from CLR [get_cells u_reg]
```

### set_max_skew

Constrains the maximum skew between signals in a group (useful for bus signals):

```tcl
set_max_skew -from [get_ports {data[*]}] 0.5
```

### Min/Max Pulse Width

Ensures clock pulses meet minimum width requirements:

```tcl
# Not standard SDC, but supported in TimeQuest
set_min_pulse_width -low  2.0 [get_clocks sys_clk]
set_min_pulse_width -high 2.0 [get_clocks sys_clk]
```

---

## 10. The TimeQuest Timing Analyzer

### Using TimeQuest in Quartus Prime

TimeQuest is accessed through:
- **GUI**: Tools -> TimeQuest Timing Analyzer
- **Command Line**: `quartus_sta <project_name>`
- **Tcl Console**: Within Quartus or TimeQuest

### Key TimeQuest Tcl Commands

#### Reporting Commands

```tcl
# Report all clocks defined in the design
report_clocks

# Report the worst-case setup timing for all paths
report_timing -setup -npaths 20 -detail full_path

# Report hold timing
report_timing -hold -npaths 20 -detail full_path

# Report timing for a specific clock domain
report_timing -from_clock sys_clk -to_clock sys_clk -setup -npaths 10

# Report timing for specific registers
report_timing -from [get_registers src_reg] -to [get_registers dst_reg]

# Report unconstrained paths (paths with no timing requirement)
report_ucd

# Report minimum pulse width
report_min_pulse_width

# Report clock transfers
report_clock_transfers

# Check that all I/O ports are constrained
check_timing
```

#### Reading the Timing Report

A typical TimeQuest timing report looks like:

```
Info: Clock Setup: 'sys_clk'
+--------+------------------+-------+-----------+------------+-----------+
| Slack  | From             | To    | Data Req  | Data Arr   | Clock     |
+--------+------------------+-------+-----------+------------+-----------+
| 2.134  | reg_a|regout     | reg_b | 9.800     | 7.666      | sys_clk   |
| 1.856  | cnt[3]|regout    | cnt[4]| 9.800     | 7.944      | sys_clk   |
| 0.234  | state[0]|regout  | out_r | 9.800     | 9.566      | sys_clk   |
+--------+------------------+-------+-----------+------------+-----------+
```

Key observations:
- **Positive slack** on all paths: timing is met
- The last row has only 0.234 ns of margin -- this is the critical path
- Slack = Data Required - Data Arrival = 9.800 - 9.566 = 0.234 ns

### TimeQuest Flow

```tcl
# Typical TimeQuest analysis script
# (Run after full compilation)

project_open my_project
create_timing_netlist
read_sdc my_design.sdc

update_timing_netlist

# Check for constraint issues
check_timing

# Generate reports
report_clocks                                     -panel_name "Clocks"
report_timing -setup -npaths 50 -detail full_path -panel_name "Setup"
report_timing -hold  -npaths 50 -detail full_path -panel_name "Hold"
report_min_pulse_width                            -panel_name "Pulse Width"
report_clock_transfers                            -panel_name "Clock Xfers"

# Report unconstrained paths
report_ucd -panel_name "Unconstrained"

delete_timing_netlist
project_close
```

---

## 11. Practical Examples

### Example A: Complete SDC for a Simple UART Design

Consider a UART module with:
- 50 MHz system clock
- UART TX/RX pins
- Active-low reset
- 8-bit parallel data bus

```tcl
# ============================================================================
# UART Design - SDC Constraints
# Target: Altera Cyclone V
# ============================================================================

# ---- Primary Clock ----
create_clock -name sys_clk -period 20.000 [get_ports clk_50mhz]

# ---- Auto-derive PLL clocks (if any) ----
derive_pll_clocks
derive_clock_uncertainty

# ---- Reset (asynchronous, false path) ----
set_false_path -from [get_ports rst_n]

# ---- UART I/O Constraints ----
# UART is slow (115200 baud = 8.68 us per bit), so timing is relaxed
# We still constrain to catch gross errors

# TX output: data must be valid 5 ns before external device samples
set_output_delay -clock sys_clk -max 5.0 [get_ports uart_tx]
set_output_delay -clock sys_clk -min 0.0 [get_ports uart_tx]

# RX input: data arrives with some delay from external transmitter
set_input_delay  -clock sys_clk -max 10.0 [get_ports uart_rx]
set_input_delay  -clock sys_clk -min 0.0  [get_ports uart_rx]

# ---- Parallel Data Bus ----
set_input_delay  -clock sys_clk -max 4.0 [get_ports {data_in[*]}]
set_input_delay  -clock sys_clk -min 1.0 [get_ports {data_in[*]}]

set_output_delay -clock sys_clk -max 4.0 [get_ports {data_out[*]}]
set_output_delay -clock sys_clk -min 0.5 [get_ports {data_out[*]}]

# ---- Status LEDs (no strict timing) ----
set_false_path -to [get_ports {led[*]}]
```

### Example B: Multi-Clock SPI Master with PLL

Design with:
- 100 MHz input clock
- PLL generating 200 MHz core clock and 25 MHz SPI clock
- SPI interface to external flash
- Asynchronous reset

```tcl
# ============================================================================
# SPI Master with PLL - SDC Constraints
# Target: Altera Cyclone 10 LP
# ============================================================================

# ---- Base Clock ----
create_clock -name clk_100 -period 10.000 [get_ports clk_100mhz]

# ---- PLL Clocks ----
derive_pll_clocks
derive_clock_uncertainty

# After derive_pll_clocks, assume the following are created:
#   u_pll|altpll_component|auto_generated|pll1|clk[0]  -> 200 MHz (core)
#   u_pll|altpll_component|auto_generated|pll1|clk[1]  -> 25 MHz  (SPI)

# ---- Convenience aliases ----
# (These are just for readability in subsequent constraints)
set core_clk {u_pll|altpll_component|auto_generated|pll1|clk[0]}
set spi_clk  {u_pll|altpll_component|auto_generated|pll1|clk[1]}

# ---- SPI Output Constraints ----
# Virtual clock representing the SPI slave's clock input
create_clock -name spi_ext_clk -period 40.000

# SPI MOSI, CS_N: referenced to SPI clock
# External flash: Tsu = 5 ns, Board delay = 2 ns
set_output_delay -clock spi_ext_clk -max 7.0 [get_ports {spi_mosi spi_cs_n}]
set_output_delay -clock spi_ext_clk -min 1.0 [get_ports {spi_mosi spi_cs_n}]

# SPI SCLK output
set_output_delay -clock spi_ext_clk -max 0.5 [get_ports spi_sclk]
set_output_delay -clock spi_ext_clk -min 0.0 [get_ports spi_sclk]

# ---- SPI Input Constraints ----
# MISO input: Flash Tco = 8 ns, Board delay = 2 ns
set_input_delay -clock spi_ext_clk -max 10.0 [get_ports spi_miso]
set_input_delay -clock spi_ext_clk -min 3.0  [get_ports spi_miso]

# ---- Clock Domain Crossing: Core <-> SPI ----
# CDC is handled by synchronizer FIFOs in RTL
set_clock_groups -asynchronous \
    -group [get_clocks $core_clk] \
    -group [get_clocks $spi_clk]

# ---- Asynchronous Reset ----
set_false_path -from [get_ports rst_n]

# ---- Debug / Status Signals ----
set_false_path -to [get_ports {led[*] debug_tp[*]}]
```

### Example C: DDR3 Memory Interface (High-Speed)

A simplified DDR3 SDRAM interface constraint set:

```tcl
# ============================================================================
# DDR3 Memory Interface - SDC Constraints
# Target: Altera Arria 10
# ============================================================================

# ---- Reference Clock ----
create_clock -name mem_refclk -period 5.000 [get_ports ddr3_refclk]

# ---- PLL Clocks ----
derive_pll_clocks
derive_clock_uncertainty

# ---- Write DQS (Output Clock to Memory) ----
create_generated_clock -name write_dqs \
    -source [get_pins {u_mem_ctrl|phy|dqs_out|clk}] \
    -phase 90 \
    [get_ports {ddr3_dqs[0]}]

# ---- Read DQS (Input Clock from Memory) ----
create_clock -name read_dqs -period 2.5 [get_ports {ddr3_dqs[0]}]

# ---- DQ Output Timing (Write) ----
# Memory Tds = 0.040 ns, Tdh = 0.065 ns
set_output_delay -clock write_dqs -max  0.294 [get_ports {ddr3_dq[*]}]
set_output_delay -clock write_dqs -min -0.065 [get_ports {ddr3_dq[*]}]
set_output_delay -clock write_dqs -max  0.294 -clock_fall -add_delay [get_ports {ddr3_dq[*]}]
set_output_delay -clock write_dqs -min -0.065 -clock_fall -add_delay [get_ports {ddr3_dq[*]}]

# ---- DQ Input Timing (Read) ----
# Tco max = 0.3 ns, Board delay variation = 0.1 ns
set_input_delay -clock read_dqs -max 0.4 [get_ports {ddr3_dq[*]}]
set_input_delay -clock read_dqs -min 0.1 [get_ports {ddr3_dq[*]}]
set_input_delay -clock read_dqs -max 0.4 -clock_fall -add_delay [get_ports {ddr3_dq[*]}]
set_input_delay -clock read_dqs -min 0.1 -clock_fall -add_delay [get_ports {ddr3_dq[*]}]

# ---- Address/Command Bus ----
# These are SDR (single data rate), clocked on rising edge only
set_output_delay -clock mem_refclk -max 1.0 \
    [get_ports {ddr3_addr[*] ddr3_ba[*] ddr3_cas_n ddr3_ras_n ddr3_we_n ddr3_cs_n ddr3_cke ddr3_odt}]
set_output_delay -clock mem_refclk -min 0.2 \
    [get_ports {ddr3_addr[*] ddr3_ba[*] ddr3_cas_n ddr3_ras_n ddr3_we_n ddr3_cs_n ddr3_cke ddr3_odt}]
```

### Example D: Ethernet RGMII Interface

```tcl
# ============================================================================
# RGMII Ethernet Interface - SDC Constraints
# ============================================================================

# ---- System Clock ----
create_clock -name sys_clk -period 8.000 [get_ports sys_clk_125]

# ---- RGMII RX Clock (from PHY) ----
create_clock -name rgmii_rx_clk -period 8.000 [get_ports eth_rx_clk]

# ---- RGMII TX Clock (to PHY) ----
# Generated from system clock, 90-degree phase shifted
create_generated_clock -name rgmii_tx_clk \
    -source [get_ports sys_clk_125] \
    -phase 90 \
    [get_ports eth_tx_clk]

# ---- RX Data (DDR on rx_clk) ----
set_input_delay -clock rgmii_rx_clk -max 1.4 [get_ports {eth_rxd[*] eth_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min 0.6 [get_ports {eth_rxd[*] eth_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -max 1.4 -clock_fall -add_delay [get_ports {eth_rxd[*] eth_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min 0.6 -clock_fall -add_delay [get_ports {eth_rxd[*] eth_rx_ctl}]

# ---- TX Data (DDR on tx_clk) ----
# PHY Tsu = 1.0 ns, Th = 1.0 ns for RGMII
set_output_delay -clock rgmii_tx_clk -max 1.0 [get_ports {eth_txd[*] eth_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -min -1.0 [get_ports {eth_txd[*] eth_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -max 1.0 -clock_fall -add_delay [get_ports {eth_txd[*] eth_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -min -1.0 -clock_fall -add_delay [get_ports {eth_txd[*] eth_tx_ctl}]

# ---- Clock Domain Crossings ----
set_clock_groups -asynchronous \
    -group {sys_clk rgmii_tx_clk} \
    -group {rgmii_rx_clk}

# ---- MDIO (Management Interface - slow) ----
set_false_path -to   [get_ports {eth_mdc eth_mdio}]
set_false_path -from [get_ports {eth_mdio}]
```

### Example E: Multi-Clock Design with Clock Mux and Multicycle Paths

```tcl
# ============================================================================
# Complex Multi-Clock Design - SDC Constraints
# Target: Altera MAX 10
# ============================================================================

# ---- Primary Clocks ----
create_clock -name osc_clk    -period 20.000 [get_ports clk_50mhz]
create_clock -name ext_clk    -period 33.333 [get_ports clk_30mhz]

# ---- PLL Outputs ----
derive_pll_clocks
derive_clock_uncertainty

# After PLL derivation (100 MHz core, 25 MHz peripheral, 10 MHz slow):
set core_clk_name  "u_pll|*|clk[0]"  ;# 100 MHz
set peri_clk_name  "u_pll|*|clk[1]"  ;# 25 MHz
set slow_clk_name  "u_pll|*|clk[2]"  ;# 10 MHz

# ---- Clock Groups ----
# PLL outputs are synchronous to each other (same source)
# but async to ext_clk
set_clock_groups -asynchronous \
    -group [get_clocks "$core_clk_name $peri_clk_name $slow_clk_name"] \
    -group [get_clocks ext_clk]

# ---- Multicycle: Core -> Peripheral Bus ----
# The peripheral bus bridge holds data for 4 core clock cycles
set_multicycle_path 4 -setup -end \
    -from [get_clocks $core_clk_name] \
    -to   [get_clocks $peri_clk_name]
set_multicycle_path 3 -hold -end \
    -from [get_clocks $core_clk_name] \
    -to   [get_clocks $peri_clk_name]

# ---- Multicycle: Slow Control Registers ----
# Software-written config registers are stable for many cycles
set_multicycle_path 10 -setup -from [get_registers {u_ctrl|config_reg[*]}]
set_multicycle_path  9 -hold  -from [get_registers {u_ctrl|config_reg[*]}]

# ---- False Paths ----
set_false_path -from [get_ports {rst_n dip_sw[*]}]
set_false_path -to   [get_ports {led[*] seg7[*]}]

# ---- I/O Constraints ----
# GPIO pins on peripheral bus clock
set_input_delay  -clock $peri_clk_name -max 8.0 [get_ports {gpio_in[*]}]
set_input_delay  -clock $peri_clk_name -min 2.0 [get_ports {gpio_in[*]}]
set_output_delay -clock $peri_clk_name -max 8.0 [get_ports {gpio_out[*]}]
set_output_delay -clock $peri_clk_name -min 1.0 [get_ports {gpio_out[*]}]

# External bus on ext_clk
set_input_delay  -clock ext_clk -max 12.0 [get_ports {ext_data[*]}]
set_input_delay  -clock ext_clk -min 3.0  [get_ports {ext_data[*]}]
set_output_delay -clock ext_clk -max 10.0 [get_ports {ext_data[*]}]
set_output_delay -clock ext_clk -min 2.0  [get_ports {ext_data[*]}]
```

---

## 12. Common Pitfalls and Best Practices

### Pitfalls to Avoid

#### 1. Missing Clock Constraints

**Problem:** Not constraining all clocks leaves register-to-register paths unchecked.

```tcl
# BAD: Only constraining the main clock, forgetting the JTAG clock
create_clock -name sys_clk -period 10.0 [get_ports clk]
# JTAG clock (altera_reserved_tck) is left unconstrained!
```

**Fix:** Always run `check_timing` and `report_ucd` to find unconstrained paths.

#### 2. Over-constraining with False Paths

**Problem:** False-pathing entire clock domains when only specific signals need it.

```tcl
# BAD: This hides all timing issues between these domains
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# BETTER: Only false-path the specific CDC synchronizer inputs
set_false_path -to [get_registers {u_sync|meta_reg[*]}]
```

#### 3. Forgetting Hold Multicycle Companion

**Problem:** Setting a multicycle setup path without adjusting the hold check.

```tcl
# INCOMPLETE: Hold check is now at the wrong edge
set_multicycle_path 3 -setup -from [get_registers src] -to [get_registers dst]

# COMPLETE: Hold check moved back to align with launch edge
set_multicycle_path 3 -setup -from [get_registers src] -to [get_registers dst]
set_multicycle_path 2 -hold  -from [get_registers src] -to [get_registers dst]
```

#### 4. Incorrect Input/Output Delay Calculations

**Problem:** Using only board delay and forgetting the external device's Tco or Tsu.

```tcl
# WRONG: Only accounts for board delay
set_input_delay -clock sys_clk -max 1.0 [get_ports data_in]

# CORRECT: Board delay + external Tco
set_input_delay -clock sys_clk -max 4.5 [get_ports data_in]
# 4.5 = 1.0 (board) + 3.5 (external device Tco)
```

#### 5. Not Using derive_clock_uncertainty

**Problem:** Ignoring jitter and uncertainty leads to overly optimistic timing.

```tcl
# Always include:
derive_clock_uncertainty
```

### Best Practices

#### 1. Organize SDC Files by Function

```
constraints/
  clocks.sdc       # Clock definitions and PLL constraints
  io.sdc           # Input/output delay constraints
  exceptions.sdc   # False paths, multicycle paths
  cdc.sdc          # Clock domain crossing constraints
```

#### 2. Always Start with These Commands

```tcl
derive_pll_clocks
derive_clock_uncertainty
```

#### 3. Use Meaningful Clock Names

```tcl
# GOOD
create_clock -name cpu_clk_100mhz    -period 10.0 [get_ports clk_cpu]
create_clock -name ddr3_refclk_200mhz -period 5.0  [get_ports clk_ddr]

# BAD
create_clock -name clk1 -period 10.0 [get_ports clk_cpu]
create_clock -name clk2 -period 5.0  [get_ports clk_ddr]
```

#### 4. Validate with check_timing

After applying all constraints, always verify:

```tcl
check_timing
```

This reports:
- Unconstrained clocks
- Unconstrained I/O ports
- Unconstrained register-to-register paths
- Latches without timing constraints

#### 5. Use Variables for Repetitive Values

```tcl
set BOARD_DELAY_MAX 1.5
set BOARD_DELAY_MIN 0.8
set EXT_TCO_MAX    3.2
set EXT_TCO_MIN    1.5

set_input_delay -clock sys_clk \
    -max [expr {$BOARD_DELAY_MAX + $EXT_TCO_MAX}] \
    [get_ports {data_bus[*]}]
set_input_delay -clock sys_clk \
    -min [expr {$BOARD_DELAY_MIN + $EXT_TCO_MIN}] \
    [get_ports {data_bus[*]}]
```

#### 6. Document Your Constraints

```tcl
# ------------------------------------------------------------
# SPI Flash Interface Constraints
# Device: Micron N25Q128 (see datasheet Table 17)
#   Tco (max) = 8 ns at 3.3V
#   Tsu       = 3 ns
#   Th        = 2 ns
# Board trace delay: 0.8 - 1.2 ns (from PCB SI analysis)
# ------------------------------------------------------------
set_input_delay  -clock spi_clk -max 9.2 [get_ports spi_miso]
set_output_delay -clock spi_clk -max 4.2 [get_ports spi_mosi]
```

#### 7. Handle JTAG Clock

Quartus provides a built-in JTAG clock. Constrain it:

```tcl
create_clock -name jtag_tck -period 100.000 [get_ports altera_reserved_tck]
set_clock_groups -asynchronous -group {jtag_tck} -group {sys_clk}
```

Or use the Altera-provided constraint:

```tcl
set_false_path -from [get_ports altera_reserved_tck]
set_false_path -to   [get_ports altera_reserved_tms]
set_false_path -to   [get_ports altera_reserved_tdo]
set_false_path -from [get_ports altera_reserved_tdi]
```

---

## 13. Quick Reference

### SDC Command Summary

| Command | Purpose |
|---|---|
| `create_clock` | Define a primary clock |
| `create_generated_clock` | Define a clock derived from another clock |
| `derive_pll_clocks` | Auto-create constraints for Altera PLL outputs |
| `derive_clock_uncertainty` | Auto-derive jitter-based uncertainty |
| `set_input_delay` | Constrain data arrival time at input ports |
| `set_output_delay` | Constrain data departure time at output ports |
| `set_false_path` | Exclude a path from timing analysis |
| `set_multicycle_path` | Allow multiple cycles for a path |
| `set_max_delay` | Set explicit maximum delay for a path |
| `set_min_delay` | Set explicit minimum delay for a path |
| `set_clock_groups` | Define clock domain relationships |
| `set_clock_latency` | Specify clock network delay |
| `set_clock_uncertainty` | Specify clock jitter/uncertainty |
| `set_max_skew` | Constrain signal skew |

### Design Object Accessors

| Command | Returns |
|---|---|
| `get_ports` | Top-level I/O ports |
| `get_pins` | Instance pins (hierarchical) |
| `get_registers` | Register/flip-flop nodes |
| `get_cells` | Design instances |
| `get_clocks` | Clock objects |
| `get_nets` | Net objects |

### TimeQuest Reporting Commands

| Command | Reports |
|---|---|
| `report_clocks` | All defined clocks |
| `report_timing` | Setup/hold timing paths |
| `report_ucd` | Unconstrained paths |
| `report_min_pulse_width` | Clock pulse width violations |
| `report_clock_transfers` | Clock domain crossings |
| `check_timing` | Constraint completeness |

### Formula Reference

```
Setup Slack  = (Latch Edge + Tclk_dest - Tsu - Uncertainty) - (Launch Edge + Tclk_src + Tco + Tdata)

Hold Slack   = (Launch Edge + Tclk_src + Tco + Tdata) - (Latch Edge + Tclk_dest + Th)

Input Delay  = External_Tco + Board_Trace_Delay

Output Delay (max) = Board_Trace_Delay + External_Tsu
Output Delay (min) = -(Board_Trace_Delay) + External_Th

Multicycle Hold Companion = Setup_Multiplier - 1
```

---

## Appendix: Altera Device Family Notes

| Device Family | Timing Analyzer | Notes |
|---|---|---|
| Cyclone IV | TimeQuest | Use `derive_pll_clocks` for `altpll` |
| Cyclone V | TimeQuest | Supports `altera_pll` and `altpll` |
| Cyclone 10 LP | TimeQuest | Similar to Cyclone IV flow |
| Cyclone 10 GX | Timing Analyzer | Quartus Prime Pro edition |
| Arria 10 | Timing Analyzer | Pro edition; uses Intel SDC extensions |
| Stratix V | TimeQuest | Supports fractional PLL constraints |
| Agilex | Timing Analyzer | Pro edition; latest Intel flow |
| MAX 10 | TimeQuest | Similar to Cyclone V |

For Quartus Prime **Pro** edition devices (Arria 10, Stratix 10, Agilex), some SDC commands have been extended. Always consult the *Intel Quartus Prime Pro Edition User Guide: Timing Analyzer* for device-specific differences.

---

*This tutorial covers the essential and advanced aspects of SDC-based timing constraints for Altera (Intel) FPGAs. For production designs, always validate your constraints against hardware measurements and consult the specific device datasheet for accurate timing parameters.*
