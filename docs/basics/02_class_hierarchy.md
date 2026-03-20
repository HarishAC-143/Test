# Chapter 2: UVM Class Hierarchy

## Overview

Every class in UVM ultimately inherits from one of two base classes:

- **`uvm_object`** — for data objects that have no position in the testbench hierarchy (transactions, sequences, configuration objects).
- **`uvm_component`** — for structural components that live in a tree and persist for the entire simulation (drivers, monitors, agents, environments, tests).

`uvm_component` itself extends `uvm_object`, so all UVM classes share a common root.

## The Complete Class Tree

```
uvm_void
  └── uvm_object
        ├── uvm_transaction
        │     └── uvm_sequence_item
        │           └── uvm_sequence_base
        │                 └── uvm_sequence #(REQ, RSP)
        ├── uvm_reg_item
        ├── uvm_reg_block
        ├── uvm_reg
        ├── uvm_reg_field
        ├── uvm_mem
        └── uvm_component
              ├── uvm_test
              ├── uvm_env
              ├── uvm_agent
              ├── uvm_driver #(REQ, RSP)
              ├── uvm_monitor
              ├── uvm_sequencer_base
              │     └── uvm_sequencer #(REQ, RSP)
              ├── uvm_scoreboard
              └── uvm_subscriber #(T)
```

## uvm_object — The Data Base Class

`uvm_object` provides the core **data operations** that every UVM object needs:

| Method | Purpose |
|--------|---------|
| `copy()` | Deep-copy one object into another |
| `clone()` | Create a new object and copy contents |
| `compare()` | Field-by-field comparison of two objects |
| `print()` | Formatted display of all fields |
| `pack()` / `unpack()` | Serialize / deserialize to a bit stream |
| `record()` | Record fields for waveform or database |
| `create()` | Factory-aware object construction |

### Example: Custom Object

```systemverilog
class my_config extends uvm_object;
  `uvm_object_utils(my_config)

  int unsigned num_transactions = 100;
  bit enable_coverage = 1;
  bit enable_checks = 1;

  function new(string name = "my_config");
    super.new(name);
  endfunction

  function void do_copy(uvm_object rhs);
    my_config rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs))
      `uvm_fatal("CAST", "Failed to cast rhs to my_config")
    num_transactions = rhs_.num_transactions;
    enable_coverage  = rhs_.enable_coverage;
    enable_checks    = rhs_.enable_checks;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    my_config rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            num_transactions == rhs_.num_transactions &&
            enable_coverage  == rhs_.enable_coverage &&
            enable_checks    == rhs_.enable_checks);
  endfunction

  function string convert2string();
    return $sformatf("num_transactions=%0d, coverage=%0b, checks=%0b",
                     num_transactions, enable_coverage, enable_checks);
  endfunction
endclass
```

### When to Use `uvm_object`

- Configuration objects
- Transactions / sequence items (via `uvm_sequence_item`)
- Sequences (via `uvm_sequence`)
- Any data container that does not need to be part of the component hierarchy

## uvm_component — The Structural Base Class

`uvm_component` adds hierarchical structure on top of `uvm_object`:

| Feature | Description |
|---------|-------------|
| **Hierarchy** | Parent-child tree; every component has a unique path string like `uvm_test_top.env.agent.driver` |
| **Phases** | Automatic phase execution (build, connect, run, etc.) |
| **Factory** | Creation through the factory with `type_id::create()` |
| **Config DB** | Access to `uvm_config_db` via the component's context |
| **Reporting** | Component-aware messaging with automatic ID tagging |

### Example: Custom Component

```systemverilog
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  uvm_analysis_port #(my_transaction) ap;
  virtual my_interface vif;

  function new(string name = "my_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual my_interface)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      my_transaction tx;
      // Sample signals on the interface and create a transaction
      @(posedge vif.clk);
      if (vif.valid) begin
        tx = my_transaction::type_id::create("tx");
        tx.addr = vif.addr;
        tx.data = vif.data;
        tx.wr   = vif.wr;
        ap.write(tx);  // broadcast to subscribers
      end
    end
  endtask
endclass
```

## Key Differences: uvm_object vs. uvm_component

| Feature | `uvm_object` | `uvm_component` |
|---------|-------------|-----------------|
| Hierarchy | No parent/child | Lives in a named tree |
| Lifetime | Can be created/destroyed any time | Created during `build_phase`, persists until end |
| Phases | None | Full phase support |
| Registration macro | `uvm_object_utils` | `uvm_component_utils` |
| Constructor | `new(string name)` | `new(string name, uvm_component parent)` |
| Typical use | Data, transactions, configs | Drivers, monitors, agents, envs |

## The `uvm_component_utils` and `uvm_object_utils` Macros

These macros serve two purposes:

1. **Factory registration** — enables `type_id::create()` and type/instance overrides.
2. **Type identification** — provides `get_type_name()` and supports printing/comparison.

### Field Automation (Legacy)

Older UVM code uses `uvm_field_*` macros inside the utils block:

```systemverilog
class my_txn extends uvm_sequence_item;
  `uvm_object_utils_begin(my_txn)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_enum(op_t, op, UVM_ALL_ON)
  `uvm_object_utils_end
  // ...
endclass
```

**Modern best practice**: Avoid `uvm_field_*` macros. They generate a lot of hidden code and can hurt simulation performance. Instead, manually implement `do_copy()`, `do_compare()`, `do_print()`, and `convert2string()` as shown in the `my_config` example above.

## Parameterized Classes

Several UVM base classes are parameterized:

```systemverilog
class uvm_driver      #(type REQ = uvm_sequence_item, type RSP = REQ) extends uvm_component;
class uvm_sequencer   #(type REQ = uvm_sequence_item, type RSP = REQ) extends uvm_sequencer_base;
class uvm_sequence    #(type REQ = uvm_sequence_item, type RSP = REQ) extends uvm_sequence_base;
class uvm_subscriber  #(type T = int) extends uvm_component;
```

When you define your own driver, sequencer, or sequence, you typically specialize them on your transaction type:

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  // ...
endclass

class my_sequencer extends uvm_sequencer #(my_transaction);
  // ...
endclass
```

## Summary

- **Everything** in UVM descends from `uvm_object`.
- Use **`uvm_object`** subclasses for data: transactions, sequences, configurations.
- Use **`uvm_component`** subclasses for structure: drivers, monitors, agents, envs, tests.
- Register every class with the appropriate **`uvm_*_utils`** macro.
- Prefer **manual** `do_*` methods over `uvm_field_*` macros.

## Next Steps

Continue to [Chapter 3: UVM Components Deep Dive](03_components.md) to learn about each component type in detail.
