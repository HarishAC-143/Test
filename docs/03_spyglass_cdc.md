# Chapter 3: SpyGlass CDC — Deep Dive

## 3.1 What is Clock Domain Crossing?

A **Clock Domain Crossing (CDC)** occurs whenever a signal generated in one clock domain is sampled by a flip-flop in a different clock domain. If not handled properly, CDC paths lead to **metastability**, **data corruption**, and **system failures**.

```
    Clock Domain A (clk_a)          Clock Domain B (clk_b)
   ┌─────────────────────┐        ┌─────────────────────┐
   │                     │        │                     │
   │  ┌───┐    ┌───┐    │  CDC   │    ┌───┐    ┌───┐  │
   │  │ FF├────┤ FF├────────────────►──┤ FF├────┤ FF│  │
   │  └───┘    └───┘    │ Path   │    └───┘    └───┘  │
   │                     │        │                     │
   └─────────────────────┘        └─────────────────────┘
```

### Why is CDC Dangerous?

When a flip-flop samples a signal that changes too close to its setup or hold time, the output can enter a **metastable state** — an undefined voltage level between 0 and 1. This can:

1. Propagate incorrect values downstream
2. Cause different parts of the design to see different values
3. Lead to system hangs or data corruption

### Types of Clock Relationships

| Relationship | Description | CDC Required? |
|-------------|-------------|---------------|
| Synchronous | Clocks derived from the same source, integer ratio | Sometimes (depends on phase) |
| Asynchronous | Clocks from independent sources | Always |
| Same clock, different phase | Same frequency, phase offset | Depends on timing |

## 3.2 CDC Synchronization Techniques

### 3.2.1 Two-Flop Synchronizer (Single-Bit Signals)

The simplest and most common synchronizer for single-bit signals:

```verilog
module two_ff_sync (
    input  wire clk_b,      // Destination clock
    input  wire rst_b_n,    // Destination reset
    input  wire data_in,    // From clock domain A
    output wire data_out    // Synchronized to clock domain B
);
    reg sync_ff1, sync_ff2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= data_in;    // First stage catches metastability
            sync_ff2 <= sync_ff1;   // Second stage resolves it
        end
    end

    assign data_out = sync_ff2;
endmodule
```

**Key design rules:**
- No combinational logic between the two synchronizer flops
- The synchronizer flops should be placed close together (synthesis constraint)
- Only works for **single-bit** signals
- Requires the input signal to be stable for at least one full destination clock cycle

### 3.2.2 Multi-Bit Synchronization — Gray Code

For multi-bit values (like FIFO pointers), use **Gray code** encoding where only one bit changes at a time:

```verilog
// Binary to Gray code conversion
function [WIDTH-1:0] bin2gray(input [WIDTH-1:0] bin);
    bin2gray = bin ^ (bin >> 1);
endfunction

// Gray code to binary conversion
function [WIDTH-1:0] gray2bin(input [WIDTH-1:0] gray);
    integer i;
    begin
        gray2bin[WIDTH-1] = gray[WIDTH-1];
        for (i = WIDTH-2; i >= 0; i = i - 1)
            gray2bin[i] = gray2bin[i+1] ^ gray[i];
    end
endfunction
```

### 3.2.3 Pulse Synchronizer

When you need to transfer a single-cycle pulse across clock domains:

```
Domain A (fast)              Domain B (slow)
                              
  pulse_in ──► Toggle FF ──► 2-FF Sync ──► Edge Detect ──► pulse_out
                              
  One pulse     Toggles       Synced        Detects
  input         level         toggle        edges
```

### 3.2.4 Handshake Synchronizer

For transferring multi-bit data that changes infrequently:

```
Domain A                          Domain B

  data ──────────────────────────────► data_out
            held stable while          (sampled when ack received)
            handshake completes
                                       
  req  ──► 2-FF Sync ───────────────► req_synced
                                       │
  ack_synced ◄── 2-FF Sync ◄──────── ack
```

### 3.2.5 Asynchronous FIFO

The gold standard for high-throughput CDC — uses dual-port RAM with Gray-coded pointers:

```
     Write Domain (clk_w)       Read Domain (clk_r)
    ┌────────────────────┐     ┌────────────────────┐
    │  wr_ptr (binary)   │     │  rd_ptr (binary)   │
    │       │            │     │       │            │
    │       ▼            │     │       ▼            │
    │  bin2gray          │     │  bin2gray          │
    │       │            │     │       │            │
    │  wr_ptr_gray ──────────────► 2-FF sync        │
    │       │            │     │       │            │
    │  2-FF sync ◄───────────────── rd_ptr_gray     │
    │       │            │     │       │            │
    │  full logic        │     │  empty logic       │
    └────────────────────┘     └────────────────────┘
              │                          │
              ▼                          ▼
         ┌────────────────────────────────────┐
         │         Dual-Port RAM              │
         └────────────────────────────────────┘
```

## 3.3 SpyGlass CDC Rules

### Structural CDC Rules

These rules check the physical structure of CDC paths:

