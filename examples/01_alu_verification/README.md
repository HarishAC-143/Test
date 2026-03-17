# Example 1: ALU Verification

A complete UVM testbench for verifying an 8-bit Arithmetic Logic Unit (ALU).

## Design Under Test

The ALU supports five operations on 8-bit operands:

| Operation | Encoding | Description |
|-----------|----------|-------------|
| ADD | `3'b000` | `result = a + b` (with carry) |
| SUB | `3'b001` | `result = a - b` (with borrow) |
| AND | `3'b010` | `result = a & b` |
| OR  | `3'b011` | `result = a \| b` |
| XOR | `3'b100` | `result = a ^ b` |

The ALU is fully registered — results appear one clock cycle after valid input.

### Interface Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low reset |
| `operand_a` | Input | 8 | First operand |
| `operand_b` | Input | 8 | Second operand |
| `operation` | Input | 3 | Operation selector |
| `valid_in` | Input | 1 | Input valid strobe |
| `result` | Output | 8 | Computation result |
| `carry_out` | Output | 1 | Carry/borrow flag |
| `zero_flag` | Output | 1 | Zero result flag |
| `valid_out` | Output | 1 | Output valid strobe |

## Testbench Architecture

```
tb_top
├── alu_if (SystemVerilog interface)
├── alu (DUT)
└── UVM Testbench
    └── alu_env
        ├── alu_agent (ACTIVE)
        │   ├── alu_sequencer
        │   ├── alu_driver
        │   └── alu_monitor ──┬──→ alu_scoreboard
        └── alu_coverage ◄────┘
```

## UVM Components

| File | Component | Description |
|------|-----------|-------------|
| `tb/alu_transaction.sv` | `alu_transaction` | Sequence item with operands, operation, and result |
| `tb/alu_sequence.sv` | Multiple sequences | Base, corner-case, single-op, and full-test sequences |
| `tb/alu_driver.sv` | `alu_driver` | Drives transactions onto the ALU interface |
| `tb/alu_monitor.sv` | `alu_monitor` | Observes interface and broadcasts transactions |
| `tb/alu_scoreboard.sv` | `alu_scoreboard` | Compares actual results vs. expected |
| `tb/alu_coverage.sv` | `alu_coverage` | Collects functional coverage |
| `tb/alu_agent.sv` | `alu_agent` | Bundles driver + monitor + sequencer |
| `tb/alu_env.sv` | `alu_env` | Top-level environment |
| `tb/alu_test.sv` | Multiple tests | Base, corner-case, and full tests |
| `tb/tb_top.sv` | `tb_top` | Top module: clock, reset, DUT, interface, UVM launch |

## Available Tests

| Test Name | Description |
|-----------|-------------|
| `alu_base_test` | 50 random transactions |
| `alu_corner_test` | Directed corner-case testing (overflow, underflow, zero) |
| `alu_full_test` | Combined: corner cases + focused ops + 100 random transactions |

## How to Run

```bash
# Using Synopsys VCS
vcs -sverilog -ntb_opts uvm rtl/alu.sv rtl/alu_if.sv tb/alu_pkg.sv tb/tb_top.sv
./simv +UVM_TESTNAME=alu_full_test +UVM_VERBOSITY=UVM_MEDIUM

# Using Cadence Xcelium
xrun -uvm rtl/alu.sv rtl/alu_if.sv tb/alu_pkg.sv tb/tb_top.sv \
     +UVM_TESTNAME=alu_full_test +UVM_VERBOSITY=UVM_MEDIUM

# Using Mentor Questa
vlog rtl/alu.sv rtl/alu_if.sv tb/alu_pkg.sv tb/tb_top.sv
vsim -c work.tb_top +UVM_TESTNAME=alu_full_test -do "run -all"
```

## Key Concepts Demonstrated

- Complete UVM testbench from transaction to test
- Constrained-random stimulus with `dist` and `inside` constraints
- Directed corner-case testing
- Hierarchical sequence composition
- Self-checking scoreboard with reference model
- Functional coverage collection with cross coverage
- Virtual interface passing via `uvm_config_db`
- Analysis port broadcasting (monitor → scoreboard + coverage)
