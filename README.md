# Altera (Intel) SPI Master & Slave SDC Constraints

SDC (Synopsys Design Constraints) files for timing-constraining Altera/Intel FPGA SPI master and slave IP cores in Quartus Prime.

## Files

| File | Description |
|---|---|
| `spi_master.sdc` | Timing constraints for an SPI **master** — the FPGA generates SCLK and drives MOSI/SS_n |
| `spi_slave.sdc`  | Timing constraints for an SPI **slave** — the FPGA receives SCLK and drives MISO |

## Quick Start

1. Copy the appropriate `.sdc` file into your Quartus project directory.
2. Open **Section 1** ("User-Configurable Parameters") and update:
   - Clock frequencies (`SYS_CLK_FREQ_MHZ`, `SPI_CLK_FREQ_MHZ`)
   - Board trace delays (`BOARD_DELAY_MAX`, `BOARD_DELAY_MIN`)
   - External device timing (`SLAVE_TCO_*` / `MASTER_TCO_*`, `TSU`, `TH`)
   - FPGA pin names (`PIN_SCLK`, `PIN_MOSI`, `PIN_MISO`, `PIN_SS_N`, `SYS_CLK_PIN`)
3. Add the SDC file to Quartus: **Assignments > Settings > Timing Analyzer > SDC files**.
4. Run **Timing Analyzer** (TimeQuest) and verify all paths are constrained.

## SPI Master vs. Slave — Key Constraint Differences

| Aspect | Master (`spi_master.sdc`) | Slave (`spi_slave.sdc`) |
|---|---|---|
| SCLK direction | **Output** — generated clock derived from sys_clk | **Input** — primary clock from external master |
| SCLK definition | `create_generated_clock` | `create_clock` |
| Clock domains | Synchronous (SCLK derived from sys_clk) | **Asynchronous** (SCLK unrelated to sys_clk) |
| MOSI | Output with `set_output_delay` | Input with `set_input_delay` |
| MISO | Input with `set_input_delay` | Output with `set_output_delay` |
| SS_n | Output (actively driven) | Input (monitored) |
| Clock groups | Optional (same source) | Required (`set_clock_groups -asynchronous`) |

## SPI Modes Reference

| Mode | CPOL | CPHA | Data Sampled On | Data Shifted On |
|---|---|---|---|---|
| 0 | 0 | 0 | Rising edge | Falling edge |
| 1 | 0 | 1 | Falling edge | Rising edge |
| 2 | 1 | 0 | Falling edge | Rising edge |
| 3 | 1 | 1 | Rising edge | Falling edge |

For modes where data is sampled on the falling edge, add `-clock_fall` to the relevant `set_input_delay` / `set_output_delay` commands as noted in the SDC comments.

## Sections Covered

Both SDC files contain the following constraint categories:

1. **User-Configurable Parameters** — all tuneable values in one place
2. **System Clock Definition** — `create_clock` for the FPGA fabric clock
3. **SPI Clock Definition** — generated (master) or primary (slave)
4. **Output Delay Constraints** — setup/hold for FPGA-driven signals
5. **Input Delay Constraints** — setup/hold for externally-driven signals
6. **Clock Groups** — asynchronous domain declarations
7. **Multicycle Paths** — relaxed timing for synchronisers / pipelines
8. **False Paths** — static config, resets, tri-state control
9. **Max/Min Delay** — optional direct delay limits
10. **Clock Uncertainty / Latency** — jitter and source latency modelling
11. **I/O Transition Times** — slew-rate modelling (slave only)
12. **Tri-State Handling** — MISO high-Z control (slave only)

## Target Devices

Tested with Intel Quartus Prime targeting:
- Cyclone IV / V / 10
- Arria II / V / 10
- Stratix IV / V / 10
- Agilex

## License

These constraint files are provided as-is for reference and educational use.
