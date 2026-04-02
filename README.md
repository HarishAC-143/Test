# Embedded Systems Programming Guides

Comprehensive tutorials covering Embedded C programming and FreeRTOS, with practical, runnable examples targeting ARM Cortex-M microcontrollers.

## Contents

### Tutorial Guides

#### 1. Embedded C Programming

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

#### 2. FreeRTOS Comprehensive Guide

**[`freertos-guide.md`](freertos-guide.md)** — Deep-dive tutorial covering 17 topics with kernel internals:

| # | Topic | Level |
|---|---|---|
| 1 | Introduction to FreeRTOS | Beginner |
| 2 | Architecture and Kernel Internals | Intermediate |
| 3 | Task Management | Beginner |
| 4 | The FreeRTOS Scheduler | Intermediate |
| 5 | Queues | Beginner |
| 6 | Semaphores | Intermediate |
| 7 | Mutexes | Intermediate |
| 8 | Event Groups | Intermediate |
| 9 | Software Timers | Intermediate |
| 10 | Task Notifications | Intermediate |
| 11 | Stream Buffers and Message Buffers | Intermediate |
| 12 | Memory Management | Advanced |
| 13 | Interrupt Management | Advanced |
| 14 | Low-Power Support (Tickless Idle) | Advanced |
| 15 | Debugging, Tracing, and Best Practices | Advanced |
| 16 | FreeRTOS Configuration Reference | Reference |
| 17 | Common Pitfalls and How to Avoid Them | All Levels |

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

#### FreeRTOS Examples

| File | Description | Key Concepts |
|---|---|---|
| [`12_freertos_tasks.c`](examples/12_freertos_tasks.c) | Task creation, priorities, delays, stack monitoring | `xTaskCreate`, `vTaskDelay`, `vTaskDelayUntil`, `vTaskSuspend`, `vTaskResume`, `uxTaskGetStackHighWaterMark` |
| [`13_freertos_queues.c`](examples/13_freertos_queues.c) | Multi-producer queues, mailbox, queue sets, ISR queues | `xQueueCreate`, `xQueueSend`, `xQueueReceive`, `xQueueOverwrite`, `xQueueCreateSet` |
| [`14_freertos_semaphores.c`](examples/14_freertos_semaphores.c) | Binary/counting semaphores, mutexes, priority inheritance | `xSemaphoreCreateBinary`, `xSemaphoreCreateMutex`, `xSemaphoreCreateRecursiveMutex`, gatekeeper pattern |
| [`15_freertos_timers_events.c`](examples/15_freertos_timers_events.c) | Software timers, event groups, barrier sync | `xTimerCreate`, `xEventGroupCreate`, `xEventGroupWaitBits`, `xEventGroupSync` |
| [`16_freertos_notifications.c`](examples/16_freertos_notifications.c) | Task notifications, stream buffers, message buffers | `xTaskNotify`, `ulTaskNotifyTake`, `xStreamBufferCreate`, `xMessageBufferCreate` |
| [`17_freertos_iot_app.c`](examples/17_freertos_iot_app.c) | Complete IoT sensor monitoring application | All major FreeRTOS primitives in a production-like architecture |

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
