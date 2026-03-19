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

## Bus Contention During TX→RX Switchover (Quad/Dual I/O)

In Quad and Dual I/O modes, the SIO lines are **bidirectional**. During read commands (4READ, QREAD, 2READ, 4DTRD), the FPGA first drives SIO[0:3] with command/address bits, then the flash takes over and drives the same lines with read data. If both devices drive the bus simultaneously during this switchover, **bus contention** occurs.

### What Happens During Contention

```
  FPGA drives HIGH ──►  ┌─────┐  ──── VCC (1.8V)
                        │ SIO │
  Flash drives LOW ──►  └─────┘  ──── GND

  Result: Short-circuit path from VCC → FPGA buffer → SIO trace → Flash buffer → GND
```

| Problem | Description | Impact |
|---------|-------------|--------|
| **Shoot-through current** | Both output buffers form a resistive divider. At 1.8 V with ~50 Ω per driver, each contending pin draws ~18 mA. In Quad mode (4 pins), total is ~72 mA. | Localized heating in both FPGA I/O bank and flash die; wasted power budget. |
| **Indeterminate voltage** | SIO line settles at ~VCC/2 ≈ 0.9 V, which falls in the "forbidden zone" between VIL_max (0.63 V) and VIH_min (1.17 V). | **Metastability** in the FPGA input register — captured data is corrupted. Excessive static current in CMOS input buffers on both devices. |
| **VCC droop / ground bounce** | 72 mA current spike through ~2 nH package inductance at a ~1 ns edge produces ΔV ≈ L × dI/dt ≈ 144 mV noise on the power rail. | Corrupts data on OTHER SIO lines (crosstalk through shared VCC/GND). Glitches on adjacent FPGA I/O bank pins. May disturb flash internal state machine. |
| **Signal ringing** | When one driver finally releases (tristates), stored energy in PCB trace inductance causes underdamped LC oscillation lasting 2–5 ns. | Ringing may violate tDVCH/tCHDX setup/hold at the flash or tCLQV/tCLQX timing at the FPGA on the next valid data edge. |
| **Long-term reliability** | Repeated contention events accelerate electromigration and hot-carrier injection in I/O transistors. | No immediate failure, but device lifetime degrades — critical for designs targeting 10+ year industrial reliability. |

### Timing Diagram — Contention Scenario

```
    SCLK  ─┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
            └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

            ◄─── ADDR (FPGA drives) ───►◄ DUMMY ►◄── DATA (Flash drives) ──►

    FPGA    ═══════════╗                 ║
    OE                 ║  ← OE late! ──►║
                       ╚════════════════╝
                                         ┊
    FPGA    ═══ADDR═══╗                  ┊
    SIO drv           ╚══════════════════╝   (FPGA still driving!)

    Flash                                ╔══DATA══DATA══DATA══DATA══
    SIO drv ─────────────────────────────╝   (Flash starts driving!)

                                         ┊◄──────►┊
                                         CONTENTION
                                         WINDOW
                                         (both drive
                                          the bus!)
```

### How Contention Happens in the MX66U1G45G Protocol

For a **4READ** (Quad I/O Read) transaction in SPI mode:

1. **Command phase** (8 SCLK cycles): FPGA drives SIO0 with command `EBh`
2. **Address phase** (6 SCLK cycles): FPGA drives SIO[0:3] with 24-bit address
3. **Mode/Dummy phase** (2 + N dummy SCLK cycles): First 2 cycles are "performance enhance indicator" (FPGA-driven), remaining are configurable dummy cycles
4. **Data phase**: Flash drives SIO[0:3] with read data

The turnaround happens between steps 3 and 4. The FPGA **must tristate its SIO output enables before the flash starts driving at the beginning of step 4**.

Root causes of contention:
- The FPGA's OE deassert logic in the SPI state machine is off-by-one in the dummy cycle counter
- The OE control path has a pipeline delay that pushes deassert one SCLK cycle too late
- The FPGA's physical tristate buffer has non-zero tZX (tristate delay, typically 2–5 ns on Altera)

### RTL Prevention Strategies

```
         Recommended OE timing for 4READ with 6 dummy cycles:

    SCLK  ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
              └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

              ◄── ADDR ──►◄── P.E. ►◄───── DUMMY CYCLES ─────►◄── DATA ──►
              FPGA drives  FPGA drv   Bus is Hi-Z (safe zone)   Flash drives

    FPGA  ════════════════╗
    OE                    ╚═══════════════════════════════════════════════════
                          ↑
                    OE deasserts at the START of the first dummy cycle
                    (provides full dummy period of dead time)
```

1. **Deassert OE early**: Turn off SIO output enables at the **start of the first dummy cycle**, not at the end. This gives the full dummy period as dead time before the flash starts driving.

2. **Add 1 guard cycle**: For extra safety, deassert OE one cycle before the dummy phase begins (during the last "performance enhance indicator" cycle). The flash ignores data during dummy cycles, so driving garbage for those cycles causes no harm, but contention during the data phase corrupts real data.

3. **Use weak pull resistors**: Add 10 kΩ pull-ups on SIO[2] (WP#) and SIO[3] (HOLD#) to keep them at defined levels during Hi-Z turnaround. Consider 10 kΩ pull-ups on SIO[0:1] as well to prevent floating.

4. **Verify in simulation**: Run gate-level simulation with SDF back-annotation and check that the OE deassertion arrives before the flash model starts driving. Use a bus contention checker in your simulator (`$bitstoreal`, Verilog `===` checks, or assertion-based verification).

### SDC Constraints for OE Turnaround

The SDC file (`sdc/mx66u1g45g_flash.sdc`, Section 8) includes constraints to ensure the OE control path meets timing. The key constraint is:

```tcl
set_max_delay -from [get_registers {spi_master_inst|sio_oe_reg[*]}] \
              -to   [get_ports {FLASH_SIO*}] \
              [expr {$spi_clk_period - 1.0}]
```

This ensures the OE deassert signal arrives at the I/O pin within one SCLK period minus 1 ns margin, preventing late deassertion that would cause contention.

After compilation, verify with:

```tcl
report_timing -from [get_registers {*sio_oe*}] -to [get_ports {FLASH_SIO*}] -npaths 10
```

If the reported slack is negative, the OE path is too slow and contention **will** occur on every read transaction.

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
