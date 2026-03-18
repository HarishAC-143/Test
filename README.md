# Advanced Digital System Design: RTL Implementation with SystemVerilog

A comprehensive, hands-on tutorial covering advanced RTL design techniques using SystemVerilog. Each chapter pairs theory with production-quality, synthesizable code examples you can simulate, synthesize, and adapt for real projects.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Parameterized Designs & Generate Statements](#2-parameterized-designs--generate-statements)
3. [Advanced Finite State Machines](#3-advanced-finite-state-machines)
4. [Pipeline Architectures](#4-pipeline-architectures)
5. [FIFO Design (Synchronous & Asynchronous)](#5-fifo-design-synchronous--asynchronous)
6. [Arbiter Design](#6-arbiter-design)
7. [Memory Controllers](#7-memory-controllers)
8. [Bus Interfaces (AXI4-Lite)](#8-bus-interfaces-axi4-lite)
9. [Clock Domain Crossing (CDC)](#9-clock-domain-crossing-cdc)
10. [Error Detection & Correction](#10-error-detection--correction)
11. [DSP Blocks](#11-dsp-blocks)
12. [Advanced Datapaths](#12-advanced-datapaths)
13. [Design Best Practices](#13-design-best-practices)
14. [Appendix: SystemVerilog Constructs Quick Reference](#14-appendix-systemverilog-constructs-quick-reference)

---

## 1. Introduction

### What is RTL Design?

**Register-Transfer Level (RTL)** design describes digital hardware as a collection of registers and the combinational logic that transforms data between them. RTL is the primary abstraction level used in ASIC and FPGA design — it is low enough to reason about timing and area, yet high enough to express complex behavior concisely.

### Why SystemVerilog?

SystemVerilog extends Verilog with:

- **Strongly typed constructs**: `logic`, `typedef`, `enum`, `struct`, `union`
- **Parameterized designs**: `parameter`, `localparam`, `generate`
- **Interfaces and modports** for clean port abstraction
- **Assertions (`assert`, `cover`, `assume`)** for formal verification
- **Packages** for reusable type and function libraries

### Repository Structure

```
examples/
├── 01_parameterized_designs/      Configurable ALU, Crossbar switch
├── 02_advanced_fsm/               SPI controller, Traffic light FSM
├── 03_pipeline_architecture/      MAC pipeline, 5-stage instruction pipeline
├── 04_fifo_design/                Synchronous FIFO, Asynchronous FIFO
├── 05_arbiter_design/             Round-robin arbiter, Weighted priority arbiter
├── 06_memory_controller/          SRAM controller with burst support
├── 07_bus_interfaces/             AXI4-Lite slave with register bank
├── 08_clock_domain_crossing/      2-FF sync, pulse sync, handshake, bus sync
├── 09_error_detection_correction/ Hamming SEC-DED, CRC-32 engine
├── 10_dsp_blocks/                 FIR filter, CORDIC engine
└── 11_advanced_datapath/          Ternary CAM, Systolic array multiplier
```

---

## 2. Parameterized Designs & Generate Statements

> **Source**: [`examples/01_parameterized_designs/`](examples/01_parameterized_designs/)

### Concept

Parameterized design is the cornerstone of reusable RTL. Instead of writing a fixed-width ALU or a specific-size crossbar, you make the design **configurable at elaboration time** using `parameter` and `generate` constructs.

### Key SystemVerilog Constructs

| Construct | Purpose |
|-----------|---------|
| `parameter` | Module-level constants overridable by the instantiator |
| `localparam` | Derived constants computed from parameters (not overridable) |
| `generate for` | Replicate hardware structure N times |
| `generate if` | Conditionally include/exclude hardware blocks |
| `$clog2()` | Compute minimum bit-width for a given depth |

### Example 1: Configurable ALU

The ALU in [`configurable_alu.sv`](examples/01_parameterized_designs/configurable_alu.sv) demonstrates:

```systemverilog
module configurable_alu #(
    parameter int DATA_WIDTH   = 32,
    parameter bit ENABLE_MUL   = 1,    // Conditionally include multiplier
    parameter bit ENABLE_SHIFT = 1     // Conditionally include barrel shifter
)(
    input  logic [DATA_WIDTH-1:0]   operand_a,
    input  logic [DATA_WIDTH-1:0]   operand_b,
    ...
);
    localparam int SHIFT_BITS = $clog2(DATA_WIDTH);  // Derived automatically
```

**Key design decisions:**

- **`parameter bit ENABLE_MUL`**: When `0`, the synthesizer removes all multiply logic, saving significant area on resource-constrained FPGAs.
- **Packed struct for flags**: Groups `zero`, `negative`, `carry`, and `overflow` into a single signal that can be passed atomically.
- **`typedef enum`**: Makes operation codes self-documenting and catches illegal values at simulation time.

**Instantiation with different configurations:**

```systemverilog
// Full-featured 32-bit ALU
configurable_alu #(.DATA_WIDTH(32), .ENABLE_MUL(1), .ENABLE_SHIFT(1)) u_alu_full (...);

// Lightweight 8-bit ALU without multiply (for area-constrained designs)
configurable_alu #(.DATA_WIDTH(8), .ENABLE_MUL(0), .ENABLE_SHIFT(0)) u_alu_lite (...);
```

### Example 2: Parameterized Crossbar Switch

The crossbar in [`generate_crossbar.sv`](examples/01_parameterized_designs/generate_crossbar.sv) uses `generate for` to create an N-master x M-slave interconnect:

```systemverilog
generate
    for (genvar s = 0; s < NUM_SLAVES; s++) begin : gen_arbiter
        round_robin_arbiter #(
            .NUM_REQUESTORS(NUM_MASTERS)
        ) u_arb (
            .clk     (clk),
            .rst_n   (rst_n),
            .request (request[s]),
            .grant   (grant[s])
        );
    end
endgenerate
```

**What happens at elaboration:**

For a 4x4 crossbar, the synthesizer unrolls this into four independent arbiter instances, each with its own request/grant vectors. The `generate` block creates named scopes (`gen_arbiter[0]`, `gen_arbiter[1]`, etc.) that appear in the hierarchy for debugging.

---

## 3. Advanced Finite State Machines

> **Source**: [`examples/02_advanced_fsm/`](examples/02_advanced_fsm/)

### FSM Encoding Strategies

| Encoding | States | Flip-Flops | Speed | Area |
|----------|--------|------------|-------|------|
| Binary | N | log2(N) | Medium | Small |
| One-Hot | N | N | Fast | Large |
| Gray | N | log2(N) | Medium | Small |

### Example: SPI Master Controller

The [`protocol_controller_fsm.sv`](examples/02_advanced_fsm/protocol_controller_fsm.sv) implements a complete SPI master with one-hot encoding:

```systemverilog
typedef enum logic [4:0] {
    S_IDLE     = 5'b00001,
    S_CS_SETUP = 5'b00010,
    S_TRANSFER = 5'b00100,
    S_CS_HOLD  = 5'b01000,
    S_DONE     = 5'b10000
} spi_state_t;
```

**Why one-hot encoding?**

Each state occupies exactly one flip-flop. The next-state decode logic becomes a simple OR of a few inputs rather than a complex binary decode tree. This trades flip-flops for reduced combinational depth, which is advantageous in high-frequency designs.

**FSM Architecture — Three-Block Pattern:**

```
┌─────────────────────────────────────────────────┐
│  always_comb (next-state logic)                 │
│  ┌─────────────┐    ┌────────────────────────┐  │
│  │ Current     │───>│ Combinational logic    │  │
│  │ State       │    │ computing next_state   │  │
│  └─────────────┘    └──────────┬─────────────┘  │
│                                │                │
│  always_ff (state register)    │                │
│  ┌─────────────┐    ┌─────────▼──────────────┐  │
│  │ next_state  │───>│ D-FF (clk, rst_n)      │──┤
│  └─────────────┘    └────────────────────────┘  │
│                                                 │
│  assign / always_comb (output decode)           │
│  ┌─────────────┐    ┌────────────────────────┐  │
│  │ State       │───>│ Output logic           │──┤─> Module outputs
│  └─────────────┘    └────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

**SPI Timing Diagram:**

```
IDLE ──> CS_SETUP ──> TRANSFER (N bits) ──> CS_HOLD ──> DONE ──> IDLE
          ┆  setup    ┆ shift out/in       ┆  hold    ┆
CS_N  ────┘           │                    │          └──────
SCLK  ────────────────┘ ∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿ └──────────────
MOSI  ────────────────── D7 D6 D5 ... D0 ───────────────
```

### Example: Traffic Light Controller

The [`traffic_light_fsm.sv`](examples/02_advanced_fsm/traffic_light_fsm.sv) demonstrates:

- **Timer-based transitions**: States advance when a countdown timer expires
- **Latched inputs**: Pedestrian request is captured and held until served
- **Emergency override**: Immediately forces all-red from any state
- **Packed struct outputs**: `light_state_t` bundles red/yellow/green into one signal

---

## 4. Pipeline Architectures

> **Source**: [`examples/03_pipeline_architecture/`](examples/03_pipeline_architecture/)

### Why Pipelining?

Pipelining divides a long combinational path into shorter stages separated by registers. This:

1. **Increases clock frequency** — each stage has less combinational delay
2. **Increases throughput** — one result per clock after the pipeline fills
3. **Introduces latency** — results appear N cycles after input (N = pipeline depth)

```
Without pipeline:     With 3-stage pipeline:
┌──────────────┐      ┌────┐ ┌────┐ ┌────┐
│ Long comb.   │      │ S1 │→│ S2 │→│ S3 │
│ path (slow)  │      │    │ │    │ │    │
└──────────────┘      └────┘ └────┘ └────┘
Tclk = Tcomb          Tclk = Tcomb/3 + Tsetup
```

### Example: Pipelined MAC Unit

The [`pipelined_multiply_accumulate.sv`](examples/03_pipeline_architecture/pipelined_multiply_accumulate.sv) implements a 3-stage MAC:

```
Stage 1: Input Registration    Stage 2: Multiplication    Stage 3: Accumulation
┌──────────────────┐          ┌──────────────────┐       ┌──────────────────┐
│ operand_a ──> s1_a│         │ s1_a * s1_b      │       │ acc += product   │
│ operand_b ──> s1_b│ ──FF──> │ = s2_product     │──FF──>│ = accumulator    │
│ valid ──> s1_valid│         │                  │       │                  │
└──────────────────┘          └──────────────────┘       └──────────────────┘
```

**Pipeline control signals:**

- **`stall`**: Freezes all pipeline registers (back-pressure from downstream)
- **`flush`**: Clears all pipeline stages (branch misprediction, exception)
- **`valid` propagation**: Each stage carries a valid bit so downstream logic knows when data is meaningful

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
        s2_product <= '0;
        s2_valid   <= 1'b0;
    end else if (!stall) begin
        s2_product <= $signed(s1_a) * $signed(s1_b);
        s2_valid   <= s1_valid;
    end
    // When stall is active, registers hold their values
end
```

### Example: 5-Stage Instruction Pipeline

The [`instruction_pipeline.sv`](examples/03_pipeline_architecture/instruction_pipeline.sv) implements a simplified RISC processor with:

- **IF → ID → EX → MEM → WB** stages
- **Data forwarding** (bypassing) from EX/MEM and MEM/WB to ID stage
- **Hazard detection** for load-use dependencies (inserts pipeline bubbles)
- **Pipeline flush** on taken branches

**Data Forwarding Path:**

```
                    ┌──────── Forward from EX/MEM ─────────┐
                    │         ┌── Forward from MEM/WB ──┐  │
                    ▼         ▼                          │  │
┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌─────┐            │  │
│ IF │──>│ ID │──>│ EX │──>│MEM │──>│ WB  │            │  │
└────┘   └──┬─┘   └──┬─┘   └──┬─┘   └──┬──┘            │  │
            │        │        └────────────────────────┘  │
            │        └───────────────────────────────────┘
            │
         Read Reg File
```

---

## 5. FIFO Design (Synchronous & Asynchronous)

> **Source**: [`examples/04_fifo_design/`](examples/04_fifo_design/)

FIFOs are the most fundamental building block for buffering, rate-matching, and clock-domain crossing in digital systems.

### Synchronous FIFO

The [`sync_fifo.sv`](examples/04_fifo_design/sync_fifo.sv) operates in a single clock domain:

```
          ┌─────────────────────────┐
wr_en ───>│                         │──> full
wr_data ─>│   Dual-Port Memory     │──> almost_full
          │   ┌─────────────────┐   │
          │   │  [0]  [1] ... [N]│  │
          │   └─────────────────┘   │
          │   wr_ptr ──>  <── rd_ptr│
rd_en ───>│                         │──> empty
          │                         │──> almost_empty
          └────────────┬────────────┘
                       └──> rd_data
```

**Key design details:**

- **Extra pointer bit**: Write and read pointers are `$clog2(DEPTH)+1` bits wide. The MSB distinguishes "full" from "empty" — both conditions have equal pointer values, but the MSBs differ when full.
- **Overflow/underflow detection**: Asserted for one cycle when a write to a full FIFO or read from an empty FIFO is attempted.
- **Almost-full/almost-empty**: Configurable thresholds for flow-control hysteresis.

### Asynchronous FIFO (Dual-Clock)

The [`async_fifo.sv`](examples/04_fifo_design/async_fifo.sv) safely transfers data between two independent clock domains:

```
wr_clk domain                          rd_clk domain
┌───────────────────┐                  ┌───────────────────┐
│ wr_ptr (binary)   │                  │ rd_ptr (binary)   │
│    ↓               │                  │    ↓               │
│ wr_ptr (Gray)  ───┼──── 2-FF sync ──┼→ wr_ptr_gray_sync │
│                    │                  │                    │
│ rd_ptr_gray_sync ←┼──── 2-FF sync ──┼── rd_ptr (Gray)   │
│    ↓               │                  │    ↓               │
│ FULL = compare    │                  │ EMPTY = compare   │
└───────────────────┘                  └───────────────────┘
```

**Why Gray Code?**

Binary counters can have multiple bits changing simultaneously (e.g., `0111 → 1000`). If a synchronizer samples mid-transition, it could read a completely wrong value. Gray code guarantees only one bit changes per increment, so the worst case is reading the old value (safe) or the new value (also safe).

```systemverilog
function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
    return bin ^ (bin >> 1);
endfunction
```

**Full/Empty conditions in Gray code:**

- **Empty**: `rd_ptr_gray == wr_ptr_gray_synced` (pointers are identical)
- **Full**: Top 2 bits differ, remaining bits match

---

## 6. Arbiter Design

> **Source**: [`examples/05_arbiter_design/`](examples/05_arbiter_design/)

Arbiters resolve contention when multiple masters compete for a shared resource.

### Round-Robin Arbiter

The [`round_robin_arbiter.sv`](examples/05_arbiter_design/round_robin_arbiter.sv) ensures fairness using a rotating priority mask:

```
Cycle 1: req = 1011, mask = 1111 → grant = 0001 (port 0)
Cycle 2: req = 1010, mask = 1110 → grant = 0010 (port 1)
Cycle 3: req = 1000, mask = 1100 → grant = 1000 (port 3)
Cycle 4: req = 1010, mask = 1111 → grant = 0010 (port 1, wrap)
```

**Lowest-set-bit trick for one-hot grant:**

```systemverilog
assign masked_lsb = masked_request & (~masked_request + 1'b1);
```

This classic bit-manipulation isolates the rightmost set bit in a single gate-level operation, producing a one-hot grant vector without explicit priority encoding loops.

**Grant holding** (optional): When `lock` is asserted by the granted port, the arbiter holds the current grant until the multi-cycle transaction completes, preventing mid-burst preemption.

### Weighted Priority Arbiter

The [`weighted_priority_arbiter.sv`](examples/05_arbiter_design/weighted_priority_arbiter.sv) provides **programmable bandwidth allocation**:

```
Port 0: weight = 4  → gets 4 grants per round (50%)
Port 1: weight = 2  → gets 2 grants per round (25%)
Port 2: weight = 1  → gets 1 grant per round  (12.5%)
Port 3: weight = 1  → gets 1 grant per round  (12.5%)
```

Each port has a credit counter initialized from its weight. A grant consumes one credit. When all eligible ports are exhausted, credits reload.

---

## 7. Memory Controllers

> **Source**: [`examples/06_memory_controller/`](examples/06_memory_controller/)

### SRAM Controller with Burst Support

The [`sram_controller.sv`](examples/06_memory_controller/sram_controller.sv) bridges a CPU-side interface to an external SRAM chip:

```
CPU Side                    Controller FSM              SRAM Side
┌──────────┐   ┌───────────────────────────┐   ┌──────────────┐
│ addr     │──>│ IDLE ──> SETUP ──> ACCESS │──>│ sram_addr    │
│ wr_data  │──>│   │                  │    │──>│ sram_data    │
│ rd_req   │──>│   │    wait states   │    │──>│ sram_ce_n    │
│ wr_req   │──>│   │                  ▼    │──>│ sram_oe_n    │
│          │   │   └─── BURST ──> DONE     │──>│ sram_we_n    │
│ rd_data  │<──│                           │   │ sram_be_n    │
│ ready    │<──│                           │   └──────────────┘
│ valid    │<──│                           │
└──────────┘   └───────────────────────────┘
```

**Design features:**

- **Configurable timing**: `READ_LATENCY` and `WRITE_LATENCY` parameters match the controller to different SRAM speed grades
- **Burst transfers**: Sequential address reads/writes without returning to IDLE
- **Tri-state data bus**: Controlled via `sram_data_oe` to avoid bus contention
- **Bank interleaving awareness**: Upper address bits select the active bank

---

## 8. Bus Interfaces (AXI4-Lite)

> **Source**: [`examples/07_bus_interfaces/`](examples/07_bus_interfaces/)

### AXI4-Lite Slave

The [`axi_lite_slave.sv`](examples/07_bus_interfaces/axi_lite_slave.sv) implements the AMBA AXI4-Lite protocol — the standard bus protocol used in ARM-based SoCs and Xilinx/Intel FPGAs.

**AXI4-Lite has five independent channels:**

```
          Write Address (AW)        Read Address (AR)
Master ──────────────────────>  ──────────────────────> Slave
          Write Data (W)
Master ──────────────────────>
          Write Response (B)        Read Data (R)
Master <──────────────────────  <────────────────────── Slave
```

**Each channel uses a valid/ready handshake:**

```
         ┌───┐       ┌───┐       ┌───┐
VALID ───┘   └───────┘   └───────┘   └───
         ┌───────┐           ┌───┐
READY ───┘       └───────────┘   └───────
              ↑ Transfer          ↑ Transfer
```

A transfer occurs on the clock edge where both `VALID` and `READY` are high.

**Write channel implementation:**

```systemverilog
case (wr_state)
    WR_IDLE: begin
        if (s_axi_awvalid) begin
            s_axi_awready   <= 1'b1;          // Accept address
            aw_addr_latched <= s_axi_awaddr;
            wr_state        <= WR_DATA;
        end
    end
    WR_DATA: begin
        s_axi_wready <= 1'b1;
        if (s_axi_wvalid) begin
            // Byte-lane write with strobe support
            for (int b = 0; b < DATA_WIDTH/8; b++) begin
                if (s_axi_wstrb[b])
                    registers[addr][b*8 +: 8] <= s_axi_wdata[b*8 +: 8];
            end
            wr_state <= WR_RESP;
        end
    end
    ...
endcase
```

**Write strobes** (`wstrb`) allow byte-granular writes to a word-sized register — essential for software compatibility where a CPU may write individual bytes.

---

## 9. Clock Domain Crossing (CDC)

> **Source**: [`examples/08_clock_domain_crossing/`](examples/08_clock_domain_crossing/)

CDC is one of the most error-prone areas in digital design. The [`cdc_synchronizers.sv`](examples/08_clock_domain_crossing/cdc_synchronizers.sv) provides a library of battle-tested CDC primitives.

### 1. Two-Flop Synchronizer

For single-bit, slowly changing signals:

```
src_clk domain          dest_clk domain
                    ┌────┐    ┌────┐
signal_src ────────>│ FF │───>│ FF │──> signal_dest
                    └────┘    └────┘
                    sync[0]   sync[1]
```

```systemverilog
(* async_reg = "true" *)    // Tells synthesis tool to place FFs close together
logic [NUM_STAGES-1:0] sync_chain;

always_ff @(posedge clk_dest or negedge rst_dest_n) begin
    if (!rst_dest_n)
        sync_chain <= {NUM_STAGES{RESET_VAL}};
    else
        sync_chain <= {sync_chain[NUM_STAGES-2:0], signal_src};
end
```

The `(* async_reg *)` attribute instructs place-and-route tools to minimize routing delay between the synchronizer flip-flops, maximizing MTBF (Mean Time Between Failures).

### 2. Pulse Synchronizer

Transfers a single-cycle pulse between domains by converting it to a level (toggle), synchronizing the level, then detecting edges:

```
src_clk: pulse ──> toggle register ──> ...
                                            (2-FF sync)
dest_clk: ... ──> synced_toggle ──> edge detect ──> pulse_dest
```

### 3. Handshake Synchronizer

For multi-bit data transfer, the handshake protocol ensures data stability:

```
1. Source captures data, asserts REQ
2. REQ synchronized to dest domain
3. Destination captures data, asserts ACK
4. ACK synchronized back to source
5. Source deasserts REQ, ready for next transfer
```

**Critical rule**: The data bus must remain stable from REQ assertion until ACK is received back. The handshake protocol guarantees this inherently.

### 4. Bus Synchronizer

Combines a data-hold register with a pulse synchronizer. The source holds data stable while a "load" pulse is synchronized to the destination domain, where it triggers data capture.

---

## 10. Error Detection & Correction

> **Source**: [`examples/09_error_detection_correction/`](examples/09_error_detection_correction/)

### Hamming SEC-DED Code

The [`hamming_ecc.sv`](examples/09_error_detection_correction/hamming_ecc.sv) implements Single Error Correction, Double Error Detection:

**Encoding:**

```
Data bits:   D7 D6 D5 D4 D3 D2 D1 D0
             ↓  ↓  ↓  ↓  ↓  ↓  ↓  ↓
Code word:   P  D7 D6 D5 D4 P3 D3 D2 D1 P2 D0 P1 P0
Position:    13 12 11 10  9  8  7  6  5  4  3  2  1
```

Parity bits occupy power-of-2 positions (1, 2, 4, 8). Each parity bit covers all positions whose binary representation has a `1` in the corresponding bit position.

**Decoding and correction:**

```systemverilog
// Compute syndrome (non-zero syndrome indicates error position)
for (int p = 0; p < PARITY_BITS; p++) begin
    syndrome[p] = 1'b0;
    for (int i = 0; i < CODE_BITS; i++) begin
        if ((i + 1) & (1 << p))
            syndrome[p] ^= code_word[i];
    end
end
```

| Syndrome | Overall Parity | Meaning |
|----------|---------------|---------|
| 0 | 0 | No error |
| Non-zero | 1 | Single-bit error at position `syndrome` — correctable |
| Non-zero | 0 | Double-bit error — detected but not correctable |

### CRC-32 Engine

The [`crc_generator.sv`](examples/09_error_detection_correction/crc_generator.sv) implements the Ethernet CRC-32 polynomial with configurable input width:

```systemverilog
// Process DATA_WIDTH bits per clock cycle
function automatic logic [31:0] crc_step(
    input logic [31:0]          crc_in,
    input logic [DATA_WIDTH-1:0] data
);
    logic [31:0] c = crc_in;
    for (int i = 0; i < DATA_WIDTH; i++) begin
        if (c[31] ^ d[i])
            c = {c[30:0], 1'b0} ^ POLYNOMIAL;
        else
            c = {c[30:0], 1'b0};
    end
    return c;
endfunction
```

This serial implementation unrolls into a parallel XOR tree during synthesis, processing all input bits in a single clock cycle.

---

## 11. DSP Blocks

> **Source**: [`examples/10_dsp_blocks/`](examples/10_dsp_blocks/)

### FIR Filter

The [`fir_filter.sv`](examples/10_dsp_blocks/fir_filter.sv) implements a configurable Finite Impulse Response filter:

```
            ┌────┐   ┌────┐   ┌────┐   ┌────┐
data_in ───>│ z⁻¹│──>│ z⁻¹│──>│ z⁻¹│──>│ z⁻¹│
            └──┬─┘   └──┬─┘   └──┬─┘   └──┬─┘
               │×c[0]    │×c[1]   │×c[2]   │×c[3]
               ▼         ▼        ▼        ▼
            ┌──┴─────────┴────────┴────────┴──┐
            │         Adder Tree              │
            └──────────────┬──────────────────┘
                           ▼
                       data_out
```

**Architecture (2-stage pipeline):**

1. **Stage 1**: All taps multiply in parallel (`delay_line[i] * coefficients[i]`)
2. **Stage 2**: Adder tree sums all products

**Runtime coefficient loading** allows filter reconfiguration without re-synthesis:

```systemverilog
if (coeff_wr)
    coefficients[coeff_addr] <= coeff_data;
```

### CORDIC Engine

The [`cordic_engine.sv`](examples/10_dsp_blocks/cordic_engine.sv) computes trigonometric functions using only shifts and adds — no multiplier required:

**Algorithm**: Iteratively rotate a vector toward the target angle. Each iteration rotates by `atan(2^-i)`, using only right-shifts for the "multiply by 2^-i":

```systemverilog
if (z_pipe[i] >= 0) begin
    x_pipe[i+1] <= x_pipe[i] - (y_pipe[i] >>> i);   // Shift, not multiply!
    y_pipe[i+1] <= y_pipe[i] + (x_pipe[i] >>> i);
    z_pipe[i+1] <= z_pipe[i] - atan_table[i];
end
```

**Two implementation variants** controlled by a parameter:

| Mode | Latency | Throughput | Resources |
|------|---------|------------|-----------|
| Pipelined (`PIPELINED=1`) | N cycles | 1 result/cycle | N stages of registers |
| Iterative (`PIPELINED=0`) | N cycles | 1 result/N cycles | 1 stage, reused N times |

---

## 12. Advanced Datapaths

> **Source**: [`examples/11_advanced_datapath/`](examples/11_advanced_datapath/)

### Ternary Content-Addressable Memory (TCAM)

The [`content_addressable_memory.sv`](examples/11_advanced_datapath/content_addressable_memory.sv) searches all entries in parallel — the opposite of conventional memory which uses an address to retrieve data:

```
Conventional RAM:                     CAM:
Address ──> Memory ──> Data           Data ──> Memory ──> Address (if match)
```

**TCAM adds "don't care" bits** via a mask register per entry:

```systemverilog
match_vector[i] = valid_bits[i] &&
    ((search_key & cam_mask[i]) == (cam_data[i] & cam_mask[i]));
```

**Use cases**: Routing tables, ACL lookup, pattern matching, TLB (Translation Lookaside Buffer).

### Systolic Array Matrix Multiplier

The [`systolic_array_multiplier.sv`](examples/11_advanced_datapath/systolic_array_multiplier.sv) implements C = A × B using a wavefront computation pattern:

```
        b[0]    b[1]    b[2]    b[3]
         ↓       ↓       ↓       ↓
a[0] → [PE00]→ [PE01]→ [PE02]→ [PE03]→
         ↓       ↓       ↓       ↓
a[1] → [PE10]→ [PE11]→ [PE12]→ [PE13]→
         ↓       ↓       ↓       ↓
a[2] → [PE20]→ [PE21]→ [PE22]→ [PE23]→
         ↓       ↓       ↓       ↓
a[3] → [PE30]→ [PE31]→ [PE32]→ [PE33]→
```

Each Processing Element (PE) is simple:

```systemverilog
module systolic_pe (
    ...
);
    always_ff @(posedge clk) begin
        a_out       <= a_in;                              // Pass right
        b_out       <= b_in;                              // Pass down
        accumulator <= accumulator + (a_in * b_in);       // MAC
    end
endmodule
```

**The N×N array is built using nested `generate`:**

```systemverilog
for (genvar r = 0; r < N; r++) begin : gen_row
    for (genvar c = 0; c < N; c++) begin : gen_col
        systolic_pe u_pe (
            .a_in  (a_wire[r][c]),
            .a_out (a_wire[r][c+1]),
            .b_in  (b_wire[r][c]),
            .b_out (b_wire[r+1][c]),
            .c_out (c_result[r][c])
        );
    end
end
```

**Data skewing**: Input data must be staggered so that the correct elements arrive at each PE at the right time. The included `input_skewer` module handles this transformation.

---

## 13. Design Best Practices

### Coding Guidelines

| Practice | Rationale |
|----------|-----------|
| Use `logic` instead of `reg`/`wire` | `logic` works in both procedural and continuous assignments |
| Prefer `always_ff` and `always_comb` | Catches unintended latches and combinational feedback |
| Use `typedef enum` for FSM states | Self-documenting, enables tool-assisted state coverage |
| Use `packed struct` for related signals | Enables atomic assignment, simplifies port lists |
| Use `localparam` for derived constants | Prevents accidental override, documents intent |
| One `always_ff` block per register group | Makes the DFF inference explicit and reviewable |

### Reset Strategy

```systemverilog
// Preferred: Asynchronous assert, synchronous deassert
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;           // Known-good initial state
        counter <= '0;
    end else begin
        state <= next_state;
        counter <= counter + 1;
    end
end
```

**Why async assert / sync deassert?** The asynchronous assertion ensures reset takes effect even if the clock is stopped. Synchronous deassertion prevents recovery-time violations by aligning the reset release with the clock edge.

### Synthesizable Subset Checklist

| Allowed | Not Allowed |
|---------|-------------|
| `always_ff`, `always_comb`, `assign` | `initial` blocks (simulation only) |
| Fixed-size arrays, packed/unpacked | Dynamic arrays, queues, associative arrays |
| `for` loops with constant bounds | `while`, `forever`, `repeat` |
| `$clog2()`, `$signed()`, `$unsigned()` | `$display`, `$monitor`, `$time` |
| `parameter`, `localparam`, `generate` | `class`, `program`, `interface` (verify only) |

### Avoiding Common Pitfalls

**Latch inference** — ensure all outputs are assigned in every branch:

```systemverilog
// BAD: infers a latch because 'result' not assigned in default
always_comb begin
    case (sel)
        2'b00: result = a;
        2'b01: result = b;
    endcase
end

// GOOD: default assignment prevents latch
always_comb begin
    result = '0;              // Default
    case (sel)
        2'b00: result = a;
        2'b01: result = b;
    endcase
end
```

**Multi-driven signals** — never drive the same signal from two `always` blocks:

```systemverilog
// BAD: two drivers for 'count'
always_ff @(posedge clk) if (inc) count <= count + 1;
always_ff @(posedge clk) if (dec) count <= count - 1;

// GOOD: single driver with priority
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)     count <= '0;
    else if (inc)   count <= count + 1;
    else if (dec)   count <= count - 1;
end
```

### Clock Domain Crossing Rules

1. **Never** use a signal from another clock domain without synchronization
2. **Single-bit** signals: use a 2-FF synchronizer
3. **Pulses**: use a pulse synchronizer (toggle + edge detect)
4. **Multi-bit buses**: use a FIFO, handshake, or MUX-recirculation scheme
5. **Gray code** pointers for async FIFOs — only 1 bit changes per transition
6. **Add `(* async_reg = "true" *)`** to synchronizer flip-flops

---

## 14. Appendix: SystemVerilog Constructs Quick Reference

### Data Types

```systemverilog
logic [7:0]  byte_val;                // 4-state (0, 1, X, Z)
bit   [7:0]  byte_sim;                // 2-state (0, 1) — simulation only

typedef enum logic [2:0] {
    RED, GREEN, BLUE
} color_t;

typedef struct packed {
    logic [7:0] r, g, b;
} pixel_t;

typedef union packed {
    logic [31:0] word;
    logic [3:0][7:0] bytes;
} word_bytes_t;
```

### Parameterization

```systemverilog
module fifo #(
    parameter int WIDTH = 8,            // Overridable by instantiator
    parameter int DEPTH = 16,
    parameter type DATA_T = logic [WIDTH-1:0]  // Type parameter
)(
    input DATA_T data_in,
    ...
);
    localparam int ADDR_W = $clog2(DEPTH);  // Computed, not overridable
endmodule
```

### Generate Blocks

```systemverilog
generate
    // Conditional hardware inclusion
    if (FEATURE_ENABLED) begin : gen_feature
        feature_module u_feat (...);
    end

    // Replicated structure
    for (genvar i = 0; i < N; i++) begin : gen_array
        processing_element u_pe (.index(i), ...);
    end
endgenerate
```

### Interfaces

```systemverilog
interface axi_stream_if #(parameter int DATA_W = 32);
    logic [DATA_W-1:0] tdata;
    logic              tvalid;
    logic              tready;
    logic              tlast;

    modport master (output tdata, tvalid, tlast, input tready);
    modport slave  (input tdata, tvalid, tlast, output tready);
endinterface
```

### Assertions (for Verification)

```systemverilog
// Immediate assertion
always_comb begin
    assert (state != ILLEGAL_STATE) else $error("Illegal state reached");
end

// Concurrent assertion (checked every clock edge)
property p_handshake;
    @(posedge clk) disable iff (!rst_n)
    valid |-> ##[1:5] ready;   // ready must come within 5 cycles of valid
endproperty

assert property (p_handshake) else $error("Handshake timeout");
cover  property (p_handshake);    // Track if this scenario was exercised
```

---

## Getting Started

### Simulation

All examples are self-contained and can be compiled with any SystemVerilog-compatible simulator:

```bash
# Using Synopsys VCS
vcs -sverilog examples/04_fifo_design/sync_fifo.sv -o simv && ./simv

# Using Cadence Xcelium
xrun -sv examples/04_fifo_design/sync_fifo.sv

# Using Mentor/Siemens QuestaSim
vlog -sv examples/04_fifo_design/sync_fifo.sv && vsim work.sync_fifo

# Using open-source Verilator (lint check)
verilator --lint-only -Wall --language 1800-2017 examples/04_fifo_design/sync_fifo.sv

# Using Icarus Verilog (basic SystemVerilog support)
iverilog -g2012 examples/04_fifo_design/sync_fifo.sv -o sync_fifo_sim
```

### Synthesis

For FPGA synthesis, instantiate any example module in your top-level design and constrain the clock. All examples use synthesizable constructs only (no `initial` blocks, no `$display`, no dynamic types).

---

## License

This tutorial and all accompanying code examples are provided for educational purposes. Feel free to use, modify, and distribute them in your projects.
