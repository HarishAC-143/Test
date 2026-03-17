# Chapter 4: Practical Workflow — Running SpyGlass End-to-End

## 4.1 Overview

This chapter walks through a complete SpyGlass flow from project setup to clean sign-off. We will use the example designs provided in this repository.

## 4.2 Project Directory Structure

A well-organized SpyGlass project looks like this:

```
my_project/
├── rtl/                    # RTL source files
│   ├── top.v
│   ├── sub_a.v
│   └── sub_b.v
├── spyglass/               # SpyGlass working directory
│   ├── project.prj         # Project file
│   ├── constraints.sgdc    # CDC constraints
│   ├── waivers.swl         # Waiver file
│   ├── scripts/
│   │   ├── run_lint.tcl    # Lint TCL script
│   │   └── run_cdc.tcl     # CDC TCL script
│   └── reports/            # Generated reports (gitignored)
└── docs/
    └── lint_cdc_status.md  # Tracking document
```

## 4.3 Step-by-Step: Lint Analysis

### Step 1: Create the Project File

```tcl
# lint_setup.prj

##-- Project configuration
set_option projectwdir   ./spyglass_work
set_option active_goal   lint/lint_rtl

##-- Read design files
read_file -type verilog {
    ../rtl/counter_with_issues.v
    ../rtl/fsm_with_issues.v
    ../rtl/memory_controller.v
}

##-- Set top module
set_option top counter_with_issues

##-- SystemVerilog support (if needed)
# set_option enableSV yes

##-- Define search paths for includes
# set_option incdir {../rtl/includes}

##-- Read waiver file
# read_file -type waiver ../waivers/lint_waivers.swl
```

### Step 2: Run Lint in Batch Mode

```bash
cd examples/lint
spyglass -project scripts/lint_setup.prj -batch -goal lint/lint_rtl
```

### Step 3: Review the Results

```bash
# Summary report
cat spyglass_work/consolidated_reports/lint_rtl_summary.rpt

# Detailed per-rule reports
ls spyglass_work/lint_rtl/
```

### Step 4: Interpret the Summary Report

A typical summary looks like:

```
╔══════════════════════════════════════════════════╗
║           SpyGlass Lint Summary Report           ║
╠══════════════════════════════════════════════════╣
║ Goal: lint/lint_rtl                              ║
║ Top:  counter_with_issues                        ║
╠══════════════════════════════════════════════════╣
║ Severity    │ Count │ Waived │ Remaining         ║
╠═════════════╪═══════╪════════╪═══════════════════╣
║ Fatal       │   0   │   0    │   0               ║
║ Error       │   2   │   0    │   2               ║
║ Warning     │   8   │   0    │   8               ║
║ Info        │   3   │   0    │   3               ║
╚══════════════════════════════════════════════════╝
```

### Step 5: Fix Violations

Work through violations systematically:

1. Open the detailed report for each rule
2. Cross-reference with the RTL source
3. Fix the code or add a waiver with justification

### Step 6: Add Waivers for Intentional Violations

```tcl
# lint_waivers.swl

# Debug port intentionally left unloaded
waive -rule W_0123 -module counter_with_issues \
    -comment "Debug port — not connected in production"

# Test signal intentionally undriven in this configuration
waive -rule W_0124 -module memory_controller -signal test_bypass \
    -comment "Driven by JTAG in full-chip integration"
```

### Step 7: Re-run and Verify Clean

```bash
# Re-run with waivers
spyglass -project scripts/lint_setup.prj -batch -goal lint/lint_rtl

# Verify: Remaining should be 0 (or only accepted items)
```

## 4.4 Step-by-Step: CDC Analysis

### Step 1: Define Clocks and Constraints

```tcl
# cdc_constraints.sgdc

current_design cdc_top

# Define clocks
create_clock -name clk_fast -period 5   [get_ports clk_fast]
create_clock -name clk_slow -period 20  [get_ports clk_slow]

# Declare asynchronous relationship
set_clock_groups -asynchronous \
    -group {clk_fast} \
    -group {clk_slow}

# Define resets
reset -name rst_fast_n -value 0 [get_ports rst_fast_n]
reset -name rst_slow_n -value 0 [get_ports rst_slow_n]
```

### Step 2: Create the Project File

