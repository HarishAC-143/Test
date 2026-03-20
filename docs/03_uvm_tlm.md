# 3. UVM TLM & Communication

[&larr; Previous: Phases & Lifecycle](02_uvm_phases.md) | [Back to Main](../README.md) | [Next: Sequences & Sequencer &rarr;](04_uvm_sequences.md)

---

## 3.1 What is TLM?

**Transaction-Level Modeling (TLM)** is UVM's mechanism for inter-component communication. Instead of passing signals or raw data, components exchange **transaction objects** through well-defined ports and exports.

### Benefits

- **Abstraction** — Components communicate at the transaction level, not signal level.
- **Decoupling** — A producer doesn't need to know who consumes its data.
- **Reusability** — Components can be reused with different connections.
- **Debug** — Transactions carry rich information (timestamps, metadata).

---

## 3.2 TLM Concepts

### Port, Export, and Imp

| Concept | Role | Initiates? |
|---------|------|-----------|
| **Port** (`uvm_*_port`) | Initiator — calls methods on the connected export/imp | Yes |
| **Export** (`uvm_*_export`) | Forwarder — passes calls to a child imp | No |
| **Imp** (`uvm_*_imp`) | Implementor — contains the actual method implementation | No |

### Connection Rules

```
Port ──► Export ──► Imp     (most common: port connects to imp)
Port ──► Imp                (direct connection)
Port ──► Export ──► Export ──► Imp   (hierarchical forwarding)
```

A **port** always connects to an **export** or **imp**, never to another port. An **imp** is always the terminal endpoint.

---

## 3.3 TLM Port Types

### 3.3.1 Blocking Put/Get Ports

These consume simulation time (they are tasks).

```systemverilog
// Producer side
uvm_blocking_put_port #(my_txn) put_port;

// Consumer side — imp
uvm_blocking_put_imp #(my_txn, my_consumer) put_imp;

// Consumer must implement:
task put(my_txn t);
  // process transaction
endtask
```

### 3.3.2 Nonblocking Put/Get Ports

These return immediately (they are functions).

```systemverilog
uvm_nonblocking_put_port #(my_txn) nb_put_port;
uvm_nonblocking_put_imp #(my_txn, my_consumer) nb_put_imp;

// Consumer must implement:
function bit try_put(my_txn t);
  // return 1 if accepted, 0 if busy
endfunction

function bit can_put();
  // return 1 if ready to accept
endfunction
```

### 3.3.3 Combined Put/Get Ports

```systemverilog
uvm_put_port #(my_txn) port;  // has both blocking and nonblocking methods
```

### 3.3.4 Analysis Ports (Publish-Subscribe)

The most commonly used TLM mechanism in UVM. One producer broadcasts to **zero or more** subscribers.

```systemverilog
// Producer (e.g., monitor)
uvm_analysis_port #(my_txn) ap;

// Subscriber (e.g., scoreboard)
uvm_analysis_imp #(my_txn, my_scoreboard) analysis_imp;

// OR use uvm_subscriber (convenience wrapper):
class my_coverage extends uvm_subscriber #(my_txn);
  // Must implement:
  function void write(my_txn t);
    // process transaction
  endfunction
endclass
```

---

## 3.4 Analysis Port — Deep Dive

The analysis port is the workhorse of UVM communication. Here's a complete example:

### Producer: Monitor

```systemverilog
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  uvm_analysis_port #(my_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_txn txn;
    forever begin
      // ... observe DUT signals ...
      txn = my_txn::type_id::create("txn");
      // ... populate txn fields ...
      ap.write(txn);  // broadcast to all subscribers
    end
  endtask
endclass
```

### Subscriber 1: Scoreboard

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp #(my_txn, my_scoreboard) analysis_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(my_txn txn);
    // Check transaction against expected results
    `uvm_info("SB", $sformatf("Received txn: %s", txn.sprint()), UVM_HIGH)
  endfunction
endclass
```

### Subscriber 2: Coverage Collector

```systemverilog
class my_coverage extends uvm_subscriber #(my_txn);
  `uvm_component_utils(my_coverage)

  covergroup cg;
    coverpoint txn.addr { bins low = {[0:63]}; bins high = {[64:127]}; }
    coverpoint txn.data;
    cross txn.addr, txn.data;
  endgroup

  my_txn txn;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void write(my_txn t);
    txn = t;
    cg.sample();
  endfunction
endclass
```

### Wiring in the Environment

```systemverilog
class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  my_agent      agt;
  my_scoreboard sb;
  my_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = my_agent::type_id::create("agt", this);
    sb  = my_scoreboard::type_id::create("sb", this);
    cov = my_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.ap.connect(sb.analysis_export);
    agt.mon.ap.connect(cov.analysis_export);
  endfunction
