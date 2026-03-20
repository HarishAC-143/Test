# 01 — SystemVerilog Basics

## Module Anatomy

Every hardware block in SystemVerilog is a **module**. A module declares its
interface (ports) and describes its behavior or structure internally.

```systemverilog
module my_adder (
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [8:0] sum
);
    assign sum = a + b;
endmodule
```

### Port Directions

| Direction | Meaning |
|-----------|---------|
| `input`   | Signal driven from outside the module |
| `output`  | Signal driven from inside the module |
| `inout`   | Bidirectional (used for tri-state buses; rare in modern FPGA designs) |

## Data Types

### 4-State vs 2-State

| Type | States | Width | Use |
|------|--------|-------|-----|
| `logic` | 0, 1, X, Z | 1+ bits | RTL design (replaces `reg`/`wire`) |
| `integer` | 0, 1, X, Z | 32 bits | Loop variables, testbench |
| `bit` | 0, 1 | 1+ bits | Testbench / 2-state simulation |
| `int` | 0, 1 | 32 bits | Testbench / 2-state simulation |
| `byte` | 0, 1 | 8 bits | Testbench / 2-state simulation |

### Vectors (Packed Dimensions)

```systemverilog
logic [7:0]  byte_val;     // 8-bit packed vector
logic [31:0] word;          // 32-bit packed vector
logic [0:7]  reversed;     // bit 0 is MSB (unusual, avoid)
```

### Arrays (Unpacked Dimensions)

```systemverilog
logic [7:0] memory [0:255];           // 256-entry x 8-bit array
logic [7:0] matrix [0:3][0:3];        // 4x4 matrix of bytes
logic [31:0] reg_file [0:31];         // 32-entry register file
```

### Packed vs Unpacked

```systemverilog
logic [3:0][7:0] packed_word;   // 32 bits total, can slice as packed_word[15:8]
logic [7:0] unpacked [0:3];    // 4 separate 8-bit entries, cannot slice across entries
```

## Parameters

```systemverilog
module counter #(
    parameter int WIDTH = 8,          // overridable from outside
    parameter int MAX_COUNT = 2**WIDTH - 1
)(
    input  logic             clk,
    input  logic             rst_n,
    output logic [WIDTH-1:0] count
);
    localparam int HALFWAY = MAX_COUNT / 2;  // internal constant, not overridable

    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)
            count <= '0;
        else if (count == MAX_COUNT[WIDTH-1:0])
            count <= '0;
        else
            count <= count + 1'b1;
endmodule
```

## Continuous Assignment

The `assign` keyword creates permanent combinational connections.

```systemverilog
assign y = a & b;           // AND gate
assign mux = sel ? a : b;   // 2:1 multiplexer
assign {cout, sum} = a + b; // adder with carry
```

## Files in This Directory

- [`data_types_demo.sv`](data_types_demo.sv) — Demonstrates all major data types
- [`basic_module.sv`](basic_module.sv) — Parameterized adder module
- [`basic_module_tb.sv`](basic_module_tb.sv) — Testbench for the adder
