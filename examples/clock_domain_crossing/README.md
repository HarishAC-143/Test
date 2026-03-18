# Example: Clock Domain Crossing

Asynchronous FIFO with Gray code pointers and single-bit synchronizers.

## Design

- **async_fifo**: Parameterized asynchronous FIFO using Gray code pointer synchronization
- **cdc_single_bit**: Double-flop synchronizer for individual signals
- Two independent clock domains: 100 MHz (write) and 75 MHz (read)

## Key SDC Concepts Demonstrated

| Concept | Command | Purpose |
|---------|---------|---------|
| Multiple clocks | `create_clock` (x2) | Define independent clock domains |
| Async clock groups | `set_clock_groups -asynchronous` | Declare domains as unrelated |
| Gray code CDC | `set_max_delay` | Bound skew between Gray code bits |
| Single-bit CDC | `set_false_path` | Allow metastability resolution time |
| Choosing the right exception | N/A | When to use false_path vs. max_delay |

## Important Lesson: false_path vs. max_delay for CDC

- **Single-bit signal**: Use `set_false_path` -- no bit-to-bit skew concern
- **Multi-bit Gray code**: Use `set_max_delay` -- bounds inter-bit skew to prevent corruption
- **Multi-bit binary bus**: Neither works! Use an async FIFO or handshake protocol

## Files

- `cdc_sync.v` - Synchronizer modules (single-bit + async FIFO)
- `cdc_sync.sdc` - SDC constraints with detailed explanations
