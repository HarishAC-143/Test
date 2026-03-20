# FPGA RTL Design with SystemVerilog: A Comprehensive Tutorial

A complete guide to FPGA RTL design using SystemVerilog, covering fundamentals through advanced techniques with synthesizable, practical examples.

---

## Table of Contents

1. [Introduction](#introduction)
2. [SystemVerilog for RTL Design](#systemverilog-for-rtl-design)
3. [Data Types and Operators](#data-types-and-operators)
4. [Combinational Logic](#combinational-logic)
5. [Sequential Logic](#sequential-logic)
6. [Finite State Machines](#finite-state-machines)
7. [Interfaces and Structs](#interfaces-and-structs)
8. [Memory Design](#memory-design)
9. [Advanced RTL Techniques](#advanced-rtl-techniques)
10. [Practical Projects](#practical-projects)
11. [Verification with Testbenches](#verification-with-testbenches)
12. [FPGA Design Best Practices](#fpga-design-best-practices)
13. [Example Index](#example-index)

---

## Introduction

### What is RTL Design?

**Register-Transfer Level (RTL)** design describes digital hardware as a flow of data between registers (flip-flops) and the combinational logic that transforms that data. RTL is the abstraction level at which FPGA and ASIC designs are written before synthesis transforms them into gate-level netlists.

### Why SystemVerilog?

SystemVerilog (IEEE 1800) extends Verilog with features that improve RTL design productivity and reduce common bugs:

| Feature | Verilog | SystemVerilog |
|---------|---------|---------------|
| Data types | `reg`, `wire` | `logic`, `bit`, enums, structs, unions |
| Always blocks | `always @(*)` | `always_comb`, `always_ff`, `always_latch` |
| Interfaces | None | Full interface support |
| Packages | None | Package imports |
| Assertions | None | SVA (SystemVerilog Assertions) |
| Parameterization | `parameter` | `parameter`, `localparam`, type parameters |

### FPGA Design Flow

```
RTL Design (.sv) ──► Synthesis ──► Place & Route ──► Bitstream ──► FPGA
     │                   │              │
     ▼                   ▼              ▼
 Simulation         Gate Netlist    Timing Reports
 (Testbench)        (Schematic)    (STA Analysis)
```

### Repository Structure

```
examples/
├── 01_combinational/    # Gates, MUX, decoders, encoders
│   ├── src/             # Synthesizable RTL source
│   └── tb/              # Testbenches
├── 02_sequential/       # Flip-flops, counters, shift registers
├── 03_fsm/              # Moore and Mealy state machines
├── 04_interfaces/       # SystemVerilog interfaces and structs
├── 05_memory/           # RAM, ROM, FIFO designs
├── 06_advanced/         # CDC, pipelining, parameterization
└── 07_practical_projects/  # UART, SPI, PWM controllers
```

---

## SystemVerilog for RTL Design

### Module Declaration

The `module` is the fundamental building block. SystemVerilog introduces ANSI-style port declarations:

```systemverilog
module adder #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    assign {cout, sum} = a + b + cin;
endmodule
```

### The `logic` Type

Replace both `reg` and `wire` with `logic` in most RTL code. The `logic` type is a 4-state type (0, 1, X, Z) that can be driven by both continuous assignments and procedural blocks:

```systemverilog
logic [7:0] data;       // 8-bit 4-state signal
logic       valid;      // single-bit signal
bit   [7:0] counter;    // 8-bit 2-state (0,1 only) — simulation only
```

### Always Block Specializations

SystemVerilog provides intent-specific always blocks that tools can check:

```systemverilog
// Combinational logic — tool verifies no latches are inferred
always_comb begin
    result = a & b;
end

// Sequential logic — tool verifies proper clocked behavior
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// Intentional latch — tool verifies latch inference
always_latch begin
    if (enable)
        q <= d;
end
```

---

## Data Types and Operators

### Packed and Unpacked Arrays

```systemverilog
logic [7:0]  packed_byte;           // packed: 8-bit vector
logic [3:0][7:0] packed_word;       // packed: 4 bytes = 32 bits
logic unpacked_mem [0:255];         // unpacked: 256 x 1-bit array
logic [7:0] memory [0:1023];       // mixed: 1024 entries of 8-bit
```

### Enumerated Types

Enums create readable, self-documenting state values:

```systemverilog
typedef enum logic [1:0] {
    IDLE   = 2'b00,
    READ   = 2'b01,
    WRITE  = 2'b10,
    ERROR  = 2'b11
} state_t;

state_t current_state, next_state;
```

### Structures

Group related signals into a single unit:

```systemverilog
typedef struct packed {
    logic [31:0] addr;
    logic [31:0] data;
    logic [3:0]  strb;
    logic        valid;
    logic        write;
} bus_req_t;

bus_req_t request;
assign request.valid = 1'b1;
assign request.addr  = 32'hDEAD_BEEF;
```

### Operators

| Category | Operators | Description |
|----------|-----------|-------------|
| Arithmetic | `+`, `-`, `*`, `/`, `%`, `**` | Standard math |
| Logical | `&&`, `\|\|`, `!` | Boolean logic |
| Bitwise | `&`, `\|`, `^`, `~` | Bit-by-bit operations |
| Reduction | `&x`, `\|x`, `^x` | Reduce vector to 1 bit |
| Shift | `<<`, `>>`, `<<<`, `>>>` | Logical and arithmetic shift |
| Relational | `<`, `>`, `<=`, `>=`, `==`, `!=` | Comparison |
| Concatenation | `{a, b}`, `{4{a}}` | Bit joining and replication |
| Conditional | `cond ? a : b` | Ternary selection |

---

## Combinational Logic

Combinational circuits produce outputs that depend only on current inputs with no memory. See `examples/01_combinational/`.

### Key Rules for Combinational `always_comb`

1. **Assign every output in every branch** — prevents latch inference
2. **No feedback loops** — outputs must not depend on themselves
3. **Use blocking assignments** (`=`) inside `always_comb`
4. **Set defaults** at the top of the block before conditional logic

### Example: 4-to-1 Multiplexer

```systemverilog
module mux4to1 #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] in0, in1, in2, in3,
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] out
);
    always_comb begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            2'b11:   out = in3;
            default: out = '0;    // good practice
        endcase
    end
endmodule
```

### Example: Priority Encoder

```systemverilog
module priority_encoder_8to3 (
    input  logic [7:0] req,
    output logic [2:0] grant_idx,
    output logic       valid
);
    always_comb begin
        valid     = 1'b1;
        grant_idx = 3'd0;
        casez (req)
            8'b1???_????: grant_idx = 3'd7;
            8'b01??_????: grant_idx = 3'd6;
            8'b001?_????: grant_idx = 3'd5;
            8'b0001_????: grant_idx = 3'd4;
            8'b0000_1???: grant_idx = 3'd3;
            8'b0000_01??: grant_idx = 3'd2;
            8'b0000_001?: grant_idx = 3'd1;
            8'b0000_0001: grant_idx = 3'd0;
            default: begin
                grant_idx = 3'd0;
                valid     = 1'b0;
            end
        endcase
    end
endmodule
```

### Continuous Assignments

For simple logic, `assign` statements are concise:

```systemverilog
assign parity = ^data;              // XOR reduction
assign mux_out = sel ? in1 : in0;   // 2:1 MUX
assign {cout, sum} = a + b + cin;   // full adder
```

---

## Sequential Logic

Sequential circuits use clocked storage elements (flip-flops). See `examples/02_sequential/`.

### Key Rules for Sequential `always_ff`

1. **Use non-blocking assignments** (`<=`) exclusively
2. **Synchronous reset** is preferred for FPGAs (uses fewer resources)
3. **Asynchronous reset** requires inclusion in the sensitivity list
4. **One clock domain per `always_ff`** block

### Synchronous vs. Asynchronous Reset

```systemverilog
// Synchronous reset — reset sampled on clock edge
always_ff @(posedge clk) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end

// Asynchronous reset — reset takes immediate effect
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end
```

### Example: Configurable Counter

```systemverilog
module counter #(
    parameter WIDTH = 8,
    parameter MAX_COUNT = (2**WIDTH) - 1
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             overflow
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= '0;
            overflow <= 1'b0;
        end else if (load) begin
            count    <= load_val;
            overflow <= 1'b0;
        end else if (enable) begin
            if (count == MAX_COUNT[WIDTH-1:0]) begin
                count    <= '0;
                overflow <= 1'b1;
            end else begin
                count    <= count + 1'b1;
                overflow <= 1'b0;
            end
        end else begin
            overflow <= 1'b0;
        end
    end
endmodule
```

### Example: Shift Register with Parallel Load

```systemverilog
module shift_register #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             shift_en,
    input  logic             load,
    input  logic             serial_in,
    input  logic [WIDTH-1:0] parallel_in,
    output logic             serial_out,
    output logic [WIDTH-1:0] parallel_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            parallel_out <= '0;
        else if (load)
            parallel_out <= parallel_in;
        else if (shift_en)
            parallel_out <= {parallel_out[WIDTH-2:0], serial_in};
    end

    assign serial_out = parallel_out[WIDTH-1];
endmodule
```

---

## Finite State Machines

FSMs are central to control logic. See `examples/03_fsm/`.

### Two-Block FSM (Recommended Style)

Separate state register from next-state logic for clarity:

```systemverilog
// Block 1: State register
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Block 2: Next-state logic + outputs (combinational)
always_comb begin
    next_state = state;   // default: hold state
    // ... transition logic ...
end
```

### Moore vs. Mealy

| Property | Moore | Mealy |
|----------|-------|-------|
| Outputs depend on | State only | State + inputs |
| Output timing | Changes with state | Changes with inputs (faster) |
| Number of states | Typically more | Typically fewer |
| Output glitches | No glitches | Possible glitches |
| Registration | Outputs naturally registered | May need output register |

---

## Interfaces and Structs

SystemVerilog interfaces bundle related signals together, reducing port-list clutter and connection errors. See `examples/04_interfaces/`.

### Interface Definition

```systemverilog
interface axi_lite_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
    logic                    awvalid, awready;
    logic [ADDR_WIDTH-1:0]   awaddr;
    logic                    wvalid, wready;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                    bvalid, bready;
    logic [1:0]              bresp;
    logic                    arvalid, arready;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic                    rvalid, rready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;

    modport manager (
        output awvalid, awaddr, wvalid, wdata, wstrb, bready, arvalid, araddr, rready,
        input  awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
    );

    modport subordinate (
        input  awvalid, awaddr, wvalid, wdata, wstrb, bready, arvalid, araddr, rready,
        output awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
    );
endinterface
```

### Using Interfaces in Modules

```systemverilog
module axi_lite_register_bank (
    input logic clk,
    input logic rst_n,
    axi_lite_if.subordinate bus
);
    // Access interface signals with bus.awvalid, bus.wdata, etc.
endmodule
```

---

## Memory Design

See `examples/05_memory/` for synthesizable memory primitives.

### Inference Patterns

FPGA synthesis tools recognize specific coding patterns and map them to block RAM or distributed RAM resources:

```systemverilog
// Single-port RAM — infers BRAM
module single_port_ram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    output logic [DATA_WIDTH-1:0]   rdata
);
    logic [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;
        rdata <= mem[addr];
    end
endmodule
```

---

## Advanced RTL Techniques

See `examples/06_advanced/` for production-grade patterns.

### Clock Domain Crossing (CDC)

Passing signals between clock domains requires synchronization to avoid metastability:

```systemverilog
// Two-flop synchronizer for single-bit signals
module sync_2ff #(
    parameter RESET_VAL = 1'b0
)(
    input  logic clk_dst,
    input  logic rst_dst_n,
    input  logic async_in,
    output logic sync_out
);
    logic meta_ff;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            meta_ff  <= RESET_VAL;
            sync_out <= RESET_VAL;
        end else begin
            meta_ff  <= async_in;
            sync_out <= meta_ff;
        end
    end
endmodule
```

### Pipelining

Add register stages to break long combinational paths and increase clock frequency:

```systemverilog
// Without pipeline: long critical path
assign result = (a * b) + (c * d);

// With pipeline: two stages
always_ff @(posedge clk) begin
    // Stage 1: multiply
    mult_ab <= a * b;
    mult_cd <= c * d;
    // Stage 2: add
    result  <= mult_ab + mult_cd;
end
```

### Generate Blocks

Parameterized, structurally replicated hardware:

```systemverilog
module ripple_carry_adder #(
    parameter WIDTH = 8
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
            full_adder u_fa (
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
```

---

## Practical Projects

See `examples/07_practical_projects/` for real-world peripheral controllers.

These include complete UART transmitter/receiver, SPI master, and PWM generator modules with testbenches.

---

## Verification with Testbenches

### Testbench Structure

```systemverilog
module tb_my_module;
    // 1. Signal declarations
    logic clk, rst_n;
    logic [7:0] data_in, data_out;

    // 2. Clock generation
    localparam CLK_PERIOD = 10;
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // 3. DUT instantiation
    my_module u_dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (data_in),
        .data_out (data_out)
    );

    // 4. Stimulus and checking
    initial begin
        rst_n = 1'b0;
        data_in = 8'h00;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // Test vector 1
        @(posedge clk);
        data_in = 8'hAB;
        @(posedge clk);
        assert (data_out == 8'hAB)
            else $error("Mismatch: expected AB, got %02h", data_out);

        $display("All tests passed!");
        $finish;
    end

    // 5. Timeout watchdog
    initial begin
        #100_000;
        $error("Simulation timeout!");
        $finish;
    end
endmodule
```

### SystemVerilog Assertions (SVA)

```systemverilog
// Immediate assertion
always_ff @(posedge clk) begin
    assert (!($isunknown(data_out)))
        else $error("Output contains X/Z values");
end

// Concurrent assertion: req must be followed by ack within 5 cycles
property p_req_ack;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##[1:5] ack;
endproperty
assert property (p_req_ack)
    else $error("ACK not received within 5 cycles of REQ");

// Cover property: verify the scenario occurs in simulation
cover property (@(posedge clk) req ##1 ack);
```

---

## FPGA Design Best Practices

### Synthesis Guidelines

1. **Use `always_comb` / `always_ff` / `always_latch`** — never `always @(*)` or `always @(posedge clk)` in new SystemVerilog code
2. **Assign defaults in `always_comb`** to prevent latches
3. **Use non-blocking (`<=`) in `always_ff`** and blocking (`=`) in `always_comb`
4. **Avoid initial blocks** in synthesizable code (use reset instead)
5. **No `#delay`** in synthesizable code
6. **No `force`/`release`** in synthesizable code

### Clock and Reset

1. **One clock per `always_ff`** block
2. **Prefer synchronous reset** for FPGAs — uses fewer routing resources
3. **Synchronize asynchronous resets** with a reset synchronizer
4. **Avoid gated clocks** — use clock enables instead:

```systemverilog
// BAD: gated clock — creates clock skew, unreliable
always_ff @(posedge (clk & enable)) begin
    q <= d;
end

// GOOD: clock enable — clean, predictable
always_ff @(posedge clk) begin
    if (enable)
        q <= d;
end
```

### Coding for Area and Performance

| Goal | Technique |
|------|-----------|
| Reduce area | Share multipliers/dividers with time-multiplexing |
| Increase Fmax | Pipeline long combinational paths |
| Reduce power | Clock-gate unused blocks, use enables |
| Avoid timing issues | Register all outputs of a module |
| Prevent metastability | Use synchronizers for CDC signals |

### Common Mistakes to Avoid

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Missing `default` in `case` | Latch inferred | Add `default` branch |
| Missing signal in `always_comb` assignment | Latch inferred | Set defaults at top of block |
| Using `=` in `always_ff` | Race conditions | Use `<=` |
| Multiple drivers on `logic` | Synthesis error | Ensure single driver |
| Combinational loop | Oscillation | Break loop with register |
| Unsynchronized CDC | Metastability | Use 2FF synchronizer |

### Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Modules | `snake_case` | `uart_transmitter` |
| Signals | `snake_case` | `data_valid` |
| Parameters | `UPPER_SNAKE` | `DATA_WIDTH` |
| Types | `_t` suffix | `state_t` |
| Active-low | `_n` suffix | `rst_n` |
| Clock | `clk` prefix/name | `clk`, `clk_100mhz` |
| Instance | `u_` prefix | `u_fifo` |
| Generate | `gen_` prefix | `gen_stage` |

---

## Example Index

| # | File | Description | Concepts |
|---|------|-------------|----------|
| 1 | `01_combinational/src/mux4to1.sv` | 4-to-1 Multiplexer | `always_comb`, `case`, parameterization |
| 2 | `01_combinational/src/decoder_3to8.sv` | 3-to-8 Decoder | Bitwise shift, `always_comb` |
| 3 | `01_combinational/src/priority_encoder.sv` | Priority Encoder | `casez`, priority logic |
| 4 | `01_combinational/src/alu.sv` | Arithmetic Logic Unit | Operations, `enum`, `unique case` |
| 5 | `02_sequential/src/dff_variants.sv` | D Flip-Flop Variants | `always_ff`, sync/async reset, enable |
| 6 | `02_sequential/src/counter.sv` | Configurable Counter | Parameterization, overflow detection |
| 7 | `02_sequential/src/shift_register.sv` | Shift Register | Parallel load, serial I/O |
| 8 | `02_sequential/src/edge_detector.sv` | Edge Detector | Rising/falling edge detection |
| 9 | `03_fsm/src/traffic_light_moore.sv` | Traffic Light (Moore) | Moore FSM, `enum`, timer |
| 10 | `03_fsm/src/vending_machine_mealy.sv` | Vending Machine (Mealy) | Mealy FSM, coin logic |
| 11 | `04_interfaces/src/simple_bus_if.sv` | Simple Bus Interface | `interface`, `modport` |
| 12 | `04_interfaces/src/bus_master.sv` | Bus Master | Interface usage, protocol |
| 13 | `04_interfaces/src/bus_subordinate.sv` | Bus Subordinate | Register bank, response logic |
| 14 | `04_interfaces/src/packet_structs_pkg.sv` | Packet Structs Package | `package`, `typedef struct packed` |
| 15 | `05_memory/src/single_port_ram.sv` | Single-Port RAM | BRAM inference |
| 16 | `05_memory/src/dual_port_ram.sv` | True Dual-Port RAM | Dual clock BRAM |
| 17 | `05_memory/src/sync_fifo.sv` | Synchronous FIFO | FIFO pointer management |
| 18 | `05_memory/src/rom_lut.sv` | ROM / Look-Up Table | `case`-based ROM |
| 19 | `06_advanced/src/sync_2ff.sv` | 2FF Synchronizer | Clock domain crossing |
| 20 | `06_advanced/src/async_fifo.sv` | Asynchronous FIFO | Gray code CDC, dual-clock |
| 21 | `06_advanced/src/pipeline_mac.sv` | Pipelined MAC Unit | Multiply-accumulate pipeline |
| 22 | `06_advanced/src/debouncer.sv` | Button Debouncer | Filtering, edge detection |
| 23 | `07_practical_projects/src/uart_tx.sv` | UART Transmitter | Serial protocol, baud rate |
| 24 | `07_practical_projects/src/uart_rx.sv` | UART Receiver | Oversampling, framing |
| 25 | `07_practical_projects/src/spi_master.sv` | SPI Master | SPI protocol, CPOL/CPHA |
| 26 | `07_practical_projects/src/pwm_generator.sv` | PWM Generator | Duty cycle control |

---

## Further Reading

- **IEEE 1800-2017**: SystemVerilog Language Reference Manual
- **Clifford Cummings**: "Nonblocking Assignments in Verilog Synthesis" (SNUG Paper)
- **Clifford Cummings**: "Simulation and Synthesis Techniques for Asynchronous FIFO Design"
- **Xilinx UG901**: Vivado Synthesis Guide
- **Intel Quartus**: Recommended HDL Coding Styles

---

*All examples in this repository are synthesizable RTL unless explicitly marked as testbench (`tb_`) or simulation-only.*
