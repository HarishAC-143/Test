# Example: Basic Counter

A simple 8-bit synchronous counter demonstrating the minimum SDC constraint set.

## Design

- 8-bit up-counter with synchronous enable and load
- Asynchronous active-low reset
- Overflow output flag
- Single clock domain (50 MHz)

## Key SDC Concepts Demonstrated

| Concept | Command | Purpose |
|---------|---------|---------|
| Clock definition | `create_clock` | Define the 50 MHz system clock |
| Clock uncertainty | `derive_clock_uncertainty` | Account for jitter/skew |
| Input timing | `set_input_delay` | Constrain data arrival at FPGA inputs |
| Output timing | `set_output_delay` | Constrain data departure from FPGA outputs |
| Async reset | `set_false_path` | Exclude async reset from timing analysis |

## Files

- `counter.v` - Verilog RTL design
- `counter.sdc` - SDC timing constraints (heavily commented)

## How to Use

1. Create a new Quartus project targeting a Cyclone V device
2. Add `counter.v` as a design file
3. Add `counter.sdc` as a timing constraints file
4. Compile and check the TimeQuest timing report
