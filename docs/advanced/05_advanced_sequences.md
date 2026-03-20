# Advanced Chapter 5: Advanced Sequences

## Layered Sequences

In protocol stacks (e.g., Ethernet → IP → TCP), higher-layer sequences generate high-level transactions that are broken down into lower-layer transactions.

```
┌─────────────────────┐
│   TCP Sequence       │  Generates TCP segments
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│   IP Sequence        │  Wraps segments in IP packets
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│   Ethernet Sequence  │  Wraps packets in Ethernet frames
└─────────┬───────────┘
          ▼
     Ethernet Driver
```

### Implementation

```systemverilog
// Layer 1: Ethernet frame
class eth_frame extends uvm_sequence_item;
  `uvm_object_utils(eth_frame)
  rand bit [47:0] dst_mac, src_mac;
  rand bit [15:0] ethertype;
  rand byte       payload[];
  constraint c_payload { payload.size() inside {[46:1500]}; }
  function new(string name = "eth_frame"); super.new(name); endfunction
endclass

// Layer 2: IP packet (carried inside Ethernet)
class ip_packet extends uvm_sequence_item;
  `uvm_object_utils(ip_packet)
  rand bit [31:0] src_ip, dst_ip;
  rand bit [7:0]  protocol;
  rand byte       payload[];
  constraint c_payload { payload.size() inside {[20:1460]}; }
  function new(string name = "ip_packet"); super.new(name); endfunction
endclass

// Layered sequencer that translates IP → Ethernet
class ip_to_eth_sequence extends uvm_sequence #(eth_frame);
  `uvm_object_utils(ip_to_eth_sequence)

  uvm_sequencer #(ip_packet) upper_sqr;  // receives IP packets from above

  function new(string name = "ip_to_eth_sequence");
    super.new(name);
  endfunction

  task body();
    ip_packet ip_pkt;
    eth_frame eth;

    forever begin
      upper_sqr.get_next_item(ip_pkt);

      eth = eth_frame::type_id::create("eth");
      start_item(eth);
      eth.dst_mac   = 48'hFF_FF_FF_FF_FF_FF;
      eth.src_mac   = 48'h00_11_22_33_44_55;
      eth.ethertype = 16'h0800;  // IPv4
      eth.payload   = new[ip_pkt.payload.size()];
      foreach (ip_pkt.payload[i]) eth.payload[i] = ip_pkt.payload[i];
      finish_item(eth);

      upper_sqr.item_done();
    end
  endtask
endclass
```

## Pipelined Driver

A standard driver processes one transaction at a time. A **pipelined driver** can have multiple outstanding transactions.

```systemverilog
class pipelined_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(pipelined_driver)

  virtual my_if vif;
  int max_outstanding = 4;
  semaphore pipeline_sem;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    pipeline_sem = new(max_outstanding);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      my_transaction req;
      seq_item_port.get_next_item(req);
      pipeline_sem.get(1);  // limit outstanding transactions

      fork
        begin
          automatic my_transaction tx = req;
          drive_transaction(tx);
          pipeline_sem.put(1);
        end
      join_none

      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(my_transaction tx);
    @(posedge vif.clk);
    vif.addr  <= tx.addr;
    vif.data  <= tx.data;
    vif.valid <= 1;
    @(posedge vif.clk iff vif.ready);
    vif.valid <= 0;
  endtask
endclass
```

## Reactive Sequences

A reactive sequence generates responses based on what the DUT sends. This is common for slave agents.

```systemverilog
class slave_response_seq extends uvm_sequence #(bus_transaction);
  `uvm_object_utils(slave_response_seq)

  bit [31:0] memory [bit [31:0]];

  function new(string name = "slave_response_seq");
    super.new(name);
  endfunction

  task body();
    bus_transaction req, rsp;
    forever begin
      // Wait for a request from the DUT (via the slave sequencer)
      p_sequencer.request_fifo.get(req);

      rsp = bus_transaction::type_id::create("rsp");
      start_item(rsp);

      if (req.write) begin
        memory[req.addr] = req.data;
        rsp.data   = req.data;
        rsp.status = OK;
      end else begin
        if (memory.exists(req.addr)) begin
          rsp.data   = memory[req.addr];
          rsp.status = OK;
        end else begin
          rsp.data   = 32'hDEAD_BEEF;
          rsp.status = ERROR;
        end
      end

      finish_item(rsp);
    end
  endtask
endclass
```

