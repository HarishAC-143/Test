# Chapter 7: Best Practices and Common Pitfalls

## Table of Contents

- [SDC File Organization](#sdc-file-organization)
- [Constraint Methodology](#constraint-methodology)
- [Common Mistakes and How to Fix Them](#common-mistakes-and-how-to-fix-them)
- [Timing Closure Checklist](#timing-closure-checklist)
- [Performance Optimization Tips](#performance-optimization-tips)
- [SDC Review Checklist](#sdc-review-checklist)
- [Quick Reference Card](#quick-reference-card)

---

## SDC File Organization

### Recommended SDC File Structure

```tcl
#==============================================================
# Project: <project_name>
# File:    <project_name>.sdc
# Author:  <name>
# Date:    <date>
# Description: Top-level timing constraints
#==============================================================

#--------------------------------------------------------------
# Section 1: Clock Definitions
#--------------------------------------------------------------
# Define ALL clocks first, before any other constraints

create_clock -name sys_clk -period 10.000 [get_ports SYS_CLK]
create_clock -name eth_clk -period  8.000 [get_ports ETH_CLK]

# PLL-derived clocks
derive_pll_clocks

# Clock uncertainty
derive_clock_uncertainty

#--------------------------------------------------------------
# Section 2: Clock Relationships
#--------------------------------------------------------------
# Define clock groups (asynchronous, exclusive)

set_clock_groups -asynchronous \
    -group {sys_clk} \
    -group {eth_clk}

#--------------------------------------------------------------
# Section 3: Input Constraints
#--------------------------------------------------------------

set_input_delay -clock sys_clk -max 5.0 [get_ports {DATA_IN[*]}]
set_input_delay -clock sys_clk -min 1.0 [get_ports {DATA_IN[*]}]

#--------------------------------------------------------------
# Section 4: Output Constraints
#--------------------------------------------------------------

set_output_delay -clock sys_clk -max 4.0 [get_ports {DATA_OUT[*]}]
set_output_delay -clock sys_clk -min 0.5 [get_ports {DATA_OUT[*]}]

#--------------------------------------------------------------
# Section 5: Timing Exceptions
#--------------------------------------------------------------
# False paths, multicycle paths, max/min delays
# ALWAYS include a comment explaining WHY each exception exists

# Asynchronous reset (synchronized in rst_sync module)
set_false_path -from [get_ports RST_N]

# Static config registers (set once during initialization)
set_false_path -from [get_registers {config|mode_reg[*]}]

#--------------------------------------------------------------
# Section 6: Interface-Specific Constraints
#--------------------------------------------------------------
# Source additional SDC files for complex interfaces

# source ddr3_constraints.sdc
# source pcie_constraints.sdc
```

### Key Principles

1. **Clocks first, exceptions last**: Always define all clocks before referencing them
2. **One SDC file per project** for simple designs; multiple files for complex designs
3. **Comment every exception**: A false path without explanation is a ticking time bomb
4. **Use variables** for parameters that might change (periods, delays)
5. **Version control** your SDC files alongside your RTL

## Constraint Methodology

### The Golden Rules

1. **Constrain everything**: Target zero unconstrained paths
2. **Be accurate, not optimistic**: Use realistic timing numbers from datasheets
3. **Constrain for the worst case**: Include tolerances and margins
4. **Validate with `check_timing`**: Run after every SDC change
5. **Never false-path a real timing path**: Use exceptions only for genuinely non-functional paths

### Deriving I/O Delays from Datasheets

When you receive a datasheet for an external device, extract these parameters:

```
From the External Device Datasheet:
  Tco_max  = Maximum clock-to-output delay
  Tco_min  = Minimum clock-to-output delay
  Tsu      = Setup time
  Th       = Hold time

From the PCB Design:
  Td_max   = Maximum board trace delay
  Td_min   = Minimum board trace delay
  Tskew    = Clock skew between devices

Calculating SDC Values:
  set_input_delay  -max = Tco_max + Td_max + Tskew
  set_input_delay  -min = Tco_min + Td_min - Tskew
  set_output_delay -max = Tsu + Td_max + Tskew
  set_output_delay -min = -(Th) + Td_min - Tskew
```

### Margin Strategy

Always include margin in your timing budget:

```tcl
# Add 10% margin to critical interfaces
set MARGIN_FACTOR 1.1

set INPUT_MAX  [expr {($TCO_MAX + $BOARD_DELAY) * $MARGIN_FACTOR}]
set OUTPUT_MAX [expr {($TSU + $BOARD_DELAY) * $MARGIN_FACTOR}]
```

## Common Mistakes and How to Fix Them

### Mistake 1: Missing Clock Definition

**Symptom**: Entire blocks appear unconstrained. Fmax shows N/A.

```tcl
# WRONG: Forgot to define the clock
# (All paths using this clock are unconstrained)

# FIX: Add the clock definition
create_clock -name clk_100 -period 10.000 [get_ports CLK_100MHZ]
```

### Mistake 2: Wrong Clock Period

**Symptom**: Timing easily passes (period too large) or impossibly fails (period too small).

```tcl
# WRONG: 100 MHz specified as 100 ns period (that's 10 MHz!)
create_clock -name clk_100 -period 100.000 [get_ports CLK_100MHZ]

# FIX: 100 MHz = 10 ns period
create_clock -name clk_100 -period 10.000 [get_ports CLK_100MHZ]
```

### Mistake 3: Missing -min Input/Output Delay

**Symptom**: Hold analysis shows unrealistic results or paths are unconstrained for hold.

```tcl
# WRONG: Only max delay specified
set_input_delay -clock sys_clk -max 5.0 [get_ports DATA]

# FIX: Always specify both max and min
set_input_delay -clock sys_clk -max 5.0 [get_ports DATA]
set_input_delay -clock sys_clk -min 1.0 [get_ports DATA]
```

### Mistake 4: False Pathing Instead of Proper CDC

**Symptom**: Design works sometimes, fails intermittently.

```tcl
# WRONG: Hiding a real timing issue with false path
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
# (But multi-bit data crosses without synchronization!)

# FIX: Use proper CDC in RTL (async FIFO, handshake)
# Then constrain appropriately:
set_max_delay -from [get_registers {fifo|wr_ptr_gray[*]}] \
              -to   [get_registers {fifo|rd_sync[0][*]}] 12.0
```

### Mistake 5: Using Generated Clock Instead of Clock Enable

**Symptom**: Over-complicated constraints, unnecessary clock domain crossings.

```tcl
# WRONG: Creating a generated clock for a clock-enable structure
create_generated_clock -name slow_clk \
    -source [get_ports CLK] \
    -divide_by 4 \
    [get_registers clk_en_cnt[1]]
# Now every path between "real" clock and "slow_clk" is cross-domain!

# FIX: Use multicycle path for clock-enabled registers
set_multicycle_path -setup -from [get_registers src*] -to [get_registers dst*] 4
set_multicycle_path -hold  -from [get_registers src*] -to [get_registers dst*] 3
```

### Mistake 6: Forgetting derive_clock_uncertainty

**Symptom**: Design barely meets timing in STA but fails on hardware.

```tcl
# WRONG: No clock uncertainty
create_clock -name sys_clk -period 10.000 [get_ports CLK]
derive_pll_clocks
# (Missing derive_clock_uncertainty!)

# FIX: Always include clock uncertainty
create_clock -name sys_clk -period 10.000 [get_ports CLK]
derive_pll_clocks
derive_clock_uncertainty
```

### Mistake 7: Missing Multicycle Hold Companion

**Symptom**: Hold violations appear on multicycle paths.

```tcl
# WRONG: Multicycle setup without hold adjustment
set_multicycle_path -setup -from [get_registers a*] -to [get_registers b*] 3

# FIX: Always pair with hold (N-1)
set_multicycle_path -setup -from [get_registers a*] -to [get_registers b*] 3
set_multicycle_path -hold  -from [get_registers a*] -to [get_registers b*] 2
```

### Mistake 8: Overly Broad Wildcards

**Symptom**: Constraints apply to unintended paths.

```tcl
# WRONG: Too broad -- catches ALL registers with "data" in the name
set_false_path -from [get_registers *data*]

# FIX: Be specific with hierarchy and naming
set_false_path -from [get_registers {config_block|static_data_reg[*]}]
```

### Mistake 9: Not Constraining All I/O Ports

**Symptom**: `report_ucp` shows unconstrained ports.

```tcl
# FIX: Constrain all ports. For non-critical ports, use false paths:
set_false_path -from [get_ports {LED[*] DEBUG_*}]
set_false_path -to   [get_ports {LED[*] DEBUG_*}]

# For buttons/switches (asynchronous inputs)
set_false_path -from [get_ports {SW[*] KEY[*]}]
```

### Mistake 10: Conflicting Constraints

**Symptom**: Unexpected timing behavior, constraints seem to have no effect.

```tcl
# WRONG: create_clock on the same port twice (second overwrites first!)
create_clock -name clk_a -period 10.000 [get_ports CLK]
create_clock -name clk_b -period 20.000 [get_ports CLK]  ;# overwrites clk_a!

# FIX: Use -add for multiple clocks on the same port
create_clock -name clk_a -period 10.000 [get_ports CLK]
create_clock -name clk_b -period 20.000 [get_ports CLK] -add

# Then mark them as exclusive
set_clock_groups -exclusive -group {clk_a} -group {clk_b}
```

## Timing Closure Checklist

Use this checklist before signing off on your design:

### Pre-Compilation

- [ ] All clocks defined (`create_clock` for every clock input)
- [ ] PLL clocks derived (`derive_pll_clocks`)
- [ ] Clock uncertainty applied (`derive_clock_uncertainty`)
- [ ] Clock groups defined for asynchronous domains
- [ ] All input ports constrained (`set_input_delay`)
- [ ] All output ports constrained (`set_output_delay`)
- [ ] Both `-max` and `-min` specified for all I/O delays
- [ ] All timing exceptions documented with comments

### Post-Compilation

- [ ] `check_timing` reports no issues
- [ ] `report_ucp` shows zero unconstrained paths
- [ ] All setup slack values are positive
- [ ] All hold slack values are positive
- [ ] Recovery/removal checks pass
- [ ] Minimum pulse width checks pass
- [ ] Fmax meets or exceeds requirements
- [ ] Cross-domain paths are either properly constrained or false-pathed with justification

### Design Reviews

- [ ] SDC file reviewed by a second engineer
- [ ] I/O delay values traced back to datasheet parameters
- [ ] Board trace delays obtained from PCB layout team
- [ ] Every `set_false_path` has RTL justification (synchronizer present)
- [ ] Every `set_multicycle_path` has RTL justification (enable or protocol)

## Performance Optimization Tips

### Tip 1: Pipeline Deep Logic

If a path fails due to logic depth, insert pipeline registers:

```verilog
// BEFORE: 8 levels of logic, fails at 200 MHz
assign result = ((a + b) * c) >> (d & e);

// AFTER: 2-stage pipeline
always @(posedge clk) begin
    stage1 <= (a + b) * c;
    result <= stage1 >> (d & e);
end
```

### Tip 2: Use Quartus Optimization Directives

```tcl
# In QSF file:
set_instance_assignment -name OPTIMIZE_HOLD_TIMING "ALL PATHS" -entity top
set_global_assignment -name OPTIMIZATION_MODE "HIGH PERFORMANCE EFFORT"
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"
```

### Tip 3: Register I/O

Always register signals at I/O boundaries:

```verilog
// Register inputs
always @(posedge clk) begin
    data_in_reg  <= data_in;
    valid_in_reg <= valid_in;
end

// Register outputs
always @(posedge clk) begin
    data_out  <= data_out_next;
    valid_out <= valid_out_next;
end
```

### Tip 4: Use Logic Lock Regions

For critical paths, lock related logic to a specific FPGA region:

```tcl
# In QSF:
set_instance_assignment -name PLACE_REGION "X30 Y20 X60 Y50" -to "critical_module"
set_instance_assignment -name ROUTE_REGION "X28 Y18 X62 Y52" -to "critical_module"
```

### Tip 5: Balance Clock Trees

Use global clock networks for high-fanout clocks:

```tcl
# In QSF:
set_instance_assignment -name GLOBAL_SIGNAL "GLOBAL CLOCK" -to sys_clk
```

## SDC Review Checklist

A compact checklist for reviewing an SDC file:

```
SDC REVIEW CHECKLIST
─────────────────────────────────────────────────────

CLOCKS:
  □ Every clock input port has a create_clock
  □ Periods match design specification (double-check units!)
  □ derive_pll_clocks is present (if using PLLs)
  □ derive_clock_uncertainty is present
  □ Generated clocks have correct source and relationship

CLOCK GROUPS:
  □ Asynchronous domains use set_clock_groups -asynchronous
  □ Mux clocks use set_clock_groups -exclusive
  □ No over-broad clock grouping that hides real paths

INPUTS:
  □ All input ports have set_input_delay
  □ Both -max and -min specified
  □ Values derived from actual hardware parameters
  □ Correct reference clock used

OUTPUTS:
  □ All output ports have set_output_delay
  □ Both -max and -min specified
  □ Values derived from actual hardware parameters
  □ Correct reference clock used

EXCEPTIONS:
  □ Every set_false_path has a comment explaining why
  □ No false paths hiding real timing issues
  □ Multicycle paths have hold companions (N-1)
  □ Wildcards are specific enough
  □ set_max_delay used for bounded CDC where appropriate

VERIFICATION:
  □ check_timing clean
  □ report_ucp shows zero unconstrained paths
  □ Timing met across all corners
```

## Quick Reference Card

### Clock Commands

```tcl
create_clock -name <name> -period <ns> [get_ports <port>]
create_generated_clock -name <name> -source <pin> -divide_by <n> <target>
create_generated_clock -name <name> -source <pin> -multiply_by <n> <target>
derive_pll_clocks
derive_clock_uncertainty
set_clock_groups -asynchronous -group {<clk1>} -group {<clk2>}
set_clock_groups -exclusive -group {<clk1>} -group {<clk2>}
set_clock_uncertainty -setup <ns> -from <clk> -to <clk>
set_clock_latency -source -early <ns> [get_clocks <clk>]
set_clock_latency -source -late <ns> [get_clocks <clk>]
```

### I/O Commands

```tcl
set_input_delay  -clock <clk> -max <ns> [get_ports <ports>]
set_input_delay  -clock <clk> -min <ns> [get_ports <ports>]
set_output_delay -clock <clk> -max <ns> [get_ports <ports>]
set_output_delay -clock <clk> -min <ns> [get_ports <ports>]
```

### Exception Commands

```tcl
set_false_path -from <src> -to <dst>
set_false_path -from [get_ports <port>]
set_false_path -through <point>
set_multicycle_path -setup -from <src> -to <dst> <N>
set_multicycle_path -hold  -from <src> -to <dst> <N-1>
set_max_delay -from <src> -to <dst> <ns>
set_min_delay -from <src> -to <dst> <ns>
```

### Collection Commands (Quartus)

```tcl
get_ports {<pattern>}          ;# FPGA I/O pins
get_pins {<pattern>}           ;# Internal cell pins
get_registers {<pattern>}     ;# Register elements
get_nets {<pattern>}           ;# Internal nets
get_clocks {<pattern>}         ;# Defined clocks
get_cells {<pattern>}          ;# Logic cells
```

### Reporting Commands

```tcl
report_timing -setup -npaths <n> -detail full_path
report_timing -hold  -npaths <n> -detail full_path
report_timing -from_clock <clk> -to_clock <clk>
report_clocks
report_ucp
check_timing
report_min_pulse_width -npaths <n>
```

---

**Previous: [Chapter 6 - Understanding Timing Reports](06_timing_reports.md)**

---

*This concludes the Altera FPGA Static Timing Analysis (SDC) Tutorial. Return to the [Table of Contents](../README.md) for the full guide and practical examples.*
