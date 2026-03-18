# Example: Pipelined Datapath

A 4-stage processing pipeline demonstrating multicycle paths and static configuration false paths.

## Design

- 4-stage pipeline: Input Reg -> Arithmetic -> Post-processing -> Output
- Static configuration registers (set once at boot, never change)
- Slow status interface (updates every 4 clock cycles)
- 200 MHz system clock

## Key SDC Concepts Demonstrated

| Concept | Command | Purpose |
|---------|---------|---------|
| Pipeline timing | (default) | Pipeline stages use standard single-cycle analysis |
| Static config | `set_false_path` | Configuration that never changes |
| Slow update (4-cycle) | `set_multicycle_path` 4/3 | Status updated every 4th cycle |
| N-1 rule | Setup=N, Hold=N-1 | Proper multicycle hold companion |

## Important Lessons

### 1. Pipelines Do NOT Need Multicycle Constraints

Each pipeline stage is a standard single-cycle path. If a stage has too much logic, add more pipeline registers in RTL rather than adding a multicycle constraint.

### 2. Static Signals Use False Paths

Signals that are set once and never change during operation (configuration registers, mode selects) should be false-pathed. This gives the fitter freedom and prevents over-constraining.

### 3. The N-1 Rule for Multicycle Paths

When you set a multicycle path with setup = N, you **must** also set hold = N-1:

```tcl
set_multicycle_path -setup ... 4    # Allow 4 cycles
set_multicycle_path -hold  ... 3    # Hold companion (4-1 = 3)
```

Forgetting the hold companion causes impossible-to-meet hold violations.

## Files

- `pipeline.v` - 4-stage pipeline with config and status interfaces
- `pipeline.sdc` - Multicycle and false path constraints
