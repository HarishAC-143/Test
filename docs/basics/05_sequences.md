# Chapter 5: Sequences and Sequence Items

## Overview

Sequences are the primary mechanism for generating stimulus in UVM. The flow is:

```
uvm_sequence  →  generates  →  uvm_sequence_item  →  delivered to  →  uvm_driver
     ↑                              (transaction)                          ↓
     │                                                              drives DUT pins
     └──── started on uvm_sequencer ────────────────────────────────┘
```

## uvm_sequence_item — The Transaction

A sequence item represents a single **transaction**: one bus cycle, one packet, one command. It inherits from `uvm_object` and carries all the data needed by the driver.

```systemverilog
class mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(mem_transaction)

  rand bit [15:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  rand int        delay;

  // Constraints
  constraint c_addr { addr inside {[16'h0000 : 16'h0FFF]}; }
  constraint c_delay { delay inside {[0 : 10]}; }

  function new(string name = "mem_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%04h data=0x%08h delay=%0d",
                     write ? "WR" : "RD", addr, data, delay);
  endfunction

  function void do_copy(uvm_object rhs);
    mem_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    addr  = rhs_.addr;
    data  = rhs_.data;
    write = rhs_.write;
    delay = rhs_.delay;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    mem_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            addr  == rhs_.addr &&
            data  == rhs_.data &&
            write == rhs_.write);
  endfunction
endclass
```

### Key Design Decisions

- **What to randomize**: Include `rand` on fields that represent stimulus variety.
- **Constraints**: Keep default constraints loose; tighten them in derived classes or sequences.
- **`convert2string()`**: Always implement this — it is invaluable for debug.

---

## uvm_sequence — The Stimulus Generator

A sequence produces a stream of sequence items. It runs on a sequencer and communicates with the driver through the sequencer-driver handshake.

### Basic Sequence

```systemverilog
class mem_write_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_write_sequence)

  rand int num_txns;
  constraint c_num { num_txns inside {[5 : 20]}; }

  function new(string name = "mem_write_sequence");
    super.new(name);
  endfunction

  task body();
    mem_transaction tx;
    for (int i = 0; i < num_txns; i++) begin
      tx = mem_transaction::type_id::create($sformatf("tx_%0d", i));
      start_item(tx);        // request grant from sequencer
      if (!tx.randomize() with { write == 1; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(tx);       // send to driver, wait for completion
      `uvm_info("SEQ", tx.convert2string(), UVM_HIGH)
    end
  endtask
endclass
```

### The Sequencer-Driver Handshake

```
Sequence                    Sequencer                   Driver
   │                           │                          │
   │── start_item(tx) ────────▶│                          │
   │   (request grant)         │                          │
   │                           │                          │
   │◀── grant ────────────────│                          │
   │                           │                          │
   │   randomize(tx)           │                          │
   │                           │                          │
   │── finish_item(tx) ───────▶│── get_next_item(tx) ───▶│
   │                           │                          │
   │                           │                    drive signals
   │                           │                          │
   │                           │◀── item_done() ─────────│
   │◀── return ───────────────│                          │
