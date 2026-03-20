# UVM (Universal Verification Methodology) — Comprehensive Tutorial

A complete, hands-on guide to UVM covering fundamentals through advanced topics, with fully worked practical examples in SystemVerilog.

---

## Table of Contents

### Tutorials

| # | Topic | Description |
|---|-------|-------------|
| 1 | [UVM Basics](docs/01_uvm_basics.md) | Introduction, class hierarchy, and core components |
| 2 | [UVM Phases & Lifecycle](docs/02_uvm_phases.md) | Build, connect, run phases and phase synchronization |
| 3 | [UVM TLM & Communication](docs/03_uvm_tlm.md) | Transaction-Level Modeling, ports, exports, FIFOs |
| 4 | [Sequences & Sequencer](docs/04_uvm_sequences.md) | Sequence items, sequences, virtual sequences, sequencer arbitration |
| 5 | [Configuration & Factory](docs/05_uvm_config_factory.md) | `uvm_config_db`, factory overrides, parameterized components |
| 6 | [Advanced Topics](docs/06_uvm_advanced.md) | Register model (RAL), callbacks, coverage, objections, reporting |

### Practical Examples

| # | Example | Description |
|---|---------|-------------|
| 1 | [ALU Verification](examples/alu_verification/) | Complete testbench for a 4-operation ALU |
| 2 | [Memory Verification](examples/memory_verification/) | Read/write verification of a synchronous SRAM |
| 3 | [AXI-Lite Verification](examples/axi_lite_verification/) | Protocol-level verification of an AXI4-Lite slave |

---

## What is UVM?

The **Universal Verification Methodology (UVM)** is an industry-standard, open-source SystemVerilog library and methodology for building modular, reusable, and scalable verification environments. It was developed collaboratively by Accellera and is supported by all major EDA vendors (Synopsys, Cadence, Siemens EDA).

### Why UVM?

- **Reusability** — Components are designed to be reused across projects and teams.
- **Scalability** — The layered architecture supports everything from simple block-level to full-chip verification.
- **Standardization** — A single methodology understood across the industry.
- **Automation** — Phasing, factory, configuration database, and reporting reduce boilerplate.
- **Coverage-Driven** — Built-in support for functional coverage and constrained-random stimulus.

### Prerequisites

To follow this tutorial you should have a working knowledge of:

- SystemVerilog (classes, interfaces, constraints, covergroups)
- Basic digital design concepts (flip-flops, FSMs, protocols)
- A simulator that supports UVM 1.2 / IEEE 1800.2 (e.g., Synopsys VCS, Cadence Xcelium, Siemens Questa)

---

## Quick Start

Clone this repository and navigate to any example:

```bash
git clone https://github.com/HarishAC-143/Test.git
cd Test/examples/alu_verification
# Run with your simulator, for example:
# vcs -sverilog -ntb_opts uvm tb_top.sv
# xrun -uvm tb_top.sv
# vsim -do "run -all" tb_top.sv
```

Each example directory contains its own README with specific build and run instructions.

---

## UVM Testbench Architecture (High-Level)

```
┌─────────────────────────────────────────────────────┐
│                      uvm_test                       │
│  ┌───────────────────────────────────────────────┐  │
│  │                   uvm_env                     │  │
│  │  ┌──────────────┐     ┌───────────────────┐   │  │
│  │  │  uvm_agent   │     │   uvm_scoreboard  │   │  │
│  │  │ ┌──────────┐ │     │                   │   │  │
│  │  │ │ sequencer│ │     └───────────────────┘   │  │
│  │  │ ├──────────┤ │     ┌───────────────────┐   │  │
│  │  │ │  driver  │ │     │  uvm_subscriber   │   │  │
│  │  │ ├──────────┤ │     │   (coverage)      │   │  │
│  │  │ │ monitor  │ │     └───────────────────┘   │  │
│  │  │ └──────────┘ │                             │  │
│  │  └──────────────┘                             │  │
│  └───────────────────────────────────────────────┘  │
│                         │                           │
│                    ┌────┴────┐                       │
│                    │   DUT   │                       │
│                    └─────────┘                       │
└─────────────────────────────────────────────────────┘
```

---

## License

This tutorial content is provided under the [MIT License](LICENSE).

## Contributing

Contributions, corrections, and improvements are welcome. Please open an issue or submit a pull request.