| Rule | Description | Severity |
|------|-------------|----------|
| `Ac_cdc01` | No synchronizer on CDC path | Error |
| `Ac_cdc02` | Combinational logic before synchronizer | Warning |
| `Ac_cdc03` | Multi-bit CDC without proper scheme | Error |
| `Ac_cdc04` | Reconvergent CDC paths | Warning |
| `Ac_cdc05` | Synchronizer with fan-out > 1 before second stage | Error |
| `Ac_cdc06` | Clock used as data on CDC path | Warning |
| `Ac_cdc07` | Reset used as data on CDC path | Warning |

### Reconvergence Rules

| Rule | Description |
|------|-------------|
| `Ac_conv01` | Reconvergent CDC paths — same source, multiple syncs, reconverge in destination |
| `Ac_conv02` | Potential data coherency issue due to reconvergence |

### Protocol Rules

| Rule | Description |
|------|-------------|
| `Ac_protocol01` | FIFO pointer crossing without Gray code |
| `Ac_protocol02` | Handshake protocol violation |
| `Ac_protocol03` | Pulse too narrow for destination clock |

## 3.4 SGDC Constraint File

SpyGlass CDC requires constraints to understand the clock architecture. These are specified in **SGDC** (SpyGlass Design Constraint) files.

### Clock Definitions

```tcl
# clock_definitions.sgdc

# Define primary clocks
current_design top_module

# Asynchronous clocks — independent sources
create_clock -name clk_sys   -period 10  [get_ports clk_sys]
create_clock -name clk_pcie  -period  4  [get_ports clk_pcie]
create_clock -name clk_usb   -period 20  [get_ports clk_usb]

# These clocks are asynchronous to each other
set_clock_groups -asynchronous \
    -group {clk_sys} \
    -group {clk_pcie} \
    -group {clk_usb}
```

### Reset Definitions

```tcl
# Reset constraints
reset -name rst_sys_n   -value 0 [get_ports rst_sys_n]
reset -name rst_pcie_n  -value 0 [get_ports rst_pcie_n]
```

### CDC Constraints

```tcl
# Specify known-good synchronizers (quasi-static signals)
cdc_false_path -from [get_cells cfg_reg*] -to [get_cells sync_cfg*]

# Specify a synchronizer abstract
abstract -clock clk_b -type cdc -cell my_custom_sync

# Gray code specification
cdc_gray_encoding -from wr_ptr_gray -to rd_ptr_gray_sync
```

## 3.5 Common CDC Violations

### 3.5.1 Missing Synchronizer (Ac_cdc01)

**Problem:** A signal crosses clock domains with no synchronizer — guaranteed metastability.

```verilog
module missing_sync (
    input  wire clk_a,
    input  wire clk_b,
    input  wire data_a,
    output reg  data_b
);
    reg data_a_reg;

    always @(posedge clk_a)
        data_a_reg <= data_a;

    // Ac_cdc01: Direct crossing with no synchronizer!
    always @(posedge clk_b)
        data_b <= data_a_reg;
endmodule
```

**Fix:** Add a two-flop synchronizer:

```verilog
module missing_sync_fixed (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_b_n,
    input  wire data_a,
    output reg  data_b
);
    reg data_a_reg;
    reg sync_ff1, sync_ff2;

    always @(posedge clk_a)
        data_a_reg <= data_a;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= data_a_reg;
            sync_ff2 <= sync_ff1;
        end
    end

    assign data_b = sync_ff2;
endmodule
```

### 3.5.2 Multi-Bit CDC Without Gray Code (Ac_cdc03)

**Problem:** A multi-bit bus crosses clock domains using a simple two-flop synchronizer — different bits can be captured at different times.

```verilog
module multibit_cdc_bad (
    input  wire       clk_a,
    input  wire       clk_b,
    input  wire [3:0] counter_a,
    output reg  [3:0] counter_b
);
    reg [3:0] sync1, sync2;

    // Ac_cdc03: Multi-bit signal synchronized bit-by-bit!
    // If counter_a changes from 4'b0111 to 4'b1000,
    // sync1 might capture 4'b1111 or 4'b0000 — glitch!
    always @(posedge clk_b) begin
        sync1 <= counter_a;
        sync2 <= sync1;
    end

    assign counter_b = sync2;
endmodule
```

**Fix:** Use Gray code encoding:

```verilog
module multibit_cdc_fixed (
    input  wire       clk_a,
    input  wire       clk_b,
    input  wire       rst_b_n,
    input  wire [3:0] counter_a,
    output wire [3:0] counter_b
);
    wire [3:0] gray_a = counter_a ^ (counter_a >> 1);  // Binary to Gray

    reg [3:0] sync1, sync2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1 <= 4'b0;
            sync2 <= 4'b0;
        end else begin
            sync1 <= gray_a;
            sync2 <= sync1;
        end
    end

    // Gray to binary conversion
    assign counter_b[3] = sync2[3];
    assign counter_b[2] = sync2[3] ^ sync2[2];
    assign counter_b[1] = sync2[3] ^ sync2[2] ^ sync2[1];
    assign counter_b[0] = sync2[3] ^ sync2[2] ^ sync2[1] ^ sync2[0];
endmodule
```

