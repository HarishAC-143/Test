# UVM Tutorial: From Basics to Advanced

A comprehensive tutorial on the **Universal Verification Methodology (UVM)** with detailed explanations and complete, runnable practical examples in SystemVerilog.

## Contents

### Tutorial Document

- **[`docs/uvm-tutorial.md`](docs/uvm-tutorial.md)** — Full tutorial covering 17 topics from fundamentals to advanced techniques:
  - UVM architecture and class hierarchy
  - Testbench components (driver, monitor, sequencer, agent, environment, test)
  - Sequences and sequence items with constraints
  - UVM phases and objections
  - Configuration database (`uvm_config_db`)
  - Factory pattern and type/instance overrides
  - TLM (Transaction Level Modeling) ports and communication
  - Reporting and messaging system
  - Register Abstraction Layer (RAL)
  - Callbacks
  - Virtual sequences and virtual sequencers
  - Coverage-driven verification
  - Scoreboards and checkers (in-order and out-of-order)
  - Best practices and common pitfalls

### Practical Examples

Each example is a self-contained UVM testbench with a DUT, full verification environment, and multiple test scenarios.

| # | Example | Directory | Key Concepts |
|---|---------|-----------|-------------|
| 1 | **APB Slave Memory** | [`examples/01_apb_slave/`](examples/01_apb_slave/) | Complete agent, scoreboard with reference model, coverage, multiple sequences (random, write-read-back, walking-ones), active/passive agent mode |
| 2 | **Synchronous FIFO** | [`examples/02_fifo/`](examples/02_fifo/) | Queue-based reference model, boundary condition testing (full/empty/overflow), flag verification, layered sequences |
| 3 | **ALU (Arithmetic Logic Unit)** | [`examples/03_alu/`](examples/03_alu/) | 13 operations, constrained random with weighted distributions, corner-case directed testing, per-operation sweep, comprehensive coverage |

## Prerequisites

- A SystemVerilog simulator with UVM support (VCS, Questa/ModelSim, Xcelium, or Riviera-PRO)
- UVM 1.2 or UVM IEEE 1800.2 library (included with most simulators)

## Quick Start

```bash
# Navigate to any example directory
cd examples/01_apb_slave

# Run with VCS
vcs -sverilog -ntb_opts uvm apb_pkg.sv tb_top.sv apb_slave_dut.sv apb_if.sv \
    +UVM_TESTNAME=apb_write_read_test
./simv

# Run with Questa
vlog -sv apb_if.sv apb_slave_dut.sv apb_pkg.sv tb_top.sv
vsim -c tb_top +UVM_TESTNAME=apb_write_read_test -do "run -all"

# Run with Xcelium
xrun -sv -uvm apb_if.sv apb_slave_dut.sv apb_pkg.sv tb_top.sv \
    +UVM_TESTNAME=apb_write_read_test
```

## Repository Structure

```
├── README.md
├── docs/
│   └── uvm-tutorial.md          # Comprehensive tutorial document
└── examples/
    ├── 01_apb_slave/             # APB slave memory verification
    │   ├── apb_if.sv
    │   ├── apb_slave_dut.sv
    │   ├── apb_seq_item.sv
    │   ├── apb_driver.sv
    │   ├── apb_monitor.sv
    │   ├── apb_sequencer.sv
    │   ├── apb_agent.sv
    │   ├── apb_scoreboard.sv
    │   ├── apb_coverage.sv
    │   ├── apb_env.sv
    │   ├── apb_sequences.sv
    │   ├── apb_tests.sv
    │   ├── apb_pkg.sv
    │   ├── tb_top.sv
    │   └── README.md
    ├── 02_fifo/                  # Synchronous FIFO verification
    │   ├── fifo_if.sv
    │   ├── fifo_dut.sv
    │   ├── fifo_seq_item.sv
    │   ├── fifo_driver.sv
    │   ├── fifo_monitor.sv
    │   ├── fifo_agent.sv
    │   ├── fifo_scoreboard.sv
    │   ├── fifo_coverage.sv
    │   ├── fifo_env.sv
    │   ├── fifo_sequences.sv
    │   ├── fifo_tests.sv
    │   ├── fifo_pkg.sv
    │   ├── tb_top.sv
    │   └── README.md
    └── 03_alu/                   # ALU verification
        ├── alu_if.sv
        ├── alu_dut.sv
        ├── alu_seq_item.sv
        ├── alu_driver.sv
        ├── alu_monitor.sv
        ├── alu_agent.sv
        ├── alu_scoreboard.sv
        ├── alu_coverage.sv
        ├── alu_env.sv
        ├── alu_sequences.sv
        ├── alu_tests.sv
        ├── alu_pkg.sv
        ├── tb_top.sv
        └── README.md
```

## License

This tutorial and all examples are provided for educational purposes.
