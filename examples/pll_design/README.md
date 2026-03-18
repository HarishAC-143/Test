# Example: PLL-Based Multi-Clock Design

Multi-domain design using Altera PLL IP with automatic constraint derivation.

## Design

- Input: 50 MHz oscillator
- PLL Output c0: 200 MHz (fast processing domain)
- PLL Output c1: 25 MHz (slow control domain)
- PLL Output c2: 100 MHz, 90 degree phase shift
- CDC synchronizer between fast and slow domains

## Key SDC Concepts Demonstrated

| Concept | Command | Purpose |
|---------|---------|---------|
| Base clock | `create_clock` | Define PLL input clock |
| Auto PLL constraints | `derive_pll_clocks` | Automatically constrain PLL outputs |
| Clock uncertainty | `derive_clock_uncertainty` | Account for PLL jitter |
| Related clocks | N/A | PLL outputs from same PLL are NOT async |
| CDC synchronizer | `set_false_path` | False-path to synchronizer meta register |

## Important Lesson: PLL Outputs are Related

Clocks from the **same PLL** share a common reference and are phase-related. TimeQuest correctly analyzes timing between them. Do NOT declare them as asynchronous:

```tcl
# WRONG -- these clocks come from the same PLL!
set_clock_groups -asynchronous -group {pll_clk_200} -group {pll_clk_25}

# CORRECT -- let TimeQuest analyze the relationship
# (no set_clock_groups needed for same-PLL outputs)
```

Clocks from **different PLLs** with independent input clocks ARE asynchronous.

## Files

- `pll_top.v` - Multi-domain design with PLL instantiation placeholder
- `pll_top.sdc` - PLL-aware SDC constraints
