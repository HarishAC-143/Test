# SDC Constraints for Macronix MX66U1G45G SPI NOR Flash — Altera FPGA

Synopsys Design Constraints (SDC) for interfacing the **Macronix MX66U1G45G** 1.8 V, 1 Gb Serial NOR Flash with an **Altera (Intel) FPGA**, targeting the Quartus Prime TimeQuest Timing Analyzer.

## Device Summary

| Parameter | Value |
|-----------|-------|
| Part Number | MX66U1G45G |
| Density | 1 Gb (128 M × 8) |
| Supply Voltage | 1.65 V – 2.0 V |
| Package | BGA-24 (5×5 ball array) |
| Temperature Grade | J (Industrial): −40 °C to +105 °C |
| Interface | SPI, Dual I/O, Quad I/O, QPI |
| DTR Support | Yes (Double Transfer Rate) |
| Max Clock (Normal READ) | 50 MHz |
| Max Clock (FAST READ) | 133 MHz (6 dummy cycles) |
| Max Clock (4READ/QREAD) | 166 MHz (10 dummy cycles) |
| Datasheet Revision | v1.2, August 13, 2020 |

## Files

| File | Description |
|------|-------------|
| `sdc/mx66u1g45g_flash.sdc` | Standard-speed constraints (up to ~66 MHz). Covers standard SPI (x1) with optional Dual/Quad I/O and DTR sections. |
| `sdc/mx66u1g45g_flash_fast.sdc` | High-speed constraints (133–166 MHz). Requires PLL-based capture clock phase shifting for read-path timing closure. |

## Key Timing Parameters (from Datasheet Table 19)

### Flash Input Timing — FPGA drives, flash samples on SCLK rising edge

| Parameter | Symbol | Min | Unit | Description |
|-----------|--------|-----|------|-------------|
| Data Setup (STR) | tDVCH | 1.5 | ns | Data stable before SCLK ↑ |
| Data Hold (STR) | tCHDX | 1.5 | ns | Data stable after SCLK ↑ |
| Data Setup (DTR) | tDVCL | 1.5 | ns | Data stable before SCLK edge (DTR) |
| Data Hold (DTR) | tCLDX | 1.5 | ns | Data stable after SCLK edge (DTR) |
| CS# Setup | tSLCH | 4.5 | ns | CS# active before SCLK ↑ |
| CS# Hold | tCHSL | 4.0 | ns | CS# inactive after SCLK ↑ |
| CS# Active Hold | tCHSH | 3.0 | ns | CS# active hold after SCLK ↑ |
| CS# Deselect (read) | tSHSL | 7.0 | ns | Min time between CS# transactions |
| CS# Deselect (write) | tSHSL | 30.0 | ns | Min time after write/erase |

### Flash Output Timing — flash drives on SCLK falling edge, FPGA captures

| Parameter | Symbol | Value | Unit | Description |
|-----------|--------|-------|------|-------------|
| Clock-to-Output Valid (30 pF) | tCLQV | 8.0 max | ns | SCLK ↓ to data valid |
| Clock-to-Output Valid (15 pF) | tCLQV | 6.0 max | ns | SCLK ↓ to data valid |
| Clock-to-Output Valid (10 pF) | tCLQV | 6.0 max | ns | SCLK ↓ to data valid |
| Output Hold | tCLQX | 1.0 min | ns | Data hold after SCLK ↓ |
| Output Disable | tSHQZ | 5.5 max | ns | CS# ↑ to Hi-Z (BGA-24, 15 pF) |

## Interface Description

```
   Altera FPGA                     MX66U1G45G Flash
  ┌────────────┐                  ┌──────────────┐
  │            │   SCLK ────────► │ CLK          │
  │ SPI Master │   CS#  ────────► │ CS#          │
  │            │   SIO0 ◄───────► │ SI / SIO0    │
  │            │   SIO1 ◄───────► │ SO / SIO1    │
  │            │   SIO2 ◄───────► │ WP# / SIO2   │
  │            │   SIO3 ◄───────► │ HOLD#/ SIO3  │
  └────────────┘                  └──────────────┘
```

