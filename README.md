# Altera/Intel FPGA — SPI IP Core Timing Constraints

Comprehensive SDC (Synopsys Design Constraints) files for constraining Altera SPI
IP cores in Quartus Prime. Covers both **SPI Master** and **SPI Slave**
configurations with detailed inline documentation.

---

## Repository Structure

```
constraints/
├── spi_master.sdc    # Timing constraints for SPI Master mode
└── spi_slave.sdc     # Timing constraints for SPI Slave mode
```

---

## Quick Start

1. Copy the appropriate `.sdc` file into your Quartus project directory.
2. Open **Section 0** of the file and set the parameters to match your design
   (clock frequencies, pin names, board delays, external device timing).
3. Add the file to your project:
   **Assignments → Settings → Timing Analyzer → SDC files**.
4. Compile the design, then open the **Timing Analyzer** and review the reports.

---

## SPI Protocol Refresher

SPI (Serial Peripheral Interface) is a synchronous, full-duplex serial bus.
Four signals are used:

| Signal  | Direction (Master) | Direction (Slave) | Purpose                           |
|---------|--------------------|--------------------|-----------------------------------|
| SCLK    | Output             | Input              | Serial clock                      |
| MOSI    | Output             | Input              | Master Out, Slave In (data)       |
| MISO    | Input              | Output             | Master In, Slave Out (data)       |
| SS_n    | Output             | Input              | Slave Select (active low)         |

### SPI Modes (CPOL / CPHA)

The clock polarity and phase determine when data is shifted and sampled:

| Mode | CPOL | CPHA | Idle State | Data Shifted On | Data Sampled On |
|------|------|------|------------|-----------------|-----------------|
| 0    | 0    | 0    | Low        | Falling edge    | Rising edge     |
| 1    | 0    | 1    | Low        | Rising edge     | Falling edge    |
| 2    | 1    | 0    | High       | Rising edge     | Falling edge    |
| 3    | 1    | 1    | High       | Falling edge    | Rising edge     |

The constraint files handle all four modes through a configurable `spi_cpol` /
`spi_cpha` parameter pair.

---

## Constraint Concepts Explained

### 1. Clock Definitions

#### System Clock (`create_clock`)

Every FPGA design has at least one system clock.  The SPI IP core's register
interface (Avalon-MM, AXI, or custom) is synchronous to this clock.

```tcl
create_clock -name sys_clk -period 20.0 [get_ports sys_clk]
```

#### Generated Clock (Master mode)

In master mode the FPGA generates SCLK by dividing the system clock.  We model
this with `create_generated_clock` so the Timing Analyzer preserves the phase
relationship:

```tcl
create_generated_clock -name spi_sclk_out \
    -source [get_ports sys_clk] \
    -divide_by 2 \
    [get_ports spi_sclk]
```

#### Input Clock (Slave mode)

In slave mode SCLK arrives from an external master.  We create a real clock on
the input port:

```tcl
create_clock -name spi_sclk_in -period 40.0 [get_ports spi_sclk]
```

#### Virtual Clock

A virtual clock has no physical pin — it represents SCLK as seen at the external
device.  Input and output delays are referenced to this clock to properly account
for PCB trace propagation delay:

```tcl
create_clock -name virtual_spi_sclk -period 40.0
```

---

### 2. Output Delay (`set_output_delay`)

`set_output_delay` tells the Timing Analyzer how much of the clock period is
consumed **outside** the FPGA on the output path.  The Timing Analyzer then
verifies that the FPGA's internal path (register → output buffer) is fast enough
to leave adequate setup/hold margin at the receiving device.

```
                 FPGA                         External Device
            ┌────────────┐                   ┌──────────────┐
  sys_clk ──┤  register  ├── MOSI ──[PCB]──→ │ D     Q      │← SCLK
            └────────────┘                   └──────────────┘
                                              ←─ tsu ──→
                                              ←───── board_delay ────→
```

**Maximum output delay** (for setup analysis):

```
output_delay_max = board_delay_max + slave_tsu
```

**Minimum output delay** (for hold analysis):

```
output_delay_min = -(board_delay_max - board_delay_min)
```

The minimum is often negative because SCLK and MOSI travel across similar PCB
traces, and their delays partially cancel.

---

### 3. Input Delay (`set_input_delay`)

`set_input_delay` tells the Timing Analyzer how late data may arrive at the FPGA
pin after the clock edge that launched it at the external device.

```
                 External Device               FPGA
            ┌──────────────┐                ┌────────────┐
  SCLK ──→  │  register    ├── MISO ──[PCB]──→ D     Q  │← spi_sclk
            └──────────────┘                └────────────┘
              ← tco ──→
                          ←───── board_delay ────→
```

**Maximum input delay** (for setup analysis):

```
input_delay_max = board_delay_max + device_tco_max
```

**Minimum input delay** (for hold analysis):

```
input_delay_min = board_delay_min + device_tco_min
```

---

### 4. Multicycle Path (`set_multicycle_path`)

When the system clock is faster than SCLK (common in master mode), the SPI shift
register only updates once per SCLK period, not every system clock cycle.  Without
multicycle constraints the Timing Analyzer would demand single-cycle sys_clk
timing on paths that actually have multiple cycles to settle.

```tcl
# N = sys_clk_freq / spi_clk_freq
set_multicycle_path -setup -end N -to [get_ports spi_mosi]
set_multicycle_path -hold  -end [expr {N - 1}] -to [get_ports spi_mosi]
```

The hold multicycle must always be one less than the setup multicycle to keep the
hold check edge in the correct position.

---

### 5. False Path (`set_false_path`)

