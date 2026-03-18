# CDC Synchronizer Selection Guide

Choosing the right synchronization scheme depends on the type of signal being transferred, throughput requirements, and acceptable latency.

---

## Decision Flowchart

```
Is the signal a single bit?
├── YES → Is it a level (steady) signal?
│         ├── YES → Use 2-FF Synchronizer
│         └── NO (pulse) → Use Pulse Synchronizer
│
└── NO (multi-bit) → Is high throughput needed?
                      ├── YES → Use Asynchronous FIFO (Gray-code pointers)
                      └── NO  → Is data transfer infrequent?
                                ├── YES → Use Handshake Synchronizer
                                └── NO  → Use MUX Synchronizer with enable
```

---

## Synchronizer Comparison

| Synchronizer | Signal Type | Latency | Throughput | Complexity | Area |
|-------------|-------------|---------|------------|------------|------|
| **2-FF** | Single-bit level | 2 cycles | Low | Very Low | 2 FFs |
| **Pulse** | Single-bit pulse | 3-4 cycles | Low | Low | 4 FFs + XOR |
| **Handshake** | Multi-bit bundle | 4-8 cycles | Low | Medium | ~10 FFs |
| **Async FIFO** | Data stream | 2-3 cycles | High | High | RAM + pointers |
| **MUX Sync** | Multi-bit with enable | 2-3 cycles | Medium | Medium | 2 FFs + MUX |

---

## 1. 2-FF Synchronizer

**File:** [`examples/cdc_synchronizers/sync_2ff.v`](../examples/cdc_synchronizers/sync_2ff.v)

### When to Use
- Single-bit control signals (enable, valid, interrupt, status)
- Signal must be stable for at least one destination clock period

### When NOT to Use
- Pulses shorter than destination clock period (use Pulse Synchronizer)
- Multi-bit data buses (use FIFO or Handshake)

### Architecture

```
                  Destination Clock Domain
                 ┌─────────┐  ┌─────────┐
data_in ────────▶│  FF_1   ├──▶│  FF_2   ├──▶ data_out
                 │ (may go │  │(resolves│     (safe)
                 │metastab)│  │  meta)  │
                 └─────────┘  └─────────┘
                    clk_dst      clk_dst
```

### Key Design Rules
1. No combinational logic between FF_1 and FF_2
2. Both FFs must use the same clock (destination)
3. Both FFs must use the same reset
4. Apply `async_reg` synthesis attribute
5. Place FFs close together (minimize wire delay)

### MTBF Calculation

```
MTBF_1ff = e^(Tclk / τ) / (T0 × fclk × fdata)

MTBF_2ff = e^(Tclk / τ) / (T0 × fclk × fdata) × e^(Tclk / τ)
         = MTBF_1ff × e^(Tclk / τ)

Example (130nm, 500MHz):
  τ ≈ 40 ps, T0 ≈ 0.04 s
  MTBF_1ff ≈ 1.6 seconds    (UNACCEPTABLE)
  MTBF_2ff ≈ 1.3 × 10^18 s  (> age of universe)
```

---

## 2. Pulse Synchronizer

**File:** [`examples/cdc_synchronizers/sync_pulse.v`](../examples/cdc_synchronizers/sync_pulse.v)

### When to Use
- Single-cycle pulses (interrupts, events, triggers)
- Source clock may be faster than destination clock

### Architecture

```
 Source Domain          Destination Domain
┌──────────┐          ┌────────────────────────┐
│  Toggle  │──2FF───▶ │ Edge   ┌────┐  pulse   │
│  on pulse│  sync    │ Detect │XOR ├──▶ out   │
└──────────┘          │        └────┘          │
                      └────────────────────────┘
```

### Limitations
- Cannot transfer back-to-back pulses faster than the synchronization latency
- If a second pulse arrives before the first is synchronized, it is lost
- Add a "busy" feedback signal if pulse loss is unacceptable

---

## 3. Handshake Synchronizer

**File:** [`examples/cdc_synchronizers/sync_handshake.v`](../examples/cdc_synchronizers/sync_handshake.v)

### When to Use
- Multi-bit data transfers at low frequency
- Control packets, configuration writes, command transfers
- When data integrity is more important than throughput

### Protocol (4-Phase Handshake)

```
                Source Domain    │    Destination Domain
                                │
 1. Assert req, hold data ──────┼───▶ (sync req)
                                │
 2.                        ◀────┼──── Capture data, assert ack
                                │
 3. See ack, deassert req ──────┼───▶ (sync req deassert)
                                │
 4.                        ◀────┼──── See req low, deassert ack
                                │
 (Ready for next transfer)      │
```

