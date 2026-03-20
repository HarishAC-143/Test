# 4. UVM Sequences & Sequencer

[&larr; Previous: TLM & Communication](03_uvm_tlm.md) | [Back to Main](../README.md) | [Next: Configuration & Factory &rarr;](05_uvm_config_factory.md)

---

## 4.1 Overview

In UVM, **sequences** are the primary mechanism for generating stimulus. The stimulus generation is separated from the stimulus driving:

| Component | Responsibility |
|-----------|---------------|
| **Sequence Item** (`uvm_sequence_item`) | Data container — one transaction |
| **Sequence** (`uvm_sequence`) | Generates a stream of sequence items |
| **Sequencer** (`uvm_sequencer`) | Arbitrates between sequences, feeds items to the driver |
| **Driver** (`uvm_driver`) | Converts items into pin-level signals |

### Data Flow

```
Sequence ──► Sequencer ──► Driver ──► DUT
   │              ▲           │
   │              │           │
   └──(items)─────┘    (pin signals)
```

---

## 4.2 Sequence Items

A sequence item defines the fields of a single transaction.

```systemverilog
class apb_txn extends uvm_sequence_item;

  `uvm_object_utils_begin(apb_txn)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(data,   UVM_ALL_ON)
    `uvm_field_enum(apb_dir_e, dir, UVM_ALL_ON)
  `uvm_object_utils_end

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand apb_dir_e  dir;   // READ or WRITE

  constraint addr_aligned {
    addr[1:0] == 2'b00;  // word-aligned
  }

  constraint valid_addr_range {
    addr inside {[32'h0000_0000 : 32'h0000_0FFF]};
  }

  function new(string name = "apb_txn");
    super.new(name);
  endfunction

endclass
```

### Useful Built-in Methods (from field macros)

```systemverilog
apb_txn t1, t2;
t1 = apb_txn::type_id::create("t1");
t1.randomize();

t2 = apb_txn::type_id::create("t2");
t2.copy(t1);           // deep copy
t1.compare(t2);        // returns 1 if equal
t1.print();            // display fields
t1.sprint();           // return string representation
t1.pack_bytes(bytes);  // serialize
t2.unpack_bytes(bytes);// deserialize
```

---

## 4.3 Basic Sequences

A sequence generates one or more sequence items and sends them to the sequencer.

### Simple Sequence

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_txn);

  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_txn txn;

    txn = apb_txn::type_id::create("txn");

    start_item(txn);             // request arbitration from sequencer
    if (!txn.randomize() with {
      txn.addr == local::addr;
      txn.data == local::data;
      txn.dir  == WRITE;
    }) `uvm_fatal("RAND", "Randomization failed")
    finish_item(txn);            // send to driver and wait for completion

  endtask

endclass
```

### Multi-Transaction Sequence

```systemverilog
class apb_burst_write_seq extends uvm_sequence #(apb_txn);

  `uvm_object_utils(apb_burst_write_seq)

  rand int unsigned num_txns;
  rand bit [31:0]   base_addr;

  constraint defaults {
    num_txns inside {[4:16]};
    base_addr[1:0] == 2'b00;
  }

  function new(string name = "apb_burst_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_txn txn;

    for (int i = 0; i < num_txns; i++) begin
      txn = apb_txn::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize() with {
        txn.addr == base_addr + (i * 4);
        txn.dir  == WRITE;
      }) `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);
    end

    `uvm_info("SEQ", $sformatf("Completed %0d writes starting at 0x%08h",
              num_txns, base_addr), UVM_MEDIUM)
  endtask

endclass
```

---

## 4.4 The `start_item` / `finish_item` Handshake

This is the core mechanism for sending items from a sequence to the driver:

```
Sequence                    Sequencer                   Driver
   │                           │                          │
   │── start_item(txn) ──────►│                          │
   │   (waits for grant)       │                          │
   │                           │◄── get_next_item() ─────│
   │◄── grant ────────────────│                          │
   │                           │                          │
   │   randomize txn           │                          │
   │                           │                          │
   │── finish_item(txn) ─────►│──── deliver txn ────────►│
   │   (waits for item_done)   │                          │
   │                           │◄── item_done() ─────────│
   │◄── done ─────────────────│                          │
```

### Alternative: `uvm_do` Macros

For simple cases, macros combine creation + randomization + start/finish:

```systemverilog
virtual task body();
  apb_txn txn;

  // Basic: create, randomize, send
  `uvm_do(txn)

  // With inline constraints
  `uvm_do_with(txn, { txn.dir == WRITE; txn.addr == 32'h100; })

  // On a specific sequencer
  `uvm_do_on(txn, target_sequencer)

  // With constraints on a specific sequencer
  `uvm_do_on_with(txn, target_sequencer, { txn.dir == READ; })
endtask
```

