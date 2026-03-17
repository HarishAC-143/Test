# Chapter 5: UVM Sequences

## What Is a Sequence?

A **sequence** is a recipe for generating a stream of transactions. Sequences define the *what* and *when* of stimulus — which transactions to create, in what order, with what constraints.

Think of it this way:
- A **transaction** is a single letter
- A **sequence** is a word, sentence, or paragraph composed of those letters

```
Sequence ─────► Sequencer ─────► Driver ─────► DUT
  (creates          (routes           (converts
   transactions)     transactions)     to signals)
```

## `uvm_sequence` Basics

All sequences extend `uvm_sequence`, parameterized with the transaction type:

```systemverilog
class my_sequence extends uvm_sequence #(my_transaction);
  `uvm_object_utils(my_sequence)
  
  function new(string name = "my_sequence");
    super.new(name);
  endfunction
  
  task body();
    // This is where you generate transactions
  endtask
endclass
```

The `body()` task is the entry point — it runs when the sequence is started on a sequencer.

## Creating and Sending Transactions

The fundamental pattern uses `start_item()` / `finish_item()`:

```systemverilog
task body();
  my_transaction txn;
  
  repeat (20) begin
    txn = my_transaction::type_id::create("txn");
    
    start_item(txn);             // Request arbitration from the sequencer
    assert(txn.randomize());     // Randomize the transaction
    finish_item(txn);            // Send the transaction to the driver
  end
endtask
```

### The `start_item()` / `finish_item()` Protocol

```
Sequence                    Sequencer                   Driver
   │                           │                          │
   │── start_item(txn) ──────►│                          │
   │   (blocks until           │                          │
   │    sequencer grants       │                          │
   │    arbitration)           │                          │
   │                           │                          │
   │   randomize(txn)          │                          │
   │                           │                          │
   │── finish_item(txn) ─────►│── get_next_item(txn) ──►│
   │   (blocks until           │                          │
   │    driver calls           │                          │  (drive DUT)
   │    item_done())           │◄── item_done() ─────────│
   │                           │                          │
   │   (continue to next       │                          │
   │    iteration)             │                          │
```

> **Important:** Always randomize *between* `start_item()` and `finish_item()`. This ensures randomization happens as late as possible, which is critical when sequences interact with each other.

## Sequence Examples

### 1. Simple Random Sequence

```systemverilog
class random_alu_seq extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(random_alu_seq)
  
  rand int unsigned num_txns;
  
  constraint default_count_c {
    num_txns inside {[10:100]};
  }
  
  function new(string name = "random_alu_seq");
    super.new(name);
  endfunction
  
  task body();
    alu_transaction txn;
    
    `uvm_info("SEQ", $sformatf("Generating %0d random transactions", num_txns), UVM_MEDIUM)
    
    repeat (num_txns) begin
      txn = alu_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize());
      finish_item(txn);
    end
  endtask
endclass
```

### 2. Directed Sequence

Sometimes you need exact control over stimulus values:

```systemverilog
class directed_alu_seq extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(directed_alu_seq)
  
  function new(string name = "directed_alu_seq");
    super.new(name);
  endfunction
  
  task body();
    alu_transaction txn;
    
    // Test: 0 + 0 = 0
    txn = alu_transaction::type_id::create("txn");
    start_item(txn);
    txn.operand_a = 8'h00;
    txn.operand_b = 8'h00;
    txn.operation = ADD;
    finish_item(txn);
    
    // Test: FF + 01 = 00 (overflow)
    txn = alu_transaction::type_id::create("txn");
    start_item(txn);
    txn.operand_a = 8'hFF;
    txn.operand_b = 8'h01;
    txn.operation = ADD;
    finish_item(txn);
    
    // Test: 00 - 01 = FF (underflow)
    txn = alu_transaction::type_id::create("txn");
    start_item(txn);
    txn.operand_a = 8'h00;
    txn.operand_b = 8'h01;
    txn.operation = SUB;
    finish_item(txn);
  endtask
endclass
```

### 3. Constrained-Random Sequence

Mix directed control with randomization:

```systemverilog
class add_only_seq extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(add_only_seq)
  
  function new(string name = "add_only_seq");
    super.new(name);
  endfunction
  
  task body();
    alu_transaction txn;
    
    repeat (50) begin
      txn = alu_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with {
        operation == ADD;
        operand_a > 8'h80;  // Focus on large values
      });
      finish_item(txn);
    end
  endtask
endclass
```

The `with { }` clause adds **inline constraints** that apply only to this specific `randomize()` call.

## Composing Sequences

### Hierarchical Sequences

A sequence can start other sequences, creating a hierarchy:

