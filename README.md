# Altera (Intel) SPI Master & Slave SDC Timing Constraints

SDC (Synopsys Design Constraints) files for the **Altera Avalon SPI** IP core in both **master** and **slave** configurations, targeting Intel (Altera) FPGAs.

## Files

| File | Description |
|------|-------------|
| `altera_spi_master.sdc` | Timing constraints for SPI **master** mode |
| `altera_spi_slave.sdc`  | Timing constraints for SPI **slave** mode  |

## What is Covered

Each SDC file contains fully commented constraints for:

1. **Clock definitions** — system clock and SPI serial clock (generated clock for master, external input clock for slave).
2. **Output delay** — constrains data outputs (MOSI for master, MISO for slave) relative to SCLK to guarantee setup/hold at the receiving device.
3. **Input delay** — constrains data inputs (MISO for master, MOSI for slave) to verify adequate setup/hold margin at the FPGA's sampling register.
4. **Clock groups** — declares asynchronous relationships between the SPI clock domain and other system clocks.
5. **False paths** — template exceptions for CDC synchronisers and static configuration registers.
6. **Multicycle paths** — template exceptions for paths that span multiple SCLK cycles due to clock-frequency ratios.
7. **Skew / tri-state** — output skew limits (master) and MISO tri-state disable timing (slave).

## How to Use

1. **Copy** the appropriate `.sdc` file into your Quartus project directory.
2. **Edit Section 1** (User-Tunable Parameters) to match your:
   - System and SPI clock frequencies.
   - Board-level PCB trace delays.
   - External device timing parameters (from its datasheet).
   - SPI port and instance names used in your design hierarchy.
3. **Add the SDC file** to your Quartus project:
   - *Project > Settings > Timing Analyzer > SDC files* or via the QSF:
     ```
     set_global_assignment -name SDC_FILE altera_spi_master.sdc
     ```
4. **Uncomment** optional sections (false paths, multicycle paths, clock groups) as needed for your design.
5. **Run the Timing Analyzer** and review reports to verify all SPI interface paths meet timing.

## SPI Modes Reference

| Mode | CPOL | CPHA | Clock Idle | Data Sampled On | Data Shifted On |
|------|------|------|------------|-----------------|-----------------|
| 0    | 0    | 0    | Low        | Rising edge     | Falling edge    |
| 1    | 0    | 1    | Low        | Falling edge    | Rising edge     |
| 2    | 1    | 0    | High       | Falling edge    | Rising edge     |
| 3    | 1    | 1    | High       | Rising edge     | Falling edge    |

Both constraint files include rising-edge and falling-edge delay analyses so they can be used with any SPI mode. Disable the unused edge constraints if your design is locked to a single mode.

## Target Devices

These constraints are written for the Intel Quartus Prime Timing Analyzer and are compatible with all Intel FPGA families (Cyclone, Arria, Stratix, MAX 10, Agilex).