> **Note:** Many teams prefer the explicit `start_item`/`finish_item` style over macros for clarity and debuggability.

---

## 4.5 Sequence Hierarchy — Composing Sequences

Sequences can start other sequences, enabling layered stimulus generation.

```systemverilog
class apb_write_read_seq extends uvm_sequence #(apb_txn);

  `uvm_object_utils(apb_write_read_seq)

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_seq wr_seq;
    apb_read_seq  rd_seq;

    // Write a value
    wr_seq = apb_write_seq::type_id::create("wr_seq");
    wr_seq.addr = 32'h0000_0100;
    wr_seq.data = 32'hDEAD_BEEF;
    wr_seq.start(m_sequencer);  // run on the same sequencer

    // Read it back
    rd_seq = apb_read_seq::type_id::create("rd_seq");
    rd_seq.addr = 32'h0000_0100;
    rd_seq.start(m_sequencer);

    // Check result
    if (rd_seq.rdata != 32'hDEAD_BEEF)
      `uvm_error("SEQ", $sformatf("Read-back mismatch: expected 0x%08h, got 0x%08h",
                 32'hDEAD_BEEF, rd_seq.rdata))
  endtask

endclass
```

### Starting from a Test

```systemverilog
class apb_test extends uvm_test;
  `uvm_component_utils(apb_test)

  apb_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_read_seq seq;

    phase.raise_objection(this);

    seq = apb_write_read_seq::type_id::create("seq");
    seq.start(env.agt.sqr);  // start sequence on the agent's sequencer

    phase.drop_objection(this);
  endtask
endclass
```

---

## 4.6 Virtual Sequences

A **virtual sequence** coordinates multiple sequences across multiple sequencers. It doesn't send items itself — it orchestrates sub-sequences.

```systemverilog
class system_virtual_seq extends uvm_sequence #(uvm_sequence_item);

  `uvm_object_utils(system_virtual_seq)

  // Handles to sequencers (set by the test or virtual sequencer)
  apb_sequencer  apb_sqr;
  axi_sequencer  axi_sqr;
  spi_sequencer  spi_sqr;

  function new(string name = "system_virtual_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_config_seq  apb_seq;
    axi_data_seq    axi_seq;
    spi_transfer_seq spi_seq;

    // Phase 1: Configure DUT via APB
    apb_seq = apb_config_seq::type_id::create("apb_seq");
    apb_seq.start(apb_sqr);

    // Phase 2: Run AXI and SPI traffic in parallel
    fork
      begin
        axi_seq = axi_data_seq::type_id::create("axi_seq");
        axi_seq.start(axi_sqr);
      end
      begin
        spi_seq = spi_transfer_seq::type_id::create("spi_seq");
        spi_seq.start(spi_sqr);
      end
    join

    `uvm_info("VSEQ", "All sub-sequences completed", UVM_LOW)
  endtask

endclass
```

### Virtual Sequencer

A virtual sequencer holds handles to real sequencers:

```systemverilog
class system_virtual_sequencer extends uvm_sequencer;

  `uvm_component_utils(system_virtual_sequencer)

  apb_sequencer apb_sqr;
  axi_sequencer axi_sqr;
  spi_sequencer spi_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
```

### Wiring in the Environment

```systemverilog
class system_env extends uvm_env;
  // ...
  system_virtual_sequencer v_sqr;

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    v_sqr.apb_sqr = apb_agt.sqr;
    v_sqr.axi_sqr = axi_agt.sqr;
    v_sqr.spi_sqr = spi_agt.sqr;
  endfunction
endclass
```

---

## 4.7 Sequencer Arbitration

When multiple sequences run on the same sequencer, the sequencer must arbitrate between them.

### Arbitration Modes

```systemverilog
// Set arbitration mode on the sequencer
env.agt.sqr.set_arbitration(UVM_SEQ_ARB_FIFO);      // default — first come, first served
env.agt.sqr.set_arbitration(UVM_SEQ_ARB_RANDOM);     // random selection
env.agt.sqr.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);// priority-based, FIFO within priority
env.agt.sqr.set_arbitration(UVM_SEQ_ARB_STRICT_RANDOM);// priority-based, random within priority
env.agt.sqr.set_arbitration(UVM_SEQ_ARB_WEIGHTED);   // weighted random by priority
env.agt.sqr.set_arbitration(UVM_SEQ_ARB_USER);       // custom arbitration
```

### Setting Priority

```systemverilog
task run_phase(uvm_phase phase);
  high_priority_seq h_seq;
  low_priority_seq  l_seq;

  phase.raise_objection(this);

  fork
    begin
      h_seq = high_priority_seq::type_id::create("h_seq");
      h_seq.start(env.agt.sqr, null, 500);  // priority = 500 (higher)
    end
    begin
      l_seq = low_priority_seq::type_id::create("l_seq");
      l_seq.start(env.agt.sqr, null, 100);  // priority = 100 (lower)
    end
  join

  phase.drop_objection(this);
endtask
```

---

## 4.8 Sequence Library

UVM provides `uvm_sequence_library` for managing collections of sequences:

```systemverilog
class my_seq_lib extends uvm_sequence_library #(apb_txn);

  `uvm_object_utils(my_seq_lib)
  `uvm_sequence_library_utils(my_seq_lib)

  function new(string name = "my_seq_lib");
    super.new(name);
    init_sequence_library();
  endfunction

endclass

// Register sequences with the library
class apb_write_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_write_seq)
  `uvm_add_to_seq_lib(apb_write_seq, my_seq_lib)
  // ...
endclass

class apb_read_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_read_seq)
  `uvm_add_to_seq_lib(apb_read_seq, my_seq_lib)
  // ...
endclass
```

