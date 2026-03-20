# Example 4: APB Protocol Verification

A complete UVM testbench for verifying an APB (Advanced Peripheral Bus) slave memory with protocol checking, constrained-random sequences, and coverage-driven verification.

## DUT Features

- APB3-compliant slave interface
- 256-byte memory space (64 x 32-bit words)
- Configurable wait states via control register
- Error response for out-of-range addresses
- Byte, halfword, and word access support

## Architecture

```
                      apb_test
                         │
                      apb_env
                    /     │     \
            apb_agent   apb_sb  apb_cov
           /    |    \
     apb_drv apb_sqr apb_mon
                │
          apb_sequence
                │
          apb_seq_item
```

## What This Example Demonstrates

1. **Complete agent structure** with configurable active/passive mode
2. **Protocol-level assertions** in the interface
3. **Self-checking scoreboard** with associative-array reference model
4. **Comprehensive functional coverage** including cross coverage
5. **Multiple test scenarios**: smoke, random, boundary, back-to-back
6. **Factory overrides** to swap in error-injection sequence

## Files

| File | Description |
|------|-------------|
| `apb_slave_dut.sv` | RTL APB slave memory |
| `apb_if.sv` | APB interface with protocol assertions |
| `apb_pkg.sv` | Package with all UVM classes |
| `apb_seq_item.sv` | APB transaction class |
| `apb_sequences.sv` | Test sequences |
| `apb_driver.sv` | APB master driver |
| `apb_monitor.sv` | APB monitor |
| `apb_agent.sv` | APB agent with sequencer |
| `apb_scoreboard.sv` | Self-checking scoreboard |
| `apb_coverage.sv` | Functional coverage collector |
| `apb_env.sv` | Verification environment |
| `apb_tests.sv` | Test classes |
| `top.sv` | Top-level testbench |
| `filelist.f` | File compilation list |

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=apb_smoke_test +UVM_VERBOSITY=UVM_MEDIUM

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=apb_smoke_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `apb_smoke_test` | Basic read/write sanity check |
| `apb_random_test` | 500 random read/write transactions |
| `apb_boundary_test` | Tests address boundaries and alignment |
| `apb_back2back_test` | Back-to-back transactions with zero delay |
