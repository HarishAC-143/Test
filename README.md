# RTL Design with SystemVerilog: A Comprehensive Tutorial

A hands-on guide to Register Transfer Level (RTL) design using SystemVerilog, covering fundamentals through advanced techniques with practical, synthesizable examples.

---

## Table of Contents

1. [Introduction to RTL Design](#1-introduction-to-rtl-design)
2. [SystemVerilog for RTL: Language Essentials](#2-systemverilog-for-rtl-language-essentials)
3. [Combinational Logic Design](#3-combinational-logic-design)
4. [Sequential Logic Design](#4-sequential-logic-design)
5. [Finite State Machines (FSMs)](#5-finite-state-machines-fsms)
6. [Memory Design](#6-memory-design)
7. [Datapath Design](#7-datapath-design)
8. [Pipelining](#8-pipelining)
9. [Interfaces and Bus Protocols](#9-interfaces-and-bus-protocols)
10. [Parameterized and Reusable Design](#10-parameterized-and-reusable-design)
11. [Writing Testbenches](#11-writing-testbenches)
12. [RTL Design Best Practices](#12-rtl-design-best-practices)
13. [Repository Structure](#13-repository-structure)

---

## 1. Introduction to RTL Design

### What is RTL?

**Register Transfer Level (RTL)** describes digital hardware at the level of data flow between registers and the logical operations performed on that data. It is the standard abstraction for designing synthesizable digital circuits — the code you write is translated directly into gates, flip-flops, and wires by a synthesis tool.

```
   ┌─────────┐    Combinational    ┌─────────┐
   │ Register│───── Logic ─────────│ Register│
   │  (FF)   │    (gates, mux,     │  (FF)   │
   └─────────┘     adders...)      └─────────┘
       ▲                               │
       │          clock edge           │
       └───────────────────────────────┘
```

### RTL Design Flow

```
Specification → RTL Coding → Simulation → Synthesis → Place & Route → Fabrication
                  (this          ▲            │
                 tutorial)       │            ▼
                              Verify    Gate-level
                              design     netlist
```

### Why SystemVerilog?

SystemVerilog extends Verilog with features that make RTL code safer, more readable, and more maintainable:

| Feature | Verilog | SystemVerilog |
|---|---|---|
| Data types | `reg`, `wire` | `logic`, `bit`, enums, structs |
| Always blocks | `always @(*)` | `always_comb`, `always_ff`, `always_latch` |
| Interfaces | N/A | Full interface support |
| Parameters | `parameter` | `parameter`, `localparam`, type params |
| Assertions | N/A | `assert`, `assume`, `cover` |
| Packages | N/A | `package`, `import` |

---

## 2. SystemVerilog for RTL: Language Essentials

### Data Types

```systemverilog
// logic: 4-state (0, 1, X, Z) - preferred for RTL
logic        single_bit;
logic [7:0]  byte_data;        // 8-bit vector
logic [31:0] word;             // 32-bit vector

// Signed vs unsigned
logic signed [15:0] signed_val;
logic        [15:0] unsigned_val;

// Packed arrays (contiguous bits, synthesizable)
logic [3:0][7:0] packed_data;  // 32 bits: 4 bytes packed together

// Unpacked arrays (memory-style, synthesizable)
logic [7:0] memory [0:255];    // 256 entries of 8 bits each

// Enumerations: self-documenting, tool-checked states
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
} state_e;

// Structures: group related signals
typedef struct packed {
    logic [7:0]  opcode;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [4:0]  rd;
    logic [8:0]  reserved;
} instruction_t;
```

### Always Blocks — The Three Synthesizable Forms

SystemVerilog provides three specialized always blocks that communicate **intent** to both the synthesis tool and the reader:

```systemverilog
// always_comb: Combinational logic (no state, no clock)
// Automatically sensitive to all inputs — no sensitivity list needed
always_comb begin
    y = a & b;
end

// always_ff: Sequential logic (clocked, flip-flops)
// MUST have a clock edge in the sensitivity list
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// always_latch: Intentional latches (use sparingly)
always_latch begin
    if (enable)
        q <= d;
end
```

> **Key Rule:** Use `always_comb` for combinational logic and `always_ff` for sequential logic. Never use the generic `always` block for new RTL.

### Blocking vs Non-Blocking Assignments

```systemverilog
// Blocking (=): Use ONLY in always_comb
always_comb begin
    temp = a + b;        // evaluated immediately
    result = temp * 2;   // uses the updated 'temp'
end

// Non-blocking (<=): Use ONLY in always_ff
always_ff @(posedge clk) begin
    stage1 <= input_data;    // all assignments happen simultaneously
    stage2 <= stage1;        // uses OLD value of stage1
end
```

> **Critical Rule:** Mixing blocking and non-blocking in the wrong context leads to simulation/synthesis mismatches and is the #1 source of RTL bugs.

### Continuous Assignments

```systemverilog
// assign: Pure combinational logic (wires)
assign sum    = a + b;
assign mux_out = sel ? data1 : data0;
assign bus     = enable ? data : 'z;    // Tri-state buffer
```

### Generate Blocks

Generate blocks create hardware structures at elaboration time:

```systemverilog
// Replicate hardware N times
genvar i;
generate
    for (i = 0; i < 8; i++) begin : gen_stage
        dff_sync_reset u_dff (
            .clk   (clk),
            .rst_n (rst_n),
            .d     (data_in[i]),
            .q     (data_out[i])
        );
    end
endgenerate

// Conditional hardware generation
generate
    if (USE_FAST_ADDER) begin : gen_fast
        carry_lookahead_adder #(.WIDTH(WIDTH)) adder (...);
    end else begin : gen_area
        ripple_carry_adder #(.WIDTH(WIDTH)) adder (...);
    end
endgenerate
```

---

## 3. Combinational Logic Design

Combinational circuits produce outputs that depend **only** on current inputs — there is no memory or clock.

### 3.1 Multiplexer

A multiplexer selects one of several inputs based on a select signal. There are multiple valid coding styles:

**File:** [`examples/01_combinational/mux4to1.sv`](examples/01_combinational/mux4to1.sv)

```systemverilog
// Style 1: case statement (most readable for large muxes)
always_comb begin
    case (sel)
        2'b00:   data_out = data_in[0];
        2'b01:   data_out = data_in[1];
        2'b10:   data_out = data_in[2];
        2'b11:   data_out = data_in[3];
        default: data_out = '0;
    endcase
end

// Style 2: Ternary operator (compact for small muxes)
assign y = (sel == 2'b00) ? a :
           (sel == 2'b01) ? b :
           (sel == 2'b10) ? c : d;

// Style 3: Array indexing (most concise)
assign data_out = data_in[sel];
```

**Synthesis result:** All three styles produce identical hardware — a tree of 2:1 muxes.

### 3.2 Decoder and Priority Encoder

**File:** [`examples/01_combinational/decoder.sv`](examples/01_combinational/decoder.sv)

A **decoder** converts an N-bit binary input to a 2^N-bit one-hot output:

```systemverilog
module decoder #(parameter N = 3)(
    input  logic [N-1:0]      encoded,
    input  logic              enable,
    output logic [(1<<N)-1:0] decoded
);
    always_comb begin
        decoded = '0;
        if (enable)
            decoded[encoded] = 1'b1;
    end
endmodule
```

A **priority encoder** does the reverse — finds the highest-priority set bit:

```systemverilog
always_comb begin
    idx   = '0;
    valid = 1'b0;
    for (int i = N-1; i >= 0; i--) begin
        if (req[i]) begin
            idx   = i[$clog2(N)-1:0];
            valid = 1'b1;
            break;
        end
    end
end
```

### 3.3 Arithmetic Logic Unit (ALU)

The ALU is the computational heart of any processor. This example supports 10 operations:

**File:** [`examples/01_combinational/alu.sv`](examples/01_combinational/alu.sv)

```systemverilog
typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLL  = 4'b0101,   // Shift Left Logical
    ALU_SRL  = 4'b0110,   // Shift Right Logical
    ALU_SRA  = 4'b0111,   // Shift Right Arithmetic
    ALU_SLT  = 4'b1000,   // Set Less Than (signed)
    ALU_SLTU = 4'b1001    // Set Less Than (unsigned)
} alu_op_e;

always_comb begin
    case (alu_op)
        ALU_ADD: begin
            result   = sum[WIDTH-1:0];
            carry    = sum[WIDTH];
            overflow = (operand_a[WIDTH-1] == operand_b[WIDTH-1]) &&
                       (result[WIDTH-1] != operand_a[WIDTH-1]);
        end
        ALU_SUB:  result = diff[WIDTH-1:0];
        ALU_AND:  result = operand_a & operand_b;
        ALU_OR:   result = operand_a | operand_b;
        ALU_XOR:  result = operand_a ^ operand_b;
        ALU_SLL:  result = operand_a << operand_b[$clog2(WIDTH)-1:0];
        ALU_SRL:  result = operand_a >> operand_b[$clog2(WIDTH)-1:0];
        ALU_SRA:  result = $signed(operand_a) >>> operand_b[$clog2(WIDTH)-1:0];
        ALU_SLT:  result = {{(WIDTH-1){1'b0}}, $signed(operand_a) < $signed(operand_b)};
        ALU_SLTU: result = {{(WIDTH-1){1'b0}}, operand_a < operand_b};
        default:  result = '0;
    endcase
end
```

**Design notes:**
- The `enum` makes the operation encoding self-documenting.
- Overflow detection is critical for signed arithmetic.
- `$signed()` casting controls whether `>>>` performs arithmetic (sign-extending) shift.

### 3.4 Adder Architectures

**File:** [`examples/01_combinational/adder.sv`](examples/01_combinational/adder.sv)

Two contrasting architectures show the area-vs-speed tradeoff:

```
Ripple Carry Adder:       Carry Look-Ahead Adder:
  Carry propagates          Carry computed in
  bit-by-bit (slow,        parallel (fast, more
  small area)               area)

  FA─FA─FA─FA               CLA block (all carries
  ↑  ↑  ↑  ↑                computed simultaneously)
  c0 c1 c2 c3
```

The **ripple carry adder** uses `generate` to instantiate N full adders:

```systemverilog
genvar i;
generate
    for (i = 0; i < WIDTH; i++) begin : gen_fa
        full_adder fa (
            .a(a[i]), .b(b[i]),
            .cin(carry[i]), .sum(sum[i]), .cout(carry[i+1])
        );
    end
endgenerate
```

The **carry look-ahead adder** computes generates and propagates:

```systemverilog
assign generate_g[i]  = a[i] & b[i];         // Carry is generated here
assign propagate_p[i] = a[i] ^ b[i];         // Carry propagates through
assign carry[i+1]     = generate_g[i] | (propagate_p[i] & carry[i]);
```

---

## 4. Sequential Logic Design

Sequential circuits contain storage elements (flip-flops) and their outputs depend on both current inputs and past state.

### 4.1 Flip-Flops

**File:** [`examples/02_sequential/flip_flops.sv`](examples/02_sequential/flip_flops.sv)

The **D flip-flop** is the fundamental building block. The file includes five variants:

```systemverilog
// D-FF with synchronous reset (reset only on clock edge)
always_ff @(posedge clk) begin
    if (!rst_n) q <= 1'b0;
    else        q <= d;
end

// D-FF with asynchronous reset (reset immediately, regardless of clock)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= 1'b0;
    else        q <= d;
end

// D-FF with clock enable
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)    q <= 1'b0;
    else if (en)   q <= d;
    // else: q retains its value (enable is low)
end
```

**When to use which reset style:**
- **Asynchronous reset** (`negedge rst_n` in sensitivity list): Use for power-on-reset and global resets. The register clears immediately without waiting for a clock edge.
- **Synchronous reset** (reset checked inside `always_ff` but not in sensitivity list): Cleaner timing, fewer reset tree routing issues. Preferred in most modern FPGA/ASIC flows.

### 4.2 Shift Registers

**File:** [`examples/02_sequential/shift_register.sv`](examples/02_sequential/shift_register.sv)

Shift registers move data one position per clock cycle. Four types are provided:

| Type | Acronym | Input | Output | Use Case |
|---|---|---|---|---|
| Serial-In Serial-Out | SISO | 1 bit/cycle | 1 bit/cycle | Delay lines |
| Parallel-In Serial-Out | PISO | N bits at once | 1 bit/cycle | Parallel-to-serial conversion |
| Serial-In Parallel-Out | SIPO | 1 bit/cycle | N bits at once | Serial-to-parallel conversion |
| Universal | - | Both | Both | SPI, configurable shift |

```systemverilog
// SISO: data shifts through WIDTH stages
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        shift_reg <= '0;
    else
        shift_reg <= {shift_reg[WIDTH-2:0], serial_in};
end
assign serial_out = shift_reg[WIDTH-1];
```

The **universal shift register** supports all modes via a 2-bit `mode` select:

```systemverilog
case (mode)
    2'b00: parallel_out <= parallel_out;                       // Hold
    2'b01: parallel_out <= {serial_in_l, parallel_out[WIDTH-1:1]}; // Shift Right
    2'b10: parallel_out <= {parallel_out[WIDTH-2:0], serial_in_r}; // Shift Left
    2'b11: parallel_out <= parallel_in;                        // Parallel Load
endcase
```

### 4.3 Counters

**File:** [`examples/02_sequential/counter.sv`](examples/02_sequential/counter.sv)

Four counter types demonstrate progressively more complex sequential logic:

**Up Counter** with enable, clear, and overflow detection:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)        count <= '0;
    else if (clear)    count <= '0;
    else if (enable)   count <= count + 1'b1;
end
assign overflow = enable & (&count);  // All bits 1 = about to overflow
```

**Modulo-N Counter** (counts 0 to N-1, then wraps):

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= '0;
    else if (enable) begin
        if (count == N - 1)
            count <= '0;       // Wrap around
        else
            count <= count + 1'b1;
    end
end
assign tick = enable & (count == N - 1);  // Pulse when wrapping
```

**Gray Code Counter** — only one bit changes per transition, critical for CDC (Clock Domain Crossing):

```systemverilog
// Binary to Gray conversion
assign gray_count = binary_count ^ (binary_count >> 1);
```

---

## 5. Finite State Machines (FSMs)

FSMs are the control backbone of digital systems. SystemVerilog's enum types and case statements make them clear and maintainable.

### Moore vs Mealy Machines

```
Moore Machine:                  Mealy Machine:
  Output = f(state)               Output = f(state, input)
  ┌───────────┐                   ┌───────────┐
  │   State   │──── Output        │   State   │─┬── Output
  │  Register │                   │  Register │ │
  └─────┬─────┘                   └─────┬─────┘ │
        │                               │       │
  ┌─────▼─────┐                   ┌─────▼─────┐ │
  │Next State  │◄── Input         │Next State  │◄┘── Input
  │   Logic    │                  │   Logic    │
  └────────────┘                  └────────────┘
```

- **Moore:** Outputs change only on clock edges (more stable, one cycle latency).
- **Mealy:** Outputs can change combinationally with inputs (faster response, but can cause glitches).

### 5.1 Traffic Light Controller (Moore FSM)

**File:** [`examples/03_fsm/traffic_light.sv`](examples/03_fsm/traffic_light.sv)

A practical Moore FSM controlling an intersection with a main road and a side road:

```systemverilog
typedef enum logic [2:0] {
    MAIN_GREEN   = 3'b000,
    MAIN_YELLOW  = 3'b001,
    SIDE_GREEN   = 3'b010,
    SIDE_YELLOW  = 3'b011,
    ALL_RED      = 3'b100
} state_e;

// State register (sequential)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= MAIN_GREEN;
    else        state <= next_state;
end

// Next-state logic (combinational)
always_comb begin
    next_state = state;  // Default: stay in current state
    case (state)
        MAIN_GREEN:
            if (timer_done && sensor_side)
                next_state = MAIN_YELLOW;
        MAIN_YELLOW:
            if (timer_done)
                next_state = ALL_RED;
        // ... more transitions
    endcase
end

// Output logic: depends ONLY on state (Moore)
always_comb begin
    case (state)
        MAIN_GREEN:  begin main_light = 3'b001; side_light = 3'b100; end
        MAIN_YELLOW: begin main_light = 3'b010; side_light = 3'b100; end
        // {Red, Yellow, Green}
    endcase
end
```

**FSM coding pattern (recommended 3-block style):**
1. **State register** (`always_ff`): Updates state on clock edge.
2. **Next-state logic** (`always_comb`): Determines `next_state` based on current state and inputs.
3. **Output logic** (`always_comb`): Generates outputs from state (Moore) or state+inputs (Mealy).

### 5.2 Vending Machine (Mealy FSM)

**File:** [`examples/03_fsm/vending_machine.sv`](examples/03_fsm/vending_machine.sv)

A Mealy machine where outputs depend on both state AND inputs — the `dispense` signal asserts in the same cycle as the coin input that reaches the threshold:

```systemverilog
// Next-state and output logic combined (Mealy)
always_comb begin
    next_state = state;
    dispense   = 1'b0;
    change     = 1'b0;

    case (state)
        TEN: begin
            if (nickel) begin
                next_state = IDLE;
                dispense   = 1'b1;  // Output depends on state AND input
            end else if (dime) begin
                next_state = IDLE;
                dispense   = 1'b1;
                change     = 1'b1;  // 10+10=20, return 5c change
            end
        end
        // ...
    endcase
end
```

### 5.3 UART Receiver (Complex FSM)

**File:** [`examples/03_fsm/uart_receiver.sv`](examples/03_fsm/uart_receiver.sv)

A practical UART receiver showing how FSMs interact with parameterized timing and metastability handling:

```systemverilog
// Double-register to prevent metastability from async input
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_sync_0 <= 1'b1;
        rx_sync_1 <= 1'b1;
    end else begin
        rx_sync_0 <= rx;          // First sync stage
        rx_sync_1 <= rx_sync_0;   // Second sync stage — safe to use
    end
end
```

State transitions: `IDLE → START_BIT → DATA_BITS (×8) → STOP_BIT → DONE`

---

## 6. Memory Design

### 6.1 Single-Port RAM

**File:** [`examples/04_memory/single_port_ram.sv`](examples/04_memory/single_port_ram.sv)

The simplest RAM — one port for both reads and writes:

```systemverilog
module single_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10   // 1024 entries
)(
    input  logic                  clk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);
    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
        data_out <= mem[addr];   // Read-after-write: returns OLD data
    end
endmodule
```

**Synthesis note:** This coding style infers Block RAM (BRAM) on FPGAs. The read occurs synchronously (registered output), which synthesis tools recognize as a BRAM pattern.

### 6.2 Dual-Port RAM

**File:** [`examples/04_memory/dual_port_ram.sv`](examples/04_memory/dual_port_ram.sv)

Two independent ports, potentially in different clock domains:

```systemverilog
// Port A
always_ff @(posedge clk_a) begin
    if (we_a)
        mem[addr_a] <= data_in_a;
    data_out_a <= mem[addr_a];
end

// Port B
always_ff @(posedge clk_b) begin
    if (we_b)
        mem[addr_b] <= data_in_b;
    data_out_b <= mem[addr_b];
end
```

**Warning:** Simultaneous writes to the same address from both ports causes undefined behavior. Use arbitration or protocol-level guarantees to prevent this.

### 6.3 Synchronous FIFO

**File:** [`examples/04_memory/sync_fifo.sv`](examples/04_memory/sync_fifo.sv)

FIFOs (First-In First-Out buffers) are essential for rate-matching and decoupling producer/consumer pairs:

```
Write ─► ┌──┬──┬──┬──┬──┬──┬──┬──┐ ─► Read
          │D0│D1│D2│D3│  │  │  │  │
          └──┴──┴──┴──┴──┴──┴──┴──┘
          ▲ wr_ptr            ▲ rd_ptr

  full  = (count == DEPTH)
  empty = (count == 0)
```

```systemverilog
// FIFO count tracking handles simultaneous read+write
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        fifo_count <= '0;
    else begin
        case ({wr_en && !full, rd_en && !empty})
            2'b10:   fifo_count <= fifo_count + 1'b1;  // Write only
            2'b01:   fifo_count <= fifo_count - 1'b1;  // Read only
            default: fifo_count <= fifo_count;          // Both or neither
        endcase
    end
end
```

### 6.4 ROM and Lookup Tables

**File:** [`examples/04_memory/rom.sv`](examples/04_memory/rom.sv)

ROMs can be initialized from hex files or computed at elaboration time:

```systemverilog
// ROM initialized from file
logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
initial begin
    $readmemh(INIT_FILE, mem);
end

// Sine lookup table (computed at elaboration)
initial begin
    for (int i = 0; i < DEPTH; i++)
        sine_table[i] = $rtoi($floor(127.0 * $sin(2.0 * 3.14159 * real'(i) / 256.0) + 128.0));
end
```

---

## 7. Datapath Design

A datapath is the collection of functional units (ALU, registers, muxes) and the data buses connecting them.

### 7.1 Register File

**File:** [`examples/05_datapath/register_file.sv`](examples/05_datapath/register_file.sv)

A register file with 2 read ports and 1 write port — the core of a processor's register bank:

```systemverilog
// Read with write-forwarding: if reading the register being written,
// forward the new data instead of the stale register value
assign rd_data_a = (rd_addr_a == '0)               ? '0 :
                   (wr_en && wr_addr == rd_addr_a)  ? wr_data :
                   regs[rd_addr_a];
```

**Write-forwarding** solves the read-after-write hazard: without it, a read in the same cycle as a write would return stale data.

### 7.2 Simple CPU Datapath

**File:** [`examples/05_datapath/simple_cpu_datapath.sv`](examples/05_datapath/simple_cpu_datapath.sv)

This module ties together the register file and ALU into a processor-like datapath:

```
                    ┌──────────────┐
 rs1 ──►│              │──► rd_data_a ──► ALU operand_a
 rs2 ──►│ Register File│──► rd_data_b ──┐
 rd  ──►│              │               │
         └──────┬───────┘              MUX (alu_src)
                │ wr_data               │     │
                │                   immediate │
         MUX (mem_to_reg)              ▼     ▼
          │           │          ┌─────────────┐
     ALU result   mem_read_data  │     ALU     │──► result ──► mem_addr
                                 └─────────────┘
                                       │
                                    zero_flag
```

```systemverilog
// ALU source MUX: choose between register data and immediate
assign alu_input_b = alu_src ? immediate : rd_data_b;

// Write-back MUX: choose between ALU result and memory data
assign write_back_data = mem_to_reg ? mem_read_data : alu_result;
```

---

## 8. Pipelining

Pipelining increases throughput by dividing a computation into stages separated by registers. Each stage operates on different data simultaneously.

**File:** [`examples/06_pipeline/pipeline_example.sv`](examples/06_pipeline/pipeline_example.sv)

### 8.1 Basic 3-Stage Pipeline

```
Clock:    |  1  |  2  |  3  |  4  |  5  |
Stage 1:  | D0  | D1  | D2  | D3  |     |  ← Input Registration
Stage 2:  |     | D0  | D1  | D2  | D3  |  ← Compute
Stage 3:  |     |     | D0  | D1  | D2  |  ← Output Registration

Latency = 3 cycles (first result after 3 clocks)
Throughput = 1 result/cycle (after pipeline fills)
```

```systemverilog
// Stage 1: Register inputs
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s1_data_a <= '0;
        s1_data_b <= '0;
        s1_op     <= '0;
        s1_valid  <= 1'b0;
    end else begin
        s1_data_a <= data_a_in;
        s1_data_b <= data_b_in;
        s1_op     <= op_in;
        s1_valid  <= valid_in;
    end
end

// Stage 2: Compute
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s2_result <= '0;
        s2_valid  <= 1'b0;
    end else begin
        s2_valid <= s1_valid;
        case (s1_op)
            2'b00: s2_result <= s1_data_a + s1_data_b;
            2'b01: s2_result <= s1_data_a - s1_data_b;
            // ...
        endcase
    end
end

// Stage 3: Output registration
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_out <= '0;
        valid_out  <= 1'b0;
    end else begin
        result_out <= s2_result;
        valid_out  <= s2_valid;
    end
end
```

### 8.2 Pipeline with Hazard Control

Real pipelines need **stall** (freeze the pipeline) and **flush** (clear invalid data):

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stage_out <= '0;
        valid     <= 1'b0;
    end else if (flush) begin     // Clear on flush (e.g., branch mispredict)
        stage_out <= '0;
        valid     <= 1'b0;
    end else if (!stall) begin    // Update only when not stalled
        stage_out <= stage_in;
        valid     <= valid_in;
    end
    // When stalled: registers hold their current values
end
```

---

## 9. Interfaces and Bus Protocols

SystemVerilog **interfaces** bundle related signals into a single named entity, dramatically reducing port clutter and connection errors.

### 9.1 Simple Bus Interface

**File:** [`examples/08_interfaces/simple_bus_interface.sv`](examples/08_interfaces/simple_bus_interface.sv)

```systemverilog
interface simple_bus_if #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
);
    logic                  req;
    logic                  gnt;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  we;
    logic                  valid;
    logic                  ready;

    // Modports restrict signal directions per role
    modport master (
        output req, addr, wdata, we,
        input  gnt, rdata, valid, ready
    );

    modport slave (
        input  req, addr, wdata, we,
        output gnt, rdata, valid, ready
    );
endinterface
```

**Without interfaces:** each module has ~8 bus ports repeated at every hierarchy level.  
**With interfaces:** one `simple_bus_if` connection replaces all of them.

```systemverilog
// Module using the interface
module bus_master (
    input  logic clk,
    input  logic rst_n,
    simple_bus_if.master bus   // single port replaces 8+ signals
);
```

### 9.2 AXI4-Lite Interface and Slave

**File:** [`examples/08_interfaces/axi_lite_interface.sv`](examples/08_interfaces/axi_lite_interface.sv)

A production-relevant example showing the AXI4-Lite protocol with 5 channels (write address, write data, write response, read address, read data). The register bank slave demonstrates:

- FSM-based handshaking for each channel
- Byte-lane write strobes (`wstrb`)
- Response codes (`bresp`, `rresp`)
- Full AXI4-Lite compliant handshake protocol

---

## 10. Parameterized and Reusable Design

**File:** [`examples/07_parameterized/parameterized_designs.sv`](examples/07_parameterized/parameterized_designs.sv)

### 10.1 Round-Robin Arbiter

Fairly distributes access among N requestors using a rotating priority mask:

```systemverilog
module round_robin_arbiter #(parameter NUM_REQ = 4)(
    input  logic clk, rst_n,
    input  logic [NUM_REQ-1:0] req,
    output logic [NUM_REQ-1:0] grant
);
    // Isolate lowest set bit: x & (~x + 1)
    assign grant_masked   = masked_req & (~masked_req + 1'b1);
    assign grant_unmasked = req & (~req + 1'b1);
    assign grant = (|masked_req) ? grant_masked : grant_unmasked;
endmodule
```

### 10.2 Configurable Edge Detector

Uses a string parameter to select behavior at elaboration time:

```systemverilog
module edge_detector #(parameter EDGE_TYPE = "RISING")(
    input  logic clk, rst_n, signal_in,
    output logic edge_detected
);
    logic signal_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) signal_d <= 1'b0;
        else        signal_d <= signal_in;
    end

    generate
        if (EDGE_TYPE == "RISING")
            assign edge_detected = signal_in & ~signal_d;
        else if (EDGE_TYPE == "FALLING")
            assign edge_detected = ~signal_in & signal_d;
        else // "BOTH"
            assign edge_detected = signal_in ^ signal_d;
    endgenerate
endmodule
```

### 10.3 Button Debouncer

Filters mechanical switch bounce using a timer-based approach with a double-flop synchronizer:

```systemverilog
module debouncer #(
    parameter CLK_FREQ_HZ = 50_000_000,
    parameter DEBOUNCE_MS  = 20,
    parameter COUNTER_MAX  = CLK_FREQ_HZ / 1000 * DEBOUNCE_MS
)( /* ... */ );
```

### 10.4 Clock Divider

Divides the input clock by a parameterized factor:

```systemverilog
module clock_divider #(parameter DIV_FACTOR = 10)(
    input  logic clk, rst_n,
    output logic clk_out
);
```

---

## 11. Writing Testbenches

**Directory:** [`examples/09_testbenches/`](examples/09_testbenches/)

### 11.1 Testbench Structure

```
┌─────────────────────────────────┐
│           Testbench             │
│  ┌───────────┐  ┌───────────┐  │
│  │  Stimulus  │  │  Checker  │  │
│  │ Generator  │  │ (Compare  │  │
│  │           │  │ vs Golden) │  │
│  └─────┬─────┘  └─────▲─────┘  │
│        │              │        │
│        ▼              │        │
│  ┌─────────────────────┐       │
│  │   DUT (Design       │       │
│  │   Under Test)       │       │
│  └─────────────────────┘       │
└─────────────────────────────────┘
```

### 11.2 ALU Testbench

**File:** [`examples/09_testbenches/alu_tb.sv`](examples/09_testbenches/alu_tb.sv)

Key techniques demonstrated:

**Reusable test task:**
```systemverilog
task automatic test_alu(
    input logic [WIDTH-1:0] a, b,
    input logic [3:0]       op,
    input logic [WIDTH-1:0] expected,
    input string            op_name
);
    operand_a = a;
    operand_b = b;
    alu_op    = op;
    #1;
    if (result !== expected)
        $error("FAIL: %s: %0h op %0h = %0h, expected %0h",
               op_name, a, b, result, expected);
    else
        $display("PASS: %s: %0h op %0h = %0h", op_name, a, b, result);
endtask
```

**SystemVerilog assertions:**
```systemverilog
assert (zero == 1'b1) else $error("Zero flag should be set for 5-5");
```

**Waveform dumping:**
```systemverilog
initial begin
    $dumpfile("alu_tb.vcd");
    $dumpvars(0, alu_tb);
end
```

### 11.3 Counter Testbench (Clock-Driven)

**File:** [`examples/09_testbenches/counter_tb.sv`](examples/09_testbenches/counter_tb.sv)

Demonstrates:
- Clock generation: `always #5 clk = ~clk;`
- Reset sequence: hold reset for multiple cycles
- `repeat (N) @(posedge clk)` for cycle-accurate delays
- Overflow and wrap-around verification

### 11.4 FIFO Testbench (Self-Checking with Reference Model)

**File:** [`examples/09_testbenches/fifo_tb.sv`](examples/09_testbenches/fifo_tb.sv)

Uses a SystemVerilog dynamic array (`$`) as a golden reference:

```systemverilog
logic [DATA_WIDTH-1:0] ref_queue [$];  // Reference model

task automatic write_fifo(input logic [DATA_WIDTH-1:0] data);
    wr_en = 1'b1; wr_data = data;
    @(posedge clk); #1;
    wr_en = 1'b0;
    if (!full)
        ref_queue.push_back(data);  // Track in reference
endtask
```

Tests include: empty/full flags, write-when-full protection, FIFO ordering, and simultaneous read/write.

---

## 12. RTL Design Best Practices

### Coding Guidelines

| Rule | Why |
|---|---|
| Use `logic` instead of `reg`/`wire` | `logic` works everywhere; `reg` and `wire` are legacy |
| Use `always_comb` and `always_ff` | Tool checks for unintended latches and missing sensitivity |
| `=` in `always_comb`, `<=` in `always_ff` | Prevents simulation/synthesis mismatches |
| Always have a `default` in `case` | Avoids inferred latches in combinational logic |
| Use `enums` for FSM states | Self-documenting, tool-checked, shows in waveforms |
| Reset all flip-flops | Prevents X propagation; necessary for FPGA and ASIC |
| Use parameters for magic numbers | Makes code reusable and configurable |
| One module per file | Matches synthesis tool expectations |

### Avoiding Common Pitfalls

**Unintended Latches:**
```systemverilog
// BAD: missing else creates a latch
always_comb begin
    if (sel)
        out = a;
    // What happens when sel=0? → latch!
end

// GOOD: assign default before the if
always_comb begin
    out = '0;       // Default assignment
    if (sel)
        out = a;
end
```

**Incomplete Case Statements:**
```systemverilog
// BAD: missing cases create latches
always_comb begin
    case (state)
        IDLE: out = 1'b0;
        RUN:  out = 1'b1;
        // DONE is missing → latch!
    endcase
end

// GOOD: use default
always_comb begin
    case (state)
        IDLE:    out = 1'b0;
        RUN:     out = 1'b1;
        default: out = 1'b0;
    endcase
end
```

**Clock Domain Crossing (CDC):**
```systemverilog
// BAD: using a signal from another clock domain directly
always_ff @(posedge clk_b) begin
    data <= signal_from_clk_a;  // Metastability risk!
end

// GOOD: double-flop synchronizer
logic sync_0, sync_1;
always_ff @(posedge clk_b) begin
    sync_0 <= signal_from_clk_a;
    sync_1 <= sync_0;  // Safe to use sync_1
end
```

### Naming Conventions

| Pattern | Example | Meaning |
|---|---|---|
| `_n` suffix | `rst_n`, `cs_n` | Active-low signal |
| `_i` / `_o` suffix | `data_i`, `valid_o` | Input / Output |
| `_d` / `_q` suffix | `data_d`, `data_q` | Combinational / Registered version |
| `_e` suffix | `state_e` | Enumerated type |
| `_t` suffix | `instruction_t` | Typedef / struct type |
| `_s` prefix | `s1_data`, `s2_result` | Pipeline stage |
| `clk_` prefix | `clk_100m`, `clk_sys` | Clock signal |

### Synthesis-Friendly Patterns

```systemverilog
// Use $clog2 for address widths derived from depth
parameter DEPTH = 1024;
parameter ADDR_W = $clog2(DEPTH);  // = 10

// Use packed structs for bit-field manipulation
typedef struct packed {
    logic [3:0] tag;
    logic [7:0] data;
} frame_t;

// Use localparam for derived constants (not overridable)
localparam HALF_PERIOD = PERIOD / 2;
```

---

## 13. Repository Structure

```
.
├── README.md                              ← This tutorial
└── examples/
    ├── 01_combinational/
    │   ├── mux4to1.sv                     ← Multiplexer (3 styles)
    │   ├── decoder.sv                     ← Decoder + Priority Encoder
    │   ├── alu.sv                         ← 10-operation ALU
    │   └── adder.sv                       ← Ripple Carry + Carry Look-Ahead
    ├── 02_sequential/
    │   ├── flip_flops.sv                  ← D-FF, T-FF, JK-FF variants
    │   ├── shift_register.sv              ← SISO, PISO, SIPO, Universal
    │   └── counter.sv                     ← Up, Up/Down, Mod-N, Gray Code
    ├── 03_fsm/
    │   ├── traffic_light.sv               ← Moore FSM traffic controller
    │   ├── vending_machine.sv             ← Mealy FSM vending machine
    │   └── uart_receiver.sv               ← UART 8N1 receiver FSM
    ├── 04_memory/
    │   ├── single_port_ram.sv             ← Single-port synchronous RAM
    │   ├── dual_port_ram.sv               ← True dual-port RAM
    │   ├── sync_fifo.sv                   ← Synchronous FIFO buffer
    │   └── rom.sv                         ← ROM + Sine lookup table
    ├── 05_datapath/
    │   ├── register_file.sv               ← 2R1W register file
    │   └── simple_cpu_datapath.sv         ← ALU + RegFile CPU datapath
    ├── 06_pipeline/
    │   └── pipeline_example.sv            ← 3-stage pipeline + hazard control
    ├── 07_parameterized/
    │   └── parameterized_designs.sv       ← Arbiter, clock div, edge det, debounce
    ├── 08_interfaces/
    │   ├── simple_bus_interface.sv         ← Bus interface + master/slave
    │   └── axi_lite_interface.sv          ← AXI4-Lite interface + register bank
    └── 09_testbenches/
        ├── alu_tb.sv                      ← ALU testbench with tasks
        ├── counter_tb.sv                  ← Counter testbench with assertions
        └── fifo_tb.sv                     ← FIFO self-checking testbench
```

---

## Getting Started

### Prerequisites

To simulate the examples, you need a SystemVerilog simulator. Options include:

- **Icarus Verilog** (open source): `iverilog -g2012 -o sim example.sv && vvp sim`
- **Verilator** (open source, lint/sim): `verilator --lint-only example.sv`
- **ModelSim/QuestaSim** (commercial): `vlog example.sv && vsim module_name`
- **VCS** (commercial): `vcs -sverilog example.sv && ./simv`
- **Xcelium** (commercial): `xrun example.sv`

### Running an Example

```bash
# Using Icarus Verilog
iverilog -g2012 -o alu_sim examples/01_combinational/alu.sv examples/09_testbenches/alu_tb.sv
vvp alu_sim

# View waveforms (if GTKWave is installed)
gtkwave alu_tb.vcd
```

---

## License

This tutorial and all examples are provided for educational purposes. Feel free to use, modify, and distribute.
