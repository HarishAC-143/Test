# SDC Constraints — Macronix MX66U1G45G Flash with Intel (Altera) FPGA

Synopsys Design Constraints (SDC) for interfacing the **Macronix MX66U1G45G** 1.8 V, 1 Gb Serial NOR Flash with an Intel (Altera) FPGA, targeting the Quartus Prime Timing Analyzer.

## Flash Device Summary

| Parameter        | Value                                    |
|------------------|------------------------------------------|
| Part Number      | MX66U1G45G                               |
| Density          | 1 Gbit (128 M x 8)                      |
| Supply Voltage   | 1.65 V – 2.0 V (1.8 V nominal)          |
| Interface        | SPI / Dual-SPI / Quad-SPI               |
| Transfer Modes   | STR (Single Transfer Rate), DTR (Double) |
| Max Clock (STR)  | 133 MHz (Fast Read / Quad Read)          |
| Max Clock (DTR)  | 83 MHz clock / 166 MT/s effective        |
| SPI Modes        | Mode 0 (CPOL=0, CPHA=0), Mode 3         |

## File

| File                     | Description                              |
|--------------------------|------------------------------------------|
| `mx66u1g45g_flash.sdc`  | SDC timing constraints for Quartus Prime |

## Key Timing Parameters (from datasheet)

### STR Mode

| Symbol | Description                          | Value    |
|--------|--------------------------------------|----------|
| tCLQV  | CLK falling → output valid (max)     | 7.0 ns   |
| tCLQX  | Output hold from CLK falling (min)   | 0.0 ns   |
| tDVCH  | Data-in setup to CLK rising (min)    | 3.0 ns   |
| tCHDX  | Data-in hold from CLK rising (min)   | 3.0 ns   |
| tSLCH  | CS# low to first CLK edge (min)      | 5.0 ns   |
| tCHSL  | Last CLK edge to CS# deassert (min)  | 5.0 ns   |
| tSHSL  | CS# deselect time (min)              | 30.0 ns  |

### DTR Mode

| Symbol | Description                          | Value    |
|--------|--------------------------------------|----------|
| tCLQV  | CLK edge → output valid (max)        | 6.0 ns   |
| tCLQX  | Output hold from CLK edge (min)      | 0.0 ns   |
| tDVCH  | Data-in setup to CLK edge (min)      | 1.5 ns   |
| tCHDX  | Data-in hold from CLK edge (min)     | 1.5 ns   |

## How to Use

### 1. Copy and customize

Copy `mx66u1g45g_flash.sdc` into your Quartus project directory and edit Section 1 and Section 3 to match your design:

- **Section 1** — Set clock frequencies, board trace delays, and transfer mode (STR/DTR).
- **Section 3** — Set the port names to match your RTL top-level ports.
- **Section 5** — Adjust the generated clock source pin to match how SCLK is produced in your design (register toggle, ALTDDIO_OUT, or PLL output).

### 2. Add to Quartus project

In the Quartus Settings dialog or your `.qsf` file:

```tcl
set_global_assignment -name SDC_FILE mx66u1g45g_flash.sdc
```

### 3. Set I/O standard (in QSF)

The MX66U1G45G operates at 1.8 V. Assign the FPGA I/O bank and standard accordingly:

```tcl
set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_clk
set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_cs_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[2]
set_instance_assignment -name IO_STANDARD "1.8 V" -to spi_io[3]
```

### 4. Verify timing closure

After compilation, check the Timing Analyzer reports. All setup and hold paths involving the SPI ports should show positive slack. Use the report commands listed in Section 12 of the SDC file for targeted analysis.

## Constraint Architecture

```
┌──────────────────────────────────────────────────────┐
│  FPGA                                                │
│                                                      │
│  sys_clk ──► [PLL / divider] ──► spi_clk_reg ──►──┐ │
│                                                    │ │
│  TX registers ──────────────────► spi_io[3:0] ──►──┤ │
│                                                    │ │
│  CS register ───────────────────► spi_cs_n ────►──┤ │
│                                                    │ │
│  RX registers ◄──────────────── spi_io[3:0] ◄──┤ │
│                                                    │ │
└────────────────────────────────────────────────────┘ │
                                                       │
                  Board Traces (Tbd)                   │
                                                       │
┌──────────────────────────────────────────────────────┐
│  MX66U1G45G                                          │
│   CLK, CS#, IO[3:0]                                  │
└──────────────────────────────────────────────────────┘
```

**Output path (FPGA → Flash):** The flash must see valid data tDVCH before the SCLK rising edge and tCHDX after it. The `set_output_delay` constraints encode these requirements plus board-delay skew.

**Input path (Flash → FPGA):** The flash drives data tCLQV after the SCLK falling edge. The total delay seen at the FPGA input is the SCLK board delay + tCLQV + data board delay (round-trip). The `set_input_delay` constraints capture this.

## Board Delay Estimation

Adjust `BOARD_*_DELAY_MAX` and `BOARD_*_DELAY_MIN` in Section 1 based on your PCB:

| Trace type     | Typical propagation   |
|----------------|-----------------------|
| Outer microstrip | ~0.14 ns/inch       |
| Inner stripline  | ~0.16 ns/inch       |

For a 2-inch trace on an outer layer: delay ≈ 0.28 ns. Add margin for manufacturing tolerance (±10–15 %) to derive min/max values.

## References

- [Macronix MX66U1G45G Datasheet (Rev 1.2)](https://www.macronix.com/Lists/Datasheet/Attachments/8399/MX66U1G45G,%201.8V,%201Gb,%20v1.2.pdf)
- [Intel Quartus Prime — Timing Analyzer Cookbook](https://www.intel.com/content/www/us/en/docs/programmable/683068/current/timing-analyzer-cookbook.html)
- [Intel SDC Command Reference](https://www.intel.com/content/www/us/en/docs/programmable/683243/current/sdc-command-reference.html)
