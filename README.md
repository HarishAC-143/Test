# Synopsys SpyGlass Lint & CDC — Comprehensive Tutorial

A hands-on tutorial covering **SpyGlass Lint** (RTL design rule checking) and **SpyGlass CDC** (Clock Domain Crossing analysis) with practical Verilog/SystemVerilog examples, project setup, constraint files, waiver files, and step-by-step explanations.

---

## Table of Contents

1. [What is SpyGlass?](#1-what-is-spyglass)
2. [SpyGlass Lint Overview](#2-spyglass-lint-overview)
3. [SpyGlass CDC Overview](#3-spyglass-cdc-overview)
4. [Installation & Environment Setup](#4-installation--environment-setup)
5. [Project Setup & Flow](#5-project-setup--flow)
6. [Lint Rules & Categories](#6-lint-rules--categories)
7. [CDC Fundamentals](#7-cdc-fundamentals)
8. [Practical Examples — Lint](#8-practical-examples--lint)
9. [Practical Examples — CDC](#9-practical-examples--cdc)
10. [Constraints & SDC for CDC](#10-constraints--sdc-for-cdc)
11. [Waivers](#11-waivers)
12. [Common SpyGlass Messages & Fixes](#12-common-spyglass-messages--fixes)
13. [Methodology & Best Practices](#13-methodology--best-practices)
14. [Running SpyGlass — Command Reference](#14-running-spyglass--command-reference)
15. [Directory Structure](#15-directory-structure)
16. [Further Reading](#16-further-reading)

---

## 1. What is SpyGlass?

**Synopsys SpyGlass** is an industry-leading static analysis platform for RTL (Register Transfer Level) designs. It performs automated checks *before* synthesis and simulation, catching design issues early in the development cycle.

SpyGlass operates in several modes:

| Mode | Purpose |
|------|---------|
| **SpyGlass Lint** | RTL design rule checking — coding style, synthesizability, naming conventions, resets, clocks |
| **SpyGlass CDC** | Clock Domain Crossing analysis — identifies unsafe multi-clock interactions |
| **SpyGlass RDC** | Reset Domain Crossing analysis — detects reset-related issues across domains |
| **SpyGlass DFT** | Design-for-Test analysis — scan chain, ATPG readiness |
| **SpyGlass Power** | Low-power analysis — UPF/CPF checks |
| **SpyGlass Constraints** | SDC constraint validation |

This tutorial focuses on **Lint** and **CDC**, the two most commonly used modes.

### Why Use SpyGlass?

- **Shift-left verification**: Catch bugs before simulation or synthesis
- **Faster turnaround**: Static analysis runs in minutes vs. hours for simulation
- **Coverage**: Exhaustive path analysis that simulation may miss
- **Standards compliance**: Enforces coding guidelines (e.g., Madhyastha, RMM)
- **Sign-off quality**: Many fabs and IP vendors require clean SpyGlass reports

---

## 2. SpyGlass Lint Overview

SpyGlass Lint performs structural and semantic analysis on RTL code. It checks for issues that can cause:

- Simulation/synthesis mismatches
- Non-synthesizable constructs
- Unintended latches
- Unused or undriven signals
- Improper clock/reset usage
- Coding guideline violations

### Lint Rule Categories

| Category | What It Checks |
|----------|----------------|
| **W (Warning)** | Potential issues that may cause functional bugs |
| **E (Error)** | Definite errors that must be fixed |
| **I (Info)** | Informational messages for review |
| **FatalError** | Structural issues preventing analysis |

### Key Lint Rule Families

| Rule Family | Prefix | Description |
|-------------|--------|-------------|
| Structural | `W_xxx`, `E_xxx` | Basic RTL structure checks |
| Synthesis | `SYNTH_xxx` | Synthesizability checks |
| Simulation | `SIM_xxx` | Simulation-related checks |
| Naming | `NAME_xxx` | Signal/module naming conventions |
| Clock | `CLK_xxx` | Clock usage rules |
| Reset | `RST_xxx` | Reset usage rules |
| FSM | `FSM_xxx` | Finite state machine checks |
| Combo Loop | `COMBO_xxx` | Combinational loop detection |

### Common Lint Rules (Detailed)

#### W_REGS_ARST — Asynchronous Reset Missing
Flags flip-flops that lack an asynchronous reset, which can cause unknown states at power-up.

#### W_UNDRIVEN — Undriven Signal
A signal is declared but never assigned a value. This results in an `X` in simulation and undefined behavior in synthesis.

#### W_UNUSED — Unused Signal
A signal is assigned but its value is never read. This indicates dead code or incomplete connectivity.

#### W_LATCH — Unintended Latch Inference
An `always` block with incomplete case/if-else branches infers a latch instead of combinational logic.

#### W_COMBO_LOOP — Combinational Feedback Loop
The output of combinational logic feeds back to its own input without a register, creating a race condition.

#### SYNTH_5130 — Non-Synthesizable Construct
Code uses constructs (`#delay`, `initial`, `$display`) that have no hardware equivalent.

#### W_MULTI_DRIVE — Multiple Drivers
A signal is driven from multiple `always` blocks or `assign` statements, causing contention.

---

## 3. SpyGlass CDC Overview

Clock Domain Crossing (CDC) is one of the most critical verification challenges in multi-clock designs. **SpyGlass CDC** identifies signals that cross from one clock domain to another without proper synchronization.

### Why CDC Matters

When a signal crosses clock domains without synchronization:
- **Metastability**: The receiving flip-flop may enter an indeterminate state
- **Data corruption**: Multi-bit signals may be sampled at different times (data incoherence)
- **Functional failures**: Intermittent, hard-to-debug bugs in silicon

### CDC Analysis Phases

SpyGlass CDC analysis proceeds in stages:

```
1. Clock Tree Analysis    → Identify all clocks and their relationships
2. Domain Classification  → Assign every flip-flop to a clock domain
3. Crossing Identification→ Find signals that cross domain boundaries
4. Synchronizer Detection → Check if proper synchronizers exist
5. Protocol Verification  → Verify multi-bit crossing schemes (Gray, handshake, FIFO)
6. Reconvergence Analysis → Detect reconvergent CDC paths
```

### Types of CDC Crossings

| Crossing Type | Risk Level | Required Synchronizer |
|---------------|------------|----------------------|
| Single-bit, unrelated clocks | High | 2-FF synchronizer |
| Single-bit, related clocks (integer ratio) | Medium | May need synchronizer depending on phase |
| Multi-bit, unrelated clocks | Critical | Gray code / handshake / async FIFO |
| Reset crossing | High | Reset synchronizer |
| Multi-bit reconvergent | Critical | MUX-recirculation or handshake protocol |

### Key CDC Rules

| Rule ID | Description |
|---------|-------------|
| `Ac_cdc01` | Signal crosses clock domain without synchronizer |
| `Ac_cdc02` | Multi-bit signal crosses without proper encoding |
| `Ac_cdc03` | Combinational logic on CDC path before synchronizer |
| `Ac_cdc04` | Reconvergent CDC paths (data coherence risk) |
| `Ac_cdc05` | FIFO pointer not Gray-coded |
| `Ac_cdc06` | Glitch on CDC path |
| `Ac_cdc07` | Reset synchronization issue |
| `Ac_unsync_rst` | Asynchronous reset not synchronized |

---

## 4. Installation & Environment Setup

### Prerequisites

- Synopsys SpyGlass license (contact Synopsys for evaluation)
- Linux operating system (RHEL/CentOS 7+ recommended)
- TCL 8.5+

### Environment Variables

```bash
# Add to your .bashrc or .cshrc
export SPYGLASS_HOME=/path/to/spyglass/installation
export PATH=$SPYGLASS_HOME/bin:$PATH
export LM_LICENSE_FILE=port@license_server

# Optional: Set methodology directory
export SPYGLASS_METHODOLOGY=$SPYGLASS_HOME/GuideWare/latest/block/rtl_handoff
```

### Verify Installation

```bash
# Check SpyGlass version
spyglass -version

# Launch SpyGlass GUI
spyglass &

# Run SpyGlass in batch mode
spyglass -batch -project my_project.prj
```

---

## 5. Project Setup & Flow

### SpyGlass Project File (`.prj`)

The project file is the central configuration for a SpyGlass run. See [`scripts/spyglass_project.prj`](scripts/spyglass_project.prj) for a complete example.

A minimal project file:

```tcl
# Project configuration
set_option projectwdir ./spyglass_output

# Read design files
read_file -type verilog examples/lint_issues/counter_with_issues.v
read_file -type verilog examples/cdc_issues/cdc_bad_sync.v

# Set top module
set_option top my_top_module

# Set goals
current_goal lint/lint_rtl
run_goal

current_goal cdc/cdc_verify
run_goal
```

### SpyGlass Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    SpyGlass Flow                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │ RTL Code │───▶│ Project File │───▶│  SpyGlass     │  │
│  │ (.v/.sv) │    │   (.prj)     │    │  Engine       │  │
│  └──────────┘    └──────────────┘    └───────┬───────┘  │
│                                              │          │
│  ┌──────────┐    ┌──────────────┐            │          │
│  │ SDC/SGDC │───▶│ Constraints  │────────────┤          │
│  │ Files    │    │              │            │          │
│  └──────────┘    └──────────────┘            │          │
│                                              │          │
│  ┌──────────┐    ┌──────────────┐            ▼          │
│  │ Waiver   │───▶│  Waiver DB   │    ┌───────────────┐  │
│  │ Files    │    │              │───▶│  Reports      │  │
│  └──────────┘    └──────────────┘    │  & Analysis   │  │
│                                      └───────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Running SpyGlass

```bash
# Batch mode (recommended for CI/CD)
spyglass -batch -project scripts/spyglass_project.prj

# GUI mode (for interactive debugging)
spyglass -project scripts/spyglass_project.prj

# Command-line goal execution
sg_shell -tcl scripts/run_lint.tcl
sg_shell -tcl scripts/run_cdc.tcl
```

---

## 6. Lint Rules & Categories

### Goal Hierarchy

SpyGlass Lint organizes rules into **goals** (predefined rule sets):

```
lint/
├── lint_rtl              ← Basic RTL checks (start here)
├── lint_rtl_enhanced     ← Extended RTL checks
├── lint_turbo_rtl        ← Fast subset of lint_rtl
├── lint_functional_rtl   ← Functional correctness
├── lint_abstract         ← High-level structural checks
└── lint_synthesis        ← Synthesis-specific checks
```

### Severity Levels

```
Fatal   → Analysis cannot proceed; must fix immediately
Error   → Definite design bug; must fix before tapeout
Warning → Likely bug or poor practice; review required
Info    → FYI; may be benign but worth reviewing
```

### Example: Running Lint Goals

```tcl
# In sg_shell or .prj file
current_goal lint/lint_rtl
set_goal_option default

# Optionally restrict to specific rules
set_parameter handle_warns_as_errors {W_LATCH W_COMBO_LOOP}

run_goal
```

---

## 7. CDC Fundamentals

### The Metastability Problem

When a signal from clock domain A is captured by a flip-flop in clock domain B, the setup/hold time requirements of the receiving flip-flop may be violated. This puts the flop in a **metastable** state — an indeterminate voltage between logic 0 and 1.

```
Clock Domain A          Clock Domain B
                ┌───┐
  sig_a ───────▶│ FF│──── sig_b_meta (potentially metastable!)
                │   │
         clk_b ─┤>  │
                └───┘

  If sig_a changes too close to clk_b's active edge,
  FF output can be metastable for an indeterminate time.
```

### Two-Flip-Flop Synchronizer

The standard solution for single-bit CDC is a **2-FF synchronizer**:

```
Clock Domain A            Clock Domain B
                 ┌───┐    ┌───┐
  sig_a ────────▶│FF1│───▶│FF2│───▶ sig_b_sync (safe)
                 │   │    │   │
          clk_b ─┤>  │    ┤>  │
                 └───┘    └───┘
                 sync1    sync2

  FF1 may go metastable, but has a full clock period to resolve.
  FF2 captures the resolved value → safe to use in domain B.
```

Mean Time Between Failures (MTBF) for a 2-FF synchronizer:

```
MTBF = e^(tr / τ) / (T₀ · f_clk · f_data)

Where:
  tr   = resolution time (one clock period of receiving clock)
  τ    = metastability time constant (technology dependent)
  T₀   = metastability window
  f_clk = receiving clock frequency
  f_data = data transition rate
```

For modern technologies at GHz frequencies, 2-FF synchronizers typically achieve MTBF > 100 years.

### Multi-Bit CDC Strategies

Passing multiple bits across clock domains requires special techniques because individual bits may be sampled at different clock edges:

#### Gray Code Encoding
Used for counters/pointers (e.g., FIFO read/write pointers):

```
Binary: 000 001 010 011 100 101 110 111
Gray:   000 001 011 010 110 111 101 100

Property: Only one bit changes between consecutive values.
Even if sampled at the wrong time, the error is at most ±1.
```

#### Handshake Protocol
Used for irregular multi-bit data:

```
Domain A                          Domain B
   │                                 │
   ├── data_out = new_data           │
   ├── req ──────────────────────▶   │
   │                       sample data
   │   ◀──────────────────── ack ────┤
   ├── data_out = next or idle       │
   │                                 │
```

#### Asynchronous FIFO
For streaming data between domains:

```
┌─────────────────────────────────────┐
│          Async FIFO                  │
│                                      │
│  wr_clk ──▶ [Write Logic]           │
│              │                       │
│              ▼                       │
│         ┌─────────┐                  │
│         │  Memory  │                 │
│         │ (Dual    │                 │
│         │  Port)   │                 │
│         └─────────┘                  │
│              │                       │
│              ▼                       │
│  rd_clk ──▶ [Read Logic]            │
│                                      │
│  wr_ptr (Gray) ─── 2FF sync ──▶     │
│  rd_ptr (Gray) ◀── 2FF sync ───     │
└─────────────────────────────────────┘
```

---

## 8. Practical Examples — Lint

All example files are in the [`examples/`](examples/) directory.

### Example 1: Counter with Common Lint Issues

**File**: [`examples/lint_issues/counter_with_issues.v`](examples/lint_issues/counter_with_issues.v)

This file demonstrates several lint violations:
- Missing async reset on flip-flops (`W_REGS_ARST`)
- Undriven signal (`W_UNDRIVEN`)
- Unused signal (`W_UNUSED`)
- Width mismatch in assignment (`W_ASSIGN_TRUNCATE`)
- Incomplete sensitivity list (`W_SENSITIVITY`)

**Fixed version**: [`examples/lint_fixed/counter_fixed.v`](examples/lint_fixed/counter_fixed.v)

### Example 2: Latch Inference & Combinational Loops

**File**: [`examples/lint_issues/latch_and_combo.v`](examples/lint_issues/latch_and_combo.v)

Demonstrates:
- Unintended latch from incomplete `case` (`W_LATCH`)
- Combinational feedback loop (`W_COMBO_LOOP`)
- Non-synthesizable constructs (`SYNTH_5130`)

**Fixed version**: [`examples/lint_fixed/latch_and_combo_fixed.v`](examples/lint_fixed/latch_and_combo_fixed.v)

### Example 3: FSM Lint Issues

**File**: [`examples/lint_issues/fsm_issues.v`](examples/lint_issues/fsm_issues.v)

Demonstrates:
- Unreachable states (`FSM_xxx`)
- Dead-end states
- Missing default in case statement
- Output encoded in state (one-hot issues)

**Fixed version**: [`examples/lint_fixed/fsm_fixed.v`](examples/lint_fixed/fsm_fixed.v)

---

## 9. Practical Examples — CDC

### Example 4: Missing Synchronizer

**File**: [`examples/cdc_issues/cdc_missing_sync.v`](examples/cdc_issues/cdc_missing_sync.v)

Signal crosses from `clk_a` domain to `clk_b` domain without any synchronization. SpyGlass reports `Ac_cdc01`.

**Fixed version**: [`examples/cdc_fixed/cdc_with_sync.v`](examples/cdc_fixed/cdc_with_sync.v)

### Example 5: Multi-Bit CDC Without Gray Encoding

**File**: [`examples/cdc_issues/cdc_multibit_bad.v`](examples/cdc_issues/cdc_multibit_bad.v)

A multi-bit bus crosses domains using simple 2-FF synchronizers per bit — incorrect because bits can be sampled at different edges.

**Fixed version**: [`examples/cdc_fixed/cdc_multibit_gray.v`](examples/cdc_fixed/cdc_multibit_gray.v)

### Example 6: Combinational Logic Before Synchronizer

**File**: [`examples/cdc_issues/cdc_combo_before_sync.v`](examples/cdc_issues/cdc_combo_before_sync.v)

Combinational logic between the source flip-flop and the synchronizer can introduce glitches.

**Fixed version**: [`examples/cdc_fixed/cdc_combo_fixed.v`](examples/cdc_fixed/cdc_combo_fixed.v)

### Example 7: Async FIFO with CDC

**File**: [`examples/practical/async_fifo.v`](examples/practical/async_fifo.v)

A complete asynchronous FIFO implementation showing proper Gray-code pointer synchronization.

### Example 8: Reset Synchronizer

**File**: [`examples/practical/reset_synchronizer.v`](examples/practical/reset_synchronizer.v)

Proper synchronization of asynchronous reset de-assertion.

---

## 10. Constraints & SDC for CDC

SpyGlass CDC requires clock definitions and domain constraints to perform accurate analysis. See [`constraints/`](constraints/) directory.

### SGDC Constraint File

**File**: [`constraints/cdc_constraints.sgdc`](constraints/cdc_constraints.sgdc)

Key constraint types:

```tcl
# Define clocks
current_design top_module
create_clock -name clk_a -period 10 [get_ports clk_a]
create_clock -name clk_b -period 7  [get_ports clk_b]

# Declare clocks as asynchronous
set_clock_groups -asynchronous \
  -group {clk_a} \
  -group {clk_b}

# Identify quasi-static signals (don't need synchronization)
quasi_static -name cfg_mode_sel

# Identify test/scan signals
abstract_port -name scan_enable -clock {}
```

### SDC Constraints for SpyGlass

**File**: [`constraints/timing.sdc`](constraints/timing.sdc)

---

## 11. Waivers

Not every SpyGlass message is actionable. Some are false positives or accepted risks. **Waivers** suppress specific messages with documented justification.

**File**: [`waivers/lint_waivers.swl`](waivers/lint_waivers.swl)  
**File**: [`waivers/cdc_waivers.swl`](waivers/cdc_waivers.swl)

### Waiver Syntax

```tcl
# Waive a specific rule on a specific signal
waive -rule {W_UNUSED}
  -instance {u_top/u_debug/dbg_signal}
  -comment "Debug signal intentionally unused in production mode"

# Waive by module
waive -rule {W_REGS_ARST}
  -module {test_wrapper}
  -comment "Test wrapper does not need async reset"

# Waive CDC violation with justification
waive -rule {Ac_cdc01}
  -from {u_core/status_reg[0]}
  -to {u_host/status_sync[0]}
  -comment "Signal is quasi-static; changes only during configuration phase"
```

### Waiver Best Practices

1. **Always include a comment** explaining why the waiver is safe
2. **Be as specific as possible** — waive individual instances, not entire rules
3. **Review waivers periodically** — design changes may invalidate justifications
4. **Track waivers in version control** alongside the RTL
5. **Require sign-off** from a senior engineer for CDC waivers

---

## 12. Common SpyGlass Messages & Fixes

### Lint Messages

| Message | Meaning | Fix |
|---------|---------|-----|
| `W_REGS_ARST` | Flip-flop has no async reset | Add `posedge rst_n`/`negedge rst_n` to sensitivity list |
| `W_UNDRIVEN` | Signal has no driver | Connect signal or remove declaration |
| `W_UNUSED` | Signal value is never read | Remove signal or connect to output |
| `W_LATCH` | Latch inferred unintentionally | Complete all `if/else` and `case` branches or add `default` |
| `W_COMBO_LOOP` | Combinational feedback loop | Break loop with a flip-flop |
| `W_ASSIGN_TRUNCATE` | RHS wider than LHS | Match widths or explicitly truncate |
| `W_SENSITIVITY` | Incomplete sensitivity list | Use `always @(*)` or add missing signals |
| `W_MULTI_DRIVE` | Multiple drivers on signal | Ensure only one `always`/`assign` drives the signal |
| `SYNTH_5130` | Non-synthesizable construct | Remove `#delays`, `initial`, `$display` from synthesizable code |
| `W_CONNECTED_X` | Port connected to constant X | Connect to valid signal or tie to 0/1 |

### CDC Messages

| Message | Meaning | Fix |
|---------|---------|-----|
| `Ac_cdc01` | No synchronizer on crossing | Add 2-FF synchronizer |
| `Ac_cdc02` | Multi-bit crossing unsynchronized | Use Gray code, handshake, or async FIFO |
| `Ac_cdc03` | Combo logic before synchronizer | Move logic after synchronizer or register output first |
| `Ac_cdc04` | Reconvergent CDC paths | Use MUX recirculation or handshake |
| `Ac_cdc05` | FIFO pointer not Gray-coded | Convert pointer to Gray before crossing |
| `Ac_cdc06` | Glitch possible on CDC path | Register signal in source domain before crossing |
| `Ac_cdc07` | Reset crossing issue | Use reset synchronizer |
| `Ac_unsync_rst` | Async reset not synchronized | Add reset synchronizer on de-assertion |
| `Ac_conv01` | Data/control convergence issue | Ensure data and control cross together |

---

## 13. Methodology & Best Practices

### Lint Methodology

```
1. Start with lint/lint_rtl goal (basic checks)
2. Fix all Errors first, then Warnings
3. Graduate to lint/lint_rtl_enhanced
4. Add waivers only after investigation
5. Run lint in CI/CD pipeline on every commit
6. Target: Zero errors, zero unwaived warnings
```

### CDC Methodology

```
1. Define all clocks and their relationships in SGDC
2. Run cdc/cdc_setup first to verify clock tree
3. Run cdc/cdc_verify for full analysis
4. Review all Ac_cdc01 violations — these are the highest priority
5. Add proper synchronizers for all crossings
6. Constrain quasi-static signals appropriately
7. Run cdc/cdc_verify_struct for structural checks
8. Generate CDC matrix report for documentation
```

### Design Guidelines for CDC-Clean RTL

1. **Register all outputs** before crossing domains
2. **Never put combinational logic** between source FF and synchronizer
3. **Use Gray code** for multi-bit counters/pointers crossing domains
4. **Use handshake protocols** for irregular multi-bit data
5. **Synchronize reset de-assertion** with the target clock
6. **Avoid reconvergent paths** — use a single synchronization point
7. **Document all CDC crossings** in a crossing matrix
8. **Instantiate synchronizer cells** from a library (not ad-hoc flops)

---

## 14. Running SpyGlass — Command Reference

### Batch Mode Commands

```bash
# Run lint on a design
spyglass -batch -project scripts/spyglass_project.prj -goal lint/lint_rtl

# Run CDC analysis
spyglass -batch -project scripts/spyglass_project.prj -goal cdc/cdc_verify

# Run with waiver file
spyglass -batch -project scripts/spyglass_project.prj \
  -goal lint/lint_rtl \
  -waiver waivers/lint_waivers.swl

# Generate HTML report
spyglass -batch -project scripts/spyglass_project.prj \
  -goal lint/lint_rtl \
  -report html
```

### sg_shell TCL Commands

```tcl
# Start sg_shell
sg_shell

# Load project
read_file -type sourcelist files.f
set_option top my_top

# Set and run goal
current_goal lint/lint_rtl
run_goal

# View results
report_results -type summary
report_results -type detail -rule W_LATCH

# Generate reports
write_report -type html -output reports/lint_report.html
write_report -type csv -output reports/lint_report.csv

# CDC-specific commands
current_goal cdc/cdc_verify
run_goal
report_cdc_matrix -output reports/cdc_matrix.csv
```

### Useful sg_shell Commands

```tcl
# List all available goals
list_goals

# Show rules in a goal
list_rules -goal lint/lint_rtl

# Get help on a specific rule
help_rule W_LATCH

# Show design hierarchy
report_hierarchy

# Show clock tree
report_clock_tree

# Show CDC crossings
report_cdc_crossings

# Enable/disable specific rules
set_rule_status -rule {W_UNUSED} -status disable
set_rule_status -rule {W_LATCH} -status enable

# Set rule severity
set_parameter handle_warns_as_errors {W_COMBO_LOOP W_LATCH}
```

---

## 15. Directory Structure

```
.
├── README.md                              ← This tutorial
├── docs/
│   ├── lint_rule_reference.md             ← Detailed lint rule explanations
│   └── cdc_synchronizer_patterns.md       ← CDC synchronizer design patterns
├── examples/
│   ├── lint_issues/                       ← RTL with intentional lint violations
│   │   ├── counter_with_issues.v
│   │   ├── latch_and_combo.v
│   │   └── fsm_issues.v
│   ├── lint_fixed/                        ← Corrected versions
│   │   ├── counter_fixed.v
│   │   ├── latch_and_combo_fixed.v
│   │   └── fsm_fixed.v
│   ├── cdc_issues/                        ← RTL with CDC violations
│   │   ├── cdc_missing_sync.v
│   │   ├── cdc_multibit_bad.v
│   │   └── cdc_combo_before_sync.v
│   ├── cdc_fixed/                         ← Corrected CDC designs
│   │   ├── cdc_with_sync.v
│   │   ├── cdc_multibit_gray.v
│   │   └── cdc_combo_fixed.v
│   └── practical/                         ← Complete practical examples
│       ├── async_fifo.v
│       ├── reset_synchronizer.v
│       └── multi_clock_system.v
├── scripts/
│   ├── spyglass_project.prj               ← Main project file
│   ├── run_lint.tcl                        ← Lint TCL script
│   ├── run_cdc.tcl                         ← CDC TCL script
│   └── filelist.f                          ← Design file list
├── constraints/
│   ├── cdc_constraints.sgdc                ← CDC constraints
│   └── timing.sdc                          ← Timing constraints
└── waivers/
    ├── lint_waivers.swl                    ← Lint waivers
    └── cdc_waivers.swl                     ← CDC waivers
```

---

## 16. Further Reading

- [Synopsys SpyGlass Documentation](https://www.synopsys.com/verification/static-and-formal-verification/spyglass.html)
- Clifford E. Cummings, "Clock Domain Crossing (CDC) Design & Verification Techniques Using SystemVerilog" (SNUG 2008)
- Clifford E. Cummings, "Simulation and Synthesis Techniques for Asynchronous FIFO Design" (SNUG 2002)
- IEEE Std 1364-2005 (Verilog)
- IEEE Std 1800-2017 (SystemVerilog)

---

*This tutorial is part of a series on VLSI/ASIC design verification. For questions or contributions, please open an issue.*
