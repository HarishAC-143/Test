# FPGA RTL Design with SystemVerilog — Comprehensive Tutorial

A complete, example-driven guide to digital design for FPGAs using SystemVerilog.
Every concept is paired with synthesizable RTL code you can simulate and deploy on
real hardware.

---

## Table of Contents

| # | Topic | Directory | Level |
|---|-------|-----------|-------|
| 01 | [Data Types, Operators & Module Anatomy](#01-basics) | `01_basics/` | Beginner |
| 02 | [Combinational Logic](#02-combinational-logic) | `02_combinational_logic/` | Beginner |
| 03 | [Sequential Logic](#03-sequential-logic) | `03_sequential_logic/` | Beginner |
| 04 | [Finite State Machines](#04-finite-state-machines) | `04_finite_state_machines/` | Intermediate |
| 05 | [Memories & FIFOs](#05-memories-and-fifos) | `05_memories_and_fifos/` | Intermediate |
| 06 | [Interfaces & Packages](#06-interfaces-and-packages) | `06_interfaces_and_packages/` | Intermediate |
| 07 | [Parameterized & Generate Designs](#07-parameterized-designs) | `07_parameterized_designs/` | Advanced |
| 08 | [SystemVerilog Assertions & Coverage](#08-assertions-and-coverage) | `08_assertions_and_coverage/` | Advanced |
| 09 | [Clock Domain Crossing](#09-clock-domain-crossing) | `09_clock_domain_crossing/` | Advanced |
| 10 | [Practical Projects](#10-practical-projects) | `10_practical_projects/` | All |
| 11 | [Testbenches & Verification](#11-testbenches) | `11_testbenches/` | All |
| 12 | [Synthesis & Implementation Guidelines](#12-synthesis-guidelines) | `12_synthesis_guidelines/` | Reference |

---

## Prerequisites

- Basic understanding of digital logic (gates, flip-flops, Boolean algebra)
- A SystemVerilog simulator — any of these work:
  - **Verilator** (free, open-source)
  - **Icarus Verilog** (free, open-source — partial SV support)
  - **Synopsys VCS**, **Cadence Xcelium**, **Siemens Questa** (commercial)
  - **Vivado Simulator** (free with Xilinx Vivado)
- Optional: FPGA development board (Xilinx, Intel/Altera, Lattice)

---

## How to Use This Tutorial

Each directory contains:
- A **README.md** explaining the concepts in depth
- One or more **`.sv`** source files with fully commented, synthesizable RTL
- Matching **`*_tb.sv`** testbench files where applicable

Simulate any example with Verilator:

```bash
verilator --binary -j 0 --timing -Wall module.sv module_tb.sv -o sim
./obj_dir/sim
```

Or with Icarus Verilog (where supported):

```bash
iverilog -g2012 -o sim module.sv module_tb.sv
vvp sim
```

---

## 01 — Basics

> **Directory:** [`01_basics/`](01_basics/)

Covers the foundational building blocks of every SystemVerilog design.

### Key Concepts

- **Modules** — the fundamental unit of hierarchy; every piece of hardware is a module.
- **Ports** — `input`, `output`, `inout` declarations with explicit direction and type.
- **Data types** — `logic`, `reg`, `wire`, `bit`; 4-state vs 2-state semantics.
- **Vectors and arrays** — packed (`logic [7:0]`) vs unpacked (`logic data [0:255]`).
- **Parameters and localparams** — compile-time constants for configurable designs.
- **Operators** — arithmetic, bitwise, logical, reduction, shift, concatenation, replication.
- **Continuous assignments** — `assign` for simple combinational connections.

### Why `logic` Instead of `reg`/`wire`?

SystemVerilog's `logic` type replaces the error-prone `reg`/`wire` distinction from
Verilog. A `logic` signal can be driven by either continuous assignments or procedural
blocks, eliminating an entire class of bugs.

```systemverilog
// Verilog-2001 style (avoid)
wire [7:0] a;
reg  [7:0] b;

// SystemVerilog style (preferred)
logic [7:0] a;
logic [7:0] b;
```

---

## 02 — Combinational Logic

> **Directory:** [`02_combinational_logic/`](02_combinational_logic/)

### Key Concepts

- **`always_comb`** — synthesizable combinational process; the simulator verifies
  that no latches are inferred.
- **`assign`** — continuous assignment for simple expressions.
- **Conditional operator** — `(cond) ? a : b` for inline muxing.
- **`case` / `unique case` / `priority case`** — structured decision logic;
  `unique` tells the tool all cases are mutually exclusive, enabling better optimization.
- **`casez` / `casex`** — wildcard matching for don't-care bits.

### Combinational Pitfalls

| Pitfall | Result | Fix |
|---------|--------|-----|
| Incomplete `if`/`case` | Latch inferred | Add `else`/`default` |
| Reading a signal you also write in `always_comb` | Combinational loop | Use separate signals |
| Missing sensitivity list items | Simulation mismatches | Use `always_comb` (auto-sensitivity) |

---

## 03 — Sequential Logic

> **Directory:** [`03_sequential_logic/`](03_sequential_logic/)

### Key Concepts

- **`always_ff`** — clocked sequential process with explicit edge sensitivity.
- **Synchronous vs asynchronous reset** — trade-offs for FPGA fabrics.
- **Blocking (`=`) vs non-blocking (`<=`)** — always use `<=` in `always_ff`.
- **Counters, shift registers, clock enables** — fundamental sequential patterns.
- **Pipeline registers** — adding stages to meet timing.

### Reset Styles

```systemverilog
// Synchronous reset (preferred for most FPGAs)
always_ff @(posedge clk) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// Asynchronous reset (needed when clock may not be running)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end
```

---

## 04 — Finite State Machines

> **Directory:** [`04_finite_state_machines/`](04_finite_state_machines/)

### Key Concepts

- **Mealy vs Moore** — output depends on state+input vs state only.
- **Enumerated types** — `typedef enum logic [N:0] {...} state_t;` for readable FSMs.
- **Two-process vs three-process** coding styles.
- **One-hot encoding** — efficient for FPGAs with abundant flip-flops.
- **Safe FSM design** — handling illegal states, default transitions.

### Recommended Two-Process Style

```systemverilog
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
} state_t;

state_t state_q, state_d;

always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) state_q <= IDLE;
    else        state_q <= state_d;

always_comb begin
    state_d = state_q; // default: hold
    unique case (state_q)
        IDLE: if (start) state_d = RUN;
        RUN:  if (done)  state_d = DONE;
        DONE:            state_d = IDLE;
        default:         state_d = IDLE;
    endcase
end
```

---

## 05 — Memories & FIFOs

> **Directory:** [`05_memories_and_fifos/`](05_memories_and_fifos/)

### Key Concepts

- **Inferred Block RAM** — coding patterns that map to FPGA BRAM primitives.
- **Single-port, simple dual-port, true dual-port** RAM templates.
- **Synchronous FIFO** — pointer-based design with full/empty flags.
- **Read-during-write behavior** — `READ_FIRST`, `WRITE_FIRST`, `NO_CHANGE`.
- **ROM inference** — using `initial` blocks or `$readmemh`.

---

## 06 — Interfaces & Packages

> **Directory:** [`06_interfaces_and_packages/`](06_interfaces_and_packages/)

### Key Concepts

- **`package`** — namespaced collections of types, parameters, and functions.
- **`interface`** — bundled signal groups with `modport` for directional control.
- **`import`** — bringing package items into scope.
- **Virtual interfaces** — for verification (not synthesizable).

### Why Interfaces?

Without interfaces, adding a signal to a bus means editing every module port list
in the hierarchy. Interfaces let you define the bus once and pass it through as a
single port.

---

## 07 — Parameterized Designs

> **Directory:** [`07_parameterized_designs/`](07_parameterized_designs/)

### Key Concepts

- **`parameter` / `localparam`** — module-level constants.
- **`generate` blocks** — `for`, `if`, `case` to conditionally instantiate hardware.
- **Type parameters** — `parameter type T = logic [7:0]`.
- **`$clog2`** — compute address widths from depths.
- **Design reuse** — building configurable IP blocks.

---

## 08 — SystemVerilog Assertions & Coverage

> **Directory:** [`08_assertions_and_coverage/`](08_assertions_and_coverage/)

### Key Concepts

- **Immediate assertions** — `assert`, `assume`, `cover` inside procedural blocks.
- **Concurrent assertions** — `assert property (...)` on clock edges.
- **Sequences and properties** — temporal patterns (`##1`, `|->`, `|=>`).
- **Functional coverage** — `covergroup`, `coverpoint`, `cross`.
- **Assertion-based verification** — finding bugs before they reach silicon.

---

## 09 — Clock Domain Crossing

> **Directory:** [`09_clock_domain_crossing/`](09_clock_domain_crossing/)

### Key Concepts

- **Metastability** — what happens when setup/hold is violated.
- **Two-flop synchronizer** — the simplest CDC technique for single-bit signals.
- **Gray-code pointers** — safe multi-bit CDC for asynchronous FIFOs.
- **Asynchronous FIFO** — full design with gray-code pointer synchronization.
- **Pulse synchronizer** — transferring single-cycle pulses across domains.
- **Handshake synchronizer** — for multi-bit data transfers.

---

## 10 — Practical Projects

> **Directory:** [`10_practical_projects/`](10_practical_projects/)

Complete, synthesizable designs with testbenches:

| Project | Directory | Description |
|---------|-----------|-------------|
| SPI Master | `spi_master/` | Full SPI Mode 0/1/2/3 master controller |
| UART Transceiver | `uart_transceiver/` | Configurable baud-rate UART TX & RX |
| AXI4-Lite Slave | `axi_lite_slave/` | Register bank with AXI4-Lite interface |
| Debouncer | `debouncer/` | Button debounce with edge detection |
| PWM Generator | `pwm_generator/` | N-bit PWM with configurable frequency |

---

## 11 — Testbenches

> **Directory:** [`11_testbenches/`](11_testbenches/)

### Key Concepts

- **`initial` blocks and `$finish`** — controlling simulation flow.
- **Clock and reset generation** — reusable patterns.
- **Tasks and functions** — encapsulating stimulus.
- **File I/O** — `$readmemh`, `$fwrite`, `$fopen` for data-driven tests.
- **Self-checking testbenches** — automatic pass/fail with assertions.
- **Waveform dumping** — `$dumpfile` / `$dumpvars` for VCD output.

---

## 12 — Synthesis Guidelines

> **Directory:** [`12_synthesis_guidelines/`](12_synthesis_guidelines/)

### Key Concepts

- **Synthesizable vs non-synthesizable** constructs.
- **Coding for timing** — pipeline stages, register balancing.
- **Coding for area** — resource sharing, mux optimization.
- **Clock enables vs gated clocks** — FPGA-safe clock management.
- **Timing constraints basics** — what the synthesizer needs to know.
- **Common synthesis warnings** and how to fix them.
- **Vendor-specific attributes** — Xilinx, Intel/Altera pragmas.

---

## Quick Reference

### SystemVerilog Type Hierarchy

```
          ┌─────────────┐
          │   4-state    │  Can be 0, 1, X, Z
          │  logic, reg  │
          │  integer     │
          └──────┬───────┘
                 │
          ┌──────┴───────┐
          │   2-state    │  Can only be 0, 1
          │  bit, byte   │
          │  shortint    │
          │  int, longint│
          └──────────────┘
```

### Operator Quick Reference

| Category | Operators |
|----------|-----------|
| Arithmetic | `+`, `-`, `*`, `/`, `%`, `**` |
| Bitwise | `~`, `&`, `\|`, `^`, `~^` |
| Logical | `!`, `&&`, `\|\|` |
| Relational | `<`, `>`, `<=`, `>=`, `==`, `!=` |
| Identity | `===`, `!==` (4-state compare) |
| Reduction | `&`, `~&`, `\|`, `~\|`, `^`, `~^` |
| Shift | `<<`, `>>`, `<<<`, `>>>` |
| Concatenation | `{a, b}`, `{N{a}}` |
| Conditional | `cond ? a : b` |

### Coding Style Checklist

- [ ] Use `logic` instead of `reg`/`wire`
- [ ] Use `always_comb` for combinational logic
- [ ] Use `always_ff` for sequential logic
- [ ] Use non-blocking (`<=`) in `always_ff`
- [ ] Use `unique case` or `priority case` with `default`
- [ ] Name all `generate` blocks
- [ ] Use `typedef enum` for FSM states
- [ ] Reset all flip-flops
- [ ] Avoid latches — ensure all `if`/`case` branches assign every output
- [ ] Use `$clog2()` for address width calculations
- [ ] Lint your code with Verilator (`--lint-only -Wall`)

---

## License

This tutorial is provided for educational purposes. All code examples are released
under the [MIT License](LICENSE).
