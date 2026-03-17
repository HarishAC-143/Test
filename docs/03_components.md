# Chapter 3: UVM Components

This chapter covers the five essential UVM component types that form every testbench. Each section includes a complete, annotated code example.

## Overview

```
┌─────────────────────────── uvm_test ────────────────────────────┐
│  Configures the environment, selects sequences to run           │
│  ┌───────────────────── uvm_env ─────────────────────────────┐  │
│  │  Top-level container for agents, scoreboards, etc.        │  │
│  │  ┌─────────────── uvm_agent ───────────────┐             │  │
│  │  │  Bundles driver + monitor + sequencer    │  Scoreboard │  │
│  │  │  ┌───────────┐  ┌───────────────────┐   │             │  │
│  │  │  │ Sequencer  │  │                   │   │             │  │
│  │  │  │     │      │  │     Monitor ──────┼───┼──→ Check    │  │
│  │  │  │     ▼      │  │       ▲           │   │             │  │
│  │  │  │  Driver ───┼──┼───→ [DUT]         │   │             │  │
│  │  │  └───────────┘  └───────────────────┘   │             │  │
│  │  └─────────────────────────────────────────┘             │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## 1. The Driver (`uvm_driver`)

The driver is responsible for **converting abstract transactions into pin-level signal activity** on the DUT interface. It receives transactions from the sequencer via a TLM port and wiggles the DUT's input signals accordingly.

### Key Responsibilities

- Pull transactions from the sequencer using `seq_item_port.get_next_item()` / `item_done()`
- Drive DUT input signals through a virtual interface
- Respect protocol timing (clock edges, setup/hold, handshakes)

### Complete Example

```systemverilog
class alu_driver extends uvm_driver #(alu_transaction);
  `uvm_component_utils(alu_driver)
  
  virtual alu_if vif;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db")
  endfunction
  
  task run_phase(uvm_phase phase);
    alu_transaction txn;
    
    forever begin
      // Get the next transaction from the sequencer
      seq_item_port.get_next_item(txn);
      
      // Drive it onto the DUT interface
      drive_transaction(txn);
      
      // Signal that we're done with this transaction
      seq_item_port.item_done();
    end
  endtask
  
  task drive_transaction(alu_transaction txn);
    @(posedge vif.clk);
    vif.operand_a <= txn.operand_a;
    vif.operand_b <= txn.operand_b;
    vif.operation <= txn.operation;
    vif.valid     <= 1'b1;
    
    @(posedge vif.clk);
    vif.valid <= 1'b0;
  endtask
endclass
```

### The Driver-Sequencer Handshake

The `get_next_item()` / `item_done()` protocol is a blocking handshake:

```
Sequencer                          Driver
    │                                │
    │  ◄── get_next_item(txn) ────   │  (driver blocks until txn available)
    │                                │
    │  ──── return txn ──────────►   │  (sequencer provides transaction)
    │                                │
    │                                │  (driver processes transaction)
    │                                │
    │  ◄── item_done() ──────────   │  (driver signals completion)
    │                                │
```

## 2. The Monitor (`uvm_monitor`)

The monitor **observes DUT interface signals and converts them back into transactions**. Unlike the driver, the monitor is strictly **passive** — it never drives signals.

### Key Responsibilities

- Sample DUT outputs (and optionally inputs) on appropriate clock edges
- Reconstruct transactions from observed signal activity
- Broadcast observed transactions through an analysis port
- Collect functional coverage

### Complete Example

```systemverilog
class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)
  
  virtual alu_if vif;
  
  // Analysis port to broadcast observed transactions
  uvm_analysis_port #(alu_transaction) ap;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db")
  endfunction
  
  task run_phase(uvm_phase phase);
    alu_transaction txn;
    
    forever begin
      // Wait for a valid transaction on the bus
      @(posedge vif.clk);
      if (vif.valid) begin
        txn = alu_transaction::type_id::create("txn");
        txn.operand_a = vif.operand_a;
        txn.operand_b = vif.operand_b;
        txn.operation = vif.operation;
        
        // Sample result on the next clock
        @(posedge vif.clk);
        txn.result = vif.result;
        
        `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
        
        // Broadcast to all connected subscribers (scoreboard, coverage)
        ap.write(txn);
      end
    end
  endtask
endclass
```

### Analysis Port Pattern

The monitor uses an **analysis port** (`uvm_analysis_port`), which is a one-to-many broadcast mechanism. Any number of subscribers (scoreboards, coverage collectors) can connect to it:

```
                    ┌──→ Scoreboard
Monitor ── ap ──────┤
                    └──→ Coverage Collector