## Sequence Library

A `uvm_sequence_library` automatically selects and runs sequences from a registered pool.

```systemverilog
class my_seq_lib extends uvm_sequence_library #(my_transaction);
  `uvm_object_utils(my_seq_lib)
  `uvm_sequence_library_utils(my_seq_lib)

  function new(string name = "my_seq_lib");
    super.new(name);
    init_sequence_library();
  endfunction
endclass

// Register sequences with the library
class write_seq extends uvm_sequence #(my_transaction);
  `uvm_object_utils(write_seq)
  `uvm_add_to_seq_lib(write_seq, my_seq_lib)

  function new(string name = "write_seq"); super.new(name); endfunction
  task body();
    // ... write stimulus ...
  endtask
endclass

class read_seq extends uvm_sequence #(my_transaction);
  `uvm_object_utils(read_seq)
  `uvm_add_to_seq_lib(read_seq, my_seq_lib)

  function new(string name = "read_seq"); super.new(name); endfunction
  task body();
    // ... read stimulus ...
  endtask
endclass

// Usage in test
task run_phase(uvm_phase phase);
  my_seq_lib lib;
  phase.raise_objection(this);
  lib = my_seq_lib::type_id::create("lib");
  lib.selection_mode = UVM_SEQ_LIB_RAND;  // random selection
  lib.min_random_count = 10;
  lib.max_random_count = 20;
  lib.start(env.agent.sqr);
  phase.drop_objection(this);
endtask
```

### Selection Modes

| Mode | Behavior |
|------|----------|
| `UVM_SEQ_LIB_RAND` | Random selection from the library |
| `UVM_SEQ_LIB_RANDC` | Each sequence runs once before repeating |
| `UVM_SEQ_LIB_ITEM` | Generate individual items (no sequences) |
| `UVM_SEQ_LIB_USER` | User-defined selection in `select_sequence()` |

## Sequence Priority and Arbitration

When multiple sequences run on the same sequencer, arbitration determines which one gets serviced.

```systemverilog
// Set priority when starting a sequence
high_priority_seq.start(sqr, null, 500);   // priority 500 (higher)
low_priority_seq.start(sqr, null, 100);    // priority 100 (lower)

// Set arbitration mode on sequencer
sqr.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);  // highest priority first, FIFO among equals
```

## Lock and Grab

Sequences can **lock** or **grab** a sequencer for exclusive access.

```systemverilog
class exclusive_seq extends uvm_sequence #(my_transaction);
  task body();
    // Lock: wait for current item to finish, then exclusive access
    lock(m_sequencer);
    // ... critical sequence of items ...
    repeat(5) begin
      `uvm_do(req)
    end
    unlock(m_sequencer);

    // Grab: immediate exclusive access (preempts lock)
    grab(m_sequencer);
    // ... urgent sequence ...
    `uvm_do(req)
    ungrab(m_sequencer);
  endtask
endclass
```

| Method | Behavior |
|--------|----------|
| `lock()` | Wait for current item to complete, then exclusive access |
| `unlock()` | Release lock |
| `grab()` | Preempt all other sequences immediately (higher priority than lock) |
| `ungrab()` | Release grab |

## Best Practices

1. **Use hierarchical sequences** to compose complex scenarios from simple building blocks.
2. **Parameterize sequences** with `rand` fields for reusability.
3. **Avoid complex logic in `body()`** — keep sequences focused on stimulus generation.
4. **Use `m_sequencer`** to access configuration in sequences (via `uvm_config_db`).
5. **Consider pipelining** for high-throughput designs where back-to-back transactions are needed.
6. **Use sequence libraries** for regression — they automatically mix different stimulus patterns.

## Next Steps

Continue to [Chapter 6: UVM Patterns and Best Practices](06_best_practices.md) for guidelines on building production-quality testbenches.
