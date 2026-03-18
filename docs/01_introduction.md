# Chapter 1: Introduction to Static Timing Analysis and SDC

## Table of Contents

- [What is Static Timing Analysis?](#what-is-static-timing-analysis)
- [Why STA Matters for FPGA Design](#why-sta-matters-for-fpga-design)
- [STA vs. Dynamic Timing Simulation](#sta-vs-dynamic-timing-simulation)
- [The SDC Format](#the-sdc-format)
- [Quartus Prime Timing Flow](#quartus-prime-timing-flow)
- [Key Timing Concepts](#key-timing-concepts)
- [Your First SDC File](#your-first-sdc-file)

---

## What is Static Timing Analysis?

Static Timing Analysis (STA) is a method for verifying timing performance of a digital circuit **without simulating it with test vectors**. Instead of running functional simulation, STA examines every possible timing path in the design and checks whether timing requirements (setup time, hold time, etc.) are met under all conditions.

STA works by:
1. Breaking the design into **timing paths** (from source to destination)
2. Computing the **delay** of each path using cell and interconnect delay models
3. Comparing the computed delays against **timing constraints** you provide
4. Reporting whether each path meets (passes) or violates (fails) its constraints

### Anatomy of a Timing Path

Every timing path has four components:

```
 Launch Clock Edge
       |
       v
  +---------+     +------------------+     +---------+
  | Source   |---->| Combinational    |---->| Dest.   |
  | Register |     | Logic + Routing  |     | Register|
  +---------+     +------------------+     +---------+
                                                 ^
                                                 |
                                           Capture Clock Edge
```

- **Launch edge**: The clock edge that launches data from the source register
- **Source register**: The flip-flop that drives data onto the path
- **Combinational logic + routing**: All logic gates and wires between source and destination
- **Destination register**: The flip-flop that captures the data
- **Capture edge**: The clock edge at the destination that captures the data

## Why STA Matters for FPGA Design

In FPGA design, the timing of your circuit is **not determined until after place-and-route**. The actual delays depend on:

- Which physical resources (ALMs/LEs, DSP blocks, RAM blocks) are used
- How signals are routed through the FPGA fabric
- Operating conditions (temperature, voltage, process variation)

Without proper timing constraints:
- The fitter has no targets to optimize for
- Critical paths may not be identified
- I/O interfaces may fail intermittently
- The design may work on your bench but fail in production

**STA with proper SDC constraints is the only reliable way to ensure your FPGA design meets timing across all conditions.**

## STA vs. Dynamic Timing Simulation

| Aspect | Static Timing Analysis | Dynamic Simulation |
|--------|----------------------|-------------------|
| **Coverage** | Exhaustive (all paths) | Only exercised paths |
| **Speed** | Fast (minutes) | Slow (hours/days) |
| **Vectors** | Not needed | Requires testbench |
| **Accuracy** | Depends on delay models | Depends on stimulus quality |
| **Glitch detection** | Limited | Yes |
| **Functional check** | No | Yes |

STA and simulation are complementary. Use STA for timing closure and simulation for functional verification.

## The SDC Format

**SDC (Synopsys Design Constraints)** is an industry-standard Tcl-based format for specifying timing constraints. Originally developed by Synopsys for ASIC design, it has been widely adopted by FPGA vendors including Intel (Altera).

SDC files use the `.sdc` extension and contain Tcl commands that describe:
- Clock definitions and relationships
- Input and output timing requirements
- Timing exceptions (false paths, multicycle paths)
- Design rule constraints

### SDC is Tcl

Because SDC is based on Tcl, you can use full Tcl programming constructs:

```tcl
# Variables
set CLK_PERIOD 10.0

# Arithmetic
set HALF_PERIOD [expr {$CLK_PERIOD / 2.0}]

# Conditionals
if {$CLK_PERIOD < 5.0} {
    post_message -type warning "Aggressive clock target"
}

# Loops for repetitive constraints
foreach port [get_ports data_*] {
    set_input_delay -clock sys_clk 2.0 $port
}
```

## Quartus Prime Timing Flow

The timing analysis flow in Quartus Prime follows these steps:

```
  ┌─────────────┐
  │  HDL Design  │
  └──────┬───────┘
         │
  ┌──────▼───────┐
  │  Synthesis    │  (Analysis & Synthesis)
  └──────┬───────┘
         │
  ┌──────▼───────┐     ┌──────────────┐
  │   Fitter     │◄────│  .sdc file   │
  │  (Place &    │     │  (Timing     │
  │   Route)     │     │  Constraints)│
  └──────┬───────┘     └──────────────┘
         │
  ┌──────▼───────┐
  │  TimeQuest   │  (Static Timing Analysis)
  │  Timing      │
  │  Analyzer    │
  └──────┬───────┘
         │
  ┌──────▼───────┐
  │  Timing      │
  │  Reports     │
  └──────────────┘
```

### Key Points

1. **SDC constraints are read by both the Fitter and TimeQuest.** The Fitter uses them to guide optimization; TimeQuest uses them for final timing verification.

2. **Unconstrained paths are not optimized.** If you don't constrain a path, the Fitter treats it as "don't care" and may produce poor timing results.

3. **Quartus looks for `.sdc` files** in your project directory, or you can specify them explicitly in the project settings (Assignments > Settings > TimeQuest Timing Analyzer).

## Key Timing Concepts

### Setup Time and Hold Time

**Setup time (Tsu)**: The minimum time data must be stable **before** the capturing clock edge.

**Hold time (Th)**: The minimum time data must be stable **after** the capturing clock edge.

```
              Setup Time        Hold Time
              ◄────────►        ◄───────►
              │         │       │        │
    Data:  ───╱ STABLE  ╲──────╱ STABLE ╲───
              │         │       │        │
    Clock: ──────────────┐      │
                         │      │
                         └──────┘
                      Capture Edge
```

### Setup Slack and Hold Slack

**Slack** is the margin between the required time and the actual arrival time:

```
Setup Slack = Data Required Time - Data Arrival Time

Hold Slack  = Data Arrival Time - Data Required Time
```

- **Positive slack**: Timing is met (the path passes)
- **Zero slack**: Timing is exactly met (no margin)
- **Negative slack**: Timing is violated (the path fails)

### Clock-to-Output (Tco)

The delay from the clock edge at a register to when the output data is valid:

```
Tco = Clock-to-Q delay of the source register
```

### Timing Corners (Operating Conditions)

Quartus analyzes timing under multiple operating conditions:

| Corner | Speed | Temperature | Voltage | Used For |
|--------|-------|-------------|---------|----------|
| **Slow** | Worst | 85°C (or 100°C) | Low | Setup analysis |
| **Fast** | Best | 0°C | High | Hold analysis |

Setup analysis uses the slow corner (maximum delays) because the concern is whether data arrives in time.
Hold analysis uses the fast corner (minimum delays) because the concern is whether data changes too quickly.

## Your First SDC File

Let's create a minimal SDC file for a simple design with a 50 MHz system clock:

```tcl
#--------------------------------------------------
# my_first_design.sdc
# Basic SDC constraints for a simple FPGA design
#--------------------------------------------------

# Step 1: Create the primary clock (50 MHz = 20 ns period)
create_clock -name sys_clk -period 20.000 [get_ports CLK_50MHZ]

# Step 2: Derive PLL clocks automatically (if using Altera PLLs)
derive_pll_clocks

# Step 3: Calculate clock uncertainty automatically
derive_clock_uncertainty

# Step 4: Constrain input ports
# All inputs are synchronous to sys_clk with 5 ns setup requirement
set_input_delay -clock sys_clk -max 5.000 [get_ports {data_in[*]}]
set_input_delay -clock sys_clk -min 1.000 [get_ports {data_in[*]}]

# Step 5: Constrain output ports
# All outputs must be valid 4 ns before the next clock edge
set_output_delay -clock sys_clk -max 4.000 [get_ports {data_out[*]}]
set_output_delay -clock sys_clk -min -1.000 [get_ports {data_out[*]}]
```

### What Each Command Does

| Command | Purpose |
|---------|---------|
| `create_clock` | Defines a clock signal with its period and waveform |
| `derive_pll_clocks` | Automatically creates clocks for Altera PLL outputs |
| `derive_clock_uncertainty` | Calculates and applies clock uncertainty (jitter + skew) |
| `set_input_delay` | Specifies when input data arrives relative to the clock |
| `set_output_delay` | Specifies when output data must be stable relative to the clock |

---

**Next: [Chapter 2 - Clock Constraints](02_clock_constraints.md)**
