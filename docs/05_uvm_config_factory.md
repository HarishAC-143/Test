# 5. UVM Configuration Database & Factory

[&larr; Previous: Sequences & Sequencer](04_uvm_sequences.md) | [Back to Main](../README.md) | [Next: Advanced Topics &rarr;](06_uvm_advanced.md)

---

## 5.1 The Configuration Database (`uvm_config_db`)

The configuration database is a **global key-value store** that allows components to share configuration data without hard-coded connections. It is the primary mechanism for passing virtual interfaces, configuration objects, and scalar values between components.

### API

```systemverilog
// Store a value
uvm_config_db#(T)::set(uvm_component context, string inst_name, string field_name, T value);

// Retrieve a value
uvm_config_db#(T)::get(uvm_component context, string inst_name, string field_name, ref T value);
```

### Parameters Explained

| Parameter | Description |
|-----------|-------------|
| `T` | The type of value being stored/retrieved |
| `context` | The component setting/getting the value (`this`, or `null` for global) |
| `inst_name` | Hierarchical path to target components (supports wildcards) |
| `field_name` | The key name for the value |
| `value` | The data to store or variable to receive it |

---

## 5.2 Passing Virtual Interfaces

The most common use of `uvm_config_db` is passing virtual interfaces from the top-level module into the testbench.

### Setting (in `tb_top`)

```systemverilog
module tb_top;
  // ...
  apb_if aif(clk, rst_n);

  initial begin
    // Make interface available to ALL components matching "*"
    uvm_config_db#(virtual apb_if)::set(null, "*", "apb_vif", aif);
    run_test();
  end
endmodule
```

### Getting (in driver/monitor)

```systemverilog
class apb_driver extends uvm_driver #(apb_txn);
  virtual apb_if vif;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("CFG", "Virtual interface 'apb_vif' not found in config_db")
  endfunction
endclass
```

### Path Matching

```systemverilog
// Set for ALL components
uvm_config_db#(int)::set(null, "*", "timeout", 1000);

// Set for a specific agent
uvm_config_db#(int)::set(this, "env.agt", "is_active", UVM_ACTIVE);

// Set for all monitors under any agent
uvm_config_db#(int)::set(this, "env.*.mon", "enable_checks", 1);
```

---

## 5.3 Configuration Objects

For complex configuration, use a dedicated config object instead of individual scalars.

### Define a Config Object

```systemverilog
class apb_agent_config extends uvm_object;

  `uvm_object_utils_begin(apb_agent_config)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
    `uvm_field_int(has_coverage, UVM_ALL_ON)
    `uvm_field_int(num_transactions, UVM_ALL_ON)
  `uvm_object_utils_end

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit has_coverage = 1;
  int num_transactions = 100;
  virtual apb_if vif;

  function new(string name = "apb_agent_config");
    super.new(name);
  endfunction

endclass
```

### Set Config in the Test

```systemverilog
class apb_test extends uvm_test;
  `uvm_component_utils(apb_test)

  apb_env env;
  apb_agent_config agt_cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agt_cfg = apb_agent_config::type_id::create("agt_cfg");
    agt_cfg.is_active = UVM_ACTIVE;
    agt_cfg.has_coverage = 1;
    agt_cfg.num_transactions = 200;

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", agt_cfg.vif))
      `uvm_fatal("CFG", "Interface not found")

    // Store config for agent to retrieve
    uvm_config_db#(apb_agent_config)::set(this, "env.agt*", "agt_cfg", agt_cfg);

    env = apb_env::type_id::create("env", this);
  endfunction
endclass
```

### Retrieve Config in the Agent

