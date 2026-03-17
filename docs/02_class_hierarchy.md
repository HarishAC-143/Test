# Chapter 2: UVM Class Hierarchy & Architecture

## The Big Picture

Every class in UVM ultimately inherits from one of two fundamental base classes. Understanding this split is the key to understanding UVM's architecture.

```
                        uvm_void
                           │
              ┌────────────┴────────────┐
              │                         │
         uvm_object                uvm_port_base
              │
    ┌─────────┴──────────┐
    │                    │
uvm_transaction    uvm_report_object
    │                    │
uvm_sequence_item   uvm_component
                         │
          ┌──────┬───────┼────────┬──────────┐
          │      │       │        │          │
     uvm_test  uvm_env  uvm_agent  uvm_driver  uvm_monitor
                                      │
                                uvm_sequencer
```

## Two Fundamental Categories

### `uvm_object` — Transient Data

`uvm_object` is the base class for **data objects** — things that are created, used, and destroyed during simulation. They do *not* exist in the component hierarchy.

Examples:
- Transactions / sequence items
- Sequences
- Configuration objects
- Register model fields

Key capabilities inherited from `uvm_object`:

| Method | Purpose |
|--------|---------|
| `copy()` | Deep-copy an object |
| `clone()` | Create a new object and copy into it |
| `compare()` | Field-by-field comparison |
| `print()` | Pretty-print all fields |
| `pack()` / `unpack()` | Serialize/deserialize to a bit stream |
| `record()` | Record to a transaction database |

### `uvm_component` — Structural Elements

`uvm_component` is the base class for **structural testbench elements** — things that are built once during the build phase and persist for the entire simulation. They form a hierarchical tree.

Examples:
- Drivers, monitors, sequencers
- Agents, environments
- Scoreboards
- Tests

Key capabilities beyond `uvm_object`:

| Capability | Description |
|------------|-------------|
| **Hierarchy** | Parent-child relationships (`get_parent()`, `get_children()`) |
| **Phasing** | Automatic phase callbacks (`build_phase`, `connect_phase`, `run_phase`, etc.) |
| **Configuration** | Access to `uvm_config_db` with hierarchical paths |
| **Factory** | Support for type overrides via the UVM factory |
| **Reporting** | Built-in verbosity-controlled messaging |

## The UVM Factory

The UVM factory is a design pattern that enables object creation through **type registration** instead of direct construction. This is what makes UVM testbenches reconfigurable without modifying source code.

### Registering with the Factory

Every UVM class should be registered using one of the utility macros:

```systemverilog
// For uvm_object-derived classes (transactions, sequences, configs)
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils(my_transaction)
  // ...
endclass

// For uvm_component-derived classes (drivers, monitors, agents)
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)
  // ...
endclass
```

### Creating Objects Through the Factory

Always use `type_id::create()` instead of `new()`:

```systemverilog
// CORRECT — uses the factory, supports overrides
my_transaction txn = my_transaction::type_id::create("txn");
my_driver      drv = my_driver::type_id::create("drv", this);

// WRONG — bypasses the factory, no override support
my_transaction txn = new("txn");      // Don't do this
my_driver      drv = new("drv", this); // Don't do this
```

### Factory Overrides

The factory lets you substitute one class for another without touching any existing code:

```systemverilog
class error_transaction extends my_transaction;
  `uvm_object_utils(error_transaction)
  
  constraint inject_error_c {
    data == 8'hFF;  // Force specific data value
  }
  
  function new(string name = "error_transaction");
    super.new(name);
  endfunction
endclass

// In your test — override globally
class error_test extends base_test;
  `uvm_component_utils(error_test)
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Every create() of my_transaction now produces error_transaction
    my_transaction::type_id::set_type_override(error_transaction::get_type());
  endfunction
endclass
```

This is extremely powerful — you can change stimulus behavior, replace a driver with a debug version, or swap in a more detailed scoreboard, all from the test level.

## The `uvm_object_utils` and `uvm_component_utils` Macros

These macros do several things behind the scenes:

```systemverilog
`uvm_object_utils(my_class)
// Expands to (approximately):
//   - typedef uvm_object_registry #(my_class, "my_class") type_id;
//   - static function type_id get_type();
//   - virtual function uvm_object_wrapper get_object_type();
//   - virtual function string get_type_name();
```

### Field Automation (Optional)

UVM provides field macros for automatic `copy()`, `compare()`, `print()`, and `pack()` support:

```systemverilog
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils_begin(my_transaction)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_enum(op_t, op, UVM_ALL_ON)
  `uvm_object_utils_end
  
  rand bit [15:0] addr;
  rand bit [31:0] data;
  rand op_t       op;
  
  function new(string name = "my_transaction");
    super.new(name);
  endfunction
endclass
```

> **Note:** The field automation macros are convenient but can cause performance issues in high-volume simulations. Many teams prefer to implement `do_copy()`, `do_compare()`, and `do_print()` manually for production code. We will show both approaches in the examples.

### Manual Implementation (Recommended for Production)

```systemverilog
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils(my_transaction)
  
  rand bit [15:0] addr;
  rand bit [31:0] data;
  rand op_t       op;
  
  function new(string name = "my_transaction");
    super.new(name);
  endfunction
  
  function void do_copy(uvm_object rhs);
    my_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    this.addr = rhs_.addr;
    this.data = rhs_.data;
    this.op   = rhs_.op;
  endfunction
  
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    my_transaction rhs_;
    bit result;
    result = super.do_compare(rhs, comparer);
    $cast(rhs_, rhs);
    result &= (this.addr == rhs_.addr);
    result &= (this.data == rhs_.data);
    result &= (this.op   == rhs_.op);
    return result;
  endfunction
  
  function string convert2string();
    return $sformatf("addr=0x%04h data=0x%08h op=%s", addr, data, op.name());
  endfunction
endclass
```

## Putting It All Together: How the Hierarchy Looks at Runtime

When a UVM simulation runs, the component hierarchy looks like this:

```
uvm_test_top (your_test)
└── env (your_env)
    ├── agent (your_agent)
    │   ├── sequencer (uvm_sequencer)
    │   ├── driver (your_driver)
    │   └── monitor (your_monitor)
    └── scoreboard (your_scoreboard)
```

You can visualize this hierarchy at any time using:

```systemverilog
uvm_top.print_topology();
```

## Summary

| Concept | Key Point |
|---------|-----------|
| `uvm_object` | Base for transient data (transactions, sequences, configs) |
| `uvm_component` | Base for persistent structural elements (drivers, monitors, agents) |
| Factory | Use `type_id::create()` — enables runtime class substitution |
| `uvm_object_utils` | Register objects with the factory |
| `uvm_component_utils` | Register components with the factory |
| Hierarchy | Components form a tree; objects do not |

---

[← Previous: Chapter 1 — Introduction](01_introduction.md) | [Next: Chapter 3 — UVM Components →](03_components.md)
