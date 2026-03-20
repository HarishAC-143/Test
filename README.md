# UVM (Universal Verification Methodology) - Comprehensive Tutorial

A complete guide to UVM covering fundamentals, advanced topics, and practical examples with fully annotated SystemVerilog code.

## Table of Contents

### Part 1: UVM Basics

| # | Topic | Description |
|---|-------|-------------|
| 1 | [Introduction to UVM](docs/basics/01_introduction.md) | What is UVM, why it matters, and how it fits into the verification flow |
| 2 | [UVM Class Hierarchy](docs/basics/02_class_hierarchy.md) | The complete UVM class tree — `uvm_object`, `uvm_component`, and their descendants |
| 3 | [UVM Components Deep Dive](docs/basics/03_components.md) | Driver, Monitor, Sequencer, Agent, Env, Scoreboard, and Test |
| 4 | [UVM Phases](docs/basics/04_phases.md) | Build, connect, run, and all other simulation phases |
| 5 | [Sequences and Sequence Items](docs/basics/05_sequences.md) | Transaction modeling, sequence creation, and sequencer-driver handshake |
| 6 | [UVM Factory](docs/basics/06_factory.md) | Object creation, type overrides, and instance overrides |
| 7 | [Configuration Database](docs/basics/07_config_db.md) | `uvm_config_db` for passing configuration across the testbench hierarchy |
| 8 | [TLM (Transaction Level Modeling)](docs/basics/08_tlm.md) | Ports, exports, FIFOs, and analysis ports for inter-component communication |
| 9 | [Reporting and Messaging](docs/basics/09_reporting.md) | `uvm_info`, `uvm_warning`, `uvm_error`, `uvm_fatal`, and verbosity control |

### Part 2: Advanced UVM

| # | Topic | Description |
|---|-------|-------------|
| 1 | [Virtual Sequences & Sequencers](docs/advanced/01_virtual_sequences.md) | Coordinating multiple agents with virtual sequences |
| 2 | [Register Abstraction Layer (RAL)](docs/advanced/02_ral.md) | Modeling and verifying memory-mapped registers |
| 3 | [Functional Coverage](docs/advanced/03_functional_coverage.md) | Coverage-driven verification with covergroups and cross coverage |
| 4 | [Callbacks](docs/advanced/04_callbacks.md) | Extending component behavior without modifying source code |
| 5 | [Advanced Sequences](docs/advanced/05_advanced_sequences.md) | Layered sequences, pipelining, and response handling |
| 6 | [UVM Patterns and Best Practices](docs/advanced/06_best_practices.md) | Reusability, coding guidelines, and common pitfalls |

### Part 3: Practical Examples

| # | Example | Description |
|---|---------|-------------|
| 1 | [ALU Testbench](examples/01_alu_testbench/) | Complete UVM testbench for a simple Arithmetic Logic Unit |
| 2 | [FIFO Verification](examples/02_fifo_verification/) | Synchronous FIFO verification with scoreboard and coverage |
| 3 | [RAL Example](examples/03_ral_example/) | Register verification using the UVM Register Abstraction Layer |
| 4 | [APB Protocol](examples/04_apb_protocol/) | APB bus protocol verification with master agent |

## Prerequisites

- Familiarity with SystemVerilog (classes, interfaces, constraints)
- A UVM-compatible simulator (Synopsys VCS, Cadence Xcelium, Mentor Questa, or Aldec Riviera-PRO)
- UVM 1.2 or IEEE 1800.2 UVM library

## How to Use This Tutorial

1. **Beginners** — Start with [Part 1: UVM Basics](docs/basics/01_introduction.md) and read sequentially.
2. **Intermediate users** — Jump to any basics chapter you need to review, then proceed to Part 2.
3. **Advanced users** — Browse Part 2 for specific topics and Part 3 for reference implementations.

Each practical example includes:
- Design Under Test (DUT) RTL
- Complete UVM testbench environment
- Multiple test scenarios
- A `README.md` explaining how to build and run

## Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd uvm-tutorial

# Run the ALU example (VCS)
cd examples/01_alu_testbench
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=alu_base_test

# Run the ALU example (Xcelium)
cd examples/01_alu_testbench
xrun -uvm -f filelist.f +UVM_TESTNAME=alu_base_test
```

## License

This tutorial is provided for educational purposes. Feel free to use and adapt the examples in your own projects.
