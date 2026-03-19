# SystemVerilog UVM Verification - Memory Model

A complete UVM verification environment for latch-based and flop-based memory models, structured as lab exercises for a 3-day SystemVerilog UVM Verification course.

## Project Structure

```
├── rtl/                          # RTL Design (DUT)
│   ├── mem_latch.sv              # Latch-based memory (level-sensitive storage)
│   ├── mem_flop.sv               # Flop-based memory (edge-triggered storage)
│   └── memory_model.sv           # Top-level wrapper (selects latch or flop)
│
├── tb/                           # UVM Testbench
│   ├── uvm_tb/                   # Core UVM components
│   │   ├── mem_pkg.sv            # UVM package (compilation unit)
│   │   ├── mem_if.sv             # Interface with clocking blocks
│   │   ├── mem_seq_item.sv       # Transaction / sequence item
│   │   ├── mem_sequencer.sv      # Sequencer
│   │   ├── mem_driver.sv         # Driver (TLM, sequence/driver sync)
│   │   ├── mem_monitor.sv        # Monitor (analysis ports)
│   │   ├── mem_agent.sv          # Agent (active/passive modes)
│   │   ├── mem_scoreboard.sv     # Scoreboard (reference model)
│   │   ├── mem_coverage.sv       # Functional coverage collector
│   │   └── mem_env.sv            # Environment
│   │
│   ├── sequences/                # Sequences
│   │   ├── mem_sequences.sv      # Write, read, write-read, random, walking-ones
│   │   └── mem_virtual_seq.sv    # Virtual sequences and virtual sequencer
│   │
│   ├── tests/                    # UVM Tests
│   │   ├── mem_base_test.sv      # Base test class
│   │   ├── mem_write_read_test.sv
│   │   ├── mem_random_test.sv
│   │   ├── mem_walking_ones_test.sv
│   │   └── mem_virtual_seq_test.sv
│   │
│   └── top/                      # Top-level modules
│       ├── tb_top.sv             # Testbench top (flop memory)
│       └── tb_top_latch.sv       # Testbench top (latch memory)
│
└── sim/                          # Simulation
    ├── Makefile                  # Multi-simulator Makefile
    └── filelist.f                # Source file list
```

## UVM Testbench Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  UVM Test (mem_base_test / mem_write_read_test / ...)          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  UVM Environment (mem_env)                                │  │
│  │  ┌─────────────────────────────┐  ┌────────────────────┐  │  │
│  │  │  UVM Agent (mem_agent)      │  │  Scoreboard        │  │  │
│  │  │  ┌───────────┐             │  │  (ref model +      │  │  │
│  │  │  │ Sequencer │◄─sequences  │  │   comparison)      │  │  │
│  │  │  └─────┬─────┘             │  └────────▲───────────┘  │  │
│  │  │        │ TLM               │           │ analysis     │  │
│  │  │  ┌─────▼─────┐  ┌───────┐ │  ┌────────┴───────────┐  │  │
│  │  │  │  Driver   │  │Monitor├─┼──►  Coverage           │  │  │
│  │  │  └─────┬─────┘  └───▲───┘ │  └────────────────────┘  │  │
│  │  └────────┼─────────────┼─────┘                          │  │
│  └───────────┼─────────────┼────────────────────────────────┘  │
└──────────────┼─────────────┼───────────────────────────────────┘
         ┌─────▼─────────────▼─────┐
         │   Interface (mem_if)    │
         │   clocking blocks       │
         └─────────┬───────────────┘
         ┌─────────▼───────────────┐
         │   DUT (memory_model)    │
         │   flop / latch based    │
         └─────────────────────────┘
