# 02 — Combinational Logic

## Overview

Combinational logic produces outputs that depend solely on current inputs — there is
no memory or state. In SystemVerilog, use `always_comb` or `assign` for combinational
blocks. The simulator enforces that no latches are inferred from `always_comb`.

## `always_comb` vs `assign`

| Feature | `assign` | `always_comb` |
|---------|----------|---------------|
| Single expression | Preferred | Works but verbose |
| Multi-line logic | Awkward | Preferred |
| Case/if-else | Not supported | Supported |
| Latch detection | N/A | Simulator warns |
| Sensitivity list | Automatic | Automatic |

## Common Patterns

### Multiplexers

```systemverilog
// 2:1 mux via assign
assign y = sel ? a : b;

// 4:1 mux via always_comb
always_comb begin
    unique case (sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
        2'b11: y = d;
    endcase
end
```

### Priority Encoder

```systemverilog
always_comb begin
    priority casez (request)
        4'b1???: grant = 4'b1000;
        4'b01??: grant = 4'b0100;
        4'b001?: grant = 4'b0010;
        4'b0001: grant = 4'b0001;
        default: grant = 4'b0000;
    endcase
end
```

## Files in This Directory

- [`mux4to1.sv`](mux4to1.sv) — Parameterized 4:1 multiplexer
- [`decoder.sv`](decoder.sv) — Parameterized binary-to-one-hot decoder
- [`priority_encoder.sv`](priority_encoder.sv) — Priority encoder with valid flag
- [`alu.sv`](alu.sv) — Simple ALU demonstrating `unique case`
- [`alu_tb.sv`](alu_tb.sv) — Self-checking ALU testbench
