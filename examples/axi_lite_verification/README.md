# Practical Example 3: AXI4-Lite Slave Verification

[&larr; Back to Main](../../README.md)

---

## Overview

This example demonstrates UVM verification of an **AXI4-Lite slave** with a register bank. It showcases protocol-level verification concepts including:

- Multi-channel protocol handling (write address, write data, write response, read address, read data)
- Protocol compliance checking
- Register-level verification
- Separate stimulus for write and read channels
- Advanced scoreboard with expected-value tracking

### DUT: AXI4-Lite Register Slave

- 4 x 32-bit read/write registers at offsets 0x00, 0x04, 0x08, 0x0C
- Full AXI4-Lite slave interface
- Single clock, active-low reset
- Supports aligned 32-bit reads and writes

### What You'll Learn

- Modeling a **multi-channel protocol** in UVM
- Building a **protocol-aware driver** that handles handshaking
- Verifying **register access patterns** (write/read-back)
- Using **directed + random** test strategies

## File Structure

| File | Description |
|------|-------------|
| `axi_lite_slave.sv` | DUT — AXI4-Lite register slave |
| `axi_lite_if.sv` | SystemVerilog interface |
| `axi_lite_pkg.sv` | Package with all TB classes |
| `axi_lite_txn.sv` | Transaction definition |
| `axi_lite_sequence.sv` | Stimulus sequences |
| `axi_lite_driver.sv` | Protocol-aware driver |
| `axi_lite_monitor.sv` | Protocol-aware monitor |
| `axi_lite_agent.sv` | Agent |
| `axi_lite_scoreboard.sv` | Register-model scoreboard |
| `axi_lite_coverage.sv` | Functional coverage |
| `axi_lite_env.sv` | Environment |
| `axi_lite_test.sv` | Test classes |
| `tb_top.sv` | Top-level testbench |

## How to Run

```bash
# Synopsys VCS
vcs -sverilog -ntb_opts uvm tb_top.sv +UVM_TESTNAME=axi_lite_base_test
./simv +UVM_VERBOSITY=UVM_MEDIUM

# Cadence Xcelium
xrun -uvm -sv tb_top.sv +UVM_TESTNAME=axi_lite_base_test

# Siemens Questa
vlog -sv tb_top.sv
vsim -do "run -all" tb_top +UVM_TESTNAME=axi_lite_base_test
```

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `axi_lite_base_test` | Random read/write (50 transactions) |
| `axi_lite_reg_test` | Write all registers, read back and verify |
| `axi_lite_stress_test` | High-volume random traffic (500 transactions) |