### 3.5.3 Combinational Logic Before Synchronizer (Ac_cdc02)

**Problem:** Combinational logic between the source flop and the synchronizer input can produce glitches that the synchronizer captures.

```verilog
module combo_before_sync (
    input  wire clk_a,
    input  wire clk_b,
    input  wire sig_a1,
    input  wire sig_a2,
    output reg  synced_out
);
    reg reg_a1, reg_a2;
    reg sync1, sync2;

    always @(posedge clk_a) begin
        reg_a1 <= sig_a1;
        reg_a2 <= sig_a2;
    end

    // Ac_cdc02: Combinational logic (AND gate) before synchronizer
    // If reg_a1 and reg_a2 change at different times,
    // the AND output can glitch
    wire combo_result = reg_a1 & reg_a2;

    always @(posedge clk_b) begin
        sync1 <= combo_result;  // May capture glitch!
        sync2 <= sync1;
    end

    assign synced_out = sync2;
endmodule
```

**Fix:** Register the combined result in the source domain first:

```verilog
module combo_before_sync_fixed (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_b_n,
    input  wire sig_a1,
    input  wire sig_a2,
    output reg  synced_out
);
    reg combo_reg_a;
    reg sync1, sync2;

    always @(posedge clk_a)
        combo_reg_a <= sig_a1 & sig_a2;  // Register in source domain

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= combo_reg_a;  // Clean registered signal
            sync2 <= sync1;
        end
    end

    assign synced_out = sync2;
endmodule
```

### 3.5.4 Reconvergent CDC Paths (Ac_conv01)

**Problem:** Two signals from the same source domain cross to the destination through separate synchronizers, then reconverge in combinational logic. The synchronizers may resolve at different cycles, creating a window of inconsistency.

```verilog
module reconvergence_bad (
    input  wire clk_a,
    input  wire clk_b,
    input  wire enable_a,
    input  wire mode_a,
    output wire result_b
);
    reg enable_a_reg, mode_a_reg;

    always @(posedge clk_a) begin
        enable_a_reg <= enable_a;
        mode_a_reg   <= mode_a;
    end

    // Two separate synchronizers
    reg en_sync1, en_sync2;
    reg mode_sync1, mode_sync2;

    always @(posedge clk_b) begin
        en_sync1   <= enable_a_reg;
        en_sync2   <= en_sync1;
        mode_sync1 <= mode_a_reg;
        mode_sync2 <= mode_sync1;
    end

    // Ac_conv01: Reconvergence!
    // en_sync2 and mode_sync2 may settle on different clock cycles
    assign result_b = en_sync2 & mode_sync2;
endmodule
```

**Fix:** Use a handshake or combine signals before crossing:

```verilog
module reconvergence_fixed (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_b_n,
    input  wire enable_a,
    input  wire mode_a,
    output wire result_b
);
    // Combine in source domain, then cross a single control signal
    reg combined_a;

    always @(posedge clk_a)
        combined_a <= enable_a & mode_a;

    reg sync1, sync2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= combined_a;
            sync2 <= sync1;
        end
    end

    assign result_b = sync2;
endmodule
```

## 3.6 CDC Verification Flow

```
 ┌──────────────────────────────────────────────────────────────┐
 │                   SpyGlass CDC Flow                         │
 │                                                              │
 │  1. Read RTL files                                          │
 │  2. Read SGDC constraints (clocks, resets, abstracts)       │
 │  3. Run cdc/cdc_verify_struct (structural checks)           │
 │  4. Review & fix structural violations                      │
 │  5. Run cdc/cdc_verify (full CDC with protocol checks)      │
 │  6. Apply waivers for intentional violations                │
 │  7. Achieve clean CDC report                                │
 └──────────────────────────────────────────────────────────────┘
```

## 3.7 Practical Example Files

See the example RTL files in this repository:

| File | Purpose |
|------|---------|
| [`examples/cdc/rtl/cdc_sync_examples.v`](../examples/cdc/rtl/cdc_sync_examples.v) | Synchronizer building blocks |
| [`examples/cdc/rtl/async_fifo.v`](../examples/cdc/rtl/async_fifo.v) | Complete async FIFO with Gray code |
| [`examples/cdc/rtl/pulse_synchronizer.v`](../examples/cdc/rtl/pulse_synchronizer.v) | Pulse transfer across domains |
| [`examples/cdc/rtl/handshake_sync.v`](../examples/cdc/rtl/handshake_sync.v) | Handshake protocol |
| [`examples/cdc/rtl/cdc_violations.v`](../examples/cdc/rtl/cdc_violations.v) | Intentional violations for learning |
| [`examples/cdc/constraints/cdc_constraints.sgdc`](../examples/cdc/constraints/cdc_constraints.sgdc) | CDC constraint file |

## 3.8 Next Steps

- [Chapter 4: Practical Workflow](04_practical_workflow.md) — Run SpyGlass end-to-end.
- [Chapter 5: Advanced Topics](05_advanced_topics.md) — Waivers, regression, hierarchical flows.
