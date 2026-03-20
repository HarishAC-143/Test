# Example 3: ALU (Arithmetic Logic Unit) Verification

## Overview

This example demonstrates UVM verification of a 32-bit ALU with 13 operations. It highlights:

- **Constrained random stimulus** with weighted distributions for corner-case values
- **Comprehensive scoreboard** that models all ALU operations as a reference
- **Rich functional coverage** across opcodes, operand ranges, and result flags
- **Multiple test strategies**: random, directed corner-case, per-operation sweep, and comprehensive

## DUT Description

The ALU supports 13 operations:

| Opcode | Operation | Description |
|--------|-----------|-------------|
| 0x0 | ADD | 32-bit addition with carry and overflow detection |
| 0x1 | SUB | 32-bit subtraction with borrow and overflow detection |
| 0x2 | AND | Bitwise AND |
| 0x3 | OR | Bitwise OR |
| 0x4 | XOR | Bitwise XOR |
| 0x5 | NOT | Bitwise NOT (operand A only) |
| 0x6 | SLL | Shift left logical |
| 0x7 | SRL | Shift right logical |
| 0x8 | SRA | Shift right arithmetic (sign-extending) |
| 0x9 | MUL | Multiply (lower 16 bits of each operand) |
| 0xA | INC | Increment operand A |
| 0xB | DEC | Decrement operand A |
| 0xF | PASS | Pass-through operand A |

Output flags: `zero_flag`, `carry_flag`, `overflow_flag`

## File Structure

| File | Description |
|------|-------------|
| `alu_if.sv` | ALU interface |
| `alu_dut.sv` | 32-bit ALU with 13 operations |
| `alu_seq_item.sv` | Transaction with opcode enum and constraints |
| `alu_driver.sv` | Drives ALU inputs |
| `alu_monitor.sv` | Captures ALU results |
| `alu_agent.sv` | ALU agent |
| `alu_scoreboard.sv` | Reference model for all 13 operations |
| `alu_coverage.sv` | Coverage for opcodes, operands, and flags |
| `alu_env.sv` | Environment |
| `alu_sequences.sv` | Random, directed, shift, all-ops, corner-case sequences |
| `alu_tests.sv` | Multiple test classes |
| `alu_pkg.sv` | Package |
| `tb_top.sv` | Top-level testbench |

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `alu_random_test` | 500 fully random operations |
| `alu_corner_case_test` | Boundary values (0, 1, MAX, MIN) for arithmetic ops |
| `alu_all_ops_test` | 30 random operations per opcode |
| `alu_shift_test` | All shift amounts (0-31) for each shift operation |
| `alu_comprehensive_test` | Runs all sequences in succession |

## How to Run

```bash
# VCS
vcs -sverilog -ntb_opts uvm alu_pkg.sv tb_top.sv alu_dut.sv alu_if.sv \
    +UVM_TESTNAME=alu_comprehensive_test
./simv

# Questa
vlog -sv alu_if.sv alu_dut.sv alu_pkg.sv tb_top.sv
vsim -c tb_top +UVM_TESTNAME=alu_random_test -do "run -all"

# Xcelium
xrun -sv -uvm alu_if.sv alu_dut.sv alu_pkg.sv tb_top.sv \
    +UVM_TESTNAME=alu_corner_case_test
```
