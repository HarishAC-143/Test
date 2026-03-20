# Example 1: ALU Testbench

A complete UVM testbench for an 8-bit ALU that supports four operations: ADD, SUB, MUL,
and AND.

## Design Under Test

The ALU (`rtl/alu.sv`) is a single-cycle, pipelined design:

- **Inputs:** two 8-bit operands, a 2-bit opcode, and a valid signal
- **Outputs:** a 16-bit result (to accommodate multiplication), an overflow flag, and a
  valid_out signal (one cycle latency)

| Opcode | Operation | Overflow Condition |
|--------|-----------|--------------------|
| `00` | ADD | Carry out of bit 8 |
| `01` | SUB | A < B (underflow) |
| `10` | MUL | Never (16-bit result) |
| `11` | AND | Never |

## Testbench Architecture

```
┌─────────────────────────────────────────────────────────┐
│  alu_test (uvm_test)                                    │
│  ┌───────────────────────────────────────────────────┐  │
│  │  alu_env (uvm_env)                                │  │
│  │  ┌──────────────────────────────┐  ┌───────────┐  │  │
│  │  │  alu_agent (UVM_ACTIVE)      │  │ alu_sb    │  │  │
│  │  │  ┌──────────┐ ┌───────────┐  │  │           │  │  │
│  │  │  │ alu_sqr  │→│ alu_drv   │──┼──┼──→ DUT    │  │  │
│  │  │  └──────────┘ └───────────┘  │  │           │  │  │
│  │  │  ┌───────────────────────┐   │  │           │  │  │
│  │  │  │ alu_mon ──→ ap ───────┼───┼──┼──→ write()│  │  │
│  │  │  └───────────────────────┘   │  └───────────┘  │  │
│  │  └──────────────────────────────┘  ┌───────────┐  │  │
│  │                                    │ alu_cov   │  │  │
│  │                    ap ─────────────┼──→ write() │  │  │
│  │                                    └───────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## File Structure

```
alu/
├── README.md
├── filelist.f
├── rtl/
│   └── alu.sv              # DUT
└── tb/
    ├── alu_if.sv            # Interface with clocking blocks
    ├── alu_transaction.sv   # Sequence item (operands, opcode, result)
    ├── alu_sequences.sv     # Random, directed, and full sequences
    ├── alu_driver.sv        # Converts transactions to pin wiggles
    ├── alu_monitor.sv       # Observes interface, broadcasts transactions
    ├── alu_sequencer.sv     # Standard sequencer
    ├── alu_agent.sv         # Groups driver + monitor + sequencer
    ├── alu_scoreboard.sv    # Reference model + comparison
    ├── alu_coverage.sv      # Functional coverage collector
    ├── alu_env.sv           # Top-level environment
    ├── alu_test.sv          # Test classes
    ├── alu_pkg.sv           # Package (compilation order)
    └── top.sv               # Top-level module
```

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=alu_random_test +UVM_VERBOSITY=UVM_LOW

# Questa
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f filelist.f
vsim -c top -do "run -all; quit" +UVM_TESTNAME=alu_directed_test

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=alu_random_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `alu_random_test` | 500 fully random transactions |
| `alu_directed_test` | Corner-case ADD/SUB/MUL followed by 200 random transactions |

## Key Learning Points

1. **Interface with clocking blocks** -- separate driver and monitor timing
2. **Scoreboard with reference model** -- self-checking testbench
3. **Constrained-random + directed** -- combine both strategies
4. **Functional coverage** -- track operation and operand coverage with cross-coverage
5. **Hierarchical sequences** -- `alu_full_sequence` composes sub-sequences