```systemverilog
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_agent_config cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(apb_agent_config)::get(this, "", "agt_cfg", cfg))
      `uvm_fatal("CFG", "Agent config not found")

    // Use config to control component creation
    if (cfg.is_active == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end

    mon = apb_monitor::type_id::create("mon", this);

    // Pass interface down to children
    uvm_config_db#(virtual apb_if)::set(this, "*", "apb_vif", cfg.vif);
  endfunction
endclass
```

---

## 5.4 Config DB Debugging

### Check if a Value Exists

```systemverilog
if (uvm_config_db#(int)::exists(this, "", "timeout"))
  `uvm_info("CFG", "timeout is configured", UVM_LOW)
```

### Enable Config DB Tracing

From the command line:

```
+UVM_CONFIG_DB_TRACE
```

This prints every `set` and `get` call, making it easy to debug configuration issues.

### Dump All Config DB Entries

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  uvm_config_db#(uvm_object)::dump();
endfunction
```

---

## 5.5 The UVM Factory

The factory is UVM's mechanism for creating objects and components. It enables **type overrides** — replacing one class with another without modifying existing code.

### Why Use the Factory?

Without the factory:
```systemverilog
my_driver drv = new("drv", this);  // hardcoded type — cannot override
```

With the factory:
```systemverilog
my_driver drv = my_driver::type_id::create("drv", this);  // factory-created — overridable
```

---

## 5.6 Factory Registration

### Components

```systemverilog
class my_driver extends uvm_driver #(my_txn);
  `uvm_component_utils(my_driver)  // register with factory

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

### Objects (Transactions, Config)

```systemverilog
class my_txn extends uvm_sequence_item;
  `uvm_object_utils(my_txn)  // register with factory

  function new(string name = "my_txn");
    super.new(name);
  endfunction
endclass
```

### With Field Automation

```systemverilog
class my_txn extends uvm_sequence_item;
  `uvm_object_utils_begin(my_txn)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
  `uvm_object_utils_end

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "my_txn");
    super.new(name);
  endfunction
endclass
```

---

## 5.7 Factory Overrides

### Type Override — Global Replacement

Replace **all** instances of one type with another:

```systemverilog
class my_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Replace ALL my_driver instances with my_better_driver
    my_driver::type_id::set_type_override(my_better_driver::get_type());

    // Alternative syntax
    set_type_override_by_type(my_driver::get_type(), my_better_driver::get_type());

    env = my_env::type_id::create("env", this);
  endfunction
endclass
```

### Instance Override — Targeted Replacement

Replace a **specific** instance:

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Only replace the driver in "env.agt1"
  my_driver::type_id::set_inst_override(
    my_better_driver::get_type(),
    "env.agt1.drv"
  );

  // Alternative syntax
  set_inst_override_by_type(
    "env.agt1.drv",
    my_driver::get_type(),
    my_better_driver::get_type()
  );

  env = my_env::type_id::create("env", this);
endfunction
```

### Override from Command Line

```
+uvm_set_type_override=my_driver,my_better_driver
+uvm_set_inst_override=my_driver,my_better_driver,env.agt1.drv
```

---

## 5.8 Practical Override Example

### Base Transaction

```systemverilog
class base_txn extends uvm_sequence_item;
  `uvm_object_utils(base_txn)

  rand bit [7:0] data;

  function new(string name = "base_txn");
    super.new(name);
  endfunction
endclass
```

### Extended Transaction with Error Injection

```systemverilog
class error_txn extends base_txn;
  `uvm_object_utils(error_txn)

  rand bit inject_error;

  constraint error_rate {
    inject_error dist { 1 := 10, 0 := 90 };  // 10% error rate
  }

  function new(string name = "error_txn");
    super.new(name);
  endfunction
endclass
```

### Error Injection Test

```systemverilog
class error_test extends base_test;
  `uvm_component_utils(error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // Override base_txn with error_txn everywhere
    base_txn::type_id::set_type_override(error_txn::get_type());
    super.build_phase(phase);
  endfunction
endclass
```

Now every component that creates `base_txn::type_id::create(...)` will get an `error_txn` instead — **without changing any existing code**.

---

## 5.9 Printing Factory Contents

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  // Print all registered types and overrides
  factory.print();
endfunction
```

Or from the command line:

```
+UVM_DUMP_FACTORY
```

---

## 5.10 Parameterized Components

UVM supports parameterized components with the factory:

```systemverilog
class generic_driver #(int WIDTH = 8) extends uvm_driver #(generic_txn #(WIDTH));

  typedef generic_driver #(WIDTH) this_type;
  `uvm_component_param_utils(generic_driver #(WIDTH))

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ...
endclass
```

### Creating Parameterized Components

```systemverilog
generic_driver #(16) drv16;
generic_driver #(32) drv32;

drv16 = generic_driver#(16)::type_id::create("drv16", this);
drv32 = generic_driver#(32)::type_id::create("drv32", this);
```

---

## 5.11 Config DB vs Factory — When to Use Which

| Scenario | Use |
|----------|-----|
| Pass interface handles | `uvm_config_db` |
| Pass configuration parameters | `uvm_config_db` (with config objects) |
| Replace a component type for a test | Factory override |
| Replace a transaction type for error injection | Factory override |
| Control active/passive agent mode | `uvm_config_db` |
| Change driver behavior | Factory override (new driver class) |
| Set verbosity per component | `uvm_config_db` |

---

## 5.12 Summary

| Concept | Key Takeaway |
|---------|-------------|
| `uvm_config_db::set` | Store a value with hierarchical scope |
| `uvm_config_db::get` | Retrieve a value by key |
| Config objects | Bundle related settings into one reusable object |
| `type_id::create` | Factory-aware object creation |
| Type override | Replace ALL instances of a class |
| Instance override | Replace a SPECIFIC instance of a class |
| `+UVM_CONFIG_DB_TRACE` | Debug config_db lookups |
| `factory.print()` | Show registered types and overrides |

---

[&larr; Previous: Sequences & Sequencer](04_uvm_sequences.md) | [Next: Advanced Topics &rarr;](06_uvm_advanced.md)
