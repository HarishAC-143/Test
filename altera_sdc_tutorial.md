# Altera FPGA Static Timing Analysis (SDC) - Comprehensive Tutorial

## Table of Contents

1. [Introduction to Static Timing Analysis](#1-introduction-to-static-timing-analysis)
2. [SDC Fundamentals](#2-sdc-fundamentals)
3. [Clock Constraints](#3-clock-constraints)
4. [I/O Timing Constraints](#4-io-timing-constraints)
5. [Timing Exceptions](#5-timing-exceptions)
6. [Clock Groups and Relationships](#6-clock-groups-and-relationships)
7. [Intel (Altera) Specific SDC Commands](#7-intel-altera-specific-sdc-commands)
8. [TimeQuest Timing Analyzer](#8-timequest-timing-analyzer)
9. [Practical Design Examples](#9-practical-design-examples)
10. [Debugging Timing Failures](#10-debugging-timing-failures)
11. [Best Practices and Common Pitfalls](#11-best-practices-and-common-pitfalls)
12. [Quick Reference](#12-quick-reference)

---

## 1. Introduction to Static Timing Analysis

### What Is Static Timing Analysis (STA)?

Static Timing Analysis is a method of verifying timing performance of a digital circuit **without simulation**. Unlike dynamic timing analysis (simulation with test vectors), STA exhaustively checks **every** timing path in the design to ensure that all timing requirements are met.

STA works by:
- Calculating the **arrival time** of signals at every node
- Comparing arrival times against **required times** (constraints)
- Reporting **slack** (the margin between required and actual timing)

```
Slack = Required Time - Arrival Time

Positive slack  -> Timing is met (the path has margin)
Zero slack      -> Timing is exactly met (no margin)
Negative slack  -> Timing violation (the path is too slow)
```

### What Are SDC Files?

**Synopsys Design Constraints (SDC)** is an industry-standard format (based on Tcl) used to specify timing constraints for digital designs. Originally developed by Synopsys for their tools, SDC has become the universal language for timing constraints across all major FPGA and ASIC tools.

In the Altera/Intel FPGA flow, SDC files are consumed by the **TimeQuest Timing Analyzer** (now called the **Timing Analyzer** in Intel Quartus Prime).

### Why Are SDC Constraints Critical?

Without proper SDC constraints, the Fitter (place-and-route tool) has no timing goals to optimize for. This leads to:

- Random placement with no timing awareness
- Clock frequencies that may not meet your requirements
- I/O timing that doesn't match your board-level interconnect
- Metastability risks from unhandled clock domain crossings

**Rule of thumb**: An unconstrained design is an unverifiable design.

### STA Terminology

| Term | Definition |
|------|-----------|
| **Setup time (Tsu)** | Minimum time data must be stable *before* the clock edge |
| **Hold time (Th)** | Minimum time data must be stable *after* the clock edge |
| **Clock-to-output (Tco)** | Delay from the clock edge to valid data at the output |
| **Propagation delay (Tpd)** | Combinational delay from input to output (no register) |
| **Slack** | Timing margin: `Required Time - Arrival Time` |
| **Launch edge** | The clock edge that sends (launches) data |
| **Latch edge** | The clock edge that captures (latches) data |
| **Clock skew** | Difference in clock arrival time between source and destination registers |
| **Clock uncertainty** | Additional timing margin to account for jitter, skew, etc. |
| **Recovery time** | Like setup time, but for asynchronous control signals (reset, set) |
| **Removal time** | Like hold time, but for asynchronous control signals |

### How STA Calculates Timing

**Setup Check (max delay analysis):**

```
Data Arrival Time = Launch Edge + Clk-to-Source-Reg + Tcq + Combinational Delay
Data Required Time = Latch Edge + Clk-to-Dest-Reg - Tsu - Clock Uncertainty

Setup Slack = Data Required Time - Data Arrival Time
```

**Hold Check (min delay analysis):**

```
Data Arrival Time = Launch Edge + Clk-to-Source-Reg + Tcq(min) + Combinational Delay(min)
Data Required Time = Latch Edge + Clk-to-Dest-Reg + Th + Clock Uncertainty

Hold Slack = Data Arrival Time - Data Required Time
```

---

## 2. SDC Fundamentals

### SDC File Structure

SDC files are Tcl scripts. They are processed **sequentially** from top to bottom. Order matters because later commands can override earlier ones.

A well-organized SDC file follows this structure:

```tcl
# ============================================================
# 1. Clock Definitions
# ============================================================
create_clock ...
create_generated_clock ...

# ============================================================
# 2. Clock Uncertainty and Latency
# ============================================================
set_clock_uncertainty ...
set_clock_latency ...

# ============================================================
# 3. Clock Groups
# ============================================================
set_clock_groups ...

# ============================================================
# 4. Input/Output Delays
# ============================================================
set_input_delay ...
set_output_delay ...

# ============================================================
# 5. Timing Exceptions
# ============================================================
set_false_path ...
set_multicycle_path ...
set_max_delay ...
set_min_delay ...

# ============================================================
# 6. Design-Specific Constraints
# ============================================================
# (Any additional constraints)
```

### Tcl Basics for SDC

SDC is built on Tcl, so you can use variables, expressions, and Tcl constructs:

```tcl
# Variables
set CLK_PERIOD 10.0
set CLK_FREQ   [expr {1000.0 / $CLK_PERIOD}]

# Arithmetic
set HALF_PERIOD [expr {$CLK_PERIOD / 2.0}]

# String operations and collections
set all_clocks [get_clocks *]

# Conditional logic (use sparingly in SDC)
if {[get_collection_size [get_clocks -quiet sys_clk]] > 0} {
    set_clock_uncertainty -setup 0.1 [get_clocks sys_clk]
}

# Iterating over collections
foreach_in_collection clk [get_clocks *] {
    set clk_name [get_clock_info -name $clk]
    puts "Found clock: $clk_name"
}
```

### Object Access Commands (get_*)

These commands return **collections** of design objects. They are the foundation for targeting constraints:

| Command | Returns |
|---------|---------|
| `get_ports` | Top-level I/O ports |
| `get_pins` | Register/cell pins |
| `get_cells` | Design instances (cells) |
| `get_clocks` | Defined clock objects |
| `get_nets` | Nets (wires) |
| `get_registers` | Registers (Altera extension) |

**Wildcards:**
- `*` matches any number of characters
- `?` matches exactly one character

```tcl
get_ports clk              ;# Exact port named "clk"
get_ports clk*             ;# All ports starting with "clk"
get_ports {data[*]}        ;# Bus port: data[0], data[1], ...
get_pins  */D              ;# All D-input pins of any cell
get_pins  reg_*/CLK        ;# CLK pins of cells starting with "reg_"
get_registers {cpu|alu|*}  ;# Registers in the cpu|alu hierarchy
```

---

## 3. Clock Constraints

Clock constraints are the most critical part of any SDC file. Without them, the tool cannot perform timing analysis.

### 3.1 create_clock

Defines a **primary clock** entering the FPGA (typically from an oscillator or external source).

**Syntax:**

```tcl
create_clock -name <clock_name> -period <period_ns> [-waveform {<rise> <fall>}] <source>
```

**Parameters:**
- `-name`: Name for the clock object (optional but recommended)
- `-period`: Clock period in nanoseconds
- `-waveform`: Rise and fall times in ns (default: `{0 half_period}`)
- `<source>`: The port or pin where the clock enters

**Examples:**

```tcl
# 100 MHz clock on port CLK (50% duty cycle, default waveform)
create_clock -name sys_clk -period 10.0 [get_ports CLK]

# 50 MHz clock with explicit 50% duty cycle waveform
create_clock -name slow_clk -period 20.0 -waveform {0.0 10.0} [get_ports CLK_50M]

# 156.25 MHz Ethernet reference clock
create_clock -name eth_refclk -period 6.4 [get_ports ETH_REFCLK]

# 25 MHz clock with 60/40 duty cycle
create_clock -name asym_clk -period 40.0 -waveform {0.0 24.0} [get_ports CLK_ASYM]

# Virtual clock (no physical port, used for I/O timing)
create_clock -name virt_clk -period 8.0
```

**Waveform diagram for `create_clock -period 10.0 -waveform {0 5}`:**

```
        ___________             ___________
       |           |           |           |
_______|           |___________|           |________
       0     5     10    15    20    25    30  (ns)
       ^rise       ^rise       ^rise
              ^fall        ^fall
```

**Waveform for `create_clock -period 10.0 -waveform {2 7}` (phase-shifted):**

```
  ____       ___________       ___________
      |     |           |     |           |
      |_____|           |_____|           |_
  0   2     7    12    17    22    27    (ns)
      ^rise             ^rise
            ^fall              ^fall
```

### 3.2 create_generated_clock

Defines a clock that is **derived** from an existing clock through logic (dividers, multiplexers, PLLs, etc.).

**Syntax:**

```tcl
create_generated_clock -name <name> -source <master_pin> \
    [-divide_by <N> | -multiply_by <N> | -edges {<e1> <e2> <e3>}] \
    [-duty_cycle <percent>] [-phase <degrees>] \
    <target>
```

**Examples:**

```tcl
# Clock divider: divide sys_clk by 2 (register output)
create_generated_clock -name clk_div2 \
    -source [get_ports CLK] \
    -divide_by 2 \
    [get_pins clk_divider|clk_out]

# Clock divider by 4
create_generated_clock -name clk_div4 \
    -source [get_pins clk_divider|clk_out] \
    -divide_by 4 \
    [get_pins clk_divider_stage2|clk_out]

# Clock multiplier (PLL output, conceptual)
create_generated_clock -name clk_x3 \
    -source [get_ports CLK] \
    -multiply_by 3 \
    [get_pins pll_inst|outclk0]

# Edge specification: pick edges 1,3,5 of master -> divide by 2
# Edges are numbered: 1(rise), 2(fall), 3(rise), 4(fall), ...
create_generated_clock -name clk_div2_edges \
    -source [get_ports CLK] \
    -edges {1 3 5} \
    [get_pins divider_reg|Q]

# Edge specification: non-50% duty cycle divider
# Edges 1,2,5 from a 10ns master: rise@0, fall@5, rise@20
# Result: 20ns period, 25% duty high
create_generated_clock -name clk_asym \
    -source [get_ports CLK] \
    -edges {1 2 5} \
    [get_pins asym_divider|Q]

# MUX-selected clock (one generated clock per mux output possibility)
create_generated_clock -name mux_clk_a \
    -source [get_ports CLK_A] \
    -combinational \
    [get_pins clk_mux|Y]

create_generated_clock -name mux_clk_b \
    -source [get_ports CLK_B] \
    -combinational \
    -add \
    [get_pins clk_mux|Y]
```

### 3.3 PLL Clock Constraints (Altera Specific)

When using Altera PLLs (ALTPLL, Altera PLL IP), Quartus can **automatically** derive generated clocks from the PLL configuration. However, you still need to constrain the PLL input clock.

```tcl
# Step 1: Constrain the PLL input clock
create_clock -name pll_refclk -period 20.0 [get_ports CLK_50M]

# Step 2: Let Quartus auto-derive PLL output clocks
# (This happens automatically if you use "derive_pll_clocks")
derive_pll_clocks

# Alternatively, manually define PLL outputs:
create_generated_clock -name pll_clk_100m \
    -source [get_pins pll_inst|inclk[0]] \
    -multiply_by 2 \
    [get_pins pll_inst|clk[0]]

create_generated_clock -name pll_clk_200m \
    -source [get_pins pll_inst|inclk[0]] \
    -multiply_by 4 \
    [get_pins pll_inst|clk[1]]

create_generated_clock -name pll_clk_25m \
    -source [get_pins pll_inst|inclk[0]] \
    -divide_by 2 \
    [get_pins pll_inst|clk[2]]
```

### 3.4 Clock Uncertainty

Adds timing margin to account for clock jitter, inter-clock skew, and board-level uncertainty.

```tcl
# Apply setup uncertainty of 200ps to all clocks
set_clock_uncertainty -setup 0.200 [get_clocks *]

# Apply hold uncertainty of 50ps to all clocks
set_clock_uncertainty -hold 0.050 [get_clocks *]

# Inter-clock uncertainty between two domains
set_clock_uncertainty -setup -from [get_clocks clk_a] -to [get_clocks clk_b] 0.300

# Automatic clock uncertainty derivation (Altera-specific)
derive_clock_uncertainty
```

`derive_clock_uncertainty` is highly recommended in Altera designs. It automatically computes appropriate uncertainty values based on the device's PLL characteristics and clock network properties.

### 3.5 Clock Latency

Specifies clock network delay. This is used when the clock has known delay not modeled by the tool.

```tcl
# Source latency: delay before the clock reaches the FPGA pin
set_clock_latency -source -early 0.5 [get_clocks sys_clk]
set_clock_latency -source -late  0.8 [get_clocks sys_clk]

# Network latency: delay within the FPGA clock network
# (Rarely needed for FPGAs since the tool models this automatically)
set_clock_latency 0.3 [get_clocks sys_clk]
```

---

## 4. I/O Timing Constraints

I/O constraints tell the timing analyzer about the timing relationship between your FPGA and external devices on the board.

### 4.1 set_input_delay

Specifies how late data can arrive at an FPGA input pin **after** the clock edge.

**Concept:**

```
                Board Trace
External FF  ───────────────>  FPGA Input Pin
    |                               |
    Tco + board_delay               |
    = input_delay                   |
```

**Syntax:**

```tcl
set_input_delay -clock <ref_clock> [-max|-min] <delay_ns> [get_ports <port>]
```

**System-Synchronous Input (Source and FPGA share same clock):**

```
           External Device                    FPGA
          ┌──────────────┐              ┌──────────────┐
 CLK ────>│  Tco_ext     │──Tboard────>│  Tsu_fpga    │
          │  (source FF) │   (trace)   │  (dest FF)   │
          └──────────────┘              └──────────────┘

 input_delay_max = Tco_ext_max + Tboard_max
 input_delay_min = Tco_ext_min + Tboard_min
```

```tcl
# External device: Tco_max = 5ns, Tboard_max = 0.5ns
# External device: Tco_min = 2ns, Tboard_min = 0.3ns
set_input_delay -clock sys_clk -max 5.5 [get_ports {data_in[*]}]
set_input_delay -clock sys_clk -min 2.3 [get_ports {data_in[*]}]
```

**Source-Synchronous Input (Clock co-routed with data):**

In source-synchronous interfaces, the clock travels with the data. The input_delay reflects the skew between clock and data.

```
           External Device                       FPGA
          ┌──────────────┐                 ┌──────────────┐
          │              │──Data──Tbd────>│              │
          │  Source      │                 │  Dest FF     │
          │              │──Clock─Tbc────>│              │
          └──────────────┘                 └──────────────┘

 input_delay_max = Tco_max + (Tbd_max - Tbc_min)
 input_delay_min = Tco_min + (Tbd_min - Tbc_max)
```

```tcl
# Source-synchronous DDR input (e.g., RGMII)
create_clock -name rx_clk -period 8.0 [get_ports RGMII_RX_CLK]

# Rising edge data
set_input_delay -clock rx_clk -max  0.5 [get_ports {rgmii_rxd[*]}]
set_input_delay -clock rx_clk -min -0.5 [get_ports {rgmii_rxd[*]}]

# Falling edge data (DDR)
set_input_delay -clock rx_clk -max  0.5 -clock_fall -add_delay [get_ports {rgmii_rxd[*]}]
set_input_delay -clock rx_clk -min -0.5 -clock_fall -add_delay [get_ports {rgmii_rxd[*]}]
```

### 4.2 set_output_delay

Specifies how much time the external device needs **after** the clock edge. This tells the FPGA how early data must depart.

**Concept:**

```
           FPGA                          External Device
          ┌──────────────┐              ┌──────────────┐
 CLK ────>│  Source FF   │──Tboard────>│  Tsu_ext     │
          │  Tco_fpga    │   (trace)   │  (dest FF)   │
          └──────────────┘              └──────────────┘

 output_delay_max = Tsu_ext + Tboard_max
 output_delay_min = -(Th_ext - Tboard_min)
     or equivalently:
 output_delay_min = Tboard_min - Th_ext
```

```tcl
# External device: Tsu = 2ns, Th = 1ns, Tboard = 0.3ns to 0.5ns
set_output_delay -clock sys_clk -max 2.5 [get_ports {data_out[*]}]
set_output_delay -clock sys_clk -min -0.7 [get_ports {data_out[*]}]
```

**Source-Synchronous Output (FPGA generates clock and data):**

```tcl
# FPGA generates a forwarded clock alongside data
create_generated_clock -name tx_clk \
    -source [get_pins pll_inst|clk[0]] \
    [get_ports TX_CLK]

# Output delay relative to the forwarded clock
set_output_delay -clock tx_clk -max  1.0 [get_ports {tx_data[*]}]
set_output_delay -clock tx_clk -min -0.5 [get_ports {tx_data[*]}]

# DDR outputs (both clock edges)
set_output_delay -clock tx_clk -max  1.0 [get_ports {ddr_out[*]}]
set_output_delay -clock tx_clk -min -0.5 [get_ports {ddr_out[*]}]
set_output_delay -clock tx_clk -max  1.0 -clock_fall -add_delay [get_ports {ddr_out[*]}]
set_output_delay -clock tx_clk -min -0.5 -clock_fall -add_delay [get_ports {ddr_out[*]}]
```

### 4.3 Virtual Clocks for I/O Timing

When the FPGA does not directly receive the reference clock for an interface, use a **virtual clock** (a clock with no physical port).

```tcl
# Virtual clock representing the external device's clock
create_clock -name virt_ext_clk -period 10.0

# Use the virtual clock for I/O constraints
set_input_delay  -clock virt_ext_clk -max 6.0 [get_ports {ext_data_in[*]}]
set_input_delay  -clock virt_ext_clk -min 2.0 [get_ports {ext_data_in[*]}]
set_output_delay -clock virt_ext_clk -max 3.0 [get_ports {ext_data_out[*]}]
set_output_delay -clock virt_ext_clk -min -1.0 [get_ports {ext_data_out[*]}]
```

---

## 5. Timing Exceptions

Timing exceptions modify the default timing analysis for specific paths. They are essential for handling asynchronous crossings, multicycle operations, and paths that don't need full-speed timing.

### 5.1 set_false_path

Declares that a path should **not be timed at all**. Use sparingly and only for truly asynchronous or non-functional paths.

```tcl
# Between two asynchronous clock domains
# (Only if you have proper synchronizers in the RTL!)
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
set_false_path -from [get_clocks clk_b] -to [get_clocks clk_a]

# Reset signal (asynchronous, handled by reset synchronizer in RTL)
set_false_path -from [get_ports RESET_N]

# Static configuration registers (values don't change during operation)
set_false_path -from [get_registers {config_reg[*]}]

# Test/debug logic
set_false_path -to [get_ports {LED[*]}]
set_false_path -from [get_ports {DIP_SW[*]}]

# Specific register-to-register path
set_false_path -from [get_registers src_domain|data_reg*] \
               -to   [get_registers dst_domain|sync_reg*]
```

**When to use `set_false_path`:**
- Paths between truly unrelated clock domains (with synchronizers in RTL)
- Asynchronous reset/preset signals (with reset synchronizers)
- Static configuration signals that don't change during normal operation
- LED outputs, DIP switch inputs
- Test/debug paths

**When NOT to use `set_false_path`:**
- Between related clocks (e.g., a clock and its divided version) -- use `set_multicycle_path`
- To mask actual timing problems

### 5.2 set_multicycle_path

Tells the analyzer that a path has **more than one clock cycle** to propagate. This relaxes the setup check and optionally tightens/relaxes the hold check.

**Syntax:**

```tcl
set_multicycle_path <multiplier> [-setup|-hold] [-from <src>] [-to <dst>] [-start|-end]
```

Key concepts:
- `-setup N` moves the **latch edge** N-1 cycles later (more time for data)
- `-hold M` moves the **hold check launch edge** M cycles later
- `-end` (default for setup) references the destination clock
- `-start` references the source clock

**Common pattern for same-clock multicycle:**

```tcl
# 2-cycle path: data takes 2 clock cycles to propagate
set_multicycle_path 2 -setup -from [get_registers slow_calc|*] -to [get_registers slow_calc|result*]
set_multicycle_path 1 -hold  -from [get_registers slow_calc|*] -to [get_registers slow_calc|result*]
```

The hold adjustment is almost always needed alongside the setup multicycle. Without it, the hold check references the wrong launch edge.

**Timing diagram for multicycle path (MCP=2):**

```
Without MCP:
Launch Edge    Latch Edge
    |              |
    v              v
    ───────────────
    |   1 cycle   |

With MCP=2 (setup):
Launch Edge              Latch Edge
    |                        |
    v                        v
    ─────────────────────────
    |       2 cycles        |

With MCP=1 (hold), moves hold check:
         Hold Check Here
              |
              v
    ──────────
Launch Edge
```

**Cross-domain multicycle (different frequency clocks):**

```tcl
# Fast (200MHz) to slow (100MHz) domain, 2 slow cycles
set_multicycle_path 2 -setup -end \
    -from [get_clocks clk_200m] -to [get_clocks clk_100m]
set_multicycle_path 1 -hold -end \
    -from [get_clocks clk_200m] -to [get_clocks clk_100m]

# Slow to fast domain, 2 fast cycles referenced from source
set_multicycle_path 2 -setup -start \
    -from [get_clocks clk_100m] -to [get_clocks clk_200m]
set_multicycle_path 1 -hold -start \
    -from [get_clocks clk_100m] -to [get_clocks clk_200m]
```

### 5.3 set_max_delay and set_min_delay

Sets an explicit maximum or minimum delay requirement on a path. Often used in combination with `set_false_path` removal for paths that need bounded (but not clock-referenced) timing.

```tcl
# Maximum delay constraint (e.g., for a CDC path with FIFO)
set_max_delay 5.0 -from [get_registers cdc_src|*] -to [get_registers cdc_dst|*]

# Minimum delay constraint
set_min_delay 1.0 -from [get_registers fast_path|*] -to [get_registers fast_path|out*]

# Datapath-only (ignore clock skew) - common for CDC paths
set_max_delay 10.0 -datapath_only \
    -from [get_registers domain_a|data*] \
    -to   [get_registers domain_b|sync_ff1*]
```

### 5.4 Priority of Timing Exceptions

When multiple exceptions apply to the same path, SDC has a **strict priority order**:

1. **`set_false_path`** (highest priority -- overrides everything)
2. **`set_max_delay` / `set_min_delay`**
3. **`set_multicycle_path`**
4. Default clock-based analysis (lowest)

Within the same exception type, **more specific** constraints override **less specific** ones:
- `-from X -to Y` overrides `-from X`
- `-from X -through Z -to Y` overrides `-from X -to Y`

---

## 6. Clock Groups and Relationships

### 6.1 set_clock_groups

Declares that clocks in different groups are **unrelated** and should not be timed against each other. This is more efficient than individual `set_false_path` commands and is the preferred method.

**Syntax:**

```tcl
set_clock_groups -asynchronous|-exclusive \
    -group {<clk1> [<clk2> ...]} \
    -group {<clk3> [<clk4> ...]} \
    [-group ...]
```

- **`-asynchronous`**: Clocks exist simultaneously but are unrelated (different oscillators)
- **`-exclusive`**: Clocks never exist at the same time (mux-selected clocks)

```tcl
# Two independent clock domains
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks eth_clk]

# Multiple domains with PLL-derived clocks in each
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk pll_clk_100m pll_clk_200m}] \
    -group [get_clocks {eth_refclk eth_tx_clk eth_rx_clk}] \
    -group [get_clocks {usb_clk}]

# Mux-selected clocks (only one active at a time)
set_clock_groups -exclusive \
    -group [get_clocks mux_clk_a] \
    -group [get_clocks mux_clk_b]
```

### 6.2 Clock Relationship Diagram

```
    sys_clk (50 MHz, on-board oscillator)
        │
        ├── PLL ──> pll_100m (100 MHz)
        │       └──> pll_200m (200 MHz)
        │
        └── [ASYNCHRONOUS to all below]

    eth_refclk (125 MHz, PHY oscillator)
        │
        ├── PHY ──> eth_tx_clk (125 MHz)
        │       └──> eth_rx_clk (125 MHz)
        │
        └── [ASYNCHRONOUS to sys_clk group]

    usb_clk (48 MHz, USB PHY)
        └── [ASYNCHRONOUS to all above]
```

Corresponding SDC:

```tcl
create_clock -name sys_clk    -period 20.0 [get_ports CLK_50M]
create_clock -name eth_refclk -period  8.0 [get_ports ETH_REFCLK]
create_clock -name usb_clk    -period 20.833 [get_ports USB_CLK]

derive_pll_clocks

set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk pll_inst|*clk[0] pll_inst|*clk[1]}] \
    -group [get_clocks {eth_refclk eth_tx_clk eth_rx_clk}] \
    -group [get_clocks {usb_clk}]
```

---

## 7. Intel (Altera) Specific SDC Commands

Quartus extends standard SDC with several Altera-specific commands.

### 7.1 derive_pll_clocks

Automatically creates `create_generated_clock` constraints for all PLL outputs.

```tcl
derive_pll_clocks
```

This reads the PLL configuration from the design and generates the appropriate `create_generated_clock` commands. **Always call this after defining your PLL input clocks.**

### 7.2 derive_clock_uncertainty

Automatically computes setup and hold clock uncertainty based on device characteristics.

```tcl
derive_clock_uncertainty
```

This accounts for:
- PLL jitter characteristics
- Intra-clock and inter-clock skew
- Device-specific timing parameters

### 7.3 get_registers

Altera extension to access registers by hierarchical name. More convenient than `get_pins` for register-to-register constraints.

```tcl
# Access registers by hierarchy
get_registers {cpu_inst|alu|result_reg[*]}
get_registers {*|sync_ff[0]}
get_registers {fifo_inst|wr_ptr*}
```

### 7.4 set_instance_assignment (via SDC)

Some Altera-specific assignments can be made via SDC for timing purposes:

```tcl
# Apply global signal promotion
set_global_assignment -name GLOBAL_SIGNAL "GLOBAL CLOCK" -to clk

# Preserve registers for timing (prevent optimization)
set_instance_assignment -name PRESERVE_REGISTER ON -to sync_ff[*]
```

### 7.5 remove_clock / remove_clock_uncertainty

```tcl
# Remove a previously defined clock
remove_clock [get_clocks old_clock]

# Remove clock uncertainty
remove_clock_uncertainty [get_clocks sys_clk]
```

---

## 8. TimeQuest Timing Analyzer

### 8.1 Overview

The TimeQuest Timing Analyzer (now Timing Analyzer in Quartus Prime) is Intel's STA engine. It reads SDC constraints, analyzes the post-fit design, and reports timing results.

### 8.2 Analysis Flow

```
 ┌─────────────────┐
 │  Design Source   │ (Verilog/VHDL)
 └────────┬────────┘
          v
 ┌─────────────────┐
 │   Synthesis      │
 └────────┬────────┘
          v
 ┌─────────────────┐     ┌─────────────────┐
 │   Fitter (P&R)  │<────│   SDC File      │
 └────────┬────────┘     └─────────────────┘
          v
 ┌─────────────────┐     ┌─────────────────┐
 │ Timing Analyzer │<────│   SDC File      │
 └────────┬────────┘     └─────────────────┘
          v
 ┌─────────────────┐
 │ Timing Reports  │
 └─────────────────┘
```

### 8.3 Running Timing Analysis

**From Quartus GUI:**
1. Open your project
2. Go to **Tools > Timing Analyzer**
3. Select **Netlist > Create Timing Netlist**
4. Select **Netlist > Read SDC File** (or it loads automatically)
5. Select **Reports > Custom Reports > Report Timing...**

**From command line (quartus_sta):**

```bash
# Run full STA and generate reports
quartus_sta my_project --sdc=constraints.sdc

# Interactive Tcl console
quartus_sta -t my_timing_script.tcl
```

### 8.4 Timing Report Commands (Tcl Console)

```tcl
# Report setup timing for all clocks
report_timing -setup -npaths 20

# Report hold timing
report_timing -hold -npaths 20

# Report timing for a specific clock domain
report_timing -from_clock sys_clk -to_clock sys_clk -setup -npaths 10

# Report timing for specific paths
report_timing -from [get_registers src_reg*] -to [get_registers dst_reg*] -npaths 5

# Report clock networks
report_clocks

# Report clock transfers (domain crossings)
report_clock_transfers

# Report unconstrained paths (critical for constraint coverage)
report_ucd   ;# Unconstrained paths
check_timing  ;# Identify missing constraints

# Report minimum pulse width
report_min_pulse_width -npaths 20

# Report recovery/removal timing
report_timing -recovery -npaths 10
report_timing -removal -npaths 10
```

### 8.5 Reading a Timing Report

A typical TimeQuest timing report looks like:

```
Info: Timing requirements met
Info:
Info: ============================================================
Info: Slow 1100mV 85C Model Setup Summary
Info: ============================================================
Info: Clock           Required  Actual   Slack
Info: sys_clk         10.000    7.234    2.766
Info: pll_100m         5.000    4.812    0.188
Info: pll_200m         2.500    2.489    0.011  <-- Tight!
Info:
Info: ============================================================
Info: Slow 1100mV 85C Model Hold Summary
Info: ============================================================
Info: Clock           Required  Actual   Slack
Info: sys_clk          0.000    0.156    0.156
Info: pll_100m         0.000    0.089    0.089
Info: pll_200m         0.000    0.045    0.045
```

**Detailed path report:**

```
Data Arrival Path:
_______________________________________________________________________________
From Node     : src_module|data_reg[0]
To Node       : dst_module|result_reg[0]
Launch Clock  : sys_clk (Rise Edge)
Latch Clock   : sys_clk (Rise Edge)
_______________________________________________________________________________

Type           Incr(ns)  Path(ns)  Info
----------------------------------------------
clock network   0.000     0.000    sys_clk
launch edge     0.000     0.000
                1.234     1.234    clock network delay
Tcq             0.456     1.690    src_module|data_reg[0]
IC              0.789     2.479    interconnect
LUT             0.567     3.046    combinational logic
IC              0.234     3.280    interconnect
LUT             0.432     3.712    combinational logic
IC              0.123     3.835    interconnect
----------------------------------------------
Data Arrival   3.835

Data Required Path:
----------------------------------------------
clock network   0.000     0.000    sys_clk
latch edge     10.000    10.000
                1.345     11.345   clock network delay
uncertainty    -0.020     11.325
Tsu            -0.150     11.175
----------------------------------------------
Data Required  11.175

Slack = 11.175 - 3.835 = 7.340 (MET)
```

---

## 9. Practical Design Examples

### Example 1: Basic Single-Clock Design

**Scenario:** A simple data processing pipeline running at 100 MHz with external memory interface.

See [`examples/01_single_clock.sdc`](examples/01_single_clock.sdc) for the full file.

```tcl
# ============================================================
# Single-Clock Design: 100 MHz Data Processing Pipeline
# ============================================================

# Primary clock: 100 MHz
create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]

# Clock uncertainty
derive_clock_uncertainty

# --- Input Constraints ---
# External SRAM: Tco = 8ns max, 3ns min, board delay = 0.5ns
set_input_delay -clock sys_clk -max 8.5 [get_ports {sram_data[*]}]
set_input_delay -clock sys_clk -min 3.5 [get_ports {sram_data[*]}]

# Control inputs from another FPGA: Tco = 5ns max, 2ns min, board = 1ns
set_input_delay -clock sys_clk -max 6.0 [get_ports {ctrl_in[*]}]
set_input_delay -clock sys_clk -min 3.0 [get_ports {ctrl_in[*]}]

# --- Output Constraints ---
# External DAC: Tsu = 3ns, Th = 1.5ns, board = 0.5ns
set_output_delay -clock sys_clk -max 3.5 [get_ports {dac_data[*]}]
set_output_delay -clock sys_clk -min -1.0 [get_ports {dac_data[*]}]

# SRAM write data: Tsu = 2ns, Th = 1ns, board = 0.5ns
set_output_delay -clock sys_clk -max 2.5 [get_ports {sram_wr_data[*]}]
set_output_delay -clock sys_clk -min -0.5 [get_ports {sram_wr_data[*]}]
set_output_delay -clock sys_clk -max 2.5 [get_ports sram_we_n]
set_output_delay -clock sys_clk -min -0.5 [get_ports sram_we_n]

# --- Timing Exceptions ---
# Async reset
set_false_path -from [get_ports RST_N]

# LEDs and DIP switches (non-timing-critical)
set_false_path -to   [get_ports {LED[*]}]
set_false_path -from [get_ports {DIP_SW[*]}]
```

### Example 2: Multi-Clock Design with PLL

**Scenario:** A design using a PLL to generate multiple clock domains from a 50 MHz input.

See [`examples/02_multi_clock_pll.sdc`](examples/02_multi_clock_pll.sdc) for the full file.

```tcl
# ============================================================
# Multi-Clock PLL Design
# Board has 50 MHz oscillator, PLL generates 100/200/25 MHz
# ============================================================

# Primary clock input
create_clock -name clk_50m -period 20.0 [get_ports CLK_50M]

# Auto-derive PLL output clocks
derive_pll_clocks

# Auto-derive clock uncertainty
derive_clock_uncertainty

# Clock groups: PLL outputs are related (same source), 
# but external clocks are asynchronous
create_clock -name adc_clk -period 40.0 [get_ports ADC_CLK]

set_clock_groups -asynchronous \
    -group [get_clocks {clk_50m pll_inst|*clk[0] pll_inst|*clk[1] pll_inst|*clk[2]}] \
    -group [get_clocks adc_clk]

# I/O constraints for the 100 MHz domain
set_input_delay  -clock pll_inst|*clk[0] -max 3.0 [get_ports {fast_data_in[*]}]
set_input_delay  -clock pll_inst|*clk[0] -min 1.0 [get_ports {fast_data_in[*]}]
set_output_delay -clock pll_inst|*clk[0] -max 2.0 [get_ports {fast_data_out[*]}]
set_output_delay -clock pll_inst|*clk[0] -min -0.5 [get_ports {fast_data_out[*]}]

# I/O constraints for the 25 MHz domain
set_input_delay  -clock pll_inst|*clk[2] -max 10.0 [get_ports {slow_data_in[*]}]
set_input_delay  -clock pll_inst|*clk[2] -min  3.0 [get_ports {slow_data_in[*]}]

# ADC interface (using its own clock)
set_input_delay -clock adc_clk -max 15.0 [get_ports {adc_data[*]}]
set_input_delay -clock adc_clk -min  5.0 [get_ports {adc_data[*]}]

# Multicycle path: 200MHz to 100MHz data transfer (2 fast cycles)
set_multicycle_path 2 -setup -end \
    -from [get_clocks pll_inst|*clk[1]] \
    -to   [get_clocks pll_inst|*clk[0]]
set_multicycle_path 1 -hold -end \
    -from [get_clocks pll_inst|*clk[1]] \
    -to   [get_clocks pll_inst|*clk[0]]
```

### Example 3: Source-Synchronous DDR Interface (RGMII)

**Scenario:** RGMII Ethernet interface with DDR data at 125 MHz.

See [`examples/03_rgmii_interface.sdc`](examples/03_rgmii_interface.sdc) for the full file.

```tcl
# ============================================================
# RGMII Ethernet Interface (1000BASE-T, DDR at 125 MHz)
# ============================================================

# System clock
create_clock -name sys_clk -period 20.0 [get_ports CLK_50M]
derive_pll_clocks
derive_clock_uncertainty

# --- RX Path (PHY -> FPGA) ---
# RX clock from PHY (source-synchronous, center-aligned)
create_clock -name rgmii_rx_clk -period 8.0 [get_ports RGMII_RX_CLK]

# RGMII spec: data valid window centered on clock edge
# Skew budget: +/- 0.5ns
set_input_delay -clock rgmii_rx_clk -max  0.5 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min -0.5 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -max  0.5 -clock_fall -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min -0.5 -clock_fall -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]

# --- TX Path (FPGA -> PHY) ---
# TX clock generated by FPGA PLL, forwarded to PHY
create_generated_clock -name rgmii_tx_clk \
    -source [get_pins tx_pll|clk[0]] \
    [get_ports RGMII_TX_CLK]

# PHY RX requirements: Tsu = 1.0ns, Th = 1.0ns (relative to TX_CLK)
set_output_delay -clock rgmii_tx_clk -max  1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -min -1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -max  1.0 -clock_fall -add_delay [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_tx_clk -min -1.0 -clock_fall -add_delay [get_ports {rgmii_txd[*] rgmii_tx_ctl}]

# Clock groups
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk pll_inst|*}] \
    -group [get_clocks {rgmii_rx_clk}]
```

### Example 4: Clock Domain Crossing with FIFO

**Scenario:** Asynchronous FIFO between two unrelated clock domains.

See [`examples/04_cdc_fifo.sdc`](examples/04_cdc_fifo.sdc) for the full file.

```tcl
# ============================================================
# Clock Domain Crossing with Async FIFO
# Write domain: 100 MHz, Read domain: 133 MHz (unrelated)
# ============================================================

create_clock -name wr_clk -period 10.0  [get_ports WR_CLK]
create_clock -name rd_clk -period  7.519 [get_ports RD_CLK]

derive_clock_uncertainty

# Declare clocks as asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]

# Although we declared async groups, we want to constrain the
# gray-code pointer crossing paths for reliability.
# The synchronizer paths need a bounded max delay.

# Write pointer -> Read domain synchronizer (gray-coded)
set_max_delay 7.519 -datapath_only \
    -from [get_registers {async_fifo|wr_ptr_gray[*]}] \
    -to   [get_registers {async_fifo|rd_sync_ff1[*]}]

# Read pointer -> Write domain synchronizer (gray-coded)
set_max_delay 10.0 -datapath_only \
    -from [get_registers {async_fifo|rd_ptr_gray[*]}] \
    -to   [get_registers {async_fifo|wr_sync_ff1[*]}]
```

### Example 5: SDRAM/DDR Memory Interface

**Scenario:** External SDRAM interface with specific timing requirements.

See [`examples/05_sdram_interface.sdc`](examples/05_sdram_interface.sdc) for the full file.

```tcl
# ============================================================
# SDRAM Interface (133 MHz, CL2)
# ============================================================

# System clock for SDRAM controller
create_clock -name sys_clk -period 20.0 [get_ports CLK_50M]
derive_pll_clocks
derive_clock_uncertainty

# SDRAM clock (133 MHz from PLL, phase-shifted for board delay compensation)
# PLL output clk[0] = 133 MHz, 0 degrees   -> internal logic
# PLL output clk[1] = 133 MHz, -63 degrees -> forwarded to SDRAM
create_generated_clock -name sdram_clk \
    -source [get_pins sdram_pll|clk[1]] \
    [get_ports SDRAM_CLK]

# --- SDRAM Output Timing ---
# SDRAM chip: Tsu = 1.5ns, Th = 0.8ns
# Board trace delay: ~0.2ns each way
set_output_delay -clock sdram_clk -max  1.7  [get_ports {sdram_addr[*] sdram_ba[*] sdram_dqm[*]}]
set_output_delay -clock sdram_clk -min -0.6  [get_ports {sdram_addr[*] sdram_ba[*] sdram_dqm[*]}]
set_output_delay -clock sdram_clk -max  1.7  [get_ports {sdram_cs_n sdram_ras_n sdram_cas_n sdram_we_n sdram_cke}]
set_output_delay -clock sdram_clk -min -0.6  [get_ports {sdram_cs_n sdram_ras_n sdram_cas_n sdram_we_n sdram_cke}]

# --- SDRAM DQ Bidirectional ---
# Write path (FPGA -> SDRAM)
set_output_delay -clock sdram_clk -max  1.7  [get_ports {sdram_dq[*]}]
set_output_delay -clock sdram_clk -min -0.6  [get_ports {sdram_dq[*]}]

# Read path (SDRAM -> FPGA)
# SDRAM Tac (access time from clock) = 5.4ns max
# Board delay ~0.2ns each way = 0.4ns round trip
set_input_delay -clock sdram_clk -max 5.8 [get_ports {sdram_dq[*]}]
set_input_delay -clock sdram_clk -min 1.0 [get_ports {sdram_dq[*]}]

# Multicycle for SDRAM read data (CAS latency allows 2 cycles)
set_multicycle_path 2 -setup -end \
    -from [get_ports {sdram_dq[*]}] \
    -to   [get_registers {sdram_ctrl|rd_data*}]
set_multicycle_path 1 -hold -end \
    -from [get_ports {sdram_dq[*]}] \
    -to   [get_registers {sdram_ctrl|rd_data*}]
```

### Example 6: SPI Master Interface

**Scenario:** SPI master running at 25 MHz generated from a 100 MHz system clock.

See [`examples/06_spi_master.sdc`](examples/06_spi_master.sdc) for the full file.

```tcl
# ============================================================
# SPI Master Interface
# System clock: 100 MHz, SPI clock: 25 MHz (div-by-4)
# ============================================================

create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]
derive_clock_uncertainty

# SPI clock is generated by a counter in the FPGA
create_generated_clock -name spi_clk \
    -source [get_ports SYS_CLK] \
    -divide_by 4 \
    [get_ports SPI_SCLK]

# --- SPI Output Timing ---
# SPI slave device: Tsu = 5ns, Th = 5ns
# Board delay: 0.5ns
set_output_delay -clock spi_clk -max  5.5 [get_ports SPI_MOSI]
set_output_delay -clock spi_clk -min -4.5 [get_ports SPI_MOSI]
set_output_delay -clock spi_clk -max  5.5 [get_ports SPI_CS_N]
set_output_delay -clock spi_clk -min -4.5 [get_ports SPI_CS_N]

# --- SPI Input Timing ---
# SPI slave: data changes on SCLK falling edge, sampled on rising
# Slave Tco = 10ns max, 2ns min from falling SCLK
# Slave output valid for most of the period
set_input_delay -clock spi_clk -max 10.5 [get_ports SPI_MISO]
set_input_delay -clock spi_clk -min  2.5 [get_ports SPI_MISO]

# Multicycle: SPI operates at 1/4 system clock rate
# Internal logic runs at sys_clk but only samples once per SPI cycle
set_multicycle_path 4 -setup -from [get_ports SPI_MISO] -to [get_registers {spi_master|rx_shift*}]
set_multicycle_path 3 -hold  -from [get_ports SPI_MISO] -to [get_registers {spi_master|rx_shift*}]
```

---

## 10. Debugging Timing Failures

### 10.1 Common Causes of Timing Failures

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Negative setup slack on register-to-register path | Too much combinational logic | Pipeline the logic, reduce LUT depth |
| Negative hold slack | Clock skew, fast paths | The Fitter usually fixes hold; check clock tree |
| Unconstrained paths | Missing clock/IO constraints | Add missing constraints, run `check_timing` |
| Large negative slack on I/O | Wrong I/O delay values | Verify board-level timing budget |
| Cross-domain failures | Missing false_path or clock_groups | Add `set_clock_groups` or `set_false_path` |
| PLL output slack issues | Wrong/missing PLL constraints | Use `derive_pll_clocks` |

### 10.2 Diagnostic Commands

```tcl
# Find all unconstrained paths
check_timing

# Report unconstrained endpoints
report_ucd -summary

# List all defined clocks and their properties
report_clocks

# Report all clock domain crossings
report_clock_transfers -warn_on_mismatch

# Report the 20 worst setup paths
report_timing -setup -npaths 20 -detail full_path

# Report timing through a specific node
report_timing -through [get_nets bottleneck_net] -npaths 5

# Report timing for specific source/destination
report_timing \
    -from [get_registers problematic_src*] \
    -to   [get_registers problematic_dst*] \
    -setup -npaths 10 -detail full_path

# Report net fanout (high fanout can cause timing issues)
report_net_fanout -high_fanout

# Report path with physical information
report_timing -setup -npaths 5 -detail full_path -panel_name "Debug Paths"
```

### 10.3 Fixing Setup Violations

**Strategy 1: Pipeline the critical path**

```
Before (fails timing at 200 MHz):
  REG_A -> LUT1 -> LUT2 -> LUT3 -> LUT4 -> LUT5 -> REG_B
                   (too many levels of logic)

After (meets timing):
  REG_A -> LUT1 -> LUT2 -> REG_pipe -> LUT3 -> LUT4 -> LUT5 -> REG_B
                   (split into two shorter paths)
```

**Strategy 2: Retiming (register balancing)**

Enable in Quartus: `set_global_assignment -name OPTIMIZATION_TECHNIQUE SPEED`

**Strategy 3: Reduce clock uncertainty**

Verify that `derive_clock_uncertainty` values are not overly pessimistic. Use explicit values if needed.

**Strategy 4: Location constraints**

For critical paths, constrain placement:

```tcl
set_instance_assignment -name PLACE_REGION "X10 Y10 X20 Y20" -to critical_module|*
```

### 10.4 Fixing Hold Violations

Hold violations are usually fixed automatically by the Fitter inserting delay. If they persist:

```tcl
# Enable hold time optimization (usually on by default)
set_global_assignment -name OPTIMIZE_HOLD_TIMING "ALL PATHS"

# Increase hold margin
set_clock_uncertainty -hold 0.100 [get_clocks sys_clk]
```

---

## 11. Best Practices and Common Pitfalls

### Best Practices

1. **Constrain every clock** - Every clock entering the FPGA must have a `create_clock`
2. **Constrain every I/O** - Use `set_input_delay` and `set_output_delay` for all data ports
3. **Use `derive_pll_clocks`** - Don't manually calculate PLL output frequencies
4. **Use `derive_clock_uncertainty`** - Let the tool compute optimal uncertainty values
5. **Use `set_clock_groups`** over multiple `set_false_path`** - More efficient, easier to maintain
6. **Always pair multicycle setup with hold** - `set_multicycle_path N -setup` needs `set_multicycle_path (N-1) -hold`
7. **Run `check_timing`** - Verify constraint coverage before analyzing results
8. **Constrain all four corners** - Check timing at slow/fast, hot/cold conditions
9. **Use meaningful clock names** - Makes reports and debugging much easier
10. **Keep SDC files organized** - Use comments and sections

### Common Pitfalls

**Pitfall 1: Forgetting hold adjustment for multicycle paths**

```tcl
# WRONG - hold check uses wrong edge
set_multicycle_path 3 -setup -from [get_registers A*] -to [get_registers B*]

# CORRECT - hold check moved to proper edge
set_multicycle_path 3 -setup -from [get_registers A*] -to [get_registers B*]
set_multicycle_path 2 -hold  -from [get_registers A*] -to [get_registers B*]
```

**Pitfall 2: Using `set_false_path` instead of `set_clock_groups`**

```tcl
# FRAGILE - must update when new clocks are added
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
set_false_path -from [get_clocks clk_b] -to [get_clocks clk_a]
# Oops, forgot clk_c !

# BETTER - automatically handles all inter-group crossings
set_clock_groups -asynchronous \
    -group [get_clocks clk_a] \
    -group [get_clocks {clk_b clk_c}]
```

**Pitfall 3: Overconstrained I/O delays**

```tcl
# WRONG - input_delay larger than clock period leaves no time for FPGA logic
set_input_delay -clock sys_clk -max 9.5 [get_ports data_in]  ;# period is 10ns!

# Reality check: 10.0 - 9.5 = 0.5ns for FPGA internal path + Tsu
# This is almost certainly impossible to meet
```

**Pitfall 4: Missing `-add_delay` for DDR constraints**

```tcl
# WRONG - second command overwrites the first
set_input_delay -clock ddr_clk -max 0.5 [get_ports ddr_data]
set_input_delay -clock ddr_clk -max 0.5 -clock_fall [get_ports ddr_data]

# CORRECT - second command adds to the first
set_input_delay -clock ddr_clk -max 0.5 [get_ports ddr_data]
set_input_delay -clock ddr_clk -max 0.5 -clock_fall -add_delay [get_ports ddr_data]
```

**Pitfall 5: Constraining clocks on internal nodes**

```tcl
# WRONG - creates a new clock that may not interact correctly with logic
create_clock -name bad_clk -period 10.0 [get_pins some_logic|output]

# CORRECT - use create_generated_clock for derived clocks
create_generated_clock -name good_clk \
    -source [get_ports CLK] \
    -divide_by 2 \
    [get_pins divider|Q]
```

### SDC Constraint Coverage Checklist

- [ ] All external clock sources have `create_clock`
- [ ] All PLL outputs are constrained (`derive_pll_clocks` or manual)
- [ ] All clock domain crossings are handled (`set_clock_groups`, `set_false_path`, or synchronizer constraints)
- [ ] All input ports have `set_input_delay` (or `set_false_path`)
- [ ] All output ports have `set_output_delay` (or `set_false_path`)
- [ ] Clock uncertainty is defined (`derive_clock_uncertainty`)
- [ ] Multicycle paths have matching hold adjustments
- [ ] `check_timing` reports no unconstrained paths
- [ ] All four timing corners pass (Slow/Fast, Hot/Cold)
- [ ] Async resets have `set_false_path` or recovery/removal constraints

---

## 12. Quick Reference

### Essential SDC Commands

| Command | Purpose |
|---------|---------|
| `create_clock` | Define a primary clock |
| `create_generated_clock` | Define a derived clock |
| `set_clock_groups` | Declare clock relationships |
| `set_input_delay` | Constrain input port timing |
| `set_output_delay` | Constrain output port timing |
| `set_false_path` | Exclude paths from timing |
| `set_multicycle_path` | Allow multiple cycles for a path |
| `set_max_delay` | Set maximum path delay |
| `set_min_delay` | Set minimum path delay |
| `set_clock_uncertainty` | Add timing margin |
| `set_clock_latency` | Specify clock delay |
| `derive_pll_clocks` | Auto-constrain PLL outputs (Altera) |
| `derive_clock_uncertainty` | Auto-compute uncertainty (Altera) |

### Object Access Commands

| Command | Returns |
|---------|---------|
| `get_ports` | Top-level I/O ports |
| `get_pins` | Cell pins |
| `get_cells` | Design instances |
| `get_clocks` | Clock objects |
| `get_nets` | Wires |
| `get_registers` | Registers (Altera) |

### Timing Report Commands

| Command | Purpose |
|---------|---------|
| `report_timing` | Report path timing details |
| `report_clocks` | List all clocks |
| `report_clock_transfers` | Show domain crossings |
| `check_timing` | Find constraint gaps |
| `report_ucd` | Unconstrained path report |
| `report_min_pulse_width` | Pulse width analysis |

### Common Constraint Patterns

```tcl
# Async reset
set_false_path -from [get_ports RESET_N]

# Slow I/O (LEDs, switches)
set_false_path -to [get_ports {LED[*]}]
set_false_path -from [get_ports {BUTTON[*]}]

# CDC with synchronizer
set_max_delay <period> -datapath_only \
    -from [get_registers {src_domain|signal}] \
    -to   [get_registers {dst_domain|sync_ff[0]}]

# N-cycle multicycle path
set_multicycle_path N -setup -from <src> -to <dst>
set_multicycle_path [expr {N-1}] -hold -from <src> -to <dst>

# Unrelated clock domains
set_clock_groups -asynchronous \
    -group [get_clocks clk_a] \
    -group [get_clocks clk_b]

# DDR I/O (both edges)
set_input_delay -clock ddr_clk -max <val> [get_ports data]
set_input_delay -clock ddr_clk -max <val> -clock_fall -add_delay [get_ports data]

# Virtual clock for I/O
create_clock -name virt_clk -period <P>
set_input_delay -clock virt_clk -max <val> [get_ports data_in]
```

---

## Further Reading

- [Intel Quartus Prime Timing Analyzer Cookbook](https://www.intel.com/content/www/us/en/docs/programmable/683068/current/timing-analyzer-cookbook.html)
- [Intel Quartus Prime Timing Analyzer User Guide](https://www.intel.com/content/www/us/en/docs/programmable/683243/current/timing-analyzer.html)
- [SDC 2.1 Specification (Synopsys)](https://www.synopsys.com)
- [AN 433: Constraining and Analyzing Source-Synchronous Interfaces](https://www.intel.com/content/www/us/en/docs/programmable/683082/current/constraining-and-analyzing-source.html)