SPI Mode 0 (CPOL=0, CPHA=0) or Mode 3 (CPOL=1, CPHA=1):
- FPGA drives data (MOSI / SIO[0:3]) on the **falling edge** of SCLK
- Flash latches data on the **rising edge** of SCLK
- Flash drives data (MISO / SIO[0:3]) on the **falling edge** of SCLK
- FPGA captures data on the **rising edge** of SCLK

## How to Use

### 1. Standard Speed (≤ 66 MHz)

Use `sdc/mx66u1g45g_flash.sdc`. Edit the file to:

1. Set `spi_clk_period` to your SPI clock period (e.g., `20.0` for 50 MHz).
2. Update port names (`flash_sclk_port`, `flash_cs_n_port`, etc.) to match your RTL.
3. Update `spi_clk_source_pin` to point to the register or PLL output driving SCLK.
4. Adjust `board_delay_clk_*` and `board_delay_data_*` to match your PCB trace delays.
5. Uncomment the Quad I/O sections if using Dual or Quad mode.
6. Uncomment the DTR section if using Double Transfer Rate mode.

Include in your Quartus project `.qsf`:

```tcl
set_global_assignment -name SDC_FILE sdc/mx66u1g45g_flash.sdc
```

### 2. High Speed (133–166 MHz)

Use `sdc/mx66u1g45g_flash_fast.sdc`. At these frequencies, tCLQV exceeds the half-period, so a PLL phase-shifted capture clock is required:

1. Configure a PLL with two outputs:
   - `outclk_0`: 0° phase — drives SCLK output and data output registers
   - `outclk_1`: phase-shifted — drives input capture registers
2. The SDC file computes the optimal phase shift; configure the PLL to match.
3. Update port names and board delays as above.

### 3. Verifying Timing

After compiling in Quartus:

```tcl
# Generate timing reports for the SPI interface
report_timing -from_clock spi_sclk -to_clock spi_sclk -setup -npaths 20
report_timing -from_clock spi_sclk -to_clock spi_sclk -hold  -npaths 20

# Check for unconstrained paths
report_timing -setup -npaths 10 -detail full_path -panel_name "SPI Flash Setup"
check_timing
```

## Timing Budget Summary

### At 50 MHz (20 ns period, 10 ns half-period)

| Path | Check | Margin | Status |
|------|-------|--------|--------|
| Read (MISO → FPGA) | Setup | ~1.9 ns | Pass |
| Read (MISO → FPGA) | Hold | ~0.9 ns | Pass |
| Write (FPGA → MOSI) | Setup | ~7.8 ns | Pass |
| Write (FPGA → MOSI) | Hold | comfortable | Pass |

### At 133 MHz with PLL Phase Shift (7.5 ns period, 3.75 ns half-period)

| Path | Check | Margin | Status |
|------|-------|--------|--------|
| Read (SIO → FPGA) | Setup | ~3.2 ns | Pass |
| Read (SIO → FPGA) | Hold | ~3.2 ns | Pass |
| Write (FPGA → SIO) | Setup | ~1.5 ns | Pass |
| Write (FPGA → SIO) | Hold | comfortable | Pass |

## Board Design Guidelines

- Keep SPI traces short and matched in length (clock vs. data ≤ 0.5 ns skew).
- Place decoupling capacitors (100 nF + 1 µF) close to the flash VCC/VSS pins.
- For Quad I/O mode, add 10 kΩ pull-up resistors on WP# (SIO2) and HOLD# (SIO3).
- Target ≤ 15 pF total load on SIO lines for best tCLQV performance.
- For frequencies above 100 MHz, use impedance-controlled traces (50 Ω single-ended).
- Ensure the FPGA I/O bank voltage matches the flash (1.8 V).

## References

- [Macronix MX66U1G45G Datasheet (Rev 1.2)](https://www.macronix.com/Lists/Datasheet/Attachments/8399/MX66U1G45G,%201.8V,%201Gb,%20v1.2.pdf)
- [Intel AN 433: Constraining and Analyzing Source-Synchronous Interfaces](https://cdrdv2-public.intel.com/653688/an433.pdf)
- [Intel SDC Input/Output Delay Documentation](https://www.intel.com/content/www/us/en/docs/programmable/683243/21-3/input-constraints-set-input-delay.html)