### Running the Library

```systemverilog
task run_phase(uvm_phase phase);
  my_seq_lib lib;

  phase.raise_objection(this);

  lib = my_seq_lib::type_id::create("lib");
  lib.selection_mode = UVM_SEQ_LIB_RAND;  // or RANDC, ITEM, USER
  lib.min_random_count = 10;
  lib.max_random_count = 20;
  lib.start(env.agt.sqr);

  phase.drop_objection(this);
endtask
```

---

## 4.9 Response Handling

Sometimes the driver needs to send a response back to the sequence (e.g., read data).

### Method 1: Modifying the Request Item

```systemverilog
// In the driver:
task run_phase(uvm_phase phase);
  apb_txn txn;
  forever begin
    seq_item_port.get_next_item(txn);
    // Drive and capture response
    drive_and_capture(txn);
    txn.data = vif.rdata;  // store response in the same item
    seq_item_port.item_done();
  end
endtask

// In the sequence:
task body();
  apb_txn txn;
  start_item(txn);
  txn.randomize() with { dir == READ; addr == 32'h100; };
  finish_item(txn);
  // txn.data now contains the read response
  `uvm_info("SEQ", $sformatf("Read data: 0x%08h", txn.data), UVM_MEDIUM)
endtask
```

### Method 2: Separate Response Item

```systemverilog
// In the driver:
task run_phase(uvm_phase phase);
  apb_txn req, rsp;
  forever begin
    seq_item_port.get_next_item(req);
    drive(req);
    rsp = apb_txn::type_id::create("rsp");
    rsp.set_id_info(req);  // link response to request
    rsp.data = vif.rdata;
    seq_item_port.item_done(rsp);
  end
endtask

// In the sequence:
task body();
  apb_txn req;
  start_item(req);
  req.randomize() with { dir == READ; };
  finish_item(req);
  get_response(rsp);  // get response from driver
endtask
```

---

## 4.10 Sequence Callbacks

### `pre_do` / `mid_do` / `post_do`

These callbacks let you inject behavior around item execution:

```systemverilog
class my_sequence extends uvm_sequence #(apb_txn);
  // ...

  virtual task pre_do(bit is_item);
    // Called before randomization
    `uvm_info("SEQ", "About to randomize item", UVM_HIGH)
  endtask

  virtual function void mid_do(uvm_sequence_item this_item);
    // Called after randomization, before sending to driver
    `uvm_info("SEQ", "Item randomized, about to send", UVM_HIGH)
  endfunction

  virtual function void post_do(uvm_sequence_item this_item);
    // Called after driver completes the item
    `uvm_info("SEQ", "Item completed by driver", UVM_HIGH)
  endfunction
endclass
```

---

## 4.11 Summary

| Concept | Purpose |
|---------|---------|
| `uvm_sequence_item` | Single transaction (data + constraints) |
| `uvm_sequence` | Generates ordered stream of items |
| `start_item`/`finish_item` | Handshake with sequencer/driver |
| `` `uvm_do `` / `` `uvm_do_with `` | Convenience macros for item generation |
| Virtual sequence | Coordinates sequences across multiple sequencers |
| Virtual sequencer | Holds handles to real sequencers |
| Arbitration | Controls which sequence gets access when multiple compete |
| Sequence library | Collection of sequences for random selection |
| Response handling | Driver sends data back to sequence |

---

[&larr; Previous: TLM & Communication](03_uvm_tlm.md) | [Next: Configuration & Factory &rarr;](05_uvm_config_factory.md)
