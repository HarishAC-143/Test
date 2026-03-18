# Altera SPI IP Core — Comprehensive Timing Constraints

SDC timing constraints for the Intel/Altera `altera_avalon_spi` IP core, covering **master mode**, **slave mode**, and a **unified multi-mode** template for all four SPI modes.

---

## Table of Contents

1. [Repository Contents](#repository-contents)
2. [SPI Protocol Background](#spi-protocol-background)
3. [SPI Modes Explained](#spi-modes-explained)
4. [Timing Constraint Strategy](#timing-constraint-strategy)
5. [Master Mode Constraints](#master-mode-constraints)
6. [Slave Mode Constraints](#slave-mode-constraints)
7. [Multi-Mode Template](#multi-mode-template)
8. [Parameter Customisation Guide](#parameter-customisation-guide)
9. [Clock Domain Crossing](#clock-domain-crossing)
10. [Common Pitfalls](#common-pitfalls)
11. [Integration Steps](#integration-steps)

---

## Repository Contents

| File | Description |
|------|-------------|
| `spi_master_constraints.sdc` | Full SDC for the FPGA acting as **SPI master** |
| `spi_slave_constraints.sdc` | Full SDC for the FPGA acting as **SPI slave** |
| `spi_multimode_constraints.sdc` | Unified template that supports all four SPI modes via a single `SPI_MODE` variable |

---

## SPI Protocol Background

The Serial Peripheral Interface (SPI) is a synchronous, full-duplex serial bus.  It uses four signals:

| Signal | Direction (Master) | Direction (Slave) | Purpose |
|--------|-------------------|-------------------|---------|
| SCLK | Output | Input | Serial clock |
| MOSI | Output | Input | Master-to-slave data |
| MISO | Input | Output | Slave-to-master data |
| SS_n | Output | Input | Active-low slave select |

Key characteristics relevant to timing analysis:

- **Source-synchronous** — clock and data originate from the same device.
- **SDR** — one data bit per clock edge (single data rate).
- **Half-duplex data edges** — data is shifted on one clock edge and sampled on the opposite edge, giving roughly half a clock period of setup margin.

---

## SPI Modes Explained

SPI defines four modes based on two configuration bits:

- **CPOL** (Clock Polarity): idle level of SCLK (0 = low, 1 = high).
- **CPHA** (Clock Phase): which edge captures data (0 = leading, 1 = trailing).

| Mode | CPOL | CPHA | SCLK Idle | Sample Edge | Shift Edge |
|------|------|------|-----------|-------------|------------|
| 0 | 0 | 0 | Low | Rising (leading) | Falling (trailing) |
| 1 | 0 | 1 | Low | Falling (trailing) | Rising (leading) |
| 2 | 1 | 0 | High | Falling (leading) | Rising (trailing) |
| 3 | 1 | 1 | High | Rising (trailing) | Falling (leading) |

**Why modes matter for SDC:**  
The `-clock_fall` flag in `set_input_delay` and `set_output_delay` selects which clock edge is the timing reference. Choosing the wrong edge produces incorrect setup/hold analysis.

> **Altera slave mode note:** The `altera_avalon_spi` IP in slave mode only supports modes 1 and 3 (CPHA=1).  Mode 0 and 2 slave operation is not guaranteed by the IP.

---

## Timing Constraint Strategy

### Why Timing Constraints Are Needed

Without SDC constraints, the Quartus timing analyser has no information about the external timing environment.  Unconstrained I/O paths are reported as "unconstrained" and may silently fail in hardware.  Proper constraints ensure:

1. **Setup analysis** — data arrives early enough before the sampling edge.
2. **Hold analysis** — data is stable long enough after the sampling edge.
3. **Accurate slack reporting** — timing reports reflect real-world margins.

### Constraint Building Blocks

| SDC Command | Purpose |
|---|---|
| `create_clock` | Define frequency and waveform of a clock entering the FPGA |
| `create_generated_clock` | Define a clock derived from another (e.g., SCLK from sys_clk) |
| `set_input_delay` | Specify when external data arrives relative to a clock edge |
| `set_output_delay` | Specify when the downstream device needs data relative to a clock edge |
| `set_clock_uncertainty` | Account for jitter and PLL uncertainty |
| `set_false_path` | Exclude logically impossible timing paths |
| `set_multicycle_path` | Allow more than one clock period for a path |
| `set_clock_groups` | Declare unrelated or asynchronous clock domains |
| `set_max_delay` | Bound worst-case delay without full clock-domain analysis |

### Virtual Clocks

A **virtual clock** has no physical source inside the FPGA.  It represents the clock as seen by the external device.  We use virtual clocks as the `-clock` reference for `set_input_delay` and `set_output_delay` so that the analyser models the timing budget at the FPGA boundary without tying constraints to internal clock tree delays.

---

## Master Mode Constraints

When the FPGA is the SPI master, it generates SCLK and drives MOSI/SS_n.  The constraint file `spi_master_constraints.sdc` handles this scenario.

### Clock Modelling

```
SCLK = sys_clk / N    (generated clock)
```

`create_generated_clock` tells Quartus the exact frequency and phase relationship so it can compute setup/hold slack on the SCLK-aligned I/O paths.

A virtual clock (`spi_sclk_virtual`) at the same frequency represents SCLK as perceived at the external slave pins.

### Output Delay (MOSI, SS_n)

The slave must see valid data for `TSU` (setup) before and `TH` (hold) after its sampling edge.

```
set_output_delay -max = BOARD_DELAY_MAX + SLAVE_TSU
set_output_delay -min = -(SLAVE_TH - BOARD_DELAY_MIN)
```

The **max** value tells Quartus the latest the data can change and still meet setup.  
The **min** value (often negative) tells Quartus how early the data can change without violating hold.

### Input Delay (MISO)

MISO undergoes a round-trip: SCLK travels from FPGA to slave, the slave responds with MISO, and MISO travels back.

```
set_input_delay -max = 2 × BOARD_DELAY_MAX + SLAVE_TCO_MAX
set_input_delay -min = 2 × BOARD_DELAY_MIN + SLAVE_TCO_MIN
```

The factor of 2 accounts for SCLK going out and MISO coming back.

### Edge Selection

- **Mode 0/3:** MOSI is referenced to the rising edge (slave samples on rising), MISO is referenced to the falling edge with `-clock_fall` (slave shifts on falling).
- **Mode 1/2:** Swap the edges.

---

## Slave Mode Constraints

When the FPGA is the SPI slave, SCLK is an **external input clock**.  The constraint file `spi_slave_constraints.sdc` handles this scenario.

### Clock Modelling

SCLK enters the FPGA as an asynchronous clock.  It is defined with `create_clock` on the SPI_SCLK port:

```
create_clock -name spi_sclk_in -period $SPI_CLK_PERIOD [get_ports SPI_SCLK]
```

### Input Delay (MOSI, SS_n)

The master drives MOSI synchronously with SCLK.  The input delay models the master's clock-to-output plus board trace delay:

```
set_input_delay -max = MASTER_TCO_MAX + BOARD_DELAY_MAX
set_input_delay -min = MASTER_TCO_MIN + BOARD_DELAY_MIN
```

### Output Delay (MISO)

MISO must meet the master's setup/hold requirements:

```
set_output_delay -max = BOARD_DELAY_MAX + MASTER_TSU
set_output_delay -min = -(MASTER_TH - BOARD_DELAY_MIN)
```

### Synchroniser Architecture

The `altera_avalon_spi` slave core can optionally synchronise SCLK, MOSI, and SS_n through double flip-flop (2FF) synchronisers clocked by sys_clk.  When this feature is enabled:

1. **SCLK is treated as data**, not a clock — it passes through synchroniser registers.
2. **No `create_clock` on SPI_SCLK** — declare `set_false_path` from the SPI input ports instead.
3. **MISO is driven from sys_clk domain** — constrain it with `set_output_delay -clock sys_clk`.

The SDC file provides both approaches as selectable sections.

---

## Multi-Mode Template

The file `spi_multimode_constraints.sdc` provides a single SDC that handles all four SPI modes.  Change the `SPI_MODE` variable at the top:

```tcl
set SPI_MODE 0   ;# 0, 1, 2, or 3
```

The Tcl logic automatically selects:
- The correct `-clock_fall` flag for MOSI and MISO.
- The correct `-phase` offset for `create_generated_clock` when CPOL=1.

This is useful when your design supports runtime-configurable SPI mode and you need to verify timing under each configuration.

---

## Parameter Customisation Guide

All SDC files use Tcl variables at the top.  Customise these to match your design:

### Clock Parameters

| Variable | Default | Description |
|----------|---------|-------------|
| `SPI_CLK_FREQ_MHZ` | 25.0 | SPI serial clock frequency |
| `SYS_CLK_FREQ_MHZ` | 100.0 | System/Avalon clock frequency |

### Board-Level Delays

| Variable | Default | Description |
|----------|---------|-------------|
| `BOARD_DELAY_MAX` | 1.5 ns | Worst-case PCB trace + connector delay |
| `BOARD_DELAY_MIN` | 0.2 ns | Best-case PCB trace delay |

Estimate these from:
- PCB trace length (rule of thumb: ~150 ps/inch for FR-4 microstrip).
- Connector/cable delays if applicable.
- Add margin for manufacturing variation.

### External Device Timing (Master Mode)

| Variable | Default | Description |
|----------|---------|-------------|
| `SLAVE_TSU` | 5.0 ns | Slave setup time (from slave device datasheet) |
| `SLAVE_TH` | 2.0 ns | Slave hold time |
| `SLAVE_TCO_MAX` | 8.0 ns | Slave clock-to-output, worst case |
| `SLAVE_TCO_MIN` | 1.0 ns | Slave clock-to-output, best case |

### External Device Timing (Slave Mode)

| Variable | Default | Description |
|----------|---------|-------------|
| `MASTER_TCO_MAX` | 7.0 ns | Master clock-to-output, worst case |
| `MASTER_TCO_MIN` | 1.0 ns | Master clock-to-output, best case |
| `MASTER_TSU` | 5.0 ns | Master setup time for MISO |
| `MASTER_TH` | 2.0 ns | Master hold time for MISO |

### How to Get Timing Numbers

1. **Slave/master device datasheet** — look for SPI timing tables labelled "AC Characteristics" or "SPI Timing Parameters" with parameters like `t_SU`, `t_H`, `t_CO`, `t_V`, etc.
2. **PCB layout tool** — extract trace lengths and calculate propagation delay.
3. **IBIS simulation** — for high-speed designs, simulate I/O buffer + trace + load for accurate delay estimates.

---

## Clock Domain Crossing

### SCLK ↔ sys_clk Relationship

| Scenario | Relationship | Constraint |
|----------|-------------|------------|
| Master mode | SCLK derived from sys_clk | `create_generated_clock` (related) |
| Slave mode (no sync) | SCLK is external input | `set_clock_groups -asynchronous` |
| Slave mode (with sync) | SCLK treated as data | `set_false_path` from SPI inputs |

### Why Asynchronous Groups Matter

If Quartus analyses setup/hold paths between truly asynchronous clocks, it may report false violations (or worse, silently pass timing on paths that are actually unsafe without synchronisers).  Declaring `-asynchronous` clock groups removes these paths from analysis and relies on the synchroniser hardware for metastability protection.

### Bounded Crossing (Alternative)

For designs where you need to guarantee a maximum latency through the synchroniser, use `set_max_delay` instead of `set_clock_groups`:

```tcl
set_max_delay -from [get_clocks spi_sclk_in] \
              -to   [get_clocks sys_clk] \
              [expr {$SYS_CLK_PERIOD * 2}]
```

This allows Quartus to verify the synchroniser path completes within 2 sys_clk periods.

---

## Common Pitfalls

### 1. Missing `-clock_fall` Flag

Omitting `-clock_fall` when the reference edge is the falling edge causes Quartus to analyse against the wrong half-period, producing either false violations or masking real timing failures.

### 2. Forgetting Round-Trip Delay for MISO

In master mode, MISO timing must account for SCLK travelling to the slave AND MISO returning — the board delay appears twice in the input delay formula.

### 3. Over-Constraining SS_n

SS_n is asserted well before the first SCLK edge and held throughout the transfer.  Over-tight constraints on SS_n can cause unnecessary place-and-route congestion.  The constraints in these files match SS_n to MOSI timing for completeness, but relaxing them via `set_multicycle_path` is safe in most designs.

### 4. Not Declaring Clock Groups in Slave Mode

Failing to separate spi_sclk_in from sys_clk with `set_clock_groups -asynchronous` causes Quartus to analyse cross-domain paths as if they were synchronous, producing meaningless (and usually failing) timing results.

### 5. Using `set_false_path` When `set_clock_groups` Is Correct

`set_false_path` is directional (from → to), while `set_clock_groups -asynchronous` removes paths in both directions.  For clock domain crossings, always prefer `set_clock_groups`.

### 6. Incorrect Generated Clock Source Pin

The `-source` argument of `create_generated_clock` must point to the actual flip-flop or PLL output driving the divider chain.  After synthesis, verify the path with:

```
quartus_sta --ssc <project>
```

or inspect the post-fit netlist in the Quartus Chip Planner.

---

## Integration Steps

### 1. Choose the Correct File

- FPGA is SPI master → use `spi_master_constraints.sdc`
- FPGA is SPI slave → use `spi_slave_constraints.sdc`
- Need all modes in one file → use `spi_multimode_constraints.sdc`

### 2. Update Parameters

Open the chosen SDC file and modify the variables in Section 1 to match your design:
- Set clock frequencies.
- Enter board delays from your PCB layout.
- Enter external device timing from its datasheet.

### 3. Update Hierarchy Paths

The `create_generated_clock -source` and any `get_pins` / `get_registers` paths must match your post-synthesis netlist hierarchy.  Run a trial compilation and check the TimeQuest messages for unresolved paths.

### 4. Add to Quartus Project

In your `.qsf` file:

```tcl
set_global_assignment -name SDC_FILE spi_master_constraints.sdc
```

Or add it through the Quartus GUI: **Assignments → Settings → Timing Analyzer → SDC files**.

### 5. Verify Timing

After compilation, open the Timing Analyzer and check:

```
quartus_sta <project> --do "report_timing -from [get_ports SPI_*] -to [get_ports SPI_*] -setup -npaths 20"
quartus_sta <project> --do "report_timing -from [get_ports SPI_*] -to [get_ports SPI_*] -hold  -npaths 20"
```

Look for:
- All SPI ports should appear as **constrained** (no unconstrained warnings).
- Setup and hold slack should be **positive**.
- If slack is negative, increase the sys_clk/SCLK frequency ratio or reduce board delays.

### 6. Multi-Corner Analysis

Enable multi-corner analysis for production designs:

```tcl
set_global_assignment -name TIMING_ANALYZER_MULTICORNER_ANALYSIS ON
```

This runs timing analysis across slow/fast process corners and temperature extremes (typically 85C slow and 0C fast models).

---

## References

- [Intel Embedded Peripherals IP User Guide — SPI Core](https://www.intel.com/content/www/us/en/docs/programmable/683130/21-4/spi-core.html)
- [AN 433: Constraining and Analyzing Source-Synchronous Interfaces](https://cdrdv2-public.intel.com/653688/an433.pdf)
- [Quartus Prime Timing Analyzer Cookbook](https://www.intel.com/content/www/us/en/docs/programmable/683068/current/overview.html)
- [Intel FPGA SDC Command Reference](https://www.intel.com/content/www/us/en/docs/programmable/683432/current/synopsys-design-constraints-file-sdc.html)
