# Advanced Digital System Design: RTL Implementations in SystemVerilog

A comprehensive, hands-on tutorial covering advanced RTL design techniques using SystemVerilog (IEEE 1800-2017). Each chapter pairs theory with synthesizable, production-quality code examples you can simulate and synthesize.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [SystemVerilog for RTL Design — Key Language Features](#2-systemverilog-for-rtl-design--key-language-features)
3. [Parameterized Combinational Logic — ALU](#3-parameterized-combinational-logic--alu)
4. [Pipelined Arithmetic — Multiplier](#4-pipelined-arithmetic--multiplier)
5. [Advanced Finite State Machines — Traffic Light Controller](#5-advanced-finite-state-machines--traffic-light-controller)
6. [Synchronous FIFO](#6-synchronous-fifo)
7. [Asynchronous FIFO and Clock Domain Crossing](#7-asynchronous-fifo-and-clock-domain-crossing)
8. [Round-Robin Arbiter](#8-round-robin-arbiter)
9. [AXI4-Lite Slave Interface](#9-axi4-lite-slave-interface)
10. [Direct-Mapped Cache Controller](#10-direct-mapped-cache-controller)
11. [UART Transceiver](#11-uart-transceiver)
12. [SPI Master Controller](#12-spi-master-controller)
13. [Design Verification Strategies](#13-design-verification-strategies)
14. [Synthesis and Optimization Guidelines](#14-synthesis-and-optimization-guidelines)

---

## 1. Introduction

Register-Transfer Level (RTL) design is the abstraction layer where digital hardware is described in terms of data flow between registers and the combinational logic that transforms that data. SystemVerilog extends classical Verilog with powerful type system features, interfaces, packages, and verification constructs — making it the industry-standard language for both design and verification.

### What This Tutorial Covers

| Topic | Design Complexity | Key Concepts |
|-------|-------------------|--------------|
| Parameterized ALU | Introductory | `always_comb`, enums, packages, parameterization |
| Pipelined Multiplier | Intermediate | Pipeline stages, throughput vs. latency |
| FSM Traffic Controller | Intermediate | Two-process FSM, enum states, Moore/Mealy |
| Synchronous FIFO | Intermediate | Circular buffer, full/empty detection |
| Asynchronous FIFO | Advanced | CDC, Gray codes, multi-flop synchronizers |
| Round-Robin Arbiter | Advanced | Fairness, rotating priority |
| AXI4-Lite Slave | Advanced | AMBA protocol, handshake channels |
| Cache Controller | Advanced | Tag/data arrays, hit/miss, FSM-datapath |
| UART Transceiver | Advanced | Baud-rate generation, serial protocols |
| SPI Master | Advanced | Shift registers, CPOL/CPHA modes |

### Prerequisites

- Basic knowledge of digital logic (gates, flip-flops, multiplexers)
- Familiarity with Verilog or introductory SystemVerilog
- A simulator such as Verilator, ModelSim/QuestaSim, VCS, or Xcelium

### Repository Structure

```
├── README.md                          # This tutorial
├── examples/
│   ├── 01_parameterized_alu/          # ALU design + testbench
│   ├── 02_pipelined_multiplier/       # Pipelined multiplier + testbench
│   ├── 03_fsm_traffic_light/          # FSM traffic controller + testbench
│   ├── 04_sync_fifo/                  # Synchronous FIFO + testbench
│   ├── 05_async_fifo/                 # Asynchronous FIFO + testbench
│   ├── 06_round_robin_arbiter/        # Round-robin arbiter + testbench
│   ├── 07_axi4_lite_slave/            # AXI4-Lite slave + testbench
│   ├── 08_cache_controller/           # Direct-mapped cache + testbench
│   ├── 09_uart_transceiver/           # UART TX/RX + testbench
│   └── 10_spi_master/                 # SPI master + testbench
```

---

## 2. SystemVerilog for RTL Design — Key Language Features

Before diving into designs, let's review the SystemVerilog features that separate modern RTL from legacy Verilog.

### 2.1 `logic` vs. `reg` vs. `wire`

In SystemVerilog, `logic` replaces both `reg` and `wire` in most contexts. It can be driven by continuous assignments, procedural blocks, or module ports — the compiler determines the correct hardware.

```systemverilog
// Preferred: use 'logic' everywhere
module example (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  data_in,
    output logic [7:0]  data_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'h00;
        else
            data_out <= data_in;
    end
endmodule
```

### 2.2 `always_ff`, `always_comb`, `always_latch`

SystemVerilog introduces intent-specific procedural blocks:

| Block | Purpose | Synthesis Result |
|-------|---------|-----------------|
| `always_ff` | Sequential logic | Flip-flops |
| `always_comb` | Combinational logic | Combinational gates |
| `always_latch` | Latch-based logic | Latches (use sparingly) |

These blocks improve readability and allow the synthesis tool to verify your intent matches the inferred hardware.

### 2.3 Enumerated Types

Enums make FSMs far more readable and debuggable:

```systemverilog
typedef enum logic [2:0] {
    IDLE   = 3'b000,
    FETCH  = 3'b001,
    DECODE = 3'b010,
    EXEC   = 3'b011,
    WB     = 3'b100
} state_t;

state_t current_state, next_state;
```

### 2.4 Packages

Packages let you share types, parameters, and functions across modules:

```systemverilog
package alu_pkg;
    typedef enum logic [3:0] {
        ADD, SUB, AND_OP, OR_OP, XOR_OP,
        SLL, SRL, SRA, SLT, SLTU
    } alu_op_t;
endpackage
```

### 2.5 Interfaces

Interfaces bundle related signals, reducing port clutter and making connections self-documenting:

```systemverilog
interface axi4_lite_if #(parameter ADDR_W = 32, DATA_W = 32) (input logic aclk, aresetn);
    logic [ADDR_W-1:0] awaddr;
    logic               awvalid;
    logic               awready;
    // ... more signals ...

    modport master (output awaddr, awvalid, input awready);
    modport slave  (input  awaddr, awvalid, output awready);
endinterface
```

### 2.6 Parameterization

SystemVerilog supports both Verilog-style `parameter` and the newer `localparam`:

```systemverilog
module fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
) ( /* ports */ );
```

### 2.7 Assertions (for Verification)

Immediate and concurrent assertions catch bugs early:

```systemverilog
// Immediate assertion in procedural code
assert (wr_ptr != rd_ptr) else $error("FIFO overflow!");

// Concurrent assertion (synthesizable as a check)
property p_handshake;
    @(posedge clk) valid |-> ##[1:5] ready;
endproperty
assert property (p_handshake);
```

---

## 3. Parameterized Combinational Logic — ALU

**Source:** [`examples/01_parameterized_alu/`](examples/01_parameterized_alu/)

### 3.1 Design Goals

- Support configurable data width (8, 16, 32, 64 bits)
- Implement arithmetic, logical, shift, and comparison operations
- Use a package to define operation codes
- Pure combinational — single-cycle result

### 3.2 Architecture

```
              ┌────────────────────────┐
  operand_a ──┤                        ├── result
  operand_b ──┤    Parameterized ALU   ├── zero_flag
  alu_op    ──┤                        ├── overflow_flag
              └────────────────────────┘
```

### 3.3 Key Design Decisions

**Enumerated opcodes via a package** — This keeps opcode definitions consistent between the ALU, the decoder, and the testbench. The enum base type `logic [3:0]` provides explicit 4-bit encoding.

**Overflow detection** — For ADD and SUB, we check the sign-bit rule: overflow occurs when two positive numbers produce a negative result or two negative numbers produce a positive result.

**`always_comb` with `unique case`** — The `unique` keyword tells the synthesis tool that exactly one branch will match, enabling optimizations and generating a warning if the case is not fully covered.

> See the full source in [`examples/01_parameterized_alu/alu_pkg.sv`](examples/01_parameterized_alu/alu_pkg.sv) and [`examples/01_parameterized_alu/alu.sv`](examples/01_parameterized_alu/alu.sv).

---

## 4. Pipelined Arithmetic — Multiplier

**Source:** [`examples/02_pipelined_multiplier/`](examples/02_pipelined_multiplier/)

### 4.1 Why Pipelining?

A single-cycle N×N multiplier has a critical path proportional to N. For high clock frequencies, we split the computation across multiple clock cycles (pipeline stages), trading latency for throughput.

### 4.2 Architecture

```
  Stage 1         Stage 2           Stage 3          Stage 4
┌──────────┐   ┌─────────────┐   ┌────────────┐   ┌──────────┐
│ Register │──▶│  Partial     │──▶│  Partial   │──▶│ Final    │
│ Inputs   │   │  Products    │   │  Sum Tree  │   │ Result   │
└──────────┘   └─────────────┘   └────────────┘   └──────────┘
```

**4 pipeline stages:**
1. **Input registration** — Latch operands, improving setup time
2. **Partial product generation** — Split multiplicand and compute partial products
3. **Partial product accumulation** — Sum partial products
4. **Output registration** — Latch the final product

### 4.3 Key Concepts

- **Throughput:** One result per clock cycle (after the pipeline is filled)
- **Latency:** 4 clock cycles from input to output
- **Valid pipeline:** A `valid` bit propagates through the pipeline alongside the data, so downstream logic knows when the output is meaningful

> See the full source in [`examples/02_pipelined_multiplier/pipelined_multiplier.sv`](examples/02_pipelined_multiplier/pipelined_multiplier.sv).

---

## 5. Advanced Finite State Machines — Traffic Light Controller

**Source:** [`examples/03_fsm_traffic_light/`](examples/03_fsm_traffic_light/)

### 5.1 Design Goals

- Control a 4-way intersection with main road and side road
- Support pedestrian crossing requests
- Emergency vehicle override mode
- Configurable timing parameters

### 5.2 Two-Process FSM Pattern

The gold-standard FSM coding style uses two `always` blocks:

```
┌──────────────────────────┐
│  always_comb             │  ← Next-state logic + output logic
│  (combinational block)   │
└──────────┬───────────────┘
           │ next_state
           ▼
┌──────────────────────────┐
│  always_ff               │  ← State register
│  (sequential block)      │
└──────────────────────────┘
```

**Why two processes?**
- Clean separation of combinational and sequential logic
- Synthesis tools infer exactly what you intend
- Easier to read, test, and maintain

### 5.3 State Diagram

```
                    ┌──────────┐
          ┌────────▶│EMERGENCY │◀── emergency signal
          │         └────┬─────┘
          │              │ !emergency
          │              ▼
     ┌────┴─────┐   ┌──────────┐
     │ MAIN_RED │◀──│MAIN_GREEN│──timer──▶ MAIN_YELLOW
     └────┬─────┘   └──────────┘              │
          │              ▲                     │
          │              │                timer│
          ▼              │                     ▼
     ┌──────────┐   ┌───┴──────┐        ┌──────────┐
     │SIDE_GREEN│──▶│SIDE_YELLOW│       │MAIN_YELLOW│
     └──────────┘   └──────────┘        └──────────┘
```

> See the full source in [`examples/03_fsm_traffic_light/traffic_light_controller.sv`](examples/03_fsm_traffic_light/traffic_light_controller.sv).

---

## 6. Synchronous FIFO

**Source:** [`examples/04_sync_fifo/`](examples/04_sync_fifo/)

### 6.1 Architecture

A synchronous FIFO uses a single clock domain with read and write pointers indexing into a circular buffer.

```
           wr_en                                rd_en
             │                                    │
             ▼                                    ▼
        ┌─────────┐                          ┌─────────┐
        │ wr_ptr  │                          │ rd_ptr  │
        └────┬────┘                          └────┬────┘
             │                                    │
             ▼         ┌──────────────┐           ▼
  wr_data──▶│  Write   │   Memory     │  Read   │──▶ rd_data
             │  Port    │   Array      │  Port   │
             └─────────┤  (DEPTH      ├─────────┘
                       │   entries)   │
                       └──────────────┘

        full ◀── (wr_ptr + 1 == rd_ptr)
        empty ◀── (wr_ptr == rd_ptr)
```

### 6.2 Key Design Decisions

- **Extra bit for full/empty:** Write and read pointers are `ADDR_WIDTH+1` bits wide. The MSB distinguishes full from empty when the lower address bits match.
- **Registered output:** The read data is registered for timing closure.
- **Almost-full / almost-empty flags:** Configurable thresholds alert upstream/downstream logic before the FIFO reaches its limits.

> See the full source in [`examples/04_sync_fifo/sync_fifo.sv`](examples/04_sync_fifo/sync_fifo.sv).

---

## 7. Asynchronous FIFO and Clock Domain Crossing

**Source:** [`examples/05_async_fifo/`](examples/05_async_fifo/)

### 7.1 The CDC Problem

When data must pass between two unrelated clock domains, metastability can corrupt pointer values. The asynchronous FIFO solves this with:

1. **Gray code pointers** — Only one bit changes per increment, preventing multi-bit glitches
2. **Two-flop synchronizers** — Each pointer is synchronized into the opposite clock domain through two back-to-back flip-flops

### 7.2 Architecture

```
  Write Clock Domain          │         Read Clock Domain
                               │
  wr_data ──▶ ┌────────┐      │      ┌────────┐ ──▶ rd_data
  wr_en  ──▶  │ Dual-  │      │      │ Dual-  │ ◀── rd_en
              │ Port   │      │      │ Port   │
              │ RAM    │      │      │ RAM    │
              └────────┘      │      └────────┘
                 │            │            │
              wr_ptr          │         rd_ptr
              (Gray) ────▶ sync ────▶ (Gray)
              (Gray) ◀──── sync ◀──── (Gray)
                              │
```

### 7.3 Gray Code Conversion

```systemverilog
// Binary to Gray
function automatic logic [N:0] bin2gray(input logic [N:0] bin);
    return bin ^ (bin >> 1);
endfunction

// Gray to Binary
function automatic logic [N:0] gray2bin(input logic [N:0] gray);
    logic [N:0] bin;
    bin[N] = gray[N];
    for (int i = N-1; i >= 0; i--)
        bin[i] = bin[i+1] ^ gray[i];
    return bin;
endfunction
```

### 7.4 Why Gray Code?

| Binary Counter | Gray Counter |
|---------------|-------------|
| `011 → 100` (3 bits change!) | `010 → 110` (1 bit changes) |

When a binary pointer crosses clock domains, multiple bits may be sampled at different moments, producing a garbage value. Gray code guarantees at most one bit changes per step, so the synchronized value is either the current or previous pointer — both safe.

> See the full source in [`examples/05_async_fifo/async_fifo.sv`](examples/05_async_fifo/async_fifo.sv).

---

## 8. Round-Robin Arbiter

**Source:** [`examples/06_round_robin_arbiter/`](examples/06_round_robin_arbiter/)

### 8.1 Design Goals

- N requestors (parameterized)
- Fair round-robin scheduling — no requestor is starved
- Single-cycle grant decision
- Support for variable-length bursts with lock signal

### 8.2 Algorithm

The arbiter maintains a rotating priority mask. After granting a request, the mask rotates so the *next* requestor in line gets highest priority:

```
Request vector:  1 0 1 1
Priority mask:   0 0 1 1  (requestors 0,1 have been recently served)
─────────────────────────
Masked requests: 0 0 1 1  → Grant goes to requestor 2 (first set bit)
Next mask:       0 0 0 1  (rotate past requestor 2)
```

### 8.3 Implementation Technique

The classic approach uses a double-width trick:

```systemverilog
// Thermometer-code masking for round-robin
logic [2*N-1:0] double_req, double_grant;
assign double_req = {req, req} & ~({2*N{1'b1}} >> (2*N - mask_ptr));
```

A simpler approach implemented here uses a rotating priority register and a priority encoder.

> See the full source in [`examples/06_round_robin_arbiter/round_robin_arbiter.sv`](examples/06_round_robin_arbiter/round_robin_arbiter.sv).

---

## 9. AXI4-Lite Slave Interface

**Source:** [`examples/07_axi4_lite_slave/`](examples/07_axi4_lite_slave/)

### 9.1 AXI4-Lite Protocol Overview

AXI4-Lite is a simplified version of the AMBA AXI4 protocol for memory-mapped register access. It uses five independent channels:

| Channel | Direction | Purpose |
|---------|-----------|---------|
| Write Address (AW) | Master → Slave | Address for write transactions |
| Write Data (W) | Master → Slave | Data + byte strobes |
| Write Response (B) | Slave → Master | Write completion status |
| Read Address (AR) | Master → Slave | Address for read transactions |
| Read Data (R) | Slave → Master | Read data + response status |

### 9.2 Handshake Protocol

Every channel uses a VALID/READY handshake:

```
        ┌───┐   ┌───┐   ┌───┐   ┌───┐
  clk ──┘   └───┘   └───┘   └───┘   └───
              ╔═══════════════╗
  VALID ──────╢               ╟──────────
              ╚═══════════════╝
                      ╔═══════╗
  READY ──────────────╢       ╟──────────
                      ╚═══════╝
                          ▲
                    Transfer occurs here
                  (VALID && READY both high)
```

### 9.3 Register Map

The example implements a simple register file with 4 read/write registers:

| Offset | Name | Description |
|--------|------|-------------|
| 0x00 | CTRL | Control register |
| 0x04 | STATUS | Status register (read-only) |
| 0x08 | DATA0 | General-purpose data |
| 0x0C | DATA1 | General-purpose data |

> See the full source in [`examples/07_axi4_lite_slave/axi4_lite_slave.sv`](examples/07_axi4_lite_slave/axi4_lite_slave.sv).

---

## 10. Direct-Mapped Cache Controller

**Source:** [`examples/08_cache_controller/`](examples/08_cache_controller/)

### 10.1 Cache Organization

```
  Address: [    TAG    |   INDEX   | OFFSET ]
            ──────────  ──────────  ────────
            Identifies   Selects    Byte
            the block    cache set  within
                                    line

  Cache Line:
  ┌───────┬───────┬────────────────────────────────┐
  │ Valid │  Tag  │          Data Block             │
  │  (1)  │ (T)  │      (BLOCK_SIZE bytes)         │
  └───────┴───────┴────────────────────────────────┘
```

### 10.2 FSM States

```
            ┌──────────┐
  ──reset──▶│   IDLE   │◀─────────────────────┐
            └────┬─────┘                      │
                 │ cpu_req                     │
                 ▼                             │
            ┌──────────┐                      │
            │  COMPARE │──hit──▶ return data  │
            │   TAG    │                      │
            └────┬─────┘                      │
                 │ miss                       │
                 ▼                            │
            ┌──────────┐      ┌──────────┐   │
            │ ALLOCATE │─────▶│ WRITE    │───┘
            │ (fetch   │      │ BACK     │
            │  from    │      │ (if      │
            │  memory) │      │  dirty)  │
            └──────────┘      └──────────┘
```

### 10.3 Key Concepts

- **Valid bit:** Indicates whether a cache line contains meaningful data
- **Tag comparison:** Determines if the requested address matches the stored line
- **Write-back policy:** Dirty lines are written to memory only on eviction, reducing bus traffic
- **Miss penalty:** Multi-cycle stall while data is fetched from main memory

> See the full source in [`examples/08_cache_controller/cache_controller.sv`](examples/08_cache_controller/cache_controller.sv).

---

## 11. UART Transceiver

**Source:** [`examples/09_uart_transceiver/`](examples/09_uart_transceiver/)

### 11.1 UART Frame Format

```
  Idle ─┐ ┌─Start─┬──D0──┬──D1──┬──D2──┬ ··· ┬──D7──┬─Parity─┬─Stop─┐ Idle
        │ │  (0)  │      │      │      │     │      │  (opt) │ (1)  │
        └─┘       └──────┴──────┴──────┴─────┴──────┴────────┴──────└──
                  ◀───────── 8 data bits ──────────▶
```

### 11.2 Baud Rate Generation

The baud rate generator divides the system clock to produce a tick at 16× the baud rate for oversampling:

```
  Divisor = f_clk / (16 × baud_rate)

  Example: 100 MHz / (16 × 115200) = 54.25 ≈ 54
```

### 11.3 Receiver Oversampling

The receiver samples the incoming signal at 16× the baud rate and uses the middle sample (count = 7) for maximum noise immunity:

```
          ┌──────────────────── Bit period ──────────────────────┐
  Sample: 0  1  2  3  4  5  6  │7│  8  9  10  11  12  13  14  15
                                 ▲
                           Sample here (middle)
```

> See the full source in [`examples/09_uart_transceiver/uart_tx.sv`](examples/09_uart_transceiver/uart_tx.sv) and [`examples/09_uart_transceiver/uart_rx.sv`](examples/09_uart_transceiver/uart_rx.sv).

---

## 12. SPI Master Controller

**Source:** [`examples/10_spi_master/`](examples/10_spi_master/)

### 12.1 SPI Signal Descriptions

| Signal | Direction | Description |
|--------|-----------|-------------|
| SCLK | Master → Slave | Serial clock |
| MOSI | Master → Slave | Master Out, Slave In |
| MISO | Slave → Master | Master In, Slave Out |
| CS_N | Master → Slave | Chip select (active low) |

### 12.2 SPI Modes

| Mode | CPOL | CPHA | Clock Idle | Data Sampling |
|------|------|------|------------|---------------|
| 0 | 0 | 0 | Low | Rising edge |
| 1 | 0 | 1 | Low | Falling edge |
| 2 | 1 | 0 | High | Falling edge |
| 3 | 1 | 1 | High | Rising edge |

### 12.3 Transaction Timing (Mode 0)

```
  CS_N  ──┐                                              ┌───
          └──────────────────────────────────────────────┘

  SCLK  ────┐   ┌───┐   ┌───┐   ┌───┐       ┌───┐   ┌──────
            └───┘   └───┘   └───┘   └─ ··· ─┘   └───┘

  MOSI  ──╳═══╳═══╳═══╳═══╳═══╳═══╳══ ··· ╳═══╳═══╳═══╳────
          MSB                                          LSB

  MISO  ──╳═══╳═══╳═══╳═══╳═══╳═══╳══ ··· ╳═══╳═══╳═══╳────
```

> See the full source in [`examples/10_spi_master/spi_master.sv`](examples/10_spi_master/spi_master.sv).

---

## 13. Design Verification Strategies

### 13.1 Self-Checking Testbenches

All examples include self-checking testbenches that automatically compare expected vs. actual outputs:

```systemverilog
task automatic check_result(
    input string   test_name,
    input logic [N-1:0] expected,
    input logic [N-1:0] actual
);
    if (expected !== actual) begin
        $error("[FAIL] %s: expected=%0h, got=%0h", test_name, expected, actual);
        error_count++;
    end else begin
        $display("[PASS] %s", test_name);
    end
endtask
```

### 13.2 Assertion-Based Verification

Use SystemVerilog Assertions (SVA) to express protocol rules:

```systemverilog
// FIFO should never overflow
property p_no_overflow;
    @(posedge clk) disable iff (!rst_n)
    (wr_en && full) |-> ##1 !wr_en;
endproperty

// AXI handshake: VALID must not deassert before READY
property p_axi_valid_stable;
    @(posedge clk) disable iff (!aresetn)
    (awvalid && !awready) |=> awvalid;
endproperty
```

### 13.3 Code Coverage

Ensure tests exercise all paths:
- **Line coverage** — every line of RTL is executed
- **Toggle coverage** — every signal transitions both 0→1 and 1→0
- **FSM coverage** — every state and transition is visited
- **Condition coverage** — every Boolean sub-expression is evaluated both ways

### 13.4 Formal Verification

For critical modules, consider formal property checking:

```systemverilog
// Formal: FIFO fill level must always be between 0 and DEPTH
assert property (@(posedge clk) disable iff (!rst_n)
    fill_level >= 0 && fill_level <= DEPTH
);
```

---

## 14. Synthesis and Optimization Guidelines

### 14.1 Coding for Synthesis

| Practice | Rationale |
|----------|-----------|
| Use `always_ff` for sequential logic | Explicitly infers flip-flops |
| Use `always_comb` for combinational logic | Prevents unintended latches |
| Use `unique case` / `priority case` | Enables synthesis optimizations |
| Avoid initial blocks (use reset) | Initial blocks are not synthesizable on most targets |
| Register all module outputs | Improves timing at module boundaries |
| Use parameterized widths (`$clog2`) | Prevents width mismatches |

### 14.2 Clock Domain Crossing Rules

1. **Never** use a single flip-flop for synchronization — always use at least two
2. **Always** use Gray code for multi-bit counters crossing domains
3. **Use** proper synchronizer cells from your technology library when available
4. **Constrain** CDC paths with `set_false_path` or `set_max_delay` in your SDC file

### 14.3 Reset Strategy

- **Asynchronous assert, synchronous deassert** — the safest pattern:

```systemverilog
logic rst_n_sync;
logic [1:0] rst_pipe;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rst_pipe <= 2'b00;
    else
        rst_pipe <= {rst_pipe[0], 1'b1};
end

assign rst_n_sync = rst_pipe[1];
```

### 14.4 Area vs. Speed Trade-offs

| Technique | Effect on Area | Effect on Speed |
|-----------|---------------|-----------------|
| Pipelining | Increases (more registers) | Improves (shorter critical path) |
| Resource sharing | Decreases | May worsen (adds muxes) |
| Unrolling/Replication | Increases | Improves (parallelism) |
| Retiming | Neutral | Improves |
| Operand isolation | Slightly increases | Reduces power, neutral on speed |

---

## How to Run the Examples

### Using Verilator (Open Source)

```bash
# Install Verilator (Ubuntu/Debian)
sudo apt-get install verilator

# Lint-check a design
verilator --lint-only -Wall examples/01_parameterized_alu/alu.sv

# Simulate with a testbench
verilator --binary -j 0 --trace \
    examples/01_parameterized_alu/alu_pkg.sv \
    examples/01_parameterized_alu/alu.sv \
    examples/01_parameterized_alu/tb_alu.sv
```

### Using Icarus Verilog (Open Source)

```bash
# Compile and simulate
iverilog -g2012 -o sim \
    examples/01_parameterized_alu/alu_pkg.sv \
    examples/01_parameterized_alu/alu.sv \
    examples/01_parameterized_alu/tb_alu.sv
vvp sim
```

### Using Commercial Simulators

```bash
# ModelSim/QuestaSim
vlog -sv examples/01_parameterized_alu/*.sv
vsim -c tb_alu -do "run -all; quit"

# VCS
vcs -sverilog examples/01_parameterized_alu/*.sv -o simv
./simv

# Xcelium
xrun -sv examples/01_parameterized_alu/*.sv
```

---

## License

This tutorial and all accompanying code examples are provided for educational purposes. Feel free to use, modify, and distribute as needed.
