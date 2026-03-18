# Altera FPGA Static Timing Analysis (SDC) Tutorial

A comprehensive tutorial on writing SDC (Synopsys Design Constraints) files for Intel (Altera) FPGA designs, with practical examples covering real-world interfaces and design patterns.

## Tutorial

The main tutorial document covers all SDC concepts from fundamentals to advanced topics:

- **[altera_sdc_tutorial.md](altera_sdc_tutorial.md)** - Complete tutorial (12 chapters)

### Topics Covered

| Chapter | Topic |
|---------|-------|
| 1 | Introduction to Static Timing Analysis |
| 2 | SDC Fundamentals (Tcl basics, object access, file structure) |
| 3 | Clock Constraints (`create_clock`, `create_generated_clock`, PLL) |
| 4 | I/O Timing Constraints (`set_input_delay`, `set_output_delay`, virtual clocks) |
| 5 | Timing Exceptions (`set_false_path`, `set_multicycle_path`, `set_max_delay`) |
| 6 | Clock Groups and Relationships |
| 7 | Intel (Altera) Specific SDC Commands |
| 8 | TimeQuest Timing Analyzer |
| 9 | Practical Design Examples |
| 10 | Debugging Timing Failures |
| 11 | Best Practices and Common Pitfalls |
| 12 | Quick Reference |

## Practical Examples

The `examples/` directory contains 11 ready-to-use SDC files demonstrating real-world constraints:

| File | Scenario | Key Concepts |
|------|----------|-------------|
| [01_single_clock.sdc](examples/01_single_clock.sdc) | Data processing pipeline with SRAM | Basic clock, I/O delays, false paths |
| [02_multi_clock_pll.sdc](examples/02_multi_clock_pll.sdc) | Video processor with PLL | `derive_pll_clocks`, clock groups, multicycle paths |
| [03_rgmii_interface.sdc](examples/03_rgmii_interface.sdc) | Gigabit Ethernet RGMII | Source-synchronous DDR, `-clock_fall`, `-add_delay` |
| [04_cdc_fifo.sdc](examples/04_cdc_fifo.sdc) | Async FIFO between two domains | CDC constraints, `set_max_delay -datapath_only` |
| [05_sdram_interface.sdc](examples/05_sdram_interface.sdc) | SDRAM controller | Phase-shifted clocks, bidirectional I/O, CAS latency MCP |
| [06_spi_master.sdc](examples/06_spi_master.sdc) | SPI master interface | Generated clocks from dividers, SPI timing |
| [07_ddr_memory.sdc](examples/07_ddr_memory.sdc) | DDR2 memory interface | DQS clocks, exclusive groups, DDR read/write paths |
| [08_uart_i2c_slow_interfaces.sdc](examples/08_uart_i2c_slow_interfaces.sdc) | UART, I2C, GPIO | Slow interface strategies (virtual clock vs. false path) |
| [09_clock_mux_exclusive.sdc](examples/09_clock_mux_exclusive.sdc) | Switchable clock sources | Exclusive clock groups, multiple generated clocks on one pin |
| [10_complete_soc.sdc](examples/10_complete_soc.sdc) | Full Nios II SoC | Complete real-world constraint set with all interfaces |
| [11_timing_analysis_script.tcl](examples/11_timing_analysis_script.tcl) | Timing analysis automation | TimeQuest Tcl report scripting |

## Design Examples

The `designs/` directory contains RTL source code that accompanies the SDC files:

| File | Description |
|------|-------------|
| [data_processor.v](designs/data_processor.v) | Multi-clock data processor with PLL, FIFO CDC, SPI, SRAM |
| [data_processor.sdc](designs/data_processor.sdc) | Complete SDC for the data processor design |
| [async_fifo.v](designs/async_fifo.v) | Gray-coded async FIFO (shows RTL targeted by CDC constraints) |

## Getting Started

1. Read the [main tutorial](altera_sdc_tutorial.md) for conceptual understanding
2. Study the [examples](examples/) that match your interface requirements
3. Examine the [design files](designs/) to see how RTL and SDC relate
4. Use Example 11 as a template for automating your timing analysis

## Prerequisites

- Intel Quartus Prime (Lite, Standard, or Pro edition)
- Basic understanding of digital design and Verilog/VHDL
- Familiarity with FPGA design flow (synthesis, place-and-route)