### Key Design Rules
1. Source MUST hold data stable from req assertion until ack is received
2. Both req and ack need 2-FF synchronization
3. Data bus does NOT need bit-by-bit synchronization (it's qualified by req)
4. Cannot start a new transfer until the handshake cycle completes

---

## 4. Asynchronous FIFO (Gray-Code)

**File:** [`examples/cdc_synchronizers/sync_gray_fifo.v`](../examples/cdc_synchronizers/sync_gray_fifo.v)

### When to Use
- High-throughput streaming data between clock domains
- Video/audio data paths, network packet buffers
- When both sides need to operate at full clock speed

### Architecture

```
  Writer Domain                      Reader Domain
 ┌──────────────┐                   ┌──────────────┐
 │ wr_ptr (bin) │                   │ rd_ptr (bin) │
 │      │       │                   │      │       │
 │ bin→gray     │                   │ bin→gray     │
 │      │       │    ┌─────────┐   │      │       │
 │      ├───────┼───▶│ 2FF     ├───┼──────┤       │
 │      │       │    │ sync    │   │ (compare for │
 │      │       │    └─────────┘   │  empty flag) │
 │      │       │                   │              │
 │      │       │    ┌─────────┐   │              │
 │      │◀──────┼────┤ 2FF     │◀──┼──────┤       │
 │ (compare for │    │ sync    │   │              │
 │  full flag)  │    └─────────┘   │              │
 └──────┬───────┘                   └──────┬───────┘
        │         ┌──────────┐            │
        └────────▶│ Dual-Port│◀───────────┘
                  │   RAM    │
                  └──────────┘
```

### Key Design Rules
1. FIFO depth MUST be a power of 2 (required for Gray code)
2. Pointers use N+1 bits (extra MSB for full/empty distinction)
3. Only Gray-coded pointers cross domains (never binary)
4. Full/empty flags are conservative (may show full/empty slightly early)
5. Write pointer synchronized to read domain (empty detection)
6. Read pointer synchronized to write domain (full detection)

### Why Gray Code Works
Binary counter transitions can change multiple bits simultaneously:
```
Binary: 0111 → 1000  (4 bits change!)
Gray:   0100 → 1100  (1 bit changes)
```

With 2-FF synchronization on a Gray-coded pointer, the synchronized value is always either the current value or the previous value — never a corrupted intermediate.

---

## 5. MUX Synchronizer

### When to Use
- Multi-bit data with an associated enable/valid signal
- The enable acts as a "data valid" qualifier
- Data changes infrequently relative to the clock

### Architecture

```
  Source Domain                  Destination Domain
 ┌────────────┐                ┌─────────────────────────┐
 │ data[N:0]  │────────────────▶│    ┌─────┐              │
 │            │                │ ───▶│ MUX ├──▶ data_out  │
 │ enable     │──▶ 2FF sync ──▶│ ───▶│     │              │
 └────────────┘                │    └─────┘              │
                               └─────────────────────────┘
```

### Key Design Rules
1. Data must be stable before and after the enable assertion
2. Enable signal is synchronized via standard 2-FF
3. MUX selects new data only when synchronized enable is high
4. Data bus itself is NOT synchronized (it's qualified by enable)

---

## Common Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|------------------|
| Synchronizing a bus bit-by-bit | Each bit resolves independently — corrupted values | Use Gray FIFO or handshake |
| Combinational logic before synchronizer | Glitches get captured | Register in source domain |
| Using 1-FF synchronizer | Insufficient metastability resolution | Minimum 2 FFs |
| Mixing synchronizer and data logic | Synthesis may optimize away sync FF | Use `dont_touch` attribute |
| Not resetting synchronizer | Unknown initial state | Reset both sync FFs |
| Using synchronized signal for multiple independent purposes | Reconvergence risk | Synchronize separately for each use |

---

## SpyGlass CDC Rule Mapping

| Synchronizer | Rules When Missing | Rules When Present |
|-------------|-------------------|-------------------|
| 2-FF | Ac_cdc01 | (clean) |
| Pulse | Ac_cdc01 | (clean) |
| Handshake | Ac_cdc05 | May see Ac_cdc07 if not constrained |
| Async FIFO | Ac_cdc05, Ac_cdc04 | (clean with gray pointers) |
| None | Ac_cdc01, Ac_cdc03 | N/A |
