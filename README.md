# Altera (Intel) SPI IP Core — Timing Constraints

Production-ready SDC timing constraints for the **Intel (Altera) Avalon SPI IP core** (`altera_avalon_spi`), targeting Quartus Prime (Standard and Pro editions).

---

## Overview

The SPI (Serial Peripheral Interface) bus consists of four signals:

| Signal  | Direction (Master) | Direction (Slave) | Description                     |
|---------|--------------------|--------------------|----------------------------------|
| `SCLK`  | Output             | Input              | Serial clock                     |
| `MOSI`  | Output             | Input              | Master-Out / Slave-In data       |
| `MISO`  | Input              | Output             | Master-In / Slave-Out data       |
| `SS_n`  | Output             | Input              | Active-low slave/chip select     |

Accurate timing constraints are essential because SPI has no flow control — data must meet setup and hold requirements at the receiving end on every clock edge, or bits will be corrupted silently.

---

## What's Included

**`altera_spi_timing_constraints.sdc`** — a single, self-contained constraint file covering:

| Section | Topic | Purpose |
|---------|-------|---------|
| 1  | User-configurable parameters | Board delays, device timing, signal names |
| 2  | System clock definition | Avalon bus clock (`create_clock`) |
| 3  | SPI generated clock | SCLK derived from system clock (`create_generated_clock`) |
| 4  | MISO input delay (Master) | Setup/hold analysis for received data |
| 5  | MOSI/SS_n output delay (Master) | Setup/hold analysis at the slave device |
| 6  | MOSI/SS_n input delay (Slave) | Incoming data from external master |
| 7  | MISO output delay (Slave) | Data driven back to external master |
| 8  | Clock domain crossings | `sys_clk` ↔ `spi_sclk` relationships |
| 9  | False paths | Reset, config registers, protocol-idle paths |
| 10 | Multicycle paths | Slow-to-fast and fast-to-slow clock transfers |
| 11 | Clock uncertainty & jitter | Guard-band for PLL jitter and board skew |
| 12 | CPOL/CPHA mode adjustments | All four SPI modes (0–3) with examples |
| 13 | Pin & I/O standard templates | Location, voltage standard, drive strength |
| 14 | Recommendations | Verification commands, multi-slave, Quad-SPI tips |

---

## Quick Start

### 1. Copy the SDC file into your project

```
cp altera_spi_timing_constraints.sdc <your_quartus_project_dir>/
```

### 2. Add it to your Quartus project

In your `.qsf` file:

```tcl
set_global_assignment -name SDC_FILE altera_spi_timing_constraints.sdc
```

Or via the GUI: **Assignments → Settings → Timing Analyzer → SDC files → Add**.

### 3. Customize the parameters (Section 1)

Open the SDC file and update the following to match your design:

```tcl
set SYS_CLK_FREQ       50.0     ;# Your Avalon bus clock frequency (MHz)
set SPI_CLK_FREQ       25.0     ;# Your SPI serial clock frequency (MHz)

set Tpcb_clk           0.5      ;# PCB trace delay on SCLK (ns)
set Tpcb_data_out      0.5      ;# PCB trace delay on MOSI / SS_n (ns)
set Tpcb_data_in       0.5      ;# PCB trace delay on MISO (ns)

set Tco_slave_max      8.0      ;# External slave's max Tco (ns)
set Tco_slave_min      2.0      ;# External slave's min Tco (ns)
set Tsu_slave          5.0      ;# External slave's setup time (ns)
set Th_slave           2.0      ;# External slave's hold time  (ns)
```

Get the `Tco`, `Tsu`, and `Th` values from the external SPI device's datasheet. Estimate `Tpcb_*` values from your PCB layout (roughly 150 ps/inch for FR-4).

### 4. Select Master or Slave mode

- **Master mode** (default): Sections 2–5 are active.
- **Slave mode**: Uncomment Sections 6–7 and the slave-mode lines in Sections 8–9. Comment out or remove Section 3.

### 5. Select the SPI mode (CPOL/CPHA)

The default constraints assume **Mode 0** (CPOL=0, CPHA=0). See Section 12 in the SDC file for instructions on switching to Modes 1, 2, or 3.

### 6. Run timing analysis

```tcl
# In the Quartus Timing Analyzer Tcl console:
report_clocks
check_timing
report_timing -setup -npaths 20
report_timing -hold  -npaths 20
```

Verify that all SPI paths have positive slack and no paths are unconstrained.

---

## SPI Timing Theory

### Master Mode Data Path

```
             FPGA (Master)                     External Slave
        ┌──────────────────┐              ┌──────────────────┐
        │                  │── SCLK ─────▶│                  │
        │   SPI Core       │── MOSI ─────▶│   SPI Slave      │
        │                  │◀── MISO ─────│                  │
        │                  │── SS_n ─────▶│                  │
        └──────────────────┘              └──────────────────┘
```

**MOSI (output) timing budget:**

The FPGA launches MOSI data on one SCLK edge. The slave captures it on the next edge. The constraint ensures the data arrives at the slave with enough setup margin and is held long enough:

```
Output delay (max) = Tpcb_data - Tpcb_clk + Tsu_slave    → governs setup
Output delay (min) = -(Tpcb_clk - Tpcb_data + Th_slave)  → governs hold
```

**MISO (input) timing budget:**

SCLK travels to the slave, which responds with data on MISO after its clock-to-output delay. The total delay from the FPGA's SCLK output edge to the MISO data arriving back at the FPGA is:

```
Input delay (max) = Tpcb_clk + Tco_slave_max + Tpcb_data  → governs setup
Input delay (min) = Tpcb_clk + Tco_slave_min + Tpcb_data  → governs hold
```

### The Four SPI Modes

| Mode | CPOL | CPHA | SCLK Idle | Data Captured On | Data Shifted On |
|------|------|------|-----------|------------------|-----------------|
| 0    | 0    | 0    | Low       | Rising edge      | Falling edge    |
| 1    | 0    | 1    | Low       | Falling edge     | Rising edge     |
| 2    | 1    | 0    | High      | Falling edge     | Rising edge     |
| 3    | 1    | 1    | High      | Rising edge      | Falling edge    |

The SDC constraints must use the correct clock edge (`-clock_fall` or default rising) and the correct SCLK waveform (`-invert` for CPOL=1) to match the selected mode.

---

## File Structure

```
.
├── README.md                              # This documentation
└── altera_spi_timing_constraints.sdc      # SDC timing constraints
```

---

## Compatibility

- **Quartus Prime** Standard Edition 18.0+
- **Quartus Prime** Pro Edition 18.0+
- **Intel (Altera) FPGA families**: Cyclone IV/V/10, Arria II/V/10, Stratix IV/V/10, MAX 10, Agilex
- **SPI IP**: `altera_avalon_spi` (Platform Designer / Qsys)

---

## License

These constraints are provided as-is for use in FPGA designs. Adapt freely to your project requirements.
