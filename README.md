# Advanced Digital System Design: RTL Implementation in SystemVerilog

A comprehensive, hands-on tutorial covering RTL (Register Transfer Level) design of advanced digital systems using SystemVerilog. Every concept is paired with fully synthesizable code examples and practical testbenches.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [SystemVerilog RTL Fundamentals](#2-systemverilog-rtl-fundamentals)
3. [Combinational Logic Design](#3-combinational-logic-design)
4. [Sequential Logic Design](#4-sequential-logic-design)
5. [Finite State Machine (FSM) Design](#5-finite-state-machine-fsm-design)
6. [Memory Subsystem Design](#6-memory-subsystem-design)
7. [Bus Protocol Interfaces](#7-bus-protocol-interfaces)
8. [Advanced Design Techniques](#8-advanced-design-techniques)
9. [Verification with Testbenches](#9-verification-with-testbenches)
10. [RTL Design Best Practices](#10-rtl-design-best-practices)
11. [Running the Examples](#11-running-the-examples)

---

## 1. Introduction

### What Is RTL Design?

**Register Transfer Level (RTL)** is an abstraction that describes a digital circuit in terms of:

- **Registers** — clocked storage elements (flip-flops, latches)
- **Combinational logic** — data transformations between registers
- **Control signals** — steering data flow through multiplexers, enables, and state machines

RTL sits between algorithmic (behavioral) descriptions and gate-level netlists. Synthesis tools convert RTL code into technology-specific gates and wires.

### Why SystemVerilog?

SystemVerilog extends Verilog with features critical for modern digital design:

| Feature | Benefit |
|---|---|
| `logic` type | Replaces ambiguous `wire`/`reg` distinction |
| `always_ff`, `always_comb`, `always_latch` | Explicit design intent for synthesis |
| `typedef enum` | Readable, type-safe FSM states |
| Parameterized modules | Reusable, scalable IP |
| Interfaces | Clean, structured port connectivity |
| Packages | Shared types and constants |
| Assertions (`assert`, `assume`) | Inline correctness checks |
| Packed/unpacked arrays | Flexible data structuring |

### Repository Structure

```
rtl_examples/
├── 01_combinational_logic/
│   ├── alu_32bit.sv                 # 32-bit ALU with 14 operations
│   ├── priority_encoder.sv          # Parameterized priority encoder with mask
│   ├── barrel_shifter.sv            # Logarithmic barrel shifter
│   ├── carry_lookahead_adder.sv     # 32-bit CLA adder
│   └── decoder_encoder.sv          # Decoder, encoder, one-hot mux
│
├── 02_sequential_logic/
│   ├── sync_fifo.sv                 # Synchronous FIFO with status flags
│   ├── async_fifo.sv                # Dual-clock FIFO with Gray code pointers
│   ├── shift_register.sv           # Universal shift register + LFSR
│   └── counters.sv                 # Up/down, Gray, ring, Johnson counters
│
├── 03_fsm_designs/
│   ├── moore_fsm_sequence_detector.sv   # Moore "1011" detector
│   ├── mealy_fsm_sequence_detector.sv   # Mealy "1011" detector
│   ├── traffic_light_controller.sv      # Timer-based intersection controller
│   └── vending_machine_fsm.sv           # Coin-accumulating dispenser
│
├── 04_memory_subsystems/
│   ├── single_port_ram.sv           # Synchronous single-port SRAM
│   ├── dual_port_ram.sv             # True dual-port SRAM
│   ├── cache_controller.sv         # Direct-mapped write-back cache
│   └── register_file.sv            # 2R1W register file with forwarding
│
├── 05_bus_protocols/
│   ├── axi_lite_slave.sv           # AXI4-Lite slave register bank
│   ├── wishbone_slave.sv           # Wishbone B4 pipelined slave
│   ├── round_robin_arbiter.sv      # Fair round-robin bus arbiter
│   └── apb_master.sv              # AMBA APB master controller
│
├── 06_advanced_designs/
│   ├── pipelined_multiplier.sv     # 4-stage pipelined multiplier
│   ├── clock_domain_crossing.sv    # CDC primitives (2FF, pulse, handshake)
│   ├── uart_transceiver.sv        # UART TX + RX (8N1, configurable baud)
│   ├── spi_master.sv              # SPI master (all 4 modes)
│   ├── cordic_engine.sv           # Iterative CORDIC sin/cos calculator
│   ├── pwm_generator.sv           # PWM with dead-time insertion
│   └── watchdog_timer.sv          # Configurable watchdog with warning
│
└── 07_testbenches/
    ├── tb_alu_32bit.sv             # Directed + random ALU tests
    ├── tb_sync_fifo.sv             # FIFO fill/drain/status verification
    ├── tb_uart_loopback.sv         # TX→RX loopback integrity test
    ├── tb_fsm_sequence_detector.sv # Moore vs Mealy comparison
    └── tb_round_robin_arbiter.sv   # Fairness verification
```

---

## 2. SystemVerilog RTL Fundamentals

### 2.1 The `logic` Type

SystemVerilog's `logic` type replaces the Verilog `reg`/`wire` confusion. A `logic` signal can be driven by continuous assignments, procedural blocks, or module ports — the compiler determines the correct hardware.

```systemverilog
logic [31:0] data;          // 32-bit 4-state signal
logic        valid;          // Single bit
logic [7:0]  mem [1024];     // Unpacked array (memory)
```

### 2.2 Procedural Blocks — Expressing Design Intent

SystemVerilog provides three specialized always blocks that explicitly declare the designer's intent. Synthesis tools use these to generate correct hardware and flag unintended misuse.

```systemverilog
// Combinational logic — all inputs in the sensitivity list
always_comb begin
    result = a + b;      // Must assign on every path (no latches)
end

// Sequential logic — clocked flip-flops
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;         // Async active-low reset
    else
        q <= d;          // Nonblocking assignment (<=)
end

// Intentional latch (rare in RTL, but explicit when needed)
always_latch begin
    if (enable)
        q <= d;
end
```

**Key rules:**
- Use `=` (blocking) inside `always_comb`
- Use `<=` (nonblocking) inside `always_ff`
- Never mix blocking and nonblocking assignments to the same signal

### 2.3 Parameterized Design

Parameters make modules reusable across different configurations:

```systemverilog
module fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)   // Computed parameter
) (
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [ADDR_WIDTH:0]   count
);
```

Use `localparam` for internal constants that should not be overridden:

```systemverilog
localparam HALF_DEPTH = DEPTH / 2;
```

### 2.4 Enumerated Types for FSMs

Enums provide readable, type-checked state encoding:

```systemverilog
typedef enum logic [2:0] {
    IDLE    = 3'b000,
    SETUP   = 3'b001,
    EXECUTE = 3'b010,
    DONE    = 3'b011
} state_e;

state_e current_state, next_state;
```

### 2.5 Generate Blocks

Generate blocks create parameterized, scalable hardware structures:

```systemverilog
genvar i;
generate
    for (i = 0; i < NUM_STAGES; i++) begin : gen_pipeline
        always_ff @(posedge clk)
            pipe[i+1] <= pipe[i];
    end
endgenerate
```

---

## 3. Combinational Logic Design

### 3.1 32-Bit ALU (`alu_32bit.sv`)

The Arithmetic Logic Unit is the computational heart of any processor. This implementation supports 14 operations spanning arithmetic, logical, shift, and comparison categories.

**Architecture:**

```
              ┌─────────────────────────────────────┐
 operand_a ──>│                                     │──> result
 operand_b ──>│           32-Bit ALU                │──> zero
    alu_op ──>│                                     │──> carry
              │  ADD SUB AND OR XOR SLL SRL SRA     │──> overflow
              │  SLT SLTU NOR NAND MUL PASS         │──> negative
              └─────────────────────────────────────┘
```

**Key design decisions:**
- **Overflow detection** uses the sign-bit technique: for addition, overflow occurs when both operands have the same sign but the result has a different sign
- **Arithmetic right shift** (`>>>`) preserves the sign bit, unlike logical right shift
- **Set-less-than** operations produce a 1 or 0, matching RISC-V ISA behavior

```systemverilog
ALU_SRA: result = $signed(operand_a) >>> operand_b[4:0];

ALU_SLT: result = {{(DATA_WIDTH-1){1'b0}},
                    $signed(operand_a) < $signed(operand_b)};
```

> **File:** `rtl_examples/01_combinational_logic/alu_32bit.sv`

### 3.2 Priority Encoder (`priority_encoder.sv`)

Encodes the highest-priority active input into a binary index. Used in interrupt controllers, arbitration logic, and branch prediction.

The file includes two variants:
1. **Basic priority encoder** — simple MSB-priority encoding
2. **Masked priority encoder** — supports masking and a rotating base priority for round-robin applications

**How the masked version works:**

```
     Double the request vector, rotate by base_priority:
     ┌──────────────┬──────────────┐
     │   request    │   request    │  >> base_priority
     └──────────────┴──────────────┘
                    ↓
           Scan from bit 0 upward
```

> **File:** `rtl_examples/01_combinational_logic/priority_encoder.sv`

### 3.3 Barrel Shifter (`barrel_shifter.sv`)

Performs arbitrary-distance shifts in a single combinational cycle using a logarithmic cascade of multiplexers.

**Architecture (32-bit, 5 stages):**

```
  Stage 0: shift by 0 or 1
  Stage 1: shift by 0 or 2
  Stage 2: shift by 0 or 4
  Stage 3: shift by 0 or 8
  Stage 4: shift by 0 or 16
```

Each stage looks at one bit of the shift amount and conditionally shifts by 2^i positions. The trick for left shifts: reverse the input, right-shift, then reverse the output.

> **File:** `rtl_examples/01_combinational_logic/barrel_shifter.sv`

### 3.4 Carry Lookahead Adder (`carry_lookahead_adder.sv`)

Demonstrates the generate/propagate technique that eliminates ripple-carry delay. The 32-bit adder is built hierarchically from eight 4-bit CLA blocks with a second-level lookahead.

**CLA equations:**

```
Generate:  g[i] = a[i] & b[i]
Propagate: p[i] = a[i] ^ b[i]
Carry:     c[i+1] = g[i] | (p[i] & c[i])
```

The carry for any bit position depends only on the original inputs, not on previous carry bits — enabling parallel computation.

> **File:** `rtl_examples/01_combinational_logic/carry_lookahead_adder.sv`

### 3.5 Decoders, Encoders, and Multiplexers (`decoder_encoder.sv`)

Building blocks used throughout digital design:

| Module | Function |
|---|---|
| `binary_decoder` | N-bit input → 2^N one-hot output |
| `onehot_to_binary` | One-hot input → binary index |
| `mux_onehot` | One-hot select multiplexer |

The one-hot encoder includes a synthesis-translate-off assertion that verifies input validity during simulation.

> **File:** `rtl_examples/01_combinational_logic/decoder_encoder.sv`

---

## 4. Sequential Logic Design

### 4.1 Synchronous FIFO (`sync_fifo.sv`)

A circular buffer with independent read/write pointers. FIFOs decouple producer/consumer rates and are among the most commonly used structures in digital design.

**Architecture:**

```
            wr_ptr                    rd_ptr
              │                         │
              ▼                         ▼
  ┌───┬───┬───┬───┬───┬───┬───┬───┐
  │ 0 │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │   RAM
  └───┴───┴───┴───┴───┴───┴───┴───┘
              ▲                         ▲
           wr_data                   rd_data
```

**Full/empty detection:** Pointers include an extra MSB. When the lower bits match, the MSBs distinguish full (different MSBs) from empty (same MSBs). The `count` signal (`wr_ptr - rd_ptr`) drives programmable `almost_full` and `almost_empty` thresholds.

> **File:** `rtl_examples/02_sequential_logic/sync_fifo.sv`

### 4.2 Asynchronous (Dual-Clock) FIFO (`async_fifo.sv`)

Transfers data between two unrelated clock domains. This is the classic Cummings-style design (SNUG 2002).

**Why Gray coding is essential:**

When a binary counter increments from `0111` to `1000`, all four bits change simultaneously. If a synchronizer samples in the middle of this transition, it can read a corrupted value like `0000` or `1111`. A Gray-coded counter changes only one bit per increment, guaranteeing the synchronized value is either the old or the new value — never a garbled intermediate.

```
Binary:  0111 → 1000  (4 bits change — unsafe to synchronize)
Gray:    0100 → 1100  (1 bit changes — safe to synchronize)
```

**Key design elements:**
1. Write pointer in Gray code, synchronized into read domain via 2-flop synchronizer
2. Read pointer in Gray code, synchronized into write domain
3. Full = `wr_gray == {~rd_gray_sync[MSB:MSB-1], rd_gray_sync[rest]}`
4. Empty = `rd_gray == wr_gray_sync`

> **File:** `rtl_examples/02_sequential_logic/async_fifo.sv`

### 4.3 Shift Registers & LFSR (`shift_register.sv`)

**Universal Shift Register:** Supports four modes via a 2-bit select:

| Mode | Operation |
|---|---|
| `00` | Hold (no change) |
| `01` | Shift right (MSB ← serial_in) |
| `10` | Shift left (LSB ← serial_in) |
| `11` | Parallel load |

**Linear Feedback Shift Register (LFSR):** Generates pseudo-random bit sequences using Galois configuration. The feedback polynomial determines the sequence length — a maximal-length LFSR with n bits produces a sequence of 2^n - 1 unique values before repeating.

```systemverilog
if (feedback_bit)
    lfsr_out <= (lfsr_out >> 1) ^ POLYNOMIAL;
else
    lfsr_out <= lfsr_out >> 1;
```

> **File:** `rtl_examples/02_sequential_logic/shift_register.sv`

### 4.4 Counter Collection (`counters.sv`)

Four counter types, each with practical applications:

| Counter | Use Case |
|---|---|
| **Up/Down Counter** | Address generation, timer/counter peripherals |
| **Gray Code Counter** | FIFO pointers for clock domain crossing |
| **Ring Counter** | One-hot sequencing, token passing |
| **Johnson Counter** | Phase generation, glitch-free decoding |

The up/down counter includes `load`, `enable`, `overflow`, and `underflow` signals for complete control.

> **File:** `rtl_examples/02_sequential_logic/counters.sv`

---

## 5. Finite State Machine (FSM) Design

### 5.1 Moore FSM — Sequence Detector (`moore_fsm_sequence_detector.sv`)

Detects the bit pattern "1011" in a serial input stream. In a **Moore machine**, the output depends only on the current state.

**State diagram:**

```
            ┌───0───┐
            ▼       │
  ┌──────┐ 1 ┌────┐ 0 ┌─────┐ 1 ┌─────┐ 1 ┌──────┐
  │ IDLE ├──>│ S_1 ├──>│ S_10├──>│ S_101├──>│ S_1011│
  └──────┘   └──┬─┘   └──┬──┘   └──┬───┘   └──┬───┘
     ▲       1  │     0  │         │  0        │
     └──────────┘     ▲  │         │           │
     └────────────────┘  │         └─────────┘ │
                         └──0──────────────────┘
```

**Output:** `detected = 1` when in state `S_1011` (one cycle after the final bit arrives).

> **File:** `rtl_examples/03_fsm_designs/moore_fsm_sequence_detector.sv`

### 5.2 Mealy FSM — Sequence Detector (`mealy_fsm_sequence_detector.sv`)

Same detection pattern ("1011") but as a **Mealy machine**: the output depends on both current state and current input. This means:
- Detection occurs **one clock cycle earlier** than the Moore version
- Requires only 4 states instead of 5
- Output may glitch if inputs are asynchronous (generally fine for synchronous inputs)

```systemverilog
S_101: begin
    if (data_in) begin
        detected   = 1'b1;   // Mealy: output reacts immediately
        next_state = S_1;    // Overlap: '1' starts a new potential match
    end
end
```

> **File:** `rtl_examples/03_fsm_designs/mealy_fsm_sequence_detector.sv`

### 5.3 Traffic Light Controller (`traffic_light_controller.sv`)

A real-world FSM controlling a two-way intersection with:
- Configurable green/yellow/red phase durations
- All-red safety overlap between opposing green phases
- Pedestrian crossing request (latched until serviced)
- Emergency override (all lights red)

**State sequence:**

```
NS_GREEN → NS_YELLOW → ALL_RED_1 → [PED_PHASE →] EW_GREEN → EW_YELLOW → ALL_RED_2 → (repeat)
                                        ↑
                                  if ped_pending
```

**Design pattern:** Timer-based FSM. A free-running counter resets on every state transition. The next-state logic compares the counter against per-state duration thresholds.

> **File:** `rtl_examples/03_fsm_designs/traffic_light_controller.sv`

### 5.4 Vending Machine FSM (`vending_machine_fsm.sv`)

Accepts nickels (5¢) and dimes (10¢), dispensing a product at 25¢ and returning change if overpaid:

```
S_0 → S_5 → S_10 → S_15 → S_20 → S_DONE (dispense!)
                                    ↑ dime: change = 5¢
```

Demonstrates accumulator-style FSM design where each state represents accumulated value.

> **File:** `rtl_examples/03_fsm_designs/vending_machine_fsm.sv`

---

## 6. Memory Subsystem Design

### 6.1 Single-Port RAM (`single_port_ram.sv`)

The simplest RAM: one address port shared for reads and writes. The coding style directly infers block RAM on FPGA targets (Xilinx BRAM, Intel M20K).

```systemverilog
always_ff @(posedge clk) begin
    if (we)
        mem[addr] <= din;
    dout <= mem[addr];    // Read-first: returns OLD data during write
end
```

Swapping the write and read order inside the `always_ff` block changes the read-during-write behavior (write-first vs. read-first).

> **File:** `rtl_examples/04_memory_subsystems/single_port_ram.sv`

### 6.2 True Dual-Port RAM (`dual_port_ram.sv`)

Both ports can independently read and write, each with its own clock. Essential for:
- Multi-clock-domain systems
- Video frame buffers (write from camera, read for display)
- Network packet buffers

```systemverilog
// Port A                       // Port B
always_ff @(posedge clk_a)     always_ff @(posedge clk_b)
    if (we_a)                      if (we_b)
        mem[addr_a] <= din_a;          mem[addr_b] <= din_b;
    dout_a <= mem[addr_a];         dout_b <= mem[addr_b];
```

> **File:** `rtl_examples/04_memory_subsystems/dual_port_ram.sv`

### 6.3 Direct-Mapped Cache Controller (`cache_controller.sv`)

Implements a complete write-back cache with FSM control. This design demonstrates how CPUs interact with memory hierarchies.

**Address decomposition (32-bit address, 256 lines, 4 words/line):**

```
┌─────────────────────┬──────────┬────────┬────┐
│      Tag (20b)      │ Index(8b)│Offset(2b)│BO │
└─────────────────────┴──────────┴────────┴────┘
```

**FSM states:**

```
IDLE → COMPARE ──hit──→ IDLE (return data)
                │
              miss
                │
          ┌─dirty?─┐
          │        │
        WRITEBACK  ALLOCATE
          │           │
       WB_WAIT    ALLOC_WAIT
          │           │
        ALLOCATE   COMPARE (retry)
```

- **Write-back policy:** Dirty lines are written to memory only on eviction
- **Word counter:** Transfers entire cache lines (4 words) during writeback and allocation
- **Tag/valid/dirty arrays:** Per-line metadata for hit detection and coherence

> **File:** `rtl_examples/04_memory_subsystems/cache_controller.sv`

### 6.4 Multi-Port Register File (`register_file.sv`)

A 2-read, 1-write register file typical of RISC processors:

- **Register 0** is hardwired to zero (matching RISC-V and MIPS conventions)
- **Write-through forwarding:** A read from the register being written returns the new value in the same cycle, avoiding data hazards

```systemverilog
assign rd_data_a = (rd_addr_a == '0) ? '0 :
                   (wr_en && wr_addr == rd_addr_a) ? wr_data :
                   registers[rd_addr_a];
```

> **File:** `rtl_examples/04_memory_subsystems/register_file.sv`

---

## 7. Bus Protocol Interfaces

### 7.1 AXI4-Lite Slave (`axi_lite_slave.sv`)

AXI4-Lite is the de facto standard for FPGA register access in the ARM/AMBA ecosystem. This slave implements a memory-mapped register bank.

**AXI4-Lite has five independent channels:**

```
         ┌───────────────────────────┐
         │                           │
  AW ──> │  Write Address Channel    │
  W  ──> │  Write Data Channel       │
  B  <── │  Write Response Channel   │──> reg_out[] (to user logic)
  AR ──> │  Read Address Channel     │
  R  <── │  Read Data Channel        │<── reg_in[]  (from user logic)
         │                           │
         └───────────────────────────┘
```

**Key implementation details:**
- Separate `aw_done` and `w_done` tracking allows address and data to arrive in any order
- Byte-strobe (`wstrb`) support enables partial-word writes
- Response is generated only after both address and data are received

> **File:** `rtl_examples/05_bus_protocols/axi_lite_slave.sv`

### 7.2 Wishbone B4 Slave (`wishbone_slave.sv`)

Wishbone is an open-source bus standard popular in FPGA SoC projects (e.g., LiteX, OpenCores).

**Pipelined vs. Classic Wishbone:**
- Classic: ACK in the same cycle as STB (combinational path)
- Pipelined (B4): ACK one cycle after STB (registered, better timing)

This implementation uses the pipelined variant with byte-select support.

> **File:** `rtl_examples/05_bus_protocols/wishbone_slave.sv`

### 7.3 Round-Robin Arbiter (`round_robin_arbiter.sv`)

Ensures fair access when multiple masters compete for a shared resource.

**Algorithm:**
1. Maintain a `mask` that suppresses recently-granted and lower-priority requests
2. Run two priority encoders: one on masked requests, one on unmasked
3. If the masked encoder finds a request, grant it (round-robin)
4. Otherwise, fall back to the unmasked encoder (wrap around)
5. Update the mask to start scanning after the last grant

This guarantees that no requestor can starve others — each will be served within N cycles.

> **File:** `rtl_examples/05_bus_protocols/round_robin_arbiter.sv`

### 7.4 APB Master (`apb_master.sv`)

The AMBA Advanced Peripheral Bus (APB) is designed for low-bandwidth peripherals. The protocol has two phases:

```
 IDLE ──cmd_valid──> SETUP ──────> ACCESS ──pready──> IDLE/SETUP
                      PSEL=1         PSEL=1
                      PENABLE=0      PENABLE=1
```

This master translates simple command-interface transactions (valid/addr/data/ready) into proper APB protocol signaling.

> **File:** `rtl_examples/05_bus_protocols/apb_master.sv`

---

## 8. Advanced Design Techniques

### 8.1 Pipelined Multiplier (`pipelined_multiplier.sv`)

Pipelining trades latency for throughput. This 4-stage multiplier processes one multiplication per clock cycle (after the initial pipeline fill delay).

**Pipeline stages:**

```
  Stage 0: Capture inputs
  Stage 1: Multiply a[3:0] × b, accumulate
  Stage 2: Multiply a[7:4] × b, shift left 4, accumulate
  Stage 3: Multiply a[11:8] × b, shift left 8, accumulate
  Stage 4: Multiply a[15:12] × b, shift left 12, accumulate → result
```

**When to pipeline:**
- The combinational delay of a single-cycle multiplier exceeds the clock period budget
- High throughput (one result/cycle) matters more than low latency
- The pipeline stages are roughly balanced in delay

> **File:** `rtl_examples/06_advanced_designs/pipelined_multiplier.sv`

### 8.2 Clock Domain Crossing (CDC) (`clock_domain_crossing.sv`)

CDC is one of the most critical aspects of multi-clock digital design. Getting it wrong causes metastability — a condition where flip-flops enter an undefined state, potentially corrupting data paths.

This file contains three CDC primitives:

#### Two-Flop Synchronizer (single-bit)

The simplest CDC circuit. Two back-to-back flip-flops in the destination domain give the metastable first flop time to resolve before the signal is used.

```
  async_in ──┤D Q├──┤D Q├── sync_out
             └───┘  └───┘
             clk_dest   clk_dest
```

**Limitations:** Only safe for single-bit, level-type signals. The signal must be stable for at least one destination clock period.

#### Pulse Synchronizer

Transfers a single-cycle pulse from one domain to another using a toggle technique:

```
  Source domain:   pulse_in → toggle register
  Synchronizer:   2-flop sync of toggle
  Dest domain:    edge detect on sync'd toggle → pulse_out
```

#### Handshake Synchronizer (multi-bit)

For multi-bit data, direct synchronization is unsafe — bits may be sampled at different moments. The handshake approach uses req/ack signaling:

```
  Source: data_hold ←── src_data (captured once)
          req ──────────────────────> [2FF sync] ──> req_sync
          ack <── [2FF sync] <──────────────────── ack
```

The data is held stable while `req` is high, ensuring the destination reads a consistent value.

> **File:** `rtl_examples/06_advanced_designs/clock_domain_crossing.sv`

### 8.3 UART Transceiver (`uart_transceiver.sv`)

A complete UART (Universal Asynchronous Receiver/Transmitter) implementation in 8N1 format.

**Transmitter FSM:**

```
  IDLE ──tx_valid──> START ──1 bit──> DATA ──8 bits──> STOP ──1 bit──> DONE → IDLE
           │            │               │                │
         TX=1         TX=0           TX=data[i]        TX=1
```

**Receiver design challenges:**
- **Metastability:** RX input passes through a 2-flop synchronizer
- **Mid-bit sampling:** After detecting the start bit falling edge, wait half a bit period to sample at the center of each bit
- **Framing error detection:** Verify the stop bit is high

**Baud rate generation:** A counter divides the system clock to the baud period: `CLKS_PER_BIT = CLK_FREQ / BAUD_RATE`.

> **File:** `rtl_examples/06_advanced_designs/uart_transceiver.sv`

### 8.4 SPI Master (`spi_master.sv`)

Implements the Serial Peripheral Interface protocol with support for all four SPI modes:

| Mode | CPOL | CPHA | Sample Edge | Shift Edge |
|------|------|------|-------------|------------|
| 0 | 0 | 0 | Rising | Falling |
| 1 | 0 | 1 | Falling | Rising |
| 2 | 1 | 0 | Falling | Rising |
| 3 | 1 | 1 | Rising | Falling |

**CPOL** sets the idle clock polarity. **CPHA** determines whether data is sampled on the leading or trailing clock edge. The `spi_master` dynamically selects sample/shift behavior based on runtime `cpol`/`cpha` inputs.

> **File:** `rtl_examples/06_advanced_designs/spi_master.sv`

### 8.5 CORDIC Engine (`cordic_engine.sv`)

The CORDIC (COordinate Rotation Digital Computer) algorithm computes trigonometric functions using only shifts and additions — no multiplier required.

**Algorithm:**
1. Start with the vector (K, 0) where K ≈ 0.6073 is the CORDIC gain
2. Iteratively rotate toward the target angle using pre-computed arctan values
3. Each iteration: if remaining angle is positive, rotate clockwise; otherwise counterclockwise
4. After N iterations: x ≈ cos(θ), y ≈ sin(θ)

```
  x[i+1] = x[i] - d[i] * y[i] * 2^(-i)
  y[i+1] = y[i] + d[i] * x[i] * 2^(-i)
  z[i+1] = z[i] - d[i] * atan(2^(-i))

  where d[i] = +1 if z[i] >= 0, else -1
```

Multiplications by 2^(-i) are implemented as arithmetic right shifts, making CORDIC extremely efficient in hardware.

> **File:** `rtl_examples/06_advanced_designs/cordic_engine.sv`

### 8.6 PWM Generator (`pwm_generator.sv`)

Generates Pulse Width Modulated signals for motor control and power conversion. Features:
- Configurable resolution (default 10-bit = 1024 duty levels)
- Complementary output with dead-time insertion to prevent shoot-through in H-bridge circuits

**Dead-time insertion:**

```
  PWM transition detected → both outputs LOW for DEAD_TIME cycles → normal operation resumes
```

This prevents brief moments when both high-side and low-side transistors conduct simultaneously, which would short the supply rails.

> **File:** `rtl_examples/06_advanced_designs/pwm_generator.sv`

### 8.7 Watchdog Timer (`watchdog_timer.sv`)

A safety mechanism that resets the system if software stops responding. The counter increments continuously; software must periodically "kick" it to reset the count. If the count reaches the timeout threshold, a reset signal is asserted.

The two-stage design provides an early `warning` signal (at 75% of timeout) so software can attempt recovery before the hard timeout fires.

> **File:** `rtl_examples/06_advanced_designs/watchdog_timer.sv`

---

## 9. Verification with Testbenches

### 9.1 ALU Testbench (`tb_alu_32bit.sv`)

Combines directed tests (specific corner cases) with random stimulus:

```systemverilog
// Directed: verify arithmetic right shift preserves sign
operand_a = 32'h8000_0000;   // Negative number
operand_b = 32'h0000_0004;   // Shift by 4
alu_op    = ALU_SRA;
// Expected: 32'hF800_0000 (sign-extended)

// Random: 20 randomized ADD operations
for (int i = 0; i < 20; i++) begin
    operand_a = $urandom;
    operand_b = $urandom;
    expected  = operand_a + operand_b;
    check("ADD_RAND", expected);
end
```

> **File:** `rtl_examples/07_testbenches/tb_alu_32bit.sv`

### 9.2 Sync FIFO Testbench (`tb_sync_fifo.sv`)

Exercises the complete FIFO lifecycle:
1. Verify empty flag after reset
2. Fill completely and verify full flag
3. Read all entries and verify data ordering (FIFO property)
4. Test simultaneous read/write operations

> **File:** `rtl_examples/07_testbenches/tb_sync_fifo.sv`

### 9.3 UART Loopback Test (`tb_uart_loopback.sv`)

Connects TX output to RX input and verifies bit-accurate data transfer:

```systemverilog
task automatic send_byte(input logic [7:0] data);
    tx_valid = 1; tx_data = data;
    @(posedge clk);
    tx_valid = 0;
    wait (!tx_busy);           // Wait for TX to finish
    @(posedge rx_valid);       // Wait for RX to capture
    assert (rx_data === data); // Verify integrity
endtask
```

Tests all-zeros, all-ones, alternating patterns, and sequential values.

> **File:** `rtl_examples/07_testbenches/tb_uart_loopback.sv`

### 9.4 FSM Comparison Test (`tb_fsm_sequence_detector.sv`)

Drives the same bit stream through both Moore and Mealy detectors simultaneously, printing a side-by-side comparison to illustrate the timing difference (Mealy detects one cycle earlier).

> **File:** `rtl_examples/07_testbenches/tb_fsm_sequence_detector.sv`

### 9.5 Arbiter Fairness Test (`tb_round_robin_arbiter.sv`)

Verifies round-robin fairness by running all 4 requestors simultaneously for 16 cycles and checking that each receives approximately 4 grants.

> **File:** `rtl_examples/07_testbenches/tb_round_robin_arbiter.sv`

---

## 10. RTL Design Best Practices

### Synthesizability

| Do | Avoid |
|---|---|
| `always_ff` for flip-flops | `initial` blocks (not synthesizable) |
| `always_comb` for combinational logic | `#delay` statements |
| Fully specified `case`/`if-else` | Incomplete case (infers latches) |
| Reset all flip-flops | Unreset state (undefined startup) |
| Parameterize widths and depths | Hard-coded magic numbers |

### Clock Domain Crossing Rules

1. **Never** connect signals between clock domains without synchronization
2. Use **2-flop synchronizers** for single-bit level signals
3. Use **pulse synchronizers** for single-cycle events
4. Use **async FIFOs** or **handshake protocols** for multi-bit data
5. Use **Gray coding** for multi-bit counters that cross domains
6. Constrain CDC paths with `set_false_path` or `set_max_delay` in timing constraints

### FSM Coding Style

```systemverilog
// Three-process FSM (recommended for clarity)

// Process 1: State register
always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) state <= IDLE;
    else        state <= next_state;

// Process 2: Next-state logic (combinational)
always_comb begin
    next_state = state;  // Default: hold state
    case (state) ... endcase
end

// Process 3: Output logic (combinational for Moore)
always_comb begin
    outputs = defaults;
    case (state) ... endcase
end
```

### Naming Conventions

| Convention | Example |
|---|---|
| Active-low signals | `rst_n`, `cs_n`, `wr_n` |
| Clock signals | `clk`, `clk_50mhz`, `aclk` |
| Parameters | `DATA_WIDTH`, `NUM_STAGES` |
| Enum types | `state_e`, `alu_op_e` (suffix `_e`) |
| Generate blocks | `gen_pipeline`, `gen_cla` (prefix `gen_`) |
| Testbench modules | `tb_module_name` (prefix `tb_`) |

### Avoiding Common Pitfalls

1. **Unintended latches:** Always assign defaults at the top of `always_comb`, or use `default` in `case` statements
2. **Multiple drivers:** Each signal should be driven by exactly one `always` block or `assign`
3. **Blocking in `always_ff`:** Always use nonblocking (`<=`) for sequential logic
4. **Missing reset:** Every flip-flop should have a defined reset value
5. **Async reset glitches:** De-assert asynchronous resets synchronously (reset synchronizer)

---

## 11. Running the Examples

### Using Icarus Verilog (Open Source)

```bash
# Install
sudo apt-get install iverilog

# Compile and run a testbench
iverilog -g2012 -o sim.vvp \
    rtl_examples/01_combinational_logic/alu_32bit.sv \
    rtl_examples/07_testbenches/tb_alu_32bit.sv
vvp sim.vvp

# FIFO testbench
iverilog -g2012 -o sim.vvp \
    rtl_examples/02_sequential_logic/sync_fifo.sv \
    rtl_examples/07_testbenches/tb_sync_fifo.sv
vvp sim.vvp

# UART loopback
iverilog -g2012 -o sim.vvp \
    rtl_examples/06_advanced_designs/uart_transceiver.sv \
    rtl_examples/07_testbenches/tb_uart_loopback.sv
vvp sim.vvp

# FSM comparison
iverilog -g2012 -o sim.vvp \
    rtl_examples/03_fsm_designs/moore_fsm_sequence_detector.sv \
    rtl_examples/03_fsm_designs/mealy_fsm_sequence_detector.sv \
    rtl_examples/07_testbenches/tb_fsm_sequence_detector.sv
vvp sim.vvp

# Round-robin arbiter
iverilog -g2012 -o sim.vvp \
    rtl_examples/05_bus_protocols/round_robin_arbiter.sv \
    rtl_examples/07_testbenches/tb_round_robin_arbiter.sv
vvp sim.vvp
```

### Using Synopsys VCS

```bash
vcs -sverilog -full64 \
    rtl_examples/01_combinational_logic/alu_32bit.sv \
    rtl_examples/07_testbenches/tb_alu_32bit.sv \
    -o simv
./simv
```

### Using Cadence Xcelium

```bash
xrun -sv \
    rtl_examples/01_combinational_logic/alu_32bit.sv \
    rtl_examples/07_testbenches/tb_alu_32bit.sv
```

### Using Verilator (Lint and Simulation)

```bash
# Lint check (fast, no simulation)
verilator --lint-only -Wall --sv \
    rtl_examples/01_combinational_logic/alu_32bit.sv

# Lint all files
find rtl_examples -name "*.sv" ! -name "tb_*" -exec \
    verilator --lint-only --sv {} \;
```

### Generating Waveforms

Add these lines to your testbench to generate VCD waveform files viewable in GTKWave:

```systemverilog
initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_alu_32bit);
end
```

Then view with:

```bash
gtkwave waveform.vcd
```

---

## License

This tutorial and all accompanying code examples are provided for educational purposes. Feel free to use, modify, and distribute them in your projects.
