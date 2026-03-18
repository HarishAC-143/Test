# Synopsys SpyGlass Lint & CDC: A Comprehensive Tutorial

A hands-on guide to static RTL analysis using Synopsys SpyGlass, covering both **Lint** (structural/coding checks) and **CDC** (Clock Domain Crossing) verification with practical, runnable examples.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [SpyGlass Overview & Architecture](#2-spyglass-overview--architecture)
3. [Environment Setup](#3-environment-setup)
4. [SpyGlass Lint](#4-spyglass-lint)
   - [What Lint Catches](#41-what-lint-catches)
   - [Running a Lint Flow](#42-running-a-lint-flow)
   - [Rule Categories & Severity](#43-rule-categories--severity)
   - [Practical Lint Examples](#44-practical-lint-examples)
5. [SpyGlass CDC](#5-spyglass-cdc)
   - [Why CDC Matters](#51-why-cdc-matters)
   - [CDC Fundamentals](#52-cdc-fundamentals)
   - [Running a CDC Flow](#53-running-a-cdc-flow)
   - [Practical CDC Examples](#54-practical-cdc-examples)
6. [Constraints & SDC for SpyGlass](#6-constraints--sdc-for-spyglass)
7. [Waivers](#7-waivers)
8. [Advanced Topics](#8-advanced-topics)
9. [Best Practices & Methodology](#9-best-practices--methodology)
10. [Troubleshooting](#10-troubleshooting)
11. [Repository Structure](#11-repository-structure)

---

## 1. Introduction

**SpyGlass** is Synopsys's flagship static analysis platform for RTL designs. Unlike simulation, SpyGlass examines the *structure* of your HDL code without requiring testbenches or input vectors. It finds bugs that are difficult or impossible to catch through simulation alone—particularly clock domain crossing (CDC) issues that only manifest under specific timing conditions.

This tutorial provides:
- A ground-up explanation of SpyGlass Lint and CDC concepts
- Ready-to-run Verilog/SystemVerilog examples with intentional issues
- TCL scripts to drive SpyGlass flows
- Constraint, waiver, and methodology guidance

### Who Should Read This

- RTL designers who want cleaner, more reliable code
- Verification engineers setting up static checks in CI/CD
- ASIC/FPGA engineers preparing designs for tapeout sign-off

---

## 2. SpyGlass Overview & Architecture

### 2.1 How SpyGlass Works

SpyGlass operates in three phases:

```
   ┌───────────────┐     ┌──────────────────┐     ┌──────────────┐
   │  RTL Parsing   │────▶│  Elaboration &    │────▶│  Rule-based  │
   │  & Compilation │     │  Model Building   │     │  Analysis    │
   └───────────────┘     └──────────────────┘     └──────────────┘
         │                       │                       │
    Read Verilog/        Build internal graph      Apply lint/CDC
    SystemVerilog/       of design hierarchy,      rules to the
    VHDL sources         connectivity, clocks      elaborated model
```

1. **Parsing**: SpyGlass reads your RTL source files, resolving `include` directives and macros.
2. **Elaboration**: It builds an internal representation—a connectivity graph that captures modules, ports, signals, clock trees, and reset trees.
3. **Analysis**: Rule engines traverse the graph, flagging violations. Different *goals* (Lint, CDC, DFT, Power, etc.) use different rule sets.

### 2.2 Key Terminology

| Term | Description |
|------|-------------|
| **Goal** | A collection of rules targeting a specific analysis area (e.g., `lint/lint_rtl`, `cdc/cdc_verify`) |
| **Rule** | A single check (e.g., `W_164` for undriven signals, `Ac_cdc01` for missing synchronizer) |
| **Severity** | `Fatal`, `Error`, `Warning`, `Info` — controls whether a violation blocks sign-off |
| **Waiver** | An explicit acknowledgment that a specific violation is acceptable |
| **SGDC** | SpyGlass Design Constraints — SpyGlass-specific constraint format |
| **SDC** | Synopsys Design Constraints — industry-standard timing constraint format |

### 2.3 SpyGlass vs. Other Tools

| Feature | SpyGlass | Simulation | Formal Verification |
|---------|----------|------------|---------------------|
| Requires testbench | No | Yes | Sometimes |
| Catches CDC bugs | Comprehensive | Only if exercised | Limited |
| Runtime | Minutes | Hours–Days | Hours |
| Coverage of corner cases | Structural (all paths) | Stimulus-dependent | Exhaustive (bounded) |

---

## 3. Environment Setup

### 3.1 Prerequisites

```bash
# Verify SpyGlass is installed and licensed
which sg_shell
sg_shell -version

# Typical environment setup
export SPYGLASS_HOME=/opt/synopsys/spyglass/current
export PATH=$SPYGLASS_HOME/bin:$PATH
export LM_LICENSE_FILE=27000@license-server
```

### 3.2 Project Structure

This tutorial uses the following layout (see [Repository Structure](#11-repository-structure) for details):

```
.
├── README.md                    # This tutorial
├── examples/
│   ├── lint_basics/             # Basic lint violation examples
│   ├── lint_advanced/           # Advanced lint scenarios
│   ├── cdc_basics/              # Basic CDC crossing examples
│   ├── cdc_synchronizers/       # Synchronizer design patterns
│   └── cdc_advanced/            # Complex CDC scenarios
├── scripts/                     # SpyGlass TCL run scripts
├── constraints/                 # SDC & SGDC constraint files
├── waivers/                     # Waiver files
└── docs/                        # Additional documentation
```

### 3.3 Running the Examples

Each example can be run using the provided TCL scripts:

```bash
# Run lint on a specific example
sg_shell -tcl scripts/run_lint.tcl -batch

# Run CDC analysis
sg_shell -tcl scripts/run_cdc.tcl -batch

# Interactive SpyGlass GUI
spyglass -project spyglass_project.prj
```

---

## 4. SpyGlass Lint

### 4.1 What Lint Catches

SpyGlass Lint performs structural analysis of your RTL to find coding issues that may lead to:

- **Simulation/synthesis mismatches** — code that simulates correctly but synthesizes to incorrect hardware
- **Unintended latches** — incomplete `if/else` or `case` statements in combinational blocks
- **Undriven or unloaded signals** — wasted logic or functional bugs
- **Width mismatches** — implicit truncation or zero-extension across assignments
- **Race conditions** — blocking vs. non-blocking assignment misuse
- **Unreachable code** — dead logic that clutters the design
- **Naming and style violations** — inconsistent conventions that hurt maintainability

### 4.2 Running a Lint Flow

A typical lint flow TCL script looks like this (see [`scripts/run_lint.tcl`](scripts/run_lint.tcl)):

```tcl
# 1. Create a new project
new_project my_design -force

# 2. Set design parameters
set_option projectwdir ./spyglass_output
set_option language_mode mixed            ;# Verilog + SystemVerilog
set_option enableSV yes                   ;# Enable SystemVerilog

# 3. Read source files
read_file -type verilog examples/lint_basics/counter.v
read_file -type verilog examples/lint_basics/fsm.v

# 4. Set the top module
set_option top counter_top

# 5. Read constraints (optional but recommended)
read_file -type sgdc constraints/lint_constraints.sgdc

# 6. Select and run the lint goal
current_goal lint/lint_rtl
run_goal

# 7. Generate reports
write_report spyglass_output/lint_report.rpt

# 8. Close
save_project
close_project
```

Run it:

```bash
sg_shell -tcl scripts/run_lint.tcl -batch 2>&1 | tee lint_run.log
```

### 4.3 Rule Categories & Severity

SpyGlass Lint rules are organized into groups:

| Category | Prefix | Description | Example Rules |
|----------|--------|-------------|---------------|
| **Synthesis** | `W_` | Simulation-synthesis mismatch | `W_116` (latch inference), `W_164` (undriven signal) |
| **Connectivity** | `W_` | Port/signal connectivity issues | `W_287` (unconnected port), `W_240` (unloaded signal) |
| **Coding Style** | `STARC-*` | STARC methodology rules | `STARC-2.1.4.4` (full case), `STARC-2.3.1.1` (reset) |
| **Clock/Reset** | `W_` | Clock and reset integrity | `W_391` (gated clock), `W_398` (async reset) |
| **Naming** | `NamingConv` | Naming convention checks | Configurable per project |

Severity levels:

```
Fatal   → Design cannot be elaborated; must fix immediately
Error   → Functional risk; should fix before tapeout
Warning → Potential issue; review and waive or fix
Info    → Informational; no action required
```

### 4.4 Practical Lint Examples

#### Example 1: Unintended Latch Inference

**File:** [`examples/lint_basics/latch_inference.v`](examples/lint_basics/latch_inference.v)

A classic bug — an incomplete `if` statement in a combinational `always` block creates an unintended latch:

```verilog
// BAD: Missing else branch infers a latch for 'result'
always @(*) begin
    if (enable)
        result = data_in;
    // No else → latch!
end
```

**SpyGlass flags:** `W_116 (Latch inferred)`, `STARC-2.1.4.4`

**Fix:**

```verilog
// GOOD: Complete assignment in all branches
always @(*) begin
    if (enable)
        result = data_in;
    else
        result = 8'b0;
end
```

#### Example 2: Width Mismatch

**File:** [`examples/lint_basics/width_mismatch.v`](examples/lint_basics/width_mismatch.v)

Implicit truncation causes silent data loss:

```verilog
wire [15:0] wide_bus;
wire [7:0]  narrow_bus;
assign narrow_bus = wide_bus;  // Upper 8 bits silently dropped
```

**SpyGlass flags:** `W_164a (Width mismatch in assignment)`

#### Example 3: Blocking vs. Non-Blocking Assignments

**File:** [`examples/lint_basics/blocking_nonblocking.v`](examples/lint_basics/blocking_nonblocking.v)

Mixing assignment types in sequential logic is a common source of simulation/synthesis mismatches:

```verilog
// BAD: Blocking assignment in sequential always block
always @(posedge clk) begin
    count = count + 1;       // Should be <=
    delayed = count;         // Gets new count in simulation,
                             // but synthesis may differ
end
```

**SpyGlass flags:** `W_391 (Blocking assignment in sequential block)`, `STARC-2.3.1.1`

#### Example 4: Finite State Machine Issues

**File:** [`examples/lint_basics/fsm.v`](examples/lint_basics/fsm.v)

SpyGlass checks FSM completeness, unreachable states, and encoding:

```verilog
// BAD: Missing default in case statement
always @(*) begin
    case (state)
        IDLE:    next_state = RUN;
        RUN:     next_state = DONE;
        DONE:    next_state = IDLE;
        // Missing default → latch + undefined behavior
        // for unused encodings
    endcase
end
```

**SpyGlass flags:** `W_116`, `STARC-2.1.4.4 (case without default)`

See the [examples/lint_basics/](examples/lint_basics/) and [examples/lint_advanced/](examples/lint_advanced/) directories for complete, runnable code.

---

## 5. SpyGlass CDC

### 5.1 Why CDC Matters

In modern SoCs, multiple clock domains are unavoidable. Data crossing from one clock domain to another without proper synchronization leads to **metastability** — a condition where a flip-flop's output is undefined for an unpredictable duration. Metastability can cause:

- Bit flips and data corruption
- FSM deadlocks or illegal state transitions
- System hangs that appear only in silicon (not in simulation)

CDC bugs are among the most dangerous because:
- They are **non-deterministic** — they may pass millions of simulation cycles, then fail in hardware
- They depend on **physical timing** — PVT (Process, Voltage, Temperature) variations change the failure rate
- They are **extremely hard to debug** in silicon

### 5.2 CDC Fundamentals

#### 5.2.1 What Is a Clock Domain Crossing?

A CDC occurs when a signal driven by a flip-flop in clock domain A is sampled by a flip-flop in clock domain B, where A and B are asynchronous (no guaranteed phase/frequency relationship).

```
     Domain A (clk_a)              Domain B (clk_b)
    ┌──────────┐                  ┌──────────┐
    │  FF_src  │──── CDC path ───▶│  FF_dst  │
    │          │   (danger zone)  │          │
    └──────────┘                  └──────────┘
```

#### 5.2.2 Metastability

When a flip-flop samples a signal that changes too close to its setup or hold time, the output may enter a metastable state — hovering between 0 and 1. The resolution time is probabilistic; adding synchronizer stages exponentially reduces the probability of failure.

**Mean Time Between Failures (MTBF):**

```
MTBF = e^(tr / τ) / (T₀ · f_clk · f_data)

Where:
  tr    = resolution time (one clock period of receiving domain)
  τ     = metastability time constant (technology-dependent)
  T₀    = metastability window (setup + hold violation window)
  f_clk = receiving clock frequency
  f_data = data transition rate
```

For a single flip-flop at 500 MHz, MTBF can be as low as *seconds*. A 2-stage synchronizer pushes it to *centuries*.

#### 5.2.3 Synchronization Schemes

| Scheme | Use Case | Latency | Throughput |
|--------|----------|---------|------------|
| **2-FF Synchronizer** | Single-bit control signals | 2–3 cycles | 1 bit/crossing |
| **Gray-code FIFO** | Multi-bit data buses | Pointer sync delay | High |
| **Handshake (req/ack)** | Infrequent multi-bit transfers | 4–6 cycles | Low |
| **Pulse synchronizer** | Edge/pulse transfer | 3–4 cycles | 1 pulse/crossing |
| **MUX synchronizer** | Multi-bit with enable | 2–3 cycles | Bus-width |

#### 5.2.4 Common CDC Violations

| Violation | Description | Risk |
|-----------|-------------|------|
| **No synchronizer** | Signal crosses domains with zero synchronization stages | Metastability |
| **Convergence** | Multiple CDC signals reconverge at a single point | Data incoherence |
| **Multi-bit CDC** | Bus crosses domain without gray coding or handshake | Partial update |
| **Glitch on CDC path** | Combinational logic on CDC path can produce glitches | Metastability |
| **Reset domain crossing** | Async reset used across domains without sync | Startup failures |

### 5.3 Running a CDC Flow

A typical CDC flow has two stages:

1. **CDC Setup (cdc_setup)** — Verify that clock and constraint definitions are correct
2. **CDC Verify (cdc_verify)** — Perform the actual crossing analysis

```tcl
# CDC flow script (see scripts/run_cdc.tcl)
new_project cdc_design -force

set_option projectwdir ./spyglass_output
set_option enableSV yes

read_file -type verilog examples/cdc_basics/async_fifo.v
read_file -type verilog examples/cdc_basics/two_ff_sync.v
read_file -type verilog examples/cdc_basics/cdc_top.v

set_option top cdc_top

# Constraints are CRITICAL for CDC — they define clock domains
read_file -type sgdc constraints/cdc_constraints.sgdc

# Stage 1: Verify constraint setup
current_goal cdc/cdc_setup
run_goal

# Stage 2: Full CDC verification
current_goal cdc/cdc_verify
run_goal

write_report spyglass_output/cdc_report.rpt
save_project
close_project
```

### 5.4 Practical CDC Examples

#### Example 1: Missing Synchronizer

**File:** [`examples/cdc_basics/missing_sync.v`](examples/cdc_basics/missing_sync.v)

The simplest CDC bug — a signal crosses domains with no synchronization:

```verilog
// Domain A generates a control signal
always @(posedge clk_a or negedge rst_n) begin
    if (!rst_n)
        req <= 1'b0;
    else
        req <= start;
end

// Domain B directly samples the unsynchronized signal — BUG!
always @(posedge clk_b or negedge rst_n) begin
    if (!rst_n)
        req_captured <= 1'b0;
    else
        req_captured <= req;  // METASTABILITY RISK!
end
```

**SpyGlass flags:** `Ac_cdc01 (Signal crosses clock domain without synchronizer)`

**Fix:** Insert a 2-FF synchronizer:

```verilog
reg req_sync1, req_sync2;
always @(posedge clk_b or negedge rst_n) begin
    if (!rst_n) begin
        req_sync1 <= 1'b0;
        req_sync2 <= 1'b0;
    end else begin
        req_sync1 <= req;
        req_sync2 <= req_sync1;
    end
end

// Use req_sync2 (safe, synchronized)
assign req_captured = req_sync2;
```

#### Example 2: Multi-Bit CDC (Gray Code FIFO)

**File:** [`examples/cdc_basics/multibit_cdc.v`](examples/cdc_basics/multibit_cdc.v)

Sending a binary-encoded multi-bit bus across clock domains is dangerous because bits change at different times:

```verilog
// BAD: Binary counter pointer crosses domain
// Binary 7→8 = 0111→1000 (all 4 bits change simultaneously)
// Receiver can sample any combination: 0000, 0001, ..., 1111
wire [3:0] wr_ptr_binary;
// Synchronizing each bit independently doesn't help —
// they can resolve at different times
```

**SpyGlass flags:** `Ac_cdc05 (Multi-bit signal crosses clock domain)`

**Fix:** Use Gray code encoding (only 1 bit changes per increment):

```verilog
// Gray code: only 1 bit changes at a time
// 7→8 in gray = 0100→1100 (only MSB changes)
wire [3:0] wr_ptr_gray = wr_ptr_binary ^ (wr_ptr_binary >> 1);
```

#### Example 3: Reconvergence

**File:** [`examples/cdc_advanced/reconvergence.v`](examples/cdc_advanced/reconvergence.v)

When multiple CDC signals recombine in the destination domain, even with individual synchronizers, the signals may be captured in different cycles:

```verilog
// Both signals are individually synchronized (2-FF each),
// but they reconverge at a MUX — the select and data can
// be from different "snapshots" of domain A
assign output = sel_sync2 ? data_a_sync2 : data_b_sync2;
```

**SpyGlass flags:** `Ac_cdc07 (Reconvergence of CDC signals)`

#### Example 4: Combinational Logic on CDC Path

**File:** [`examples/cdc_advanced/combo_on_cdc.v`](examples/cdc_advanced/combo_on_cdc.v)

Combinational logic between the source flip-flop and the first synchronizer stage can produce glitches that get captured as wrong values:

```verilog
// BAD: AND gate on CDC path can glitch
wire cdc_signal = src_reg_a & src_reg_b;
// If src_reg_a and src_reg_b update at slightly different times
// (within the same clk_a cycle), a glitch can appear on cdc_signal

// Synchronizer sees the glitch
always @(posedge clk_b) sync1 <= cdc_signal;  // May capture glitch!
```

**SpyGlass flags:** `Ac_cdc03 (Combinational logic on CDC path)`

**Fix:** Register the signal in the source domain first:

```verilog
// GOOD: Register in source domain, then synchronize
always @(posedge clk_a) cdc_signal_reg <= src_reg_a & src_reg_b;

always @(posedge clk_b) begin
    sync1 <= cdc_signal_reg;
    sync2 <= sync1;
end
```

See the [examples/cdc_basics/](examples/cdc_basics/), [examples/cdc_synchronizers/](examples/cdc_synchronizers/), and [examples/cdc_advanced/](examples/cdc_advanced/) directories for complete designs.

---

## 6. Constraints & SDC for SpyGlass

Constraints are **essential** for CDC analysis — without them, SpyGlass cannot determine which signals belong to which clock domain.

### 6.1 SGDC Constraint File

**File:** [`constraints/cdc_constraints.sgdc`](constraints/cdc_constraints.sgdc)

```tcl
# Define clocks
current_design cdc_top

# Primary clocks
sdc_data -file constraints/clocks.sdc

# Clock domain relationships
clock -name clk_a -period 10 -edge {0 5}
clock -name clk_b -period 7  -edge {0 3.5}

# Declare clocks as asynchronous
assume_clock_relationship -async clk_a clk_b

# Quasi-static signals (change only during reset/config)
quasi_static -name config_reg[*]

# Abstract CDC-safe modules (already verified)
abstract_port -module my_verified_sync -type cdc_safe
```

### 6.2 SDC Clock Definitions

**File:** [`constraints/clocks.sdc`](constraints/clocks.sdc)

```tcl
# SDC-format clock definitions
create_clock -name clk_a -period 10.0 [get_ports clk_a]
create_clock -name clk_b -period 7.0  [get_ports clk_b]

# Generated clock (PLL output)
create_generated_clock -name clk_pll \
    -source [get_ports clk_a] \
    -multiply_by 2 \
    [get_pins pll_inst/clk_out]

# Declare async relationship
set_clock_groups -asynchronous \
    -group [get_clocks clk_a] \
    -group [get_clocks clk_b]
```

### 6.3 Why Constraints Matter

| Without Constraints | With Constraints |
|---------------------|------------------|
| SpyGlass treats all clocks as synchronous | Correct async/sync relationships |
| False negatives (missed CDC violations) | Accurate CDC detection |
| Cannot identify quasi-static signals | Reduced false positives |
| No generated clock handling | Proper PLL/divider analysis |

---

## 7. Waivers

Not every SpyGlass violation is a real bug. Waivers let you formally document acknowledged violations.

### 7.1 Waiver File Format

**File:** [`waivers/lint_waivers.swl`](waivers/lint_waivers.swl)

```tcl
# Waive a specific rule on a specific signal
waive -rule W_164 -module counter_top -signal unused_debug_port \
    -comment "Debug port intentionally unloaded in production mode"

# Waive by pattern
waive -rule W_240 -module "*_tb" \
    -comment "Testbench modules — not synthesized"

# Waive CDC violation for a known-safe path
waive -rule Ac_cdc01 -from {clk_a:config_mode} -to {clk_b:config_mode_sync} \
    -comment "Quasi-static signal — only changes during reset"
```

### 7.2 Waiver Best Practices

1. **Always include a comment** explaining *why* the waiver is acceptable
2. **Be as specific as possible** — avoid broad wildcards
3. **Review waivers periodically** — design changes may invalidate old waivers
4. **Track waivers in version control** — treat them as design artifacts
5. **Require sign-off** — waivers should be reviewed by a senior engineer

---

## 8. Advanced Topics

### 8.1 Reset Domain Crossing (RDC)

SpyGlass can also verify reset tree integrity:

```tcl
# Enable RDC analysis
current_goal cdc/cdc_verify_struct
set_goal_option rdc yes
run_goal
```

Common RDC issues:
- Async reset used in synchronous reset domain
- Reset release not synchronized to destination clock
- Missing reset synchronizer after power-on

### 8.2 SpyGlass in CI/CD

SpyGlass can be integrated into continuous integration pipelines:

```bash
#!/bin/bash
# ci_spyglass.sh — Run SpyGlass checks and fail on errors

sg_shell -tcl scripts/run_lint.tcl -batch > lint.log 2>&1
LINT_ERRORS=$(grep -c "^Error" lint.log)

sg_shell -tcl scripts/run_cdc.tcl -batch > cdc.log 2>&1
CDC_ERRORS=$(grep -c "^Error" cdc.log)

if [ "$LINT_ERRORS" -gt 0 ] || [ "$CDC_ERRORS" -gt 0 ]; then
    echo "FAIL: $LINT_ERRORS lint errors, $CDC_ERRORS CDC errors"
    exit 1
fi
echo "PASS: All SpyGlass checks clean"
```

### 8.3 Incremental Analysis

For large designs, SpyGlass supports incremental runs that only re-analyze modified blocks:

```tcl
set_option incr_mode yes
set_option incr_refdir ./previous_run
```

### 8.4 Custom Rules (SpyGlass Rules API)

You can write custom lint rules using SpyGlass's Tcl-based rule API:

```tcl
# Custom rule: flag any register wider than 64 bits
proc check_wide_registers {design} {
    foreach reg [get_registers $design] {
        set width [get_attribute $reg width]
        if {$width > 64} {
            report_violation -rule CUSTOM_001 \
                -message "Register $reg is $width bits wide (>64)" \
                -severity warning
        }
    }
}
```

---

## 9. Best Practices & Methodology

### 9.1 Lint Best Practices

| Practice | Rationale |
|----------|-----------|
| Run lint early and often | Catching issues early is cheaper; run on every commit |
| Start with `lint_rtl` goal | Covers the most critical structural checks |
| Fix errors before warnings | Errors indicate functional risk |
| Use `STARC` rules | Industry-proven methodology rules |
| Create a project-wide waiver policy | Prevents waiver abuse |
| Treat lint like compiler warnings | Zero-warning policy for production code |

### 9.2 CDC Best Practices

| Practice | Rationale |
|----------|-----------|
| Define all clocks in constraints | CDC analysis is only as good as its clock definitions |
| Verify `cdc_setup` before `cdc_verify` | Ensures constraints are correct before analysis |
| Use proven synchronizer library cells | Don't hand-code synchronizers; use verified cells |
| Synchronize resets in each domain | Async reset deassertion must be synchronous |
| Avoid combinational logic on CDC paths | Glitches on CDC inputs can cause metastability |
| Prefer gray-coded FIFOs for data buses | Gray code guarantees single-bit transitions |
| Review ALL `Ac_cdc01` violations | Missing synchronizers are the highest-risk CDC issue |
| Use `quasi_static` constraints judiciously | Only for signals that truly never change during operation |

### 9.3 Design Methodology Checklist

```
□ All clocks defined in SDC/SGDC
□ Async clock relationships declared
□ All CDC paths have synchronizers
□ No combinational logic on CDC inputs
□ Multi-bit crossings use gray-code FIFO or handshake
□ Reset trees synchronized in each domain
□ Lint runs clean (zero errors, warnings waived or fixed)
□ CDC runs clean (zero Ac_cdc01 without waiver)
□ All waivers documented and signed off
□ SpyGlass integrated into CI pipeline
```

---

## 10. Troubleshooting

### Common Issues & Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| "Cannot find module X" | Missing source file | Add to `read_file` list or fix include path |
| Too many false CDC violations | Missing constraints | Define all clocks and async relationships in SGDC |
| Lint flags testbench code | TB files included | Exclude TB files or waive by module pattern |
| "Clock X not defined" in CDC | SDC missing clock | Add `create_clock` for all clock sources |
| SpyGlass hangs on elaboration | Recursive generate or large design | Use `set_option max_loop_count` and hierarchical analysis |
| Waiver not taking effect | Pattern mismatch | Check module/signal names; use `report_waiver` to debug |

### Useful Debug Commands

```tcl
# In sg_shell interactive mode:

# List all violations for a specific rule
report_violations -rule W_116

# Show clock domain information
report_clock_domains

# Show CDC crossings
report_crossings

# Debug constraint application
report_constraints

# Show design hierarchy
report_hierarchy
```

---

## 11. Repository Structure

```
.
├── README.md                              # This comprehensive tutorial
├── examples/
│   ├── lint_basics/
│   │   ├── latch_inference.v              # Unintended latch example
│   │   ├── width_mismatch.v               # Width mismatch example
│   │   ├── blocking_nonblocking.v         # Assignment type mixing
│   │   ├── fsm.v                          # FSM lint issues
│   │   └── counter.v                      # Undriven/unloaded signals
│   ├── lint_advanced/
│   │   ├── multidriven.v                  # Multi-driven signal
│   │   ├── array_index_oob.v             # Array index out of bounds
│   │   └── case_full_parallel.v          # Case statement analysis
│   ├── cdc_basics/
│   │   ├── missing_sync.v                 # Missing synchronizer
│   │   ├── two_ff_sync.v                  # 2-FF synchronizer
│   │   ├── multibit_cdc.v                # Multi-bit CDC issue
│   │   └── cdc_top.v                      # Top-level CDC testbed
│   ├── cdc_synchronizers/
│   │   ├── sync_2ff.v                     # 2-FF synchronizer
│   │   ├── sync_pulse.v                   # Pulse synchronizer
│   │   ├── sync_handshake.v               # Handshake synchronizer
│   │   └── sync_gray_fifo.v              # Gray-code async FIFO
│   └── cdc_advanced/
│       ├── reconvergence.v                # CDC reconvergence issue
│       ├── combo_on_cdc.v                 # Combinational on CDC path
│       └── reset_cdc.v                    # Reset domain crossing
├── scripts/
│   ├── run_lint.tcl                       # Lint flow script
│   ├── run_cdc.tcl                        # CDC flow script
│   └── run_all.tcl                        # Combined flow script
├── constraints/
│   ├── clocks.sdc                         # SDC clock definitions
│   ├── lint_constraints.sgdc              # Lint constraints
│   └── cdc_constraints.sgdc               # CDC constraints
├── waivers/
│   └── lint_waivers.swl                   # Example waiver file
└── docs/
    ├── spyglass_rule_reference.md         # Quick rule reference
    └── cdc_synchronizer_guide.md          # Synchronizer selection guide
```

---

## Further Reading

- [Synopsys SpyGlass Documentation](https://www.synopsys.com/verification/static-and-formal-verification/spyglass.html)
- Clifford E. Cummings, "Clock Domain Crossing (CDC) Design & Verification Techniques Using SystemVerilog" (SNUG 2008)
- Clifford E. Cummings, "Simulation and Synthesis Techniques for Asynchronous FIFO Design" (SNUG 2002)
- STARC RTL Design Style Guide

---

*This tutorial is part of a hands-on learning repository. All examples contain intentional issues for educational purposes. See individual files for detailed comments explaining each violation and its fix.*
