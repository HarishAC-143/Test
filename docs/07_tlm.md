# Chapter 7: TLM Ports & Communication

## What Is TLM?

**Transaction Level Modeling (TLM)** is UVM's mechanism for passing transactions between components. Instead of components directly calling each other's methods, they communicate through standardized **ports** and **exports** — a level of indirection that keeps components loosely coupled and reusable.

## Why Not Just Use Method Calls?

Direct method calls create tight coupling:

```systemverilog
// WRONG: Direct coupling — monitor calls scoreboard method
class my_monitor extends uvm_monitor;
  my_scoreboard sb;  // Hard reference to a specific scoreboard
  
  task run_phase(uvm_phase phase);
    // ...
    sb.check(txn);  // Tightly coupled — can't reuse monitor without this scoreboard
  endtask
endclass
```

TLM ports provide abstraction:

```systemverilog
// CORRECT: Loosely coupled via TLM
class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_transaction) ap;  // No knowledge of who's listening
  
  task run_phase(uvm_phase phase);
    // ...
    ap.write(txn);  // Broadcast to whoever is connected
  endtask
endclass
```

## TLM Port Types

UVM provides several TLM port types. Here are the ones you'll use most:

### 1. Analysis Ports (One-to-Many Broadcast)

The most common TLM mechanism in UVM testbenches:

```
                    ┌──→ Scoreboard (subscriber 1)
Monitor ── ap ──────┤
                    ├──→ Coverage Collector (subscriber 2)
                    └──→ Logger (subscriber 3)
```

**Producer side:** `uvm_analysis_port #(T)`

```systemverilog
class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_transaction) ap;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    my_transaction txn;
    forever begin
      // ... observe DUT ...
      txn = my_transaction::type_id::create("txn");
      // ... fill in fields ...
      ap.write(txn);  // Non-blocking broadcast
    end
  endtask
endclass
```

**Subscriber side:** `uvm_analysis_imp #(T, IMP)`

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)
  
  uvm_analysis_imp #(my_transaction, my_scoreboard) analysis_export;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction
  
  // This function is called automatically when the monitor writes a transaction
  function void write(my_transaction txn);
    // Check the transaction
    `uvm_info("SCB", $sformatf("Received: %s", txn.convert2string()), UVM_HIGH)
  endfunction
endclass
```

**Connection (in the environment):**

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  agent.monitor.ap.connect(scoreboard.analysis_export);
endfunction
```

### 2. `uvm_analysis_fifo` — Buffered Analysis

When a subscriber needs to process transactions asynchronously (in a task), use an analysis FIFO:

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)
  
  uvm_analysis_fifo #(my_transaction) expected_fifo;
  uvm_analysis_fifo #(my_transaction) actual_fifo;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    my_transaction expected_txn, actual_txn;
    
    forever begin
      // Block until both FIFOs have data
      expected_fifo.get(expected_txn);
      actual_fifo.get(actual_txn);
      
      // Compare
      if (!expected_txn.compare(actual_txn))
        `uvm_error("SCB", $sformatf("Mismatch!\n  Expected: %s\n  Actual:   %s",
                                     expected_txn.convert2string(), actual_txn.convert2string()))
    end
  endtask
endclass
```

**Connection:**

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  agent.monitor.ap.connect(scoreboard.actual_fifo.analysis_export);
  ref_model.ap.connect(scoreboard.expected_fifo.analysis_export);
endfunction
```

### 3. Sequencer-Driver Port (`seq_item_port`)

This is the built-in TLM connection between `uvm_driver` and `uvm_sequencer`:

```systemverilog
// In the agent's connect_phase:
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  driver.seq_item_port.connect(sequencer.seq_item_export);
endfunction
```

The driver uses it to pull transactions:

```systemverilog
// In the driver's run_phase:
task run_phase(uvm_phase phase);
  my_transaction txn;
  forever begin
    seq_item_port.get_next_item(txn);
    // ... drive DUT ...
    seq_item_port.item_done();
  end
endtask
```

