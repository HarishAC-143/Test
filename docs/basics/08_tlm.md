# Chapter 8: TLM (Transaction Level Modeling)

## What Is TLM?

TLM (Transaction Level Modeling) is UVM's mechanism for **inter-component communication**. Instead of passing data through global variables or hierarchical references, components communicate through well-defined **ports** and **exports**.

TLM abstracts communication to the transaction level — components send and receive complete transactions rather than individual signals.

## TLM Port Types

```
┌──────────────────────────────────────────────┐
│              TLM Port Types                   │
├──────────────────────────────────────────────┤
│                                              │
│  Port (initiator)  ──────►  Export (target)  │
│                                              │
│  Analysis Port     ──────►  Analysis Export  │
│  (1-to-many broadcast)      (subscriber)     │
│                                              │
│  Port  ──► TLM FIFO ──►  Export             │
│  (decoupled producer/consumer)               │
│                                              │
└──────────────────────────────────────────────┘
```

## 1. Point-to-Point TLM: Ports and Exports

### Blocking Put Port

The producer calls `put()` which blocks until the consumer accepts the transaction.

```systemverilog
// Producer
class producer extends uvm_component;
  `uvm_component_utils(producer)

  uvm_blocking_put_port #(my_transaction) put_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    put_port = new("put_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_transaction tx;
    repeat(10) begin
      tx = my_transaction::type_id::create("tx");
      tx.randomize();
      put_port.put(tx);  // blocking call
    end
  endtask
endclass

// Consumer
class consumer extends uvm_component;
  `uvm_component_utils(consumer)

  uvm_blocking_put_imp #(my_transaction, consumer) put_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    put_export = new("put_export", this);
  endfunction

  task put(my_transaction tx);
    `uvm_info("CON", $sformatf("Received: %s", tx.convert2string()), UVM_MEDIUM)
    #10;  // simulate processing time
  endtask
endclass

// Connection in parent env
function void connect_phase(uvm_phase phase);
  producer.put_port.connect(consumer.put_export);
endfunction
```

### Blocking Get Port

The consumer calls `get()` to pull transactions from the producer.

```systemverilog
class consumer extends uvm_component;
  uvm_blocking_get_port #(my_transaction) get_port;

  task run_phase(uvm_phase phase);
    my_transaction tx;
    forever begin
      get_port.get(tx);  // blocking call
      process_transaction(tx);
    end
  endtask
endclass
```

### Port/Export/Imp Naming Convention

| Class | Role | Who creates it |
|-------|------|---------------|
| `uvm_*_port` | Initiator (caller) | Component that initiates the call |
| `uvm_*_export` | Intermediate pass-through | Component in the middle of the hierarchy |
| `uvm_*_imp` | Implementation (callee) | Component that implements the method |

Connection rules:
- **Port** connects to **Export** or **Imp**
- **Export** connects to **Export** or **Imp**
- **Imp** is always the terminal endpoint

---

## 2. Analysis Ports (Broadcast)

Analysis ports are the most commonly used TLM mechanism in UVM. They provide **one-to-many broadcast** communication.

### Characteristics

- **Non-blocking**: `write()` is a function, not a task (zero time)
- **One-to-many**: Multiple subscribers can connect to a single analysis port
- **No back-pressure**: The sender does not wait for receivers

### Monitor Broadcasting to Subscribers

```systemverilog
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  uvm_analysis_port #(my_transaction) ap;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      my_transaction tx = my_transaction::type_id::create("tx");
      // ... sample DUT signals into tx ...
      ap.write(tx);  // broadcast to all connected subscribers
    end
  endtask
endclass
```

### Scoreboard Receiving via Analysis Imp

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp #(my_transaction, my_scoreboard) analysis_export;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // This function is called automatically when monitor writes
  function void write(my_transaction tx);
    check_transaction(tx);
  endfunction
endclass
```

### Multiple Analysis Imps in One Component

