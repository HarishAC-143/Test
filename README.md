# Altera SPI Master & Slave SDC Timing Constraints

SDC (Synopsys Design Constraints) files for Intel (Altera) FPGA SPI Master and Slave IP cores, targeting the Quartus Prime Timing Analyzer (TimeQuest).

## Files

| File | Description |
|------|-------------|
| `spi_master.sdc` | Timing constraints for an SPI **Master** IP that generates SCLK and drives MOSI/SS_n |
| `spi_slave.sdc`  | Timing constraints for an SPI **Slave** IP that receives SCLK from an external master |

## Key Differences: Master vs. Slave

| Aspect | SPI Master | SPI Slave |
|--------|-----------|-----------|
| **SCLK** | Generated clock (`create_generated_clock`) | Input clock (`create_clock`) |
| **MOSI** | Output (constrained with `set_output_delay`) | Input (constrained with `set_input_delay`) |
| **MISO** | Input (constrained with `set_input_delay`) | Output (constrained with `set_output_delay`) |
| **SS_n** | Output (constrained with `set_output_delay`) | Input (constrained with `set_input_delay`) |
| **CDC** | Multicycle paths (sys_clk to generated SCLK) | False paths (sys_clk to asynchronous SCLK) |

## How to Use

1. **Set parameters**: Edit the parameter section at the top of each `.sdc` file to match your system clock frequency, SPI bus speed, board trace delays, and external device timing specs.
2. **Update port names**: Modify `get_ports` references to match your Quartus project's pin and hierarchy names.
3. **Select SPI mode**: Uncomment the `-clock_fall` variants in the input/output delay sections if your design uses CPHA=1 modes.
4. **Add to Quartus**: Include the `.sdc` file in your project:
   - Via GUI: **Assignments > Settings > Timing Analyzer > SDC files**
   - Via QSF: `set_global_assignment -name SDC_FILE spi_master.sdc`

## Constraints Covered

Each SDC file includes well-commented sections for:

- Clock definitions (system clock and SPI clock)
- Clock uncertainty and jitter budgeting
- Input delay constraints (setup and hold)
- Output delay constraints (setup and hold)
- Multicycle path relaxation (master) / false path CDC (slave)
- Asynchronous reset false paths
- PLL clock derivation (`derive_pll_clocks`, `derive_clock_uncertainty`)
- Board-level clock latency modeling (slave)
- I/O standard and pin assignment notes

## SPI Mode Reference

| Mode | CPOL | CPHA | SCLK Idle | Data Sampled On |
|------|------|------|-----------|-----------------|
| 0    | 0    | 0    | Low       | Rising edge     |
| 1    | 0    | 1    | Low       | Falling edge    |
| 2    | 1    | 0    | High      | Rising edge     |
| 3    | 1    | 1    | High      | Falling edge    |