```

### Key Methods

| Method | Where | Purpose |
|--------|-------|---------|
| `start_item(tx)` | Sequence | Request sequencer grant; blocks until granted |
| `finish_item(tx)` | Sequence | Send item to driver; blocks until `item_done()` |
| `get_next_item(tx)` | Driver | Blocking fetch of next item from sequencer |
| `item_done()` | Driver | Signal completion to sequencer and sequence |
| `try_next_item(tx)` | Driver | Non-blocking fetch (returns null if no item) |

---

## Sequence Patterns

### Read-After-Write Sequence

```systemverilog
class mem_read_after_write_seq extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_read_after_write_seq)

  function new(string name = "mem_read_after_write_seq");
    super.new(name);
  endfunction

  task body();
    mem_transaction wr_tx, rd_tx;

    repeat(10) begin
      // Write
      wr_tx = mem_transaction::type_id::create("wr_tx");
      start_item(wr_tx);
      if (!wr_tx.randomize() with { write == 1; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(wr_tx);

      // Read back from the same address
      rd_tx = mem_transaction::type_id::create("rd_tx");
      start_item(rd_tx);
      if (!rd_tx.randomize() with {
        write == 0;
        addr  == wr_tx.addr;
      })
        `uvm_error("RAND", "Randomization failed")
      finish_item(rd_tx);
    end
  endtask
endclass
```

### Walking-Ones Address Sequence (Directed)

```systemverilog
class mem_walking_ones_seq extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_walking_ones_seq)

  function new(string name = "mem_walking_ones_seq");
    super.new(name);
  endfunction

  task body();
    mem_transaction tx;
    for (int i = 0; i < 16; i++) begin
      tx = mem_transaction::type_id::create($sformatf("tx_%0d", i));
      start_item(tx);
      tx.addr  = 16'h1 << i;
      tx.data  = 32'hDEAD_BEEF;
      tx.write = 1;
      tx.delay = 0;
      finish_item(tx);
    end
  endtask
endclass
```

### Hierarchical Sequences (Sequence of Sequences)

```systemverilog
class mem_full_test_seq extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_full_test_seq)

  function new(string name = "mem_full_test_seq");
    super.new(name);
  endfunction

  task body();
    mem_write_sequence      wr_seq;
    mem_read_after_write_seq raw_seq;
    mem_walking_ones_seq    walk_seq;

    `uvm_info("SEQ", "=== Phase 1: Random Writes ===", UVM_LOW)
    wr_seq = mem_write_sequence::type_id::create("wr_seq");
    wr_seq.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 2: Read-After-Write ===", UVM_LOW)
    raw_seq = mem_read_after_write_seq::type_id::create("raw_seq");
    raw_seq.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 3: Walking Ones ===", UVM_LOW)
    walk_seq = mem_walking_ones_seq::type_id::create("walk_seq");
    walk_seq.start(m_sequencer);
  endtask
endclass
```

---

## Using `uvm_do` Macros (Alternative Style)

UVM provides shorthand macros for the start_item/randomize/finish_item pattern:

```systemverilog
task body();
  mem_transaction tx;

  // Simple — randomize with default constraints
  `uvm_do(tx)

  // With inline constraints
  `uvm_do_with(tx, { write == 1; addr < 16'h100; })

  // On a specific sequencer
  `uvm_do_on(tx, target_sequencer)

  // With constraints on a specific sequencer
  `uvm_do_on_with(tx, target_sequencer, { write == 0; })
endtask
```

### Pros and Cons of `uvm_do` Macros

| Pros | Cons |
|------|------|
| Concise syntax | Hides the handshake mechanism |
| Less boilerplate | Harder to debug |
| Good for simple cases | Cannot insert logic between start_item and finish_item |

**Recommendation**: Use explicit `start_item`/`finish_item` for complex sequences; `uvm_do` macros for simple cases.

---

## Sequence Item Responses

When the DUT returns data (e.g., a read response), the driver can send it back to the sequence:

### Driver Side

```systemverilog
task run_phase(uvm_phase phase);
  mem_transaction req, rsp;
  forever begin
    seq_item_port.get_next_item(req);
    drive_transaction(req);

    // Send response back to sequence
    $cast(rsp, req.clone());
    rsp.data = vif.rdata;          // capture read data
    rsp.set_id_info(req);          // link response to request
    seq_item_port.item_done(rsp);  // pass response back
  end
endtask
```

### Sequence Side

```systemverilog
task body();
  mem_transaction tx;
  tx = mem_transaction::type_id::create("tx");
  start_item(tx);
  tx.randomize() with { write == 0; };
  finish_item(tx);

  // Get response from driver
  get_response(rsp);
  `uvm_info("SEQ", $sformatf("Read data = 0x%08h", rsp.data), UVM_MEDIUM)
endtask
```

---

## Starting Sequences from a Test

```systemverilog
class my_test extends uvm_test;
  `uvm_component_utils(my_test)

  my_env env;

  function new(string name = "my_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    mem_full_test_seq seq;
    phase.raise_objection(this);

    seq = mem_full_test_seq::type_id::create("seq");
    seq.start(env.agent.sqr);  // start sequence on the agent's sequencer

    phase.drop_objection(this);
  endtask
endclass
```

---

## Default Sequences (Legacy Approach)

Older UVM code sets a default sequence via `uvm_config_db`:

```systemverilog
// In build_phase of the test:
uvm_config_db #(uvm_object_wrapper)::set(this,
  "env.agent.sqr.main_phase",
  "default_sequence",
  mem_write_sequence::type_id::get());
```

**Modern practice**: Start sequences explicitly from the test's `run_phase` as shown above. It is clearer and easier to debug.

---

## Summary

| Concept | Key Class/Method |
|---------|-----------------|
| Transaction | `uvm_sequence_item` with `rand` fields and constraints |
| Sequence | `uvm_sequence#(T)` with `body()` task |
| Send to driver | `start_item()` → randomize → `finish_item()` |
| Receive in driver | `get_next_item()` → drive → `item_done()` |
| Compose sequences | Call `sub_seq.start(m_sequencer)` |
| Response | `item_done(rsp)` in driver, `get_response(rsp)` in sequence |
| Start from test | `seq.start(env.agent.sqr)` in `run_phase` |

## Next Steps

Continue to [Chapter 6: UVM Factory](06_factory.md) to learn about runtime object creation and overrides.
