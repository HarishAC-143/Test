# 03 — Sequential Logic

## Overview

Sequential logic retains state across clock cycles. In SystemVerilog, use `always_ff`
for all clocked (flip-flop-based) designs. The `always_ff` block enforces that the
sensitivity list contains only edge expressions.

## Key Rules

1. **Always use non-blocking assignments (`<=`)** inside `always_ff`.
2. **Reset every flip-flop** — uninitialized flops cause X-propagation.
3. **One clock edge per `always_ff`** — do not mix `posedge` and `negedge` of
   the same clock.
4. **Keep logic simple** inside `always_ff` — compute in `always_comb`, register in `always_ff`.

## Reset Strategies

### Synchronous Reset
- Reset takes effect on the next clock edge.
- Preferred for most FPGA designs — uses regular data path, no dedicated reset routing.
- Requires the clock to be running to reset.

### Asynchronous Reset
- Reset takes effect immediately, independent of the clock.
- Needed when the clock may not be running at startup.
- Requires careful deassertion (synchronize the release to avoid metastability).

## Files in This Directory

- [`counter.sv`](counter.sv) — Configurable up/down counter with enable and load
- [`shift_register.sv`](shift_register.sv) — Parameterized shift register with parallel load
- [`edge_detector.sv`](edge_detector.sv) — Rising/falling/any edge detector
- [`clock_divider.sv`](clock_divider.sv) — Programmable clock divider
- [`pipeline_example.sv`](pipeline_example.sv) — Multi-stage pipeline with valid propagation
- [`counter_tb.sv`](counter_tb.sv) — Self-checking counter testbench
