# 05 — Memories & FIFOs

## Overview

FPGAs contain dedicated Block RAM (BRAM) primitives. By following specific coding
patterns, synthesis tools automatically infer these BRAMs instead of building
memories from flip-flops (which wastes resources).

## RAM Types

| Type | Ports | Read Ports | Write Ports | Use Case |
|------|-------|-----------|-------------|----------|
| Single-port | 1 | 1 (shared) | 1 (shared) | Simple storage |
| Simple dual-port | 2 | 1 | 1 | FIFOs, buffers |
| True dual-port | 2 | 2 | 2 | Multi-access memories |

## BRAM Inference Rules

1. Use a **2D array** for the storage: `logic [WIDTH-1:0] mem [0:DEPTH-1]`.
2. Reads and writes must be **synchronous** (inside `always_ff`).
3. Address must index the array.
4. Avoid reading and writing the same address in the same cycle unless you
   explicitly define the behavior (`READ_FIRST`, `WRITE_FIRST`).

## FIFO Design

A synchronous FIFO uses read and write pointers that index into a circular buffer.
The full/empty conditions are derived from pointer comparison:

- **Empty:** `read_ptr == write_ptr`
- **Full:** `write_ptr + 1 == read_ptr` (or use a separate counter)

Using a power-of-two depth simplifies pointer wrap-around (natural binary overflow).

## Files in This Directory

- [`single_port_ram.sv`](single_port_ram.sv) — Single-port RAM with byte-write enable
- [`dual_port_ram.sv`](dual_port_ram.sv) — Simple dual-port RAM (1R + 1W)
- [`sync_fifo.sv`](sync_fifo.sv) — Synchronous FIFO with programmable depth
- [`sync_fifo_tb.sv`](sync_fifo_tb.sv) — FIFO testbench with full/empty checks
- [`rom_lookup.sv`](rom_lookup.sv) — ROM with initialization from file
