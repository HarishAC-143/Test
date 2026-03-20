# Chapter 6: UVM Factory

## What Is the Factory?

The UVM factory is a **creation pattern** that decouples object construction from object use. Instead of calling `new()` directly, you use the factory to create objects. This enables **type overrides** and **instance overrides** without modifying any source code.

```
Traditional:   my_driver drv = new("drv", this);         // fixed type
Factory:       my_driver drv = my_driver::type_id::create("drv", this);  // overridable
```

## Why Use the Factory?

1. **Test-specific behavior** — Override a base sequence with a corner-case sequence without touching the environment.
2. **Reusability** — A generic agent can be customized for different projects by swapping components.
3. **Error injection** — Replace a normal driver with one that injects errors.
4. **Debug** — Swap a complex component for a simplified version during debug.

## Registering with the Factory

Every UVM class must be registered with the factory using the appropriate macro:

```systemverilog
// For uvm_component subclasses
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)
  // ...
endclass

// For uvm_object subclasses
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils(my_transaction)
  // ...
endclass
```

### Parameterized Classes

For parameterized classes, use the `_param_utils` variants:

```systemverilog
class generic_driver #(int WIDTH = 8) extends uvm_driver #(generic_txn #(WIDTH));
  `uvm_component_param_utils(generic_driver #(WIDTH))
  // ...
endclass
```

## Creating Objects with the Factory

### Components

```systemverilog
// In build_phase of a parent component:
my_driver drv = my_driver::type_id::create("drv", this);
```

- `"drv"` — instance name in the hierarchy
- `this` — parent component

### Objects (Transactions, Sequences, Configs)

```systemverilog
// Anywhere:
my_transaction tx = my_transaction::type_id::create("tx");
```

- No parent argument (objects don't live in the hierarchy)

---

## Type Overrides

A **type override** replaces **all instances** of one type with another throughout the entire testbench.

### Example: Replacing a Sequence

```systemverilog
// Original sequence
class base_sequence extends uvm_sequence #(my_transaction);
  `uvm_object_utils(base_sequence)
  task body();
    // normal stimulus
  endtask
endclass

// Error-injection sequence
class error_sequence extends base_sequence;
  `uvm_object_utils(error_sequence)
  task body();
    // inject protocol errors
  endtask
endclass

// In the test's build_phase:
class error_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Every create("base_sequence") now returns an error_sequence
    base_sequence::type_id::set_type_override_by_type(
      base_sequence::get_type(),
      error_sequence::get_type()
    );
    env = my_env::type_id::create("env", this);
  endfunction
endclass
```

### Alternative Syntax

```systemverilog
// Using the factory singleton directly
factory.set_type_override_by_type(
  base_sequence::get_type(),
  error_sequence::get_type()
);

// Using string names
factory.set_type_override_by_name("base_sequence", "error_sequence");
```

---

## Instance Overrides

An **instance override** replaces a specific instance (identified by its hierarchical path) while leaving all other instances unchanged.

```systemverilog
class my_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Only the driver inside env.agent1 is replaced
    my_driver::type_id::set_inst_override_by_type(
      my_driver::get_type(),
      slow_driver::get_type(),
      "env.agent1.drv"       // hierarchical path
    );

    env = my_env::type_id::create("env", this);
  endfunction
endclass
```

### Instance Override with Wildcards

```systemverilog
// Override all drivers in all agents
my_driver::type_id::set_inst_override_by_type(
  my_driver::get_type(),
  debug_driver::get_type(),
  "env.*.drv"
);
```

---

## Override Priority

When multiple overrides apply to the same creation, UVM resolves them with these rules:

1. **Instance overrides** take priority over **type overrides**.
2. Among instance overrides, the **most specific path** wins.
3. Among type overrides, the **last one set** wins.
4. Overrides are **chained**: if A is overridden by B, and B is overridden by C, creating A yields C.

---

## Practical Example: Full Override Flow

```systemverilog
// === Base Components ===

class base_driver extends uvm_driver #(my_txn);
  `uvm_component_utils(base_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info("DRV", $sformatf("Base driver: %s", req.convert2string()), UVM_MEDIUM)
      #10;
      seq_item_port.item_done();
    end
  endtask
endclass

// === Override Driver ===

class fast_driver extends base_driver;
  `uvm_component_utils(fast_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_info("DRV", $sformatf("Fast driver: %s", req.convert2string()), UVM_MEDIUM)
      #1;  // faster drive time
      seq_item_port.item_done();
    end
  endtask
endclass

// === Test ===

class fast_test extends base_test;
  `uvm_component_utils(fast_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // Type override: all base_drivers become fast_drivers
    set_type_override_by_type(base_driver::get_type(), fast_driver::get_type());
    super.build_phase(phase);  // env creates fast_driver instead of base_driver
  endfunction
endclass
```

---

## Command-Line Overrides

Overrides can also be applied at runtime via plusargs:

```bash
./simv +uvm_set_type_override=base_driver,fast_driver
./simv +uvm_set_inst_override=env.agent.drv,fast_driver
```

---

## Debugging the Factory

### Print All Registered Types

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  factory.print();
endfunction
```

### Print Active Overrides

```bash
./simv +UVM_TESTNAME=my_test +UVM_VERBOSITY=UVM_DEBUG
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `new()` instead of `type_id::create()` | Always use the factory for creation |
| Forgetting `uvm_component_utils` / `uvm_object_utils` | Register every UVM class |
| Override type is not a subclass of original | Override must extend the original class |
| Setting overrides after `create()` | Set overrides **before** creating objects (early in `build_phase`) |
| Wrong hierarchical path in instance override | Use `uvm_top.print_topology()` to verify paths |

---

## Summary

| Feature | Method |
|---------|--------|
| Create component | `T::type_id::create(name, parent)` |
| Create object | `T::type_id::create(name)` |
| Type override | `T::type_id::set_type_override_by_type(orig, repl)` |
| Instance override | `T::type_id::set_inst_override_by_type(orig, repl, path)` |
| Print factory | `factory.print()` |
| CLI override | `+uvm_set_type_override=orig,repl` |

## Next Steps

Continue to [Chapter 7: Configuration Database](07_config_db.md) to learn how to pass settings across the testbench hierarchy.
