# Example 2: Synchronous Memory Verification

A complete UVM testbench for a synchronous single-port SRAM with byte-enable writes.

## Design Under Test

The memory (`rtl/sync_mem.sv`) features:

- Parameterized address width (default 8 bits = 256 locations) and data width (default 32
  bits)
- Single-cycle read latency (`rvalid` asserted one cycle after `re`)
- Byte-enable granularity on writes (4 byte-enable bits for 32-bit data)
- Synchronous reset

## Testbench Architecture

```
┌──────────────────────────────────────────────────────────┐
│  mem_test                                                │
│  ┌────────────────────────────────────────────────────┐  │
│  │  mem_env                                           │  │
│  │  ┌──────────────────────────────┐  ┌────────────┐  │  │
│  │  │  mem_agent (UVM_ACTIVE)      │  │ mem_sb     │  │  │
│  │  │  ┌──────────┐ ┌───────────┐  │  │ (ref model)│  │  │
│  │  │  │ mem_sqr  │→│ mem_drv   │──┼──┼──→ DUT     │  │  │
│  │  │  └──────────┘ └───────────┘  │  │            │  │  │
│  │  │  ┌──────────────────────┐    │  │            │  │  │
│  │  │  │ mem_mon ──→ ap ──────┼────┼──┼→ write()   │  │  │
│  │  │  └──────────────────────┘    │  └────────────┘  │  │
│  │  └──────────────────────────────┘  ┌────────────┐  │  │
│  │                                    │ mem_cov    │  │  │
│  │                    ap ─────────────┼→ write()   │  │  │
│  │                                    └────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## File Structure

```
memory/
├── README.md
├── filelist.f
├── rtl/
│   └── sync_mem.sv            # Parameterized SRAM with byte-enable
└── tb/
    ├── mem_if.sv              # Interface with clocking blocks
    ├── mem_transaction.sv     # Sequence item (addr, data, we, re, be)
    ├── mem_sequences.sv       # Various test sequences
    ├── mem_driver.sv          # Drives memory interface
    ├── mem_monitor.sv         # Monitors reads and writes
    ├── mem_sequencer.sv       # Standard sequencer
    ├── mem_agent.sv           # Groups driver + monitor + sequencer
    ├── mem_scoreboard.sv      # Reference model with byte-enable tracking
    ├── mem_coverage.sv        # Operation, address, byte-enable coverage
    ├── mem_env.sv             # Top-level environment
    ├── mem_test.sv            # Test classes
    ├── mem_pkg.sv             # Package
    └── top.sv                 # Top-level module
```

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=mem_full_test

# Questa
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f filelist.f
vsim -c top -do "run -all; quit" +UVM_TESTNAME=mem_byte_enable_test

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=mem_write_read_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `mem_write_read_test` | Write data, then read back and verify |
| `mem_byte_enable_test` | Verify byte-enable masking |
| `mem_full_test` | Walking ones + byte-enable + write-read + random stress |

## Key Learning Points

1. **Reference model scoreboard** -- mirrors memory state with byte-enable accounting
2. **Byte-enable constraints** -- ensures at least one byte is enabled on writes
3. **Walking-ones pattern** -- classic memory test for stuck-at faults
4. **Hierarchical sequences** -- `mem_full_sequence` orchestrates sub-sequences
5. **Coverage cross-products** -- tracks byte-enable patterns per operation type