## Multiple Analysis Ports (Multiple Write Functions)

When a component needs to receive transactions from **multiple** analysis ports, you need the `uvm_analysis_imp_decl` macro because SystemVerilog doesn't support overloading the `write()` function by parameter type:

```systemverilog
// Declare two analysis imp suffixes
`uvm_analysis_imp_decl(_input)
`uvm_analysis_imp_decl(_output)

class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)
  
  uvm_analysis_imp_input  #(input_txn, my_scoreboard) input_export;
  uvm_analysis_imp_output #(output_txn, my_scoreboard) output_export;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    input_export  = new("input_export", this);
    output_export = new("output_export", this);
  endfunction
  
  // Called when the input monitor writes
  function void write_input(input_txn txn);
    `uvm_info("SCB", $sformatf("Input: %s", txn.convert2string()), UVM_HIGH)
    // Store expected result
  endfunction
  
  // Called when the output monitor writes
  function void write_output(output_txn txn);
    `uvm_info("SCB", $sformatf("Output: %s", txn.convert2string()), UVM_HIGH)
    // Compare against expected
  endfunction
endclass
```

## `uvm_subscriber` — A Convenient Base Class

If a component only needs to subscribe to one analysis port, `uvm_subscriber` provides a cleaner interface:

```systemverilog
class alu_coverage extends uvm_subscriber #(alu_transaction);
  `uvm_component_utils(alu_coverage)
  
  covergroup alu_cg;
    op_cp: coverpoint txn_cached.operation;
    a_cp:  coverpoint txn_cached.operand_a {
      bins zero = {0};
      bins max  = {8'hFF};
      bins mid  = {[1:8'hFE]};
    }
    b_cp:  coverpoint txn_cached.operand_b {
      bins zero = {0};
      bins max  = {8'hFF};
      bins mid  = {[1:8'hFE]};
    }
    cross_cp: cross op_cp, a_cp, b_cp;
  endgroup
  
  alu_transaction txn_cached;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_cg = new();
  endfunction
  
  // Called automatically when the analysis port writes
  function void write(alu_transaction t);
    txn_cached = t;
    alu_cg.sample();
  endfunction
endclass
```

## TLM Port Connection Rules

| Port Type | Connects To | Direction |
|-----------|-------------|-----------|
| `uvm_analysis_port` | `uvm_analysis_imp` | Producer → Consumer |
| `uvm_analysis_port` | `uvm_analysis_fifo.analysis_export` | Producer → Buffer |
| `uvm_analysis_port` | `uvm_analysis_port` (child → parent) | Port forwarding |
| `seq_item_port` | `seq_item_export` | Driver → Sequencer |

## Complete TLM Topology Example

```
Test
└── Environment
    ├── Input Agent
    │   ├── Sequencer ◄──── seq_item_port ────── Driver
    │   └── Monitor ── ap ──┬──→ Scoreboard.input_export
    │                       └──→ Coverage.analysis_export
    ├── Output Agent (passive)
    │   └── Monitor ── ap ────→ Scoreboard.output_export
    └── Scoreboard
        ├── input_export  (uvm_analysis_imp_input)
        └── output_export (uvm_analysis_imp_output)
```

## Summary

| TLM Element | Class | Purpose |
|-------------|-------|---------|
| Analysis Port | `uvm_analysis_port #(T)` | Broadcast transactions (one-to-many) |
| Analysis Imp | `uvm_analysis_imp #(T, IMP)` | Receive transactions (implements `write()`) |
| Analysis FIFO | `uvm_analysis_fifo #(T)` | Buffer transactions for async processing |
| Subscriber | `uvm_subscriber #(T)` | Convenient base class for single-port subscribers |
| Seq Item Port | `uvm_seq_item_pull_port` | Driver-sequencer communication |
| Multiple Imps | `uvm_analysis_imp_decl(_suffix)` | Multiple `write_suffix()` functions in one component |

---

[← Previous: Chapter 6 — Phases](06_phases.md) | [Next: Chapter 8 — Configuration Database →](08_config_db.md)
