# Altera SPI IP Core — Timing Constraints (SDC)

Comprehensive, production-ready SDC timing constraint files for the **Intel (Altera) Avalon SPI IP core** (`altera_avalon_spi`) targeting the **Terasic DE10** board (Cyclone V).

---

## Files

| File | Description |
|---|---|
| `spi_master_timing.sdc` | Constraints for the SPI IP configured as **master** |
| `spi_slave_timing.sdc` | Constraints for the SPI IP configured as **slave** |

---

## What Is Covered

Each SDC file contains fully commented, section-by-section constraints:

| # | Section | Purpose |
|---|---------|---------|
| 1 | **User-Tunable Parameters** | All numeric values (frequencies, board delays, device timing) collected in one place for easy customisation. |
| 2 | **System Clock** | `create_clock` for the 50 MHz Avalon-MM base clock. |
| 3 | **SPI Clock** | Master: `create_generated_clock` on the SCLK output. Slave: `create_clock` on the SCLK input. |
| 4 | **Output Delays** | `set_output_delay` on data/control outputs so the Timing Analyzer checks setup/hold at the receiving device. |
| 5 | **Input Delays** | `set_input_delay` on data inputs so the Timing Analyzer checks that captured data meets FPGA register timing. |
| 6 | **Multicycle / CDC Paths** | Master: multicycle relaxation for the sys_clk-to-SCLK domain. Slave: `set_clock_groups -asynchronous` for the unrelated clock domains. |
| 7 | **False Paths** | Reset, static configuration registers, FIFO gray-code pointers. |
| 8 | **Clock Uncertainty** | PLL jitter and board-level noise margins. |
| 9 | **Optional Overrides** | `set_max_delay` / `set_min_delay` for absolute path bounding. |
| 10 | **Clock Groups** | Template for designs with additional unrelated clocks. |
| 11 | **I/O Standard Reminders** | QSF assignments that affect I/O buffer delays. |

---

## SPI Mode Reference

The SPI protocol defines four modes based on clock polarity (CPOL) and clock phase (CPHA):

| Mode | CPOL | CPHA | Data Sampled On | Data Shifted On |
|------|------|------|-----------------|-----------------|
| 0 | 0 | 0 | Rising edge | Falling edge |
| 1 | 0 | 1 | Falling edge | Rising edge |
| 2 | 1 | 0 | Falling edge | Rising edge |
| 3 | 1 | 1 | Rising edge | Falling edge |

The constraint files default to **Mode 0** with inline notes explaining how to adapt for other modes (primarily adding or removing `-clock_fall`).

---

## Quick-Start Guide

### 1. Copy the appropriate file into your Quartus project

For an SPI master design:

```
cp spi_master_timing.sdc <your_quartus_project_dir>/
```

For an SPI slave design:

```
cp spi_slave_timing.sdc <your_quartus_project_dir>/
```

### 2. Add the SDC file to your Quartus project

In your `.qsf` file, add:

```tcl
set_global_assignment -name SDC_FILE spi_master_timing.sdc
```

Or via the GUI: **Assignments > Settings > Timing Analyzer > SDC files**.

### 3. Customise the parameters (Section 1)

Open the SDC file and edit the variables at the top to match your design:

```tcl
set SYS_CLK_FREQ_MHZ       50.0    ;# your system clock frequency
set SPI_CLK_FREQ_MHZ         5.0    ;# your SPI clock frequency

set BOARD_DELAY_MAX_NS       1.5    ;# PCB trace delay (worst case)
set BOARD_DELAY_MIN_NS       0.5    ;# PCB trace delay (best case)

set SLAVE_TSU_NS             5.0    ;# external device setup time
set SLAVE_TH_NS              2.0    ;# external device hold time
set SLAVE_TCO_MAX_NS         8.0    ;# external device clock-to-output (max)
set SLAVE_TCO_MIN_NS         0.0    ;# external device clock-to-output (min)
```

### 4. Update port names

Replace the generic port names (`SPI_SCLK`, `SPI_MOSI`, `SPI_MISO`, `SPI_SS_n`, `CLOCK_50`, `RESET_n`) with the actual top-level port names in your design.

### 5. Run the Timing Analyzer

```
quartus_sta <project_name> --sdc=spi_master_timing.sdc
```

Or use the GUI: **Tools > Timing Analyzer**, then **Reports > Setup Summary / Hold Summary**.

---

## How to Read the Constraint Formulas

### Output Delay (FPGA drives data, external device captures)

```
max output delay = board_delay_max + device_setup_time
min output delay = board_delay_min - device_hold_time
```

The Timing Analyzer subtracts these from the available clock period to determine the **FPGA-internal budget**. A positive max output delay shortens the allowed FPGA-internal path delay. A negative min output delay gives extra hold margin.

### Input Delay (External device drives data, FPGA captures)

```
max input delay = board_delay_max + device_clock_to_output_max
min input delay = board_delay_min + device_clock_to_output_min
```

The Timing Analyzer uses these to compute when data actually arrives at the FPGA register, checking that it meets the register's setup and hold requirements.

---

## Board Trace Delay Estimation

If you don't have an impedance-controlled PCB stack-up report, estimate trace delays using:

```
Delay (ns) = Trace_Length (inches) x 0.150 ns/inch
```

This is the typical propagation delay for outer-layer microstrip on FR-4 PCB material. Inner-layer stripline is slightly slower (~0.180 ns/inch).

---

## Adapting for Other SPI Modes

The default constraints target **Mode 0 (CPOL=0, CPHA=0)**. To adapt:

- **Mode 1 (CPOL=0, CPHA=1):** Add `-clock_fall` to output delay constraints; remove `-clock_fall` from input delay constraints.
- **Mode 2 (CPOL=1, CPHA=0):** Change the SCLK waveform so idle-high; the edge relationships stay the same as Mode 0 but inverted.
- **Mode 3 (CPOL=1, CPHA=1):** Change the SCLK waveform to idle-high and swap `-clock_fall` usage as in Mode 1.

Each SDC file contains inline comments at the relevant sections with the exact changes needed.

---

## Target Platform

- **Board:** Terasic DE10 (DE10-Standard / DE10-Nano)
- **FPGA:** Intel Cyclone V (5CSXFC6D6F31C6N or similar)
- **Tool:** Intel Quartus Prime (Standard or Lite edition)
- **IP Core:** `altera_avalon_spi` from Platform Designer (Qsys)

---

## License

These constraint files are provided as-is for educational and engineering use. Adapt freely for your projects.
