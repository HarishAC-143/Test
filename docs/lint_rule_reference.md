# SpyGlass Lint Rule Reference

A detailed reference of the most commonly encountered SpyGlass Lint rules, organized by category, with explanations, code examples, and recommended fixes.

---

## Table of Contents

- [Structural Rules](#structural-rules)
- [Synthesis Rules](#synthesis-rules)
- [Clock Rules](#clock-rules)
- [Reset Rules](#reset-rules)
- [FSM Rules](#fsm-rules)
- [Naming Rules](#naming-rules)

---

## Structural Rules

### W_UNDRIVEN — Undriven Signal

**Severity**: Warning  
**Category**: Structural

A signal is declared but never assigned a value in the design. In simulation this produces `X` (unknown). In synthesis, the tool may optimize the signal away or infer a constant.

**Example (violation)**:

```verilog
module example (input clk, output [7:0] data_out);
    wire [7:0] internal_bus;  // Declared but never driven
    assign data_out = internal_bus;
endmodule
```

**Fix**: Either drive the signal or remove it if unused.

```verilog
module example (input clk, input [7:0] data_in, output [7:0] data_out);
    wire [7:0] internal_bus;
    assign internal_bus = data_in;  // Now driven
    assign data_out = internal_bus;
endmodule
```

---

### W_UNUSED — Unused Signal

**Severity**: Warning  
**Category**: Structural

A signal is driven (assigned a value) but never read by any downstream logic or output port. This typically indicates dead code or incomplete connectivity.

**Example (violation)**:

```verilog
module example (input clk, input [7:0] data_in, output [7:0] data_out);
    reg [7:0] temp;
    reg [7:0] debug;  // Assigned but never read

    always @(posedge clk) begin
        temp  <= data_in;
        debug <= data_in + 8'd1;  // Dead assignment
    end

    assign data_out = temp;
endmodule
```

**Fix**: Remove the unused signal, or connect it to a debug port.

---

### W_LATCH — Unintended Latch Inference

**Severity**: Warning (often promoted to Error)  
**Category**: Structural

A combinational `always` block has incomplete conditional branches, causing the synthesis tool to infer a latch to "remember" the previous value.

**Example (violation)**:

```verilog
always @(*) begin
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
        2'b10: out = c;
        // Missing 2'b11 → latch on 'out'
    endcase
end
```

**Fix options**:

```verilog
// Option 1: Add default
always @(*) begin
    case (sel)
        2'b00:   out = a;
        2'b01:   out = b;
        2'b10:   out = c;
        default: out = 8'd0;
    endcase
end

// Option 2: Assign default before case
always @(*) begin
    out = 8'd0;  // Default value
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
        2'b10: out = c;
    endcase
end

// Option 3 (SystemVerilog): Use always_comb + full_case
always_comb begin
    unique case (sel)
        2'b00: out = a;
        2'b01: out = b;
        2'b10: out = c;
        2'b11: out = d;
    endcase
end
```

---

### W_COMBO_LOOP — Combinational Feedback Loop

**Severity**: Warning (often promoted to Error)  
**Category**: Structural

The output of combinational logic feeds back to its own input without passing through a sequential element (flip-flop). This creates a race condition with non-deterministic behavior in hardware.

**Example (violation)**:

```verilog
assign a = b ^ c;
assign c = a | d;    // 'a' depends on 'c', 'c' depends on 'a'
```

**Fix**: Insert a flip-flop to break the loop.

```verilog
assign a = b ^ c_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        c_reg <= 1'b0;
    else
        c_reg <= a | d;
end
```

---

### W_ASSIGN_TRUNCATE — Width Mismatch (Truncation)

**Severity**: Warning  
**Category**: Structural

The right-hand side of an assignment is wider than the left-hand side. Upper bits are silently discarded, which may indicate a design error.

**Example (violation)**:

```verilog
wire [7:0] a;
wire [3:0] b;
assign b = a;    // Upper 4 bits of 'a' lost
```

**Fix**: Explicitly select the desired bits.

```verilog
assign b = a[3:0];    // Explicit truncation — intent is clear
```

---

### W_MULTI_DRIVE — Multiple Drivers

**Severity**: Warning  
**Category**: Structural

A signal is driven from multiple always blocks, assign statements, or module ports. In hardware, this creates contention (two drivers fighting over the same wire).

**Example (violation)**:

```verilog
always @(posedge clk) begin
    data <= input_a;
end

always @(posedge clk) begin
    if (sel)
        data <= input_b;   // Second driver on 'data'!
end
```

**Fix**: Merge into a single always block.

```verilog
always @(posedge clk) begin
    if (sel)
        data <= input_b;
    else
        data <= input_a;
end
```

---

### W_SENSITIVITY — Incomplete Sensitivity List

**Severity**: Warning  
**Category**: Structural

A combinational always block's sensitivity list does not include all signals read within the block. This causes simulation/synthesis mismatch: simulation only re-evaluates when listed signals change, but synthesis creates logic sensitive to all inputs.

**Example (violation)**:

```verilog
always @(a)     // Missing 'b' in sensitivity list
    out = a & b;
```

**Fix**: Use `always @(*)` (Verilog-2001) or `always_comb` (SystemVerilog).

```verilog
always @(*) begin
    out = a & b;
end
```

---

## Synthesis Rules

### SYNTH_5130 — Non-Synthesizable Construct

**Severity**: Error  
**Category**: Synthesis

The code uses constructs that have no hardware equivalent and cannot be synthesized:

| Construct | Why Non-Synthesizable |
|-----------|----------------------|
| `initial` block | No hardware equivalent (use reset instead) |
| `#delay` | No hardware delay element |
| `$display`, `$monitor` | Simulation-only system tasks |
| `$readmemh` | File I/O |
| `real` type | No floating-point hardware (in standard synthesis) |
| `fork/join` | Parallel threads have no direct HW mapping |

**Fix**: Move these constructs to testbench/simulation-only files, not synthesizable RTL.

---

## Clock Rules

### CLK_GATING — Improper Clock Gating

**Severity**: Warning  
**Category**: Clock

Clock is gated using combinational logic that may glitch, creating spurious clock edges.

**Example (violation)**:

```verilog
wire gated_clk = clk & enable;  // Glitch-prone!
```

**Fix**: Use an ICG (Integrated Clock Gating) cell from the technology library, or the enable-latch pattern.

```verilog
// Latch-based clock gating (glitch-free)
reg enable_latched;
always @(*) begin
    if (!clk)
        enable_latched = enable;
end
wire gated_clk = clk & enable_latched;
```

---

## Reset Rules

### W_REGS_ARST — Missing Asynchronous Reset

**Severity**: Warning  
**Category**: Reset

A flip-flop does not have an asynchronous reset. At power-up, its value is unknown. In ASIC designs, all flip-flops typically require async reset for deterministic power-up.

**Example (violation)**:

```verilog
always @(posedge clk) begin
    q <= d;
end
```

**Fix**: Add async reset.

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= d;
end
```

### RST_POLARITY — Inconsistent Reset Polarity

**Severity**: Warning  
**Category**: Reset

Different flip-flops in the same module use different reset polarities (some active-high, others active-low), which usually indicates a design error.

---

## FSM Rules

### FSM_NO_DEFAULT — Missing Default in State Case

**Severity**: Warning  
**Category**: FSM

State machine case statement lacks a `default` branch. If the state register enters an undefined value (SEU, power-up), the FSM has no recovery path.

### FSM_DEADEND — Dead-End State

**Severity**: Error  
**Category**: FSM

A state exists with no outgoing transition. Once entered, the FSM is stuck permanently.

### FSM_UNREACHABLE — Unreachable State

**Severity**: Warning  
**Category**: FSM

A state is defined in the encoding but no transition from any other state leads to it. This is dead code.

---

## Naming Rules

### NAME_MIXED_CASE — Inconsistent Naming

**Severity**: Info  
**Category**: Naming

Signal names use inconsistent casing (mixing `camelCase` and `snake_case`). Most Verilog coding guidelines recommend consistent `snake_case`.

### NAME_RESERVED — Reserved Keyword Used

**Severity**: Error  
**Category**: Naming

A signal or module name conflicts with a Verilog/SystemVerilog reserved keyword.