```

## Course Lab Mapping

### Day 1 - Design a latch and flop based memory model
- `rtl/mem_latch.sv` - Latch-based memory with level-sensitive write
- `rtl/mem_flop.sv` - Flop-based memory with edge-triggered write
- `rtl/memory_model.sv` - Parameterized top-level wrapper
- `tb/uvm_tb/mem_if.sv` - Interface with driver and monitor clocking blocks
- `tb/uvm_tb/mem_seq_item.sv` - Transaction class with field macros
- `tb/sequences/mem_sequences.sv` - Write, read, and random sequences

### Day 2 - Code UVM components to verify the memory model
- `tb/uvm_tb/mem_driver.sv` - Driver with get_next_item/item_done handshake
- `tb/uvm_tb/mem_monitor.sv` - Monitor with write, read, and combined analysis ports
- `tb/uvm_tb/mem_agent.sv` - Agent with UVM_ACTIVE/UVM_PASSIVE mode support
- `tb/uvm_tb/mem_sequencer.sv` - Parameterized sequencer
- `tb/uvm_tb/mem_scoreboard.sv` - Scoreboard with reference model and result comparison
- `tb/uvm_tb/mem_coverage.sv` - Functional coverage with covergroups and crosses
- `tb/uvm_tb/mem_env.sv` - Environment connecting all components

### Day 3 - Code UVM components and testbench top
- `tb/tests/mem_base_test.sv` - Base test with config_db and factory setup
- `tb/tests/mem_write_read_test.sv` - Directed write-read verification
- `tb/tests/mem_random_test.sv` - Constrained random stress test
- `tb/tests/mem_walking_ones_test.sv` - Walking ones stuck-at fault detection
- `tb/tests/mem_virtual_seq_test.sv` - Virtual sequences (sequential and parallel)
- `tb/sequences/mem_virtual_seq.sv` - Virtual sequencer and virtual sequences
- `tb/top/tb_top.sv` - Top-level testbench (flop-based DUT)
- `tb/top/tb_top_latch.sv` - Top-level testbench (latch-based DUT)

## Key UVM Concepts Demonstrated

| Concept | Implementation |
|---------|---------------|
| `uvm_object` | `mem_seq_item` extends `uvm_sequence_item` |
| `uvm_component` | Driver, Monitor, Agent, Scoreboard, Env, Test |
| Virtual Interfaces | `mem_if` with clocking blocks; set/get via `uvm_config_db` |
| Field Macros | `uvm_field_int` in `mem_seq_item` |
| Factory Registration | `uvm_object_utils`, `uvm_component_utils` throughout |
| Factory Overrides | Supported via standard `type_id::create()` pattern |
| Config Database | Virtual interface, `is_active` agent mode |
| UVM Phases | build, connect, end_of_elaboration, run, report |
| TLM Ports | `seq_item_port`, `uvm_analysis_port`, `uvm_analysis_imp` |
| Sequence/Driver Sync | `get_next_item` / `item_done` handshake |
| Active/Passive Agent | Controlled via `is_active` config |
| Scoreboard | Reference model with predicted vs actual comparison |
| Functional Coverage | Covergroups, coverpoints, cross coverage |
| Virtual Sequences | Sequential, parallel, and comprehensive patterns |
| Multiple Tests | Selected at runtime via `+UVM_TESTNAME` |

## Running Simulations

### Prerequisites
- A SystemVerilog simulator with UVM support (VCS, Questa, or Xcelium)

### Quick Start

```bash
cd sim

# Run a specific test with flop-based memory (VCS)
make run_flop TEST=mem_write_read_test SIMULATOR=vcs

# Run with latch-based memory
make run_latch TEST=mem_write_read_test SIMULATOR=vcs

# Run all tests
make all_tests_flop SIMULATOR=vcs

# Run with Questa
make run_flop TEST=mem_random_test SIMULATOR=questa

# Run with Xcelium
make run_flop TEST=mem_random_test SIMULATOR=xcelium

# Control verbosity and seed
make run_flop TEST=mem_random_test VERBOSITY=UVM_HIGH SEED=12345

# Clean generated files
make clean
```

### Available Tests

| Test Name | Description |
|-----------|-------------|
| `mem_write_read_test` | Writes data to addresses then reads back to verify |
| `mem_random_test` | Fully random mix of reads, writes, and idles |
| `mem_walking_ones_test` | Walking ones pattern across all addresses |
| `mem_virtual_seq_test` | Comprehensive virtual sequence combining all patterns |
| `mem_sequential_vseq_test` | Sequential virtual sequence (write → read → write-read) |
| `mem_parallel_vseq_test` | Parallel virtual sequence (concurrent random sequences) |
