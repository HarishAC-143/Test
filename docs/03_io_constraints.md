# Chapter 3: I/O Timing Constraints

## Table of Contents

- [Why I/O Constraints Matter](#why-io-constraints-matter)
- [Understanding I/O Timing Models](#understanding-io-timing-models)
- [set_input_delay](#set_input_delay)
- [set_output_delay](#set_output_delay)
- [System-Synchronous Interfaces](#system-synchronous-interfaces)
- [Source-Synchronous Interfaces](#source-synchronous-interfaces)
- [Constraining Asynchronous Inputs](#constraining-asynchronous-inputs)
- [Practical Examples](#practical-examples)

---

## Why I/O Constraints Matter

The FPGA does not exist in isolation. It connects to external devices (memories, ADCs, processors, transceivers) via board-level traces. The timing of data at the FPGA's I/O pins depends on:

- **Board trace delays** between devices
- **Clock skew** between the FPGA and external devices
- **Setup and hold requirements** of external devices
- **Clock-to-output delays** of external devices

Without I/O constraints, TimeQuest cannot verify that data will be correctly captured at FPGA inputs or correctly presented at FPGA outputs.

## Understanding I/O Timing Models

### Input Delay Model

`set_input_delay` specifies when data arrives at the FPGA input pin **relative to a clock edge**.

```
                  Input Delay
               ◄──────────────►
               │               │
  Clock Edge ──┤               ├── Data Valid at FPGA Pin
               │               │
               ├───────────────┤
               Tco(ext) + Tboard
```

**Input delay = External device Tco + Board trace delay**

### Output Delay Model

`set_output_delay` specifies the timing requirement at the FPGA output pin **relative to a clock edge**. It represents how much time the external device needs.

```
                              Output Delay
                           ◄──────────────────►
                           │                   │
  Clock Edge at Ext Dev ───┤                   ├── Data must be stable
                           │                   │
                           ├───────────────────┤
                           Tsu(ext) + Tboard
```

**Output delay (max) = External device Tsu + Board trace delay**
**Output delay (min) = -(External device Th) + Board trace delay**

## set_input_delay

### Syntax

```tcl
set_input_delay -clock <clock_name> \
                [-max <max_delay>] \
                [-min <min_delay>] \
                [-clock_fall] \
                [-add_delay] \
                [-source_latency_included] \
                [-rise] [-fall] \
                <port_list>
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| `-clock` | Reference clock for the delay calculation |
| `-max` | Maximum input delay (used for setup analysis) |
| `-min` | Minimum input delay (used for hold analysis) |
| `-clock_fall` | Delay is relative to the falling edge of the clock |
| `-add_delay` | Add to existing delay instead of overwriting |

### Important Notes

- Always specify **both** `-max` and `-min` delays for complete analysis
- `-max` affects **setup** analysis (worst-case late data)
- `-min` affects **hold** analysis (best-case early data)

### Basic Examples

```tcl
# Data arrives 2-5 ns after clock edge
set_input_delay -clock sys_clk -max 5.000 [get_ports DATA_IN]
set_input_delay -clock sys_clk -min 2.000 [get_ports DATA_IN]
```

```tcl
# Bus with wildcard matching
set_input_delay -clock sys_clk -max 4.500 [get_ports {ADDR[*]}]
set_input_delay -clock sys_clk -min 1.500 [get_ports {ADDR[*]}]
```

### Using -add_delay for DDR Inputs

For double data rate inputs, data is valid on both edges:

```tcl
# Data captured on rising edge
set_input_delay -clock ddr_clk -max 3.0 [get_ports DDR_DQ[*]]
set_input_delay -clock ddr_clk -min 1.0 [get_ports DDR_DQ[*]]

# Data also captured on falling edge
set_input_delay -clock ddr_clk -max 3.0 -clock_fall -add_delay [get_ports DDR_DQ[*]]
set_input_delay -clock ddr_clk -min 1.0 -clock_fall -add_delay [get_ports DDR_DQ[*]]
```

## set_output_delay

### Syntax

```tcl
set_output_delay -clock <clock_name> \
                 [-max <max_delay>] \
                 [-min <min_delay>] \
                 [-clock_fall] \
                 [-add_delay] \
                 [-source_latency_included] \
                 [-rise] [-fall] \
                 <port_list>
```

### Understanding Max and Min Output Delay

- **`-max` output delay** = Tsu(external) + Tboard
  - Used for setup analysis: ensures FPGA drives data early enough
- **`-min` output delay** = -(Th(external)) + Tboard
  - Used for hold analysis: ensures FPGA doesn't change data too early
  - Often negative because Th(external) is subtracted

### Examples

```tcl
# External device needs:
#   Setup time (Tsu) = 2.0 ns
#   Hold time (Th)   = 0.5 ns
#   Board delay      = 1.0 ns
#
# Max output delay = Tsu + Tboard = 2.0 + 1.0 = 3.0 ns
# Min output delay = -Th + Tboard = -0.5 + 1.0 = 0.5 ns

set_output_delay -clock sys_clk -max 3.000 [get_ports {Q[*]}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {Q[*]}]
```

```tcl
# Negative min output delay (when Th > Tboard):
#   Tsu = 3.0 ns, Th = 1.5 ns, Tboard = 0.8 ns
#   Max = 3.0 + 0.8 = 3.8 ns
#   Min = -1.5 + 0.8 = -0.7 ns

set_output_delay -clock sys_clk -max  3.800 [get_ports DOUT]
set_output_delay -clock sys_clk -min -0.700 [get_ports DOUT]
```

## System-Synchronous Interfaces

In a system-synchronous interface, the same clock feeds both the FPGA and the external device. The clock travels on the PCB alongside the data.

```
                  Board Clock
                     │
            ┌────────┼────────┐
            ▼        │        ▼
         ┌──────┐    │    ┌──────┐
         │ FPGA │◄───┼────│ Ext  │
         │      │    │    │ Dev  │
         └──────┘    │    └──────┘
                   data
```

### Calculating Input Delays

Given:
- External device Tco_max = 8 ns, Tco_min = 2 ns
- Board data delay: Td_max = 1.5 ns, Td_min = 0.5 ns
- Board clock skew: Tskew = ±0.3 ns

```tcl
# Input delay max = Tco_max + Td_max + Tskew
# Input delay min = Tco_min + Td_min - Tskew
set_input_delay -clock sys_clk -max 9.800 [get_ports EXT_DATA]   ;# 8 + 1.5 + 0.3
set_input_delay -clock sys_clk -min 2.200 [get_ports EXT_DATA]   ;# 2 + 0.5 - 0.3
```

### Calculating Output Delays

Given:
- External device Tsu = 3 ns, Th = 1 ns
- Board data delay: Td_max = 1.5 ns, Td_min = 0.5 ns
- Board clock skew: Tskew = ±0.3 ns

```tcl
# Output delay max = Tsu + Td_max + Tskew
# Output delay min = -(Th) + Td_min - Tskew
set_output_delay -clock sys_clk -max 4.800 [get_ports EXT_OUT]   ;# 3 + 1.5 + 0.3
set_output_delay -clock sys_clk -min -0.800 [get_ports EXT_OUT]  ;# -1 + 0.5 - 0.3
```

## Source-Synchronous Interfaces

In a source-synchronous interface, the transmitting device sends a clock along with the data. The clock and data travel together on the PCB, which largely cancels out board trace delays.

```
          ┌──────┐         ┌──────┐
          │      │──CLK───►│      │
          │ Src  │──DATA──►│ Dest │
          │      │         │      │
          └──────┘         └──────┘
```

### Two Alignment Styles

#### 1. Edge-Aligned (Clock and Data Transition Together)

Data transitions at the same time as the clock edge. The receiver must internally shift the clock (typically using a PLL or delay) to sample at the center of the data eye.

```tcl
# Source sends data edge-aligned with the clock
# External device Tco ≈ 0 (data changes with clock)
# Skew between clock and data = ±0.2 ns

# Create the source-synchronous clock
create_clock -name src_clk -period 5.000 [get_ports SS_CLK]

set_input_delay -clock src_clk -max  0.200 [get_ports {SS_DATA[*]}]
set_input_delay -clock src_clk -min -0.200 [get_ports {SS_DATA[*]}]
```

#### 2. Center-Aligned (Clock Edge at Center of Data Eye)

The source intentionally shifts the clock by half a period so the clock edge is centered in the data valid window. This is the easier case for the receiver.

```tcl
# Data valid window: ±Tvalid around the clock edge
# Tvalid = 2.0 ns (data is valid ±2.0 ns around clock edge)
# Period = 5.0 ns, so data changes every 2.5 ns relative to clock

create_clock -name src_clk -period 5.000 [get_ports SS_CLK]

# For center-aligned: input_delay = half_period - Tvalid
set_input_delay -clock src_clk -max  0.500 [get_ports {SS_DATA[*]}]  ;# 2.5 - 2.0
set_input_delay -clock src_clk -min -0.500 [get_ports {SS_DATA[*]}]
```

## Constraining Asynchronous Inputs

Some inputs are truly asynchronous (buttons, external interrupts, reset signals). These should be:

1. Synchronized in RTL using a double-flop synchronizer
2. Declared as false paths in SDC

```tcl
# Asynchronous reset -- synchronized in RTL
set_false_path -from [get_ports RST_N]

# Asynchronous push button
set_false_path -from [get_ports BTN_*]
```

Alternatively, if you want to constrain the path but not relative to any clock:

```tcl
# Set max delay for asynchronous input (for reporting purposes)
set_max_delay 10.000 -from [get_ports ASYNC_IN] -to [get_registers sync_reg[0]]
set_min_delay 0.000 -from [get_ports ASYNC_IN] -to [get_registers sync_reg[0]]
```

## Practical Examples

### Example 1: SPI Slave Interface

```
  SPI Master                    FPGA (SPI Slave)
  ┌──────────┐                 ┌──────────┐
  │          │──SCLK──────────►│          │
  │          │──MOSI──────────►│          │
  │          │◄─MISO───────────│          │
  │          │──CS_N──────────►│          │
  └──────────┘                 └──────────┘
```

```tcl
# SPI clock at 10 MHz (from master)
create_clock -name spi_clk -period 100.000 [get_ports SPI_SCLK]

# MOSI: Master drives data, FPGA captures on rising edge
# Master Tco = 10 ns, Board delay = 2 ns
set_input_delay -clock spi_clk -max 12.000 [get_ports SPI_MOSI]
set_input_delay -clock spi_clk -min  2.000 [get_ports SPI_MOSI]

# CS_N: Same timing as MOSI
set_input_delay -clock spi_clk -max 12.000 [get_ports SPI_CS_N]
set_input_delay -clock spi_clk -min  2.000 [get_ports SPI_CS_N]

# MISO: FPGA drives data, master captures on falling edge
# Master Tsu = 5 ns, Master Th = 2 ns, Board delay = 2 ns
set_output_delay -clock spi_clk -max  7.000 -clock_fall [get_ports SPI_MISO]
set_output_delay -clock spi_clk -min  0.000 -clock_fall [get_ports SPI_MISO]
```

### Example 2: Parallel ADC Interface

```tcl
# System clock
create_clock -name sys_clk -period 20.000 [get_ports CLK_50MHZ]

# Virtual clock for the ADC (ADC has its own clock derived from sys_clk)
create_clock -name adc_clk -period 20.000

# ADC data outputs (12-bit)
# ADC Tco_max = 14 ns, Tco_min = 5 ns
# Board delay = 1.5 ns max, 0.5 ns min
set_input_delay -clock adc_clk -max 15.500 [get_ports {ADC_D[*]}]
set_input_delay -clock adc_clk -min  5.500 [get_ports {ADC_D[*]}]

# ADC busy/ready flag
set_input_delay -clock adc_clk -max 16.000 [get_ports ADC_BUSY]
set_input_delay -clock adc_clk -min  4.000 [get_ports ADC_BUSY]

# ADC conversion start signal (FPGA output)
# ADC Tsu = 4 ns, Th = 1 ns, Board delay = 1.5 ns
set_output_delay -clock adc_clk -max  5.500 [get_ports ADC_CONVST]
set_output_delay -clock adc_clk -min  0.500 [get_ports ADC_CONVST]
```

### Example 3: SDRAM Interface with Virtual Clock

```tcl
# FPGA system clock
create_clock -name clk_100 -period 10.000 [get_ports CLK_100MHZ]

# PLL outputs
derive_pll_clocks

# The SDRAM clock is a PLL output routed off-chip
# We use it as the reference for SDRAM I/O constraints

# Assume PLL output c0 drives SDRAM_CLK pad
# PLL clock name (auto-derived): pll|altpll|auto_generated|pll1|clk[0]
set sdram_pll_clk {pll|altpll_component|auto_generated|pll1|clk[0]}

# SDRAM Address/Command outputs
# SDRAM Tsu = 1.5 ns, Th = 0.8 ns, Board trace = 0.2 ns
set_output_delay -clock $sdram_pll_clk -max  1.700 [get_ports {SDRAM_ADDR[*] SDRAM_BA[*] SDRAM_CS_N SDRAM_RAS_N SDRAM_CAS_N SDRAM_WE_N}]
set_output_delay -clock $sdram_pll_clk -min -0.600 [get_ports {SDRAM_ADDR[*] SDRAM_BA[*] SDRAM_CS_N SDRAM_RAS_N SDRAM_CAS_N SDRAM_WE_N}]

# SDRAM Data (bidirectional)
# Write: same as address constraints
set_output_delay -clock $sdram_pll_clk -max  1.700 [get_ports {SDRAM_DQ[*]}]
set_output_delay -clock $sdram_pll_clk -min -0.600 [get_ports {SDRAM_DQ[*]}]

# Read: SDRAM Tac_max = 5.4 ns, Tac_min = 1.0 ns
set_input_delay -clock $sdram_pll_clk -max 5.400 [get_ports {SDRAM_DQ[*]}]
set_input_delay -clock $sdram_pll_clk -min 1.000 [get_ports {SDRAM_DQ[*]}]
```

---

**Previous: [Chapter 2 - Clock Constraints](02_clock_constraints.md)** | **Next: [Chapter 4 - Timing Exceptions](04_timing_exceptions.md)**
