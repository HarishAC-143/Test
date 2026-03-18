# Altera FPGA Static Timing Analysis (SDC) — Comprehensive Tutorial

A practical, in-depth guide to writing Synopsys Design Constraints (SDC) for Altera (Intel) FPGAs using the TimeQuest / Timing Analyzer tool. Every concept is paired with annotated examples you can adapt directly to your own designs.

---

## Table of Contents

1. [What Is Static Timing Analysis?](#1-what-is-static-timing-analysis)
2. [SDC — The Constraint Language](#2-sdc--the-constraint-language)
3. [TimeQuest / Timing Analyzer Overview](#3-timequest--timing-analyzer-overview)
4. [Clock Constraints](#4-clock-constraints)
5. [Generated Clocks](#5-generated-clocks)
6. [I/O Timing Constraints](#6-io-timing-constraints)
7. [Clock Groups and Relationships](#7-clock-groups-and-relationships)
8. [Timing Exceptions](#8-timing-exceptions)
9. [Clock Uncertainty and Jitter](#9-clock-uncertainty-and-jitter)
10. [Advanced Constraints](#10-advanced-constraints)
11. [Practical Examples](#11-practical-examples)
12. [Common Pitfalls and Best Practices](#12-common-pitfalls-and-best-practices)
13. [SDC Command Quick Reference](#13-sdc-command-quick-reference)
14. [Further Reading](#14-further-reading)

---

## 1. What Is Static Timing Analysis?

Static Timing Analysis (STA) verifies that every register-to-register data path in a digital design meets its setup and hold timing requirements **without simulating the design with test vectors**. It is exhaustive — it checks every possible path — and fast compared to gate-level simulation.

### Key Timing Concepts

```
         ┌──────────┐    Combinational     ┌──────────┐
  Data ──►  Reg A    ├────── Logic ─────────►  Reg B    ├── Data
         │  (Launch) │     (Data Path)      │ (Capture) │
  Clk ───►          │                      │           ◄── Clk
         └──────────┘                      └──────────┘
```

| Term | Definition |
|------|-----------|
| **Setup time (Tsu)** | Minimum time data must be stable *before* the capturing clock edge. |
| **Hold time (Th)** | Minimum time data must remain stable *after* the capturing clock edge. |
| **Clock-to-Q (Tco)** | Delay from the clock edge to valid data appearing at a register's Q output. |
| **Data arrival time** | Clock-to-Q + combinational delay along the data path. |
| **Data required time** | Clock period − setup time (for setup analysis). |
| **Slack** | `Required time − Arrival time`. Positive slack = timing met; negative = violation. |
| **Clock skew** | Difference in clock arrival time at the launch and capture registers. |
| **Recovery / Removal** | Analogous to setup/hold, but for asynchronous control signals (reset, set, enable). |

### Setup and Hold Relationships

**Setup check (max-delay analysis):**

```
Slack_setup = (T_clk + T_skew) − T_su − T_co − T_data
```

**Hold check (min-delay analysis):**

```
Slack_hold = T_co_min + T_data_min − T_hold − T_skew
```

A design passes timing when **all** setup and hold slack values are ≥ 0.

---

## 2. SDC — The Constraint Language

SDC (Synopsys Design Constraints) is an industry-standard Tcl-based format originally created by Synopsys. Altera's Quartus toolchain (TimeQuest Timing Analyzer in older versions, Timing Analyzer in modern versions) uses SDC to define timing intent. The SDC file tells the tool:

- What clocks exist and their properties.
- How I/O ports relate to external clocks.
- Which paths are exceptions (false paths, multicycle paths, etc.).

SDC files are plain text with a `.sdc` extension. They are evaluated top to bottom; order matters when commands reference objects created by earlier commands.

### SDC File Basics

```tcl
# Lines starting with '#' are comments

# Every SDC file should begin with clock definitions,
# then I/O constraints, then exceptions.
# This ordering is a strong convention, not a syntactic requirement.

# Tcl variables and expressions are fully supported:
set CLK_PERIOD 10.0
create_clock -name sys_clk -period $CLK_PERIOD [get_ports clk]
```

### Object Access Commands

SDC uses "get_*" commands (collection accessors) to refer to design objects:

| Command | Returns |
|---------|---------|
| `get_ports <pattern>` | Top-level I/O ports |
| `get_pins <pattern>` | Internal cell pins (hierarchical) |
| `get_cells <pattern>` | Instances (cells) in the netlist |
| `get_clocks <pattern>` | Previously defined clock objects |
| `get_nets <pattern>` | Nets in the netlist |
| `get_registers <pattern>` | Register (flip-flop) instances — Altera extension |

Wildcards `*` (any characters) and `?` (single character) are supported in patterns.

```tcl
# All ports starting with "data_"
get_ports data_*

# All registers in the UART instance
get_registers uart_inst|*

# Pin 'clk' on cell 'pll_inst'
get_pins pll_inst|clk
```

> **Note:** Altera uses `|` (pipe) as the hierarchy separator, not `/` (slash).

---

## 3. TimeQuest / Timing Analyzer Overview

Altera's timing analysis flow:

```
  ┌─────────────┐     ┌────────────┐     ┌──────────────────┐
  │  SDC File    │────►│  Quartus   │────►│  Timing Analyzer │
  │  (.sdc)      │     │  Fitter    │     │  (TimeQuest)     │
  └─────────────┘     └────────────┘     └──────────────────┘
                                                  │
                                          ┌───────▼───────┐
                                          │ Timing Reports │
                                          │  (slack, fmax) │
                                          └───────────────┘
```

### How Quartus Uses SDC

1. **Synthesis** — SDC is read to guide optimization.
2. **Fitter (Place & Route)** — SDC drives placement and routing to meet timing.
3. **Timing Analyzer** — SDC defines the analysis; reports are generated against these constraints.

### Invoking Timing Analyzer (command line)

```bash
# Run STA after compilation
quartus_sta my_project --sdc_file=my_constraints.sdc

# Or within a Tcl console
quartus_sta --tcl_eval "project_open my_project; create_timing_netlist; read_sdc; update_timing_netlist; report_timing; project_close"
```

### Useful Tcl Commands Inside Timing Analyzer

```tcl
# Report worst-case setup paths
report_timing -setup -npaths 20

# Report hold violations
report_timing -hold -npaths 10

# Report all clocks
report_clocks

# Report minimum period (Fmax) for every clock domain
report_fmax_summary

# Report unconstrained paths (should be empty for a well-constrained design)
report_ucp

# Report clock transfers (inter-domain crossings)
report_clock_transfers
```

---

## 4. Clock Constraints

Clock definitions are the **most important** constraints. Without them, the Timing Analyzer has no reference for any timing check.

### 4.1 `create_clock` — Base / Primary Clocks

Define every clock that enters the FPGA through a port or is generated by an oscillator.

```tcl
create_clock -name <clock_name> -period <period_ns> [<targets>]
```

| Option | Description |
|--------|-------------|
| `-name` | Logical name for the clock (used in reports and other SDC commands). |
| `-period` | Clock period in nanoseconds. |
| `-waveform {rise fall}` | Optional. Defaults to `{0 half_period}`. |
| `<targets>` | Port(s) or pin(s) the clock is applied to. |

#### Example: Simple 100 MHz Clock

```tcl
create_clock -name sys_clk -period 10.0 [get_ports clk]
```

This creates a clock named `sys_clk` with a 10 ns period (100 MHz), rising at 0 ns and falling at 5 ns.

#### Example: Clock with Custom Duty Cycle

```tcl
# 50 MHz clock, 30% duty cycle (high for 6 ns, low for 14 ns)
create_clock -name clk_30pct -period 20.0 -waveform {0 6.0} [get_ports clk_in]
```

#### Example: Virtual Clock (No Physical Port)

A virtual clock has no target. It represents an external clock that drives devices communicating with the FPGA.

```tcl
create_clock -name virt_clk -period 8.0
```

Virtual clocks are used as references for `set_input_delay` / `set_output_delay` when the external clock does not enter the FPGA.

#### Example: Multiple Clock Inputs

```tcl
create_clock -name clk_a -period 10.0 [get_ports clk_a]
create_clock -name clk_b -period 12.5 [get_ports clk_b]
create_clock -name clk_c -period 20.0 [get_ports clk_c]
```

### 4.2 Oscillator on Internal Pin

Some Altera devices have internal oscillators. Constrain them on their output pin:

```tcl
create_clock -name int_osc -period 18.518 [get_pins int_osc_inst|clkout]
```

---

## 5. Generated Clocks

Clocks produced by PLLs, clock dividers, or multiplexers **inside** the FPGA.

### 5.1 PLL-Generated Clocks

Quartus **automatically** creates generated clocks for Altera PLL outputs when `derive_pll_clocks` is used:

```tcl
derive_pll_clocks
```

This single command finds all PLL instances and creates the appropriate `create_generated_clock` commands. It is the **recommended** approach.

If you need manual control (e.g., custom naming):

```tcl
create_generated_clock -name pll_clk_100 \
    -source [get_pins pll_inst|inclk[0]] \
    -multiply_by 2 \
    [get_pins pll_inst|clk[0]]

create_generated_clock -name pll_clk_50 \
    -source [get_pins pll_inst|inclk[0]] \
    -divide_by 2 \
    [get_pins pll_inst|clk[1]]
```

| Option | Description |
|--------|-------------|
| `-source` | The pin that the source clock drives into the generating cell. |
| `-multiply_by N` | Frequency multiplication factor. |
| `-divide_by N` | Frequency division factor. |
| `-duty_cycle D` | Output duty cycle (percentage). |
| `-phase P` | Phase shift in degrees. |

### 5.2 Logic-Based Clock Dividers

If you divide a clock using RTL logic (e.g., toggling a register), you must manually create a generated clock:

```verilog
// RTL: simple divide-by-2
always @(posedge clk)
    clk_div2 <= ~clk_div2;
```

```tcl
create_generated_clock -name clk_div2 \
    -source [get_ports clk] \
    -divide_by 2 \
    [get_registers clk_div2]
```

### 5.3 Clock Multiplexer

When a mux selects between two clocks, define both possible clocks on the mux output. Use `-add` so the second definition doesn't overwrite the first:

```tcl
create_generated_clock -name mux_clk_a \
    -source [get_ports clk_a] \
    -master_clock clk_a \
    [get_pins clk_mux_inst|combout]

create_generated_clock -name mux_clk_b \
    -source [get_ports clk_b] \
    -master_clock clk_b \
    -add \
    [get_pins clk_mux_inst|combout]

# The two mux outputs are mutually exclusive
set_clock_groups -physically_exclusive -group {mux_clk_a} -group {mux_clk_b}
```

---

## 6. I/O Timing Constraints

I/O constraints tell the Timing Analyzer how external devices interact with the FPGA's pins.

### 6.1 `set_input_delay`

Specifies how late (or early) data arrives at an FPGA input port **relative to a clock edge**.

```tcl
set_input_delay -clock <ref_clock> -max <max_delay_ns> [get_ports <port>]
set_input_delay -clock <ref_clock> -min <min_delay_ns> [get_ports <port>]
```

#### System-Synchronous Input (Same Clock Source)

```
                 External Device              FPGA
              ┌──────────────────┐     ┌──────────────────┐
  Board Clk ──► Reg ──► Tco+Tbd ──────► Input Port ──► Reg
              └──────────────────┘     └──────────────────┘
```

- `Tco` = clock-to-output of external device
- `Tbd` = board delay (PCB trace)

```tcl
# External device: Tco_max=5ns, Tbd_max=1.5ns => max input delay = 6.5ns
# External device: Tco_min=2ns, Tbd_min=0.5ns => min input delay = 2.5ns
set_input_delay -clock sys_clk -max 6.5 [get_ports data_in[*]]
set_input_delay -clock sys_clk -min 2.5 [get_ports data_in[*]]
```

#### Source-Synchronous Input (Clock Travels With Data)

When the external device sends a clock alongside data:

```tcl
create_clock -name rx_clk -period 10.0 [get_ports rx_clk]

# Data valid window relative to received clock
set_input_delay -clock rx_clk -max 2.0 [get_ports rx_data[*]]
set_input_delay -clock rx_clk -min -1.0 [get_ports rx_data[*]]
```

Negative minimum input delay is valid and common in source-synchronous interfaces — it means data arrives *before* the clock edge.

### 6.2 `set_output_delay`

Specifies how much time the downstream device needs data to be stable **before and after its capturing clock edge**.

```tcl
set_output_delay -clock <ref_clock> -max <max_delay_ns> [get_ports <port>]
set_output_delay -clock <ref_clock> -min <min_delay_ns> [get_ports <port>]
```

#### System-Synchronous Output

```tcl
# Downstream device setup time: 3ns, board delay: 1.5ns
# max output delay = Tsu + Tbd = 4.5ns
set_output_delay -clock sys_clk -max 4.5 [get_ports data_out[*]]

# Downstream device hold time: -1ns, board delay: 0.3ns
# min output delay = -Th + Tbd_min = -0.7ns
set_output_delay -clock sys_clk -min -0.7 [get_ports data_out[*]]
```

#### Using a Virtual Clock

When the external clock doesn't enter the FPGA:

```tcl
create_clock -name virt_ext_clk -period 10.0

set_output_delay -clock virt_ext_clk -max 4.0 [get_ports spi_mosi]
set_output_delay -clock virt_ext_clk -min -1.0 [get_ports spi_mosi]
```

### 6.3 `set_input_delay` / `set_output_delay` with DDR

For double-data-rate interfaces, constrain both rising and falling edges:

```tcl
# DDR input
set_input_delay -clock ddr_clk -max 1.5 [get_ports ddr_dq[*]]
set_input_delay -clock ddr_clk -max 1.5 -clock_fall -add_delay [get_ports ddr_dq[*]]
set_input_delay -clock ddr_clk -min -0.5 [get_ports ddr_dq[*]]
set_input_delay -clock ddr_clk -min -0.5 -clock_fall -add_delay [get_ports ddr_dq[*]]
```

---

## 7. Clock Groups and Relationships

### 7.1 `set_clock_groups`

Defines relationships between clocks. By default, the Timing Analyzer assumes all clocks are related and performs timing analysis between every pair. This is often too pessimistic.

| Option | Meaning |
|--------|---------|
| `-asynchronous` | Clocks are from independent sources; no phase relationship. **No timing analysis between groups.** |
| `-exclusive` | Clocks never coexist (e.g., mux-selected clocks). **No timing analysis between groups.** |
| `-physically_exclusive` | Clocks defined on the same pin but cannot be active simultaneously. |
| `-logically_exclusive` | Clocks on different pins that are mutually exclusive by design. |

```tcl
# PLL output clocks are related to each other (same source),
# but asynchronous to an external independent clock.
set_clock_groups -asynchronous \
    -group {sys_clk pll_clk_100 pll_clk_50} \
    -group {ext_async_clk}
```

#### Multiple Asynchronous Domains

```tcl
# Three independent clock domains
set_clock_groups -asynchronous \
    -group [get_clocks {clk_a pll_a_*}] \
    -group [get_clocks {clk_b pll_b_*}] \
    -group [get_clocks {clk_c}]
```

### 7.2 `derive_clock_uncertainty`

Automatically calculates and applies clock uncertainty (jitter, phase error) based on device characteristics:

```tcl
derive_clock_uncertainty
```

This should appear in virtually every SDC file. Quartus uses device-specific models to compute PLL jitter, inter-clock transfers, etc.

---

## 8. Timing Exceptions

Exceptions override default timing analysis for specific paths.

### 8.1 `set_false_path`

Marks paths that should **never** be analyzed for timing. The Timing Analyzer completely ignores these paths.

Common use cases:
- Asynchronous reset paths
- Static configuration registers
- Paths between asynchronous clock domains (when already handled by synchronizers)
- Test/debug-only paths

```tcl
# Asynchronous reset — no timing check needed
set_false_path -from [get_ports rst_n]

# Static configuration that changes only at startup
set_false_path -from [get_ports cfg_sw[*]]

# Between specific clock domains (alternative to set_clock_groups for fine control)
set_false_path -from [get_clocks clk_a] -to [get_clocks clk_b]
set_false_path -from [get_clocks clk_b] -to [get_clocks clk_a]
```

> **Warning:** Over-use of `set_false_path` can mask real timing problems. Only false-path paths that are *genuinely* not timing-critical.

### 8.2 `set_multicycle_path`

Allows paths more than one clock cycle to propagate. Used when the architecture guarantees that data is sampled only every N cycles.

```tcl
set_multicycle_path -setup -from <source> -to <dest> <N>
set_multicycle_path -hold  -from <source> -to <dest> <N-1>
```

The hold adjustment `N-1` is the standard companion to a setup multicycle of `N`. It keeps the hold check relative to the correct edge.

#### Example: 2-Cycle Path

```tcl
# Data path from slow_reg to fast_reg is captured every 2 clock cycles
set_multicycle_path -setup -end -from [get_registers slow_reg[*]] -to [get_registers fast_reg[*]] 2
set_multicycle_path -hold  -end -from [get_registers slow_reg[*]] -to [get_registers fast_reg[*]] 1
```

#### Example: 3-Cycle Path Across Clock Domains

```tcl
set_multicycle_path -setup -end -from [get_clocks clk_slow] -to [get_clocks clk_fast] 3
set_multicycle_path -hold  -end -from [get_clocks clk_slow] -to [get_clocks clk_fast] 2
```

#### `-start` vs `-end` Reference

| Flag | Meaning |
|------|---------|
| `-end` | Multicycle count is relative to the **destination** (capture) clock. **Default for setup.** |
| `-start` | Multicycle count is relative to the **source** (launch) clock. **Default for hold.** |

### 8.3 `set_max_delay` / `set_min_delay`

Override the default timing requirement for specific paths with an absolute delay value.

```tcl
# CDC synchronizer path: constrain to one destination clock period
set_max_delay -from [get_registers cdc_src_reg] -to [get_registers cdc_sync_reg[0]] 10.0

# Remove the associated min-delay (hold) check
set_min_delay -from [get_registers cdc_src_reg] -to [get_registers cdc_sync_reg[0]] -1.0
```

### 8.4 Applying Exceptions to Specific Paths

You can combine `-from`, `-to`, and `-through` for precise targeting:

```tcl
# False path only through a specific mux
set_false_path -through [get_pins mux_inst|datab]

# Multicycle only for specific register groups
set_multicycle_path -setup \
    -from [get_registers {core|pipeline|stage3|*}] \
    -to   [get_registers {core|pipeline|stage5|*}] \
    2
set_multicycle_path -hold \
    -from [get_registers {core|pipeline|stage3|*}] \
    -to   [get_registers {core|pipeline|stage5|*}] \
    1
```

---

## 9. Clock Uncertainty and Jitter

### 9.1 `set_clock_uncertainty`

Manually specify additional clock uncertainty (pessimism) for setup or hold checks:

```tcl
# Add 200 ps of setup uncertainty to sys_clk
set_clock_uncertainty -setup -to [get_clocks sys_clk] 0.200

# Add 50 ps of hold uncertainty to sys_clk
set_clock_uncertainty -hold -to [get_clocks sys_clk] 0.050

# Inter-clock transfer uncertainty
set_clock_uncertainty -setup -from [get_clocks clk_a] -to [get_clocks clk_b] 0.300
```

### 9.2 `derive_clock_uncertainty` (Recommended)

Prefer the automatic command over manual values:

```tcl
derive_clock_uncertainty
```

Quartus uses per-device jitter models and PLL characteristics to compute realistic uncertainty values.

### 9.3 Clock Latency

Although less common in FPGAs (because clock trees are well characterized by the tool), you can specify clock latency:

```tcl
# Source latency (external, before the clock enters the FPGA)
set_clock_latency -source -early 0.5 [get_clocks sys_clk]
set_clock_latency -source -late  1.0 [get_clocks sys_clk]
```

---

## 10. Advanced Constraints

### 10.1 `set_clock_groups` for JTAG

JTAG clocks (TCK) are asynchronous to all functional clocks:

```tcl
create_clock -name altera_reserved_tck -period 100.0 [get_ports altera_reserved_tck]
set_clock_groups -asynchronous -group {altera_reserved_tck}
```

### 10.2 I/O Standards and Drive Strengths

While not SDC per se, they affect timing. SDC handles the timing side:

```tcl
# LVDS input with center-aligned clock
create_clock -name lvds_rx_clk -period 3.333 [get_ports lvds_clk_p]

set_input_delay -clock lvds_rx_clk -max 0.4 [get_ports lvds_data_p[*]]
set_input_delay -clock lvds_rx_clk -min -0.4 [get_ports lvds_data_p[*]]
```

### 10.3 `set_disable_timing`

Disables timing arcs through a cell. Used rarely, for cells where the tool incorrectly infers a timing path:

```tcl
set_disable_timing -from dataa -to combout [get_cells special_mux_inst]
```

### 10.4 `set_max_skew`

Constrains the maximum skew between a group of signals (e.g., a parallel bus):

```tcl
set_max_skew -from [get_ports data_bus[*]] 0.500
```

### 10.5 `set_net_delay`

Constrains the maximum or minimum net delay (useful for long routing paths):

```tcl
set_net_delay -max 2.0 -from [get_pins src|q] -to [get_pins dst|datain]
```

### 10.6 TimeQuest-Specific Altera Extensions

```tcl
# Automatically constrain all PLL outputs
derive_pll_clocks

# Automatically compute clock uncertainty
derive_clock_uncertainty

# Report Fmax for each clock domain
report_fmax_summary

# Report unconstrained paths (aim for zero)
report_ucp
```

---

## 11. Practical Examples

All example files are provided in the [`examples/`](examples/) directory for direct use. Below are walkthroughs of real-world scenarios.

---

### 11.1 Basic System Clock Constraint

**Scenario:** FPGA receives a 50 MHz oscillator on pin `CLK_50`.

```tcl
#-------------------------------------------------------
# Base clock
#-------------------------------------------------------
create_clock -name clk_50 -period 20.0 [get_ports CLK_50]

#-------------------------------------------------------
# Derive PLL outputs and uncertainty
#-------------------------------------------------------
derive_pll_clocks
derive_clock_uncertainty
```

See: [`examples/01_basic_clock_constraints.sdc`](examples/01_basic_clock_constraints.sdc)

---

### 11.2 UART Interface

**Scenario:** UART TX/RX pins at 115200 baud. The UART clock is derived from the system clock internally. Since UART is asynchronous by nature, I/O pins just need basic false-path or relaxed constraints.

```tcl
create_clock -name clk_50 -period 20.0 [get_ports CLK_50]

# UART pins are asynchronous — no meaningful timing relationship to clk_50
set_false_path -from [get_ports uart_rx]
set_false_path -to   [get_ports uart_tx]
```

---

### 11.3 SPI Master Interface

**Scenario:** FPGA is an SPI master clocking out at 25 MHz (period = 40 ns). SCLK is generated from the 100 MHz system clock.

```tcl
create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]
derive_pll_clocks
derive_clock_uncertainty

# Create a virtual clock representing the SPI domain
create_clock -name virt_spi_clk -period 40.0

# SPI outputs: MOSI, CS_N
# Slave requires Tsu=5ns, Th=2ns, board delay ~1ns
set_output_delay -clock virt_spi_clk -max 6.0 [get_ports {spi_mosi spi_cs_n}]
set_output_delay -clock virt_spi_clk -min -1.0 [get_ports {spi_mosi spi_cs_n}]

# SPI input: MISO
# Slave Tco_max=8ns, Tco_min=2ns, board delay ~1ns
set_input_delay -clock virt_spi_clk -max 9.0 [get_ports spi_miso]
set_input_delay -clock virt_spi_clk -min 3.0 [get_ports spi_miso]

# SPI clock output is not a data signal — false path
set_false_path -to [get_ports spi_sclk]
```

See: [`examples/03_spi_interface.sdc`](examples/03_spi_interface.sdc)

---

### 11.4 DDR Memory Interface

**Scenario:** DDR3 interface running at 400 MHz (800 MT/s). This is a source-synchronous, double-data-rate interface.

```tcl
create_clock -name sys_clk -period 10.0 [get_ports SYS_CLK]
derive_pll_clocks
derive_clock_uncertainty

# DDR3 clock (output from PLL, forwarded to memory)
# The PLL output is already constrained by derive_pll_clocks.
# Create a virtual clock for the memory-side timing:
create_clock -name virt_ddr_clk -period 2.5

# DQ bus — DDR, constrain both edges
set_input_delay -clock virt_ddr_clk -max 0.35 [get_ports ddr3_dq[*]]
set_input_delay -clock virt_ddr_clk -max 0.35 -clock_fall -add_delay [get_ports ddr3_dq[*]]
set_input_delay -clock virt_ddr_clk -min -0.35 [get_ports ddr3_dq[*]]
set_input_delay -clock virt_ddr_clk -min -0.35 -clock_fall -add_delay [get_ports ddr3_dq[*]]

# DQS strobe (source-synchronous clock from memory)
create_clock -name ddr3_dqs -period 2.5 [get_ports ddr3_dqs[*]]

# Address/Command — SDR on rising edge only
set_output_delay -clock virt_ddr_clk -max 0.6 [get_ports {ddr3_addr[*] ddr3_ba[*] ddr3_ras_n ddr3_cas_n ddr3_we_n}]
set_output_delay -clock virt_ddr_clk -min -0.4 [get_ports {ddr3_addr[*] ddr3_ba[*] ddr3_ras_n ddr3_cas_n ddr3_we_n}]

# Asynchronous between DDR and system domains
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk}] \
    -group [get_clocks {virt_ddr_clk ddr3_dqs}]
```

See: [`examples/06_ddr_interface.sdc`](examples/06_ddr_interface.sdc)

---

### 11.5 Multi-Clock Domain Design with CDC

**Scenario:** Three clock domains (50 MHz, 100 MHz, 133 MHz). Data crosses between domains through synchronizer chains.

```tcl
create_clock -name clk_50  -period 20.0 [get_ports CLK_50]
create_clock -name clk_100 -period 10.0 [get_ports CLK_100]
create_clock -name clk_133 -period 7.5  [get_ports CLK_133]

derive_pll_clocks
derive_clock_uncertainty

# All three clocks are asynchronous to each other
set_clock_groups -asynchronous \
    -group [get_clocks clk_50]  \
    -group [get_clocks clk_100] \
    -group [get_clocks clk_133]

# ALTERNATIVELY, if you want to constrain the CDC synchronizer paths
# instead of fully false-pathing them:
# set_max_delay -from [get_clocks clk_50] -to [get_clocks clk_100] 10.0
# set_min_delay -from [get_clocks clk_50] -to [get_clocks clk_100] 0.0
```

See: [`examples/07_multi_clock_design.sdc`](examples/07_multi_clock_design.sdc)

---

### 11.6 Source-Synchronous RGMII Interface

**Scenario:** Gigabit Ethernet RGMII at 125 MHz, DDR. The PHY sends a clock (RX_CLK) with the data.

```tcl
create_clock -name sys_clk -period 20.0 [get_ports CLK_50]
derive_pll_clocks
derive_clock_uncertainty

# PHY sends RX_CLK at 125 MHz with data
create_clock -name rgmii_rx_clk -period 8.0 [get_ports rgmii_rx_clk]

# RX_DATA — DDR, center-aligned clock
# RGMII spec: data valid ±1.0 ns around clock edge
set_input_delay -clock rgmii_rx_clk -max 1.0 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -max 1.0 -clock_fall -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min -1.0 [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rx_clk -min -1.0 -clock_fall -add_delay [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]

# TX side — FPGA generates TX_CLK from PLL, edge-aligned with data
# Virtual clock for TX timing analysis
create_clock -name virt_rgmii_tx_clk -period 8.0

set_output_delay -clock virt_rgmii_tx_clk -max 1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock virt_rgmii_tx_clk -max 1.0 -clock_fall -add_delay [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock virt_rgmii_tx_clk -min -1.0 [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock virt_rgmii_tx_clk -min -1.0 -clock_fall -add_delay [get_ports {rgmii_txd[*] rgmii_tx_ctl}]

# TX clock output — false path (it IS the clock, not data)
set_false_path -to [get_ports rgmii_tx_clk]

# RX and TX domains are asynchronous to system clock
set_clock_groups -asynchronous \
    -group [get_clocks {sys_clk}] \
    -group [get_clocks {rgmii_rx_clk}] \
    -group [get_clocks {virt_rgmii_tx_clk}]
```

See: [`examples/08_source_synchronous_rgmii.sdc`](examples/08_source_synchronous_rgmii.sdc)

---

### 11.7 Multicycle Path — Slow Enable

**Scenario:** An enable signal `ce_slow` qualifies data every 4 clock cycles. The data path between `data_reg` and `result_reg` has 4 cycles to settle.

```tcl
create_clock -name sys_clk -period 10.0 [get_ports clk]
derive_clock_uncertainty

# 4-cycle multicycle path
set_multicycle_path -setup -end \
    -from [get_registers {data_reg[*]}] \
    -to   [get_registers {result_reg[*]}] \
    4
set_multicycle_path -hold -end \
    -from [get_registers {data_reg[*]}] \
    -to   [get_registers {result_reg[*]}] \
    3
```

---

### 11.8 Complete Production SDC Template

A realistic, full SDC file for a medium-complexity design:

```tcl
# ==============================================================
# SDC Constraints — Project: my_fpga_design
# Target: Cyclone V (5CEBA4F23C7)
# ==============================================================

# ==============================================================
# 1. Base Clocks
# ==============================================================
create_clock -name clk_50   -period 20.0 [get_ports CLK_50]
create_clock -name clk_osc  -period 40.0 [get_ports CLK_25]

# ==============================================================
# 2. PLL and Derived Clocks
# ==============================================================
derive_pll_clocks

# ==============================================================
# 3. Clock Uncertainty
# ==============================================================
derive_clock_uncertainty

# ==============================================================
# 4. Clock Groups
# ==============================================================
set_clock_groups -asynchronous \
    -group [get_clocks {clk_50 pll_inst|*clk[0]*}] \
    -group [get_clocks {clk_osc}]

# JTAG
set_clock_groups -asynchronous \
    -group [get_clocks altera_reserved_tck]

# ==============================================================
# 5. Input Constraints
# ==============================================================
# Push-buttons and switches — asynchronous
set_false_path -from [get_ports {KEY[*] SW[*]}]

# Synchronous data input bus
set_input_delay -clock clk_50 -max 6.0 [get_ports data_in[*]]
set_input_delay -clock clk_50 -min 1.0 [get_ports data_in[*]]

# ==============================================================
# 6. Output Constraints
# ==============================================================
# LEDs — no timing requirement
set_false_path -to [get_ports {LED[*]}]

# Synchronous data output bus
set_output_delay -clock clk_50 -max 5.0 [get_ports data_out[*]]
set_output_delay -clock clk_50 -min -1.0 [get_ports data_out[*]]

# ==============================================================
# 7. Timing Exceptions
# ==============================================================
# Asynchronous reset
set_false_path -from [get_ports RST_N]

# CDC synchronizer chains (2FF synchronizer — constrain max delay)
set_max_delay -from [get_registers {*cdc_src*}] -to [get_registers {*cdc_sync[0]*}] 10.0
set_min_delay -from [get_registers {*cdc_src*}] -to [get_registers {*cdc_sync[0]*}] 0.0
```

---

## 12. Common Pitfalls and Best Practices

### Pitfalls

| Pitfall | Consequence | Fix |
|---------|-------------|-----|
| Missing `create_clock` | All paths are unconstrained; Fmax is meaningless. | Define **every** clock entering the FPGA. |
| Forgetting `derive_pll_clocks` | PLL outputs are unconstrained. | Add the command, or define generated clocks manually. |
| Omitting `derive_clock_uncertainty` | Optimistic timing — may fail in silicon. | Always include it. |
| Over-using `set_false_path` | Real timing violations are hidden. | Only false-path truly non-functional paths. |
| Incorrect multicycle hold value | Setup passes but hold fails, or vice versa. | Hold multicycle = Setup multicycle − 1 (for `-end`). |
| Not constraining I/O | Ports are unconstrained; I/O timing failures on the board. | Add `set_input_delay` / `set_output_delay` for every functional I/O. |
| Using `set_clock_groups -exclusive` when clocks are asynchronous | Semantically different; may confuse analysis. | Use `-asynchronous` for unrelated clocks, `-exclusive` for muxed clocks. |
| Wrong hierarchy separator | SDC commands silently match nothing. | Use `\|` (pipe) for Altera, not `/`. |

### Best Practices

1. **Constrain everything.** Run `report_ucp` (unconstrained paths) and aim for zero entries.
2. **Define clocks first.** All other constraints reference clock objects.
3. **Use `derive_pll_clocks` and `derive_clock_uncertainty`.** They are accurate and maintainable.
4. **Keep SDC files version-controlled.** Treat them like RTL — review changes.
5. **Comment your constraints.** Explain *why* a path is false-pathed, not just *that* it is.
6. **Separate SDC files by function** if the design is large (e.g., `clocks.sdc`, `io.sdc`, `exceptions.sdc`).
7. **Validate with reports.** After every SDC change, check `report_timing`, `report_clocks`, and `report_fmax_summary`.
8. **Avoid `*` wildcards on `set_false_path -from`/`-to`.** Be specific to avoid accidentally suppressing real paths.
9. **Use `-add_delay` for DDR constraints.** Without it, the second `set_input_delay`/`set_output_delay` overwrites the first.
10. **Test with both slow and fast timing models** (multi-corner analysis) to catch both setup and hold issues.

---

## 13. SDC Command Quick Reference

| Command | Purpose |
|---------|---------|
| `create_clock` | Define a base (primary) clock |
| `create_generated_clock` | Define a derived clock (PLL, divider, mux) |
| `derive_pll_clocks` | Auto-create generated clocks for all PLLs |
| `derive_clock_uncertainty` | Auto-compute jitter/uncertainty for all clocks |
| `set_clock_groups` | Declare clock domain relationships |
| `set_clock_uncertainty` | Manually add clock uncertainty |
| `set_clock_latency` | Specify source or network clock latency |
| `set_input_delay` | Constrain input port arrival time |
| `set_output_delay` | Constrain output port required time |
| `set_false_path` | Exclude paths from timing analysis |
| `set_multicycle_path` | Allow multiple clock cycles for a path |
| `set_max_delay` | Override maximum delay for a path |
| `set_min_delay` | Override minimum delay for a path |
| `set_disable_timing` | Disable timing arcs through a cell |
| `set_max_skew` | Constrain maximum skew on a group of signals |
| `get_ports` | Access top-level I/O ports |
| `get_pins` | Access internal cell pins |
| `get_cells` | Access cell instances |
| `get_clocks` | Access defined clock objects |
| `get_registers` | Access register instances (Altera extension) |
| `get_nets` | Access nets |
| `report_timing` | Report worst-case timing paths |
| `report_clocks` | Report all defined clocks |
| `report_fmax_summary` | Report maximum frequency per clock domain |
| `report_ucp` | Report unconstrained paths |
| `report_clock_transfers` | Report clock domain crossings |

---

## 14. Further Reading

- [Intel Quartus Prime Timing Analyzer Cookbook](https://www.intel.com/content/www/us/en/docs/programmable/683068/current/timing-analyzer-cookbook.html)
- [Intel SDC Command Reference](https://www.intel.com/content/www/us/en/docs/programmable/683432/current/sdc-command-reference.html)
- [TimeQuest User Guide (legacy)](https://www.intel.com/content/www/us/en/docs/programmable/683068/current/introduction-to-the-timing-analyzer.html)
- [Synopsys SDC Specification (IEEE 1801 related)](https://www.synopsys.com/)
- [Intel FPGA Training — Static Timing Analysis](https://www.intel.com/content/www/us/en/programmable/support/training/overview.html)

---

*This tutorial and all example files are provided for educational purposes. Adapt constraints to your specific device, board, and design requirements.*
