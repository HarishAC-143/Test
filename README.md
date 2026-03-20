# FPGA RTL Design with SystemVerilog: From Basics to Advanced

A comprehensive, hands-on tutorial covering FPGA RTL design using SystemVerilog. Each section includes theory, synthesizable code examples, and testbenches you can simulate with any IEEE 1800-compliant tool (Vivado, Quartus, VCS, ModelSim, Verilator, etc.).

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [SystemVerilog Basics](#2-systemverilog-basics)
3. [Combinational Logic](#3-combinational-logic)
4. [Sequential Logic](#4-sequential-logic)
5. [Finite State Machines](#5-finite-state-machines)
6. [Parameterized & Reusable Modules](#6-parameterized--reusable-modules)
7. [Interfaces & Packages](#7-interfaces--packages)
8. [Generate Blocks](#8-generate-blocks)
9. [SystemVerilog Assertions (SVA)](#9-systemverilog-assertions-sva)
10. [Synchronous FIFO](#10-synchronous-fifo)
11. [Asynchronous FIFO & Clock Domain Crossing](#11-asynchronous-fifo--clock-domain-crossing)
12. [Pipelined Datapath](#12-pipelined-datapath)
13. [AXI4-Lite Slave](#13-axi4-lite-slave)
14. [Memory Controller](#14-memory-controller)
15. [UART Transceiver](#15-uart-transceiver)
16. [SPI Master](#16-spi-master)
17. [Hardware Timer / PWM](#17-hardware-timer--pwm)
18. [Round-Robin Arbiter](#18-round-robin-arbiter)
19. [Writing Effective Testbenches](#19-writing-effective-testbenches)
20. [Synthesis & FPGA Best Practices](#20-synthesis--fpga-best-practices)

---

## 1. Introduction

### What is an FPGA?

A **Field-Programmable Gate Array (FPGA)** is a semiconductor device containing an array of configurable logic blocks (CLBs) connected via programmable interconnects. Unlike ASICs, FPGAs can be reprogrammed after manufacturing, making them ideal for prototyping, low-volume production, and applications requiring hardware reconfigurability.

### Key FPGA Resources

| Resource | Description |
|---|---|
| **LUTs** | Look-Up Tables implement combinational logic (typically 4-6 input) |
| **Flip-Flops** | Single-bit storage elements for sequential logic |
| **Block RAM** | Dedicated memory blocks (typically 18 Kb or 36 Kb) |
| **DSP Slices** | Hardened multiply-accumulate units |
| **I/O Banks** | Configurable I/O pins with various voltage standards |
| **Clock Resources** | PLLs, MMCMs for clock generation and management |

### RTL Design Flow

```
Specification → RTL Coding (SystemVerilog) → Functional Simulation
     → Synthesis → Place & Route → Timing Analysis → Bitstream → FPGA
```

### Why SystemVerilog for RTL?

SystemVerilog (IEEE 1800) extends Verilog with:
- **Stronger typing** (`logic`, `enum`, `struct`, `union`)
- **`always_comb` / `always_ff` / `always_latch`** — intent-driven procedural blocks
- **Interfaces** — bundle ports and protocols into reusable units
- **Packages** — share types, parameters, and functions across modules
- **Assertions (SVA)** — embed protocol checks directly in RTL
- **Parameterized types** — write truly generic, reusable IP

---

## 2. SystemVerilog Basics

### Data Types

SystemVerilog introduces the `logic` type, which replaces the need to choose between `reg` and `wire`. The `logic` type is a 4-state type (0, 1, X, Z) that can be used for both driven nets and procedural assignments.

```systemverilog
// 4-state types (for RTL)
logic              single_bit;      // 1-bit, replaces reg/wire
logic [7:0]        byte_val;        // 8-bit vector
logic [31:0]       word;            // 32-bit vector
logic signed [15:0] signed_val;    // signed 16-bit

// 2-state types (for testbenches — faster simulation)
bit                fast_bit;
int                counter;         // 32-bit signed
shortint           small;           // 16-bit signed
longint            big;             // 64-bit signed
byte               octet;           // 8-bit signed

// Enumerated types — invaluable for FSMs
typedef enum logic [1:0] {
    IDLE  = 2'b00,
    RUN   = 2'b01,
    DONE  = 2'b10
} state_t;

// Structures — group related signals
typedef struct packed {
    logic [7:0]  addr;
    logic [31:0] data;
    logic        valid;
} bus_req_t;

// Unions — overlay different views of the same bits
typedef union packed {
    logic [31:0] word;
    struct packed {
        logic [15:0] upper;
        logic [15:0] lower;
    } halves;
} word_view_t;
```

> **Example file:** [`examples/01_basics/data_types.sv`](examples/01_basics/data_types.sv)

### Module Declaration

```systemverilog
module adder #(
    parameter int WIDTH = 8           // parameterize the bit-width
)(
    input  logic [WIDTH-1:0] a, b,    // operands
    input  logic             cin,     // carry-in
    output logic [WIDTH-1:0] sum,     // result
    output logic             cout     // carry-out
);
    assign {cout, sum} = a + b + cin;
endmodule
```

> **Example file:** [`examples/01_basics/adder.sv`](examples/01_basics/adder.sv)

### Arrays and Memories

```systemverilog
// Packed arrays — treated as a single vector
logic [3:0][7:0] packed_word;  // 32 bits: 4 bytes packed together

// Unpacked arrays — separate storage elements
logic [7:0] mem [0:255];       // 256-entry memory, 8 bits each

// Multi-dimensional
logic [7:0] frame [0:479][0:639]; // 480×640 frame buffer
```

---

## 3. Combinational Logic

Combinational logic produces outputs that depend only on the current inputs — there is no memory or clock involved. SystemVerilog provides two primary ways to describe combinational logic.

### Continuous Assignments (`assign`)

Best for simple, single-expression logic:

```systemverilog
module priority_encoder (
    input  logic [7:0] req,
    output logic [2:0] grant,
    output logic       valid
);
    always_comb begin
        valid = |req;
        grant = '0;
        for (int i = 7; i >= 0; i--) begin
            if (req[i]) begin
                grant = i[2:0];
                break;
            end
        end
    end
endmodule
```

### `always_comb` Blocks

Use `always_comb` (not `always @(*)`) for combinational logic. The compiler verifies that no latches are inferred and that all outputs are assigned on every path.

```systemverilog
module alu #(
    parameter int WIDTH = 32
)(
    input  logic [WIDTH-1:0]  a, b,
    input  logic [3:0]        op,
    output logic [WIDTH-1:0]  result,
    output logic              zero
);
    always_comb begin
        result = '0;
        unique case (op)
            4'b0000: result = a + b;
            4'b0001: result = a - b;
            4'b0010: result = a & b;
            4'b0011: result = a | b;
            4'b0100: result = a ^ b;
            4'b0101: result = a << b[4:0];
            4'b0110: result = a >> b[4:0];
            4'b0111: result = $signed(a) >>> b[4:0];
            4'b1000: result = {{(WIDTH-1){1'b0}}, $signed(a) < $signed(b)};
            default: result = '0;
        endcase
        zero = (result == '0);
    end
endmodule
```

> **Example files:** [`examples/02_combinational/`](examples/02_combinational/)

### Common Combinational Patterns

| Pattern | Use Case | Keyword |
|---|---|---|
| Multiplexer | Select one of N inputs | `unique case` / ternary |
| Decoder | One-hot from binary | Shift or case |
| Priority Encoder | Binary from one-hot | `for` with `break` |
| Barrel Shifter | Arbitrary-width shift | Cascaded muxes |
| Comparator | Magnitude/equality | Relational operators |

---

## 4. Sequential Logic

Sequential logic stores state across clock cycles. In SystemVerilog, always use `always_ff` for flip-flop inference.

### Basic Flip-Flop Patterns

```systemverilog
// D flip-flop with synchronous active-low reset
always_ff @(posedge clk) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// D flip-flop with asynchronous active-low reset
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// Flip-flop with clock enable
always_ff @(posedge clk) begin
    if (!rst_n)
        q <= '0;
    else if (en)
        q <= d;
end
```

### Shift Register

```systemverilog
module shift_register #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 4
)(
    input  logic             clk, rst_n,
    input  logic             shift_en,
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] stage [DEPTH];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++)
                stage[i] <= '0;
        end else if (shift_en) begin
            stage[0] <= data_in;
            for (int i = 1; i < DEPTH; i++)
                stage[i] <= stage[i-1];
        end
    end

    assign data_out = stage[DEPTH-1];
endmodule
```

### Counter with Wrap and Terminal Count

```systemverilog
module counter #(
    parameter int WIDTH = 8,
    parameter int MAX_COUNT = (2**WIDTH) - 1
)(
    input  logic             clk, rst_n, en, load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             tc     // terminal count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (load)
            count <= load_val;
        else if (en)
            count <= (count == MAX_COUNT[WIDTH-1:0]) ? '0 : count + 1'b1;
    end

    assign tc = en && (count == MAX_COUNT[WIDTH-1:0]);
endmodule
```

> **Example files:** [`examples/03_sequential/`](examples/03_sequential/)

---

## 5. Finite State Machines

FSMs are the backbone of control logic in RTL design. SystemVerilog's `enum` type and `unique case` make FSMs cleaner and safer.

### Coding Style: Two-Process (Recommended for FPGA)

Separate the **state register** (sequential) from the **next-state & output logic** (combinational):

```systemverilog
module traffic_light_fsm (
    input  logic clk, rst_n,
    input  logic sensor,
    output logic red, yellow, green
);
    typedef enum logic [1:0] {
        S_RED    = 2'b00,
        S_GREEN  = 2'b01,
        S_YELLOW = 2'b10
    } state_t;

    state_t state, next_state;
    logic [3:0] timer, next_timer;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RED;
            timer <= '0;
        end else begin
            state <= next_state;
            timer <= next_timer;
        end
    end

    // Next-state and output logic
    always_comb begin
        next_state = state;
        next_timer = timer + 4'd1;
        {red, yellow, green} = 3'b000;

        unique case (state)
            S_RED: begin
                red = 1'b1;
                if (timer == 4'd9 && sensor) begin
                    next_state = S_GREEN;
                    next_timer = '0;
                end
            end
            S_GREEN: begin
                green = 1'b1;
                if (timer == 4'd7) begin
                    next_state = S_YELLOW;
                    next_timer = '0;
                end
            end
            S_YELLOW: begin
                yellow = 1'b1;
                if (timer == 4'd2) begin
                    next_state = S_RED;
                    next_timer = '0;
                end
            end
            default: begin
                next_state = S_RED;
                next_timer = '0;
                red = 1'b1;
            end
        endcase
    end
endmodule
```

### One-Hot Encoding

For FPGA targets, one-hot encoding often yields better timing because next-state logic decodes from a single bit rather than a binary value:

```systemverilog
typedef enum logic [3:0] {
    IDLE   = 4'b0001,
    FETCH  = 4'b0010,
    EXEC   = 4'b0100,
    WRITE  = 4'b1000
} onehot_state_t;
```

> **Example file:** [`examples/04_fsm/traffic_light_fsm.sv`](examples/04_fsm/traffic_light_fsm.sv)

---

## 6. Parameterized & Reusable Modules

Parameters make modules generic and reusable across projects.

### Width-Parameterized FIFO-style Register

```systemverilog
module pipe_reg #(
    parameter int WIDTH = 32,
    parameter bit RESET_VAL = 1'b0
)(
    input  logic             clk, rst_n, en, flush,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= {WIDTH{RESET_VAL}};
        else if (flush)
            q <= {WIDTH{RESET_VAL}};
        else if (en)
            q <= d;
    end
endmodule
```

### Type-Parameterized Module

```systemverilog
module register #(
    parameter type T = logic [7:0]
)(
    input  logic clk, rst_n, en,
    input  T     d,
    output T     q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= T'(0);
        else if (en)
            q <= d;
    end
endmodule
```

> **Example file:** [`examples/05_parameterized/pipe_reg.sv`](examples/05_parameterized/pipe_reg.sv)

---

## 7. Interfaces & Packages

### Packages

Packages share type definitions, parameters, and functions across multiple modules:

```systemverilog
package cpu_pkg;
    parameter int XLEN = 32;

    typedef enum logic [3:0] {
        ALU_ADD, ALU_SUB, ALU_AND, ALU_OR,
        ALU_XOR, ALU_SLL, ALU_SRL, ALU_SRA,
        ALU_SLT, ALU_SLTU
    } alu_op_t;

    typedef struct packed {
        logic [XLEN-1:0] pc;
        logic [XLEN-1:0] instruction;
        logic             valid;
    } fetch_packet_t;

    function automatic logic [XLEN-1:0] sign_extend(
        input logic [15:0] imm
    );
        return {{(XLEN-16){imm[15]}}, imm};
    endfunction
endpackage
```

### Interfaces

Interfaces encapsulate signal bundles and protocol details:

```systemverilog
interface axi_stream_if #(
    parameter int DATA_WIDTH = 32
)(
    input logic clk, rst_n
);
    logic [DATA_WIDTH-1:0]   tdata;
    logic [DATA_WIDTH/8-1:0] tkeep;
    logic                    tvalid;
    logic                    tready;
    logic                    tlast;

    modport master (
        output tdata, tkeep, tvalid, tlast,
        input  tready
    );

    modport slave (
        input  tdata, tkeep, tvalid, tlast,
        output tready
    );
endinterface
```

> **Example files:** [`examples/06_interfaces_packages/`](examples/06_interfaces_packages/)

---

## 8. Generate Blocks

Generate statements create parameterized, replicated, or conditionally included hardware.

### `for` Generate — Ripple-Carry Adder

```systemverilog
module ripple_carry_adder #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0] a, b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    logic [WIDTH:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_fa
            full_adder fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[WIDTH];
endmodule

module full_adder (
    input  logic a, b, cin,
    output logic sum, cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule
```

### `if` Generate — Conditional Architecture

```systemverilog
module sync_or_async_reset #(
    parameter bit ASYNC_RESET = 1
)(
    input  logic clk, rst_n,
    input  logic d,
    output logic q
);
    generate
        if (ASYNC_RESET) begin : gen_async
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) q <= 1'b0;
                else        q <= d;
            end
        end else begin : gen_sync
            always_ff @(posedge clk) begin
                if (!rst_n) q <= 1'b0;
                else        q <= d;
            end
        end
    endgenerate
endmodule
```

> **Example files:** [`examples/07_generate/`](examples/07_generate/)

---

## 9. SystemVerilog Assertions (SVA)

Assertions catch protocol violations and design bugs during simulation. While not synthesizable, they live alongside RTL and dramatically improve verification quality.

### Immediate Assertions

```systemverilog
always_comb begin
    assert (state != ILLEGAL_STATE) else $error("Entered illegal state!");
end
```

### Concurrent Assertions

```systemverilog
module fifo_assertions (
    input logic clk, rst_n,
    input logic wr_en, rd_en, full, empty
);
    // Never write to a full FIFO
    property no_write_when_full;
        @(posedge clk) disable iff (!rst_n)
        full |-> !wr_en;
    endproperty
    assert property (no_write_when_full)
        else $error("Write attempted on full FIFO!");

    // Never read from an empty FIFO
    property no_read_when_empty;
        @(posedge clk) disable iff (!rst_n)
        empty |-> !rd_en;
    endproperty
    assert property (no_read_when_empty)
        else $error("Read attempted on empty FIFO!");

    // Valid handshake: if valid rises, it stays high until ready
    property valid_until_ready;
        @(posedge clk) disable iff (!rst_n)
        $rose(wr_en) && full |-> ##[1:10] !full;
    endproperty

    // Cover property — ensure scenario is reachable
    cover property (@(posedge clk) wr_en && rd_en);
endmodule
```

> **Example file:** [`examples/08_assertions/fifo_assertions.sv`](examples/08_assertions/fifo_assertions.sv)

---

## 10. Synchronous FIFO

A synchronous FIFO is one of the most commonly used building blocks in digital design. It buffers data between a producer and consumer that share the same clock.

### Architecture

```
                 ┌─────────────────────┐
  wr_data ──────►│                     │──────► rd_data
  wr_en ────────►│   Dual-Port RAM     │◄────── rd_en
                 │   (DEPTH entries)   │
                 └─────────────────────┘
                    ▲wr_ptr    ▲rd_ptr
                    │          │
                 ┌──┴──┐   ┌──┴──┐
                 │WR   │   │RD   │
                 │CTRL │   │CTRL │
                 └─────┘   └─────┘
                    │          │
                 full      empty
```

```systemverilog
module sync_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16
)(
    input  logic             clk, rst_n,
    input  logic             wr_en, rd_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic [WIDTH-1:0] rd_data,
    output logic             full, empty,
    output logic [$clog2(DEPTH):0] count
);
    localparam int ADDR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH];
    logic [ADDR_W:0]  wr_ptr, rd_ptr;

    assign full  = (count == DEPTH[$clog2(DEPTH):0]);
    assign empty = (count == '0);

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1'b1;
    end

    assign rd_data = mem[rd_ptr[ADDR_W-1:0]];

    // Count tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else begin
            unique case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
```

> **Example file:** [`examples/09_fifo/sync_fifo.sv`](examples/09_fifo/sync_fifo.sv)

---

## 11. Asynchronous FIFO & Clock Domain Crossing

When data must cross between two clock domains, an asynchronous FIFO using **Gray-code pointers** is the standard solution.

### Gray Code Refresher

Gray code changes only one bit per increment, preventing metastability glitches when a multi-bit pointer is sampled by a different clock domain.

```
Binary → Gray:  gray = binary ^ (binary >> 1)
Gray → Binary:  binary[i] = ^gray[MSB:i]
```

### Asynchronous FIFO

```systemverilog
module async_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16
)(
    // Write side
    input  logic             wr_clk, wr_rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             full,

    // Read side
    input  logic             rd_clk, rd_rst_n,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty
);
    localparam int ADDR_W = $clog2(DEPTH);

    // Dual-port RAM
    logic [WIDTH-1:0] mem [DEPTH];

    // Gray-code pointers
    logic [ADDR_W:0] wr_ptr_bin, wr_ptr_gray;
    logic [ADDR_W:0] rd_ptr_bin, rd_ptr_gray;

    // Synchronized pointers (crossed to opposite domain)
    logic [ADDR_W:0] wr_ptr_gray_rd_sync [2];  // wr→rd domain
    logic [ADDR_W:0] rd_ptr_gray_wr_sync [2];  // rd→wr domain

    // --- Write Domain ---
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_en && !full) begin
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);
            mem[wr_ptr_bin[ADDR_W-1:0]] <= wr_data;
        end
    end

    // Synchronize rd_ptr_gray into wr_clk domain
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_wr_sync[0] <= '0;
            rd_ptr_gray_wr_sync[1] <= '0;
        end else begin
            rd_ptr_gray_wr_sync[0] <= rd_ptr_gray;
            rd_ptr_gray_wr_sync[1] <= rd_ptr_gray_wr_sync[0];
        end
    end

    assign full = (wr_ptr_gray == {~rd_ptr_gray_wr_sync[1][ADDR_W:ADDR_W-1],
                                     rd_ptr_gray_wr_sync[1][ADDR_W-2:0]});

    // --- Read Domain ---
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);
        end
    end

    // Synchronize wr_ptr_gray into rd_clk domain
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_rd_sync[0] <= '0;
            wr_ptr_gray_rd_sync[1] <= '0;
        end else begin
            wr_ptr_gray_rd_sync[0] <= wr_ptr_gray;
            wr_ptr_gray_rd_sync[1] <= wr_ptr_gray_rd_sync[0];
        end
    end

    assign empty = (rd_ptr_gray == wr_ptr_gray_rd_sync[1]);
    assign rd_data = mem[rd_ptr_bin[ADDR_W-1:0]];
endmodule
```

### Two-Flop Synchronizer (Basic CDC)

For single-bit signals crossing clock domains:

```systemverilog
module cdc_sync #(
    parameter int STAGES = 2
)(
    input  logic clk, rst_n,
    input  logic async_in,
    output logic sync_out
);
    logic [STAGES-1:0] sync_chain;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync_chain <= '0;
        else
            sync_chain <= {sync_chain[STAGES-2:0], async_in};
    end

    assign sync_out = sync_chain[STAGES-1];
endmodule
```

> **Example files:** [`examples/12_cdc/`](examples/12_cdc/)

---

## 12. Pipelined Datapath

Pipelining breaks a long combinational path into stages separated by registers, increasing throughput at the cost of latency.

### 4-Stage Pipelined Multiplier-Accumulator

```systemverilog
module pipelined_mac #(
    parameter int A_WIDTH = 16,
    parameter int B_WIDTH = 16,
    parameter int ACC_WIDTH = 48
)(
    input  logic                   clk, rst_n, valid_in, clear,
    input  logic [A_WIDTH-1:0]     a,
    input  logic [B_WIDTH-1:0]     b,
    output logic [ACC_WIDTH-1:0]   acc_out,
    output logic                   valid_out
);
    // Stage 1: Register inputs
    logic [A_WIDTH-1:0]  a_s1;
    logic [B_WIDTH-1:0]  b_s1;
    logic                valid_s1;

    // Stage 2: Multiply
    logic [A_WIDTH+B_WIDTH-1:0] product_s2;
    logic                       valid_s2;

    // Stage 3: Accumulate
    logic [ACC_WIDTH-1:0] acc_s3;
    logic                 valid_s3;

    // Stage 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_s1     <= '0;
            b_s1     <= '0;
            valid_s1 <= 1'b0;
        end else begin
            a_s1     <= a;
            b_s1     <= b;
            valid_s1 <= valid_in;
        end
    end

    // Stage 2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= '0;
            valid_s2   <= 1'b0;
        end else begin
            product_s2 <= a_s1 * b_s1;
            valid_s2   <= valid_s1;
        end
    end

    // Stage 3
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_s3   <= '0;
            valid_s3 <= 1'b0;
        end else if (clear) begin
            acc_s3   <= '0;
            valid_s3 <= 1'b0;
        end else begin
            if (valid_s2)
                acc_s3 <= acc_s3 + ACC_WIDTH'(product_s2);
            valid_s3 <= valid_s2;
        end
    end

    assign acc_out   = acc_s3;
    assign valid_out = valid_s3;
endmodule
```

> **Example file:** [`examples/10_pipeline/pipelined_mac.sv`](examples/10_pipeline/pipelined_mac.sv)

---

## 13. AXI4-Lite Slave

AXI4-Lite is the standard register-access interface in Xilinx and other FPGA ecosystems. Here is a synthesizable slave with a small register file.

```systemverilog
module axi_lite_slave #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS   = 16
)(
    input  logic                    aclk, aresetn,

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]   s_awaddr,
    input  logic                    s_awvalid,
    output logic                    s_awready,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]   s_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_wstrb,
    input  logic                    s_wvalid,
    output logic                    s_wready,

    // Write response channel
    output logic [1:0]              s_bresp,
    output logic                    s_bvalid,
    input  logic                    s_bready,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0]   s_araddr,
    input  logic                    s_arvalid,
    output logic                    s_arready,

    // Read data channel
    output logic [DATA_WIDTH-1:0]   s_rdata,
    output logic [1:0]              s_rresp,
    output logic                    s_rvalid,
    input  logic                    s_rready
);
    localparam int ADDR_LSB = $clog2(DATA_WIDTH / 8);
    localparam int REG_ADDR_W = $clog2(NUM_REGS);

    logic [DATA_WIDTH-1:0] regs [NUM_REGS];

    // Write FSM
    typedef enum logic [1:0] { WR_IDLE, WR_DATA, WR_RESP } wr_state_t;
    wr_state_t wr_state;
    logic [ADDR_WIDTH-1:0] wr_addr_latched;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state       <= WR_IDLE;
            s_awready      <= 1'b0;
            s_wready       <= 1'b0;
            s_bvalid       <= 1'b0;
            s_bresp        <= 2'b00;
            wr_addr_latched <= '0;
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else begin
            unique case (wr_state)
                WR_IDLE: begin
                    s_bvalid  <= 1'b0;
                    s_awready <= 1'b1;
                    s_wready  <= 1'b0;
                    if (s_awvalid && s_awready) begin
                        wr_addr_latched <= s_awaddr;
                        s_awready <= 1'b0;
                        s_wready  <= 1'b1;
                        wr_state  <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    if (s_wvalid && s_wready) begin
                        for (int b = 0; b < DATA_WIDTH/8; b++) begin
                            if (s_wstrb[b])
                                regs[wr_addr_latched[ADDR_LSB +: REG_ADDR_W]][b*8 +: 8]
                                    <= s_wdata[b*8 +: 8];
                        end
                        s_wready <= 1'b0;
                        s_bvalid <= 1'b1;
                        s_bresp  <= 2'b00;
                        wr_state <= WR_RESP;
                    end
                end
                WR_RESP: begin
                    if (s_bvalid && s_bready) begin
                        s_bvalid <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // Read FSM
    typedef enum logic { RD_IDLE, RD_DATA } rd_state_t;
    rd_state_t rd_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state  <= RD_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= '0;
            s_rresp   <= 2'b00;
        end else begin
            unique case (rd_state)
                RD_IDLE: begin
                    s_arready <= 1'b1;
                    s_rvalid  <= 1'b0;
                    if (s_arvalid && s_arready) begin
                        s_rdata   <= regs[s_araddr[ADDR_LSB +: REG_ADDR_W]];
                        s_rresp   <= 2'b00;
                        s_arready <= 1'b0;
                        s_rvalid  <= 1'b1;
                        rd_state  <= RD_DATA;
                    end
                end
                RD_DATA: begin
                    if (s_rvalid && s_rready) begin
                        s_rvalid <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end
endmodule
```

> **Example file:** [`examples/11_axi_lite/axi_lite_slave.sv`](examples/11_axi_lite/axi_lite_slave.sv)

---

## 14. Memory Controller

A simple single-port SRAM controller with registered outputs, demonstrating block RAM inference patterns:

```systemverilog
module sram_controller #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    input  logic                    clk, rst_n,
    input  logic                    req,
    input  logic                    wr_en,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    ack
);
    localparam int DEPTH = 2**ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [DEPTH];
    logic                  req_d;

    always_ff @(posedge clk) begin
        if (req && wr_en)
            mem[addr] <= wr_data;
    end

    always_ff @(posedge clk) begin
        if (req && !wr_en)
            rd_data <= mem[addr];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            req_d <= 1'b0;
        else
            req_d <= req;
    end

    assign ack = req_d;
endmodule
```

> **Example file:** [`examples/13_memory/sram_controller.sv`](examples/13_memory/sram_controller.sv)

---

## 15. UART Transceiver

A complete UART transmitter and receiver with configurable baud rate — one of the most practical FPGA peripherals.

### UART Transmitter

```systemverilog
module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200,
    parameter int DATA_BITS = 8
)(
    input  logic                  clk, rst_n,
    input  logic [DATA_BITS-1:0]  tx_data,
    input  logic                  tx_valid,
    output logic                  tx_ready,
    output logic                  tx_out
);
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int BIT_CNT_W   = $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] { TX_IDLE, TX_START, TX_DATA, TX_STOP } tx_state_t;
    tx_state_t state;

    logic [BIT_CNT_W-1:0]  clk_cnt;
    logic [2:0]            bit_idx;
    logic [DATA_BITS-1:0]  shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= TX_IDLE;
            tx_out    <= 1'b1;
            tx_ready  <= 1'b1;
            clk_cnt   <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
        end else begin
            unique case (state)
                TX_IDLE: begin
                    tx_out   <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        tx_ready  <= 1'b0;
                        clk_cnt   <= '0;
                        state     <= TX_START;
                    end
                end
                TX_START: begin
                    tx_out <= 1'b0;  // start bit
                    if (clk_cnt == CLKS_PER_BIT[BIT_CNT_W-1:0] - 1) begin
                        clk_cnt <= '0;
                        bit_idx <= '0;
                        state   <= TX_DATA;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                TX_DATA: begin
                    tx_out <= shift_reg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT[BIT_CNT_W-1:0] - 1) begin
                        clk_cnt <= '0;
                        if (bit_idx == DATA_BITS[2:0] - 1)
                            state <= TX_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                TX_STOP: begin
                    tx_out <= 1'b1;  // stop bit
                    if (clk_cnt == CLKS_PER_BIT[BIT_CNT_W-1:0] - 1) begin
                        clk_cnt <= '0;
                        state   <= TX_IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
            endcase
        end
    end
endmodule
```

### UART Receiver

```systemverilog
module uart_rx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200,
    parameter int DATA_BITS = 8
)(
    input  logic                  clk, rst_n,
    input  logic                  rx_in,
    output logic [DATA_BITS-1:0]  rx_data,
    output logic                  rx_valid
);
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int BIT_CNT_W   = $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] { RX_IDLE, RX_START, RX_DATA, RX_STOP } rx_state_t;
    rx_state_t state;

    logic [BIT_CNT_W-1:0]  clk_cnt;
    logic [2:0]            bit_idx;
    logic [DATA_BITS-1:0]  shift_reg;
    logic                  rx_sync;

    // Input synchronizer
    cdc_sync #(.STAGES(2)) u_rx_sync (
        .clk      (clk),
        .rst_n    (rst_n),
        .async_in (rx_in),
        .sync_out (rx_sync)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= RX_IDLE;
            rx_valid  <= 1'b0;
            rx_data   <= '0;
            clk_cnt   <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
        end else begin
            rx_valid <= 1'b0;
            unique case (state)
                RX_IDLE: begin
                    if (!rx_sync) begin  // falling edge = start bit
                        clk_cnt <= '0;
                        state   <= RX_START;
                    end
                end
                RX_START: begin
                    // Sample at mid-bit
                    if (clk_cnt == (CLKS_PER_BIT/2)[BIT_CNT_W-1:0]) begin
                        if (!rx_sync) begin
                            clk_cnt <= '0;
                            bit_idx <= '0;
                            state   <= RX_DATA;
                        end else
                            state <= RX_IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                RX_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT[BIT_CNT_W-1:0] - 1) begin
                        clk_cnt <= '0;
                        shift_reg[bit_idx] <= rx_sync;
                        if (bit_idx == DATA_BITS[2:0] - 1)
                            state <= RX_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
                RX_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT[BIT_CNT_W-1:0] - 1) begin
                        if (rx_sync) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                        state <= RX_IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end
            endcase
        end
    end
endmodule
```

> **Example files:** [`examples/14_uart/`](examples/14_uart/)

---

## 16. SPI Master

A configurable SPI master supporting all four SPI modes (CPOL/CPHA):

```systemverilog
module spi_master #(
    parameter int CLK_FREQ    = 50_000_000,
    parameter int SPI_FREQ    = 1_000_000,
    parameter int DATA_WIDTH  = 8
)(
    input  logic                   clk, rst_n,

    // Control
    input  logic [1:0]             spi_mode,   // {CPOL, CPHA}
    input  logic                   start,
    input  logic [DATA_WIDTH-1:0]  mosi_data,
    output logic [DATA_WIDTH-1:0]  miso_data,
    output logic                   busy,
    output logic                   done,

    // SPI bus
    output logic                   sclk,
    output logic                   mosi,
    input  logic                   miso,
    output logic                   cs_n
);
    localparam int CLK_DIV = CLK_FREQ / (2 * SPI_FREQ);
    localparam int DIV_W   = $clog2(CLK_DIV + 1);

    logic [DIV_W-1:0]        clk_cnt;
    logic [DATA_WIDTH-1:0]   tx_shift, rx_shift;
    logic [$clog2(DATA_WIDTH):0] bit_cnt;
    logic                    cpol, cpha;
    logic                    sclk_int, sclk_prev;
    logic                    running;

    assign cpol = spi_mode[1];
    assign cpha = spi_mode[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_int  <= 1'b0;
            sclk_prev <= 1'b0;
            tx_shift  <= '0;
            rx_shift  <= '0;
            bit_cnt   <= '0;
            clk_cnt   <= '0;
            busy      <= 1'b0;
            done      <= 1'b0;
            cs_n      <= 1'b1;
            miso_data <= '0;
            running   <= 1'b0;
        end else begin
            done      <= 1'b0;
            sclk_prev <= sclk_int;

            if (!running) begin
                if (start) begin
                    tx_shift <= mosi_data;
                    rx_shift <= '0;
                    bit_cnt  <= '0;
                    clk_cnt  <= '0;
                    sclk_int <= 1'b0;
                    busy     <= 1'b1;
                    cs_n     <= 1'b0;
                    running  <= 1'b1;
                end
            end else begin
                if (clk_cnt == CLK_DIV[DIV_W-1:0] - 1) begin
                    clk_cnt  <= '0;
                    sclk_int <= ~sclk_int;
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end

                // Leading edge: shift out (CPHA=0) or sample (CPHA=1)
                if (sclk_int && !sclk_prev) begin
                    if (!cpha)
                        rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                    else begin
                        mosi <= tx_shift[DATA_WIDTH-1];
                        tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                    end
                end

                // Trailing edge: sample (CPHA=0) or shift out (CPHA=1)
                if (!sclk_int && sclk_prev) begin
                    if (!cpha) begin
                        mosi <= tx_shift[DATA_WIDTH-1];
                        tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                    end else
                        rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};

                    bit_cnt <= bit_cnt + 1'b1;
                    if (bit_cnt == DATA_WIDTH[$clog2(DATA_WIDTH):0] - 1) begin
                        miso_data <= cpha ? {rx_shift[DATA_WIDTH-2:0], miso}
                                          : rx_shift;
                        running   <= 1'b0;
                        busy      <= 1'b0;
                        done      <= 1'b1;
                        cs_n      <= 1'b1;
                    end
                end
            end
        end
    end

    assign sclk = sclk_int ^ cpol;
    assign mosi = running ? tx_shift[DATA_WIDTH-1] : 1'b0;
endmodule
```

> **Example file:** [`examples/15_spi/spi_master.sv`](examples/15_spi/spi_master.sv)

---

## 17. Hardware Timer / PWM

A multi-channel timer with PWM output — useful for motor control, LED dimming, or general timing:

```systemverilog
module pwm_timer #(
    parameter int WIDTH       = 16,
    parameter int NUM_CHANNELS = 4
)(
    input  logic             clk, rst_n,
    input  logic             enable,
    input  logic [WIDTH-1:0] period,
    input  logic [WIDTH-1:0] duty [NUM_CHANNELS],
    output logic [NUM_CHANNELS-1:0] pwm_out,
    output logic             overflow
);
    logic [WIDTH-1:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= '0;
        else if (enable) begin
            if (counter >= period)
                counter <= '0;
            else
                counter <= counter + 1'b1;
        end
    end

    assign overflow = enable && (counter == period);

    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch++) begin : gen_pwm
            always_comb begin
                pwm_out[ch] = (counter < duty[ch]) ? 1'b1 : 1'b0;
            end
        end
    endgenerate
endmodule
```

> **Example file:** [`examples/16_timer/pwm_timer.sv`](examples/16_timer/pwm_timer.sv)

---

## 18. Round-Robin Arbiter

A fair arbiter that grants access to requestors in round-robin order — essential for shared-bus and crossbar designs:

```systemverilog
module round_robin_arbiter #(
    parameter int NUM_REQ = 4
)(
    input  logic                  clk, rst_n,
    input  logic [NUM_REQ-1:0]    req,
    output logic [NUM_REQ-1:0]    grant,
    output logic                  valid
);
    logic [NUM_REQ-1:0] mask, masked_req, next_mask;
    logic [NUM_REQ-1:0] grant_masked, grant_unmasked;

    // Masked request (suppress previously serviced requestors)
    assign masked_req = req & mask;

    // Priority encoder for masked requests
    always_comb begin
        grant_masked = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (masked_req[i]) begin
                grant_masked[i] = 1'b1;
                break;
            end
        end
    end

    // Priority encoder for unmasked requests (fallback)
    always_comb begin
        grant_unmasked = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (req[i]) begin
                grant_unmasked[i] = 1'b1;
                break;
            end
        end
    end

    // Choose masked grant if any masked request is active
    assign grant = (|masked_req) ? grant_masked : grant_unmasked;
    assign valid = |req;

    // Update mask after each grant
    always_comb begin
        next_mask = '1;
        if (valid) begin
            next_mask = '0;
            for (int i = NUM_REQ-1; i >= 0; i--) begin
                if (grant[i])
                    next_mask = '0;
                else if (!grant[i] && (i > 0 || !grant[0]))
                    next_mask[i] = !grant[i];
            end
            // Set mask bits above the granted position
            for (int i = 0; i < NUM_REQ; i++) begin
                if (grant[i]) begin
                    for (int j = i+1; j < NUM_REQ; j++)
                        next_mask[j] = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mask <= '1;
        else if (valid)
            mask <= next_mask;
    end
endmodule
```

> **Example file:** [`examples/17_arbiter/round_robin_arbiter.sv`](examples/17_arbiter/round_robin_arbiter.sv)

---

## 19. Writing Effective Testbenches

### Testbench Structure

A good SystemVerilog testbench follows this structure:

```
testbench
  ├── Clock & reset generation
  ├── DUT instantiation
  ├── Stimulus generation (tasks / sequences)
  ├── Output checking (monitors / scoreboards)
  └── Coverage collection
```

### Example: Synchronous FIFO Testbench

```systemverilog
module tb_sync_fifo;
    parameter int WIDTH = 8;
    parameter int DEPTH = 16;

    logic             clk, rst_n;
    logic             wr_en, rd_en;
    logic [WIDTH-1:0] wr_data, rd_data;
    logic             full, empty;
    logic [$clog2(DEPTH):0] count;

    // Clock generation
    initial clk = 1'b0;
    always #5ns clk = ~clk;

    // DUT
    sync_fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (.*);

    // Scoreboard
    logic [WIDTH-1:0] expected_queue [$];
    int pass_count, fail_count;

    task automatic reset_dut();
        rst_n  <= 1'b0;
        wr_en  <= 1'b0;
        rd_en  <= 1'b0;
        wr_data <= '0;
        repeat (5) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
    endtask

    task automatic write_one(input logic [WIDTH-1:0] data);
        @(posedge clk);
        wr_en   <= 1'b1;
        wr_data <= data;
        @(posedge clk);
        wr_en <= 1'b0;
        expected_queue.push_back(data);
    endtask

    task automatic read_and_check();
        @(posedge clk);
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
        @(negedge clk);
        if (expected_queue.size() > 0) begin
            automatic logic [WIDTH-1:0] exp = expected_queue.pop_front();
            if (rd_data === exp)
                pass_count++;
            else begin
                $error("MISMATCH: got 0x%0h, expected 0x%0h", rd_data, exp);
                fail_count++;
            end
        end
    endtask

    // Test sequence
    initial begin
        pass_count = 0;
        fail_count = 0;

        reset_dut();

        // Test 1: Write then read
        $display("=== Test 1: Sequential write/read ===");
        for (int i = 0; i < DEPTH; i++)
            write_one(i[WIDTH-1:0]);
        for (int i = 0; i < DEPTH; i++)
            read_and_check();

        // Test 2: Simultaneous write and read
        $display("=== Test 2: Simultaneous write/read ===");
        write_one(8'hAA);
        write_one(8'hBB);
        fork
            begin
                for (int i = 0; i < 10; i++)
                    write_one($urandom_range(0, 255));
            end
            begin
                repeat (3) @(posedge clk);
                for (int i = 0; i < 10; i++)
                    read_and_check();
            end
        join

        // Drain remaining
        while (!empty) read_and_check();

        // Report
        $display("=================================");
        $display("  PASS: %0d  FAIL: %0d", pass_count, fail_count);
        $display("=================================");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100us;
        $fatal(1, "Simulation timed out!");
    end
endmodule
```

> **Example file:** [`examples/18_testbenches/tb_sync_fifo.sv`](examples/18_testbenches/tb_sync_fifo.sv)

---

## 20. Synthesis & FPGA Best Practices

### Coding Guidelines for Synthesizable RTL

| Rule | Rationale |
|---|---|
| Use `always_ff` for registers, `always_comb` for combinational logic | Compiler enforces intent; avoids accidental latches |
| Use `unique case` / `priority case` | Signals to tools that cases are mutually exclusive or ordered |
| Avoid `initial` blocks in RTL (TB only) | Not synthesizable on most FPGA flows |
| Drive all outputs on all paths in `always_comb` | Prevents latch inference |
| Use non-blocking assignments (`<=`) in `always_ff` | Prevents race conditions in simulation |
| Use blocking assignments (`=`) in `always_comb` | Matches combinational semantics |
| Avoid asynchronous reset unless required | Synchronous resets are simpler and more portable |
| Register all module outputs | Improves timing closure |
| Use `localparam` for derived constants | Keeps module interface clean |

### Clock Domain Crossing Checklist

1. Single-bit signals: 2-flop synchronizer (`cdc_sync`)
2. Multi-bit buses: Gray-coded FIFO or handshake protocol
3. Pulse signals: Toggle synchronizer or pulse stretcher
4. Never use clock gating in RTL without tool support
5. Constrain CDC paths with `set_false_path` or `set_max_delay`

### Block RAM Inference Rules

For synthesis tools to infer Block RAM:

```systemverilog
// This pattern infers Block RAM in most FPGA tools
logic [DATA_W-1:0] ram [2**ADDR_W];

always_ff @(posedge clk) begin
    if (we)
        ram[addr] <= wdata;
    rdata <= ram[addr];  // read-first behavior
end
```

Key rules:
- Array depth should be ≥ 256 (tool-dependent)
- Use synchronous reads (register the output)
- Avoid resets on the RAM array
- Ensure the address width matches `$clog2(depth)`

### Timing Closure Tips

1. **Pipeline long paths** — Break combinational logic > 1 DSP or > 3 LUT levels
2. **Retiming** — Enable retiming in synthesis settings for automatic register balancing
3. **False paths** — Mark truly asynchronous paths with `set_false_path`
4. **Multi-cycle paths** — Use `set_multicycle_path` for paths that have multiple cycles to settle
5. **I/O constraints** — Always constrain `set_input_delay` and `set_output_delay`
6. **Floorplanning** — For large designs, use Pblocks (Xilinx) or LogicLock (Intel)

### Resource Estimation Rules of Thumb

| Structure | FPGA Resource |
|---|---|
| 1 LUT | ≈ 1 function of 4-6 inputs |
| 1 flip-flop | 1 bit of registered storage |
| Multiplier | DSP slice (save LUTs) |
| Memory > 256 bits | Block RAM |
| Memory ≤ 256 bits | Distributed RAM (LUTs) |
| Clock manipulation | PLL / MMCM |

---

## Directory Structure

```
.
├── README.md                          # This tutorial
└── examples/
    ├── 01_basics/
    │   ├── data_types.sv              # SystemVerilog type demonstrations
    │   └── adder.sv                   # Parameterized adder
    ├── 02_combinational/
    │   ├── alu.sv                     # Arithmetic Logic Unit
    │   ├── mux4.sv                    # 4:1 multiplexer
    │   └── priority_encoder.sv        # Priority encoder
    ├── 03_sequential/
    │   ├── shift_register.sv          # Parameterized shift register
    │   └── counter.sv                 # Counter with load/enable/TC
    ├── 04_fsm/
    │   └── traffic_light_fsm.sv       # Traffic light controller
    ├── 05_parameterized/
    │   └── pipe_reg.sv                # Pipeline register
    ├── 06_interfaces_packages/
    │   ├── cpu_pkg.sv                 # CPU definitions package
    │   └── axi_stream_if.sv           # AXI-Stream interface
    ├── 07_generate/
    │   ├── ripple_carry_adder.sv      # Generate-for adder
    │   └── sync_or_async_reset.sv     # Generate-if reset styles
    ├── 08_assertions/
    │   └── fifo_assertions.sv         # SVA examples
    ├── 09_fifo/
    │   └── sync_fifo.sv              # Synchronous FIFO
    ├── 10_pipeline/
    │   └── pipelined_mac.sv           # Pipelined multiply-accumulate
    ├── 11_axi_lite/
    │   └── axi_lite_slave.sv          # AXI4-Lite register slave
    ├── 12_cdc/
    │   ├── cdc_sync.sv                # 2-flop synchronizer
    │   └── async_fifo.sv              # Asynchronous FIFO
    ├── 13_memory/
    │   └── sram_controller.sv         # SRAM controller
    ├── 14_uart/
    │   ├── uart_tx.sv                 # UART transmitter
    │   └── uart_rx.sv                 # UART receiver
    ├── 15_spi/
    │   └── spi_master.sv             # SPI master (all modes)
    ├── 16_timer/
    │   └── pwm_timer.sv              # Multi-channel PWM timer
    ├── 17_arbiter/
    │   └── round_robin_arbiter.sv    # Round-robin arbiter
    └── 18_testbenches/
        └── tb_sync_fifo.sv           # FIFO testbench example
```

---

## License

This tutorial and all example code are provided under the [MIT License](LICENSE). Use freely in your projects.

---

## References

- IEEE Std 1800-2017 — *SystemVerilog — Unified Hardware Design, Specification, and Verification Language*
- Cummings, C. — *Synthesizable Finite State Machine Design Techniques Using the New SystemVerilog 3.0 Enhancements* (SNUG 2003)
- Cummings, C. — *Simulation and Synthesis Techniques for Asynchronous FIFO Design* (SNUG 2002)
- Xilinx UG901 — *Vivado Design Suite User Guide: Synthesis*
- Intel/Altera — *Quartus Prime Pro Synthesis User Guide*
