# CDC Synchronizer Design Patterns

A comprehensive catalog of Clock Domain Crossing (CDC) synchronization patterns, with circuit diagrams, Verilog code, and guidance on when to use each pattern.

---

## Table of Contents

1. [Two-Flip-Flop Synchronizer](#1-two-flip-flop-synchronizer)
2. [Three-Flip-Flop Synchronizer](#2-three-flip-flop-synchronizer)
3. [Pulse Synchronizer (Toggle)](#3-pulse-synchronizer-toggle)
4. [Handshake Synchronizer](#4-handshake-synchronizer)
5. [MUX Recirculation Synchronizer](#5-mux-recirculation-synchronizer)
6. [Gray-Code Counter Synchronizer](#6-gray-code-counter-synchronizer)
7. [Asynchronous FIFO](#7-asynchronous-fifo)
8. [Reset Synchronizer](#8-reset-synchronizer)
9. [Level Synchronizer with Feedback](#9-level-synchronizer-with-feedback)
10. [Choosing the Right Pattern](#10-choosing-the-right-pattern)

---

## 1. Two-Flip-Flop Synchronizer

**Use for**: Single-bit level signals crossing between unrelated clock domains.

**How it works**: The first flip-flop may go metastable, but it has a full clock period to resolve before the second flip-flop samples it. The MTBF of a 2-FF synchronizer is typically >100 years at modern process nodes.

```
Source Domain          Destination Domain
                ┌───┐    ┌───┐
  sig_src ─────▶│FF1│───▶│FF2│───▶ sig_dst (safe)
                │   │    │   │
       clk_dst ─┤>  │    ┤>  │
                └───┘    └───┘
```

```verilog
module sync_2ff (
    input  wire clk_dst,
    input  wire rst_dst_n,
    input  wire sig_src,    // From source domain (registered)
    output wire sig_dst     // Synchronized to clk_dst
);
    reg sync1, sync2;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= sig_src;
            sync2 <= sync1;
        end
    end

    assign sig_dst = sync2;
endmodule
```

**Constraints**:
- `sig_src` MUST be a registered output from the source domain (no combinational logic between source FF and `sync1`)
- `sig_src` must be stable for at least one destination clock period

**Latency**: 2 destination clock cycles

---

## 2. Three-Flip-Flop Synchronizer

**Use for**: Very high-frequency designs or safety-critical applications where 2-FF MTBF is insufficient.

```verilog
module sync_3ff (
    input  wire clk_dst,
    input  wire rst_dst_n,
    input  wire sig_src,
    output wire sig_dst
);
    reg sync1, sync2, sync3;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync3 <= 1'b0;
        end else begin
            sync1 <= sig_src;
            sync2 <= sync1;
            sync3 <= sync2;
        end
    end

    assign sig_dst = sync3;
endmodule
```

**When to use 3-FF instead of 2-FF**:
- Clock frequency > 1 GHz
- Automotive (ISO 26262) or aerospace applications
- When MTBF requirements exceed 1000 years

**Latency**: 3 destination clock cycles

---

## 3. Pulse Synchronizer (Toggle)

**Use for**: Transferring a single-cycle pulse from one domain to another. A simple 2-FF synchronizer may miss a short pulse if the destination clock is slower.

**How it works**: Convert the pulse to a toggle (level change) in the source domain, synchronize the level with 2-FF, then detect the edge in the destination domain.

```
Source Domain             Destination Domain

         ┌───┐            ┌───┐  ┌───┐  ┌───┐
pulse ──▶│TGL│── level ──▶│FF1│─▶│FF2│─▶│FF3│
         │   │            │   │  │   │  │   │
  clk_s ─┤>  │   clk_d ──┤>  │  ┤>  │  ┤>  │
         └───┘            └───┘  └───┘  └───┘
                                   │      │
                                   └──XOR─┘──▶ pulse_dst
```

```verilog
module pulse_sync (
    // Source domain
    input  wire clk_src,
    input  wire rst_src_n,
    input  wire pulse_src,

    // Destination domain
    input  wire clk_dst,
    input  wire rst_dst_n,
    output wire pulse_dst
);
    // Source: convert pulse to toggle
    reg toggle_src;
    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_src)
            toggle_src <= ~toggle_src;
    end

    // Destination: 2-FF sync + edge detect
    reg sync1, sync2, sync3;
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync3 <= 1'b0;
        end else begin
            sync1 <= toggle_src;
            sync2 <= sync1;
            sync3 <= sync2;
        end
    end

    assign pulse_dst = sync2 ^ sync3;
endmodule
```

**Important**: Source pulses must not arrive faster than the synchronization latency (min ~3 destination clock cycles apart). If they can, use a FIFO instead.

---

## 4. Handshake Synchronizer

**Use for**: Multi-bit data transfers that occur infrequently (not streaming). The protocol guarantees that data is stable when sampled.

```
Source Domain                    Destination Domain

  data ─────┬─────────────────────────────▶ [data sampled here]
            │                                      ▲
  req ──────┼──── 2FF sync ──────▶ req_sync ──────┘
            │                                      │
  ack ◀─────┴──── 2FF sync ◀───── ack_sync ◀──────┘
```

**Protocol**:
1. Source places `data` on the bus
2. Source asserts `req`
3. Destination sees `req_sync`, samples `data`, asserts `ack`
4. Source sees `ack_sync`, may change `data` and deassert `req`
5. Destination sees `req_sync` low, deasserts `ack`

```verilog
module handshake_sync #(
    parameter WIDTH = 8
) (
    // Source domain
    input  wire             clk_src,
    input  wire             rst_src_n,
    input  wire             send,         // Pulse to initiate transfer
    input  wire [WIDTH-1:0] data_src,
    output reg              busy,         // High while transfer in progress

    // Destination domain
    input  wire             clk_dst,
    input  wire             rst_dst_n,
    output reg [WIDTH-1:0]  data_dst,
    output reg              data_valid    // Pulse when new data available
);
    // Source side
    reg             req_src;
    reg [WIDTH-1:0] data_hold;
    wire            ack_src_sync;

    // Synchronize ack back to source
    reg ack_sync1_s, ack_sync2_s;
    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            ack_sync1_s <= 1'b0;
            ack_sync2_s <= 1'b0;
        end else begin
            ack_sync1_s <= ack_dst;
            ack_sync2_s <= ack_sync1_s;
        end
    end
    assign ack_src_sync = ack_sync2_s;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            req_src   <= 1'b0;
            data_hold <= {WIDTH{1'b0}};
            busy      <= 1'b0;
        end else begin
            if (send && !busy) begin
                data_hold <= data_src;
                req_src   <= 1'b1;
                busy      <= 1'b1;
            end else if (ack_src_sync) begin
                req_src <= 1'b0;
            end else if (!req_src && !ack_src_sync && busy) begin
                busy <= 1'b0;
            end
        end
    end

    // Destination side
    reg req_sync1_d, req_sync2_d;
    reg ack_dst;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_sync1_d <= 1'b0;
            req_sync2_d <= 1'b0;
        end else begin
            req_sync1_d <= req_src;
            req_sync2_d <= req_sync1_d;
        end
    end

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            data_dst   <= {WIDTH{1'b0}};
            data_valid <= 1'b0;
            ack_dst    <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            if (req_sync2_d && !ack_dst) begin
                data_dst   <= data_hold;
                data_valid <= 1'b1;
                ack_dst    <= 1'b1;
            end else if (!req_sync2_d) begin
                ack_dst <= 1'b0;
            end
        end
    end
endmodule
```

**Throughput**: Low — one transfer takes ~6-8 total clock cycles (both domains). Use for configuration, status, or infrequent data transfers.

---

## 5. MUX Recirculation Synchronizer

**Use for**: Multi-bit data where a 2-FF-synchronized control signal selects between old and new data.

```
Source Domain            Destination Domain

  data_src ──────────────────────────┐
                                     │ 0 ┌─────┐
                              ┌──────┤MUX├──▶│ FF │──┬──▶ data_dst
                              │      │ 1 └─────┘  └──┘
                              │      └───────────────┘
                              │           ▲
  ctrl_src ── 2FF sync ──────▶ sel        │ (recirculation)
```

**How it works**: The MUX output recirculates to its own input. When `sel=0`, the register holds its previous value (recirculation). When `sel=1` (control signal arrives), new data is loaded. The data bus is only sampled when the synchronized control signal asserts — by which time the data has been stable for 2+ destination clock cycles.

```verilog
module mux_recirc_sync #(
    parameter WIDTH = 8
) (
    input  wire             clk_dst,
    input  wire             rst_dst_n,
    input  wire [WIDTH-1:0] data_src,    // Multi-bit from source (registered)
    input  wire             load_src,    // Single-bit load control from source
    output reg  [WIDTH-1:0] data_dst
);
    // Synchronize load control (single-bit, safe with 2-FF)
    reg load_sync1, load_sync2;
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            load_sync1 <= 1'b0;
            load_sync2 <= 1'b0;
        end else begin
            load_sync1 <= load_src;
            load_sync2 <= load_sync1;
        end
    end

    // Edge detect for load pulse
    reg load_prev;
    wire load_pulse;
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            load_prev <= 1'b0;
        else
            load_prev <= load_sync2;
    end
    assign load_pulse = load_sync2 & ~load_prev;

    // MUX recirculation: load new data only when control arrives
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            data_dst <= {WIDTH{1'b0}};
        else if (load_pulse)
            data_dst <= data_src;    // Data stable by now
        // else: recirculate (hold current value)
    end
endmodule
```

**Requirement**: Source must hold `data_src` stable for at least 2 destination clock cycles before and after asserting `load_src`.

---

## 6. Gray-Code Counter Synchronizer

**Use for**: Counters or pointers that cross domains (e.g., FIFO write/read pointers).

See the detailed implementation in [`examples/cdc_fixed/cdc_multibit_gray.v`](../examples/cdc_fixed/cdc_multibit_gray.v).

**Gray code conversion formulas**:

```
Binary to Gray:  gray = binary ^ (binary >> 1)
Gray to Binary:  binary[i] = XOR(gray[N:i])  for each bit i
```

**Why Gray code works**: Only one bit changes between consecutive counter values. Even if the synchronizer samples the transition, the result is either the old value or the new value — never a spurious intermediate value.

---

## 7. Asynchronous FIFO

**Use for**: Streaming data between clock domains at high throughput.

See the complete implementation in [`examples/practical/async_fifo.v`](../examples/practical/async_fifo.v).

**Key components**:
- Dual-port RAM (one write port, one read port)
- Gray-coded write pointer synchronized to read domain (for empty flag)
- Gray-coded read pointer synchronized to write domain (for full flag)
- Full/empty flags computed from synchronized pointer comparison

**Sizing**: FIFO depth should absorb burst rate differences. Minimum depth depends on:
- Clock frequency ratio
- Maximum burst length
- Allowable latency for backpressure (full flag)

---

## 8. Reset Synchronizer

**Use for**: Distributing asynchronous reset to different clock domains with safe de-assertion.

See the implementation in [`examples/practical/reset_synchronizer.v`](../examples/practical/reset_synchronizer.v).

**Pattern**: "Asynchronous assert, synchronous de-assert"

```verilog
always @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n)
        {sync2, sync1} <= 2'b00;           // Assert immediately
    else
        {sync2, sync1} <= {sync1, 1'b1};   // De-assert synchronously
end

assign rst_sync_n = sync2;
```

---

## 9. Level Synchronizer with Feedback

**Use for**: Ensuring the source domain knows when the destination has captured a level change. Prevents the source from changing the signal again before it's been properly synchronized.

```verilog
module level_sync_feedback (
    // Source domain
    input  wire clk_src,
    input  wire rst_src_n,
    input  wire level_in,
    output wire safe_to_change,  // Feedback: OK to change level_in

    // Destination domain
    input  wire clk_dst,
    input  wire rst_dst_n,
    output wire level_out
);
    // Source → Destination: synchronize level
    reg sync1, sync2;
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= level_in;
            sync2 <= sync1;
        end
    end
    assign level_out = sync2;

    // Destination → Source: feedback synchronized value
    reg fb_sync1, fb_sync2;
    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            fb_sync1 <= 1'b0;
            fb_sync2 <= 1'b0;
        end else begin
            fb_sync1 <= sync2;
            fb_sync2 <= fb_sync1;
        end
    end

    // Safe to change when feedback matches current input
    assign safe_to_change = (fb_sync2 == level_in);
endmodule
```

---

## 10. Choosing the Right Pattern

| Scenario | Recommended Pattern | Latency | Throughput |
|----------|-------------------|---------|------------|
| Single-bit level signal | 2-FF Synchronizer | 2 clk_dst | N/A |
| Single-bit pulse | Pulse Synchronizer | 3-4 clk_dst | 1 pulse per 6 clk_dst |
| Multi-bit data (infrequent) | Handshake | 6-8 total cycles | Low |
| Multi-bit data (streaming) | Async FIFO | 2-3 clk_dst (read) | High (1 per clk) |
| Counter / pointer | Gray Code + 2-FF | 2 clk_dst | N/A |
| Multi-bit data (with control) | MUX Recirculation | 3 clk_dst | Medium |
| Reset signal | Reset Synchronizer | 2 clk_dst (de-assert) | N/A |
| Level with acknowledgment | Level Sync + Feedback | 4+ total cycles | Low |

### Decision Flowchart

```
Is the signal single-bit?
├── Yes: Is it a pulse?
│   ├── Yes → Pulse Synchronizer
│   └── No → 2-FF Synchronizer
└── No (multi-bit):
    ├── Is it a counter/pointer? → Gray Code + 2-FF
    ├── Is it streaming data? → Async FIFO
    ├── Is it infrequent data? → Handshake Synchronizer
    └── Is it config/status data? → MUX Recirculation
```

### Common Mistakes to Avoid

1. **Using 2-FF on multi-bit buses** — Each bit may synchronize on a different clock edge
2. **Combinational logic before synchronizer** — Introduces glitches
3. **Forgetting to register in source domain** — Input to synchronizer must be a registered output
4. **Sending pulses faster than sync latency** — Pulses can be lost
5. **Not constraining `set_max_delay`** — Synchronizer timing must be constrained
6. **Using async FIFO without Gray-coded pointers** — Standard binary pointers are unsafe
7. **Ignoring reconvergent CDC paths** — Data that splits and re-merges across domains needs special handling
