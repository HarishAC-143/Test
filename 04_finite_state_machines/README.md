# 04 — Finite State Machines

## Overview

Finite State Machines (FSMs) are the backbone of control logic in digital designs.
SystemVerilog's `typedef enum` and `unique case` make FSMs readable, maintainable,
and tool-friendly.

## Mealy vs Moore

| Property | Moore | Mealy |
|----------|-------|-------|
| Output depends on | State only | State + inputs |
| Output changes | One clock after input | Same cycle as input |
| Typical latency | Higher | Lower |
| Glitch risk on output | Lower | Higher (use output register) |
| State count | Often more states | Fewer states |

## Encoding Styles

| Encoding | Flip-Flops | Logic | Best For |
|----------|-----------|-------|----------|
| Binary | log₂(N) | More decode logic | ASICs, tight resources |
| One-hot | N | Less decode logic | FPGAs (abundant FFs) |
| Gray | log₂(N) | Moderate | Sequential transitions |

FPGA synthesis tools usually choose one-hot automatically when beneficial.

## Coding Styles

### Two-Process (Recommended)
- Process 1 (`always_ff`): State register update.
- Process 2 (`always_comb`): Next-state and output logic.
- Clean separation of sequential and combinational logic.

### Three-Process
- Process 1: State register.
- Process 2: Next-state logic.
- Process 3: Output logic.
- More verbose but separates output computation.

### Single-Process
- Everything in one `always_ff`.
- Compact but mixes sequential and combinational concerns.

## Files in This Directory

- [`traffic_light_fsm.sv`](traffic_light_fsm.sv) — Moore FSM: traffic light controller
- [`traffic_light_fsm_tb.sv`](traffic_light_fsm_tb.sv) — Testbench for traffic light
- [`serial_detector_fsm.sv`](serial_detector_fsm.sv) — Mealy FSM: pattern detector (detects "1011")
- [`vending_machine_fsm.sv`](vending_machine_fsm.sv) — Complex FSM: vending machine controller
