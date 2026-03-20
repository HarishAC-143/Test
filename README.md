# Embedded C Programming Tutorial

A comprehensive guide to Embedded C programming — from fundamentals to advanced techniques — with practical, real-world examples targeting microcontrollers.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Repository Structure](#repository-structure)
4. [Tutorial Material](#tutorial-material)
5. [Building and Running Examples](#building-and-running-examples)
6. [Target Platform](#target-platform)
7. [Contributing](#contributing)
8. [License](#license)

## Introduction

Embedded C is a set of language extensions for the C programming language, designed to address commonalities and differences between C extensions for different embedded systems. It is widely used to program microcontrollers, DSPs, and other embedded processors.

This tutorial covers:

- **Basics**: Data types, memory-mapped I/O, bitwise operations, volatile and const qualifiers
- **Intermediate**: Interrupts, timers, UART communication, ADC/DAC, SPI, I2C, watchdog timers
- **Advanced**: DMA, RTOS fundamentals, state machines, low-power modes, memory management, debugging

## Getting Started

### Prerequisites

- A C compiler (`arm-none-eabi-gcc` for ARM targets, or `gcc` for host-based simulation)
- Basic understanding of C programming
- Familiarity with binary and hexadecimal number systems
- A text editor or IDE (VS Code, STM32CubeIDE, Keil, IAR)
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
├── embedded-c-programming-guide.md    # Monolithic tutorial guide (21 topics)
├── docs/
│   ├── 01_basics.md                   # Basics tutorial chapter
│   ├── 02_intermediate.md            # Intermediate tutorial chapter
│   ├── 03_advanced.md                # Advanced tutorial chapter
│   └── 04_practical_projects.md      # Practical projects chapter
├── examples/
│   ├── 01_basics/                    # Categorized examples with Makefiles
│   │   ├── data_types.c
│   │   ├── bitwise_operations.c
│   │   ├── register_access.c
│   │   ├── gpio_control.c
│   │   └── Makefile
│   ├── 02_intermediate/
│   │   ├── interrupt_handler.c
│   │   ├── timer_config.c
│   │   ├── uart_driver.c
│   │   ├── adc_reader.c
│   │   ├── watchdog_timer.c
│   │   └── Makefile
│   ├── 03_advanced/
│   │   ├── dma_transfer.c
│   │   ├── simple_rtos.c
│   │   ├── state_machine.c
│   │   ├── low_power.c
│   │   ├── ring_buffer.c
│   │   └── Makefile
│   ├── 04_projects/
│   │   ├── temperature_monitor.c
│   │   ├── led_pattern_controller.c
│   │   ├── serial_command_parser.c
│   │   ├── debounce_library.c
│   │   └── Makefile
│   ├── 01_gpio_driver.c              # Standalone annotated examples
│   ├── 02_timer_driver.c
│   ├── 03_uart_driver.c
│   ├── 04_uart_ring_buffer.c
│   ├── 05_adc_driver.c
│   ├── 06_spi_driver.c
│   ├── 07_i2c_driver.c
│   ├── 08_dma_driver.c
│   ├── 09_state_machine.c
│   ├── 10_rtos_tasks.c
│   └── 11_memory_pool.c
```

## Tutorial Material

### Programming Guide

**[`embedded-c-programming-guide.md`](embedded-c-programming-guide.md)** — A comprehensive single-file guide covering 21 topics:

| # | Topic | Level |
|---|---|---|
| 1 | Introduction to Embedded C | Beginner |
| 2 | Embedded C vs Standard C | Beginner |
| 3 | Data Types and Memory Layout | Beginner |
| 4 | Bit Manipulation | Beginner |
| 5 | Volatile, Const, and Static Qualifiers | Beginner |
| 6 | Memory-Mapped I/O and Register Access | Intermediate |
| 7 | GPIO Programming | Intermediate |
| 8 | Interrupt Handling | Intermediate |
| 9 | Timers and Counters | Intermediate |
| 10 | UART Serial Communication | Intermediate |
| 11 | ADC and DAC | Intermediate |
| 12 | SPI Communication | Intermediate |
| 13 | I2C Communication | Intermediate |
| 14 | DMA (Direct Memory Access) | Advanced |
| 15 | Finite State Machines | Advanced |
| 16 | RTOS Fundamentals | Advanced |
| 17 | Memory Management Strategies | Advanced |
| 18 | Low-Power Design Techniques | Advanced |
| 19 | Watchdog Timers and System Reliability | Advanced |
| 20 | Debugging and Testing | Advanced |
| 21 | Coding Standards and Best Practices | All Levels |

### Tutorial Chapters

Detailed tutorial chapters with in-depth explanations in the [`docs/`](docs/) directory:

| Chapter | Topic | Description |
|---------|-------|-------------|
| [Chapter 1](docs/01_basics.md) | **Basics** | Data types, memory layout, bitwise ops, register access, GPIO |
| [Chapter 2](docs/02_intermediate.md) | **Intermediate** | Interrupts, timers, UART, ADC, watchdog timers |
| [Chapter 3](docs/03_advanced.md) | **Advanced** | DMA, RTOS concepts, state machines, low-power modes |
| [Chapter 4](docs/04_practical_projects.md) | **Practical Projects** | Complete real-world project examples |

### Standalone Annotated Examples

Self-contained source files with detailed comments in the [`examples/`](examples/) directory:

| File | Description | Key Concepts |
|---|---|---|
| [`01_gpio_driver.c`](examples/01_gpio_driver.c) | GPIO driver with button debounce | Structure overlays, pin configuration, EXTI |
| [`02_timer_driver.c`](examples/02_timer_driver.c) | Timer driver with PWM and input capture | Periodic interrupts, PWM, encoder mode |
| [`03_uart_driver.c`](examples/03_uart_driver.c) | Polled UART with CLI interface | Baud rate calc, printf, command parser |
| [`04_uart_ring_buffer.c`](examples/04_uart_ring_buffer.c) | Interrupt-driven UART with ring buffer | Lock-free SPSC queue, ISR design |
| [`05_adc_driver.c`](examples/05_adc_driver.c) | ADC with averaging and watchdog | Oversampling, moving average filter |
| [`06_spi_driver.c`](examples/06_spi_driver.c) | SPI master with Flash/sensor/DAC | W25Q Flash, MAX31855, MCP4921 |
| [`07_i2c_driver.c`](examples/07_i2c_driver.c) | I2C master with multiple sensors | Bus scan, LM75, MPU6050, AT24C EEPROM |
| [`08_dma_driver.c`](examples/08_dma_driver.c) | DMA for UART TX and ADC sampling | Double buffering, signal statistics |
| [`09_state_machine.c`](examples/09_state_machine.c) | FSM patterns (switch, table-driven) | Traffic light, thermostat controller |
| [`10_rtos_tasks.c`](examples/10_rtos_tasks.c) | FreeRTOS multitasking system | Queues, mutexes, semaphores, events |
| [`11_memory_pool.c`](examples/11_memory_pool.c) | Fixed-block memory allocator | Free-list pool, multi-pool, packet buffers |

### Categorized Examples with Build System

Compilable examples organized by difficulty in subdirectories, each with a `Makefile`:

| Directory | Examples | Topics |
|-----------|----------|--------|
| [`examples/01_basics/`](examples/01_basics/) | 4 files | Data types, bitwise ops, register access, GPIO |
| [`examples/02_intermediate/`](examples/02_intermediate/) | 5 files | Interrupts, timers/PWM, UART, ADC, watchdog |
| [`examples/03_advanced/`](examples/03_advanced/) | 5 files | DMA, RTOS scheduler, state machines, low-power, ring buffers |
| [`examples/04_projects/`](examples/04_projects/) | 4 files | Temperature monitor, LED controller, serial CLI, debounce library |

## Building and Running Examples

The categorized examples in subdirectories include `Makefile`s and use simulated hardware registers so they compile and run on a host PC:

```bash
# Build all basics examples
cd examples/01_basics && make

# Build and run a specific example
cd examples/01_basics && make data_types && ./data_types

# Clean build artifacts
make clean
```

The standalone annotated examples (`examples/01_gpio_driver.c`, etc.) use STM32-style register definitions and are designed to be studied and adapted for real hardware.

For deployment on real hardware, adapt the register addresses and linker scripts to match your specific microcontroller.

## Target Platform

The examples use STM32-style (ARM Cortex-M) register definitions. The concepts and patterns apply broadly to any embedded microcontroller, including:

- STM32 (F1/F4/L4/H7 series)
- NXP LPC / i.MX RT
- TI MSP432 / TM4C
- Microchip SAM (Cortex-M based)
- Nordic nRF52 series

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with improvements, corrections, or new examples.

## License

This project is released under the MIT License. See individual files for details.
