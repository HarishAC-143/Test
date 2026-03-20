# Example 2: Synchronous FIFO Verification

A complete UVM testbench for a parameterizable synchronous FIFO with full/empty detection.

## DUT Features

- Configurable data width and depth
- Synchronous push and pop operations
- Full and empty status flags
- Almost-full and almost-empty thresholds
- Overflow and underflow error detection

## Architecture

```
                    fifo_test
                       │
                    fifo_env
                  /     │     \
          wr_agent   rd_agent  fifo_scoreboard
         /  |  \    /  |  \        │
       drv sqr mon drv sqr mon  fifo_coverage
```

This example uses **two agents**: a write agent and a read agent, demonstrating multi-agent coordination.

## Files

| File | Description |
|------|-------------|
| `fifo_dut.sv` | RTL design of the synchronous FIFO |
| `fifo_if.sv` | SystemVerilog interface |
| `fifo_pkg.sv` | Package with all UVM classes |
| `fifo_transaction.sv` | Write/read transactions |
| `fifo_sequences.sv` | Various test sequences |
| `fifo_driver.sv` | Write and read drivers |
| `fifo_monitor.sv` | Write and read monitors |
| `fifo_agent.sv` | Write and read agents |
| `fifo_scoreboard.sv` | Reference-model scoreboard |
| `fifo_coverage.sv` | Functional coverage |
| `fifo_env.sv` | Environment with dual agents |
| `fifo_tests.sv` | Test cases |
| `top.sv` | Top-level testbench module |
| `filelist.f` | File compilation list |

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=fifo_base_test

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=fifo_base_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `fifo_base_test` | Random writes and reads |
| `fifo_full_empty_test` | Tests full and empty boundary conditions |
| `fifo_overflow_test` | Attempts to write to a full FIFO |
