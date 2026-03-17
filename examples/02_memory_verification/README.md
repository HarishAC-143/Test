# Example 2: Memory Verification

A complete UVM testbench for verifying a synchronous single-port RAM.

## Design Under Test

A parameterizable synchronous memory with:
- Configurable address width (default 8 bits → 256 locations)
- Configurable data width (default 32 bits)
- Synchronous write (data stored on clock edge when `wr_en` is high)
- Synchronous read (data available one clock after `rd_en` is asserted)
- Active-low reset

### Interface Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low reset |
| `addr` | Input | ADDR_WIDTH | Address bus |
| `wdata` | Input | DATA_WIDTH | Write data |
| `wr_en` | Input | 1 | Write enable |
| `rd_en` | Input | 1 | Read enable |
| `rdata` | Output | DATA_WIDTH | Read data |
| `rvalid` | Output | 1 | Read data valid |

## Testbench Architecture

```
tb_top
├── mem_if (parameterized interface)
├── sync_mem (DUT)
└── UVM Testbench
    └── mem_env
        ├── mem_agent (ACTIVE)
        │   ├── sequencer
        │   ├── mem_driver
        │   └── mem_monitor ──→ mem_scoreboard (with reference model)
```

## Verification Strategy

The scoreboard maintains an **associative array as a reference model** that mirrors the DUT's memory. On each write, the scoreboard updates its reference. On each read, it compares the DUT's output against the stored reference value.

## Available Sequences

| Sequence | Description |
|----------|-------------|
| `mem_random_sequence` | Random reads and writes to random addresses |
| `mem_write_read_sequence` | Write to N locations, then read them all back |
| `mem_walking_ones_sequence` | Write walking-one patterns to verify data bus integrity |
| `mem_addr_bus_sequence` | Write to power-of-2 addresses to detect address aliasing |
| `mem_full_test_sequence` | Runs all of the above in sequence |

## Available Tests

| Test | Description |
|------|-------------|
| `mem_base_test` | 50 random transactions |
| `mem_write_read_test` | Write 16 locations and read them back |
| `mem_full_test` | Comprehensive test: walking ones + address bus + write/read + random |

## How to Run

```bash
# Using Synopsys VCS
vcs -sverilog -ntb_opts uvm rtl/sync_mem.sv rtl/mem_if.sv tb/mem_pkg.sv tb/tb_top.sv
./simv +UVM_TESTNAME=mem_full_test

# Using Cadence Xcelium
xrun -uvm rtl/sync_mem.sv rtl/mem_if.sv tb/mem_pkg.sv tb/tb_top.sv \
     +UVM_TESTNAME=mem_full_test

# Using Mentor Questa
vlog rtl/sync_mem.sv rtl/mem_if.sv tb/mem_pkg.sv tb/tb_top.sv
vsim -c work.tb_top +UVM_TESTNAME=mem_full_test -do "run -all"
```

## Key Concepts Demonstrated

- Reference model scoreboard (associative array as golden model)
- Parameterized DUT and interface
- Multiple test strategies: walking ones, address bus, write-read-back
- Hierarchical sequence composition
- Read latency handling in the monitor (synchronous read pipeline)
