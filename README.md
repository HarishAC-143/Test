# Advanced Digital System Design: RTL Implementation with SystemVerilog

A comprehensive, hands-on tutorial covering advanced RTL design techniques using SystemVerilog. Each topic includes production-quality RTL source code, testbenches, and detailed explanations of the underlying concepts.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [SystemVerilog Language Fundamentals for RTL](#2-systemverilog-language-fundamentals-for-rtl)
3. [Parameterized Synchronous FIFO](#3-parameterized-synchronous-fifo)
4. [Advanced Finite State Machines](#4-advanced-finite-state-machines)
5. [Multi-Stage Pipelined ALU with Forwarding](#5-multi-stage-pipelined-alu-with-forwarding)
6. [Asynchronous FIFO for Clock Domain Crossing](#6-asynchronous-fifo-for-clock-domain-crossing)
7. [AXI4-Lite Slave Register Interface](#7-axi4-lite-slave-register-interface)
8. [Round-Robin Arbiter with Priority Override](#8-round-robin-arbiter-with-priority-override)
9. [SPI Master Controller](#9-spi-master-controller)
10. [CRC Generator (CRC-32)](#10-crc-generator-crc-32)
11. [Radix-4 Booth Multiplier](#11-radix-4-booth-multiplier)
12. [Direct-Mapped Cache Controller](#12-direct-mapped-cache-controller)
13. [RTL Design Best Practices](#13-rtl-design-best-practices)
14. [Running the Examples](#14-running-the-examples)

---

## 1. Introduction

Register Transfer Level (RTL) design is the cornerstone of digital hardware development. It describes hardware behavior in terms of data flow between registers and the combinational logic that transforms that data. SystemVerilog extends classical Verilog with powerful features that make RTL code more readable, maintainable, and verifiable.

### What This Tutorial Covers

This tutorial focuses on **advanced** RTL design patterns that appear in real-world ASIC and FPGA projects:

- **Parameterized, reusable modules** using SystemVerilog generics
- **Complex FSMs** for protocol handling (AXI-Stream packet processing)
- **Pipelined datapaths** with hazard detection and forwarding
- **Clock domain crossing** using asynchronous FIFOs with Gray code pointers
- **Industry-standard bus protocols** (AXI4-Lite slave implementation)
- **Arbitration schemes** (round-robin with priority override)
- **Serial protocol controllers** (SPI master with CPOL/CPHA support)
- **Error detection** (parallel CRC-32 generator)
- **Advanced arithmetic** (Radix-4 Booth multiplier)
- **Memory subsystem design** (write-back cache controller)

### Repository Structure

```
.
├── README.md               # This tutorial
├── rtl/                    # Synthesizable RTL source files
│   ├── parameterized_fifo.sv
│   ├── advanced_fsm.sv
│   ├── pipelined_alu.sv
│   ├── async_fifo.sv
│   ├── axi_lite_slave.sv
│   ├── round_robin_arbiter.sv
│   ├── spi_master.sv
│   ├── crc_generator.sv
│   ├── booth_multiplier.sv
│   └── cache_controller.sv
└── tb/                     # Testbenches
    ├── tb_parameterized_fifo.sv
    ├── tb_advanced_fsm.sv
    ├── tb_pipelined_alu.sv
    ├── tb_async_fifo.sv
    ├── tb_axi_lite_slave.sv
    ├── tb_round_robin_arbiter.sv
    ├── tb_spi_master.sv
    ├── tb_crc_generator.sv
    ├── tb_booth_multiplier.sv
    └── tb_cache_controller.sv
```

---

## 2. SystemVerilog Language Fundamentals for RTL

Before diving into advanced designs, here is a summary of key SystemVerilog features used throughout this tutorial.

### 2.1 Data Types

```systemverilog
// 4-state types (0, 1, x, z) — used in RTL for synthesis
logic        single_bit;
logic [31:0] bus;

// 2-state types (0, 1) — faster simulation, not synthesizable for I/O
bit          fast_bit;
int          counter;       // 32-bit signed
shortint     small;         // 16-bit signed

// Packed arrays (contiguous bit vectors, synthesizable)
logic [3:0][7:0] packed_word;  // 32 bits: 4 bytes packed together

// Unpacked arrays (memory-like, synthesizable)
logic [7:0] memory [256];     // 256-entry memory, 8 bits each
```

### 2.2 Structs, Enums, Typedefs, and Packages

```systemverilog
// Package: groups related types for reuse
package my_pkg;
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        ACTIVE = 2'b01,
        DONE   = 2'b10
    } state_e;

    typedef struct packed {
        logic [15:0] address;
        logic [7:0]  data;
        logic        valid;
    } transaction_t;
endpackage

// Usage in a module
module my_module
    import my_pkg::*;
( /* ports */ );
    state_e       current_state;
    transaction_t txn;
endmodule
```

### 2.3 Always Blocks in SystemVerilog

SystemVerilog distinguishes between combinational, sequential, and latch-based logic:

```systemverilog
// Combinational logic (replaces always @(*))
always_comb begin
    y = a & b;
end

// Sequential logic (clocked flip-flops)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// Latch inference (rarely used intentionally)
always_latch begin
    if (enable)
        q <= d;
end
```

### 2.4 Unique and Priority Case

```systemverilog
// unique case: exactly one branch must match (synthesis tool optimizes)
always_comb begin
    unique case (sel)
        2'b00: out = a;
        2'b01: out = b;
        2'b10: out = c;
        2'b11: out = d;
    endcase
end

// priority case: first matching branch wins
always_comb begin
    priority case (1'b1)
        req[3]: grant = 4'b1000;
        req[2]: grant = 4'b0100;
        req[1]: grant = 4'b0010;
        req[0]: grant = 4'b0001;
        default: grant = 4'b0000;
    endcase
end
```

### 2.5 Generate Blocks

```systemverilog
module replicated_unit #(parameter int N = 4) ( /* ports */ );
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_units
            processing_element pe_inst (
                .data_in  (data[i]),
                .data_out (result[i])
            );
        end
    endgenerate
endmodule
```

### 2.6 Interfaces and Modports

```systemverilog
interface axi_stream_if #(parameter int DATA_W = 32) (input logic clk);
    logic [DATA_W-1:0] tdata;
    logic              tvalid;
    logic              tready;
    logic              tlast;

    modport master (output tdata, tvalid, tlast, input tready);
    modport slave  (input tdata, tvalid, tlast, output tready);
endinterface
```

### 2.7 SystemVerilog Assertions (SVA)

```systemverilog
// Immediate assertion
assert (count <= MAX) else $error("Counter overflow!");

// Concurrent assertion (checked every clock edge)
property req_ack_handshake;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##[1:3] ack;  // ack must come within 1-3 cycles of req
endproperty
assert property (req_ack_handshake);

// Cover property (measures functional coverage)
cover property (@(posedge clk) state == IDLE ##1 state == ACTIVE);
```

---

## 3. Parameterized Synchronous FIFO

**Source:** `rtl/parameterized_fifo.sv` | **Testbench:** `tb/tb_parameterized_fifo.sv`

### Concept

FIFOs are the most fundamental building block in digital design, used for rate-matching, data buffering, and pipeline decoupling. This implementation demonstrates parameterization, pointer-based FIFO management, and inline assertions.

### Architecture

```
          ┌─────────────────────────────────────┐
 wr_en ──>│   ┌─────────────────────────────┐   │──> full
wr_data ─>│   │   Dual-Port Memory Array    │   │──> almost_full
          │   │   mem[0..DEPTH-1]            │   │──> count
 rd_en ──>│   └─────────────────────────────┘   │──> empty
          │       ↑wr_ptr          ↑rd_ptr      │──> almost_empty
          │   ┌───┴───┐       ┌───┴───┐         │
          │   │ Write │       │ Read  │         │
          │   │ Logic │       │ Logic │         │──> rd_data
          └───┴───────┴───────┴───────┴─────────┘
```

### Key Design Decisions

**Pointer Scheme:** Both `wr_ptr` and `rd_ptr` are one bit wider than the address width. The MSB serves as a "wrap bit" — when both pointers have the same address bits but different MSBs, the FIFO is full. When both pointers are identical, the FIFO is empty.

```systemverilog
assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
               (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
assign empty = (wr_ptr == rd_ptr);
assign count = wr_ptr - rd_ptr;
```

**Parameterization:** The FIFO depth, data width, and threshold values are all configurable:

```systemverilog
module parameterized_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ALMOST_FULL_THRESH  = DEPTH - 2,
    parameter int ALMOST_EMPTY_THRESH = 2
) ( /* ports */ );
```

**Inline SVA:** Assertions guard against illegal operations:

```systemverilog
property no_write_when_full;
    @(posedge clk) disable iff (!rst_n)
    (full && wr_en) |-> $stable(wr_ptr);
endproperty
assert property (no_write_when_full);
```

### Practical Insight

In real designs, FIFO depth is often chosen as a power of 2 for efficient pointer comparison. The `$clog2()` function automatically computes the required address width. The almost-full/almost-empty thresholds are critical for flow control — upstream producers use `almost_full` to stop writing before overflow occurs.

---

## 4. Advanced Finite State Machines

**Source:** `rtl/advanced_fsm.sv` | **Testbench:** `tb/tb_advanced_fsm.sv`

### Concept

This module implements an AXI-Stream packet processor — a realistic FSM that receives streaming packets, parses headers, forwards valid payloads, and handles error conditions. It demonstrates enum-based state encoding, packed structs for header parsing, and functional coverage collection.

### State Diagram

```
                ┌──────────┐
    ┌──────────>│   IDLE   │
    │           └────┬─────┘
    │                │ tvalid
    │           ┌────▼─────┐
    │           │  HEADER  │──── type==ERROR ──> DROP
    │           └────┬─────┘                      │
    │                │ length>0                    │ tlast
    │           ┌────▼─────┐                      │
    │           │ PAYLOAD  │──── premature ───> ERROR
    │           └────┬─────┘    tlast              │
    │                │ count==0                    │
    │           ┌────▼─────┐                      │
    │           │ TRAILER  │──── missing ────> ERROR
    │           └────┬─────┘    tlast              │
    │                │ tlast                       │
    └────────────────┘ <───────────────────────────┘
```

### Key Design Patterns

**Enum-based states** produce readable RTL and better synthesis:

```systemverilog
typedef enum logic [2:0] {
    ST_IDLE, ST_HEADER, ST_PAYLOAD, ST_TRAILER, ST_ERROR, ST_DROP
} state_e;
```

**Packed structs** for protocol headers let you overlay bitfields naturally:

```systemverilog
typedef struct packed {
    logic [15:0] length;
    logic [7:0]  src_id;
    logic [7:0]  dst_id;
    pkt_type_e   pkt_type;
    logic [4:0]  reserved;
} pkt_header_t;
```

**Two-process FSM pattern:** State transitions are in a combinational block (`always_comb`), while outputs and datapath updates are in a sequential block (`always_ff`). This separation is recommended for clarity and to avoid unintended latches.

**Covergroups** track which states and transitions have been exercised:

```systemverilog
covergroup fsm_cg @(posedge clk);
    cp_transitions: coverpoint state {
        bins idle_to_header    = (ST_IDLE => ST_HEADER);
        bins header_to_payload = (ST_HEADER => ST_PAYLOAD);
        // ...
    }
endgroup
```

---

## 5. Multi-Stage Pipelined ALU with Forwarding

**Source:** `rtl/pipelined_alu.sv` | **Testbench:** `tb/tb_pipelined_alu.sv`

### Concept

Pipelining is the most important performance optimization in digital design. This ALU demonstrates a 2-stage pipeline with data forwarding, flush, and stall support — the same concepts used in CPU microarchitecture.

### Pipeline Stages

```
  ┌─────────────────┐    ┌──────────────────┐    ┌──────────────┐
  │   Stage 0        │    │   Stage 1         │    │   Stage 2    │
  │   (Input)        │───>│   (Execute)       │───>│   (Output)   │
  │                  │    │                   │    │              │
  │ - Register       │    │ - ALU Operation   │    │ - Result     │
  │   operands       │    │ - Forwarding MUX  │    │   latch      │
  │ - Detect hazards │    │ - Overflow detect │    │ - Valid flag  │
  └─────────────────┘    └──────────────────┘    └──────────────┘
        ↑                                              │
        └──────── Forwarding Path ─────────────────────┘
```

### Supported Operations

The ALU implements a RISC-V style instruction set via enum encoding:

```systemverilog
typedef enum logic [3:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
    ALU_SLL, ALU_SRL, ALU_SRA,
    ALU_SLT, ALU_SLTU,
    ALU_MUL, ALU_MULH
} alu_op_e;
```

### Pipeline Hazard Handling

- **Data forwarding:** When a result from a previous instruction is needed, the forwarding MUX bypasses the register file.
- **Stall:** When a structural hazard is detected, the `stall` signal freezes all pipeline registers.
- **Flush:** Branch mispredictions clear the pipeline by resetting all valid bits.

```systemverilog
// Forwarding MUX in pipeline stage 1
stage1.operand_a <= (fwd_valid && fwd_addr == rd_addr_in) ?
                     fwd_data : operand_a;
```

---

## 6. Asynchronous FIFO for Clock Domain Crossing

**Source:** `rtl/async_fifo.sv` | **Testbench:** `tb/tb_async_fifo.sv`

### Concept

When data must cross between two clock domains, a direct connection causes metastability. The asynchronous FIFO safely transfers data by using **Gray code pointers** and **double-flop synchronizers**.

### Architecture

```
  Write Clock Domain          │         Read Clock Domain
  ─────────────────           │         ─────────────────
                              │
  wr_ptr_bin ──> bin2gray ──> wr_ptr_gray ──> [sync] ──> wr_ptr_gray_sync
                              │                              │
                              │                              ▼
              ┌───────────────┼────────────────┐        empty = (rd_gray == wr_gray_sync)
              │   Dual-Port   │   Memory       │
              │   mem[0..N-1] │                │
              └───────────────┼────────────────┘
                              │
  full = (wr_gray_msb !=     │
          rd_gray_sync_msb)   │
          && (rest match)     │
                              │
  rd_ptr_gray_sync <── [sync] <── rd_ptr_gray <── bin2gray <── rd_ptr_bin
```

### Why Gray Code?

Binary counters can change multiple bits simultaneously (e.g., `0111 → 1000` changes all 4 bits). If sampled mid-transition by a different clock, the synchronized value could be wildly wrong. Gray code guarantees only **one bit changes per increment**, making metastability affect at most one bit and yielding a value that is either the old or new count — both are safe.

```systemverilog
function automatic logic [PTR_WIDTH-1:0] bin2gray(
    input logic [PTR_WIDTH-1:0] bin
);
    return bin ^ (bin >> 1);
endfunction
```

### Double-Flop Synchronizer

The `gray_code_sync` module passes Gray-coded pointers through two flip-flops clocked by the destination domain. This reduces the probability of metastability to negligible levels:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_stage1 <= '0;
        sync_stage2 <= '0;
    end else begin
        sync_stage1 <= data_in;
        sync_stage2 <= sync_stage1;
    end
end
```

### Practical Insight

The full/empty flags are **conservative**: they may briefly indicate "full" when space exists or "empty" when data is available (due to synchronization latency). This is safe — it merely reduces effective throughput slightly rather than causing data corruption.

---

## 7. AXI4-Lite Slave Register Interface

**Source:** `rtl/axi_lite_slave.sv` | **Testbench:** `tb/tb_axi_lite_slave.sv`

### Concept

AXI4-Lite is the industry-standard register-access bus used by ARM AMBA interconnects. This module provides a reusable register bank that can be connected to any IP core, handling the full AXI4-Lite handshake protocol.

### AXI4-Lite Channel Architecture

```
                   ┌───────────────────────────┐
                   │     AXI-Lite Slave         │
   AW Channel ───>│  ┌─────────────────────┐   │
   (Write Addr)    │  │  Write FSM          │   │──> reg_out[0..N-1]
                   │  │  IDLE→DATA→RESP     │   │
    W Channel ───>│  └─────────────────────┘   │──> reg_wr_en[0..N-1]
   (Write Data)    │                            │
                   │  ┌─────────────────────┐   │
    B Channel <───│  │  Register Array      │   │<── reg_in[0..N-1]
   (Write Resp)    │  │  registers[0..N-1]  │   │
                   │  └─────────────────────┘   │
   AR Channel ───>│                            │
   (Read Addr)     │  ┌─────────────────────┐   │
                   │  │  Read FSM           │   │
    R Channel <───│  │  IDLE→DATA          │   │
   (Read Data)     │  └─────────────────────┘   │
                   └───────────────────────────┘
```

### Key Features

**SystemVerilog Interface with Modports** (defined alongside the module):

```systemverilog
interface axi_lite_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (input logic aclk, input logic aresetn);

    modport master (
        output awaddr, awvalid, wdata, wstrb, wvalid, bready,
               araddr, arvalid, rready,
        input  awready, wready, bresp, bvalid,
               arready, rdata, rresp, rvalid
    );

    modport slave ( /* reverse of master */ );
endinterface
```

**Byte-lane write strobes** allow partial register updates:

```systemverilog
for (int i = 0; i < DATA_WIDTH/8; i++) begin
    if (s_axi_wstrb[i])
        registers[wr_reg_idx][i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
end
```

**Separate read/write FSMs** handle independent AXI channels concurrently, improving bus utilization.

---

## 8. Round-Robin Arbiter with Priority Override

**Source:** `rtl/round_robin_arbiter.sv` | **Testbench:** `tb/tb_round_robin_arbiter.sv`

### Concept

Bus arbitration decides which of multiple requestors gains access to a shared resource. Round-robin provides fairness, while priority override handles urgent traffic. This pattern is used in network switches, memory controllers, and DMA engines.

### Algorithm

```
  req[3:0] ──────────────────┐
                              ▼
  priority_req[3:0] ──> [ Priority     ] ──> grant (if priority active)
                        [ Encoder      ]
                              │
                              ▼ (if no priority)
  mask[3:0] ──────────> [ Masked       ] ──> grant (round-robin)
                        [ Priority Enc ]
                              │
                              ▼ (if no masked match)
                        [ Unmasked     ] ──> grant (wrap-around)
                        [ Priority Enc ]
                              │
                              ▼
                        [ Update Mask  ] ──> mask = bits above granted position
```

### Mask-Based Round-Robin

The mask register tracks which requestors have been served. After granting to requestor `i`, the mask clears bits 0 through `i`, forcing the next grant to go to a higher-numbered requestor. When no masked requests remain, the arbiter wraps around.

```systemverilog
// After granting position i, mask out positions 0..i
mask <= ({NUM_REQUESTORS{1'b1}} << (i + 1));
```

### One-Hot Grant Assertion

An SVA assertion ensures correctness at all times:

```systemverilog
assert property (@(posedge clk) disable iff (!rst_n)
    $onehot0(grant)
) else $error("Multiple grants asserted simultaneously!");
```

---

## 9. SPI Master Controller

**Source:** `rtl/spi_master.sv` | **Testbench:** `tb/tb_spi_master.sv`

### Concept

SPI (Serial Peripheral Interface) is a ubiquitous 4-wire serial protocol. This master controller supports all four SPI modes (CPOL/CPHA combinations) and uses a configurable clock divider for baud-rate generation.

### SPI Modes

| Mode | CPOL | CPHA | Clock Idle | Sample Edge | Shift Edge |
|------|------|------|-----------|------------|------------|
| 0    | 0    | 0    | Low       | Rising     | Falling    |
| 1    | 0    | 1    | Low       | Falling    | Rising     |
| 2    | 1    | 0    | High      | Falling    | Rising     |
| 3    | 1    | 1    | High      | Rising     | Falling    |

### Timing Diagram

```
         ┌──────────────────────────────────────────────┐
  CS_N   ┘                                              └──────
         │<-- LOAD -->|<--------- TRANSFER ----------->|COMPLETE
  SCLK   ─────────────┐   ┌───┐   ┌───┐   ┌───┐   ┌──┘
                       └───┘   └───┘   └───┘   └───┘
  MOSI   ──────────────< B7 >< B6 >< B5 >...< B0 >──────
  MISO   ──────────────< D7 >< D6 >< D5 >...< D0 >──────
```

### Clock Generation with CPOL/CPHA

The internal clock toggles at the configured rate, then XOR with CPOL produces the actual SCLK polarity. CPHA selects which edge samples vs. shifts:

```systemverilog
assign sclk = sclk_int ^ cpol;
assign sample_edge = sclk_edge && (sclk_int == cpha);
assign shift_edge  = sclk_edge && (sclk_int != cpha);
```

---

## 10. CRC Generator (CRC-32)

**Source:** `rtl/crc_generator.sv` | **Testbench:** `tb/tb_crc_generator.sv`

### Concept

Cyclic Redundancy Check detects errors in data transmission and storage. This implementation uses the CRC-32/Ethernet polynomial and processes data in parallel — one full byte per clock cycle — making it suitable for high-throughput applications.

### How Parallel CRC Works

A serial CRC processes one bit per cycle through an LFSR (Linear Feedback Shift Register). For higher throughput, the LFSR equations are "unrolled" so that all bits of a data word are processed simultaneously:

```systemverilog
// Single-bit LFSR step
function automatic logic [CRC_WIDTH-1:0] crc_step(
    input logic [CRC_WIDTH-1:0] crc_in,
    input logic data_bit
);
    logic feedback;
    feedback = crc_in[CRC_WIDTH-1] ^ data_bit;
    crc_step = {crc_in[CRC_WIDTH-2:0], 1'b0} ^ (feedback ? POLYNOMIAL : '0);
endfunction

// Parallel: unroll DATA_WIDTH serial steps into one combinational function
function automatic logic [CRC_WIDTH-1:0] crc_parallel(
    input logic [CRC_WIDTH-1:0]  crc_in,
    input logic [DATA_WIDTH-1:0] data
);
    logic [CRC_WIDTH-1:0] crc_tmp;
    crc_tmp = crc_in;
    for (int i = DATA_WIDTH - 1; i >= 0; i--)
        crc_tmp = crc_step(crc_tmp, data[i]);
    return crc_tmp;
endfunction
```

### Practical Insight

The `for` loop in `crc_parallel` is fully unrolled by synthesis into a purely combinational XOR tree. There is no iteration at runtime — the loop just describes the structure of the XOR network. The Ethernet standard requires initialization to all-1s and final bit inversion:

```systemverilog
// Init
crc_reg <= '1;
// Output
assign crc_out = ~crc_reg;
```

---

## 11. Radix-4 Booth Multiplier

**Source:** `rtl/booth_multiplier.sv` | **Testbench:** `tb/tb_booth_multiplier.sv`

### Concept

Booth's algorithm performs signed multiplication by encoding the multiplier into a series of additions and subtractions, reducing the number of partial products. Radix-4 Booth encoding examines 3 bits at a time, halving the number of iterations compared to the basic algorithm.

### Radix-4 Booth Encoding Table

| Bits [i+1, i, i-1] | Operation | Explanation |
|---------------------|-----------|-------------|
| 000                 | +0        | No operation |
| 001                 | +M        | Add multiplicand |
| 010                 | +M        | Add multiplicand |
| 011                 | +2M       | Add 2x multiplicand |
| 100                 | -2M       | Subtract 2x multiplicand |
| 101                 | -M        | Subtract multiplicand |
| 110                 | -M        | Subtract multiplicand |
| 111                 | +0        | No operation |

### Algorithm Flow

```
  Initialize: accumulator = {0...0, multiplier, 0}
                              │
                    ┌─────────▼──────────┐
                    │ Read booth_bits[2:0]│ <── 3 LSBs of accumulator
                    │ Compute partial     │
                    │ product from table  │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │ Add to upper half   │
                    │ Arithmetic shift    │
                    │ right by 2          │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │ Repeat WIDTH/2     │
                    │ times              │
                    └─────────┬──────────┘
                              │
                    ┌─────────▼──────────┐
                    │ Product = acc[2W:1]│
                    └────────────────────┘
```

### Practical Insight

In ASIC design, dedicated multiplier blocks are synthesized from the `*` operator. However, understanding Booth's algorithm is crucial for:
- Designing custom multipliers with specific area/timing tradeoffs
- Working with FPGAs that have limited DSP blocks
- Implementing multiply-accumulate (MAC) units for DSP applications

---

## 12. Direct-Mapped Cache Controller

**Source:** `rtl/cache_controller.sv` | **Testbench:** `tb/tb_cache_controller.sv`

### Concept

This cache controller implements a direct-mapped, write-back cache — the fundamental building block of modern memory hierarchies. It handles cache hits, compulsory misses, conflict misses, and dirty-line writebacks.

### Address Decomposition

```
 31                    TAG_BITS  INDEX_BITS OFFSET_BITS  0
 ┌────────────────────┬──────────┬──────────────────────┐
 │       TAG          │  INDEX   │   BLOCK OFFSET       │
 └────────────────────┴──────────┴──────────────────────┘
                          │              │
                          ▼              ▼
                    Select cache    Select word within
                    set/line        cache line
```

### Cache Operation FSM

```
                    ┌──────────┐
         ┌─────────│   IDLE   │<──────────────┐
         │         └────┬─────┘               │
         │              │ cpu_rd/wr           │
         │         ┌────▼─────┐               │
         │         │TAG_CHECK │               │
         │         └────┬─────┘               │
         │              │                     │
         │      ┌───────┴────────┐            │
         │      │                │            │
         │   hit?            miss?            │
         │      │                │            │
         │      ▼           dirty?───yes──> WRITEBACK ──> WRITEBACK_WAIT
         │   UPDATE              │                              │
         │      │            no  │                              │
         │      │                ▼                              │
         │      │          ALLOCATE ──> ALLOCATE_WAIT ──────────┤
         │      │                                               │
         └──────┴───────────────── UPDATE <─────────────────────┘
```

### Key Mechanisms

**Tag comparison** determines hit/miss:
```systemverilog
assign tag_match = (tag_array[addr_index] == addr_tag);
assign cache_hit = valid_array[addr_index] && tag_match;
```

**Write-back policy:** Dirty lines are written to main memory only when evicted, reducing memory bus traffic compared to write-through.

**Block allocation:** On a miss, the entire cache line (multiple words) is fetched from main memory, exploiting spatial locality.

---

## 13. RTL Design Best Practices

### 13.1 Coding Style

| Guideline | Rationale |
|-----------|-----------|
| Use `always_ff` for sequential, `always_comb` for combinational | Prevents accidental latch inference |
| Use `unique case` / `priority case` instead of plain `case` | Enables synthesis optimizations and catches FSM errors |
| Use `logic` instead of `reg`/`wire` | Single unified type reduces confusion |
| Use `'0` and `'1` for zero/one fill | Width-independent, fewer bugs during refactoring |
| Declare `localparam` for derived constants | Self-documenting, single point of change |

### 13.2 Reset Strategy

```systemverilog
// Asynchronous reset (most common in ASICs)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Synchronous reset (preferred for FPGAs)
always_ff @(posedge clk) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end
```

### 13.3 Clock Domain Crossing Rules

1. **Never** connect signals directly between clock domains.
2. Use **double-flop synchronizers** for single-bit control signals.
3. Use **async FIFOs** with Gray code pointers for multi-bit data.
4. Use **handshake protocols** for infrequent multi-bit transfers.
5. Apply **set_false_path** or **set_max_delay** constraints for synchronized paths.

### 13.4 Synthesis-Friendly Patterns

```systemverilog
// DO: Use non-blocking assignments in sequential blocks
always_ff @(posedge clk)
    q <= d;

// DON'T: Mix blocking and non-blocking in the same block
// DON'T: Use delays (#) in synthesizable code
// DON'T: Use initial blocks for synthesizable logic (use reset instead)

// DO: Fully specify all outputs in combinational blocks
always_comb begin
    out_a = '0;  // default prevents latches
    out_b = '0;
    unique case (sel)
        2'b00: out_a = in_x;
        2'b01: out_b = in_y;
        default: ;
    endcase
end
```

### 13.5 Assertion-Driven Design

Embed assertions directly in RTL modules rather than only in testbenches. This ensures invariants are checked regardless of which testbench exercises the module:

```systemverilog
// Inside a FIFO module
assert property (@(posedge clk) disable iff (!rst_n)
    !(wr_en && full)
) else $error("Write to full FIFO!");

// Inside a bus interface
assert property (@(posedge clk) disable iff (!rst_n)
    $onehot0(grant)
) else $fatal("Multiple grants!");
```

---

## 14. Running the Examples

### Prerequisites

You need a SystemVerilog simulator. Any of these will work:

| Simulator | Command | License |
|-----------|---------|---------|
| Synopsys VCS | `vcs` | Commercial |
| Cadence Xcelium | `xrun` | Commercial |
| Mentor/Siemens QuestaSim | `vsim` | Commercial |
| Icarus Verilog | `iverilog` | Open Source |
| Verilator | `verilator` | Open Source |

### Running with Icarus Verilog (Open Source)

```bash
# Compile and run the FIFO example
iverilog -g2012 -o sim_fifo rtl/parameterized_fifo.sv tb/tb_parameterized_fifo.sv
vvp sim_fifo

# Compile and run the async FIFO (CDC)
iverilog -g2012 -o sim_async_fifo rtl/async_fifo.sv tb/tb_async_fifo.sv
vvp sim_async_fifo

# Compile and run the pipelined ALU
iverilog -g2012 -o sim_alu rtl/pipelined_alu.sv tb/tb_pipelined_alu.sv
vvp sim_alu

# Compile and run the SPI master
iverilog -g2012 -o sim_spi rtl/spi_master.sv tb/tb_spi_master.sv
vvp sim_spi

# Compile and run the CRC generator
iverilog -g2012 -o sim_crc rtl/crc_generator.sv tb/tb_crc_generator.sv
vvp sim_crc

# Compile and run the Booth multiplier
iverilog -g2012 -o sim_booth rtl/booth_multiplier.sv tb/tb_booth_multiplier.sv
vvp sim_booth

# Compile and run the arbiter
iverilog -g2012 -o sim_arb rtl/round_robin_arbiter.sv tb/tb_round_robin_arbiter.sv
vvp sim_arb

# Compile and run the AXI-Lite slave
iverilog -g2012 -o sim_axi rtl/axi_lite_slave.sv tb/tb_axi_lite_slave.sv
vvp sim_axi

# Compile and run the advanced FSM
iverilog -g2012 -o sim_fsm rtl/advanced_fsm.sv tb/tb_advanced_fsm.sv
vvp sim_fsm

# Compile and run the cache controller
iverilog -g2012 -o sim_cache rtl/cache_controller.sv tb/tb_cache_controller.sv
vvp sim_cache
```

### Running with Synopsys VCS

```bash
vcs -sverilog -full64 rtl/parameterized_fifo.sv tb/tb_parameterized_fifo.sv -o sim_fifo
./sim_fifo
```

### Running with Cadence Xcelium

```bash
xrun -sv rtl/parameterized_fifo.sv tb/tb_parameterized_fifo.sv
```

### Viewing Waveforms

All testbenches generate VCD waveform files. Open them with GTKWave:

```bash
gtkwave fifo_waves.vcd
```

---

## License

This tutorial and all accompanying source code are provided for educational purposes. Use freely in your projects.
