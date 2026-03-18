# Altera FPGA Static Timing Analysis (SDC) - Comprehensive Tutorial

A complete, hands-on guide to mastering Synopsys Design Constraints (SDC) for static timing analysis on Intel (Altera) FPGAs using Quartus Prime and the TimeQuest Timing Analyzer.

## What You Will Learn

- Fundamentals of Static Timing Analysis and why it matters for FPGA design
- SDC syntax and the complete set of timing constraint commands
- How to constrain clocks, I/O ports, and complex timing relationships
- Timing exceptions: false paths, multicycle paths, min/max delays
- Advanced techniques for PLL, clock domain crossing, and DDR interfaces
- Reading and interpreting TimeQuest timing reports
- Industry best practices and how to avoid common pitfalls

## Tutorial Structure

### Documentation

| Chapter | Topic | Description |
|---------|-------|-------------|
| [Chapter 1](docs/01_introduction.md) | Introduction to STA & SDC | Fundamentals of static timing analysis, SDC origins, and the Quartus timing flow |
| [Chapter 2](docs/02_clock_constraints.md) | Clock Constraints | Defining clocks, generated clocks, virtual clocks, and clock groups |
| [Chapter 3](docs/03_io_constraints.md) | I/O Timing Constraints | Input/output delay constraints, system-synchronous and source-synchronous I/O |
| [Chapter 4](docs/04_timing_exceptions.md) | Timing Exceptions | False paths, multicycle paths, min/max delay overrides |
| [Chapter 5](docs/05_advanced_constraints.md) | Advanced Constraints | PLL constraints, clock domain crossings, clock uncertainty, and SDC scripting |
| [Chapter 6](docs/06_timing_reports.md) | Understanding Timing Reports | Reading TimeQuest reports, setup/hold analysis, and debugging failures |
| [Chapter 7](docs/07_best_practices.md) | Best Practices & Common Pitfalls | Constraint ordering, methodology, and common mistakes to avoid |

### Practical Examples

| Example | Description | Key Concepts |
|---------|-------------|--------------|
| [Basic Counter](examples/basic_counter/) | Simple synchronous counter with basic SDC | Clock creation, I/O delays |
| [UART Controller](examples/uart_controller/) | UART TX/RX with baud rate generation | Generated clocks, multicycle paths |
| [Clock Domain Crossing](examples/clock_domain_crossing/) | CDC synchronizer design | Multiple clocks, false paths, clock groups |
| [DDR Interface](examples/ddr_interface/) | Double data rate I/O interface | Source-synchronous constraints, center/edge-aligned clocking |
| [PLL Design](examples/pll_design/) | Altera PLL with derived clocks | PLL auto-constraints, derive_pll_clocks |
| [Pipelined Datapath](examples/pipelined_datapath/) | Multi-stage pipeline with timing exceptions | Multicycle paths, pipelining constraints |

## Prerequisites

- Intel Quartus Prime (Lite, Standard, or Pro Edition)
- Basic understanding of digital design and Verilog/VHDL
- Familiarity with FPGA design flow (synthesis, place & route)

## Quick Start

1. Start with [Chapter 1](docs/01_introduction.md) to understand the fundamentals
2. Follow each chapter sequentially for a structured learning path
3. Apply concepts hands-on using the [examples](examples/) directory
4. Refer to [Chapter 7](docs/07_best_practices.md) as a checklist before taping out

## Tool Versions

This tutorial targets Intel Quartus Prime 18.1+ and is applicable to:
- Cyclone IV, V, 10 LP/GX device families
- Arria II, V, 10 device families
- Stratix IV, V, 10 device families
- Agilex device families (Quartus Prime Pro)

## License

This tutorial is provided for educational purposes. All trademarks belong to their respective owners.
