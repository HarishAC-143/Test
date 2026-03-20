# Embedded C Programming Tutorial

A comprehensive guide to Embedded C programming — from fundamentals to advanced techniques — with practical, real-world examples targeting microcontrollers.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Repository Structure](#repository-structure)
4. [Tutorial Chapters](#tutorial-chapters)
5. [Building and Running Examples](#building-and-running-examples)
6. [Contributing](#contributing)
7. [License](#license)

## Introduction

Embedded C is a set of language extensions for the C programming language, designed to address commonalities and differences between C extensions for different embedded systems. It is widely used to program microcontrollers, DSPs, and other embedded processors.

This tutorial covers:

- **Basics**: Data types, memory-mapped I/O, bitwise operations, volatile and const qualifiers
- **Intermediate**: Interrupts, timers, UART communication, ADC/DAC, watchdog timers
- **Advanced**: DMA, RTOS fundamentals, state machines, low-power modes, bootloaders
- **Practical Projects**: Complete working examples you can adapt for real hardware

## Getting Started

### Prerequisites

- A C compiler (`arm-none-eabi-gcc` for ARM targets, or `gcc` for host-based simulation)
- Basic understanding of C programming
- Familiarity with binary and hexadecimal number systems
- (Optional) A development board such as STM32 Nucleo, Arduino, or similar

### Toolchain Setup

```bash
# Ubuntu/Debian — install ARM cross-compiler
sudo apt-get install gcc-arm-none-eabi

# macOS — via Homebrew
brew install --cask gcc-arm-embedded

# Verify installation
arm-none-eabi-gcc --version
```

## Repository Structure

```
.
├── README.md                          # This file
├── docs/
│   ├── 01_basics.md                   # Basics tutorial chapter
│   ├── 02_intermediate.md            # Intermediate tutorial chapter
│   ├── 03_advanced.md                # Advanced tutorial chapter
│   └── 04_practical_projects.md      # Practical projects chapter
├── examples/
│   ├── 01_basics/
│   │   ├── data_types.c              # Embedded data types and qualifiers
│   │   ├── bitwise_operations.c      # Bitwise manipulation techniques
│   │   ├── register_access.c         # Memory-mapped register access
│   │   ├── gpio_control.c            # GPIO pin control
│   │   └── Makefile
│   ├── 02_intermediate/
│   │   ├── interrupt_handler.c       # Interrupt setup and handling
│   │   ├── timer_config.c            # Timer/counter configuration
│   │   ├── uart_driver.c             # UART serial communication
│   │   ├── adc_reader.c              # ADC analog-to-digital conversion
│   │   ├── watchdog_timer.c          # Watchdog timer usage
│   │   └── Makefile
│   ├── 03_advanced/
│   │   ├── dma_transfer.c            # DMA data transfer
│   │   ├── simple_rtos.c             # Minimal RTOS scheduler
│   │   ├── state_machine.c           # Finite state machine pattern
│   │   ├── low_power.c              # Low-power mode management
│   │   ├── ring_buffer.c            # Lock-free ring buffer
│   │   └── Makefile
│   └── 04_projects/
│       ├── temperature_monitor.c     # Complete temperature monitoring system
│       ├── led_pattern_controller.c  # LED pattern controller with button input
│       ├── serial_command_parser.c   # Serial command-line interface
│       ├── debounce_library.c        # Button debounce library
│       └── Makefile
```

## Tutorial Chapters

| Chapter | Topic | Description |
|---------|-------|-------------|
| [Chapter 1](docs/01_basics.md) | **Basics** | Data types, memory layout, bitwise ops, register access, GPIO |
| [Chapter 2](docs/02_intermediate.md) | **Intermediate** | Interrupts, timers, UART, ADC, watchdog timers |
| [Chapter 3](docs/03_advanced.md) | **Advanced** | DMA, RTOS concepts, state machines, low-power modes |
| [Chapter 4](docs/04_practical_projects.md) | **Practical Projects** | Complete real-world project examples |

## Building and Running Examples

Each example directory contains a `Makefile`. The examples are written in a portable style using simulated hardware registers so they can compile and run on a host PC for learning purposes.

```bash
# Build all basics examples
cd examples/01_basics && make

# Build and run a specific example
cd examples/01_basics && make data_types && ./data_types

# Clean build artifacts
make clean
```

For deployment on real hardware, adapt the register addresses and linker scripts to match your specific microcontroller.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with improvements, corrections, or new examples.

## License

This project is released under the MIT License. See individual files for details.
