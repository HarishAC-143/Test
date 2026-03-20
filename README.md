# Embedded C Programming Guide

A comprehensive tutorial covering Embedded C programming from fundamentals to advanced techniques, with practical examples targeting real-world microcontroller development.

## Who Is This For?

This guide is intended for:

- Software developers transitioning into embedded systems
- Electronics/EE students learning firmware development
- Hobbyists working with Arduino, STM32, AVR, PIC, or similar platforms
- Anyone who wants to understand how C interacts directly with hardware

## Prerequisites

- Basic understanding of the C programming language
- Familiarity with binary and hexadecimal number systems
- (Optional) Access to a development board (e.g., STM32 Nucleo, Arduino, AVR)

## Table of Contents

### Part I — Fundamentals

| # | Chapter | Description |
|---|---------|-------------|
| 1 | [Introduction to Embedded C](docs/01-introduction.md) | What makes Embedded C different from standard C |
| 2 | [Data Types and Qualifiers](docs/02-data-types-and-qualifiers.md) | `volatile`, `const`, `static`, fixed-width integers |
| 3 | [Bit Manipulation](docs/03-bit-manipulation.md) | Setting, clearing, toggling, and testing bits |
| 4 | [Pointers and Memory-Mapped I/O](docs/04-pointers-and-memory-mapped-io.md) | Accessing hardware registers through pointers |
| 5 | [Structures, Unions, and Bit-Fields](docs/05-structures-unions-bitfields.md) | Modeling hardware registers and protocol frames |
| 6 | [Preprocessor and Macros](docs/06-preprocessor-and-macros.md) | Compile-time configuration, hardware abstraction |

### Part II — Peripheral Programming

| # | Chapter | Description |
|---|---------|-------------|
| 7 | [GPIO Programming](docs/07-gpio-programming.md) | Digital input/output, LED control, button reading |
| 8 | [Interrupts and ISRs](docs/08-interrupts-and-isrs.md) | Hardware interrupts, interrupt service routines, priorities |
| 9 | [Timers and PWM](docs/09-timers-and-pwm.md) | Hardware timers, delays, pulse-width modulation |
| 10 | [UART / Serial Communication](docs/10-uart-serial-communication.md) | Asynchronous serial, ring buffers, printf redirection |
| 11 | [ADC and DAC](docs/11-adc-and-dac.md) | Analog-to-digital and digital-to-analog conversion |

### Part III — Advanced Topics

| # | Chapter | Description |
|---|---------|-------------|
| 12 | [State Machines](docs/12-state-machines.md) | Table-driven and switch-based FSM patterns |
| 13 | [Circular Buffers](docs/13-circular-buffers.md) | Lock-free producer/consumer data structures |
| 14 | [RTOS Fundamentals](docs/14-rtos-fundamentals.md) | Tasks, scheduling, synchronization primitives |
| 15 | [Low-Power Techniques](docs/15-low-power-techniques.md) | Sleep modes, clock gating, peripheral power management |
| 16 | [Debugging and Best Practices](docs/16-debugging-and-best-practices.md) | Defensive coding, assertions, common pitfalls |

### Practical Examples

All runnable code examples are in the [`examples/`](examples/) directory, organized by topic:

| Directory | Contents |
|-----------|----------|
| [`examples/01_basics/`](examples/01_basics/) | Data types, volatile, bit manipulation demos |
| [`examples/02_gpio/`](examples/02_gpio/) | LED blink, button debounce, port configuration |
| [`examples/03_interrupts/`](examples/03_interrupts/) | External interrupt handling, ISR best practices |
| [`examples/04_timers/`](examples/04_timers/) | Delay generation, PWM output, input capture |
| [`examples/05_uart/`](examples/05_uart/) | Serial transmit/receive, ring buffer UART driver |
| [`examples/06_adc/`](examples/06_adc/) | Single-channel and multi-channel ADC sampling |
| [`examples/07_state_machines/`](examples/07_state_machines/) | Traffic light controller, menu system FSM |
| [`examples/08_circular_buffer/`](examples/08_circular_buffer/) | Generic circular buffer implementation |
| [`examples/09_watchdog/`](examples/09_watchdog/) | Watchdog timer configuration and feeding |
| [`examples/10_low_power/`](examples/10_low_power/) | Sleep mode entry/exit patterns |

## How to Use This Guide

1. **Read sequentially** if you are new to embedded development — each chapter builds on the previous.
2. **Jump to a topic** if you need a quick reference on a specific peripheral or technique.
3. **Study the examples** — each example compiles as a standalone file and includes detailed comments explaining the hardware interaction.

> **Note:** Most examples use generic register names and pseudo-hardware definitions so they can be understood without a specific microcontroller datasheet. Where a real target is used, STM32 (ARM Cortex-M) conventions are followed.

## Building the Examples

The examples are written as standalone C files. To compile any example for inspection (not linked to real hardware):

```bash
gcc -Wall -Wextra -std=c11 -o example examples/01_basics/bit_manipulation.c
```

For actual embedded targets, use the appropriate cross-compiler toolchain (e.g., `arm-none-eabi-gcc` for ARM Cortex-M).

## License

This project is provided for educational purposes. Feel free to use, modify, and distribute the content.