A false path removes a timing path from analysis entirely.  Use it when:

- **Clock domain crossing with synchronizers**: Data passes through 2–3 flip-flop
  synchronizer stages, and no single-cycle setup relationship exists.
- **Asynchronous resets**: Reset signals are not data-synchronous.
- **Unrelated signal pairs**: e.g., SS_n has no direct timing relationship to MISO.

```tcl
set_false_path -from [get_clocks spi_sclk_in] -to [get_clocks sys_clk]
set_false_path -from [get_clocks sys_clk]     -to [get_clocks spi_sclk_in]
```

> **Warning:** Over-applying false paths can mask real timing violations.  Only
> false-path a crossing when you have verified that proper synchronizers exist.

---

### 6. Clock Uncertainty (`set_clock_uncertainty`)

Clock uncertainty adds guard-band to account for jitter (PLL jitter, board noise,
etc.).  Quartus typically computes this automatically for PLL-derived clocks, but
you may want extra margin, especially for externally sourced clocks (slave SCLK):

```tcl
set_clock_uncertainty -setup 0.300 [get_clocks spi_sclk_in]
set_clock_uncertainty -hold  0.150 [get_clocks spi_sclk_in]
```

---

### 7. Clock Groups (`set_clock_groups`)

When two clocks are completely asynchronous (no frequency or phase relationship),
declare them in separate groups to suppress cross-domain analysis:

```tcl
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks eth_rx_clk]
```

---

## Master vs. Slave: Key Differences

| Aspect                 | SPI Master                       | SPI Slave                          |
|------------------------|----------------------------------|------------------------------------|
| SCLK                   | Generated (output)               | Received (input)                   |
| Clock model            | `create_generated_clock`         | `create_clock` on input port       |
| MOSI                   | Output — `set_output_delay`      | Input — `set_input_delay`          |
| MISO                   | Input — `set_input_delay`        | Output — `set_output_delay`        |
| SS_n                   | Output — `set_output_delay`      | Input — `set_input_delay`          |
| Clock domain crossing  | Optional (if bus clock ≠ SCLK)   | Always (external SCLK ≠ sys_clk)  |
| Multicycle paths       | Common (sys_clk >> SCLK)         | Less common (paths are in SCLK domain) |

---

## How to Obtain Timing Parameters

### Board Delays

- Use your PCB layout tool to extract trace lengths.
- Convert to delay: approximately **150 ps/inch** (6 ps/mm) for FR-4 microstrip.
- Add margin for connector delays, vias, and manufacturing variation.

### External Device Timing

Open the datasheet of the SPI slave (for master constraints) or SPI master (for
slave constraints) and find these parameters:

| Parameter   | Datasheet Label (typical)  | What It Means                          |
|-------------|----------------------------|----------------------------------------|
| `tsu`       | t_SU, t_SETUP              | Data setup time before sampling edge   |
| `th`        | t_HD, t_HOLD               | Data hold time after sampling edge     |
| `tco_max`   | t_CO, t_CLK_OUT, t_V       | Clock-to-output propagation (max)      |
| `tco_min`   | t_CO (min), t_OH           | Clock-to-output propagation (min)      |

---

## Timing Closure Checklist

1. **All clocks defined** — Verify with `report_clocks`.
2. **No unconstrained paths** — Run `check_timing` and resolve all warnings.
3. **Setup slack ≥ 0** on all constrained paths.
4. **Hold slack ≥ 0** on all constrained paths.
5. **No recovery/removal violations** on asynchronous resets.
6. **Review false paths** — Ensure no real timing paths are accidentally excluded.
7. **I/O standards set** — Confirm QSF assignments match your voltage levels.
8. **Post-fit timing met** — Setup/hold margins can change after place-and-route.

---

## Frequently Asked Questions

### Why use a virtual clock instead of referencing the real SCLK directly?

The virtual clock represents SCLK at the external device, separated from the
FPGA pin by board trace delay.  Referencing the virtual clock in `set_input_delay`
and `set_output_delay` properly models the fact that the clock and data travel
across PCB traces with different delays.

### Do I need constraints if my SPI clock is very slow?

Yes.  Even at 1 MHz, unconstrained paths cause Quartus to report timing warnings
and may lead to unpredictable fitter behavior.  Slow interfaces are easy to close
timing on, but they still need to be properly constrained.

### My design uses a PLL to generate the system clock.  Do I still need `create_clock`?

If the PLL IP auto-generates its own SDC file (common with Quartus IP), the PLL
output clock is already defined.  You only need to ensure your SDC references the
correct clock name.  Check with `report_clocks` after loading the netlist.

### What if my SPI interface supports multiple modes at runtime?

Constrain for the most timing-critical mode (usually Mode 0 or Mode 3, where
setup/hold alignment is tightest).  If all four modes must work, constrain for
the worst-case combination of setup and hold across all modes.

---

## References

- [Intel FPGA Timing Analyzer Cookbook](https://www.intel.com/content/www/us/en/docs/programmable/683068/current/timing-analyzer-cookbook.html)
- [Quartus Prime SDC & Timing Analyzer API Reference](https://www.intel.com/content/www/us/en/docs/programmable/683432/current/sdc-and-timequest-timing-analyzer-api.html)
- [Intel SPI Master IP Core User Guide](https://www.intel.com/content/www/us/en/docs/programmable/683277/current/using-spi-master-in-altera-devices.html)
- [AN 433: Constraining and Analyzing Source-Synchronous Interfaces](https://www.intel.com/content/www/us/en/docs/programmable/683082/current/constraining-and-analyzing-source.html)
