# Example: UART Controller

UART transmitter and receiver demonstrating async input handling and clock enable patterns.

## Design

- UART TX: Parallel-to-serial with configurable baud rate
- UART RX: Serial-to-parallel with 16x oversampling and double-flop synchronizer
- Baud rate generator using clock enable (NOT a generated clock)

## Key SDC Concepts Demonstrated

| Concept | Command | Purpose |
|---------|---------|---------|
| System clock | `create_clock` | Define 50 MHz clock |
| Async input | `set_false_path` | RX serial input is asynchronous |
| Clock enable vs. generated clock | N/A | Baud counter uses enable, not a separate clock |
| Reset false path | `set_false_path` | Async reset excluded from timing |

## Important Lesson: Clock Enable vs. Generated Clock

The baud rate generator divides the system clock by counting cycles and producing a `baud_tick` enable signal. This is a **clock enable**, not a **generated clock**:

- The baud tick does NOT drive any clock pin
- All flip-flops are still clocked by `sys_clk`
- No `create_generated_clock` is needed
- No cross-domain analysis is needed

## Files

- `uart_tx.v` - UART transmitter
- `uart_rx.v` - UART receiver with input synchronizer
- `uart_controller.sdc` - SDC constraints
