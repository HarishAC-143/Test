# Altera FPGA Static Timing Analysis (SDC) Tutorial

A comprehensive tutorial on Synopsys Design Constraints (SDC) for Altera (Intel) FPGA designs, covering everything from basic clock definitions to advanced multi-clock timing analysis.

## Contents

### Tutorial Document

- **[altera_sdc_tutorial.md](altera_sdc_tutorial.md)** -- The complete tutorial covering:
  - Fundamentals of Static Timing Analysis (setup, hold, slack)
  - SDC file syntax and structure
  - Clock constraints (`create_clock`, `create_generated_clock`)
  - PLL clock derivation (`derive_pll_clocks`)
  - I/O timing constraints (`set_input_delay`, `set_output_delay`)
  - Timing exceptions (false paths, multicycle paths)
  - Clock groups and domain crossings
  - Advanced constraints (latency, uncertainty, skew)
  - TimeQuest Timing Analyzer usage
  - Common pitfalls and best practices
  - Quick reference tables and formulas

### Practical SDC Examples

Located in the `examples/` directory:

| File | Description |
|---|---|
| [01_basic_clock.sdc](examples/01_basic_clock.sdc) | Minimal SDC for a single-clock design |
| [02_pll_clocks.sdc](examples/02_pll_clocks.sdc) | PLL-based clock constraints with `derive_pll_clocks` |
| [03_io_constraints.sdc](examples/03_io_constraints.sdc) | Input/output delay calculations with worked math |
| [04_false_paths.sdc](examples/04_false_paths.sdc) | False path types: resets, CDC, config registers, debug |
| [05_multicycle_paths.sdc](examples/05_multicycle_paths.sdc) | Multicycle constraints with hold companions and `-start`/`-end` |
| [06_clock_groups.sdc](examples/06_clock_groups.sdc) | Asynchronous and exclusive clock group definitions |
| [07_source_synchronous_interface.sdc](examples/07_source_synchronous_interface.sdc) | SDR and DDR source-synchronous I/O constraints |
| [08_complete_design.sdc](examples/08_complete_design.sdc) | Full real-world video processing design constraints |
| [09_timing_analysis_scripts.tcl](examples/09_timing_analysis_scripts.tcl) | TimeQuest Tcl scripts for timing verification and debug |

## Target Audience

- FPGA engineers working with Altera (Intel) Cyclone, Arria, Stratix, MAX, or Agilex devices
- Digital designers learning static timing analysis
- Engineers migrating from ASIC flows to FPGA flows
- Anyone using the Quartus Prime TimeQuest Timing Analyzer

## Prerequisites

- Basic understanding of digital logic (flip-flops, combinational logic)
- Familiarity with Verilog or VHDL
- Access to Intel Quartus Prime (any edition)