```

## 3. The Sequencer (`uvm_sequencer`)

The sequencer acts as a **routing and arbitration layer** between sequences and the driver. In most cases, you use the default `uvm_sequencer` without customization.

### When You Need a Custom Sequencer

Most testbenches use the parameterized base class directly:

```systemverilog
typedef uvm_sequencer #(alu_transaction) alu_sequencer;
```

A custom sequencer is only needed when you require special arbitration or routing logic:

```systemverilog
class my_sequencer extends uvm_sequencer #(my_transaction);
  `uvm_component_utils(my_sequencer)
  
  // Custom configuration
  int unsigned max_outstanding = 4;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

## 4. The Agent (`uvm_agent`)

The agent **groups the driver, monitor, and sequencer into a single reusable unit**. Agents can operate in two modes:

| Mode | Components Instantiated | Use Case |
|------|------------------------|----------|
| `UVM_ACTIVE` | Driver + Sequencer + Monitor | Generate stimulus and observe |
| `UVM_PASSIVE` | Monitor only | Observe only (e.g., on an output interface) |

### Complete Example

```systemverilog
class alu_agent extends uvm_agent;
  `uvm_component_utils(alu_agent)
  
  alu_driver     driver;
  alu_monitor    monitor;
  alu_sequencer  sequencer;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Monitor is always created (active or passive)
    monitor = alu_monitor::type_id::create("monitor", this);
    
    // Driver and sequencer only in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = alu_driver::type_id::create("driver", this);
      sequencer = alu_sequencer::type_id::create("sequencer", this);
    end
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect driver to sequencer in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass
```

### Setting Agent Mode

From the test or environment:

```systemverilog
// In build_phase of the environment or test:
uvm_config_db #(uvm_active_passive_enum)::set(this, "agent", "is_active", UVM_PASSIVE);
```

## 5. The Environment (`uvm_env`)

The environment is the **top-level container** that holds agents, scoreboards, coverage collectors, and any other top-level components. Complex SoCs may have nested environments.

### Complete Example

```systemverilog
class alu_env extends uvm_env;
  `uvm_component_utils(alu_env)
  
  alu_agent      agent;
  alu_scoreboard scoreboard;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = alu_agent::type_id::create("agent", this);
    scoreboard = alu_scoreboard::type_id::create("scoreboard", this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect monitor's analysis port to the scoreboard
    agent.monitor.ap.connect(scoreboard.analysis_export);
  endfunction
endclass
```

## 6. The Test (`uvm_test`)

The test is the **entry point** of a UVM simulation. It:
- Builds and configures the environment
- Starts sequences on the sequencer
- Controls simulation duration via objections

### Complete Example

```systemverilog
class alu_base_test extends uvm_test;
  `uvm_component_utils(alu_base_test)
  
  alu_env env;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    alu_base_sequence seq;
    
    phase.raise_objection(this);
    
    seq = alu_base_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);
    
    phase.drop_objection(this);
  endtask
endclass
```

### Objections

Objections control when the simulation ends:

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);   // "I have work to do — don't end simulation"
  // ... do work ...
  phase.drop_objection(this);    // "I'm done — simulation can end"
endtask
```

If no component has a raised objection, the `run_phase` completes and the simulation moves to the next phase.

## 7. The Scoreboard

While not a dedicated UVM base class (it typically extends `uvm_scoreboard` or `uvm_component`), the scoreboard is a critical component that **checks DUT correctness**.

### Complete Example

```systemverilog
class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)
  
  uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;
  
  int pass_count = 0;
  int fail_count = 0;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction
  
  // Called automatically when the monitor writes a transaction
  function void write(alu_transaction txn);
    bit [8:0] expected;
    
    case (txn.operation)
      ADD: expected = txn.operand_a + txn.operand_b;
      SUB: expected = txn.operand_a - txn.operand_b;
      AND: expected = txn.operand_a & txn.operand_b;
      OR:  expected = txn.operand_a | txn.operand_b;
      XOR: expected = txn.operand_a ^ txn.operand_b;
    endcase
    
    if (txn.result === expected[7:0]) begin
      pass_count++;
      `uvm_info("SCB", $sformatf("PASS: %s = 0x%02h", txn.convert2string(), expected[7:0]), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SCB", $sformatf("FAIL: %s — expected 0x%02h, got 0x%02h",
                                   txn.convert2string(), expected[7:0], txn.result))
    end
  endfunction
  
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf("Test Results: %0d passed, %0d failed", pass_count, fail_count), UVM_LOW)
  endfunction
endclass
```

## Summary

| Component | Base Class | Key Method | Purpose |
|-----------|-----------|------------|---------|
| Driver | `uvm_driver` | `run_phase()` | Drive DUT inputs |
| Monitor | `uvm_monitor` | `run_phase()` | Observe DUT outputs |
| Sequencer | `uvm_sequencer` | (automatic) | Route transactions to driver |
| Agent | `uvm_agent` | `build_phase()`, `connect_phase()` | Bundle driver + monitor + sequencer |
| Environment | `uvm_env` | `build_phase()`, `connect_phase()` | Top-level container |
| Test | `uvm_test` | `run_phase()` | Configure env, launch sequences |
| Scoreboard | `uvm_scoreboard` | `write()` | Check DUT correctness |

---

[← Previous: Chapter 2 — Class Hierarchy](02_class_hierarchy.md) | [Next: Chapter 4 — Transactions & Sequence Items →](04_transactions.md)
