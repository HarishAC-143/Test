# Embedded Systems & Verification Guides

Comprehensive tutorials covering Embedded C programming and UVM verification methodology, with practical, annotated examples.

## Contents

### Tutorial Guides

**[`embedded-c-programming-guide.md`](embedded-c-programming-guide.md)** — Full Embedded C tutorial covering 21 topics:

**[`uvm-config-db-and-factory-guide.md`](uvm-config-db-and-factory-guide.md)** — Deep-dive into UVM's config_db and factory mechanisms (18 topics)

### Embedded C Topics

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

#### Embedded C Examples

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

#### UVM Verification Examples

| File | Description | Key Concepts |
|---|---|---|
| [`12_uvm_config_db.sv`](examples/12_uvm_config_db.sv) | APB testbench with config_db | Virtual interfaces, config objects, scoping, precedence |
| [`13_uvm_factory.sv`](examples/13_uvm_factory.sv) | Factory registration and overrides | Type/instance overrides, override chaining, polymorphism |
| [`14_uvm_config_db_factory_combined.sv`](examples/14_uvm_config_db_factory_combined.sv) | SPI testbench using both mechanisms | Test customization, conditional builds, full UVM flow |

## Target Platform

The examples use STM32-style (ARM Cortex-M) register definitions. The concepts and patterns apply broadly to any embedded microcontroller, including:

- STM32 (F1/F4/L4/H7 series)
- NXP LPC / i.MX RT
- TI MSP432 / TM4C
- Microchip SAM (Cortex-M based)
- Nordic nRF52 series

## How to Use

1. **Read the guide** — Start with [`embedded-c-programming-guide.md`](embedded-c-programming-guide.md) for conceptual understanding.
2. **Study the examples** — Each file in `examples/` is self-contained with detailed comments.
3. **Adapt to your platform** — Replace register addresses and peripheral definitions with those from your MCU's reference manual or vendor HAL.

## Prerequisites

- Basic knowledge of C programming
- A text editor or IDE (VS Code, STM32CubeIDE, Keil, IAR)
- An ARM cross-compiler (arm-none-eabi-gcc) for compiling examples
- A development board (optional, but recommended for hands-on practice)