endclass
```

---

## 3.5 TLM FIFOs

When the producer and consumer run at different rates, use a **TLM FIFO** to buffer transactions.

### `uvm_tlm_analysis_fifo`

Connects an analysis port to a blocking get port via an internal FIFO.

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_tlm_analysis_fifo #(my_txn) expected_fifo;
  uvm_tlm_analysis_fifo #(my_txn) actual_fifo;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_txn expected_txn, actual_txn;
    forever begin
      expected_fifo.get(expected_txn);
      actual_fifo.get(actual_txn);

      if (!expected_txn.compare(actual_txn))
        `uvm_error("SB", $sformatf("Mismatch!\nExpected: %s\nActual: %s",
                   expected_txn.sprint(), actual_txn.sprint()))
      else
        `uvm_info("SB", "Match!", UVM_HIGH)
    end
  endtask
endclass
```

### Wiring FIFOs

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  // Monitor -> FIFO (analysis port side)
  agt.mon.ap.connect(sb.actual_fifo.analysis_export);
  // Reference model -> FIFO
  ref_model.ap.connect(sb.expected_fifo.analysis_export);
endfunction
```

---

## 3.6 Multiple Analysis Ports with `uvm_analysis_imp_decl`

When a component needs to receive transactions from multiple analysis ports, use the declaration macro:

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp_expected #(my_txn, my_scoreboard) expected_export;
  uvm_analysis_imp_actual   #(my_txn, my_scoreboard) actual_export;

  my_txn expected_queue[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_export = new("expected_export", this);
    actual_export   = new("actual_export", this);
  endfunction

  // Called when expected analysis port writes
  function void write_expected(my_txn txn);
    expected_queue.push_back(txn);
  endfunction

  // Called when actual analysis port writes
  function void write_actual(my_txn txn);
    my_txn exp;
    if (expected_queue.size() == 0) begin
      `uvm_error("SB", "Received actual with no expected!")
      return;
    end

    exp = expected_queue.pop_front();
    if (!exp.compare(txn))
      `uvm_error("SB", $sformatf("Mismatch!\nExpected: %s\nActual: %s",
                 exp.sprint(), txn.sprint()))
    else
      `uvm_info("SB", "Match!", UVM_HIGH)
  endfunction
endclass
```

---

## 3.7 TLM2 Sockets (Advanced)

UVM also supports TLM-2.0 style sockets for bidirectional communication:

```systemverilog
class my_initiator extends uvm_component;
  uvm_tlm_b_initiator_socket #(my_txn) socket;

  task run_phase(uvm_phase phase);
    my_txn txn = new();
    uvm_tlm_time delay = new();
    socket.b_transport(txn, delay);  // blocking transport
  endtask
endclass

class my_target extends uvm_component;
  uvm_tlm_b_target_socket #(this_type, my_txn) socket;

  task b_transport(my_txn txn, uvm_tlm_time delay);
    // Process request and update txn with response
    #(delay.get_realtime(1ns));
  endtask
endclass
```

---

## 3.8 TLM Communication Summary

| Mechanism | Cardinality | Blocking? | Typical Use |
|-----------|------------|-----------|-------------|
| `uvm_blocking_put_port` | 1:1 | Yes | Producer → Consumer |
| `uvm_nonblocking_put_port` | 1:1 | No | Polling communication |
| `uvm_analysis_port` | 1:N | No (function) | Monitor → Scoreboard/Coverage |
| `uvm_tlm_analysis_fifo` | 1:1 (buffered) | Yes (get side) | Rate decoupling |
| `uvm_analysis_imp_decl` | N:1 | No | Multiple sources → one checker |
| TLM-2.0 sockets | 1:1 | Yes/No | SystemC interop, bidirectional |

---

## 3.9 Connection Diagram

```
┌──────────┐     analysis_port       ┌──────────────┐
│  Monitor │──────────────────────► │  Scoreboard  │
│          │           │             │  (write())   │
└──────────┘           │             └──────────────┘
                       │
                       │             ┌──────────────┐
                       └───────────► │  Coverage    │
                                     │  (write())   │
                                     └──────────────┘

┌──────────┐  seq_item_port    ┌──────────────┐
│  Driver  │◄──────────────────│  Sequencer   │
│          │  seq_item_export  │              │
└──────────┘                   └──────────────┘
```

---

[&larr; Previous: Phases & Lifecycle](02_uvm_phases.md) | [Next: Sequences & Sequencer &rarr;](04_uvm_sequences.md)
