# Example 3: FIFO Verification

A complete UVM testbench for verifying a synchronous FIFO with full/empty status flags.

## Design Under Test

A parameterizable synchronous FIFO with:
- Configurable data width (default 8 bits)
- Configurable depth (default 16 entries)
- Full and empty status flags
- Occupancy counter
- Simultaneous read/write support

### Interface Signals

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low reset |
| `wr_data` | Input | DATA_WIDTH | Write data |
| `wr_en` | Input | 1 | Write enable |
| `full` | Output | 1 | FIFO is full |
| `rd_data` | Output | DATA_WIDTH | Read data |
| `rd_en` | Input | 1 | Read enable |
| `empty` | Output | 1 | FIFO is empty |
| `count` | Output | ADDR_WIDTH+1 | Current occupancy |

## Testbench Architecture

```
tb_top
├── fifo_if (parameterized interface)
├── sync_fifo (DUT)
└── UVM Testbench
    └── fifo_env
        ├── fifo_agent (ACTIVE)
        │   ├── sequencer
        │   ├── fifo_driver
        │   └── fifo_monitor ──→ fifo_scoreboard (with queue reference model)
```

## Verification Strategy

The scoreboard maintains a **SystemVerilog queue** (`$`) as a reference model:
- On writes: `push_back()` the data
- On reads: `pop_front()` and compare against DUT output
- Overflow/underflow attempts are tracked separately

### Checked Properties

- Data integrity (FIFO ordering — first in, first out)
- Full flag correctness
- Empty flag correctness
- Write blocking when full
- Read blocking when empty
- Simultaneous read/write behavior

## Available Sequences

| Sequence | Description |
|----------|-------------|
| `fifo_random_sequence` | Random mix of reads, writes, and simultaneous operations |
| `fifo_fill_drain_sequence` | Fills FIFO to capacity, attempts overflow, drains completely, attempts underflow |
| `fifo_simultaneous_sequence` | Pre-fills FIFO, then performs simultaneous read+write operations |
| `fifo_burst_sequence` | Alternating bursts of writes and reads |
| `fifo_full_test_sequence` | Runs all sub-sequences in order |

## Available Tests

| Test | Description |
|------|-------------|
| `fifo_base_test` | 100 random operations |
| `fifo_fill_drain_test` | Fill/overflow/drain/underflow boundary test |
| `fifo_full_test` | Comprehensive test: fill-drain + simultaneous + burst + random |

## How to Run

```bash
# Using Synopsys VCS
vcs -sverilog -ntb_opts uvm rtl/sync_fifo.sv rtl/fifo_if.sv tb/fifo_pkg.sv tb/tb_top.sv
./simv +UVM_TESTNAME=fifo_full_test

# Using Cadence Xcelium
xrun -uvm rtl/sync_fifo.sv rtl/fifo_if.sv tb/fifo_pkg.sv tb/tb_top.sv \
     +UVM_TESTNAME=fifo_full_test

# Using Mentor Questa
vlog rtl/sync_fifo.sv rtl/fifo_if.sv tb/fifo_pkg.sv tb/tb_top.sv
vsim -c work.tb_top +UVM_TESTNAME=fifo_full_test -do "run -all"
```

## Key Concepts Demonstrated

- Queue-based reference model scoreboard
- FIFO-specific verification: ordering, boundary conditions, overflow/underflow
- Multiple operation types in a single transaction (write, read, simultaneous, idle)
- Burst and stress testing patterns
- Status flag verification (full, empty, count)
- Simultaneous read/write handling
