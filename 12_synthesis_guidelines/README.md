# 12 — Synthesis & Implementation Guidelines

## Synthesizable vs Non-Synthesizable Constructs

### Synthesizable (use in RTL)

| Construct | Notes |
|-----------|-------|
| `module` / `endmodule` | Hierarchy |
| `always_ff`, `always_comb`, `always_latch` | Sequential, combinational, latch logic |
| `assign` | Continuous assignment |
| `if` / `else` | Conditional logic |
| `case` / `casez` / `casex` | Selection |
| `unique case` / `priority case` | Tool-optimized case |
| `generate` / `for` / `if` | Structural replication |
| `parameter` / `localparam` | Compile-time constants |
| `typedef`, `struct packed`, `enum` | Type definitions |
| `interface` / `modport` | Signal bundling |
| `function` (without `time`) | Combinational logic functions |
| `+`, `-`, `*`, `&`, `\|`, `^`, `~`, `<<`, `>>` | Arithmetic and logic operators |
| `$clog2` | Compile-time math |

### Non-Synthesizable (testbench only)

| Construct | Purpose |
|-----------|---------|
| `initial` blocks | Simulation startup |
| `#delay` | Time-based delays |
| `$display`, `$monitor`, `$write` | Console output |
| `$readmemh`, `$readmemb` | File I/O (exception: ROM initialization) |
| `$finish`, `$stop` | Simulation control |
| `fork` / `join` | Parallel threads |
| `class` | OOP for verification |
| `mailbox`, `semaphore` | IPC primitives |
| `real`, `string` (as ports) | Floating-point, strings |
| Dynamic arrays, queues, associative arrays | Dynamic allocation |
| `$urandom`, `$random` | Random number generation |

## Coding for Timing

### Pipeline Registers

Break long combinational paths by inserting register stages:

```
Before:  [input] → [complex logic A + B + C] → [output]
                    ↑ may violate timing

After:   [input] → [logic A] → [REG] → [logic B] → [REG] → [logic C] → [output]
                    ↑ shorter paths, higher Fmax
```

### Register Outputs

Always register module outputs. This makes timing closure easier because the
output delay is known (just the clock-to-q of the flip-flop).

```systemverilog
// Bad: combinational output, timing depends on what's connected
assign out = complex_expression;

// Good: registered output, predictable timing
always_ff @(posedge clk)
    out <= complex_expression;
```

### Avoid Combinational Loops

A combinational loop is a signal that feeds back to itself through combinational
logic with no register. This creates undefined behavior and will fail synthesis.

## Coding for Area

### Resource Sharing

The synthesizer can share expensive operators (multipliers, dividers) across
mutually exclusive paths:

```systemverilog
// Both multiplications share one multiplier if paths are exclusive
always_comb begin
    if (sel)
        result = a * b;    // reuses the same multiplier
    else
        result = c * d;    // as this one
end
```

### Use DSP Primitives

For multiplication and multiply-accumulate, write code that the synthesizer
can map to dedicated DSP blocks:

```systemverilog
always_ff @(posedge clk)
    product <= a * b;  // infers DSP48 on Xilinx, DSP block on Intel
```

## Clock Management

### Clock Enables (Preferred for FPGAs)

```systemverilog
// Correct: use clock enable
always_ff @(posedge clk)
    if (ce) q <= d;

// Wrong: gated clock (creates clock skew, complicates timing analysis)
// assign gated_clk = clk & enable;
// always_ff @(posedge gated_clk) q <= d;
```

### Reset Strategy

| Reset Type | Pros | Cons |
|-----------|------|------|
| Synchronous | Simpler timing, no async paths | Requires running clock |
| Asynchronous | Works without clock | Needs synchronized deassertion |
| No reset | Saves routing resources | Only for data paths (not control) |

## Vendor-Specific Attributes

### Xilinx (Vivado)

```systemverilog
(* ASYNC_REG = "TRUE" *)    logic [1:0] sync_chain;  // CDC synchronizer
(* KEEP = "TRUE" *)         logic       debug_sig;    // prevent optimization
(* DONT_TOUCH = "TRUE" *)   logic       critical_net; // prevent removal
(* RAM_STYLE = "block" *)   logic [7:0] mem [0:1023]; // force BRAM
(* USE_DSP = "yes" *)       logic [31:0] product;     // force DSP usage
```

### Intel / Altera (Quartus)

```systemverilog
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
logic [1:0] sync_chain;

(* ramstyle = "M20K" *)
logic [7:0] mem [0:1023];

(* preserve *)
logic debug_sig;
```

## Common Synthesis Warnings and Fixes

| Warning | Cause | Fix |
|---------|-------|-----|
| Latch inferred | Incomplete if/case | Add default/else branches |
| Multi-driven net | Signal assigned in multiple always blocks | Ensure single driver |
| Timing not met | Path too long | Add pipeline registers |
| Unconnected port | Module port not wired | Connect or explicitly leave open |
| Width mismatch | Operand sizes differ | Use explicit width casts |
| Unused signal | Declared but not read | Remove or use `(* unused *)` |

## Lint Checking

Run Verilator in lint-only mode before synthesis:

```bash
verilator --lint-only -Wall --top-module my_module my_module.sv
```

This catches many common errors:
- Width mismatches
- Unused signals
- Undriven signals
- Missing case items
- Combinational loops
- Latches

## Timing Constraints Basics

Every FPGA design needs at minimum:

```tcl
# SDC / XDC format

# Define clock (100 MHz example)
create_clock -period 10.0 -name sys_clk [get_ports clk]

# Input delay (relative to clock)
set_input_delay -clock sys_clk -max 3.0 [get_ports data_in]
set_input_delay -clock sys_clk -min 1.0 [get_ports data_in]

# Output delay
set_output_delay -clock sys_clk -max 3.0 [get_ports data_out]
set_output_delay -clock sys_clk -min 1.0 [get_ports data_out]

# False path for CDC synchronizers
set_false_path -to [get_cells */sync_chain_reg[0]]
```

## Files in This Directory

- [`synthesis_do_dont.sv`](synthesis_do_dont.sv) — Annotated examples of good and bad synthesis patterns
