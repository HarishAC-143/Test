# 08 — SystemVerilog Assertions & Coverage

## Overview

SystemVerilog Assertions (SVA) provide a concise way to specify and verify temporal
properties of your design. They catch bugs that simple self-checking testbenches
often miss.

## Assertion Types

### Immediate Assertions

Checked at the point of execution in procedural code (like an `if` check):

```systemverilog
always_comb begin
    assert (state != ILLEGAL) else $error("Entered illegal state");
end
```

### Concurrent Assertions

Evaluated on every clock edge, can express multi-cycle temporal properties:

```systemverilog
assert property (@(posedge clk) disable iff (!rst_n)
    req |-> ##[1:3] ack
) else $error("ACK not received within 3 cycles of REQ");
```

## Sequence Operators

| Operator | Meaning | Example |
|----------|---------|---------|
| `##N` | N-cycle delay | `a ##2 b` — `b` is true 2 cycles after `a` |
| `##[M:N]` | Delay range | `a ##[1:3] b` — `b` within 1-3 cycles |
| `\|->` | Overlapping implication | `a \|-> b` — if `a`, `b` must be true same cycle |
| `\|=>` | Non-overlapping implication | `a \|=> b` — if `a`, `b` must be true next cycle |
| `[*N]` | Consecutive repetition | `a[*3]` — `a` for 3 consecutive cycles |
| `[*M:N]` | Repetition range | `a[*1:5]` — `a` for 1 to 5 cycles |

## Functional Coverage

Coverage measures which scenarios have been exercised during simulation:

```systemverilog
covergroup cg_txn @(posedge clk);
    cp_opcode: coverpoint opcode {
        bins read  = {OP_READ};
        bins write = {OP_WRITE};
    }
    cp_size: coverpoint size {
        bins small  = {[1:4]};
        bins medium = {[5:16]};
        bins large  = {[17:64]};
    }
    cross_op_size: cross cp_opcode, cp_size;
endgroup
```

## Files in This Directory

- [`assertion_examples.sv`](assertion_examples.sv) — Common assertion patterns for RTL
- [`coverage_example.sv`](coverage_example.sv) — Functional coverage for a protocol module
