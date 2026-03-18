# Synopsys SpyGlass Lint & CDC -- Comprehensive Tutorial

A hands-on guide to static RTL analysis with **Synopsys SpyGlass**, covering **Lint** (structural/coding-style checks) and **CDC** (Clock Domain Crossing) verification. Every section includes practical examples with Verilog/SystemVerilog source files you can run through SpyGlass yourself.

---

## Table of Contents

1. [What is SpyGlass?](#1-what-is-spyglass)
2. [SpyGlass Lint](#2-spyglass-lint)
   - [2.1 Why Lint Matters](#21-why-lint-matters)
   - [2.2 Rule Categories](#22-rule-categories)
   - [2.3 Running a Lint Session](#23-running-a-lint-session)
   - [2.4 Common Lint Violations with Examples](#24-common-lint-violations-with-examples)
   - [2.5 Fixing Lint Violations](#25-fixing-lint-violations)
   - [2.6 Waivers](#26-waivers)
3. [SpyGlass CDC](#3-spyglass-cdc)
   - [3.1 Why CDC Matters](#31-why-cdc-matters)
   - [3.2 CDC Fundamentals](#32-cdc-fundamentals)
   - [3.3 Running a CDC Session](#33-running-a-cdc-session)
   - [3.4 CDC Constraint Files (SGDC)](#34-cdc-constraint-files-sgdc)
   - [3.5 Common CDC Issues with Examples](#35-common-cdc-issues-with-examples)
   - [3.6 Synchronizer Patterns](#36-synchronizer-patterns)
   - [3.7 CDC Waivers and Scheme Files](#37-cdc-waivers-and-scheme-files)
4. [SpyGlass Project Setup](#4-spyglass-project-setup)
5. [Interpreting Reports](#5-interpreting-reports)
6. [Best Practices](#6-best-practices)
7. [Repository Structure](#7-repository-structure)

---

## 1. What is SpyGlass?

**Synopsys SpyGlass** is a static analysis platform for RTL designs. Unlike simulation (which requires test vectors) or formal verification (which proves properties), SpyGlass analyses the *structure* of RTL code without executing it.

SpyGlass ships with several analysis engines:

| Engine | Purpose |
|--------|---------|
| **SpyGlass Lint** | Coding-style, synthesis-compatibility, and structural checks |
| **SpyGlass CDC** | Clock Domain Crossing analysis |
| **SpyGlass RDC** | Reset Domain Crossing analysis |
| **SpyGlass DFT** | Design-for-Test rule checking |
| **SpyGlass Power** | Power-intent (UPF/CPF) checking |
| **SpyGlass Constraints** | SDC constraint validation |

This tutorial focuses on **Lint** and **CDC**.

### Typical SpyGlass Flow

```
RTL Source Files (.v / .sv)
        |
        v
  +-----------+     +------------------+
  | SpyGlass  |<----|  Project File     |
  | Engine    |     |  (.prj / .sgdc)   |
  +-----------+     +------------------+
        |
        v
  +------------------+
  | Violation Report |
  | (HTML / Text)    |
  +------------------+
        |
        v
  Fix / Waive / Review
```

---

## 2. SpyGlass Lint

### 2.1 Why Lint Matters

Lint catches problems that a simulator silently tolerates but that cause failures in synthesis, timing closure, or silicon:

- Undriven / unloaded signals (wasted area)
- Incomplete sensitivity lists (simulation/synthesis mismatch)
- Inferred latches (unintended state elements)
- Width mismatches (silent truncation/extension)
- Combinational loops (oscillation risk)
- Non-synthesizable constructs

Catching these issues early reduces ECO cost significantly.

### 2.2 Rule Categories

SpyGlass Lint organizes rules into **rule groups**:

| Rule Group | Prefix | Description |
|------------|--------|-------------|
| W (Warning) | `W_*` | General coding warnings |
| E (Error) | `E_*` | Hard errors (syntax, elaboration) |
| STARC | `STARC05-*` | STARC (Semiconductor Technology Academic Research Center) guidelines |
| Naming | `NamingConv-*` | Signal/module naming conventions |
| Synthesis | `SynthCheck-*` | Synthesis compatibility |
| Simulation | `SimCheck-*` | Simulation behaviour issues |
| Array | `Array-*` | Array/memory modelling checks |

### 2.3 Running a Lint Session

#### Interactive (GUI)

```bash
spyglass -project my_design.prj &
```

Then select **Lint** goal from the Goal pane and click **Run**.

#### Batch Mode (Recommended for CI)

```bash
spyglass -batch -project my_design.prj \
         -goal lint/lint_rtl           \
         -report_file lint_report.rpt
```

Or using a **Tcl-based** flow:

```tcl
# run_lint.tcl
read_file -type verilog {rtl/my_module.v rtl/top.v}
set_option top my_top
current_goal lint/lint_rtl
run_goal
save_report -file lint_report.rpt
exit
```

```bash
spyglass -tcl run_lint.tcl
```

See [`scripts/run_lint.tcl`](scripts/run_lint.tcl) for a complete example.

### 2.4 Common Lint Violations with Examples

Each violation below links to a full source file in the [`examples/lint/`](examples/lint/) directory.

#### 2.4.1 W_164 -- Undriven Input Port

A module instance has an input port that is not connected.

```verilog
// Bad: port 'cfg' left floating
my_block u_blk (
    .clk  (clk),
    .din  (data),
    .cfg  ()          // W_164
);
```

**Fix:** Connect the port or explicitly tie off:

```verilog
my_block u_blk (
    .clk  (clk),
    .din  (data),
    .cfg  (1'b0)      // explicit tie-off
);
```

#### 2.4.2 W_116 -- Conditional Expression Width Mismatch

Operands of a ternary have different widths, causing implicit extension.

```verilog
wire [7:0] a;
wire [3:0] b;
wire [7:0] result = sel ? a : b;  // W_116: b zero-extended silently
```

**Fix:** Explicit extension:

```verilog
wire [7:0] result = sel ? a : {4'b0, b};
```

#### 2.4.3 W_391 -- Inferred Latch

An incomplete `case` or `if-else` in a combinational `always` block infers a latch.

```verilog
always @(*) begin
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
        // missing 2'b10, 2'b11 -> latch on 'out'  (W_391)
    endcase
end
```

**Fix:** Add `default`:

```verilog
always @(*) begin
    case (sel)
        2'b00:   out = a;
        2'b01:   out = b;
        default: out = '0;
    endcase
end
```

#### 2.4.4 W_446 -- Signal Read but Never Assigned

```verilog
module bad_example (input clk, output reg [7:0] dout);
    reg [7:0] temp;    // never assigned -> W_446
    always @(posedge clk)
        dout <= temp;
endmodule
```

#### 2.4.5 W_528 -- Combinational Loop

```verilog
assign a = b & c;
assign b = a | d;   // combinational loop: a -> b -> a  (W_528)
```

See the full example files in [`examples/lint/`](examples/lint/) for before/after code.

### 2.5 Fixing Lint Violations

General strategy:

1. **Sort by severity** -- Fix Errors first, then Warnings.
2. **Fix structurally** -- Prefer code changes over waivers.
3. **Batch related violations** -- One root cause often triggers multiple messages.
4. **Re-run after fixes** -- Validate that the count drops to zero (or waivers-only).

### 2.6 Waivers

When a violation is intentional, suppress it with a **waiver**:

```tcl
# waivers/lint_waivers.swl
waiver -rule W_164 -module "debug_port" \
       -comment "Debug port intentionally left unconnected in production mode"

waiver -rule W_446 -signal "spare_*" \
       -comment "Spare signals reserved for ECO"
```

Load waivers in the project file:

```tcl
read_file -type waiver waivers/lint_waivers.swl
```

---

## 3. SpyGlass CDC

### 3.1 Why CDC Matters

Modern SoCs contain dozens of clock domains. Any signal that crosses from one domain to another risks:

- **Metastability** -- The receiving flip-flop samples during a setup/hold window and enters an unpredictable state.
- **Data corruption** -- Multi-bit buses sampled at different edges can produce garbage values.
- **Data loss** -- A short pulse in the source domain may be missed entirely by the destination domain.

CDC bugs are *extremely* hard to find in simulation because metastability events are non-deterministic. SpyGlass CDC performs **static structural analysis** to find every crossing and verify that proper synchronization exists.

### 3.2 CDC Fundamentals

#### Clock Domains

A **clock domain** is the set of all flip-flops clocked by the same clock (or phase-related clocks). Two clocks are in the *same domain* if they are:
- The same signal, or
- Generated from the same source with a known, fixed phase relationship.

Otherwise they are in *different domains*, and any signal travelling between them is a **CDC path**.

#### Synchronization Schemes

| Pattern | Use Case | Latency |
|---------|----------|---------|
| 2-FF Synchronizer | Single-bit signals | 2 destination-clock cycles |
| 3-FF Synchronizer | High-frequency or high-MTBF requirements | 3 cycles |
| Gray-code + 2-FF | Multi-bit counters (FIFO pointers) | 2 cycles |
| MUX-based (Qualifier) | Multi-bit data with enable/valid | 1 cycle after qualifier is sync'd |
| Handshake (req/ack) | Infrequent, multi-bit data | Several cycles |
| Async FIFO | Streaming data between domains | Pointer sync delay |
| Pulse Synchronizer | Single-cycle pulses | 2-3 destination-clock cycles |

### 3.3 Running a CDC Session

#### Batch Mode

```bash
spyglass -batch -project my_design.prj \
         -goal cdc/cdc_verify           \
         -sgdc constraints/cdc.sgdc     \
         -report_file cdc_report.rpt
```

#### Tcl Flow

```tcl
# run_cdc.tcl
read_file -type verilog {rtl/top.v rtl/sync_ff.v rtl/async_fifo.v}
read_file -type sgdc    constraints/cdc.sgdc
set_option top my_top
current_goal cdc/cdc_verify
run_goal
save_report -file cdc_report.rpt
exit
```

See [`scripts/run_cdc.tcl`](scripts/run_cdc.tcl) for a complete example.

### 3.4 CDC Constraint Files (SGDC)

SpyGlass needs to know the clock structure. This is specified in an **SGDC** (SpyGlass Design Constraint) file.

```tcl
# constraints/cdc.sgdc

# Define clocks
current_design top

# Primary clocks
clock -name clk_100  -period 10   [get_ports clk_100]
clock -name clk_200  -period 5    [get_ports clk_200]
clock -name clk_50   -period 20   [get_ports clk_50]

# Generated / divided clocks
clock -name clk_div2 -period 20 -source clk_100 \
      [get_pins u_clkdiv/clk_out]

# Asynchronous clock relationships (default is async)
clock_relationship -async clk_100 clk_200
clock_relationship -async clk_100 clk_50

# Synchronous clock relationship (share same source)
clock_relationship -sync  clk_100 clk_div2

# Quasi-static signals (treated as constants during CDC)
quasi_static -name cfg_mode [get_ports cfg_mode]

# Abstract CDC structures (tell SpyGlass this is already a synchronizer)
abstract -type cdc -from clk_100 -to clk_200 \
         -module async_fifo_wrapper
```

See [`constraints/cdc.sgdc`](constraints/cdc.sgdc) for a complete, annotated example.

### 3.5 Common CDC Issues with Examples

All example files are in [`examples/cdc/`](examples/cdc/).

#### 3.5.1 Ac_unsync01 -- Unsynchronized Single-Bit Crossing

The most common CDC violation. A signal from domain A directly drives a flip-flop in domain B with no synchronizer.

```verilog
// clk_a domain
always @(posedge clk_a)
    flag_a <= event_detected;

// clk_b domain -- VIOLATION: no synchronizer
always @(posedge clk_b)
    flag_b <= flag_a;   // Ac_unsync01
```

**Fix:** Insert a 2-FF synchronizer:

```verilog
reg flag_a_sync1, flag_a_sync2;
always @(posedge clk_b or negedge rst_b_n) begin
    if (!rst_b_n) begin
        flag_a_sync1 <= 1'b0;
        flag_a_sync2 <= 1'b0;
    end else begin
        flag_a_sync1 <= flag_a;
        flag_a_sync2 <= flag_a_sync1;
    end
end

assign flag_b = flag_a_sync2;  // safe to use in clk_b domain
```

#### 3.5.2 Ac_conv01 -- Convergence of CDC Signals

Two or more independently synchronized signals are combined in logic. If they arrive on different clock edges, the result can glitch.

```verilog
// Each bit synced independently
sync_2ff u_sync_a (.d(ctrl_a), .q(ctrl_a_sync), .clk(clk_dst));
sync_2ff u_sync_b (.d(ctrl_b), .q(ctrl_b_sync), .clk(clk_dst));

// Convergence -- bits may be from different source-clock edges
assign mode = {ctrl_b_sync, ctrl_a_sync};  // Ac_conv01
```

**Fix:** Use a MUX-based qualifier or handshake to transfer the bus atomically.

#### 3.5.3 Ac_glitch01 -- Combinational Logic Before Synchronizer

Glitch-prone logic feeds the synchronizer input. A glitch shorter than the destination clock period may be captured as a wrong value.

```verilog
// Combinational logic in source domain
assign flag_combo = (state == IDLE) & req;

// Glitch on flag_combo can be captured
sync_2ff u_sync (.d(flag_combo), .q(flag_sync), .clk(clk_dst));  // Ac_glitch01
```

**Fix:** Register the signal in the source domain before crossing:

```verilog
always @(posedge clk_src)
    flag_reg <= (state == IDLE) & req;

sync_2ff u_sync (.d(flag_reg), .q(flag_sync), .clk(clk_dst));  // clean
```

#### 3.5.4 Ac_multibit01 -- Multi-Bit CDC Without Gray Encoding

A multi-bit bus crosses domains without Gray encoding or a qualifier. Different bits may be sampled on different edges.

```verilog
// 4-bit counter crosses domains -- VIOLATION
always @(posedge clk_a)
    cnt_a <= cnt_a + 1;

sync_2ff #(.WIDTH(4)) u_sync (
    .d(cnt_a), .q(cnt_b), .clk(clk_b)  // Ac_multibit01
);
```

**Fix:** Convert to Gray code before crossing:

```verilog
wire [3:0] cnt_gray = cnt_a ^ (cnt_a >> 1);

sync_2ff #(.WIDTH(4)) u_sync (
    .d(cnt_gray), .q(cnt_gray_b), .clk(clk_b)
);

// Convert back to binary in destination domain
assign cnt_b = gray_to_bin(cnt_gray_b);
```

#### 3.5.5 Ac_resetSync -- Asynchronous Reset Not Synchronized

An asynchronous reset from one domain is applied directly to flip-flops in another domain without a reset synchronizer.

```verilog
// rst_a is released asynchronously to clk_b
always @(posedge clk_b or negedge rst_a)
    if (!rst_a) q <= 0;      // Ac_resetSync
    else        q <= d;
```

**Fix:** Use a reset synchronizer (assert asynchronously, deassert synchronously):

```verilog
reset_sync u_rst_sync (
    .clk      (clk_b),
    .rst_in_n (rst_a),
    .rst_out_n(rst_b_n)
);

always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n) q <= 0;
    else          q <= d;
```

### 3.6 Synchronizer Patterns

Complete, synthesizable synchronizer modules are provided in [`examples/cdc/synchronizers/`](examples/cdc/synchronizers/).

| File | Pattern |
|------|---------|
| `sync_2ff.sv` | Basic 2-FF synchronizer (single-bit) |
| `sync_pulse.sv` | Pulse synchronizer (toggle-based) |
| `sync_bus_mux.sv` | MUX-qualified bus synchronizer |
| `async_fifo.sv` | Asynchronous FIFO with Gray-coded pointers |
| `reset_sync.sv` | Asynchronous-assert, synchronous-deassert reset synchronizer |
| `handshake_sync.sv` | Req/Ack four-phase handshake |

### 3.7 CDC Waivers and Scheme Files

```tcl
# waivers/cdc_waivers.swl
waiver -rule Ac_unsync01 -from "u_jtag/tdi" -to "u_core/*" \
       -comment "JTAG TDI is quasi-static during functional mode"

waiver -rule Ac_conv01 -module "async_fifo" \
       -comment "Gray-coded pointers are never more than 1 bit apart"
```

---

## 4. SpyGlass Project Setup

A `.prj` file ties everything together:

```tcl
# my_design.prj
##----------------------------------------------
## Design Read-in
##----------------------------------------------
read_file -type verilog {
    rtl/top.v
    rtl/core.v
    rtl/peripherals.v
    rtl/sync_2ff.sv
    rtl/async_fifo.sv
}

##----------------------------------------------
## Top module
##----------------------------------------------
set_option top top

##----------------------------------------------
## Constraints
##----------------------------------------------
read_file -type sgdc constraints/cdc.sgdc

##----------------------------------------------
## Waivers
##----------------------------------------------
read_file -type waiver waivers/lint_waivers.swl
read_file -type waiver waivers/cdc_waivers.swl

##----------------------------------------------
## Options
##----------------------------------------------
set_option enableSV   yes       ;# enable SystemVerilog
set_option language_mode mixed  ;# allow Verilog + SystemVerilog
set_option mthresh     50000    ;# memory threshold (KB)
set_option sgsyn       yes      ;# enable synthesis semantics
```

See [`scripts/my_design.prj`](scripts/my_design.prj) for a ready-to-use template.

---

## 5. Interpreting Reports

SpyGlass generates reports in text and HTML. Each entry contains:

```
Rule      : W_391
Severity  : Warning
Module    : decoder
File      : rtl/decoder.v
Line      : 42
Message   : Latch inferred for signal 'out' due to incomplete
            case statement in combinational always block.
```

### Severity Levels

| Level | Meaning |
|-------|---------|
| **Fatal** | Cannot continue (file not found, syntax error) |
| **Error** | Design will not work correctly |
| **Warning** | Potential problem; review required |
| **Info** | Informational; usually safe to ignore |

### Report Tips

- Use `spyglass_reports/` output directory for HTML browsable reports.
- Sort by **rule** to find systemic issues.
- Sort by **module** to assign ownership.
- Use `sg_shell` interactively to query the violation database.

---

## 6. Best Practices

### Lint

1. Run Lint on every RTL commit (CI integration).
2. Start with `lint/lint_rtl` goal; add `lint/lint_rtl_enhanced` later.
3. Adopt a zero-warning policy for new code; grandfather legacy.
4. Use waivers *sparingly* and always include a comment.
5. Create a team coding standard that aligns with SpyGlass rules.

### CDC

1. Define *all* clocks and their relationships in the SGDC file.
2. Use `abstract` for pre-verified IP blocks to reduce noise.
3. Mark quasi-static signals (`quasi_static`) to avoid false positives.
4. Standardize on a library of synchronizer cells -- do not hand-code synchronizers inline.
5. Set `set_option sdc2sgdc yes` to import SDC constraints when available.
6. Run CDC before gate-level simulation to catch structural issues early.
7. Review the **CDC Matrix** (SpyGlass GUI) to get a domain-level overview.
8. Attribute flip-flops intended as synchronizers with `(* sync_cell *)` or equivalent synthesis attributes.

### CI Integration

```bash
#!/bin/bash
# ci_spyglass.sh -- exit non-zero if any Error-severity violation exists

spyglass -batch -project my_design.prj \
         -goal lint/lint_rtl \
         -goal cdc/cdc_verify \
         -report_file ci_report.rpt

if grep -q "^Error" ci_report.rpt; then
    echo "SpyGlass: ERRORS found -- failing build"
    exit 1
fi
echo "SpyGlass: PASS"
```

---

## 7. Repository Structure

```
.
├── README.md                        # This tutorial
├── constraints/
│   └── cdc.sgdc                     # CDC constraint file (annotated)
├── examples/
│   ├── lint/
│   │   ├── lint_violations.v        # Common Lint violations (before fix)
│   │   └── lint_violations_fixed.v  # Same design with fixes applied
│   └── cdc/
│       ├── cdc_violations.v         # Common CDC violations (before fix)
│       ├── cdc_violations_fixed.v   # Same design with fixes applied
│       └── synchronizers/
│           ├── sync_2ff.sv          # 2-FF synchronizer
│           ├── sync_pulse.sv        # Pulse synchronizer
│           ├── sync_bus_mux.sv      # MUX-qualified bus sync
│           ├── async_fifo.sv        # Async FIFO (Gray pointers)
│           ├── reset_sync.sv        # Reset synchronizer
│           └── handshake_sync.sv    # 4-phase handshake
├── scripts/
│   ├── my_design.prj               # SpyGlass project file template
│   ├── run_lint.tcl                 # Lint batch-run script
│   └── run_cdc.tcl                  # CDC batch-run script
└── waivers/
    ├── lint_waivers.swl             # Lint waiver examples
    └── cdc_waivers.swl              # CDC waiver examples
```

---

> **Disclaimer:** SpyGlass rule names and options may vary across tool versions. Consult the *SpyGlass Reference Manual* for your specific release.
