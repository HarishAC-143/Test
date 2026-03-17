# Chapter 1: Introduction to Synopsys SpyGlass

## 1.1 What is SpyGlass?

SpyGlass is a **static analysis** platform from Synopsys that examines RTL source code *without* simulation. It catches a broad class of design issues that would otherwise surface late in the verification cycle — or worse, in silicon.

Static analysis is fundamentally different from simulation:

| Aspect | Simulation | SpyGlass Static Analysis |
|--------|-----------|--------------------------|
| Requires testbench | Yes | No |
| Coverage dependent | Yes | No (analyzes all paths) |
| Speed | Slow (time-domain) | Fast (structural) |
| Bug detection | Depends on stimulus | Exhaustive for covered rules |
| Catches CDC issues | Only if exercised | Structurally complete |

## 1.2 SpyGlass Product Family

SpyGlass is not a single tool — it is a family of analysis engines:

```
SpyGlass Platform
├── SpyGlass Lint          ─ RTL coding style, synthesis checks
├── SpyGlass CDC           ─ Clock domain crossing analysis
├── SpyGlass RDC           ─ Reset domain crossing analysis
├── SpyGlass DFT           ─ Design-for-test analysis
├── SpyGlass Power         ─ Power intent verification (UPF/CPF)
├── SpyGlass Constraints   ─ SDC constraint verification
└── SpyGlass Abstract      ─ Hierarchical analysis with abstracts
```

This tutorial focuses on **Lint** and **CDC**, the two most commonly used modules.

## 1.3 Why Use SpyGlass?

### Shift-Left Verification

SpyGlass enables "shift-left" — finding bugs earlier in the design cycle when they are cheapest to fix:

```
              Traditional Bug Discovery
              ─────────────────────────
RTL Coding ──► Simulation ──► Synthesis ──► STA ──► Silicon
                   ▲              ▲          ▲
                   │              │          │
               Lint bugs     CDC bugs   Timing bugs
              found here    found here  found here

              With SpyGlass
              ─────────────
RTL Coding ──► SpyGlass ──► Simulation ──► Synthesis ──► STA ──► Silicon
                  ▲
                  │
            Lint + CDC + RDC
            found here (early!)
```

### Common Issues Caught

**Lint catches:**
- Undriven or unloaded signals
- Width mismatches in assignments and connections
- Incomplete sensitivity lists
- Simulation/synthesis mismatches (latches from incomplete `if`/`case`)
- Dead code and unreachable states
- Naming convention violations

**CDC catches:**
- Missing synchronizers on clock domain crossings
- Multi-bit CDC without proper protocol
- Reconvergent clock domain paths
- Glitch-prone combinational logic on CDC paths
- FIFO pointer crossing issues

## 1.4 Installation and Setup

### Environment Setup

SpyGlass is typically installed in a shared location on a compute farm. Set up your environment:

```bash
# Option 1: Source the setup script
source /tools/synopsys/spyglass/2024.06/SPYGLASS_HOME/bin/spyglass_setup.sh

# Option 2: Set environment variables manually
export SPYGLASS_HOME=/tools/synopsys/spyglass/2024.06/SPYGLASS_HOME
export PATH=$SPYGLASS_HOME/bin:$PATH
export LM_LICENSE_FILE=27000@license_server:$LM_LICENSE_FILE
```

### Verify Installation

```bash
# Check SpyGlass version
spyglass -version

# Expected output (example):
# SpyGlass v2024.06 -- Built on Jun 15 2024
# Copyright (c) Synopsys, Inc.
```

## 1.5 Running SpyGlass

SpyGlass can run in three modes:

### GUI Mode

```bash
# Launch the GUI
spyglass -project my_project.prj &
```

The GUI provides:
- Interactive rule browsing and filtering
- Schematic cross-probing
- Waveform-like signal tracing
- Report generation and export

### Batch Mode

```bash
# Run in batch (no GUI)
spyglass -project my_project.prj -batch
```

Batch mode is essential for:
- Regression runs
- CI/CD integration
- Automated sign-off flows

### TCL Shell Mode

```bash
# Interactive TCL shell
spyglass -tcl

# Then at the spyglass prompt:
spyglass> read_file -type verilog my_design.v
spyglass> set_option top my_top_module
spyglass> run_goal lint/lint_rtl
spyglass> exit
```

## 1.6 SpyGlass Project File (.prj)

The project file is the central configuration for a SpyGlass run. Here is a minimal example:

```tcl
# my_project.prj

# Design files
read_file -type verilog {rtl/top.v rtl/sub_module.v}

# Set top module
set_option top top_module

# Enable specific goals
current_goal lint/lint_rtl

# Run the analysis
run_goal
```

### Key Project File Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `read_file` | Add RTL source files | `read_file -type verilog {a.v b.v}` |
| `set_option top` | Define the top-level module | `set_option top chip_top` |
| `current_goal` | Select analysis goal | `current_goal lint/lint_rtl` |
| `run_goal` | Execute the selected goal | `run_goal` |
| `read_file -type sgdc` | Read constraint file | `read_file -type sgdc cdc.sgdc` |
| `set_option enableSV` | Enable SystemVerilog | `set_option enableSV yes` |
| `waive` | Apply waiver | `waive -rule W_xxxx ...` |

## 1.7 SpyGlass Goals

A "goal" is a predefined set of rules targeting a specific analysis area:

### Lint Goals

| Goal | Description |
|------|-------------|
| `lint/lint_rtl` | Basic RTL lint checks |
| `lint/lint_turbo_rtl` | Faster subset of lint_rtl |
| `lint/lint_rtl_enhanced` | Extended lint including performance rules |
| `lint/lint_abstract` | Hierarchical lint with block abstracts |
| `lint/lint_functional_rtl` | Functional correctness checks |

### CDC Goals

| Goal | Description |
|------|-------------|
| `cdc/cdc_verify` | Basic CDC structural analysis |
| `cdc/cdc_verify_struct` | Structural-only CDC checks |
| `cdc/cdc_verify_functional` | Functional CDC verification |
| `cdc/cdc_abstract` | Hierarchical CDC with abstracts |

## 1.8 Understanding SpyGlass Output

SpyGlass generates results in the `spyglass_reports/` directory:

```
spyglass_reports/
├── moresimple.rpt            # Summary report
├── moresimple_RuleResults/   # Per-rule detailed results
│   ├── W_0001.rpt
│   ├── W_0123.rpt
│   └── ...
├── spyglass.log              # Execution log
└── consolidated_reports/
    ├── waiver_summary.rpt
    └── coverage.rpt
```

### Message Severity Levels

| Severity | Prefix | Meaning |
|----------|--------|---------|
| Fatal | `FatalError` | Cannot continue analysis |
| Error | `E_xxxx` | Definite design bug |
| Warning | `W_xxxx` | Likely design issue |
| Info | `I_xxxx` | Informational, review recommended |
| Lint | `L_xxxx` | Style/coding guideline |

### Example Message

```
Warning: [W_0123] Signal 'data_out' is driven but not loaded
  File: rtl/my_module.v, Line: 42
  Module: my_module
  Severity: Warning
  Rule: W_0123 (UnloadedNet)
```

## 1.9 Next Steps

- [Chapter 2: SpyGlass Lint Deep Dive](02_spyglass_lint.md) — Learn lint rules, common violations, and how to fix them.
- [Chapter 3: SpyGlass CDC Deep Dive](03_spyglass_cdc.md) — Understand clock domain crossing analysis.