```systemverilog
class full_test_seq extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(full_test_seq)
  
  function new(string name = "full_test_seq");
    super.new(name);
  endfunction
  
  task body();
    directed_alu_seq  directed;
    add_only_seq      add_seq;
    random_alu_seq    random;
    
    // Phase 1: Run directed tests
    `uvm_info("SEQ", "Phase 1: Directed tests", UVM_MEDIUM)
    directed = directed_alu_seq::type_id::create("directed");
    directed.start(m_sequencer);
    
    // Phase 2: Focus on ADD operations
    `uvm_info("SEQ", "Phase 2: ADD-focused tests", UVM_MEDIUM)
    add_seq = add_only_seq::type_id::create("add_seq");
    add_seq.start(m_sequencer);
    
    // Phase 3: Fully random tests
    `uvm_info("SEQ", "Phase 3: Random tests", UVM_MEDIUM)
    random = random_alu_seq::type_id::create("random");
    random.start(m_sequencer);
  endtask
endclass
```

### Parallel Sequences with `fork`/`join`

Run multiple sequences simultaneously:

```systemverilog
task body();
  read_seq  rd_seq;
  write_seq wr_seq;
  
  rd_seq = read_seq::type_id::create("rd_seq");
  wr_seq = write_seq::type_id::create("wr_seq");
  
  fork
    rd_seq.start(m_sequencer);
    wr_seq.start(m_sequencer);
  join
endtask
```

The sequencer automatically arbitrates between the two sequences, interleaving their transactions.

## The `uvm_do` Macros (Shorthand)

UVM provides convenience macros that combine create + start_item + randomize + finish_item:

```systemverilog
task body();
  // These two blocks are equivalent:

  // Explicit approach (recommended for clarity)
  begin
    alu_transaction txn = alu_transaction::type_id::create("txn");
    start_item(txn);
    assert(txn.randomize());
    finish_item(txn);
  end

  // Macro approach (concise but less transparent)
  `uvm_do(txn)

  // With inline constraints
  `uvm_do_with(txn, { operation == ADD; operand_a > 100; })
endtask
```

> **Note:** Many teams avoid the `uvm_do` macros in production code because they hide the create/randomize/start/finish steps and make debugging harder. The explicit approach is preferred for readability.

## Starting Sequences from a Test

To run a sequence on a sequencer from your test's `run_phase`:

```systemverilog
class my_test extends uvm_test;
  `uvm_component_utils(my_test)
  
  my_env env;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    full_test_seq seq;
    
    phase.raise_objection(this);
    
    seq = full_test_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
    
    #100;  // Optional drain time
    
    phase.drop_objection(this);
  endtask
endclass
```

## Using `pre_body()` and `post_body()`

These callbacks run before and after `body()`:

```systemverilog
class my_sequence extends uvm_sequence #(my_transaction);
  `uvm_object_utils(my_sequence)
  
  function new(string name = "my_sequence");
    super.new(name);
  endfunction
  
  task pre_body();
    `uvm_info("SEQ", "Setting up sequence...", UVM_MEDIUM)
  endtask
  
  task body();
    // Generate transactions
  endtask
  
  task post_body();
    `uvm_info("SEQ", "Sequence complete.", UVM_MEDIUM)
  endtask
endclass
```

## Sequence Configuration

Pass configuration to sequences using class fields:

```systemverilog
class configurable_seq extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(configurable_seq)
  
  bit [15:0] base_addr   = 16'h0000;
  int unsigned num_writes = 100;
  int unsigned num_reads  = 100;
  
  function new(string name = "configurable_seq");
    super.new(name);
  endfunction
  
  task body();
    mem_transaction txn;
    
    // Write phase
    repeat (num_writes) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with {
        addr >= base_addr;
        addr < base_addr + 16'h0100;
        write == 1;
      });
      finish_item(txn);
    end
    
    // Read-back phase
    repeat (num_reads) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with {
        addr >= base_addr;
        addr < base_addr + 16'h0100;
        write == 0;
      });
      finish_item(txn);
    end
  endtask
endclass

// In the test:
task run_phase(uvm_phase phase);
  configurable_seq seq;
  phase.raise_objection(this);
  
  seq = configurable_seq::type_id::create("seq");
  seq.base_addr   = 16'h4000;  // Override defaults
  seq.num_writes  = 200;
  seq.start(env.agent.sequencer);
  
  phase.drop_objection(this);
endtask
```

## Summary

| Concept | Description |
|---------|-------------|
| Sequence | A recipe for generating a stream of transactions |
| `body()` | The main task — entry point for the sequence |
| `start_item()` / `finish_item()` | The handshake protocol for sending transactions |
| Inline constraints (`with`) | Add constraints at the point of randomization |
| Hierarchical sequences | A sequence that starts other sequences |
| Parallel sequences | Use `fork`/`join` to run sequences concurrently |
| `uvm_do` macros | Shorthand (but less transparent) for the create-randomize-send pattern |

---

[← Previous: Chapter 4 — Transactions](04_transactions.md) | [Next: Chapter 6 — UVM Phases →](06_phases.md)