When a component needs to receive from multiple analysis ports, use the `uvm_analysis_imp_decl` macro:

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp_expected #(my_transaction, my_scoreboard) expected_export;
  uvm_analysis_imp_actual   #(my_transaction, my_scoreboard) actual_export;

  my_transaction expected_queue[$];

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_export = new("expected_export", this);
    actual_export   = new("actual_export", this);
  endfunction

  function void write_expected(my_transaction tx);
    expected_queue.push_back(tx);
  endfunction

  function void write_actual(my_transaction tx);
    my_transaction exp;
    if (expected_queue.size() == 0) begin
      `uvm_error("SB", "Unexpected transaction received")
      return;
    end
    exp = expected_queue.pop_front();
    if (!tx.compare(exp))
      `uvm_error("SB", $sformatf("Mismatch: exp=%s got=%s",
                                   exp.convert2string(), tx.convert2string()))
    else
      `uvm_info("SB", "Match!", UVM_HIGH)
  endfunction
endclass
```

---

## 3. TLM FIFOs

TLM FIFOs decouple the producer and consumer in time — the producer can write without waiting for the consumer to read.

### uvm_tlm_analysis_fifo

The most commonly used FIFO. It connects to an analysis port on one side and provides a blocking get port on the other.

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_tlm_analysis_fifo #(my_transaction) expected_fifo;
  uvm_tlm_analysis_fifo #(my_transaction) actual_fifo;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_transaction exp_tx, act_tx;
    forever begin
      expected_fifo.get(exp_tx);  // blocking get from FIFO
      actual_fifo.get(act_tx);    // blocking get from FIFO

      if (!exp_tx.compare(act_tx))
        `uvm_error("SB", $sformatf("Mismatch!\n  EXP: %s\n  ACT: %s",
                   exp_tx.convert2string(), act_tx.convert2string()))
      else
        `uvm_info("SB", "Transaction match", UVM_HIGH)
    end
  endtask
endclass

// Connection in env
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  // reference model output → expected_fifo
  ref_model.ap.connect(scoreboard.expected_fifo.analysis_export);
  // monitor output → actual_fifo
  agent.mon.ap.connect(scoreboard.actual_fifo.analysis_export);
endfunction
```

### uvm_tlm_fifo

A general-purpose FIFO with put and get interfaces (not connected to analysis ports):

```systemverilog
uvm_tlm_fifo #(my_transaction) fifo;

// Producer writes
fifo.put(tx);       // blocking
fifo.try_put(tx);   // non-blocking, returns 1 on success

// Consumer reads
fifo.get(tx);       // blocking
fifo.try_get(tx);   // non-blocking, returns 1 on success

// Check FIFO status
fifo.is_empty();
fifo.is_full();
fifo.used();        // number of items in FIFO
```

---

## 4. The Sequencer-Driver TLM Connection

The sequencer-driver handshake uses a specialized TLM port:

```systemverilog
// Built into uvm_driver:
uvm_seq_item_pull_port #(REQ, RSP) seq_item_port;

// Built into uvm_sequencer:
uvm_seq_item_pull_imp #(REQ, RSP, uvm_sequencer) seq_item_export;

// Connection in agent's connect_phase:
drv.seq_item_port.connect(sqr.seq_item_export);
```

---

## TLM Connection Summary

```
Monitor ──(analysis_port)──►──(analysis_export)── Scoreboard
                              ──(analysis_export)── Coverage

Driver ──(seq_item_port)──►──(seq_item_export)── Sequencer

Producer ──(put_port)──►──(put_imp)── Consumer

Producer ──(analysis_port)──►──(analysis_export)── TLM_FIFO ──(get_port)── Consumer
```

---

## Debugging TLM Connections

### Check Connection Status

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  // Verify all ports are connected
  if (!drv.seq_item_port.size())
    `uvm_warning("CONN", "Driver seq_item_port has no connections")
endfunction
```

### Print Topology

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  uvm_top.print_topology();
endfunction
```

---

## Summary

| TLM Type | Direction | Blocking | Use Case |
|----------|-----------|----------|----------|
| `uvm_analysis_port` | 1-to-many broadcast | Non-blocking (function) | Monitor → Scoreboard, Coverage |
| `uvm_blocking_put_port` | 1-to-1 | Blocking (task) | Producer → Consumer |
| `uvm_blocking_get_port` | 1-to-1 | Blocking (task) | Consumer ← Producer |
| `uvm_tlm_analysis_fifo` | 1-to-1 (buffered) | Mixed | Decoupled analysis |
| `uvm_tlm_fifo` | 1-to-1 (buffered) | Mixed | General buffered channel |
| `seq_item_port` | 1-to-1 | Blocking | Driver ↔ Sequencer |

## Next Steps

Continue to [Chapter 9: Reporting and Messaging](09_reporting.md) to learn about UVM's built-in messaging system.
