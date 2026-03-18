# SDC Constraints for Macronix MX66U1G45G QSPI Flash (Altera FPGA)

Synopsys Design Constraints (SDC) file for interfacing the **Macronix MX66U1G45G** 1.8V 1Gb serial NOR flash with Intel (Altera) FPGAs.

## Device Summary

| Parameter         | Value                                  |
|--------------------|----------------------------------------|
| Part Number        | MX66U1G45G                             |
| Density            | 1 Gbit (128M x 8)                     |
| Supply Voltage     | 1.65V -- 2.0V (1.8V nominal)          |
| Interface          | SPI / Dual-IO / Quad-IO / QPI          |
| Max Frequency      | 133 MHz (STR), 166 MHz (DTR)           |
| Transfer Modes     | STR (Single Transfer Rate), DTR (Double Transfer Rate) |
| Address Mode       | 4-byte                                 |

## File

- **`mx66u1g45g_qspi.sdc`** -- Timing constraints for the QSPI interface between the FPGA and flash.

## How to Use

1. Copy `mx66u1g45g_qspi.sdc` into your Quartus project directory.
2. Edit the **User-Configurable Parameters** section (Section 1) to match your design:
   - `SYS_CLK_NAME` / `SYS_CLK_FREQ_MHZ` -- your FPGA system clock
   - `QSPI_CLK_FREQ_MHZ` -- the SPI clock frequency your controller uses
   - `QSPI_MODE` -- `"STR"` or `"DTR"`
   - Port names (`QSPI_CLK_PORT`, `QSPI_CS_PORT`, `QSPI_DATA_PORTS`)
   - Board trace delays (`BOARD_DELAY_MAX`, `BOARD_DELAY_MIN`)
3. Add the SDC file to your Quartus project:
   - **Project > Settings > Timing Analyzer > SDC files > Add**
   - Or add to your QSF: `set_global_assignment -name SDC_FILE mx66u1g45g_qspi.sdc`
4. Run the Timing Analyzer (`quartus_sta`) and verify positive slack on all QSPI paths.

## Constraints Overview

| Section | Description |
|---------|-------------|
| System Clock | Reference clock for the QSPI controller |
| Generated Clock | Models the SCLK output pin driven by the FPGA |
| Virtual Clock | Represents the clock domain at the flash device |
| Output Delays | Setup/hold requirements for FPGA-to-flash signals (CS#, data) |
| Input Delays | Clock-to-output timing for flash-to-FPGA read data |
| Multicycle Paths | Relaxes constraints when SCLK is divided from a faster system clock |
| False Paths | Cuts analysis between unrelated clock domains |
| I/O Standards | 1.8V I/O assignments (commented, can be set in QSF) |

## Key Timing Parameters

Extracted from the MX66U1G45G datasheet:

| Parameter | STR Mode | DTR Mode | Description |
|-----------|----------|----------|-------------|
| tCLQV     | 6.0 ns   | 5.5 ns   | Clock to output valid (max) |
| tCLQX     | 0.5 ns   | 0.5 ns   | Clock to output hold (min) |
| tDVCH     | 2.0 ns   | 1.5 ns   | Data input setup time (min) |
| tCHDX     | 2.0 ns   | 1.5 ns   | Data input hold time (min) |
| tSLCH     | 5.0 ns   | 5.0 ns   | CS# active setup to SCK (min) |
| tCHSL     | 5.0 ns   | 5.0 ns   | SCK to CS# deassert (min) |
| tSHSL     | 10 ns    | 10 ns    | CS# high time (min) |

## Notes

- Always verify timing parameters against the specific revision of the MX66U1G45G datasheet for your part.
- Board-level trace delays should be measured or extracted from your PCB layout tool.
- The generated clock `-source` pin may need adjustment depending on your QSPI controller RTL structure.
