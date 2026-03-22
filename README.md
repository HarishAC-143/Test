# Embedded C Programming Guide & UVM Reference

A comprehensive tutorial covering Embedded C programming from basics to advanced topics, with practical, runnable examples targeting ARM Cortex-M microcontrollers. Also includes a detailed UVM (Universal Verification Methodology) reference covering all UVM classes and their internal functions with annotated SystemVerilog examples.

## Contents

### Tutorial Guide

**[`embedded-c-programming-guide.md`](embedded-c-programming-guide.md)** — Full tutorial covering 21 topics:

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

### Practical Examples

Complete, annotated source files in the [`examples/`](examples/) directory:

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

### UVM (Universal Verification Methodology) Guide

**[`uvm-classes-and-functions-guide.md`](uvm-classes-and-functions-guide.md)** — Detailed reference covering 24 topics:

| # | Topic | Level |
|---|---|---|
| 1 | UVM Overview and Architecture | Beginner |
| 2 | UVM Class Hierarchy | Beginner |
| 3 | uvm_void | Beginner |
| 4 | uvm_object — Core Data Methods | Intermediate |
| 5 | uvm_transaction | Intermediate |
| 6 | uvm_sequence_item | Intermediate |
| 7 | uvm_sequence | Intermediate |
| 8 | uvm_component | Intermediate |
| 9 | uvm_driver | Intermediate |
| 10 | uvm_monitor | Intermediate |
| 11 | uvm_sequencer | Intermediate |
| 12 | uvm_agent | Intermediate |
| 13 | uvm_scoreboard | Intermediate |
| 14 | uvm_env | Intermediate |
| 15 | uvm_test | Intermediate |
| 16 | UVM Phases In Detail | Advanced |
| 17 | UVM Factory | Advanced |
| 18 | UVM Configuration Database | Advanced |
| 19 | UVM TLM Ports and Communication | Advanced |
| 20 | UVM Reporting and Messaging | Intermediate |
| 21 | UVM Register Layer (UVM RAL) | Advanced |
| 22 | UVM Field Automation Macros | Intermediate |
| 23 | UVM Callbacks | Advanced |
| 24 | Complete UVM Testbench Example | All Levels |

### UVM SystemVerilog Examples

| File | Description | Key Concepts |
|---|---|---|
| [`12_uvm_sequence_item.sv`](examples/12_uvm_sequence_item.sv) | APB transaction with manual do_* hooks | do_copy, do_compare, do_print, do_pack, do_unpack, constraints |
| [`13_uvm_sequence.sv`](examples/13_uvm_sequence.sv) | Six sequence patterns | Simple, response, composed, burst, stress, virtual sequence |
| [`14_uvm_driver_monitor.sv`](examples/14_uvm_driver_monitor.sv) | APB driver and monitor with interface | Protocol timing, analysis ports, functional coverage |
| [`15_uvm_agent_env_test.sv`](examples/15_uvm_agent_env_test.sv) | Complete agent/env/test hierarchy | Config objects, scoreboard, factory overrides, active/passive |
| [`16_uvm_register_model.sv`](examples/16_uvm_register_model.sv) | UVM RAL register model | Fields, registers, blocks, adapter, predictor, access patterns |

## Target Platform

The examples use STM32-style (ARM Cortex-M) register definitions. The concepts and patterns apply broadly to any embedded microcontroller, including:

- STM32 (F1/F4/L4/H7 series)
- NXP LPC / i.MX RT
- TI MSP432 / TM4C
- Microchip SAM (Cortex-M based)
- Nordic nRF52 series

## How to Use

### Embedded C
1. **Read the guide** — Start with [`embedded-c-programming-guide.md`](embedded-c-programming-guide.md) for conceptual understanding.
2. **Study the examples** — Each file in `examples/` (01–11) is self-contained with detailed comments.
3. **Adapt to your platform** — Replace register addresses and peripheral definitions with those from your MCU's reference manual or vendor HAL.

### UVM
1. **Read the UVM guide** — [`uvm-classes-and-functions-guide.md`](uvm-classes-and-functions-guide.md) covers every major UVM class with method tables and code.
2. **Study the examples** — Files 12–16 in `examples/` demonstrate each UVM concept with complete, annotated SystemVerilog code.
3. **Use as reference** — The guide includes quick-reference tables for macros, phases, command-line arguments, and TLM port rules.

## Prerequisites

### Embedded C
- Basic knowledge of C programming
- A text editor or IDE (VS Code, STM32CubeIDE, Keil, IAR)
- An ARM cross-compiler (arm-none-eabi-gcc) for compiling examples
- A development board (optional, but recommended for hands-on practice)

### UVM
- Knowledge of SystemVerilog (classes, interfaces, constraints, randomization)
- A SystemVerilog simulator with UVM support (Synopsys VCS, Cadence Xcelium, Siemens Questa, or Aldec Riviera-PRO)
- UVM library (typically bundled with the simulator, or available from Accellera)
