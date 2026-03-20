# Example 1: ALU Testbench

A complete UVM testbench for a simple 32-bit Arithmetic Logic Unit.

## DUT Features

- 32-bit operands A and B
- 8 operations: ADD, SUB, MUL, AND, OR, XOR, SHL, SHR
- Synchronous operation with valid/ready handshake
- Result output with status flags (zero, carry, overflow)

## Architecture

```
                  alu_test
                     │
                  alu_env
                 /        \
          alu_agent     alu_scoreboard
         /    |    \        │
   alu_driver │  alu_monitor ── alu_coverage
        alu_sequencer
              │
        alu_sequence
              │
        alu_transaction
```

## Files

| File | Description |
|------|-------------|
| `alu_dut.sv` | RTL design of the ALU |
| `alu_if.sv` | SystemVerilog interface |
| `alu_pkg.sv` | Package with all UVM classes |
| `alu_transaction.sv` | Transaction (sequence item) |
| `alu_sequences.sv` | Various test sequences |
| `alu_driver.sv` | Pin-level driver |
| `alu_monitor.sv` | Interface monitor |
| `alu_sequencer.sv` | Sequencer |
| `alu_agent.sv` | Agent encapsulation |
| `alu_scoreboard.sv` | Self-checking scoreboard |
| `alu_coverage.sv` | Functional coverage |
| `alu_env.sv` | Environment |
| `alu_tests.sv` | Test cases |
| `top.sv` | Top-level testbench module |
| `filelist.f` | File compilation list |

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=alu_base_test +UVM_VERBOSITY=UVM_MEDIUM

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=alu_base_test

# Questa
vlog -f filelist.f
vsim -c top -do "run -all" +UVM_TESTNAME=alu_base_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `alu_base_test` | Runs 100 random transactions |
| `alu_directed_test` | Tests specific corner cases (zero, max values) |
| `alu_stress_test` | Runs 5000 random transactions for coverage closure |
