# Hardware Engineering Tutorials

Comprehensive tutorials covering Embedded C programming and SystemVerilog/UVM verification, with practical, annotated examples.

---

## SystemVerilog Classes & UVM Tutorial

**[`systemverilog-uvm-tutorial.md`](systemverilog-uvm-tutorial.md)** — Full tutorial covering 35 topics across three parts:

### Part I — SystemVerilog Classes

| # | Topic | Level |
|---|---|---|
| 1 | Why Classes in Hardware Verification? | Beginner |
| 2 | Class Fundamentals | Beginner |
| 3 | The Constructor — `new()` | Beginner |
| 4 | Properties and Methods | Beginner |
| 5 | Access Control — `local` and `protected` | Beginner |
| 6 | Inheritance | Intermediate |
| 7 | Polymorphism and Virtual Methods | Intermediate |
| 8 | Abstract Classes and Pure Virtual Methods | Intermediate |
| 9 | Parameterized (Generic) Classes | Intermediate |
| 10 | Static Members | Intermediate |
| 11 | Copying Objects — Shallow vs Deep | Intermediate |
| 12 | Randomization and Constraints | Intermediate |
| 13 | Typedef, Forward Declarations, and Scope Resolution | Intermediate |
| 14 | Class Casting — `$cast` | Intermediate |

### Part II — UVM (Universal Verification Methodology)

| # | Topic | Level |
|---|---|---|
| 15 | Introduction to UVM | Beginner |
| 16 | UVM Class Hierarchy Overview | Beginner |
| 17 | `uvm_object` — The Root of Everything | Intermediate |
| 18 | `uvm_component` — Structural Backbone | Intermediate |
| 19 | UVM Phasing Mechanism | Intermediate |
| 20 | `uvm_transaction` and `uvm_sequence_item` | Intermediate |
| 21 | `uvm_sequence` — Stimulus Generation | Intermediate |
| 22 | `uvm_driver` — Driving the DUT | Intermediate |
| 23 | `uvm_sequencer` — Arbitration | Intermediate |
| 24 | `uvm_monitor` — Passive Observation | Intermediate |
| 25 | `uvm_agent` — Grouping Driver, Sequencer, Monitor | Intermediate |
| 26 | `uvm_scoreboard` — Checking Results | Intermediate |
| 27 | `uvm_env` — Top-Level Environment | Intermediate |
| 28 | `uvm_test` — Test Entry Point | Intermediate |
| 29 | The UVM Factory | Advanced |
| 30 | Configuration Database — `uvm_config_db` | Advanced |
| 31 | TLM Ports and Communication | Advanced |
| 32 | UVM Reporting and Messaging | Intermediate |
| 33 | Field Automation Macros — `uvm_field_*` | Advanced |
| 34 | Register Abstraction Layer (RAL) Overview | Advanced |

### Part III — Complete Example

| # | Topic | Level |
|---|---|---|
| 35 | Complete UVM Testbench Walkthrough | Advanced |

### SystemVerilog / UVM Examples

Complete, annotated source files in the [`examples/sv_uvm/`](examples/sv_uvm/) directory:

| File | Description | Key Concepts |
|---|---|---|
| [`01_sv_class_basics.sv`](examples/sv_uvm/01_sv_class_basics.sv) | Class fundamentals and access control | Constructor, `this`, `local`, `protected` |
| [`02_sv_inheritance_polymorphism.sv`](examples/sv_uvm/02_sv_inheritance_polymorphism.sv) | Inheritance, polymorphism, abstract classes | `extends`, `virtual`, `super`, `$cast` |
| [`03_sv_parameterized_classes.sv`](examples/sv_uvm/03_sv_parameterized_classes.sv) | Generics, static members, singleton | Parameterized classes, `static`, extern |
| [`04_sv_randomization.sv`](examples/sv_uvm/04_sv_randomization.sv) | Constrained-random verification | `rand`, `randc`, constraints, distributions |
| [`05_sv_copy_clone_compare.sv`](examples/sv_uvm/05_sv_copy_clone_compare.sv) | Object copying and comparison | Shallow vs deep copy, equality checks |
| [`06_uvm_object_methods.sv`](examples/sv_uvm/06_uvm_object_methods.sv) | UVM object hooks: copy, compare, print | `do_copy`, `do_compare`, `do_print`, `clone` |
| [`07_uvm_factory_config.sv`](examples/sv_uvm/07_uvm_factory_config.sv) | UVM factory and config database | Factory overrides, `uvm_config_db` |
| [`08_uvm_sequence_driver.sv`](examples/sv_uvm/08_uvm_sequence_driver.sv) | Sequences, sequencer, and driver flow | `start_item`/`finish_item`, layered sequences |
| [`09_uvm_agent_env.sv`](examples/sv_uvm/09_uvm_agent_env.sv) | Agent, environment, and scoreboard | Active/passive agent, analysis ports |
| [`10_uvm_tlm_analysis.sv`](examples/sv_uvm/10_uvm_tlm_analysis.sv) | TLM communication patterns | Analysis ports/imps, FIFO, broadcast |
| [`11_uvm_complete_testbench.sv`](examples/sv_uvm/11_uvm_complete_testbench.sv) | Full APB memory testbench | All UVM components, DUT, coverage |

---

## Embedded C Programming Guide

A comprehensive tutorial covering Embedded C programming from basics to advanced topics, with practical, runnable examples targeting ARM Cortex-M microcontrollers.

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
