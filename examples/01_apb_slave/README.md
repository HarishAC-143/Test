# Example 1: APB Slave Memory Verification

## Overview

This example demonstrates a complete UVM testbench for verifying a simple APB (AMBA Peripheral Bus) slave memory device. It covers all fundamental UVM concepts:

- **Sequence items** with constraints
- **Driver** that converts transactions to pin-level activity
- **Monitor** that passively observes the bus
- **Sequencer** that routes transactions
- **Agent** that encapsulates driver/monitor/sequencer
- **Scoreboard** with a reference memory model
- **Coverage collector** with functional covergroups
- **Environment** as a container
- **Multiple tests** demonstrating different scenarios

## File Structure

| File | Description |
|------|-------------|
| `apb_if.sv` | APB interface with clocking blocks |
| `apb_slave_dut.sv` | Simple 256-word memory DUT |
| `apb_seq_item.sv` | APB transaction class |
| `apb_driver.sv` | Drives APB protocol on the bus |
| `apb_monitor.sv` | Observes and collects transactions |
| `apb_sequencer.sv` | Routes sequence items |
| `apb_agent.sv` | Groups driver, monitor, sequencer |
| `apb_scoreboard.sv` | Checks read data against reference model |
| `apb_coverage.sv` | Collects functional coverage |
| `apb_env.sv` | Top-level environment |
| `apb_sequences.sv` | Multiple test sequences |
| `apb_tests.sv` | Test classes |
| `apb_pkg.sv` | Package for compilation |
| `tb_top.sv` | Top-level testbench module |

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `apb_random_write_test` | Writes 20 random transactions |
| `apb_write_read_test` | Writes data, then reads it back to verify |
| `apb_walking_ones_test` | Tests each address bit with walking-ones pattern |
| `apb_stress_test` | Runs all sequences in succession |

## How to Run

```bash
# VCS
vcs -sverilog -ntb_opts uvm apb_pkg.sv tb_top.sv apb_slave_dut.sv apb_if.sv \
    +UVM_TESTNAME=apb_write_read_test
./simv

# Questa/ModelSim
vlog -sv apb_if.sv apb_slave_dut.sv apb_pkg.sv tb_top.sv
vsim -c tb_top +UVM_TESTNAME=apb_write_read_test -do "run -all"

# Xcelium
xrun -sv -uvm apb_if.sv apb_slave_dut.sv apb_pkg.sv tb_top.sv \
    +UVM_TESTNAME=apb_write_read_test
```
