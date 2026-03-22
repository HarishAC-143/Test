# Engineering Tutorials Repository

A collection of comprehensive tutorials covering Embedded C programming and SystemVerilog/UVM verification, with practical, runnable examples.

---

## Tutorial Guides

### 1. Embedded C Programming

**[`embedded-c-programming-guide.md`](embedded-c-programming-guide.md)** — Full tutorial covering 21 topics from basics to advanced embedded development targeting ARM Cortex-M microcontrollers.

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

### 2. SystemVerilog Classes and UVM

**[`systemverilog-uvm-classes-tutorial.md`](systemverilog-uvm-classes-tutorial.md)** — Deep-dive tutorial covering object-oriented programming in SystemVerilog and the Universal Verification Methodology (UVM), with 37 sections:

**Part 1 — SystemVerilog Classes:**

| # | Topic | Level |
|---|---|---|
| 1 | Introduction to OOP in SystemVerilog | Beginner |
| 2 | Class Basics | Beginner |
| 3 | The Constructor — `new()` | Beginner |
| 4 | Object Handles and `null` | Beginner |
| 5 | Encapsulation — `local` and `protected` | Beginner |
| 6 | `this` Keyword | Beginner |
| 7 | Static Members | Intermediate |
| 8 | Inheritance | Intermediate |
| 9 | Polymorphism and Virtual Methods | Intermediate |
| 10 | Abstract Classes and Pure Virtual Methods | Intermediate |
| 11 | Parameterized (Generic) Classes | Intermediate |
| 12 | Shallow Copy vs. Deep Copy | Intermediate |
| 13 | Class Scope Resolution Operator `::` | Intermediate |
| 14 | Forward Declarations and Typedef | Intermediate |
| 15 | Randomization in Classes | Advanced |
| 16 | Interfaces in Classes and Virtual Interfaces | Advanced |

**Part 2 — UVM Class Architecture:**

| # | Topic | Level |
|---|---|---|
| 17 | UVM Overview and Philosophy | Beginner |
| 18 | UVM Class Hierarchy | Beginner |
| 19 | `uvm_void` and `uvm_object` | Intermediate |
| 20 | `uvm_object` Core Methods (copy, clone, compare, print, pack/unpack) | Intermediate |
| 21 | `uvm_component` — The Backbone of the Testbench | Intermediate |
| 22 | UVM Phases In Depth | Intermediate |
| 23 | `uvm_transaction` and `uvm_sequence_item` | Intermediate |
| 24 | `uvm_sequence` | Intermediate |
| 25 | `uvm_driver` | Intermediate |
| 26 | `uvm_monitor` | Intermediate |
| 27 | `uvm_agent` | Intermediate |
| 28 | `uvm_scoreboard` | Intermediate |
| 29 | `uvm_env` | Intermediate |
| 30 | `uvm_test` | Intermediate |
| 31 | UVM Factory — Create, Override, Substitute | Advanced |
| 32 | UVM Configuration Database (`uvm_config_db`) | Advanced |
| 33 | UVM TLM (Transaction-Level Modeling) | Advanced |
| 34 | Field Macros and Automation | Advanced |
| 35 | UVM Reporting and Messaging | Advanced |
| 36 | UVM Register Layer (`uvm_reg`) | Advanced |
| 37 | Putting It All Together — Full UVM Testbench | Advanced |

---

## Practical Examples

Complete, annotated source files in the [`examples/`](examples/) directory:

### Embedded C Examples

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

### SystemVerilog / UVM Examples

| File | Description | Key Concepts |
|---|---|---|
| [`12_sv_class_basics.sv`](examples/12_sv_class_basics.sv) | Class fundamentals with testbench | Properties, methods, constructors, encapsulation, static members, handles |
| [`13_sv_inheritance_polymorphism.sv`](examples/13_sv_inheritance_polymorphism.sv) | Inheritance and polymorphism | extends, super, virtual methods, abstract classes, $cast |
| [`14_sv_parameterized_classes.sv`](examples/14_sv_parameterized_classes.sv) | Generic classes and copy semantics | Parameterized Stack/FIFO, shallow vs deep copy, forward declarations |
| [`15_sv_randomization.sv`](examples/15_sv_randomization.sv) | Constrained-random verification | rand/randc, constraints, distributions, pre/post_randomize, constraint layering |
| [`16_uvm_transaction_sequence.sv`](examples/16_uvm_transaction_sequence.sv) | Complete UVM testbench for APB slave | Transaction, sequences, driver, monitor, agent, scoreboard, env, test |
| [`17_uvm_register_model.sv`](examples/17_uvm_register_model.sv) | UVM register abstraction layer | uvm_reg_field, uvm_reg, uvm_reg_block, uvm_reg_map, register sequences |

---

## Target Platforms

### Embedded C
The C examples use STM32-style (ARM Cortex-M) register definitions. The concepts apply to any embedded MCU (STM32, NXP LPC, TI MSP432, Nordic nRF52, etc.).

### SystemVerilog / UVM
The SystemVerilog examples (12–15) are self-contained and compile with any IEEE 1800-compliant simulator. The UVM examples (16–17) require a UVM 1.2+ library (included with most commercial simulators: Synopsys VCS, Cadence Xcelium, Siemens Questa).

## How to Use

1. **Read the guides** — Start with the tutorial markdown files for conceptual understanding.
2. **Study the examples** — Each file in `examples/` is self-contained with detailed comments.
3. **Run and experiment** — Modify constraints, add components, and observe behavior.

## Prerequisites

### For Embedded C
- Basic knowledge of C programming
- An ARM cross-compiler (arm-none-eabi-gcc) for compiling examples
- A development board (optional)

### For SystemVerilog / UVM
- Basic knowledge of digital logic and Verilog
- A SystemVerilog simulator (Synopsys VCS, Cadence Xcelium, Siemens Questa, or Verilator for non-UVM examples)
- UVM library (bundled with commercial simulators)
