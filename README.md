# VLSI & Embedded Engineering Tutorials

A collection of comprehensive tutorials covering Embedded C programming and SystemVerilog/UVM verification, with practical, runnable examples.

---

## Tutorials

### 1. Embedded C Programming Guide

**[`embedded-c-programming-guide.md`](embedded-c-programming-guide.md)** — Full tutorial covering 21 topics from GPIO drivers to RTOS fundamentals, targeting ARM Cortex-M microcontrollers.

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

**Practical Examples** in [`examples/`](examples/):

| File | Description |
|---|---|
| [`01_gpio_driver.c`](examples/01_gpio_driver.c) | GPIO driver with button debounce |
| [`02_timer_driver.c`](examples/02_timer_driver.c) | Timer driver with PWM and input capture |
| [`03_uart_driver.c`](examples/03_uart_driver.c) | Polled UART with CLI interface |
| [`04_uart_ring_buffer.c`](examples/04_uart_ring_buffer.c) | Interrupt-driven UART with ring buffer |
| [`05_adc_driver.c`](examples/05_adc_driver.c) | ADC with averaging and watchdog |
| [`06_spi_driver.c`](examples/06_spi_driver.c) | SPI master with Flash/sensor/DAC |
| [`07_i2c_driver.c`](examples/07_i2c_driver.c) | I2C master with multiple sensors |
| [`08_dma_driver.c`](examples/08_dma_driver.c) | DMA for UART TX and ADC sampling |
| [`09_state_machine.c`](examples/09_state_machine.c) | FSM patterns (switch, table-driven) |
| [`10_rtos_tasks.c`](examples/10_rtos_tasks.c) | FreeRTOS multitasking system |
| [`11_memory_pool.c`](examples/11_memory_pool.c) | Fixed-block memory allocator |

---

### 2. SystemVerilog Classes & UVM Internals Guide

**[`systemverilog-uvm-classes-guide.md`](systemverilog-uvm-classes-guide.md)** — Deep-dive tutorial covering SystemVerilog object-oriented programming and the internal architecture of the UVM library, organized in three parts with 33 sections.

**Part I — SystemVerilog Class Fundamentals**

| # | Topic | Key Concepts |
|---|---|---|
| 1 | What is a Class? | Class vs module, dynamic allocation |
| 2 | Properties and Methods | Data members, functions, tasks, extern |
| 3 | Object Lifetime | `new`, handles, `null`, garbage collection |
| 4 | The `this` Keyword | Self-reference, shadowing |
| 5 | Encapsulation | `local`, `protected`, access control |
| 6 | Static Members | Shared state, class-level methods |
| 7 | Inheritance | `extends`, `super`, constructor chaining |
| 8 | Polymorphism | `virtual` methods, dynamic dispatch, `$cast` |
| 9 | Abstract Classes | `virtual class`, `pure virtual` methods |
| 10 | Parameterized Classes | Type parameters, generic containers |
| 11 | Copy and Clone | Shallow vs deep copy, clone patterns |
| 12 | Randomization | `rand`/`randc`, constraints, distributions |
| 13 | Typedef and Forward Declarations | Circular references, type aliases |
| 14 | Packages | Class organization, scope resolution |
| 15 | Virtual Interfaces | Connecting classes to RTL modules |

**Part II — UVM Class Hierarchy and Architecture**

| # | Topic | Key Concepts |
|---|---|---|
| 16 | UVM Class Tree | Full hierarchy overview |
| 17 | `uvm_void` | Root of all UVM classes |
| 18 | `uvm_object` | do_copy, do_compare, do_print, do_pack |
| 19 | `uvm_sequence_item` | Transaction timing, sequencer awareness |
| 20 | `uvm_component` | Hierarchy, phases, factory |
| 21 | UVM Phases | Build, connect, run, cleanup phase flow |
| 22 | UVM Factory | Registration, creation, type/instance overrides |
| 23 | `uvm_config_db` | Configuration database, set/get, wildcards |
| 24 | TLM Communication | Analysis ports, FIFOs, subscribers |
| 25 | Driver and Monitor | `seq_item_port`, signal observation |
| 26 | Sequencer and Sequences | `body()`, `start_item`/`finish_item`, virtual sequences |
| 27 | Agent, Env, Test | Testbench architecture layers |
| 28 | Scoreboard | Comparators, result checking |
| 29 | UVM Reporting | Severity, verbosity, report control |
| 30 | Register Abstraction Layer | `uvm_reg`, `uvm_reg_block`, front/back-door access |
| 31 | Field Macros vs Do-Methods | Trade-offs, production recommendations |

