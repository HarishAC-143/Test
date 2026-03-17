# Chapter 2: SpyGlass Lint — Deep Dive

## 2.1 What is Lint Analysis?

Lint analysis checks RTL code for **coding style violations**, **potential bugs**, and **simulation/synthesis mismatches** without running simulation. The term "lint" originated from the C programming language tool of the same name.

SpyGlass Lint goes far beyond simple syntax checking. It performs structural analysis of the design to find issues that a compiler would accept but that lead to incorrect hardware.

## 2.2 Lint Rule Categories

SpyGlass organizes lint rules into categories:

### Naming Conventions
Rules that enforce consistent naming across the design.

| Rule | Description |
|------|-------------|
| `NamingConvention` | Signal/module names violate project conventions |
| `W_0100` | Reserved keyword used as identifier |

### Signal Integrity
Rules that catch connectivity and driver issues.

| Rule | Description |
|------|-------------|
| `W_0123` | Unloaded net — signal is driven but never read |
| `W_0124` | Undriven net — signal is read but never driven |
| `W_0125` | Multi-driven net — multiple drivers on the same signal |
| `W_0116` | Unconnected port — module port left floating |

### Width Mismatch
Rules that catch bit-width incompatibilities.

| Rule | Description |
|------|-------------|
| `W_0110` | Width mismatch in assignment |
| `W_0111` | Width mismatch in port connection |
| `W_0164` | Truncation in assignment |
| `W_0490` | Implicit width extension |

### Simulation / Synthesis Mismatch
Rules that catch code behaving differently in simulation vs. synthesis.

| Rule | Description |
|------|-------------|
| `W_0391` | Incomplete sensitivity list |
| `W_0408` | Inferred latch (missing `else` or incomplete `case`) |
| `W_0415` | Non-synthesizable construct used |
| `W_0528` | Blocking assignment in sequential `always` block |
| `W_0527` | Non-blocking assignment in combinational `always` block |

### FSM Analysis
Rules specific to finite state machine quality.

| Rule | Description |
|------|-------------|
| `W_0551` | Unreachable state in FSM |
| `W_0552` | Dead-end state (no exit transitions) |
| `W_0553` | FSM without default state |
| `W_0554` | Implicit default transition |

### Clock and Reset
Rules related to clocking and reset structures.

| Rule | Description |
|------|-------------|
| `W_0445` | Gated clock detected |
| `W_0446` | Generated clock without proper constraints |
| `W_0480` | Asynchronous reset used as data |

## 2.3 Common Lint Violations — Explained with Examples

### 2.3.1 Undriven and Unloaded Nets (W_0123, W_0124)

**Problem:** A signal exists but is either never driven (reads produce `X`) or never read (wasted logic).

```verilog
module undriven_example (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [7:0] data_out
);
    wire [7:0] internal_bus;  // W_0124: Never driven!
    reg  [7:0] debug_reg;     // W_0123: Driven but never read!

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'h00;
        else begin
            data_out  <= internal_bus;  // Reads undriven signal
            debug_reg <= data_out;      // Writes to unloaded signal
        end
    end
endmodule
```

**Fix:** Either connect the signal properly or remove it:

```verilog
module undriven_fixed (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,    // Provide a real source
    output reg  [7:0] data_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 8'h00;
        else
            data_out <= data_in;
    end
endmodule
```

### 2.3.2 Width Mismatch (W_0110)

**Problem:** Source and destination have different bit widths, causing silent truncation or zero-extension.

```verilog
module width_mismatch (
    input  wire [15:0] wide_data,
    output reg  [7:0]  narrow_data,
    output reg  [31:0] wider_data
);
    always @(*) begin
        narrow_data = wide_data;   // W_0164: Truncation! Upper 8 bits lost
        wider_data  = wide_data;   // W_0490: Implicit zero-extension
    end
endmodule
```

**Fix:** Make width conversions explicit:

```verilog
module width_fixed (
    input  wire [15:0] wide_data,
    output reg  [7:0]  narrow_data,
    output reg  [31:0] wider_data
);
    always @(*) begin
        narrow_data = wide_data[7:0];          // Explicit truncation
        wider_data  = {16'b0, wide_data};      // Explicit zero-extension
    end
endmodule
```

### 2.3.3 Incomplete Sensitivity List (W_0391)

**Problem:** Combinational `always` block does not list all read signals, causing simulation/synthesis mismatch.

```verilog
module sensitivity_issue (
    input  wire a,
    input  wire b,
    input  wire sel,
    output reg  y
);
    // W_0391: 'b' missing from sensitivity list
    always @(a or sel) begin
        if (sel)
            y = a;
        else
            y = b;  // 'b' changes won't trigger re-evaluation in simulation!
    end
endmodule
```

**Fix:** Use `always @(*)` for combinational logic:

```verilog
module sensitivity_fixed (
    input  wire a,
    input  wire b,
    input  wire sel,
    output reg  y
);
    always @(*) begin  // Automatic complete sensitivity list
        if (sel)
            y = a;
        else
            y = b;
    end
endmodule
```

### 2.3.4 Inferred Latch (W_0408)

