# Practical Example 2: Synchronous SRAM Verification

[&larr; Back to Main](../../README.md)

---

## Overview

This example demonstrates UVM verification of a **synchronous single-port SRAM**. It covers:

- Write-then-read verification with a reference memory model
- Address boundary testing
- Data integrity checks
- A TLM FIFO-based scoreboard comparing expected vs actual read data
- Functional coverage of address ranges, data patterns, and access types

### DUT: Synchronous SRAM

- 256 x 8-bit single-port SRAM
- 8-bit address, 8-bit data
- Write enable (`we`), chip select (`cs`)
- Synchronous read/write on clock rising edge

### What You'll Learn

- How to build a **reference model** inside the scoreboard
- Using **TLM analysis FIFOs** for decoupled checking
- **Directed sequences** for boundary testing
- **Constrained-random** sequences for broad coverage

## File Structure

| File | Description |
|------|-------------|
| `sram.sv` | DUT — synchronous SRAM |
| `mem_if.sv` | SystemVerilog interface |
| `mem_pkg.sv` | Package with all TB classes |
| `mem_txn.sv` | Transaction definition |
| `mem_sequence.sv` | Stimulus sequences |
| `mem_driver.sv` | Pin-level driver |
| `mem_monitor.sv` | Passive monitor |
| `mem_agent.sv` | Agent |
| `mem_scoreboard.sv` | Reference-model scoreboard |
| `mem_coverage.sv` | Functional coverage |
| `mem_env.sv` | Environment |
| `mem_test.sv` | Test classes |
| `tb_top.sv` | Top-level testbench |

## How to Run

```bash
# Synopsys VCS
vcs -sverilog -ntb_opts uvm tb_top.sv +UVM_TESTNAME=mem_base_test
./simv +UVM_VERBOSITY=UVM_MEDIUM

# Cadence Xcelium
xrun -uvm -sv tb_top.sv +UVM_TESTNAME=mem_base_test

# Siemens Questa
vlog -sv tb_top.sv
vsim -do "run -all" tb_top +UVM_TESTNAME=mem_base_test
```

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `mem_base_test` | Random read/write (200 transactions) |
| `mem_write_read_test` | Write-then-read-back on every address |
| `mem_boundary_test` | Tests first, last, and boundary addresses |
