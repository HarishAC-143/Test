# Synopsys SpyGlass Lint & CDC Tutorial

A comprehensive, hands-on tutorial covering Synopsys SpyGlass for **RTL Lint analysis** and **Clock Domain Crossing (CDC) verification**, complete with practical Verilog/SystemVerilog examples, project setup files, and methodology guidance.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [SpyGlass Overview](#2-spyglass-overview)
3. [Installation & Environment Setup](#3-installation--environment-setup)
4. [SpyGlass Project Setup](#4-spyglass-project-setup)
5. [SpyGlass Lint](#5-spyglass-lint)
   - [What Lint Checks Do](#51-what-lint-checks-do)
   - [Running Lint Analysis](#52-running-lint-analysis)
   - [Common Lint Rules & Violations](#53-common-lint-rules--violations)
   - [Practical Lint Examples](#54-practical-lint-examples)
6. [Clock Domain Crossing (CDC)](#6-clock-domain-crossing-cdc)
   - [CDC Fundamentals](#61-cdc-fundamentals)
   - [Metastability & Synchronization](#62-metastability--synchronization)
   - [CDC Verification with SpyGlass](#63-cdc-verification-with-spyglass)
   - [Practical CDC Examples](#64-practical-cdc-examples)
7. [SGDC Constraint Files](#7-sgdc-constraint-files)
8. [Waivers & Filtering](#8-waivers--filtering)
9. [SpyGlass GUI & Reports](#9-spyglass-gui--reports)
10. [Advanced Topics](#10-advanced-topics)
11. [Methodology & Best Practices](#11-methodology--best-practices)
12. [Quick Reference](#12-quick-reference)
13. [Repository Structure](#13-repository-structure)

---

## 1. Introduction

Modern SoC designs contain millions of gates, dozens of clock domains, and complex reset architectures. Two of the most critical early-stage verification tasks are:

- **Lint analysis** — catching RTL coding issues (undriven nets, width mismatches, unused signals, race conditions, inferred latches, etc.) before simulation or synthesis.
- **CDC verification** — ensuring that signals crossing between asynchronous clock domains are properly synchronized and will not cause metastability failures in silicon.

**Synopsys SpyGlass** is the industry-standard tool for both of these tasks. It performs static analysis on RTL source code and can catch bugs that are difficult or impossible to find through simulation alone.

### Why SpyGlass?

| Capability | Benefit |
|---|---|
| Rule-based RTL lint | Catches coding errors, style violations, and synthesis issues early |
| Structural CDC analysis | Finds unsynchronized clock domain crossings without simulation |
| Reset domain crossing (RDC) | Verifies reset synchronization |
| Low-power analysis | Checks UPF/CPF power intent |
| Design constraints (SGDC) | Allows precise specification of clocks, resets, and crossing intent |
| Waiver mechanism | Manages known-good violations to focus on real issues |

---

## 2. SpyGlass Overview

### 2.1 SpyGlass Product Family

SpyGlass is not a single tool but a family of analysis engines:

| Product | Purpose |
|---|---|
| **SpyGlass Lint** | RTL coding rule checks (syntax, semantics, synthesis, style) |
| **SpyGlass CDC** | Clock domain crossing analysis |
| **SpyGlass RDC** | Reset domain crossing analysis |
| **SpyGlass DFT** | Design-for-test rule checks |
| **SpyGlass LP** | Low-power (UPF/CPF) analysis |
| **SpyGlass Constraints** | SDC constraint validation |

This tutorial focuses on **Lint** and **CDC**.

### 2.2 SpyGlass Analysis Flow

```
 ┌──────────────┐
 │  RTL Source   │ (.v, .sv, .vhd)
 └──────┬───────┘
        │
        ▼
 ┌──────────────┐
 │  Project File │ (.prj)
 │  + SGDC       │ (.sgdc)
 └──────┬───────┘
        │
        ▼
 ┌──────────────┐      ┌──────────────┐
 │  SpyGlass    │─────▶│  Reports     │
 │  Engine      │      │  (.rpt)      │
 └──────┬───────┘      └──────────────┘
        │
        ▼
 ┌──────────────┐
 │  GUI / Debug │
 │  (spyglass)  │
 └──────────────┘
```

### 2.3 Key Terminology

| Term | Definition |
|---|---|
| **Goal** | A predefined set of analysis rules (e.g., `lint/lint_rtl`, `cdc/cdc_verify`) |
| **Rule** | An individual check (e.g., `W110` for undriven input port) |
| **SGDC** | SpyGlass Design Constraints — file format for specifying clocks, resets, and waivers |
| **Waiver** | An intentional suppression of a known-acceptable violation |
| **Severity** | Fatal / Error / Warning / Info classification of each violation |
| **Schematic** | SpyGlass GUI view showing connectivity around a violation |

---

## 3. Installation & Environment Setup

### 3.1 License Setup

SpyGlass requires a valid Synopsys license. Set the license server:

```bash
export SNPSLMD_LICENSE_FILE=27000@license_server
export LM_LICENSE_FILE=27000@license_server
```

### 3.2 Tool Path Setup

```bash
# Point to your SpyGlass installation
export SPYGLASS_HOME=/path/to/spyglass/SPYGLASS_LATEST
export PATH=$SPYGLASS_HOME/bin:$PATH

# Verify installation
spyglass -version
sg_shell -version
```

### 3.3 Common Invocation Modes

| Command | Mode | Use Case |
|---|---|---|
| `spyglass` | GUI mode | Interactive debugging and schematic views |
| `sg_shell` | Interactive shell | Scripted/batch analysis with TCL commands |
| `sg_shell -tcl script.tcl` | Batch mode | CI/CD integration and regression runs |

---

## 4. SpyGlass Project Setup

### 4.1 Project File (.prj)

The project file tells SpyGlass where to find your RTL, which top-level module to analyze, and which technology to target.

See [`project/example.prj`](project/example.prj) for a complete project file.

```tcl
# Minimal project file
set_option top        my_top_module
set_option language   verilog
set_option enableSV   yes

# Read RTL sources
read_file -type verilog {
    rtl/clk_divider.v
    rtl/async_fifo.v
    rtl/top_module.v
}

# Read design constraints
read_file -type sgdc constraints/design.sgdc

# Set analysis goals
current_goal lint/lint_rtl
run_goal

current_goal cdc/cdc_verify
run_goal
```

### 4.2 Running from Command Line

```bash
# Batch mode with a TCL script
sg_shell -tcl scripts/run_spyglass.tcl

# Interactive GUI
spyglass -project project/example.prj

# Quick run with a single goal
sg_shell << EOF
set_option top top_module
read_file -type verilog rtl/top_module.v
current_goal lint/lint_rtl
run_goal
EOF
```

### 4.3 Project File Options Reference

```tcl
# Common project options
set_option top           <module>      ;# Top-level module
set_option language      verilog       ;# verilog | vhdl | systemverilog
set_option enableSV      yes           ;# Enable SystemVerilog
set_option define        {SYNTHESIS 1} ;# Define macros
set_option incdir        {./include}   ;# Include directories
set_option lib           {work}        ;# Library name
set_option mthresh       50000         ;# Message threshold
set_option sgsyn         synopsys_dc   ;# Target synthesis tool
set_option allow_module_override yes   ;# Allow module redefinition
```

---

## 5. SpyGlass Lint

### 5.1 What Lint Checks Do

Lint analysis examines RTL code for issues that fall into several categories:

| Category | Examples |
|---|---|
| **Syntax & Semantics** | Incorrect port connections, parameter misuse |
| **Synthesis** | Inferred latches, combinational loops, multi-driven nets |
| **Simulation-Synthesis Mismatch** | Incomplete sensitivity lists, blocking/non-blocking misuse |
| **Coding Style** | Naming conventions, magic numbers, missing defaults |
| **Connectivity** | Undriven inputs, unloaded outputs, floating nets |
| **Arithmetic** | Width mismatches, truncation, sign extension issues |

### 5.2 Running Lint Analysis

#### Common Lint Goals

| Goal | Description |
|---|---|
| `lint/lint_rtl` | Comprehensive RTL lint checks |
| `lint/lint_turbo_rtl` | Faster subset of lint checks |
| `lint/lint_rtl_enhanced` | Extended checks including naming and style |
| `lint/lint_abstract` | Checks on abstract/interface-level models |

#### TCL Commands for Lint

```tcl
# Run basic lint
current_goal lint/lint_rtl
run_goal

# Run with specific rules enabled/disabled
current_goal lint/lint_rtl
set_goal_option rule -enable  W110 W116 W120
set_goal_option rule -disable W156
run_goal

# Generate reports
write_report -type summary -output reports/lint_summary.rpt
write_report -type detail  -output reports/lint_detail.rpt
```

### 5.3 Common Lint Rules & Violations

Below is a categorized reference of the most frequently encountered SpyGlass lint rules.

#### Connectivity Rules

| Rule | Severity | Description |
|---|---|---|
| **W110** | Warning | Undriven input port |
| **W116** | Warning | Unloaded output port |
| **W120** | Warning | Signal used but not driven |
| **W123** | Warning | Signal driven but not used |
| **W164** | Warning | Bit-width mismatch in port connection |
| **W240** | Warning | Undriven internal net |
| **W287** | Warning | Unconnected port in module instantiation |

#### Synthesis Rules

| Rule | Severity | Description |
|---|---|---|
| **W15** | Warning | Inferred latch (incomplete `if`/`case`) |
| **W18** | Warning | Combinational loop detected |
| **W71** | Warning | Blocking assignment in sequential always block |
| **W72** | Warning | Non-blocking assignment in combinational always block |
| **W263** | Warning | Multi-driven net |
| **W391** | Warning | Non-synthesizable construct |
| **W480** | Warning | Incomplete case statement without `default` |
| **W484** | Warning | Possible loss of carry/borrow in arithmetic |

#### Simulation-Synthesis Mismatch Rules

| Rule | Severity | Description |
|---|---|---|
| **W56** | Warning | Sensitivity list mismatch |
| **W68** | Warning | Variable read before being written in always block |
| **W69** | Warning | Combinational logic depends on edge-triggered signal |

#### Clock & Reset Rules

| Rule | Severity | Description |
|---|---|---|
| **W398** | Warning | Clock signal used as data |
| **W402** | Warning | Both edges of clock used |
| **W408** | Warning | Asynchronous reset used as data |

### 5.4 Practical Lint Examples

The [`examples/lint/`](examples/lint/) directory contains complete RTL files demonstrating common lint violations and their fixes.

#### Example 1: Inferred Latch (W15)

**Problem:** An incomplete `if` or `case` statement in a combinational block causes a latch to be inferred during synthesis.

**Buggy code** ([`examples/lint/rtl/latch_inferred.v`](examples/lint/rtl/latch_inferred.v)):

```verilog
// W15: incomplete if/case causes latch inference
module priority_encoder (
    input  [3:0] req,
    output reg [1:0] grant
);
    always @(*) begin
        if (req[3])
            grant = 2'b11;
        else if (req[2])
            grant = 2'b10;
        else if (req[1])
            grant = 2'b01;
        // Missing: else grant = 2'b00;
        // When req == 4'b0001 or 4'b0000, grant holds
        // its previous value → latch inferred
    end
endmodule
```

**Fix** ([`examples/lint/fixed/latch_inferred_fixed.v`](examples/lint/fixed/latch_inferred_fixed.v)):

```verilog
module priority_encoder (
    input  [3:0] req,
    output reg [1:0] grant
);
    always @(*) begin
        if (req[3])
            grant = 2'b11;
        else if (req[2])
            grant = 2'b10;
        else if (req[1])
            grant = 2'b01;
        else
            grant = 2'b00;  // Default assignment prevents latch
    end
endmodule
```

#### Example 2: Width Mismatch (W164)

**Problem:** Port connection widths don't match, causing silent truncation or zero-extension.

**Buggy code** ([`examples/lint/rtl/width_mismatch.v`](examples/lint/rtl/width_mismatch.v)):

```verilog
// W164: bit-width mismatch in port connection
module adder (
    input  [7:0] a, b,
    output [8:0] sum       // 9-bit output
);
    assign sum = a + b;
endmodule

module top_width (
    input  [7:0] x, y,
    output [7:0] result    // 8-bit — truncates carry!
);
    adder u_adder (
        .a   (x),
        .b   (y),
        .sum (result)       // W164: 9-bit port → 8-bit net
    );
endmodule
```

**Fix** ([`examples/lint/fixed/width_mismatch_fixed.v`](examples/lint/fixed/width_mismatch_fixed.v)):

```verilog
module top_width (
    input  [7:0] x, y,
    output [7:0] result,
    output       carry
);
    wire [8:0] full_sum;

    adder u_adder (
        .a   (x),
        .b   (y),
        .sum (full_sum)
    );

    assign result = full_sum[7:0];
    assign carry  = full_sum[8];
endmodule
```

#### Example 3: Blocking in Sequential Logic (W71)

**Problem:** Using blocking assignments (`=`) in a clocked `always` block causes simulation-synthesis mismatch and race conditions.

**Buggy code** ([`examples/lint/rtl/blocking_sequential.v`](examples/lint/rtl/blocking_sequential.v)):

```verilog
// W71: blocking assignment in sequential always block
module pipeline (
    input        clk, rst_n,
    input  [7:0] data_in,
    output [7:0] data_out
);
    reg [7:0] stage1, stage2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 = 8'h0;   // W71: should be <=
            stage2 = 8'h0;   // W71: should be <=
        end else begin
            stage1 = data_in; // W71: blocking in sequential
            stage2 = stage1;  // Race! stage2 gets data_in directly
        end
    end

    assign data_out = stage2;
endmodule
```

**Fix** ([`examples/lint/fixed/blocking_sequential_fixed.v`](examples/lint/fixed/blocking_sequential_fixed.v)):

```verilog
module pipeline (
    input        clk, rst_n,
    input  [7:0] data_in,
    output [7:0] data_out
);
    reg [7:0] stage1, stage2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= 8'h0;
            stage2 <= 8'h0;
        end else begin
            stage1 <= data_in;
            stage2 <= stage1;  // Correctly samples previous stage1
        end
    end

    assign data_out = stage2;
endmodule
```

#### Example 4: Combinational Loop (W18)

**Problem:** A feedback loop through purely combinational logic causes simulation to oscillate and synthesis to fail or produce unpredictable behavior.

**Buggy code** ([`examples/lint/rtl/combo_loop.v`](examples/lint/rtl/combo_loop.v)):

```verilog
// W18: combinational feedback loop
module combo_loop (
    input  a, b,
    output y
);
    wire mid;
    assign mid = a & y;    // 'y' feeds back into its own computation
    assign y   = mid | b;  // W18: combinational loop: y → mid → y
endmodule
```

**Fix** ([`examples/lint/fixed/combo_loop_fixed.v`](examples/lint/fixed/combo_loop_fixed.v)):

```verilog
module combo_loop_fixed (
    input      clk, rst_n,
    input      a, b,
    output reg y
);
    wire mid;
    assign mid = a & y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            y <= 1'b0;
        else
            y <= mid | b;  // Register breaks the combinational loop
    end
endmodule
```

#### Example 5: Undriven and Unused Signals (W120, W123, W240)

See [`examples/lint/rtl/undriven_unused.v`](examples/lint/rtl/undriven_unused.v) for a file demonstrating these connectivity issues.

---

## 6. Clock Domain Crossing (CDC)

### 6.1 CDC Fundamentals

A **Clock Domain Crossing** occurs whenever a signal generated in one clock domain is sampled by a flip-flop in a different, asynchronous clock domain.

```
  Clock Domain A              Clock Domain B
 ┌────────────┐    CDC       ┌────────────┐
 │ FF (clk_a) │───crossing──▶│ FF (clk_b) │
 └────────────┘              └────────────┘
```

**Why is CDC dangerous?**

When a signal transitions close to the sampling clock edge in the destination domain, the receiving flip-flop may enter a **metastable** state — an intermediate voltage level between logic 0 and 1. This can:

- Propagate corrupted values downstream
- Cause different parts of the design to see different values (data incoherence)
- Lead to functional failures that are non-deterministic and extremely hard to debug

### 6.2 Metastability & Synchronization

#### The Metastability Problem

```
         clk_b rising edge
              │
    data ─────╱╲────── ← Signal transitions near clock edge
              │
         Flip-flop enters metastable state
         Takes non-deterministic time to resolve
```

The **Mean Time Between Failures (MTBF)** for metastability is:

```
MTBF = 1 / (f_clk × f_data × T_w)
```

Where `T_w` is the metastability window of the receiving flip-flop. For modern processes, a single synchronizer flip-flop may yield an MTBF of only seconds — unacceptable. Adding a second synchronizer stage typically increases MTBF to thousands of years.

#### Synchronizer Patterns

**1. Two-Flop Synchronizer (single-bit signals)**

The simplest and most common CDC pattern. Used for single-bit control signals.

```verilog
module two_ff_sync (
    input  clk_b, rst_b_n,
    input  data_in,       // from clk_a domain
    output data_out        // synchronized to clk_b
);
    reg sync_ff1, sync_ff2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= data_in;   // May go metastable
            sync_ff2 <= sync_ff1;  // Resolves before sampling
        end
    end

    assign data_out = sync_ff2;
endmodule
```

**2. Gray-Code Counter for Multi-Bit Pointers**

Never synchronize a binary counter across clock domains — multiple bits may change simultaneously, causing garbled values. Gray code guarantees only one bit changes per increment.

```
Binary  →  Gray
 000       000
 001       001
 010       011
 011       010
 100       110
 101       111
 110       101
 111       100
```

**3. Pulse Synchronizer (edge detection across domains)**

Converts a single-cycle pulse in the source domain into a single-cycle pulse in the destination domain.

**4. Asynchronous FIFO**

The gold-standard for transferring multi-bit data across clock domains. Uses dual-port RAM with Gray-coded read/write pointers synchronized in each direction.

**5. MUX-based Synchronization (with valid/acknowledge handshake)**

For multi-bit data buses, hold the data stable while a synchronized control signal indicates valid data.

### 6.3 CDC Verification with SpyGlass

#### CDC Goals

| Goal | Description |
|---|---|
| `cdc/cdc_verify` | Main CDC verification — finds unsynchronized crossings |
| `cdc/cdc_verify_struct` | Structural CDC checks |
| `cdc/cdc_fx` | Advanced CDC with formal analysis |

#### Key CDC Rules

| Rule | Severity | Description |
|---|---|---|
| **Ac_cdc01** | Error | Unsynchronized single-bit signal crossing |
| **Ac_cdc02** | Error | Multi-bit signal crossing without proper synchronization |
| **Ac_cdc03** | Warning | Reconvergence of CDC paths |
| **Ac_cdc04** | Warning | Combinational logic before synchronizer |
| **Ac_cdc05** | Warning | Fan-out from CDC signal before synchronization |
| **Ac_cdc06** | Warning | Reset signal crossing clock domain without synchronization |
| **Ac_glitch01** | Warning | Potential glitch on CDC path due to combinational logic |
| **Ac_conv01** | Warning | Convergence of signals from different domains |

#### Running CDC Analysis

```tcl
# Specify clocks in SGDC
current_design top_module

# Read SGDC constraints
read_file -type sgdc constraints/clocks.sgdc

# Run CDC verification
current_goal cdc/cdc_verify
run_goal

# Generate CDC report
write_report -type cdc_detail -output reports/cdc_report.rpt
```

### 6.4 Practical CDC Examples

The [`examples/cdc/`](examples/cdc/) directory contains complete, runnable CDC examples.

#### Example 1: Unsynchronized Single-Bit Crossing (Ac_cdc01)

**Problem:** A control signal crosses from `clk_a` domain to `clk_b` domain with no synchronizer.

**Buggy code** ([`examples/cdc/rtl/unsync_crossing.v`](examples/cdc/rtl/unsync_crossing.v)):

```verilog
// Ac_cdc01: single-bit signal crosses without synchronizer
module unsync_crossing (
    input  clk_a, rst_a_n,
    input  clk_b, rst_b_n,
    input  data_in,
    output reg data_out
);
    reg data_reg_a;

    // Source domain register
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            data_reg_a <= 1'b0;
        else
            data_reg_a <= data_in;
    end

    // Destination domain — DIRECTLY samples from clk_a domain!
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n)
            data_out <= 1'b0;
        else
            data_out <= data_reg_a;  // Ac_cdc01: no synchronizer!
    end
endmodule
```

**Fix** ([`examples/cdc/fixed/unsync_crossing_fixed.v`](examples/cdc/fixed/unsync_crossing_fixed.v)):

```verilog
module unsync_crossing_fixed (
    input  clk_a, rst_a_n,
    input  clk_b, rst_b_n,
    input  data_in,
    output data_out
);
    reg data_reg_a;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            data_reg_a <= 1'b0;
        else
            data_reg_a <= data_in;
    end

    // Proper two-flop synchronizer in destination domain
    reg sync_ff1, sync_ff2;
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= data_reg_a;
            sync_ff2 <= sync_ff1;
        end
    end

    assign data_out = sync_ff2;
endmodule
```

#### Example 2: Multi-Bit CDC Without Gray Code (Ac_cdc02)

**Problem:** A multi-bit bus crosses clock domains using binary encoding. Multiple bits may change simultaneously, and the synchronizer may capture a garbled value.

**Buggy code** ([`examples/cdc/rtl/multibit_crossing.v`](examples/cdc/rtl/multibit_crossing.v)):

```verilog
// Ac_cdc02: multi-bit signal crosses without proper encoding
module multibit_crossing (
    input        clk_a, rst_a_n,
    input        clk_b, rst_b_n,
    input  [3:0] wptr_bin,
    output reg [3:0] wptr_sync
);
    reg [3:0] sync1, sync2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1     <= 4'b0;
            sync2     <= 4'b0;
            wptr_sync <= 4'b0;
        end else begin
            sync1     <= wptr_bin;  // Ac_cdc02: binary multi-bit crossing!
            sync2     <= sync1;
            wptr_sync <= sync2;
        end
    end
endmodule
```

**Fix** ([`examples/cdc/fixed/multibit_crossing_fixed.v`](examples/cdc/fixed/multibit_crossing_fixed.v)):

```verilog
module multibit_crossing_fixed (
    input        clk_a, rst_a_n,
    input        clk_b, rst_b_n,
    input  [3:0] wptr_bin,
    output [3:0] wptr_sync_bin
);
    // Convert binary to Gray code in source domain
    wire [3:0] wptr_gray = wptr_bin ^ (wptr_bin >> 1);

    // Synchronize Gray-coded pointer in destination domain
    reg [3:0] sync1, sync2;
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1 <= 4'b0;
            sync2 <= 4'b0;
        end else begin
            sync1 <= wptr_gray;
            sync2 <= sync1;
        end
    end

    // Convert Gray back to binary in destination domain
    assign wptr_sync_bin[3] = sync2[3];
    assign wptr_sync_bin[2] = sync2[3] ^ sync2[2];
    assign wptr_sync_bin[1] = sync2[3] ^ sync2[2] ^ sync2[1];
    assign wptr_sync_bin[0] = sync2[3] ^ sync2[2] ^ sync2[1] ^ sync2[0];
endmodule
```

#### Example 3: Combinational Logic Before Synchronizer (Ac_cdc04)

**Problem:** Combinational logic on the CDC path before the synchronizer input can generate glitches that the synchronizer might capture.

See [`examples/cdc/rtl/combo_before_sync.v`](examples/cdc/rtl/combo_before_sync.v) for the violation and [`examples/cdc/fixed/combo_before_sync_fixed.v`](examples/cdc/fixed/combo_before_sync_fixed.v) for the fix.

#### Example 4: Asynchronous FIFO (Complete CDC Solution)

A complete asynchronous FIFO implementation is provided in [`examples/cdc/rtl/async_fifo.v`](examples/cdc/rtl/async_fifo.v). This demonstrates the proper way to transfer multi-bit data across clock domains using:

- Dual-port RAM
- Gray-coded write and read pointers
- Two-flop synchronizers for pointer crossing
- Full/empty flag generation in the correct domain

#### Example 5: Pulse Synchronizer

See [`examples/cdc/rtl/pulse_sync.v`](examples/cdc/rtl/pulse_sync.v) for a complete pulse synchronizer that safely transfers a single-cycle pulse from one clock domain to another.

#### Example 6: MUX-Based Data Synchronization

See [`examples/cdc/rtl/mux_sync.v`](examples/cdc/rtl/mux_sync.v) for a handshake-based multi-bit data transfer using the MUX synchronization scheme.

---

## 7. SGDC Constraint Files

SGDC (SpyGlass Design Constraints) files provide critical information about the design's clock structure, reset architecture, and intended CDC behavior.

### 7.1 Clock Definitions

```tcl
# Define clocks
create_clock -name sys_clk  -period 10   [get_ports clk_100mhz]
create_clock -name fast_clk -period 5    [get_ports clk_200mhz]
create_clock -name slow_clk -period 20   [get_ports clk_50mhz]

# Generated clocks (divided from a parent)
create_generated_clock -name div2_clk \
    -source [get_ports clk_100mhz] \
    -divide_by 2 \
    [get_pins u_divider/clk_out]
```

### 7.2 Clock Relationships

```tcl
# Declare clocks as asynchronous to each other
set_clock_groups -asynchronous \
    -group {sys_clk} \
    -group {fast_clk}

# Declare clocks as synchronous (same source, fixed phase)
# No constraint needed — SpyGlass assumes synchronous by default
# for clocks from the same source.
```

### 7.3 Reset Definitions

```tcl
# Identify reset signals
set_reset -name main_reset  [get_ports rst_n] -async -sense low
set_reset -name pcie_reset  [get_ports pcie_rst_n] -async -sense low
```

### 7.4 CDC Constraints

```tcl
# Specify expected synchronization schemes
set_cdc_synchronizer -type two_dff \
    -from sys_clk -to fast_clk \
    [get_cells u_sync/sync_ff1]

# Quasi-static signals (change only during reset or initialization)
set_cdc_signal -type quasi_static \
    -from sys_clk -to fast_clk \
    [get_nets config_reg[*]]

# Mark intentionally unsynchronized paths (with justification)
set_cdc_false_path \
    -from sys_clk -to fast_clk \
    [get_nets debug_signal]
```

### 7.5 Complete SGDC Example

See [`examples/cdc/constraints/design.sgdc`](examples/cdc/constraints/design.sgdc) for a complete constraint file.

---

## 8. Waivers & Filtering

Not every reported violation is a real bug. SpyGlass provides mechanisms to filter out known-acceptable issues.

### 8.1 Waiver File Syntax

```tcl
# Waive a specific rule on a specific signal
waive -rule W123 -comment "Debug signal intentionally unloaded" \
    -module top_module -signal debug_out

# Waive by instance path
waive -rule Ac_cdc01 \
    -comment "Signal is quasi-static, changes only at boot" \
    -instance u_top/u_config/boot_mode_reg

# Waive by rule across entire design
waive -rule W287 -comment "Unconnected test ports for DFT"
```

### 8.2 Waiver Best Practices

1. **Always add a `-comment`** explaining why the waiver is safe
2. **Be as specific as possible** — waive individual signals, not entire rules
3. **Review waivers periodically** — design changes may invalidate previous justifications
4. **Track waivers in version control** alongside RTL
5. **Categorize waivers** — separate intentional waivers from temporary workarounds

### 8.3 Severity Filtering

```tcl
# Only show errors and fatals
set_option report_severity {fatal error}

# Suppress informational messages
set_option suppress_info yes
```

See [`project/waivers.tcl`](project/waivers.tcl) for a complete waiver file example.

---

## 9. SpyGlass GUI & Reports

### 9.1 Launching the GUI

```bash
# Open a completed analysis in the GUI
spyglass -project project/example.prj

# Open results from a previous run
spyglass -results results_dir/
```

### 9.2 GUI Features

| View | Purpose |
|---|---|
| **Message Browser** | Lists all violations, sortable by severity/rule/module |
| **Schematic View** | Shows circuit connectivity around a violation |
| **Source View** | Highlights the offending RTL line |
| **CDC Matrix** | Shows all clock domain pairs and crossing status |
| **CDC Paths** | Visualizes the synchronization path for each crossing |
| **Waiver Manager** | Create and manage waivers interactively |

### 9.3 Report Generation

```tcl
# Summary report
write_report -type summary -output reports/summary.rpt

# Detailed violation report
write_report -type detail -output reports/detail.rpt

# CDC-specific reports
write_report -type cdc_detail -output reports/cdc.rpt
write_report -type cdc_matrix -output reports/cdc_matrix.rpt

# Waiver report
write_report -type waiver -output reports/waivers.rpt

# HTML report for sharing
write_report -type html -output reports/spyglass_report.html
```

---

## 10. Advanced Topics

### 10.1 Reset Domain Crossing (RDC)

Similar to CDC but for reset signals. SpyGlass RDC verifies that:
- Reset de-assertion is synchronized to the destination clock
- Reset trees don't have glitches
- Reset sequencing is correct

```tcl
current_goal rdc/rdc_verify
run_goal
```

See [`examples/advanced/reset_sync.v`](examples/advanced/reset_sync.v) for a reset synchronizer example.

### 10.2 Reconvergence Analysis (Ac_cdc03)

Reconvergence occurs when the same source signal is synchronized through multiple paths and they later converge. Even though each path is individually synchronized, they may arrive at different times, causing data corruption.

```
                    ┌── sync_path_1 ──┐
     source_sig ───┤                  ├──▶ downstream_logic
                    └── sync_path_2 ──┘
                    
     Each path may have different latency!
```

See [`examples/advanced/reconvergence.v`](examples/advanced/reconvergence.v).

### 10.3 Glitch Detection (Ac_glitch01)

Combinational logic on a CDC path can produce transient glitches shorter than a clock period. If such a glitch arrives at a flip-flop close to the clock edge, it may be incorrectly captured.

### 10.4 CI/CD Integration

SpyGlass can be integrated into continuous integration pipelines:

```bash
#!/bin/bash
# ci_spyglass.sh — Run SpyGlass in CI and fail on errors

sg_shell -tcl scripts/run_spyglass.tcl 2>&1 | tee spyglass.log

# Parse results
ERROR_COUNT=$(grep -c "^Error" reports/summary.rpt)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "SpyGlass found $ERROR_COUNT errors!"
    exit 1
fi

echo "SpyGlass clean."
exit 0
```

### 10.5 Incremental Analysis

For large designs, run SpyGlass incrementally on changed modules:

```tcl
set_option incr_mode on
set_option incr_db   results_dir/previous_run
```

---

## 11. Methodology & Best Practices

### 11.1 Lint Methodology

1. **Start with `lint/lint_rtl`** — run on every RTL check-in
2. **Fix all errors first** — then move to warnings
3. **Establish a clean baseline** — waive justified warnings, then enforce zero new violations
4. **Integrate into CI** — block merges that introduce new lint errors
5. **Use naming conventions** — configure SpyGlass to enforce your team's naming rules

### 11.2 CDC Methodology

1. **Define all clocks and resets in SGDC** — incorrect clock definitions lead to false negatives
2. **Run `cdc/cdc_verify` after every architectural change** — new crossings are easily introduced
3. **Use standard synchronizer cells** from your library — don't hand-code synchronizers
4. **Review every Ac_cdc01/02** — unsynchronized crossings are potential silicon bugs
5. **Pay attention to reconvergence (Ac_cdc03)** — these are often the subtlest CDC bugs
6. **Mark quasi-static signals explicitly** — reduces noise from configuration registers
7. **Never ignore multi-bit crossings** — always use Gray code, handshake, or FIFO

### 11.3 Common Mistakes to Avoid

| Mistake | Consequence |
|---|---|
| Forgetting to define a clock in SGDC | CDC crossings go undetected |
| Using binary counter across domains | Garbled pointer values → data corruption |
| Combinational logic before synchronizer | Glitches captured as valid data |
| Synchronizing related signals independently | Reconvergence → data incoherence |
| Waiving violations without understanding them | Real bugs masked |
| Running CDC without proper constraints | Excessive false positives drown real issues |

### 11.4 Recommended Run Order

```
1. lint/lint_rtl          → Fix all RTL coding issues first
2. lint/lint_rtl_enhanced → Catch additional style/naming issues
3. cdc/cdc_verify         → Find all CDC violations
4. rdc/rdc_verify         → Find reset domain issues
5. Review & waive         → Justify and waive acceptable violations
6. Regression             → Re-run to confirm zero open issues
```

---

## 12. Quick Reference

### SpyGlass Shell Commands

```tcl
# Project setup
set_option top <module>
read_file -type verilog <file>
read_file -type sgdc <file>

# Goal management
current_goal <goal>
run_goal
set_goal_option rule -enable <rule>
set_goal_option rule -disable <rule>

# Reporting
write_report -type summary -output <file>
write_report -type detail -output <file>
write_report -type cdc_detail -output <file>

# Waivers
waive -rule <rule> -comment "<reason>" -module <mod> -signal <sig>

# Design queries
get_ports <pattern>
get_cells <pattern>
get_nets <pattern>
get_pins <pattern>
```

### Common Command-Line Invocations

```bash
# GUI mode
spyglass -project design.prj

# Batch mode
sg_shell -tcl run.tcl

# Quick lint run
sg_shell -tcl - <<'EOF'
set_option top my_module
read_file -type verilog rtl/my_module.v
current_goal lint/lint_rtl
run_goal
write_report -type summary -output lint.rpt
EOF

# CDC run with constraints
sg_shell -tcl - <<'EOF'
set_option top my_soc
read_file -type verilog {rtl/module_a.v rtl/module_b.v rtl/top.v}
read_file -type sgdc constraints/clocks.sgdc
current_goal cdc/cdc_verify
run_goal
write_report -type cdc_detail -output cdc.rpt
EOF
```

---

## 13. Repository Structure

```
├── README.md                              ← This tutorial
├── project/
│   ├── example.prj                        ← SpyGlass project file
│   └── waivers.tcl                        ← Waiver examples
├── scripts/
│   └── run_spyglass.tcl                   ← Batch run script
├── examples/
│   ├── lint/
│   │   ├── rtl/
│   │   │   ├── latch_inferred.v           ← W15 example
│   │   │   ├── width_mismatch.v           ← W164 example
│   │   │   ├── blocking_sequential.v      ← W71 example
│   │   │   ├── combo_loop.v               ← W18 example
│   │   │   └── undriven_unused.v          ← W120/W123/W240 examples
│   │   └── fixed/
│   │       ├── latch_inferred_fixed.v
│   │       ├── width_mismatch_fixed.v
│   │       ├── blocking_sequential_fixed.v
│   │       └── combo_loop_fixed.v
│   ├── cdc/
│   │   ├── rtl/
│   │   │   ├── unsync_crossing.v          ← Ac_cdc01 example
│   │   │   ├── multibit_crossing.v        ← Ac_cdc02 example
│   │   │   ├── combo_before_sync.v        ← Ac_cdc04 example
│   │   │   ├── async_fifo.v               ← Complete async FIFO
│   │   │   ├── pulse_sync.v               ← Pulse synchronizer
│   │   │   └── mux_sync.v                 ← MUX-based synchronizer
│   │   ├── fixed/
│   │   │   ├── unsync_crossing_fixed.v
│   │   │   ├── multibit_crossing_fixed.v
│   │   │   └── combo_before_sync_fixed.v
│   │   └── constraints/
│   │       └── design.sgdc                ← SGDC constraint file
│   └── advanced/
│       ├── reset_sync.v                   ← Reset synchronizer
│       └── reconvergence.v                ← Reconvergence example
```

---

## License

This tutorial is provided for educational purposes. SpyGlass is a trademark of Synopsys, Inc.
