# 11 — Testbenches & Verification

## Overview

A testbench is non-synthesizable SystemVerilog code that drives stimulus into your
design (DUT — Device Under Test) and checks the outputs. Good testbenches are
**self-checking** — they compare DUT outputs against expected values automatically.

## Testbench Structure

```
┌──────────────────────────────────┐
│          Testbench               │
│                                  │
│  ┌──────────┐  ┌──────────────┐  │
│  │ Stimulus  │  │  Reference   │  │
│  │ Generator │  │    Model     │  │
│  └────┬──┬──┘  └──────┬───────┘  │
│       │  │             │          │
│  ┌────▼──▼──┐   ┌──────▼───────┐ │
│  │   DUT    │   │   Checker /  │ │
│  │ (design) │──►│   Scoreboard │ │
│  └──────────┘   └──────────────┘ │
│                                  │
│  ┌──────────────────────────────┐│
│  │ Clock & Reset Generation     ││
│  └──────────────────────────────┘│
└──────────────────────────────────┘
```

## Key Patterns

### Clock Generation

```systemverilog
localparam int CLK_PERIOD = 10; // ns

logic clk;
initial clk = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;
```

### Reset Sequence

```systemverilog
logic rst_n;
initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
end
```

### Self-Checking with Assertions

```systemverilog
if (actual !== expected) begin
    $error("Mismatch: got %h, expected %h", actual, expected);
    error_count++;
end
```

### Waveform Dumping

```systemverilog
initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_top);
end
```

### Timeout Watchdog

```systemverilog
initial begin
    #(CLK_PERIOD * 100000);
    $error("Simulation timeout");
    $finish;
end
```

## Files in This Directory

- [`tb_template.sv`](tb_template.sv) — Reusable testbench template
- [`clk_rst_generator.sv`](clk_rst_generator.sv) — Configurable clock and reset module
- [`self_checking_example_tb.sv`](self_checking_example_tb.sv) — Complete self-checking testbench
