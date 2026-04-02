# Embedded Systems Programming Guides

Comprehensive tutorials covering Embedded C and FreeRTOS from fundamentals to advanced internals, with practical, annotated examples targeting ARM Cortex-M microcontrollers.

## Contents

### Guide 1: Embedded C Programming

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

---

### Guide 2: FreeRTOS Comprehensive Guide

**[`freertos-comprehensive-guide.md`](freertos-comprehensive-guide.md)** — Deep-dive tutorial covering 18 topics:

| # | Topic | Level |
|---|---|---|
| 1 | Introduction to FreeRTOS | Beginner |
| 2 | Architecture and Kernel Internals | Intermediate |
| 3 | Task Management | Beginner |
| 4 | The Scheduler: How It Works Internally | Intermediate |
| 5 | Queues | Intermediate |
| 6 | Semaphores | Intermediate |
| 7 | Mutexes | Intermediate |
| 8 | Event Groups | Intermediate |
| 9 | Software Timers | Intermediate |
| 10 | Task Notifications | Intermediate |
| 11 | Stream Buffers and Message Buffers | Intermediate |
| 12 | Memory Management | Advanced |
| 13 | Interrupt Management and Deferred Processing | Advanced |
| 14 | Tick Hook, Idle Hook, and Stack Overflow Detection | Intermediate |
| 15 | FreeRTOSConfig.h — Kernel Configuration Reference | All Levels |
| 16 | Common Pitfalls and Debugging | All Levels |
| 17 | Design Patterns and Best Practices | Advanced |
| 18 | Quick API Reference Card | All Levels |

### FreeRTOS Examples

Complete, annotated source files in the [`freertos-examples/`](freertos-examples/) directory:

| File | Description | Key Concepts |
|---|---|---|
| [`01_basic_tasks.c`](freertos-examples/01_basic_tasks.c) | Task creation, priorities, and scheduling | `xTaskCreate`, `xTaskCreateStatic`, `vTaskDelay`, `vTaskDelayUntil`, preemption, suspension |
| [`02_queues.c`](freertos-examples/02_queues.c) | Queue-based inter-task communication | `xQueueCreate`, send/receive, `xQueueOverwrite`, `xQueuePeek`, queue sets, `FromISR` |
| [`03_semaphores_mutexes.c`](freertos-examples/03_semaphores_mutexes.c) | Semaphores and mutexes | Binary/counting semaphores, mutexes, priority inheritance, recursive mutex, gatekeeper pattern |
| [`04_event_groups.c`](freertos-examples/04_event_groups.c) | Event-driven synchronization | Bit flags, wait for any/all, `xEventGroupSync` barrier, ISR set bits |
| [`05_software_timers.c`](freertos-examples/05_software_timers.c) | Periodic and one-shot timers | Timer daemon, callbacks, `xTimerReset`, `xTimerChangePeriod`, shared callbacks via timer ID |
| [`06_task_notifications.c`](freertos-examples/06_task_notifications.c) | Lightweight task notifications | Binary/counting sem replacement, event bits, mailbox, `eSetValueWithOverwrite` |
| [`07_memory_management.c`](freertos-examples/07_memory_management.c) | Heap usage and stack monitoring | `pvPortMalloc`, `vPortGetHeapStats`, stack HWM, static allocation, fixed-block memory pool |
| [`08_isr_deferred.c`](freertos-examples/08_isr_deferred.c) | Interrupt handling and deferred processing | `FromISR` functions, `portYIELD_FROM_ISR`, centralized ISR dispatcher, critical sections |
| [`09_stream_message_buffers.c`](freertos-examples/09_stream_message_buffers.c) | Stream and message buffer communication | UART stream, GPS buffering, variable-length messages, trigger levels, static allocation |
| [`10_realworld_application.c`](freertos-examples/10_realworld_application.c) | Complete IoT sensor node | Multi-task architecture, all primitives combined: queues, mutexes, events, timers, notifications, message buffers |

---

## Target Platform

The examples use STM32-style (ARM Cortex-M) register definitions. The concepts and patterns apply broadly to any embedded microcontroller, including:

- STM32 (F1/F4/L4/H7 series)
- NXP LPC / i.MX RT
- TI MSP432 / TM4C
- Microchip SAM (Cortex-M based)
- Nordic nRF52 series

## How to Use

1. **Embedded C** — Start with [`embedded-c-programming-guide.md`](embedded-c-programming-guide.md) for bare-metal programming concepts. Study examples in `examples/`.
2. **FreeRTOS** — Read [`freertos-comprehensive-guide.md`](freertos-comprehensive-guide.md) for RTOS concepts and internal mechanics. Study examples in `freertos-examples/`.
3. **Adapt to your platform** — Replace register addresses and peripheral definitions with those from your MCU's reference manual or vendor HAL.

## Prerequisites

- Basic knowledge of C programming
- A text editor or IDE (VS Code, STM32CubeIDE, Keil, IAR)
- An ARM cross-compiler (arm-none-eabi-gcc) for compiling examples
- FreeRTOS source code (download from [freertos.org](https://www.freertos.org/))
- A development board (optional, but recommended for hands-on practice)
