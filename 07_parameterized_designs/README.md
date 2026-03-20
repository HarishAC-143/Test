# 07 — Parameterized & Generate Designs

## Overview

Parameterization is the key to reusable RTL. A single module can serve multiple
configurations by using `parameter`, `localparam`, and `generate` constructs.

## Parameter Types

| Keyword | Overridable? | Scope | Use |
|---------|-------------|-------|-----|
| `parameter` | Yes (at instantiation) | Module | Width, depth, mode selection |
| `localparam` | No | Module | Derived constants |
| `parameter type` | Yes | Module | Generic data types |

## Generate Constructs

### `generate for`

Replicate hardware structures a parameterized number of times.

```systemverilog
genvar i;
generate
    for (i = 0; i < N; i++) begin : gen_stage
        pipe_stage u_stage (.clk(clk), ...);
    end
endgenerate
```

### `generate if`

Conditionally include or exclude hardware.

```systemverilog
generate
    if (USE_BRAM) begin : gen_bram
        bram_wrapper u_mem (...);
    end else begin : gen_lutram
        lutram_wrapper u_mem (...);
    end
endgenerate
```

## `$clog2` for Address Widths

Always compute address widths from depth parameters:

```systemverilog
parameter int DEPTH = 1024;
localparam int ADDR_W = $clog2(DEPTH);  // = 10
```

## Files in This Directory

- [`parameterized_fifo.sv`](parameterized_fifo.sv) — FIFO with type-parameterized data
- [`generate_adder_tree.sv`](generate_adder_tree.sv) — Tree adder using generate-for
- [`configurable_pipeline.sv`](configurable_pipeline.sv) — N-stage pipeline via generate
