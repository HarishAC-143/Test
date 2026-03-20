# Example 3: Register Abstraction Layer (RAL)

A complete example demonstrating UVM RAL for register verification of a simple peripheral with control, status, and data registers.

## DUT Features

- APB-lite slave interface
- Control register (RW): enable, mode, interrupt enable
- Status register (RO/W1C): busy, done, error, interrupt pending
- Data input register (RW): 32-bit data input
- Data output register (RO): 32-bit data output (mirrors input when enabled)
- Interrupt status register (W1C)

## Architecture

```
                    ral_test
                       │
                    ral_env
                  /    │    \
           apb_agent  │  ral_coverage
                  reg_model
                  (uvm_reg_block)
                       │
                  reg_adapter
                  (apb ↔ reg)
```

## Register Map

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| 0x00 | CTRL | RW | Control register |
| 0x04 | STATUS | RO/W1C | Status register |
| 0x08 | DATA_IN | RW | Data input |
| 0x0C | DATA_OUT | RO | Data output |
| 0x10 | IRQ_STATUS | W1C | Interrupt status |

## Files

| File | Description |
|------|-------------|
| `periph_dut.sv` | RTL design of the peripheral |
| `apb_if.sv` | APB interface |
| `ral_pkg.sv` | Package with RAL model and UVM testbench |
| `periph_reg_model.sv` | Register model (uvm_reg_block) |
| `apb_reg_adapter.sv` | RAL-to-APB adapter |
| `apb_transaction.sv` | APB transaction |
| `apb_driver.sv` | APB driver |
| `apb_monitor.sv` | APB monitor |
| `apb_agent.sv` | APB agent |
| `ral_env.sv` | Environment with RAL integration |
| `ral_sequences.sv` | Register test sequences |
| `ral_tests.sv` | Test cases |
| `top.sv` | Top-level module |
| `filelist.f` | Compilation file list |

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=ral_reset_test

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=ral_reset_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `ral_reset_test` | Verifies all register reset values |
| `ral_rw_test` | Tests read/write access to all registers |
| `ral_bit_bash_test` | Bit-level walking-1/walking-0 test |
| `ral_functional_test` | Functional test using register operations |
