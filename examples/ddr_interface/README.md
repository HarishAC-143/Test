# Example: DDR I/O Interface

Generic double data rate I/O interface demonstrating source-synchronous timing constraints.

## Design

- DDR TX: Outputs data on both rising and falling clock edges with a forwarded clock
- DDR RX: Captures incoming data on both edges of a source-synchronous clock
- Data transfer from DDR RX domain to system clock domain

## Key SDC Concepts Demonstrated

| Concept | Command | Purpose |
|---------|---------|---------|
| Source-sync clock | `create_clock` | Define incoming DDR clock |
| Generated clock | `create_generated_clock` | Define forwarded TX clock |
| DDR input delays | `set_input_delay -clock_fall -add_delay` | Constrain both edges |
| DDR output delays | `set_output_delay -clock_fall -add_delay` | Constrain both edges |
| Center-aligned clocking | Symmetric max/min delays | Clock at center of data eye |
| Async clock groups | `set_clock_groups` | Separate source-sync from system domain |

## Important Lesson: -clock_fall and -add_delay

For DDR interfaces, you must constrain data relative to **both** clock edges:

```tcl
# Rising edge constraint (default)
set_input_delay -clock ddr_clk -max 0.3 [get_ports DATA]

# Falling edge constraint (MUST use -add_delay to not overwrite!)
set_input_delay -clock ddr_clk -max 0.3 -clock_fall -add_delay [get_ports DATA]
```

Without `-add_delay`, the second command overwrites the first.

## Files

- `ddr_io.v` - DDR I/O module with TX and RX paths
- `ddr_io.sdc` - DDR-specific SDC constraints