```tcl
# cdc_setup.prj

set_option projectwdir ./spyglass_work

##-- Read design files
read_file -type verilog {
    ../rtl/async_fifo.v
    ../rtl/cdc_sync_examples.v
    ../rtl/pulse_synchronizer.v
    ../rtl/handshake_sync.v
}

##-- Read constraints
read_file -type sgdc {
    ../constraints/clock_definitions.sgdc
    ../constraints/cdc_constraints.sgdc
}

##-- Set top module
set_option top async_fifo

##-- Set CDC goal
current_goal cdc/cdc_verify_struct
run_goal

current_goal cdc/cdc_verify
run_goal
```

### Step 3: Run CDC Analysis

```bash
cd examples/cdc
spyglass -project scripts/cdc_setup.prj -batch
```

### Step 4: Review CDC Results

The CDC report classifies crossings:

```
╔══════════════════════════════════════════════════════════════╗
║               SpyGlass CDC Crossing Summary                  ║
╠══════════════════════════════════════════════════════════════╣
║ Crossing Type               │ Count │ Properly Synced       ║
╠═════════════════════════════╪═══════╪═══════════════════════╣
║ 1-bit signal crossing       │  12   │  10 (2 violations)    ║
║ Multi-bit bus crossing      │   4   │   3 (1 violation)     ║
║ Control signal crossing     │   6   │   6 (all clean)       ║
║ Gray-coded bus crossing     │   2   │   2 (all clean)       ║
╠═════════════════════════════╪═══════╪═══════════════════════╣
║ Reconvergence paths         │   1   │   0 (1 violation)     ║
╚══════════════════════════════════════════════════════════════╝
```

### Step 5: Fix or Waive Violations

For each violation:

1. **Missing synchronizer** → Add appropriate synchronizer
2. **Multi-bit without Gray code** → Implement Gray coding or use handshake/FIFO
3. **Reconvergence** → Combine signals before crossing or use MUX recapture
4. **Intentional crossing** → Waive with detailed justification

### Step 6: CDC Waivers

```tcl
# cdc_waivers.swl

# Quasi-static configuration register — changes only during init
waive -rule Ac_cdc01 \
    -from {config_reg[*]} -to {sync_config[*]} \
    -comment "Quasi-static: written once at boot, stable during operation"

# Custom synchronizer verified separately
waive -rule Ac_cdc02 \
    -module custom_sync_wrapper \
    -comment "Custom synchronizer cell verified via STA and formal"
```

## 4.5 Interactive GUI Workflow

While batch mode is essential for regression, the GUI is invaluable for debug:

### Launching the GUI

```bash
spyglass -project scripts/lint_setup.prj &
```

### GUI Navigation

1. **Goal Navigator** (left panel) — Select and run goals
2. **Message Browser** (center) — Browse violations by rule, module, or severity
3. **Source View** — Click a message to jump to the RTL source
4. **Schematic View** — Visualize the logic around a violation
5. **CDC Crossing Matrix** — (CDC mode) See all crossings in a matrix view

### Useful GUI Operations

| Operation | How |
|-----------|-----|
| Filter by severity | Click severity filters in Message Browser |
| Group by module | Right-click → Group By → Module |
| View schematic | Select message → View → Schematic |
| Generate report | File → Generate Report |
| Apply waiver | Right-click message → Waive |
| Cross-probe to source | Double-click any message |

## 4.6 Automating with Makefiles

```makefile
# Makefile for SpyGlass runs

SPYGLASS  = spyglass
PROJ_LINT = scripts/lint_setup.prj
PROJ_CDC  = scripts/cdc_setup.prj
WORK_DIR  = spyglass_work

.PHONY: lint cdc clean all

all: lint cdc

lint:
	$(SPYGLASS) -project $(PROJ_LINT) -batch -goal lint/lint_rtl

cdc:
	$(SPYGLASS) -project $(PROJ_CDC) -batch -goal cdc/cdc_verify

clean:
	rm -rf $(WORK_DIR) spyglass_reports

report:
	@echo "=== Lint Summary ==="
	@cat $(WORK_DIR)/consolidated_reports/lint_rtl_summary.rpt 2>/dev/null || echo "No lint report found"
	@echo ""
	@echo "=== CDC Summary ==="
	@cat $(WORK_DIR)/consolidated_reports/cdc_verify_summary.rpt 2>/dev/null || echo "No CDC report found"
```

## 4.7 Incremental Workflow

For large designs, running full analysis every time is slow. Use incremental mode:

```tcl
# Enable incremental analysis
set_option incr_mode yes

# SpyGlass will re-analyze only changed files
run_goal
```

## 4.8 Next Steps

- [Chapter 5: Advanced Topics](05_advanced_topics.md) — Hierarchical analysis, CI integration, methodology.
