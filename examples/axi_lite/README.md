# Example 3: AXI4-Lite Slave Verification

A complete UVM testbench for an AXI4-Lite slave with a 16-register file, demonstrating
protocol-level handshake verification.

## Design Under Test

The AXI4-Lite slave (`rtl/axi_lite_slave.sv`) implements:

- Full AXI4-Lite protocol compliance (5 channels: AW, W, B, AR, R)
- 16 x 32-bit read/write registers
- Write-strobe (byte-enable) support
- Independent read and write FSMs
- Always returns OKAY (2'b00) response

### AXI4-Lite Channel Handshakes

```
Master                            Slave
  │                                 │
  │── AWADDR + AWVALID ───────────▶│
  │◀──────────────── AWREADY ──────│
  │                                 │
  │── WDATA + WSTRB + WVALID ─────▶│
  │◀──────────────── WREADY ───────│
  │                                 │
  │◀── BRESP + BVALID ─────────────│
  │── BREADY ────────────────────▶│
  │                                 │
  │── ARADDR + ARVALID ───────────▶│
  │◀──────────────── ARREADY ──────│
  │                                 │
  │◀── RDATA + RRESP + RVALID ────│
  │── RREADY ────────────────────▶│
```

## Testbench Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  axi_lite_test                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  axi_lite_env                                         │  │
│  │  ┌──────────────────────────────────┐  ┌───────────┐  │  │
│  │  │  axi_lite_agent (UVM_ACTIVE)     │  │ axi_sb    │  │  │
│  │  │  ┌──────────┐  ┌─────────────┐  │  │           │  │  │
│  │  │  │ axi_sqr  │→ │ axi_drv     │──┼──┼──→ DUT    │  │  │
│  │  │  └──────────┘  │ (aw/w/b/    │  │  │           │  │  │
│  │  │                │  ar/r FSM)  │  │  │           │  │  │
│  │  │                └─────────────┘  │  │           │  │  │
│  │  │  ┌────────────────────────────┐ │  │           │  │  │
│  │  │  │ axi_mon (wr fork + rd     │ │  │           │  │  │
│  │  │  │  fork) ──→ ap ────────────┼─┼──┼→ write()  │  │  │
│  │  │  └────────────────────────────┘ │  └───────────┘  │  │
│  │  └──────────────────────────────────┘  ┌───────────┐  │  │
│  │                                        │ axi_cov   │  │  │
│  │                        ap ─────────────┼→ write()  │  │  │
│  │                                        └───────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## File Structure

```
axi_lite/
├── README.md
├── filelist.f
├── rtl/
│   └── axi_lite_slave.sv       # AXI4-Lite slave with register file
└── tb/
    ├── axi_lite_if.sv           # AXI4-Lite interface (5 channels)
    ├── axi_lite_transaction.sv  # Unified read/write transaction
    ├── axi_lite_sequences.sv    # Write, read, write-read-all, random, b2b
    ├── axi_lite_driver.sv       # AXI protocol-aware driver
    ├── axi_lite_monitor.sv      # Dual-fork monitor (write + read)
    ├── axi_lite_sequencer.sv    # Standard sequencer
    ├── axi_lite_agent.sv        # Agent
    ├── axi_lite_scoreboard.sv   # Register-file reference model
    ├── axi_lite_coverage.sv     # Channel and strobe coverage
    ├── axi_lite_env.sv          # Environment
    ├── axi_lite_test.sv         # Test classes
    ├── axi_lite_pkg.sv          # Package
    └── top.sv                   # Top-level module
```

## Running

```bash
# VCS
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv
./simv +UVM_TESTNAME=axi_lite_full_test

# Questa
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f filelist.f
vsim -c top -do "run -all; quit" +UVM_TESTNAME=axi_lite_random_test

# Xcelium
xrun -uvm -f filelist.f +UVM_TESTNAME=axi_lite_wr_rd_test
```

## Available Tests

| Test | Description |
|------|-------------|
| `axi_lite_wr_rd_test` | Write unique data to all 16 registers, then read back |
| `axi_lite_random_test` | 500 random read/write transactions |
| `axi_lite_full_test` | Write-read-all + back-to-back + 300 random |

## Key Learning Points

1. **Protocol-aware driver** -- implements AXI4-Lite write (AW→W→B) and read (AR→R)
   handshakes correctly
2. **Forked monitor** -- separate threads for monitoring write and read channels
3. **Back-to-back sequences** -- write then immediately read-back the same address
4. **Write-strobe coverage** -- ensures all byte-enable patterns are exercised
5. **Per-register coverage** -- cross-coverage of address x operation type
