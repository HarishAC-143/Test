# Chapter 4: Timing Exceptions

## Table of Contents

- [What Are Timing Exceptions?](#what-are-timing-exceptions)
- [set_false_path](#set_false_path)
- [set_multicycle_path](#set_multicycle_path)
- [set_max_delay and set_min_delay](#set_max_delay-and-set_min_delay)
- [Exception Priority Rules](#exception-priority-rules)
- [Practical Examples](#practical-examples)

---

## What Are Timing Exceptions?

By default, TimeQuest assumes:
- All register-to-register paths are single-cycle (data launches on one clock edge and must be captured on the very next edge)
- All paths between clocks are valid and must be analyzed

**Timing exceptions** override these defaults for paths where the standard analysis is incorrect or too restrictive. The three main exception types are:

| Exception | Purpose |
|-----------|---------|
| `set_false_path` | Completely removes a path from timing analysis |
| `set_multicycle_path` | Allows data more than one clock cycle to propagate |
| `set_max_delay` / `set_min_delay` | Overrides the setup/hold requirement with an explicit delay |

> **Warning**: Timing exceptions are powerful but dangerous. Every exception you add is a path you are **telling the tool not to check**. Use them judiciously and always document why each exception exists.

## set_false_path

A false path is a timing path that physically exists in the netlist but is either:
- Never exercised during actual operation
- Not relevant for timing (e.g., static configuration registers)
- Already handled by other mechanisms (e.g., CDC synchronizers)

### Syntax

```tcl
set_false_path [-setup] [-hold] \
               [-from <source>] \
               [-through <through_point>] \
               [-to <destination>]
```

### When to Use False Paths

| Scenario | Example |
|----------|---------|
| Asynchronous reset | `set_false_path -from [get_ports RST_N]` |
| CDC synchronizer first stage | `set_false_path -to [get_registers {*sync_reg[0]}]` |
| Static configuration registers | `set_false_path -from [get_registers {config_reg[*]}]` |
| Test/debug logic | `set_false_path -from [get_registers {debug_*}]` |
| Cross-domain status bits | `set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]` |

### Examples

#### Asynchronous Reset

```tcl
# Reset is asynchronous and synchronized in RTL
set_false_path -from [get_ports ASYNC_RST_N]
```

#### Clock Domain Crossing (Synchronizer)

```tcl
# False path TO the first synchronizer flip-flop
# The double-flop synchronizer handles metastability
set_false_path -to [get_registers {*cdc_sync|meta_reg}]
```

#### Between Asynchronous Domains (Specific Paths)

```tcl
# Status register from clk_a domain read in clk_b domain
# (single-bit, level-sensitive, stable for multiple cycles)
set_false_path -from [get_registers {status_reg}] \
               -to   [get_registers {status_sync[0]}]
```

#### Static Configuration

```tcl
# Configuration registers set once at startup and never changed
set_false_path -from [get_registers {cfg_mode[*] cfg_addr[*] cfg_data[*]}]
```

#### Using -through

```tcl
# False path through a specific multiplexer select (test mode)
set_false_path -through [get_pins {test_mux|sel}]
```

### Common Mistakes with False Paths

**Mistake 1**: Using false path between entire clock domains instead of specific paths.

```tcl
# DANGEROUS: This disables ALL timing between clk_a and clk_b
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# BETTER: Use set_clock_groups if they are truly asynchronous
set_clock_groups -asynchronous -group {clk_a} -group {clk_b}

# BEST: False path only to specific synchronizer registers
set_false_path -to [get_registers {sync_a2b|meta[*]}]
```

**Mistake 2**: False-pathing a multi-bit bus crossing without proper synchronization.

```tcl
# WRONG: Multi-bit bus needs a synchronization scheme (FIFO, handshake),
# not just a false path declaration
set_false_path -from [get_registers {data_bus[*]}] \
               -to   [get_registers {data_sync[*]}]
```

## set_multicycle_path

A multicycle path is a path where data is intentionally allowed more than one clock cycle to propagate. This occurs when:
- A clock enable limits how often a register is updated
- A protocol guarantees data is stable for multiple cycles
- A slow pipeline stage has deliberately relaxed timing

### Syntax

```tcl
set_multicycle_path [-setup | -hold] \
                    [-start | -end] \
                    -from <source> \
                    -to <destination> \
                    <path_multiplier>
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| `-setup` | Apply to setup analysis (default if not specified) |
| `-hold` | Apply to hold analysis |
| `-start` | Multiplier is relative to the launch (source) clock |
| `-end` | Multiplier is relative to the capture (destination) clock (default) |
| `<path_multiplier>` | Number of clock cycles allowed |

### The Setup/Hold Relationship

When you set a multicycle setup path of N, you almost always need a corresponding hold multicycle of N-1:

```tcl
# Allow 2 clock cycles for setup
set_multicycle_path -setup -from [get_registers src_*] -to [get_registers dst_*] 2

# Adjust hold check to be 1 cycle (N-1 = 2-1 = 1)
set_multicycle_path -hold  -from [get_registers src_*] -to [get_registers dst_*] 1
```

**Why?** Without the hold adjustment, the hold check moves to an earlier edge, making it overly pessimistic (and often impossible to meet).

### Visual Explanation

#### Default (Single Cycle):

```
Launch    Capture
  |          |
  v          v
  ┌──────────┐
  │ 1 cycle  │
  └──────────┘
  Setup check: capture edge = launch edge + 1 period
  Hold check:  capture edge = launch edge
```

#### Multicycle = 2 (Setup Only, NO Hold Adjustment):

```
Launch              Capture
  |                    |
  v                    v
  ┌────────────────────┐
  │    2 cycles        │
  └────────────────────┘
  Setup check: capture edge = launch edge + 2 periods
  Hold check:  capture edge = launch edge + 1 period  ← WRONG! Too late
```

#### Multicycle = 2 (Setup) + Multicycle = 1 (Hold):

```
Launch              Capture
  |                    |
  v                    v
  ┌────────────────────┐
  │    2 cycles        │
  └────────────────────┘
  Setup check: capture edge = launch edge + 2 periods  ✓
  Hold check:  capture edge = launch edge               ✓ Correct!
```

### Examples

#### Clock Enable Based Multicycle

```verilog
// Data updates every 4th clock cycle
reg [1:0] cnt;
always @(posedge clk) begin
    cnt <= cnt + 1;
    if (cnt == 2'b11) begin
        result <= long_computation;
    end
end
```

```tcl
# 4-cycle multicycle path
set_multicycle_path -setup -end \
    -from [get_registers {compute_*}] \
    -to   [get_registers {result[*]}] 4

set_multicycle_path -hold -end \
    -from [get_registers {compute_*}] \
    -to   [get_registers {result[*]}] 3
```

#### Cross-Clock Domain Multicycle

When source and destination clocks have different frequencies, use `-start` or `-end` carefully:

```tcl
# Source clock: 100 MHz (10 ns), Destination clock: 50 MHz (20 ns)
# Data launched from 100 MHz domain, captured in 50 MHz domain
# The 50 MHz capture window is already 2x the source period

# Allow 2 source clock cycles for data propagation
set_multicycle_path -setup -start \
    -from [get_clocks clk_100] \
    -to   [get_clocks clk_50] 2

set_multicycle_path -hold -start \
    -from [get_clocks clk_100] \
    -to   [get_clocks clk_50] 1
```

### Multicycle Summary Table

| Multicycle Setup Value | Hold Companion | Effect |
|----------------------|---------------|--------|
| 2 | 1 | 2 clock cycles for data (1 extra cycle) |
| 3 | 2 | 3 clock cycles for data (2 extra cycles) |
| 4 | 3 | 4 clock cycles for data (3 extra cycles) |
| N | N-1 | N clock cycles for data |

## set_max_delay and set_min_delay

These commands override the normal setup/hold analysis with explicit delay requirements. They are commonly used for:
- Point-to-point delay constraints
- Paths where you want to control propagation delay directly
- Constraining paths that don't fit the standard clocked model

### Syntax

```tcl
set_max_delay -from <source> -to <destination> <delay_value>
set_min_delay -from <source> -to <destination> <delay_value>
```

### Examples

#### Constraining a CDC Path

```tcl
# Ensure CDC data path is no longer than 5 ns
# (Used when the synchronizer protocol requires bounded delay)
set_max_delay -from [get_registers {src_data[*]}] \
              -to   [get_registers {dst_sync[0][*]}] 5.000
set_min_delay -from [get_registers {src_data[*]}] \
              -to   [get_registers {dst_sync[0][*]}] 0.000
```

#### Constraining a Combinational Output Path

```tcl
# Pure combinational path from input to output (no registers)
set_max_delay -from [get_ports TRIGGER_IN] \
              -to   [get_ports ALARM_OUT] 15.000
```

#### set_max_delay vs. set_false_path for CDC

Using `set_max_delay` instead of `set_false_path` for CDC can be better because it still ensures the path delay is bounded:

```tcl
# Instead of completely ignoring the path:
# set_false_path -from [get_registers src] -to [get_registers dst_sync[0]]

# Bound the delay to something reasonable:
set_max_delay -from [get_registers {gray_ptr[*]}] \
              -to   [get_registers {gray_sync[0][*]}] 8.000
```

## Exception Priority Rules

When multiple exceptions apply to the same path, Quartus uses these priority rules (highest to lowest):

1. **Most specific path wins**: A constraint specifying `-from` AND `-to` overrides one with only `-from` or only `-to`
2. **`set_false_path`** overrides `set_multicycle_path`
3. **`set_max_delay`/`set_min_delay`** overrides `set_multicycle_path` and `set_false_path`
4. **Later declarations** override earlier ones (for same specificity)

### Priority Example

```tcl
# 1. General false path between domains
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]

# 2. Specific max_delay for a particular path in the same domains
# This OVERRIDES the false path for these specific registers
set_max_delay -from [get_registers {clk_a|handshake_req}] \
              -to   [get_registers {clk_b|handshake_ack}] 6.000
```

## Practical Examples

### Example 1: Processor with Slow Peripheral Bus

```tcl
# Main processor clock: 200 MHz
create_clock -name cpu_clk -period 5.000 [get_ports CPU_CLK]

# Peripheral bus is guaranteed stable for 4 CPU clock cycles
# when accessed via the bus controller

# Register file to peripheral bus -- 4-cycle multicycle
set_multicycle_path -setup \
    -from [get_registers {cpu_core|reg_file[*]}] \
    -to   [get_registers {peri_bus|data_reg[*]}] 4
set_multicycle_path -hold \
    -from [get_registers {cpu_core|reg_file[*]}] \
    -to   [get_registers {peri_bus|data_reg[*]}] 3

# Peripheral bus to register file -- 4-cycle multicycle
set_multicycle_path -setup \
    -from [get_registers {peri_bus|rdata_reg[*]}] \
    -to   [get_registers {cpu_core|rd_data[*]}] 4
set_multicycle_path -hold \
    -from [get_registers {peri_bus|rdata_reg[*]}] \
    -to   [get_registers {cpu_core|rd_data[*]}] 3
```

### Example 2: Mixed Clock Design with Multiple Exceptions

```tcl
# Clock definitions
create_clock -name clk_core   -period  5.000 [get_ports CORE_CLK]
create_clock -name clk_io     -period 10.000 [get_ports IO_CLK]
create_clock -name clk_debug  -period 40.000 [get_ports DBG_CLK]

derive_pll_clocks
derive_clock_uncertainty

# --- False Paths ---

# Debug logic is not timing critical
set_false_path -from [get_clocks clk_debug] -to [get_clocks clk_core]
set_false_path -from [get_clocks clk_core]  -to [get_clocks clk_debug]

# Asynchronous reset
set_false_path -from [get_ports RESET_N]

# Static configuration (set once at boot)
set_false_path -from [get_registers {config_regs|mode_reg[*]}]
set_false_path -from [get_registers {config_regs|feature_en[*]}]

# --- Multicycle Paths ---

# Core-to-IO bus bridge: data stable for 2 core clocks
set_multicycle_path -setup -start \
    -from [get_clocks clk_core] \
    -to   [get_clocks clk_io] 2
set_multicycle_path -hold -start \
    -from [get_clocks clk_core] \
    -to   [get_clocks clk_io] 1

# --- Max Delay ---

# Critical handshake signal between core and IO
set_max_delay -from [get_registers {core|handshake_req}] \
              -to   [get_registers {io_ctrl|handshake_sync[0]}] 8.000
```

### Example 3: Reset Domain Crossing

```tcl
# Main clock
create_clock -name sys_clk -period 10.000 [get_ports SYS_CLK]

# Asynchronous reset input
set_false_path -from [get_ports RESET_N]

# Reset synchronizer output (de-assertion is synchronous)
# The reset tree from the synchronizer to all registers is NOT a false path
# It's clocked by sys_clk and must be analyzed normally.

# Only the input to the synchronizer is a false path:
set_false_path -to [get_registers {rst_sync|rst_meta}]
```

### Example 4: Gray Code Counter CDC

```tcl
# Two asynchronous clocks
create_clock -name wr_clk -period 8.000  [get_ports WR_CLK]
create_clock -name rd_clk -period 12.000 [get_ports RD_CLK]

# Gray code pointer crossing from write to read domain
# Gray code guarantees only 1 bit changes at a time
# Use max_delay instead of false_path to bound skew between bits
set_max_delay -from [get_registers {fifo|wr_gray_ptr[*]}] \
              -to   [get_registers {fifo|rd_sync_wr_ptr[0][*]}] 12.000
set_min_delay -from [get_registers {fifo|wr_gray_ptr[*]}] \
              -to   [get_registers {fifo|rd_sync_wr_ptr[0][*]}] 0.000

# Gray code pointer crossing from read to write domain
set_max_delay -from [get_registers {fifo|rd_gray_ptr[*]}] \
              -to   [get_registers {fifo|wr_sync_rd_ptr[0][*]}] 8.000
set_min_delay -from [get_registers {fifo|rd_gray_ptr[*]}] \
              -to   [get_registers {fifo|wr_sync_rd_ptr[0][*]}] 0.000
```

---

**Previous: [Chapter 3 - I/O Timing Constraints](03_io_constraints.md)** | **Next: [Chapter 5 - Advanced Constraints](05_advanced_constraints.md)**
