# VLSI / Embedded Programming Tutorials

Comprehensive tutorials covering Embedded C programming and SystemVerilog/UVM verification methodology, with practical, runnable examples.

---

## SystemVerilog Classes & UVM Tutorial

**[`systemverilog-uvm-classes-guide.md`](systemverilog-uvm-classes-guide.md)** — In-depth guide covering 37 topics across three parts:

### Part 1 — SystemVerilog Object-Oriented Programming

| # | Topic | Level |
|---|---|---|
| 1 | Classes: The Basics | Beginner |
| 2 | Properties and Methods | Beginner |
| 3 | Constructors and Object Lifetime | Beginner |
| 4 | Encapsulation: `local` and `protected` | Beginner |
| 5 | Inheritance | Intermediate |
| 6 | Polymorphism and Virtual Methods | Intermediate |
| 7 | Abstract Classes and Pure Virtual Methods | Intermediate |
| 8 | Parameterized (Generic) Classes | Intermediate |
| 9 | Static Members | Intermediate |
| 10 | Copying Objects: Shallow vs Deep Copy | Intermediate |
| 11 | Typedef, Forward Declarations, and Scope Resolution | Intermediate |
| 12 | Interface Classes | Advanced |
| 13 | Randomization and Constraints | Advanced |
| 14 | Interprocess Communication: Mailboxes and Semaphores | Advanced |

### Part 2 — UVM Class Hierarchy and Internal Functions

| # | Topic | Level |
|---|---|---|
| 15 | UVM Overview and Architecture | Beginner |
| 16 | `uvm_void` and `uvm_object` — The Foundation | Beginner |
| 17 | `uvm_object` Core Methods (copy, compare, print, pack, unpack, record) | Intermediate |
| 18 | `uvm_component` — The Structural Backbone | Intermediate |
| 19 | UVM Phases and the Phase Mechanism | Intermediate |
| 20 | `uvm_transaction` and `uvm_sequence_item` | Intermediate |
| 21 | `uvm_sequence` and `uvm_sequencer` | Intermediate |
| 22 | `uvm_driver` | Intermediate |
| 23 | `uvm_monitor` | Intermediate |
| 24 | `uvm_agent` | Intermediate |
| 25 | `uvm_scoreboard` | Intermediate |
| 26 | `uvm_env` | Intermediate |
| 27 | `uvm_test` | Intermediate |

### Part 3 — UVM Infrastructure and Advanced Topics

| # | Topic | Level |
|---|---|---|
| 28 | The UVM Factory | Advanced |
| 29 | Configuration Database (`uvm_config_db`) | Advanced |
| 30 | Field Automation Macros (`uvm_field_*`) | Advanced |
| 31 | TLM Ports and Communication | Advanced |
| 32 | UVM Reporting and Messaging | Advanced |
| 33 | Objection Mechanism | Advanced |
| 34 | UVM Register Layer (RAL) Overview | Advanced |
| 35 | Virtual Sequences and Virtual Sequencers | Advanced |
| 36 | Coverage-Driven Verification with UVM | Advanced |
| 37 | Complete UVM Testbench Example | Advanced |

### SystemVerilog / UVM Examples

Complete, annotated source files in [`examples/sv_uvm/`](examples/sv_uvm/):

| File | Description | Key Concepts |
|---|---|---|
| [`01_sv_class_basics.sv`](examples/sv_uvm/01_sv_class_basics.sv) | Class fundamentals | Handles, constructors, properties, methods, shallow/deep copy |
| [`02_sv_inheritance_polymorphism.sv`](examples/sv_uvm/02_sv_inheritance_polymorphism.sv) | Inheritance and polymorphism | `extends`, `super`, `virtual`, `$cast`, abstract classes, interface classes |
| [`03_sv_randomization_constraints.sv`](examples/sv_uvm/03_sv_randomization_constraints.sv) | Randomization and constraints | `rand`/`randc`, distributions, implications, `constraint_mode`, `rand_mode` |
| [`04_sv_parameterized_classes.sv`](examples/sv_uvm/04_sv_parameterized_classes.sv) | Generic classes and IPC | Parameterized types, mailbox, semaphore, producer-consumer |
| [`05_uvm_object_methods.sv`](examples/sv_uvm/05_uvm_object_methods.sv) | UVM object core methods | `do_copy`, `do_compare`, `do_print`, `do_pack`/`do_unpack`, clone, factory |
| [`06_uvm_factory_config.sv`](examples/sv_uvm/06_uvm_factory_config.sv) | Factory and config_db | Type/instance overrides, `uvm_config_db`, configuration objects |
| [`07_uvm_sequence_driver.sv`](examples/sv_uvm/07_uvm_sequence_driver.sv) | Sequences and driver | Sequence nesting, `start_item`/`finish_item`, driver get/item_done |
| [`08_uvm_complete_testbench.sv`](examples/sv_uvm/08_uvm_complete_testbench.sv) | Full UVM testbench | ALU DUT with interface, driver, monitor, scoreboard, coverage, multiple tests |

---

## Embedded C Programming Guide

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

Complete, annotated source files in [`examples/`](examples/):

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

## How to Use

1. **Read the guides** — Start with the main tutorial markdown files for conceptual understanding.
2. **Study the examples** — Each file in `examples/` is self-contained with detailed annotations.
3. **Adapt to your tools** — For SystemVerilog/UVM examples, use your EDA simulator (VCS, Questa, Xcelium, etc.).

## Prerequisites

- For SystemVerilog/UVM: A SystemVerilog simulator with UVM library support
- For Embedded C: A C compiler and optionally an ARM cross-compiler for hardware targets
