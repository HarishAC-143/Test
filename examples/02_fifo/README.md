# Example 2: Synchronous FIFO Verification

## Overview

This example demonstrates UVM verification of a parameterized synchronous FIFO. It focuses on:

- **Boundary conditions**: full, empty, overflow, underflow
- **Reference model scoreboard**: uses a SystemVerilog queue to mirror expected FIFO behavior
- **Flag verification**: checks `full` and `empty` flags against the reference model
- **Layered sequences**: fill-then-drain composed from simpler fill and drain sequences

## DUT Description

The FIFO is a synchronous, single-clock FIFO with configurable data width (default 8 bits) and depth (default 16 entries). It provides:
- `wr_en` / `rd_en`: write and read enables
- `full` / `empty`: status flags
- `count`: current occupancy

## File Structure

| File | Description |
|------|-------------|
| `fifo_if.sv` | FIFO interface |
| `fifo_dut.sv` | Parameterized synchronous FIFO |
| `fifo_seq_item.sv` | FIFO transaction |
| `fifo_driver.sv` | Drives FIFO signals |
| `fifo_monitor.sv` | Observes FIFO activity |
| `fifo_agent.sv` | FIFO agent |
| `fifo_scoreboard.sv` | Queue-based reference model |
| `fifo_coverage.sv` | Coverage for operations and boundary conditions |
| `fifo_env.sv` | Environment |
| `fifo_sequences.sv` | Fill, drain, random, overflow sequences |
| `fifo_tests.sv` | Test classes |
| `fifo_pkg.sv` | Package |
| `tb_top.sv` | Top-level testbench |

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `fifo_fill_drain_test` | Fills FIFO to capacity, then drains completely |
| `fifo_random_test` | 200 random read/write operations |
| `fifo_overflow_test` | Tests overflow boundary behavior |

## How to Run

```bash
# VCS
vcs -sverilog -ntb_opts uvm fifo_pkg.sv tb_top.sv fifo_dut.sv fifo_if.sv \
    +UVM_TESTNAME=fifo_fill_drain_test
./simv

# Questa
vlog -sv fifo_if.sv fifo_dut.sv fifo_pkg.sv tb_top.sv
vsim -c tb_top +UVM_TESTNAME=fifo_random_test -do "run -all"
```