**Part III — Putting It All Together**

| # | Topic |
|---|---|
| 32 | Complete UVM Testbench Walk-through |
| 33 | Best Practices and Common Pitfalls |

**Practical Examples** in [`uvm_examples/`](uvm_examples/):

| File | Description | Key Concepts |
|---|---|---|
| [`01_sv_class_basics.sv`](uvm_examples/01_sv_class_basics.sv) | Class basics, constructors, static members | `new`, handles, `this`, `static` |
| [`02_sv_inheritance_polymorphism.sv`](uvm_examples/02_sv_inheritance_polymorphism.sv) | Inheritance, polymorphism, abstract classes | `extends`, `virtual`, `$cast`, `pure virtual` |
| [`03_sv_parameterized_classes.sv`](uvm_examples/03_sv_parameterized_classes.sv) | Generic classes and constrained randomization | Type parameters, `rand`, constraints, distributions |
| [`04_sv_interfaces_and_classes.sv`](uvm_examples/04_sv_interfaces_and_classes.sv) | Virtual interfaces and encapsulation | `virtual interface`, `local`, `protected`, forward declarations |
| [`05_uvm_object_fundamentals.sv`](uvm_examples/05_uvm_object_fundamentals.sv) | UVM object do-methods | `do_copy`, `do_compare`, `do_print`, `do_pack` |
| [`06_uvm_factory_and_overrides.sv`](uvm_examples/06_uvm_factory_and_overrides.sv) | UVM factory and type overrides | `type_id::create`, `set_type_override`, `set_inst_override` |
| [`07_uvm_sequences_and_sequencer.sv`](uvm_examples/07_uvm_sequences_and_sequencer.sv) | Sequences, sequencer, driver communication | `body()`, `start_item`/`finish_item`, hierarchical sequences |
| [`08_uvm_config_db_and_phases.sv`](uvm_examples/08_uvm_config_db_and_phases.sv) | Configuration database and phase execution | `uvm_config_db`, build/connect/run/report phases |
| [`09_uvm_tlm_communication.sv`](uvm_examples/09_uvm_tlm_communication.sv) | TLM ports, analysis FIFOs, scoreboard | `uvm_analysis_port`, `uvm_subscriber`, `uvm_tlm_analysis_fifo` |
| [`10_uvm_complete_testbench.sv`](uvm_examples/10_uvm_complete_testbench.sv) | Complete APB slave testbench | Full agent, scoreboard, coverage, multiple tests |
| [`11_uvm_register_model.sv`](uvm_examples/11_uvm_register_model.sv) | UVM Register Abstraction Layer | `uvm_reg`, `uvm_reg_block`, `uvm_reg_map`, set/get/predict |

---

## How to Use

### Embedded C Examples

1. Read [`embedded-c-programming-guide.md`](embedded-c-programming-guide.md) for conceptual understanding
2. Study annotated source files in [`examples/`](examples/)
3. Adapt register addresses for your target MCU

### SystemVerilog/UVM Examples

1. Read [`systemverilog-uvm-classes-guide.md`](systemverilog-uvm-classes-guide.md) for the full tutorial
2. Study the progressive examples in [`uvm_examples/`](uvm_examples/) (numbered 01–11)
3. Run with any SystemVerilog simulator supporting UVM (e.g., Synopsys VCS, Cadence Xcelium, Mentor Questa)

```bash
# Example: run the complete APB testbench with VCS
vcs -sverilog -ntb_opts uvm uvm_examples/10_uvm_complete_testbench.sv +UVM_TESTNAME=apb_wr_rd_test
./simv

# Example: run with Questa
vlog -sv uvm_examples/10_uvm_complete_testbench.sv
vsim -c tb_top +UVM_TESTNAME=apb_wr_rd_test -do "run -all"
```

## Prerequisites

### For Embedded C
- Basic knowledge of C programming
- ARM cross-compiler (arm-none-eabi-gcc) for compiling examples
- A development board (optional)

### For SystemVerilog/UVM
- Understanding of digital logic and Verilog basics
- A SystemVerilog simulator with UVM support (VCS, Xcelium, Questa, or Vivado Simulator)
- UVM 1.2 or UVM IEEE 1800.2 library (included with most commercial simulators)
