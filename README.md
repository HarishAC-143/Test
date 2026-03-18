# Macronix MX66U1G45G Flash SDC Constraints for Altera FPGA

SDC (Synopsys Design Constraints) timing constraints for interfacing the
**Macronix MX66U1G45G** 1.8V 1Gb Serial NOR Flash with an **Altera (Intel) FPGA**.

## Flash Device Summary

| Parameter           | Value                          |
|---------------------|--------------------------------|
| Part Number         | MX66U1G45G                     |
| Density             | 1 Gbit (128M x 8)             |
| Supply Voltage      | 1.65V – 2.0V (1.8V nominal)   |
| Interface           | SPI / Dual / Quad (QPI) / DTR  |
| Max Frequency (STR) | 166 MHz                        |
| Max Frequency (DTR) | 83 MHz (effective 166 MT/s)    |
| Package             | BGA-24                         |

## File

| File                      | Description                                  |
|---------------------------|----------------------------------------------|
| `mx66u1g45g_flash.sdc`   | Timing constraints for Quartus Prime         |

## Supported Modes

The SDC file provides constraints for:

- **STR (Single Transfer Rate)** — data sampled on one clock edge (default, active)
- **DTR (Double Transfer Rate)** — data sampled on both clock edges (commented out, enable as needed)

Both Standard SPI (single I/O) and Quad SPI (QPI, x4 I/O) pin configurations
are supported.

## Key Timing Parameters Used

Values sourced from the MX66U1G45G datasheet (v1.2):

| Parameter | Symbol  | Value   | Description                         |
|-----------|---------|---------|-------------------------------------|
| tCLQV     | max     | 6.0 ns  | Clock-to-output valid (STR)         |
| tCLQX     | min     | 0.5 ns  | Clock-to-output hold                |
| tSI       | min     | 2.0 ns  | Data input setup time (STR)         |
| tHI       | min     | 2.0 ns  | Data input hold time (STR)          |
| tSI (DTR) | min     | 1.5 ns  | Data input setup time (DTR)         |
| tHI (DTR) | min     | 1.5 ns  | Data input hold time (DTR)          |
| tCH       | min     | 2.7 ns  | SCLK high time                      |
| tCL       | min     | 2.7 ns  | SCLK low time                       |
| tSLCH     | min     | 5.0 ns  | CS# active setup to SCLK            |
| tCHSH     | min     | 5.0 ns  | SCLK to CS# inactive hold           |
| tSHSL     | min     | 10.0 ns | CS# deselect time                   |

## Quick Start

1. Copy `mx66u1g45g_flash.sdc` into your Quartus project directory.

2. Edit the **user-configurable parameters** (Section 1 of the file):
   - `SPI_CLK_FREQ_MHZ` — set to your operating frequency
   - `BOARD_DELAY_MAX` / `BOARD_DELAY_MIN` — set based on your PCB trace lengths
   - `BOARD_CLK_SKEW` — set based on trace length mismatch between SCLK and data

3. Update the **FPGA pin names** (Section 3) to match your RTL port names:
   - `flash_sclk`, `flash_cs_n`, `flash_io[0:3]`

4. Update the `create_generated_clock` source pin (Section 4) to point to the
   correct register or PLL output driving your SPI clock.

5. Add the file to your Quartus project:
   ```
   set_global_assignment -name SDC_FILE mx66u1g45g_flash.sdc
   ```

6. Run TimeQuest / Timing Analyzer and review the reported slack.

## DTR Mode

To use DTR mode, comment out the STR constraints in Sections 5–6 and uncomment
Section 7. The DTR constraints apply `set_input_delay` and `set_output_delay`
on both rising and falling clock edges using `-add_delay`.

## Constraint Methodology

- **Input delays** model the flash-to-FPGA read path using `tCLQV` (max) and
  `tCLQX` (min) plus board propagation delay.
- **Output delays** model the FPGA-to-flash write/command path using `tSI`
  (setup) and `tHI` (hold) plus board propagation delay.
- A **virtual clock** at the SPI frequency is used as the timing reference to
  decouple board-level delays from the FPGA-internal clock network.
- **Duty cycle checks** warn at constraint-load time if the configured clock
  frequency violates the flash's minimum `tCH`/`tCL` requirements.

## References

- [Macronix MX66U1G45G Datasheet (PDF)](https://www.macronix.com/Lists/Datasheet/Attachments/8399/MX66U1G45G,%201.8V,%201Gb,%20v1.2.pdf)
- [Intel Quartus Prime SDC Timing Constraints](https://www.intel.com/content/www/us/en/docs/programmable/683432/current/sdc-file.html)
