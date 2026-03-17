# UVM Basics Tutorial

A comprehensive, hands-on tutorial covering the **Universal Verification Methodology (UVM)** for SystemVerilog-based hardware verification. This repository walks you through every foundational concept with clear explanations and fully worked practical examples.

---

## Who Is This For?

- Verification engineers learning UVM for the first time
- RTL designers who want to understand modern verification methodology
- Students studying digital design verification
- Anyone transitioning from directed testing to constrained-random, coverage-driven verification

## Prerequisites

- Working knowledge of SystemVerilog (classes, interfaces, constraints)
- Basic understanding of digital design concepts (combinational/sequential logic)
- A SystemVerilog simulator with UVM support (e.g., Synopsys VCS, Cadence Xcelium, Mentor Questa, or Verilator with UVM)

---

## Table of Contents

### Tutorial Chapters

| # | Chapter | Description |
|---|---------|-------------|
| 1 | [Introduction to UVM](docs/01_introduction.md) | What UVM is, why it exists, and the problems it solves |
| 2 | [UVM Class Hierarchy & Architecture](docs/02_class_hierarchy.md) | The class tree, base classes, and architectural patterns |
| 3 | [UVM Components](docs/03_components.md) | Driver, Monitor, Sequencer, Agent, Environment, and Test |
| 4 | [Transactions & Sequence Items](docs/04_transactions.md) | Modeling stimulus as objects with `uvm_sequence_item` |
| 5 | [UVM Sequences](docs/05_sequences.md) | Creating, composing, and controlling stimulus generation |
| 6 | [UVM Phases](docs/06_phases.md) | Build, connect, run, and other simulation phases |
| 7 | [TLM Ports & Communication](docs/07_tlm.md) | Transaction-level communication between components |
| 8 | [Configuration Database](docs/08_config_db.md) | Configuring components with `uvm_config_db` |
| 9 | [Reporting & Messaging](docs/09_reporting.md) | UVM's built-in logging, severity levels, and message control |

### Practical Examples

| # | Example | Description |
|---|---------|-------------|
| 1 | [ALU Verification](examples/01_alu_verification/) | Complete UVM testbench for a simple arithmetic logic unit |
| 2 | [Memory Verification](examples/02_memory_verification/) | Read/write verification of a synchronous memory model |
| 3 | [FIFO Verification](examples/03_fifo_verification/) | Verification of a synchronous FIFO with full/empty flags |

---

## Repository Structure

```
.
├── README.md                          # This file
├── docs/                              # Tutorial chapters
│   ├── 01_introduction.md
│   ├── 02_class_hierarchy.md
│   ├── 03_components.md
│   ├── 04_transactions.md
│   ├── 05_sequences.md
│   ├── 06_phases.md
│   ├── 07_tlm.md
│   ├── 08_config_db.md
│   └── 09_reporting.md
└── examples/                          # Practical verification examples
    ├── 01_alu_verification/
    │   ├── rtl/                       # Design under test
    │   ├── tb/                        # UVM testbench components
    │   └── README.md
    ├── 02_memory_verification/
    │   ├── rtl/
    │   ├── tb/
    │   └── README.md
    └── 03_fifo_verification/
        ├── rtl/
        ├── tb/
        └── README.md
```

---

## How to Use This Tutorial

1. **Read the chapters in order** — each chapter builds on the concepts introduced in the previous one.
2. **Study the code examples** — every chapter includes inline code snippets with detailed explanations.
3. **Run the practical examples** — each example directory contains a complete, self-contained testbench you can simulate.
4. **Experiment** — modify constraints, add new sequences, or extend coverage to deepen your understanding.

---

## Running the Examples

Each example directory contains its own `README.md` with specific instructions. The general flow for any simulator is:

```bash
# Using Synopsys VCS
vcs -sverilog -ntb_opts uvm <files> && ./simv

# Using Cadence Xcelium
xrun -uvm <files>

# Using Mentor Questa
vlog <files> && vsim -c work.tb_top -do "run -all"
```

---

## Quick Reference

| UVM Concept | Base Class | Purpose |
|-------------|-----------|---------|
| Component | `uvm_component` | Structural element that persists throughout simulation |
| Object | `uvm_object` | Transient data object (transactions, configurations) |
| Driver | `uvm_driver` | Converts transactions into pin-level activity |
| Monitor | `uvm_monitor` | Observes pin-level activity and creates transactions |
| Sequencer | `uvm_sequencer` | Arbitrates and routes sequences to a driver |
| Agent | `uvm_agent` | Groups driver + monitor + sequencer |
| Environment | `uvm_env` | Top-level container for agents and scoreboards |
| Test | `uvm_test` | Entry point that configures and starts the environment |
| Sequence | `uvm_sequence` | Generates a stream of transactions |
| Sequence Item | `uvm_sequence_item` | A single transaction object |

---

## License

This tutorial is provided for educational purposes. Feel free to use, modify, and distribute.
