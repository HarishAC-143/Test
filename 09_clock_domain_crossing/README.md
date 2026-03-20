# 09 — Clock Domain Crossing (CDC)

## Overview

When signals cross between different clock domains, metastability can corrupt data.
CDC techniques ensure safe, reliable data transfer between asynchronous clock domains.

## The Metastability Problem

When a flip-flop's input changes too close to the clock edge (violating setup/hold
time), the output can settle to an unpredictable value or oscillate — this is
**metastability**. The probability of remaining metastable decreases exponentially
with time, so adding synchronization flip-flops reduces the failure rate to
negligible levels.

## CDC Techniques Summary

| Technique | Signal Type | Latency | Complexity |
|-----------|-------------|---------|------------|
| Two-flop synchronizer | Single bit, slow-changing | 2 cycles | Low |
| Pulse synchronizer | Single-cycle pulse | 2-3 cycles | Low |
| Gray-code FIFO | Multi-bit data stream | 2-3 cycles | Medium |
| Handshake | Multi-bit, infrequent | 4+ cycles | Medium |
| MUX recirculation | Multi-bit, with enable | 2 cycles | Low |

## Key Rules

1. **Never** pass a multi-bit binary value directly across clock domains.
2. **Always** use at least a two-flop synchronizer for single-bit signals.
3. For multi-bit data, use **Gray code pointers** (async FIFO) or a **handshake**.
4. **Constrain** synchronizer paths in SDC with `set_false_path` or `set_max_delay`.
5. **Name** synchronizer instances clearly so CDC tools can identify them.

## Files in This Directory

- [`two_ff_sync.sv`](two_ff_sync.sv) — Two-flop synchronizer for single-bit CDC
- [`pulse_sync.sv`](pulse_sync.sv) — Pulse synchronizer (toggle-domain technique)
- [`async_fifo.sv`](async_fifo.sv) — Asynchronous FIFO with Gray-code pointers
- [`async_fifo_tb.sv`](async_fifo_tb.sv) — Testbench for the async FIFO
- [`handshake_sync.sv`](handshake_sync.sv) — Handshake-based multi-bit synchronizer
