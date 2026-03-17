# Synopsys SpyGlass Lint & CDC Tutorial

A comprehensive, hands-on tutorial covering **Synopsys SpyGlass** for RTL Lint analysis and Clock Domain Crossing (CDC) verification, complete with practical Verilog examples, project scripts, constraint files, and waiver templates.

## What is SpyGlass?

Synopsys SpyGlass is an industry-standard static analysis platform for RTL designs. It identifies design issues early in the flow — before simulation or synthesis — saving significant debug time. Its two primary analysis domains are:

- **SpyGlass Lint** — Catches coding style violations, synthesis mismatches, potential simulation/synthesis discrepancies, undriven nets, width mismatches, FSM issues, and more.
- **SpyGlass CDC** — Identifies clock domain crossing issues such as missing synchronizers, reconvergence, glitch-prone paths, and data coherency problems.

## Repository Structure

```
.
├── README.md                              # This file
├── docs/
│   ├── 01_introduction.md                 # SpyGlass overview and setup
│   ├── 02_spyglass_lint.md                # Lint analysis deep dive
│   ├── 03_spyglass_cdc.md                 # CDC analysis deep dive
│   ├── 04_practical_workflow.md           # End-to-end workflow guide
│   └── 05_advanced_topics.md              # Advanced techniques & best practices
├── examples/
│   ├── lint/
│   │   ├── rtl/
│   │   │   ├── counter_with_issues.v      # Counter with common lint issues
│   │   │   ├── counter_fixed.v            # Corrected counter
│   │   │   ├── fsm_with_issues.v          # FSM with lint violations
│   │   │   ├── fsm_fixed.v               # Corrected FSM
│   │   │   └── memory_controller.v        # Memory controller example
│   │   ├── scripts/
│   │   │   ├── run_lint.tcl               # Lint analysis TCL script
│   │   │   └── lint_setup.prj             # SpyGlass project file for lint
│   │   └── waivers/
│   │       └── lint_waivers.swl           # Lint waiver examples
│   └── cdc/
│       ├── rtl/
│       │   ├── async_fifo.v               # Asynchronous FIFO with Gray code
│       │   ├── cdc_sync_examples.v        # Synchronizer building blocks
│       │   ├── pulse_synchronizer.v       # Pulse synchronizer
│       │   ├── handshake_sync.v           # Request/acknowledge handshake
│       │   └── cdc_violations.v           # Intentional CDC violations
│       ├── constraints/
│       │   ├── cdc_constraints.sgdc       # CDC constraint definitions
│       │   └── clock_definitions.sgdc     # Clock and reset definitions
│       ├── scripts/
│       │   ├── run_cdc.tcl                # CDC analysis TCL script
│       │   └── cdc_setup.prj              # SpyGlass project file for CDC
│       └── waivers/
│           └── cdc_waivers.swl            # CDC waiver examples
```

## Tutorial Roadmap

| Chapter | Topic | Key Takeaways |
|---------|-------|---------------|
| [01 — Introduction](docs/01_introduction.md) | SpyGlass overview, installation, GUI/batch modes | Understand the tool ecosystem |
| [02 — SpyGlass Lint](docs/02_spyglass_lint.md) | Lint rules, severity levels, common violations | Write cleaner, synthesis-safe RTL |
| [03 — SpyGlass CDC](docs/03_spyglass_cdc.md) | CDC fundamentals, synchronizers, SGDC constraints | Design reliable multi-clock systems |
| [04 — Practical Workflow](docs/04_practical_workflow.md) | End-to-end project setup and analysis | Run SpyGlass on your own designs |
| [05 — Advanced Topics](docs/05_advanced_topics.md) | Waivers, regression, CI integration, methodology | Scale SpyGlass across teams |

## Quick Start

```bash
# 1. Set up your environment (adjust path to your SpyGlass installation)
source /path/to/spyglass/bin/setup.sh

# 2. Run a basic lint check on the counter example
cd examples/lint
spyglass -project scripts/lint_setup.prj -batch

# 3. Run CDC analysis on the async FIFO example
cd ../cdc
spyglass -project scripts/cdc_setup.prj -batch
```

## Prerequisites

- Synopsys SpyGlass (2021.06 or later recommended)
- Basic knowledge of Verilog / SystemVerilog
- Understanding of digital design fundamentals (clocking, resets, FSMs)

## License

This tutorial is provided for educational purposes. The SpyGlass tool itself requires a valid Synopsys license.