**Problem:** An incomplete `if` or `case` statement in combinational logic infers a latch — almost always a bug.

```verilog
module latch_inferred (
    input  wire [1:0] sel,
    input  wire [7:0] a, b, c,
    output reg  [7:0] result
);
    // W_0408: 'result' does not get assigned in all branches
    always @(*) begin
        case (sel)
            2'b00: result = a;
            2'b01: result = b;
            2'b10: result = c;
            // Missing 2'b11 — latch inferred for 'result'!
        endcase
    end
endmodule
```

**Fix:** Add a `default` case:

```verilog
module latch_fixed (
    input  wire [1:0] sel,
    input  wire [7:0] a, b, c,
    output reg  [7:0] result
);
    always @(*) begin
        case (sel)
            2'b00:   result = a;
            2'b01:   result = b;
            2'b10:   result = c;
            default: result = 8'h00;  // Explicit default prevents latch
        endcase
    end
endmodule
```

### 2.3.5 Blocking vs Non-Blocking Assignment (W_0527, W_0528)

**Problem:** Using blocking assignments (`=`) in sequential logic or non-blocking (`<=`) in combinational logic causes simulation/synthesis mismatch.

```verilog
module assignment_issues (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] d,
    output reg  [7:0] q1, q2
);
    // W_0528: Blocking assignment in sequential always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 = 8'h00;   // BAD: should be <=
            q2 = 8'h00;   // BAD: should be <=
        end else begin
            q1 = d;        // BAD: creates race condition
            q2 = q1;       // BAD: q2 gets d (same cycle), not q1's old value
        end
    end
endmodule
```

**Fix:** Use non-blocking for sequential, blocking for combinational:

```verilog
module assignment_fixed (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] d,
    output reg  [7:0] q1, q2
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= 8'h00;
            q2 <= 8'h00;
        end else begin
            q1 <= d;
            q2 <= q1;   // q2 gets q1's OLD value — correct pipeline behavior
        end
    end
endmodule
```

### 2.3.6 Gated Clock (W_0445)

**Problem:** Combinational logic drives a clock pin, creating a gated clock that can produce glitches.

```verilog
module gated_clock_issue (
    input  wire       clk,
    input  wire       enable,
    input  wire [7:0] d,
    output reg  [7:0] q
);
    wire gated_clk = clk & enable;  // W_0445: Gated clock!

    always @(posedge gated_clk)
        q <= d;
endmodule
```

**Fix:** Use a clock enable instead:

```verilog
module gated_clock_fixed (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [7:0] d,
    output reg  [7:0] q
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 8'h00;
        else if (enable)
            q <= d;
    end
endmodule
```

## 2.4 Running Lint Analysis

### Basic Lint Run

```tcl
# run_lint.tcl

read_file -type verilog {rtl/my_design.v rtl/sub_block.v}
set_option top my_design
current_goal lint/lint_rtl
run_goal
```

```bash
spyglass -tcl run_lint.tcl -batch
```

### Filtering by Severity

```tcl
# Show only errors and warnings (skip info)
set_option report_severity {Error Warning}
```

### Enabling/Disabling Specific Rules

```tcl
# Disable a noisy rule
set_rule_status -disable W_0123

# Enable an optional rule
set_rule_status -enable W_0789
```

## 2.5 Interpreting Lint Results

A typical lint report entry:

```
================================================================================
Rule: W_0408 [LatchInfer]
Severity: Warning
Message: Latch inferred for signal 'result' due to incomplete
         case statement in module 'mux_4to1'
File: rtl/mux_4to1.v
Line: 23
Module: mux_4to1
================================================================================
Recommendation: Add a 'default' branch to the case statement to avoid
                 unintentional latch inference.
================================================================================
```

### Triage Strategy

1. **Errors first** — These are definite bugs. Fix immediately.
2. **Warnings by category** — Group warnings by rule ID and fix systematically.
3. **Waive intentional violations** — Some warnings are by design (e.g., intentionally unloaded debug ports). Use waiver files.
4. **Track zero-warning goal** — Aim for a clean lint run with all remaining violations waived with justification.

## 2.6 Practical Example Files

See the example RTL files in this repository:

| File | Purpose |
|------|---------|
| [`examples/lint/rtl/counter_with_issues.v`](../examples/lint/rtl/counter_with_issues.v) | Counter with multiple lint violations |
| [`examples/lint/rtl/counter_fixed.v`](../examples/lint/rtl/counter_fixed.v) | Same counter with all issues fixed |
| [`examples/lint/rtl/fsm_with_issues.v`](../examples/lint/rtl/fsm_with_issues.v) | FSM with state encoding and transition issues |
| [`examples/lint/rtl/fsm_fixed.v`](../examples/lint/rtl/fsm_fixed.v) | Same FSM with all issues fixed |
| [`examples/lint/rtl/memory_controller.v`](../examples/lint/rtl/memory_controller.v) | Realistic memory controller design |

## 2.7 Next Steps

- [Chapter 3: SpyGlass CDC Deep Dive](03_spyglass_cdc.md) — Learn about clock domain crossing analysis.
- [Chapter 4: Practical Workflow](04_practical_workflow.md) — Run SpyGlass end-to-end.
