# FPGA RTL Design with SystemVerilog: Comprehensive Tutorial

A complete guide to FPGA RTL design using SystemVerilog, covering fundamentals through advanced techniques with practical, synthesizable examples.

---

## Table of Contents

1. [Introduction to FPGA and RTL Design](#1-introduction-to-fpga-and-rtl-design)
2. [SystemVerilog Basics](#2-systemverilog-basics)
3. [Combinational Logic](#3-combinational-logic)
4. [Sequential Logic](#4-sequential-logic)
5. [Finite State Machines (FSMs)](#5-finite-state-machines-fsms)
6. [Parameterized and Reusable Modules](#6-parameterized-and-reusable-modules)
7. [Interfaces](#7-interfaces)
8. [Packages](#8-packages)
9. [SystemVerilog Assertions (SVA)](#9-systemverilog-assertions-sva)
10. [FIFO Design](#10-fifo-design)
11. [Pipeline Design](#11-pipeline-design)
12. [Clock Domain Crossing (CDC)](#12-clock-domain-crossing-cdc)
13. [Memory Design](#13-memory-design)
14. [AXI4-Lite Bus Interface](#14-axi4-lite-bus-interface)
15. [Testbench Techniques](#15-testbench-techniques)
16. [FPGA Design Best Practices](#16-fpga-design-best-practices)
17. [Common Pitfalls and How to Avoid Them](#17-common-pitfalls-and-how-to-avoid-them)
18. [FPGA Design Flow Summary](#18-fpga-design-flow-summary)

---

## 1. Introduction to FPGA and RTL Design

### What Is an FPGA?

A **Field-Programmable Gate Array (FPGA)** is an integrated circuit that can be configured after manufacturing. Unlike ASICs (Application-Specific Integrated Circuits), FPGAs can be reprogrammed to implement any digital circuit, making them ideal for prototyping, low-volume production, and applications requiring hardware flexibility.

### FPGA Architecture Overview

```
+--------------------------------------------------+
|                    FPGA Die                       |
|  +------+  +------+  +------+  +------+          |
|  | CLB  |--| CLB  |--| CLB  |--| CLB  |  I/O    |
|  +------+  +------+  +------+  +------+  Pads    |
|     |         |         |         |       +-+-+   |
|  +------+  +------+  +------+  +------+  | | |   |
|  | CLB  |--| BRAM |--| CLB  |--| DSP  |  | | |   |
|  +------+  +------+  +------+  +------+  +-+-+   |
|     |         |         |         |               |
|  +------+  +------+  +------+  +------+          |
|  | CLB  |--| CLB  |--| CLB  |--| CLB  |          |
|  +------+  +------+  +------+  +------+          |
|                                                   |
|  CLB  = Configurable Logic Block (LUTs + FFs)     |
|  BRAM = Block RAM                                 |
|  DSP  = Digital Signal Processing Block           |
+--------------------------------------------------+
```

Key FPGA resources:

| Resource | Description | Typical Use |
|----------|-------------|-------------|
| **LUT** (Look-Up Table) | Implements any combinational function of N inputs | Logic, muxes, small math |
| **Flip-Flop** (FF) | Single-bit storage element | Registers, state, pipelines |
| **Block RAM** (BRAM) | Dedicated memory blocks (typically 18Kb or 36Kb) | FIFOs, caches, buffers |
| **DSP Slice** | Hardened multiply-accumulate unit | Filters, math, AI/ML |
| **I/O** | Configurable input/output pins | External interfaces |
| **Clock Resources** | PLLs, MMCMs, clock buffers | Clock generation and distribution |
| **Routing** | Programmable interconnect fabric | Connecting all resources |

### What Is RTL Design?

**RTL (Register-Transfer Level)** is the abstraction level where you describe digital circuits in terms of:
- **Registers** (flip-flops that store data)
- **Combinational logic** (how data transforms between registers)
- **Data flow** (how data moves from register to register)

### Why SystemVerilog?

SystemVerilog (IEEE 1800) extends Verilog with features that make RTL design safer, more expressive, and more productive:

| Feature | Verilog | SystemVerilog |
|---------|---------|---------------|
| Data types | `reg`, `wire` | `logic`, `bit`, `enum`, `struct`, `union` |
| Always blocks | `always @(*)` | `always_comb`, `always_ff`, `always_latch` |
| Interfaces | Not available | Full interface support with modports |
| Assertions | Not available | SVA (immediate + concurrent) |
| Packages | Not available | Packages with types, functions, constants |
| Type checking | Weak | Strong (unique, priority case) |

---

## 2. SystemVerilog Basics

### Module Declaration

A **module** is the fundamental building block. It defines a circuit with input/output ports.

```systemverilog
module hello_world (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);
    assign data_out = data_in;
endmodule
```

> **Source:** [`examples/01_basics/hello_world.sv`](examples/01_basics/hello_world.sv)

Key points:
- `logic` replaces both `reg` and `wire` from Verilog — the compiler infers the correct type
- `[7:0]` defines an 8-bit bus (MSB:LSB)
- `assign` creates a continuous (combinational) connection
- Always use **active-low reset** (`rst_n`) — industry convention for FPGAs

### Data Types

SystemVerilog provides rich data types that improve design clarity and catch bugs at compile time:

```systemverilog
// Four-state types (0, 1, x, z) — use for RTL/synthesis
logic [7:0]  my_signal;       // Replaces reg/wire

// Two-state types (0, 1 only) — use for testbenches
bit   [7:0]  tb_var;
int          my_int;          // 32-bit signed

// Enumerated types — for state machines and opcodes
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    PAUSE = 2'b10,
    STOP  = 2'b11
} state_e;

// Structs — group related signals
typedef struct packed {
    logic [15:0] address;
    logic [7:0]  data;
    logic        valid;
    logic [6:0]  tag;
} packet_t;

// Packed arrays (contiguous bits)
logic [3:0][7:0] packed_array;    // 32 bits total

// Constants
localparam int WIDTH = 8;
localparam logic [7:0] INIT_VAL = 8'hFF;
```

> **Source:** [`examples/01_basics/data_types.sv`](examples/01_basics/data_types.sv)

### Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Signals | `snake_case` | `data_valid`, `write_enable` |
| Parameters | `UPPER_SNAKE_CASE` | `DATA_WIDTH`, `FIFO_DEPTH` |
| Types | suffix `_t` | `packet_t`, `state_t` |
| Enums | suffix `_e` | `state_e`, `opcode_e` |
| Interfaces | suffix `_if` | `axi_stream_if` |
| Active-low | suffix `_n` | `rst_n`, `cs_n` |
| Clock | prefix `clk` | `clk`, `clk_200m` |
| Instances | prefix `u_` | `u_fifo`, `u_alu` |

### Number Literals

```systemverilog
8'b1010_0011    // 8-bit binary (underscores for readability)
8'hA3           // 8-bit hexadecimal
8'd163          // 8-bit decimal
32'hDEAD_BEEF   // 32-bit hex

'0              // All zeros (width from context)
'1              // All ones
'x              // All unknown
```

---

## 3. Combinational Logic

Combinational circuits produce outputs that depend only on current inputs — there is no memory. Use `always_comb` or `assign` for combinational logic.

### Multiplexers

Multiplexers select one of several inputs based on a select signal — the most fundamental combinational building block.

```systemverilog
// 2:1 MUX — ternary operator (simplest form)
assign y = sel ? b : a;

// 4:1 MUX — always_comb with case statement
always_comb begin
    case (sel)
        2'b00:   y = a;
        2'b01:   y = b;
        2'b10:   y = c;
        2'b11:   y = d;
        default: y = '0;
    endcase
end

// 4:1 MUX — unique case (synthesis optimization hint)
always_comb begin
    unique case (sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
        2'b11: y = d;
    endcase
end
```

**`unique case` vs `case`:** `unique` tells the synthesizer that all cases are mutually exclusive and complete, enabling parallel MUX synthesis instead of priority logic. It also generates simulation warnings if an unexpected case occurs.

**`priority if` vs `if`:** `priority` tells the synthesizer that at least one condition will be true, and conditions are checked in order (priority encoding).

> **Source:** [`examples/02_combinational/mux.sv`](examples/02_combinational/mux.sv)

### ALU (Arithmetic Logic Unit)

A practical ALU demonstrating arithmetic, logic, and shift operations:

```systemverilog
module alu #(parameter int WIDTH = 32) (
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  logic [3:0]       operation,
    output logic [WIDTH-1:0] result,
    output logic             zero_flag,
    output logic             carry_flag,
    output logic             overflow_flag
);
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_SLT  = 4'b1000,
        ALU_SLTU = 4'b1001
    } alu_op_e;
    // ... operation implementation using unique case
endmodule
```

Key concepts:
- **Carry flag:** Detects unsigned overflow (result exceeds bit width)
- **Overflow flag:** Detects signed overflow (sign change on add/sub of same-sign operands)
- **Arithmetic shift (`>>>`):** Preserves sign bit (unlike logical shift `>>`)

> **Source:** [`examples/02_combinational/alu.sv`](examples/02_combinational/alu.sv)

### Decoder and Encoder

```systemverilog
// 3-to-8 Decoder: converts binary to one-hot
always_comb begin
    out = '0;
    if (enable)
        out[in] = 1'b1;
end

// Priority Encoder: casez with don't-cares
always_comb begin
    casez (in)
        8'b1???_????: out = 3'd7;
        8'b01??_????: out = 3'd6;
        // ... priority ordering
        default:      out = '0;
    endcase
end
```

> **Source:** [`examples/02_combinational/decoder_encoder.sv`](examples/02_combinational/decoder_encoder.sv)

---

## 4. Sequential Logic

Sequential circuits have memory — outputs depend on both inputs and past state. Use `always_ff` for all sequential logic.

### Flip-Flop Fundamentals

```
         ┌──────────┐
    D ──>│          │──> Q
         │   D-FF   │
  clk ──>│          │
 rst_n ->│          │
         └──────────┘
```

**Critical rule:** In FPGAs, use **synchronous design** — all state changes happen on clock edges.

```systemverilog
// Async reset (most common in FPGAs): reset takes effect immediately
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;       // Reset value
    else
        q <= d;           // Normal operation
end

// Sync reset: reset sampled on clock edge (smaller, often preferred)
always_ff @(posedge clk) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= d;
end

// With enable: register holds value when enable is low
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else if (en)
        q <= d;
    // Implicit: else q <= q (hold)
end
```

**`<=` (non-blocking) vs `=` (blocking):**
- Use `<=` in `always_ff` — assignments happen simultaneously at the end of the time step
- Use `=` in `always_comb` — assignments happen immediately (as expected for combinational logic)
- **Never mix them in the same always block**

> **Source:** [`examples/03_sequential/dff_variants.sv`](examples/03_sequential/dff_variants.sv)

### Counters

Counters are the workhorses of digital design — used for timing, addressing, sequencing, and control.

```systemverilog
module up_counter #(
    parameter int WIDTH     = 8,
    parameter int MAX_COUNT = (2**WIDTH) - 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             clear,
    output logic [WIDTH-1:0] count,
    output logic             terminal_count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (clear)
            count <= '0;
        else if (enable) begin
            if (count == MAX_COUNT[WIDTH-1:0])
                count <= '0;           // Wrap around
            else
                count <= count + 1'b1;
        end
    end

    assign terminal_count = enable && (count == MAX_COUNT[WIDTH-1:0]);
endmodule
```

**Gray Code Counter** — essential for clock domain crossing (only one bit changes per increment):

```systemverilog
// Binary to Gray: G = B ^ (B >> 1)
assign gray_count = binary_count ^ (binary_count >> 1);
```

> **Source:** [`examples/03_sequential/counters.sv`](examples/03_sequential/counters.sv)

### Shift Registers

```systemverilog
// Serial-In, Parallel-Out (SIPO)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        parallel_out <= '0;
    else if (shift_en)
        parallel_out <= {parallel_out[WIDTH-2:0], serial_in};
end

// LFSR (Linear Feedback Shift Register) — pseudo-random generator
// Feedback polynomial: x^8 + x^6 + x^5 + x^4 + 1
assign feedback = lfsr_out[7] ^ lfsr_out[5] ^ lfsr_out[4] ^ lfsr_out[3];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        lfsr_out <= SEED;  // Must be non-zero
    else if (enable)
        lfsr_out <= {lfsr_out[WIDTH-2:0], feedback};
end
```

> **Source:** [`examples/03_sequential/shift_register.sv`](examples/03_sequential/shift_register.sv)

---

## 5. Finite State Machines (FSMs)

FSMs are the control backbone of digital systems. They manage sequencing, protocol handling, and complex decision-making.

### FSM Design Pattern

The recommended three-block coding style separates concerns for clarity and maintainability:

```
┌─────────────────────────────────────────────┐
│            Three-Block FSM Pattern          │
│                                             │
│  Block 1: State Register (always_ff)        │
│    state_q <= state_d;                      │
│                                             │
│  Block 2: Next State Logic (always_comb)    │
│    state_d = f(state_q, inputs);            │
│                                             │
│  Block 3: Output Logic (always_comb)        │
│    outputs = g(state_q [, inputs]);         │
│                                             │
│  Moore: outputs = g(state_q)                │
│  Mealy: outputs = g(state_q, inputs)        │
└─────────────────────────────────────────────┘
```

### Moore FSM: Traffic Light Controller

In a **Moore FSM**, outputs depend only on the current state — they change synchronously with state transitions, making them glitch-free.

```systemverilog
typedef enum logic [2:0] {
    NS_GREEN, NS_YELLOW, EW_GREEN, EW_YELLOW, ALL_RED
} state_e;

state_e state_q, state_d;

// Block 1: State Register
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= NS_GREEN;
    else        state_q <= state_d;
end

// Block 2: Next State Logic
always_comb begin
    state_d = state_q;
    unique case (state_q)
        NS_GREEN:  if (timer_done && sensor_ew) state_d = NS_YELLOW;
        NS_YELLOW: if (timer_done)              state_d = ALL_RED;
        // ...
    endcase
end

// Block 3: Output Logic (Moore — state only)
always_comb begin
    unique case (state_q)
        NS_GREEN:  begin light_ns = 3'b001; light_ew = 3'b100; end
        NS_YELLOW: begin light_ns = 3'b010; light_ew = 3'b100; end
        EW_GREEN:  begin light_ns = 3'b100; light_ew = 3'b001; end
        // ...
    endcase
end
```

> **Source:** [`examples/04_fsm/moore_fsm.sv`](examples/04_fsm/moore_fsm.sv)

### Mealy FSM: Sequence Detector

In a **Mealy FSM**, outputs depend on both state AND inputs — this allows faster response (one cycle earlier than Moore) but outputs can glitch if inputs are asynchronous.

```systemverilog
// Detects bit pattern "1011" in a serial stream
always_comb begin
    state_d  = state_q;
    detected = 1'b0;
    unique case (state_q)
        S_GOT101: begin
            if (bit_in) begin
                detected = 1'b1;    // Mealy: output depends on input
                state_d  = S_GOT1; // Overlapping detection
            end else
                state_d = S_GOT10;
        end
        // ...
    endcase
end
```

> **Source:** [`examples/04_fsm/mealy_fsm.sv`](examples/04_fsm/mealy_fsm.sv)

### One-Hot FSM: SPI Master

**One-hot encoding** uses one flip-flop per state. On FPGAs, this is often optimal because:
- State decode is a single flip-flop read (no LUTs needed)
- FPGAs have abundant flip-flops
- Faster `fmax` due to simpler decode logic

```systemverilog
typedef enum logic [4:0] {
    ST_IDLE     = 5'b00001,
    ST_LOAD     = 5'b00010,
    ST_SHIFT_LO = 5'b00100,
    ST_SHIFT_HI = 5'b01000,
    ST_DONE     = 5'b10000
} state_e;

// One-hot decode using case(1'b1) pattern
always_comb begin
    unique case (1'b1)
        state_q[0]: ...  // IDLE
        state_q[1]: ...  // LOAD
        state_q[2]: ...  // SHIFT_LO
        state_q[3]: ...  // SHIFT_HI
        state_q[4]: ...  // DONE
    endcase
end
```

> **Source:** [`examples/04_fsm/fsm_onehot.sv`](examples/04_fsm/fsm_onehot.sv)

---

## 6. Parameterized and Reusable Modules

Parameters make modules configurable and reusable across different contexts.

### Parameters and Localparam

```systemverilog
module register_file #(
    parameter int DATA_WIDTH = 32,       // Configurable from outside
    parameter int ADDR_WIDTH = 5,
    parameter int NUM_REGS   = 2**ADDR_WIDTH  // Derived parameter
) (
    input  logic                  clk,
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic [ADDR_WIDTH-1:0] rd_addr1,
    input  logic [ADDR_WIDTH-1:0] rd_addr2,
    output logic [DATA_WIDTH-1:0] rd_data1,
    output logic [DATA_WIDTH-1:0] rd_data2
);
    logic [DATA_WIDTH-1:0] regs [NUM_REGS];
    // ...
endmodule
```

### Generate Statements

`generate` creates multiple instances of hardware from a loop or conditional:

```systemverilog
module ripple_carry_adder #(parameter int WIDTH = 8) (
    input  logic [WIDTH-1:0] a, b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    logic [WIDTH:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_full_adder
            full_adder u_fa (
                .a(a[i]), .b(b[i]), .cin(carry[i]),
                .sum(sum[i]), .cout(carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[WIDTH];
endmodule
```

### Instantiation with Parameter Override

```systemverilog
// Named parameter override (preferred)
register_file #(
    .DATA_WIDTH (64),
    .ADDR_WIDTH (4)
) u_regfile (
    .clk     (clk),
    .wr_en   (reg_wr_en),
    // ...
);
```

> **Source:** [`examples/05_parameterized/parameterized_modules.sv`](examples/05_parameterized/parameterized_modules.sv)

---

## 7. Interfaces

Interfaces bundle related signals together, reducing port list clutter and ensuring consistent connections. They are especially valuable for bus protocols.

```systemverilog
interface axi_stream_if #(
    parameter int DATA_WIDTH = 32
) (
    input logic clk,
    input logic rst_n
);
    logic [DATA_WIDTH-1:0]   tdata;
    logic                    tvalid;
    logic                    tready;
    logic                    tlast;

    // Modports define directional access
    modport master (
        output tdata, tvalid, tlast,
        input  tready
    );

    modport slave (
        input  tdata, tvalid, tlast,
        output tready
    );
endinterface
```

### Using Interfaces in Modules

```systemverilog
module axis_data_doubler (
    axi_stream_if.slave  s_axis,    // Input stream
    axi_stream_if.master m_axis     // Output stream
);
    assign m_axis.tdata  = s_axis.tdata << 1;  // Double the data
    assign m_axis.tvalid = s_axis.tvalid;
    assign s_axis.tready = m_axis.tready;
endmodule
```

### Connecting Interfaces at the Top Level

```systemverilog
module top (input logic clk, rst_n);
    axi_stream_if #(.DATA_WIDTH(32)) stream_a (.clk, .rst_n);
    axi_stream_if #(.DATA_WIDTH(32)) stream_b (.clk, .rst_n);

    data_source u_src  (.m_axis(stream_a));
    axis_data_doubler  (.s_axis(stream_a), .m_axis(stream_b));
    data_sink   u_sink (.s_axis(stream_b));
endmodule
```

> **Source:** [`examples/06_interfaces/axi_stream_if.sv`](examples/06_interfaces/axi_stream_if.sv)

---

## 8. Packages

Packages group related types, constants, and functions for reuse across modules. They provide namespace isolation and are essential for large designs.

```systemverilog
package common_pkg;
    typedef enum logic [2:0] {
        OP_NOP, OP_READ, OP_WRITE, OP_RMW, OP_BURST
    } opcode_e;

    typedef struct packed {
        logic [31:0] address;
        logic [31:0] data;
        opcode_e     opcode;
        logic [3:0]  byte_en;
    } transaction_t;

    function automatic logic [31:0] byte_reverse(input logic [31:0] data);
        return {data[7:0], data[15:8], data[23:16], data[31:24]};
    endfunction
endpackage

// Import in modules
module my_module
    import common_pkg::*;
(
    input  transaction_t txn_in,
    output transaction_t txn_out
);
```

> **Source:** [`examples/07_packages/common_pkg.sv`](examples/07_packages/common_pkg.sv)

---

## 9. SystemVerilog Assertions (SVA)

Assertions document and verify design intent. They catch bugs during simulation and can be used by formal verification tools to prove correctness.

### Immediate Assertions

Checked at a specific point in procedural code:

```systemverilog
always_comb begin
    if (valid) begin
        assert (!$isunknown(data))
            else $error("Data contains X/Z when valid is high");
    end
end
```

### Concurrent Assertions

Checked continuously across clock cycles using temporal sequences:

```systemverilog
// Request must be acknowledged within 5 cycles
property p_req_ack;
    @(posedge clk) disable iff (!rst_n)
        req |-> ##[1:5] ack;       // |-> is "implies"
endproperty
assert property (p_req_ack)
    else $error("ACK timeout");

// Valid/ready handshake: valid must not drop without ready
property p_valid_until_ready;
    @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> valid;   // |=> is "next-cycle implies"
endproperty

// Data stability during handshake
property p_data_stable;
    @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> $stable(data);
endproperty
```

### SVA Operators Quick Reference

| Operator | Meaning | Example |
|----------|---------|---------|
| `\|->` | Overlapping implication | `a \|-> b` (if a then b same cycle) |
| `\|=>` | Non-overlapping implication | `a \|=> b` (if a then b next cycle) |
| `##N` | Cycle delay | `a ##3 b` (a then 3 cycles later b) |
| `##[M:N]` | Delay range | `a ##[1:5] b` (b within 1-5 cycles) |
| `[*N]` | Consecutive repetition | `a [*3]` (a for 3 consecutive cycles) |
| `$rose()` | Rising edge | `$rose(signal)` |
| `$fell()` | Falling edge | `$fell(signal)` |
| `$stable()` | No change | `$stable(data)` |
| `$past()` | Previous value | `$past(signal, 2)` |

> **Source:** [`examples/08_assertions/sva_examples.sv`](examples/08_assertions/sva_examples.sv)

---

## 10. FIFO Design

FIFOs (First-In, First-Out) are fundamental building blocks for buffering, rate matching, and clock domain crossing.

### Synchronous FIFO

Single clock domain. Uses a dual-port memory with read/write pointers. The MSB trick distinguishes full from empty:

```
Pointer:   [MSB | ADDR_WIDTH-1 : 0]
            ↑         ↑
         Wrap bit   Memory address

Empty: wr_ptr == rd_ptr          (identical)
Full:  wr_ptr[MSB] != rd_ptr[MSB]  AND
       wr_ptr[addr] == rd_ptr[addr] (same address, different wrap)
```

```systemverilog
module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16
) (
    input  logic                  clk, rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);
    logic [DATA_WIDTH-1:0] mem [DEPTH];
    logic [ADDR_WIDTH:0]   wr_ptr, rd_ptr;  // Extra MSB

    assign full  = (wr_ptr[MSB] != rd_ptr[MSB]) &&
                   (wr_ptr[addr] == rd_ptr[addr]);
    assign empty = (wr_ptr == rd_ptr);
endmodule
```

> **Source:** [`examples/09_fifo/sync_fifo.sv`](examples/09_fifo/sync_fifo.sv)

### Asynchronous FIFO (Dual-Clock)

Transfers data between two unrelated clock domains. The key challenge is safely comparing pointers across domains. The solution uses **Gray code pointers** (only one bit changes per increment) synchronized through 2-FF synchronizers.

```
┌──────────────────────────────────────────────────┐
│               Async FIFO Architecture            │
│                                                  │
│   wr_clk domain          rd_clk domain           │
│  ┌────────────┐         ┌────────────┐           │
│  │ wr_ptr     │         │ rd_ptr     │           │
│  │ (binary)   │         │ (binary)   │           │
│  └─────┬──────┘         └─────┬──────┘           │
│        │ B→G                  │ B→G               │
│  ┌─────▼──────┐         ┌─────▼──────┐           │
│  │ wr_gray    │────2FF──│ wr_gray    │           │
│  │            │  sync   │  _sync     │           │
│  └────────────┘         └────────────┘           │
│  ┌────────────┐         ┌────────────┐           │
│  │ rd_gray    │──2FF────│ rd_gray    │           │
│  │  _sync     │  sync   │            │           │
│  └────────────┘         └────────────┘           │
│                                                  │
│  Full = wr_gray_next == {~rd_sync[MSB:MSB-1],   │
│                           rd_sync[MSB-2:0]}      │
│  Empty = rd_gray_next == wr_gray_sync            │
└──────────────────────────────────────────────────┘
```

> **Source:** [`examples/09_fifo/async_fifo.sv`](examples/09_fifo/async_fifo.sv)

---

## 11. Pipeline Design

Pipelining breaks long combinational paths into stages, each completing in one clock cycle. This increases **throughput** (one result per cycle) at the cost of **latency** (N cycles for first result).

```
Without pipeline:        With 4-stage pipeline:
  ┌──────────────┐        ┌───┐ ┌───┐ ┌───┐ ┌───┐
  │  Long comb.  │        │S1 │→│S2 │→│S3 │→│S4 │
  │  path        │        │   │ │   │ │   │ │   │
  │  (slow fmax) │        └───┘ └───┘ └───┘ └───┘
  └──────────────┘        (4x higher fmax)
```

### Pipelined MAC (Multiply-Accumulate)

Common in DSP and ML accelerators:

```systemverilog
module pipelined_mac #(
    parameter int A_WIDTH = 16, B_WIDTH = 16, ACC_WIDTH = 48
) (
    input  logic                 clk, rst_n, clear_acc, valid_in,
    input  logic [A_WIDTH-1:0]   a,
    input  logic [B_WIDTH-1:0]   b,
    output logic [ACC_WIDTH-1:0] accumulator,
    output logic                 valid_out
);
    // Stage 1: Multiply
    logic [A_WIDTH+B_WIDTH-1:0] product;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) product <= '0;
        else        product <= $signed(a) * $signed(b);

    // Stage 2: Accumulate
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)       accumulator <= '0;
        else if (clear)   accumulator <= '0;
        else if (s1_valid) accumulator <= accumulator + product;
endmodule
```

### Pipeline with Backpressure

Real-world pipelines need flow control. The **valid/ready handshake** is the standard approach:

```systemverilog
// Each stage can accept data when empty OR when output is consumed
wire s2_ready = !s2_valid || out_ready;
wire s1_ready = !s1_valid || s2_ready;
assign in_ready = s1_ready;

// Stage N only advances when its downstream is ready
always_ff @(posedge clk) begin
    if (s1_ready) begin
        s1_data  <= in_data + 1;
        s1_valid <= in_valid;
    end
end
```

> **Source:** [`examples/10_pipeline/pipeline_stages.sv`](examples/10_pipeline/pipeline_stages.sv)

---

## 12. Clock Domain Crossing (CDC)

CDC is one of the most critical and error-prone aspects of multi-clock FPGA design. Incorrect CDC causes **metastability** — a flip-flop enters an undefined state when setup/hold times are violated.

### The Problem

```
clk_a:  ___/‾‾‾\___/‾‾‾\___/‾‾‾\___
signal: ____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾____
clk_b:  _____/‾‾‾\___/‾‾‾\___/‾‾‾\__
                ↑
           Setup/hold violation!
           FF output could be 0, 1, or metastable
```

### Solution 1: 2-FF Synchronizer (Single-Bit Signals)

The fundamental CDC primitive. The first FF may go metastable, but it settles before the second FF samples.

```systemverilog
module sync_2ff (
    input  logic clk_dest,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);
    logic meta_ff;
    always_ff @(posedge clk_dest or negedge rst_n) begin
        if (!rst_n) begin
            meta_ff  <= 1'b0;
            sync_out <= 1'b0;
        end else begin
            meta_ff  <= async_in;      // May go metastable
            sync_out <= meta_ff;       // Settled by now
        end
    end
endmodule
```

### Solution 2: Pulse Synchronizer

Transfers a single-cycle pulse across domains using a toggle + edge detect:

```systemverilog
// Source: toggle on each pulse
always_ff @(posedge src_clk)
    if (src_pulse) toggle_ff <= ~toggle_ff;

// Destination: synchronize toggle, detect edges
// sync1 <= toggle_ff; sync2 <= sync1; sync3 <= sync2;
assign dst_pulse = sync2 ^ sync3;  // Edge = XOR of adjacent samples
```

### Solution 3: Handshake Synchronizer (Multi-Bit Data)

For transferring a multi-bit bus, data must be stable while it crosses domains:

```
src_clk:  Latch data → Assert REQ ──────────────── Deassert REQ
                                     ↓ 2-FF sync
dst_clk:              ──────────── See REQ → Capture data → Assert ACK
                                                              ↓ 2-FF sync
src_clk:  ──────────────────────────────────────── See ACK → Ready
```

### CDC Rules Summary

| Signal Type | Recommended Solution |
|-------------|---------------------|
| Single bit (level) | 2-FF synchronizer |
| Single bit (pulse) | Pulse synchronizer (toggle + edge detect) |
| Multi-bit counter | Gray code + 2-FF synchronizer |
| Multi-bit data (slow) | Handshake synchronizer |
| Multi-bit data (fast) | Async FIFO (Gray code pointers) |
| Reset | Async assert, sync deassert |

> **Source:** [`examples/11_clock_domain_crossing/cdc_modules.sv`](examples/11_clock_domain_crossing/cdc_modules.sv)

---

## 13. Memory Design

FPGAs provide dedicated memory resources (Block RAM, Distributed RAM). The coding style determines which resource the synthesizer infers.

### Single-Port RAM

```systemverilog
module single_port_ram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10
) (
    input  logic                  clk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);
    logic [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH];

    always_ff @(posedge clk) begin
        if (we) mem[addr] <= din;
        dout <= mem[addr];              // Read-first mode
    end
endmodule
```

### Read/Write Mode Behaviors

The order of read vs write in the `always_ff` block controls behavior:

```systemverilog
// Read-First: output shows OLD value on write
always_ff @(posedge clk) begin
    dout <= mem[addr];    // Read first
    if (we) mem[addr] <= din;
end

// Write-First: output shows NEW value on write
always_ff @(posedge clk) begin
    if (we) mem[addr] <= din;
    dout <= mem[addr];    // Read after write
end

// No-Change: output holds previous value on write
always_ff @(posedge clk) begin
    if (we)
        mem[addr] <= din;
    else
        dout <= mem[addr];
end
```

### RAM with Byte Enables

Essential for processor data memory — allows writing individual bytes:

```systemverilog
always_ff @(posedge clk) begin
    if (we) begin
        if (byte_en[0]) mem[addr][ 7: 0] <= din[ 7: 0];
        if (byte_en[1]) mem[addr][15: 8] <= din[15: 8];
        if (byte_en[2]) mem[addr][23:16] <= din[23:16];
        if (byte_en[3]) mem[addr][31:24] <= din[31:24];
    end
    dout <= mem[addr];
end
```

### Memory Inference Guidelines

| Coding Style | Inferred Resource |
|-------------|-------------------|
| Registered output, large array | Block RAM (BRAM) |
| Combinational read, small array | Distributed RAM (LUTs) |
| Read-only, initialized array | ROM (Block RAM or LUTs) |
| Both ports clocked | True Dual-Port RAM |

> **Source:** [`examples/12_memory/ram_models.sv`](examples/12_memory/ram_models.sv)

---

## 14. AXI4-Lite Bus Interface

AXI4-Lite is the standard register access interface in FPGA SoC designs (Xilinx Zynq, Intel FPGA SoC). It provides a simple read/write interface for control and status registers.

### AXI4-Lite Channels

```
┌─────────┐                              ┌─────────┐
│         │  Write Addr (AW): awaddr,    │         │
│         │  awvalid, awready            │         │
│         │ ───────────────────────────> │         │
│         │  Write Data (W):  wdata,     │         │
│         │  wstrb, wvalid, wready       │         │
│  AXI    │ ───────────────────────────> │  AXI    │
│  Master │  Write Resp (B):  bresp,     │  Slave  │
│         │  bvalid, bready              │         │
│         │ <─────────────────────────── │         │
│         │  Read Addr (AR):  araddr,    │         │
│         │  arvalid, arready            │         │
│         │ ───────────────────────────> │         │
│         │  Read Data (R):   rdata,     │         │
│         │  rresp, rvalid, rready       │         │
│         │ <─────────────────────────── │         │
└─────────┘                              └─────────┘
```

### AXI4-Lite Handshake

Every channel uses the same valid/ready handshake:
- **Sender** asserts `valid` when data is available
- **Receiver** asserts `ready` when it can accept
- **Transfer** occurs when both `valid` AND `ready` are high in the same cycle

### Register Map Design Pattern

```systemverilog
// Define register offsets (word-addressed)
localparam int REG_CONTROL = 0;  // R/W
localparam int REG_STATUS  = 1;  // Read-only
localparam int REG_CONFIG  = 2;  // R/W
localparam int REG_DEBUG   = 3;  // Read-only

// Write handling with byte strobes
always_ff @(posedge aclk) begin
    if (write_valid) begin
        for (int b = 0; b < 4; b++)
            if (wstrb[b])
                regs[addr][b*8 +: 8] <= wdata[b*8 +: 8];
    end
end

// Read mux with read-only register overrides
always_ff @(posedge aclk) begin
    if (read_valid) begin
        case (addr)
            REG_CONTROL: rdata <= regs[REG_CONTROL];
            REG_STATUS:  rdata <= status_input;   // External input
            REG_CONFIG:  rdata <= regs[REG_CONFIG];
            REG_DEBUG:   rdata <= debug_input;    // External input
            default:     rdata <= 32'hDEAD_BEEF;
        endcase
    end
end
```

> **Source:** [`examples/13_axi_lite/axi_lite_slave.sv`](examples/13_axi_lite/axi_lite_slave.sv)

---

## 15. Testbench Techniques

Verification is crucial — most of an FPGA engineer's time is spent verifying, not designing.

### Testbench Structure

```
┌──────────────────────────────────────┐
│           Testbench (TB)             │
│  ┌────────────────────────────────┐  │
│  │  Clock Generation              │  │
│  │  Reset Sequence                │  │
│  │  Stimulus Driver               │  │
│  │  ┌──────────────────────────┐  │  │
│  │  │    DUT (Design Under     │  │  │
│  │  │         Test)            │  │  │
│  │  └──────────────────────────┘  │  │
│  │  Scoreboard / Checker          │  │
│  │  Coverage Monitor              │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### Clock and Reset Generation

```systemverilog
localparam int CLK_PERIOD = 10;  // 100 MHz

// Clock generation
initial clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;

// Reset task
task automatic reset_dut();
    rst_n <= 1'b0;
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
endtask
```

### Self-Checking with Reference Models

Use a software reference model to verify hardware outputs:

```systemverilog
// Reference model using SystemVerilog queue
logic [7:0] ref_queue [$];

always @(posedge clk) begin
    if (wr_en && !full) ref_queue.push_back(wr_data);
    if (rd_en && !empty) begin
        automatic logic [7:0] expected = ref_queue.pop_front();
        assert (rd_data === expected)
            else $error("Mismatch: expected=%h got=%h", expected, rd_data);
    end
end
```

### Functional Coverage

Coverage tells you what scenarios have been exercised:

```systemverilog
covergroup cg_fifo @(posedge clk);
    cp_fill: coverpoint fill_level {
        bins empty = {0};
        bins low   = {[1:4]};
        bins mid   = {[5:11]};
        bins high  = {[12:15]};
        bins full  = {16};
    }
    cp_wr: coverpoint wr_en;
    cp_rd: coverpoint rd_en;
    cp_simultaneous: cross cp_wr, cp_rd;
endgroup
```

### Constrained Random Stimulus

```systemverilog
// Random read/write mix
for (int t = 0; t < NUM_TRANSACTIONS; t++) begin
    @(posedge clk);
    wr_en   <= ($urandom_range(0,1) == 1) && !full;
    rd_en   <= ($urandom_range(0,1) == 1) && !empty;
    wr_data <= $urandom();
end
```

> **Source:**
> - [`examples/14_testbenches/tb_counter.sv`](examples/14_testbenches/tb_counter.sv)
> - [`examples/14_testbenches/tb_sync_fifo.sv`](examples/14_testbenches/tb_sync_fifo.sv)
> - [`examples/14_testbenches/tb_alu.sv`](examples/14_testbenches/tb_alu.sv)

---

## 16. FPGA Design Best Practices

### Coding Style

| Practice | Reason |
|----------|--------|
| Use `always_comb` for combinational, `always_ff` for sequential | Compiler verifies correct usage; prevents accidental latches |
| Use `logic` instead of `reg`/`wire` | Simpler, works everywhere, compiler-inferred |
| Use `unique case` / `priority if` | Communicates intent; enables synthesis optimization |
| Always include `default` in case statements | Prevents unintended latches in `always_comb` |
| Use non-blocking (`<=`) in `always_ff` | Correct simulation of register behavior |
| Use blocking (`=`) in `always_comb` | Correct modeling of combinational logic |
| Avoid `initial` blocks in RTL | Not synthesizable (use only in testbenches and ROM init) |

### Reset Strategy

```systemverilog
// Preferred: Asynchronous assert, synchronous deassert
module reset_sync (
    input  logic clk,
    input  logic async_rst_n,
    output logic sync_rst_n
);
    logic rst_meta;
    always_ff @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            rst_meta   <= 1'b0;
            sync_rst_n <= 1'b0;
        end else begin
            rst_meta   <= 1'b1;
            sync_rst_n <= rst_meta;
        end
    end
endmodule
```

### Timing Closure Tips

1. **Register all outputs** of a module — avoids long combinational paths across module boundaries
2. **Break long combinational chains** with pipeline registers
3. **Use dedicated DSP blocks** for multipliers — they have built-in pipeline registers
4. **Avoid** asynchronous resets on timing-critical paths (use synchronous reset)
5. **Minimize fan-out** on high-frequency nets — add register stages to duplicate high-fan-out signals

### Resource Optimization

```systemverilog
// Use DSP inference for multiply-accumulate
// Most synthesizers recognize this pattern and map to DSP slices
always_ff @(posedge clk)
    result <= a * b + c;  // Maps to DSP48 (Xilinx) or DSP block (Intel)

// Use shift instead of multiply by power of 2
assign doubled = value << 1;     // Free (just routing)
assign quadrupled = value << 2;  // Free (just routing)

// Use one-hot encoding for FPGA FSMs
// FPGAs have abundant flip-flops; one-hot avoids LUT-based decode
```

---

## 17. Common Pitfalls and How to Avoid Them

### Pitfall 1: Unintentional Latches

```systemverilog
// BAD: Missing else creates a latch
always_comb begin
    if (sel)
        y = a;
    // When sel=0, y must hold its value → latch inferred!
end

// GOOD: Always assign a default
always_comb begin
    y = '0;       // Default value
    if (sel)
        y = a;
end
```

### Pitfall 2: Incomplete Sensitivity List (Verilog)

```systemverilog
// In Verilog, you'd write: always @(a or b) — easy to forget signals
// SystemVerilog always_comb automatically includes all read signals
always_comb begin
    y = a & b;   // Both a and b in implicit sensitivity list
end
```

### Pitfall 3: Mixing Blocking and Non-Blocking

```systemverilog
// BAD: Mixing = and <= in always_ff
always_ff @(posedge clk) begin
    temp = a + b;      // Blocking ← WRONG in always_ff
    result <= temp;    // Non-blocking
end

// GOOD: Use only <= in always_ff
always_ff @(posedge clk) begin
    result <= a + b;
end
```

### Pitfall 4: Multi-Driven Signals

```systemverilog
// BAD: Two always blocks driving the same signal
always_ff @(posedge clk) begin
    if (cond_a) data <= val_a;
end
always_ff @(posedge clk) begin
    if (cond_b) data <= val_b;   // ERROR: multi-driven
end

// GOOD: Single driver
always_ff @(posedge clk) begin
    if (cond_a) data <= val_a;
    else if (cond_b) data <= val_b;
end
```

### Pitfall 5: Unsafe Clock Domain Crossing

```systemverilog
// BAD: Direct use of a signal from another clock domain
always_ff @(posedge clk_b) begin
    if (signal_from_clk_a)     // METASTABILITY RISK!
        do_something <= 1'b1;
end

// GOOD: Synchronize first
sync_2ff u_sync (.clk_dest(clk_b), .async_in(signal_from_clk_a), .sync_out(safe_signal));
always_ff @(posedge clk_b) begin
    if (safe_signal)
        do_something <= 1'b1;
end
```

### Pitfall 6: Asynchronous Reset Glitches

```systemverilog
// BAD: Combinational logic on reset path
wire rst_n = external_rst_n & pll_locked;  // Glitch-prone!

// GOOD: Synchronize reset deassertion
reset_sync u_rst_sync (
    .clk        (clk),
    .async_rst_n(external_rst_n & pll_locked),
    .sync_rst_n (clean_rst_n)
);
```

---

## 18. FPGA Design Flow Summary

```
  ┌─────────────────────────────────────────────┐
  │              FPGA Design Flow               │
  │                                             │
  │  1. Specification & Architecture            │
  │     └─ Define requirements, block diagram   │
  │                                             │
  │  2. RTL Design (SystemVerilog)              │
  │     └─ Write synthesizable HDL code         │
  │                                             │
  │  3. Functional Simulation                   │
  │     └─ Verify behavior with testbenches     │
  │     └─ Tools: Icarus Verilog, ModelSim,     │
  │        VCS, Xcelium, Verilator              │
  │                                             │
  │  4. Lint / Static Analysis                  │
  │     └─ Catch coding errors early            │
  │     └─ Tools: Spyglass, Verilator --lint    │
  │                                             │
  │  5. Synthesis                               │
  │     └─ Convert RTL to gate-level netlist    │
  │     └─ Tools: Vivado, Quartus, Yosys        │
  │                                             │
  │  6. Place & Route                           │
  │     └─ Map gates to FPGA resources          │
  │     └─ Route interconnections               │
  │                                             │
  │  7. Static Timing Analysis (STA)            │
  │     └─ Verify all timing constraints met    │
  │     └─ Fix timing violations                │
  │                                             │
  │  8. Bitstream Generation                    │
  │     └─ Create programming file              │
  │                                             │
  │  9. Hardware Testing                        │
  │     └─ Program FPGA, test on real hardware  │
  │     └─ Use ILA/SignalTap for debug          │
  └─────────────────────────────────────────────┘
```

### Useful Open-Source Tools

| Tool | Purpose | Installation |
|------|---------|-------------|
| [Icarus Verilog](http://iverilog.icarus.com/) | Simulation | `apt install iverilog` |
| [Verilator](https://www.veripool.org/verilator/) | Fast simulation + lint | `apt install verilator` |
| [GTKWave](http://gtkwave.sourceforge.net/) | Waveform viewer | `apt install gtkwave` |
| [Yosys](https://yosyshq.net/yosys/) | Open-source synthesis | `apt install yosys` |
| [nextpnr](https://github.com/YosysHQ/nextpnr) | Open-source place & route | Build from source |

---

## Repository Structure

```
.
├── README.md                              # This tutorial
└── examples/
    ├── 01_basics/
    │   ├── hello_world.sv                 # First module, continuous assignment
    │   ├── data_types.sv                  # logic, enum, struct, arrays
    │   └── port_styles.sv                 # ANSI, non-ANSI, bidirectional ports
    ├── 02_combinational/
    │   ├── mux.sv                         # 2:1, 4:1, unique, priority mux
    │   ├── decoder_encoder.sv             # Decoder, priority encoder, one-hot
    │   └── alu.sv                         # Full ALU with flags
    ├── 03_sequential/
    │   ├── dff_variants.sv                # Async/sync reset, enable, byte-enable
    │   ├── counters.sv                    # Up, up/down, Gray, ring counters
    │   └── shift_register.sv             # SIPO, PISO, LFSR
    ├── 04_fsm/
    │   ├── moore_fsm.sv                   # Traffic light controller
    │   ├── mealy_fsm.sv                   # Sequence detector ("1011")
    │   └── fsm_onehot.sv                 # SPI master with one-hot encoding
    ├── 05_parameterized/
    │   └── parameterized_modules.sv       # Register file, width converter, generate
    ├── 06_interfaces/
    │   └── axi_stream_if.sv              # AXI-Stream interface with modports
    ├── 07_packages/
    │   └── common_pkg.sv                  # Package with types, functions, constants
    ├── 08_assertions/
    │   └── sva_examples.sv               # Immediate + concurrent assertions
    ├── 09_fifo/
    │   ├── sync_fifo.sv                   # Single-clock FIFO
    │   └── async_fifo.sv                  # Dual-clock FIFO (Gray code CDC)
    ├── 10_pipeline/
    │   └── pipeline_stages.sv             # Generic pipeline, MAC, backpressure
    ├── 11_clock_domain_crossing/
    │   └── cdc_modules.sv                 # 2-FF sync, pulse sync, handshake
    ├── 12_memory/
    │   └── ram_models.sv                  # SP-RAM, DP-RAM, TDP-RAM, ROM, byte-enable
    ├── 13_axi_lite/
    │   └── axi_lite_slave.sv              # AXI4-Lite register bank
    └── 14_testbenches/
        ├── tb_counter.sv                  # Basic self-checking testbench
        ├── tb_sync_fifo.sv                # Reference model + coverage
        └── tb_alu.sv                      # Directed + random testing
```

---

## Further Reading

- IEEE 1800-2017 SystemVerilog LRM (Language Reference Manual)
- Clifford Cummings' papers on [CDC](http://www.sunburst-design.com/papers/CummingsSNUG2008Boston_CDC.pdf) and [FSM design](http://www.sunburst-design.com/papers/CummingsSNUG2019SV_FSM1.pdf)
- Xilinx UG901: Vivado Synthesis Guide (coding style for BRAM/DSP inference)
- Intel FPGA Recommended HDL Coding Styles
- Stuart Sutherland's "RTL Modeling with SystemVerilog for Simulation and Synthesis"

---

*All examples in this repository are synthesizable (unless noted otherwise) and follow industry-standard coding practices for FPGA RTL design.*
