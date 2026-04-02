# Embedded Systems Programming Guides

Comprehensive tutorials covering Embedded C programming and FreeRTOS, with practical, annotated examples targeting ARM Cortex-M microcontrollers.

---

## Guides

### 1. Embedded C Programming Guide

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

### 2. FreeRTOS Comprehensive Guide

**[`freertos-comprehensive-guide.md`](freertos-comprehensive-guide.md)** — Deep-dive tutorial covering 18 topics with kernel internals:

| # | Topic | Level |
|---|---|---|
| 1 | Introduction to FreeRTOS | Beginner |
| 2 | Architecture and Kernel Internals | Intermediate |
| 3 | FreeRTOS Configuration (FreeRTOSConfig.h) | Beginner |
| 4 | Task Management | Beginner |
| 5 | The Scheduler: Internals and Algorithms | Intermediate |
| 6 | Queue Management | Intermediate |
| 7 | Semaphores | Intermediate |
| 8 | Mutexes and Priority Inheritance | Intermediate |
| 9 | Event Groups | Intermediate |
| 10 | Software Timers | Intermediate |
| 11 | Task Notifications | Intermediate |
| 12 | Stream Buffers and Message Buffers | Advanced |
| 13 | Memory Management | Advanced |
| 14 | Interrupt Management | Advanced |
| 15 | Co-routines (Legacy) | Advanced |
| 16 | Debugging, Tracing, and Runtime Statistics | Advanced |
| 17 | Common Pitfalls and Best Practices | All Levels |
| 18 | API Reference Summary | All Levels |

---

## Practical Examples

### Embedded C Examples

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

### FreeRTOS Examples

Complete, annotated source files in the [`freertos-examples/`](freertos-examples/) directory:

| File | Description | Key Concepts |
|---|---|---|
| [`01_task_basics.c`](freertos-examples/01_task_basics.c) | Task creation, lifecycle, and scheduling | Dynamic/static creation, priorities, delay, suspend/resume, stack monitoring |
| [`02_queues.c`](freertos-examples/02_queues.c) | Queue-based inter-task communication | FIFO, LIFO, mailbox, ISR queues, queue sets, pointer queues |
| [`03_semaphores.c`](freertos-examples/03_semaphores.c) | Binary and counting semaphores | Deferred ISR, event counting, resource pools, gatekeeper pattern |
| [`04_mutexes.c`](freertos-examples/04_mutexes.c) | Mutexes and priority inheritance | Standard mutex, recursive mutex, deadlock avoidance, holder queries |
| [`05_event_groups.c`](freertos-examples/05_event_groups.c) | Event group synchronization | AND/OR wait, barrier sync, ISR events, bit clearing |
| [`06_software_timers.c`](freertos-examples/06_software_timers.c) | Software timer management | One-shot, auto-reload, timer ID, dynamic period, pending function calls |
| [`07_task_notifications.c`](freertos-examples/07_task_notifications.c) | Lightweight task notifications | Binary/counting sem replacement, event bits, mailbox, indexed notifications |
| [`08_memory_management.c`](freertos-examples/08_memory_management.c) | Memory management strategies | Heap monitoring, memory pools, static allocation, heap_5 multi-region |
| [`09_stream_message_buffers.c`](freertos-examples/09_stream_message_buffers.c) | Stream and message buffers | Byte streams, trigger levels, discrete messages, ISR data transfer |
| [`10_iot_sensor_hub.c`](freertos-examples/10_iot_sensor_hub.c) | Complete IoT sensor hub project | All primitives combined: tasks, queues, mutex, events, timers, notifications |

---

## Target Platform

The examples use STM32-style (ARM Cortex-M) register definitions. The concepts and patterns apply broadly to any embedded microcontroller, including:

- STM32 (F1/F4/L4/H7 series)
- NXP LPC / i.MX RT
- TI MSP432 / TM4C
- Microchip SAM (Cortex-M based)
- Nordic nRF52 series
- ESP32 (Xtensa, uses FreeRTOS natively)

## How to Use

1. **Read the guides** — Start with [`embedded-c-programming-guide.md`](embedded-c-programming-guide.md) for hardware fundamentals, then [`freertos-comprehensive-guide.md`](freertos-comprehensive-guide.md) for RTOS concepts.
2. **Study the examples** — Each file in `examples/` and `freertos-examples/` is self-contained with detailed comments explaining every API call and internal mechanism.
3. **Adapt to your platform** — Replace register addresses and peripheral definitions with those from your MCU's reference manual or vendor HAL.

## Prerequisites

- Basic knowledge of C programming
- A text editor or IDE (VS Code, STM32CubeIDE, Keil, IAR)
- An ARM cross-compiler (arm-none-eabi-gcc) for compiling examples
- FreeRTOS source code (downloadable from [freertos.org](https://www.freertos.org))
- A development board (optional, but recommended for hands-on practice)
