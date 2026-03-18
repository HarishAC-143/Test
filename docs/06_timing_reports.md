# Chapter 6: Understanding Timing Reports

## Table of Contents

- [TimeQuest Timing Analyzer Overview](#timequest-timing-analyzer-overview)
- [Setup (Max) Timing Report](#setup-max-timing-report)
- [Hold (Min) Timing Report](#hold-min-timing-report)
- [Recovery and Removal Reports](#recovery-and-removal-reports)
- [Clock Summary Reports](#clock-summary-reports)
- [Unconstrained Path Reports](#unconstrained-path-reports)
- [Debugging Timing Failures](#debugging-timing-failures)
- [Practical Examples](#practical-examples)

---

## TimeQuest Timing Analyzer Overview

After compilation, TimeQuest generates timing reports organized into several categories:

| Report Category | What It Shows |
|----------------|---------------|
| **Clocks** | All defined clocks and their properties |
| **Slow Model (Setup)** | Setup timing analysis at worst-case conditions |
| **Slow Model (Hold)** | Hold timing analysis at worst-case conditions |
| **Fast Model (Setup)** | Setup analysis at best-case conditions |
| **Fast Model (Hold)** | Hold analysis at best-case conditions |
| **Recovery/Removal** | Asynchronous reset/preset timing |
| **Minimum Pulse Width** | Clock pulse width requirements |
| **Unconstrained Paths** | Paths missing timing constraints |

### Accessing Reports in Quartus

1. **GUI**: Compilation Report > TimeQuest Timing Analyzer
2. **Command Line**: `quartus_sta <project> --do_report_timing`
3. **Tcl Console**: `report_timing -setup -npaths 20`

### Key Tcl Commands for Reporting

```tcl
# Report worst setup paths
report_timing -setup -npaths 10 -detail full_path

# Report worst hold paths
report_timing -hold -npaths 10 -detail full_path

# Report specific clock domain
report_timing -setup -from_clock sys_clk -to_clock sys_clk -npaths 5

# Report specific path
report_timing -from [get_registers src_reg] -to [get_registers dst_reg]

# Report all clocks
report_clocks

# Report unconstrained paths
report_ucp

# Check timing (summary)
check_timing
```

## Setup (Max) Timing Report

A setup timing report shows whether data arrives at the destination register early enough to be captured. Here is a typical setup report broken down:

### Report Structure

```
=====================================================
Slow 1100mV 85C Model Setup Report
=====================================================

Info: Clock "sys_clk" - Setup
=====================================================
From Node    : datapath|stage1|reg_out
To Node      : datapath|stage2|reg_in
Launch Clock : sys_clk
Latch Clock  : sys_clk
=====================================================

  Data Arrival Time
  ─────────────────────────────────────────
  Clock Rise Edge                    0.000
  + Clock Network Delay (Source)     2.531
  = Launch Edge Time                 2.531
  + Register Tco                     0.432
  + Data Path Delay                  4.217
    (combinational logic: 2.103 ns)
    (routing delay:       2.114 ns)
  ─────────────────────────────────────────
  Data Arrival Time                  7.180

  Data Required Time
  ─────────────────────────────────────────
  Clock Rise Edge                   10.000   (1 clock period)
  + Clock Network Delay (Dest)       2.612
  - Clock Uncertainty                0.150
  - Register Tsu                     0.089
  ─────────────────────────────────────────
  Data Required Time                12.373

  Setup Slack = Data Required Time - Data Arrival Time
              = 12.373 - 7.180
              = 5.193 ns  (PASS)
```

### Understanding Each Component

| Component | Description |
|-----------|-------------|
| **Clock Rise Edge** | The reference time (0 for launch, period for capture) |
| **Clock Network Delay** | Time for clock to propagate through the clock tree |
| **Register Tco** | Clock-to-output delay of the source flip-flop |
| **Data Path Delay** | Total combinational logic + routing delay |
| **Clock Uncertainty** | Jitter, skew, and other variations (subtracted from available time) |
| **Register Tsu** | Setup time of the destination flip-flop |
| **Setup Slack** | The margin -- positive means timing is met |

### Data Arrival Path Breakdown

The data path is broken into individual segments:

```
Data Path Detail:
─────────────────────────────────────────────────────
Total                                        4.217 ns
  datapath|stage1|reg_out (Tco)              0.432 ns
  datapath|add_u0|result[3] (LUT)            0.487 ns
  routing                                     0.892 ns
  datapath|mux_u0|out (LUT)                  0.312 ns
  routing                                     1.123 ns
  datapath|cmp_u0|greater (LUT)              0.425 ns
  routing                                     0.546 ns
  datapath|stage2|reg_in (setup)             0.000 ns
```

## Hold (Min) Timing Report

Hold analysis ensures data doesn't change too quickly at the destination register after the capturing clock edge.

### Report Structure

```
=====================================================
Fast 1100mV 0C Model Hold Report
=====================================================

  Data Arrival Time
  ─────────────────────────────────────────
  Clock Rise Edge                    0.000
  + Clock Network Delay (Source)     1.890
  = Launch Edge Time                 1.890
  + Register Tco (min)               0.148
  + Data Path Delay (min)            0.672
  ─────────────────────────────────────────
  Data Arrival Time                  2.710

  Data Required Time
  ─────────────────────────────────────────
  Clock Rise Edge                    0.000
  + Clock Network Delay (Dest)       1.943
  + Clock Uncertainty                0.050
  + Register Th                      0.167
  ─────────────────────────────────────────
  Data Required Time                 2.160

  Hold Slack = Data Arrival Time - Data Required Time
             = 2.710 - 2.160
             = 0.550 ns  (PASS)
```

### Key Differences from Setup

| Aspect | Setup | Hold |
|--------|-------|------|
| Corner | Slow (max delays) | Fast (min delays) |
| Data path | Uses maximum delay | Uses minimum delay |
| Slack formula | Required - Arrival | Arrival - Required |
| Positive slack | Data arrives early enough | Data holds long enough |
| Clock edge | Next edge (launch + period) | Same edge (launch) |

## Recovery and Removal Reports

Recovery and removal timing applies to asynchronous reset/preset signals:

- **Recovery**: Similar to setup -- ensures the reset de-assertion occurs early enough before the clock edge
- **Removal**: Similar to hold -- ensures the reset signal is held stable long enough after the clock edge

```
=====================================================
Recovery Report
=====================================================

From Node    : reset_sync|rst_sync_reg[1]
To Node      : datapath|reg_a
Launch Clock : sys_clk
Latch Clock  : sys_clk

Recovery Slack = 3.218 ns (PASS)
```

If you use asynchronous resets, these checks ensure glitch-free reset de-assertion. Synchronizing the reset in RTL prevents most recovery/removal issues.

## Clock Summary Reports

The clock summary shows all clocks recognized by TimeQuest:

```
=====================================================
Clocks Summary
=====================================================

Clock Name           Type          Period    Freq     Source
─────────────────────────────────────────────────────────────
sys_clk              Base          10.000   100.0MHz  CLK_100MHZ
pll|...|clk[0]       Generated      5.000   200.0MHz  pll|...|clk[0]
pll|...|clk[1]       Generated     40.000    25.0MHz  pll|...|clk[1]
spi_clk              Base         100.000    10.0MHz  SPI_SCLK
adc_virt_clk         Virtual       20.000    50.0MHz  (none)
```

### What to Check

- **All expected clocks appear**: Missing clocks mean unconstrained paths
- **Periods are correct**: Verify against your design specification
- **Generated clocks trace back** to the correct source
- **Virtual clocks** are present if needed for I/O constraints

## Unconstrained Path Reports

The unconstrained paths report (`report_ucp`) is critically important. It shows paths that TimeQuest cannot analyze because they lack constraints.

### Common Categories of Unconstrained Paths

```
=====================================================
Unconstrained Paths Report
=====================================================

Unconstrained Clocks:
  (none)    ← Good! All clocks are defined

Unconstrained Input Ports:
  SWITCH[0]     ← Not constrained with set_input_delay
  SWITCH[1]
  BUTTON_N

Unconstrained Output Ports:
  LED[0]        ← Not constrained with set_output_delay
  LED[1]
  DEBUG_PIN

Unconstrained Register-to-Register Paths:
  (none)    ← Good! All reg-to-reg paths have clocks
```

### Addressing Unconstrained Paths

```tcl
# Option 1: Constrain the paths properly
set_input_delay -clock sys_clk -max 5.0 [get_ports {SWITCH[*]}]

# Option 2: If truly asynchronous, false-path them
set_false_path -from [get_ports {BUTTON_N}]

# Option 3: If LEDs are not timing-critical
set_false_path -to [get_ports {LED[*]}]

# Goal: Zero unconstrained paths in production designs
```

## Debugging Timing Failures

### Step 1: Identify the Worst Failing Path

```tcl
# Get the 10 worst setup paths
report_timing -setup -npaths 10 -detail full_path

# Filter to specific failing domain
report_timing -setup -from_clock clk_200 -to_clock clk_200 -npaths 5
```

### Step 2: Analyze the Path Components

Look at the path breakdown:
- **Logic levels**: High logic depth (>5-8 levels for 200 MHz) suggests the path needs pipelining
- **Routing delay**: High routing delay suggests placement issues
- **Clock skew**: Large clock network delay difference between source and destination

### Step 3: Common Fixes

| Problem | Solution |
|---------|----------|
| Too many logic levels | Add pipeline registers |
| Large routing delay | Add location constraints, use Logic Lock regions |
| Clock skew | Ensure balanced clock tree, use global clock networks |
| Barely failing (< 0.5 ns) | Increase Fitter effort, use optimization directives |
| Wrong constraint | Fix SDC (check periods, delays, exceptions) |

### Step 4: Verify Constraint Correctness

```tcl
# Check if the constraint is what you intended
report_timing -setup -from [get_registers src] -to [get_registers dst] -detail full_path

# Verify clock definition
report_clocks

# Check what exceptions apply to a path
report_exceptions -from [get_registers src] -to [get_registers dst]
```

### Interpreting Timing Numbers

```
Example Failing Path:
  Data Arrival Time     = 10.523 ns
  Data Required Time    = 10.000 ns
  Setup Slack           = -0.523 ns  ← FAIL

Breakdown:
  Logic delay           = 5.234 ns  (49.7%)
  Routing delay         = 4.421 ns  (42.0%)
  Register Tco          = 0.432 ns  ( 4.1%)
  Clock uncertainty     = 0.436 ns  ( 4.2% of budget consumed)
```

If routing delay dominates, placement is the issue. If logic delay dominates, the path is too deep.

## Practical Examples

### Example 1: Analyzing a Complete Timing Report

```tcl
# Step-by-step timing analysis script for Quartus

# Load the design
project_open my_project

# Create timing netlist
create_timing_netlist

# Read SDC
read_sdc

# Update timing netlist
update_timing_netlist

# --- Clock Summary ---
report_clocks
# Verify: Are all expected clocks present?

# --- Unconstrained Paths ---
report_ucp
# Target: Zero unconstrained paths

# --- Setup Analysis ---
report_timing -setup -npaths 20 -detail full_path \
    -file setup_report.txt

# --- Hold Analysis ---
report_timing -hold -npaths 20 -detail full_path \
    -file hold_report.txt

# --- Per-Clock-Domain Summary ---
foreach clk [get_collection_members [get_clocks *] -name] {
    puts "=== Clock: $clk ==="
    report_timing -setup -from_clock $clk -to_clock $clk \
        -npaths 3 -detail summary
}

# --- Recovery/Removal ---
report_timing -recovery -npaths 5
report_timing -removal -npaths 5

# --- Minimum Pulse Width ---
report_min_pulse_width -npaths 5

# --- Check Timing (overall summary) ---
check_timing

# Delete the netlist
delete_timing_netlist
project_close
```

### Example 2: Fmax Report

The maximum frequency (Fmax) is the highest clock frequency at which the design can operate:

```
=====================================================
Fmax Summary
=====================================================

Clock Name       Restricted Fmax    Unrestricted Fmax
────────────────────────────────────────────────────
sys_clk          100.00 MHz         127.35 MHz
                 (Required)         (Actual capability)

pll_200mhz       200.00 MHz         213.45 MHz
                 (Required)         (Actual capability)

spi_clk           10.00 MHz          87.52 MHz
                 (Required)         (Actual capability)
```

- **Restricted Fmax**: The clock frequency requested in SDC (your target)
- **Unrestricted Fmax**: The maximum achievable frequency (1 / critical_path_delay)

If Restricted Fmax < Unrestricted Fmax, timing is met.

### Example 3: Cross-Domain Timing Report

When analyzing paths between clock domains:

```
=====================================================
Setup Report: clk_100 -> clk_200
=====================================================

From Clock: clk_100 (period = 10.000 ns)
To Clock:   clk_200 (period =  5.000 ns)

Relationship: setup = 5.000 ns (most restrictive common edge)

From Node    : bridge|data_reg[0]
To Node      : fast_proc|input_reg[0]

Data Arrival Time    = 4.256 ns
Data Required Time   = 4.750 ns
Setup Slack          = 0.494 ns (PASS, but tight)
```

The "relationship" tells you which launch/capture edge pair TimeQuest selected for analysis. For cross-domain paths, the tool finds the most restrictive valid edge pair.

### Example 4: I/O Timing Report

```
=====================================================
Input Port Timing Report
=====================================================

Port: DATA_IN[0]
Reference Clock: sys_clk (rising edge)
Input Delay: max = 5.000 ns, min = 1.000 ns

  Data Arrival Time:
    Clock Edge        0.000 ns
    + Input Delay     5.000 ns (max)
    + Pin Delay       1.234 ns
    + Routing         0.567 ns
    ─────────────────────────
    Total             6.801 ns

  Data Required Time:
    Clock Edge       10.000 ns
    + Clock Delay     2.345 ns
    - Tsu             0.089 ns
    - Uncertainty     0.150 ns
    ─────────────────────────
    Total            12.106 ns

  Setup Slack = 12.106 - 6.801 = 5.305 ns (PASS)
```

---

**Previous: [Chapter 5 - Advanced Constraints](05_advanced_constraints.md)** | **Next: [Chapter 7 - Best Practices & Common Pitfalls](07_best_practices.md)**
