# Practical Example 1: ALU Verification

[&larr; Back to Main](../../README.md)

---

## Overview

This example demonstrates a complete UVM testbench for verifying a **4-operation ALU** (ADD, SUB, AND, OR). It covers all fundamental UVM concepts in a single, runnable project.

### DUT: Simple ALU

- 8-bit operands A and B
- 2-bit operation select (ADD, SUB, AND, OR)
- 9-bit result (8-bit + carry)
- Single-cycle latency

### Testbench Architecture

```
┌─────────────────────────────────────────────┐
│              alu_base_test                  │
│  ┌───────────────────────────────────────┐  │
│  │              alu_env                  │  │
│  │  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │  alu_agent   │  │ alu_scoreboard│  │  │
│  │  │ ┌──────────┐ │  └──────────────┘   │  │
│  │  │ │alu_seqr  │ │  ┌──────────────┐   │  │
│  │  │ │alu_driver│ │  │ alu_coverage │   │  │
│  │  │ │alu_monit.│ │  └──────────────┘   │  │
│  │  │ └──────────┘ │                     │  │
│  │  └──────────────┘                     │  │
│  └───────────────────────────────────────┘  │
│                    │                        │
│               ┌────┴────┐                   │
│               │   ALU   │                   │
│               └─────────┘                   │
└─────────────────────────────────────────────┘
```

## File Structure

| File | Description |
|------|-------------|
| `alu.sv` | DUT — the ALU module |
| `alu_if.sv` | SystemVerilog interface |
| `alu_pkg.sv` | Package with all testbench classes |
| `alu_txn.sv` | Transaction (sequence item) |
| `alu_sequence.sv` | Stimulus sequences |
| `alu_driver.sv` | Pin-level driver |
| `alu_monitor.sv` | Passive monitor |
| `alu_agent.sv` | Agent (driver + monitor + sequencer) |
| `alu_scoreboard.sv` | Result checker |
| `alu_coverage.sv` | Functional coverage collector |
| `alu_env.sv` | Top-level environment |
| `alu_test.sv` | Test classes |
| `tb_top.sv` | Top-level testbench module |

## How to Run

```bash
# Synopsys VCS
vcs -sverilog -ntb_opts uvm tb_top.sv +UVM_TESTNAME=alu_base_test
./simv +UVM_VERBOSITY=UVM_MEDIUM

# Cadence Xcelium
xrun -uvm -sv tb_top.sv +UVM_TESTNAME=alu_base_test +UVM_VERBOSITY=UVM_MEDIUM

# Siemens Questa
vlog -sv tb_top.sv
vsim -do "run -all" tb_top +UVM_TESTNAME=alu_base_test +UVM_VERBOSITY=UVM_MEDIUM
```

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `alu_base_test` | Random operations (100 transactions) |
| `alu_add_test` | Focused ADD testing with corner cases |
| `alu_exhaustive_test` | Tests all operation types systematically |
