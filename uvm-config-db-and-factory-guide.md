# UVM config_db and Factory — A Comprehensive Guide

A deep-dive into two of the most powerful mechanisms in the Universal Verification Methodology (UVM): the **configuration database (`uvm_config_db`)** and the **factory (`uvm_factory`)**. Together they enable flexible, reusable, and scalable verification environments.

---

## Table of Contents

1. [Why config_db and Factory Matter](#1-why-config_db-and-factory-matter)
2. [UVM config_db Fundamentals](#2-uvm-config_db-fundamentals)
3. [config_db API in Detail](#3-config_db-api-in-detail)
4. [config_db Scoping and Hierarchical Paths](#4-config_db-scoping-and-hierarchical-paths)
5. [Passing Virtual Interfaces with config_db](#5-passing-virtual-interfaces-with-config_db)
6. [Passing Configuration Objects](#6-passing-configuration-objects)
7. [config_db Precedence Rules](#7-config_db-precedence-rules)
8. [Debugging config_db Issues](#8-debugging-config_db-issues)
9. [UVM Factory Fundamentals](#9-uvm-factory-fundamentals)
10. [Registering Components and Objects with the Factory](#10-registering-components-and-objects-with-the-factory)
11. [Creating Objects Through the Factory](#11-creating-objects-through-the-factory)
12. [Factory Overrides — Type Overrides](#12-factory-overrides--type-overrides)
13. [Factory Overrides — Instance Overrides](#13-factory-overrides--instance-overrides)
14. [Factory Override Chaining](#14-factory-override-chaining)
15. [Parameterized Classes and the Factory](#15-parameterized-classes-and-the-factory)
16. [Combining config_db and Factory](#16-combining-config_db-and-factory)
17. [Common Pitfalls and Best Practices](#17-common-pitfalls-and-best-practices)
18. [Complete Worked Examples](#18-complete-worked-examples)

---

## 1. Why config_db and Factory Matter

UVM verification environments must be **reusable** across different projects, DUT configurations, and test scenarios. Two mechanisms make this possible:

| Mechanism | Purpose |
|---|---|
| `uvm_config_db` | Share **data** (interfaces, parameters, configuration objects) between components without hard-coded connections |
| `uvm_factory` | Swap **types** (transactions, drivers, sequences) without modifying the environment source code |

Without these, every new test variant would require editing the environment code — the opposite of reuse.

### The Principle

```
config_db  → Controls WHAT values/settings components receive at runtime
factory    → Controls WHICH class implementation is instantiated at runtime
```

Together they decouple a testbench's **structure** from its **behavior**, enabling test writers to customize both without touching the reusable verification IP.

---

## 2. UVM config_db Fundamentals

`uvm_config_db` is a **global, parameterized key-value store** that allows any component to publish data and any other component to retrieve it. It replaces the older `set_config_*` / `get_config_*` API from OVM/UVM 1.0.

### Mental Model

Think of `config_db` as a dictionary organized by **scope** and **field name**:

```
┌──────────────────────────────────────────────────────────┐
│                   uvm_config_db                          │
├────────────────────┬─────────────┬───────────────────────┤
│ Scope (hierarchy)  │ Field Name  │ Value                 │
├────────────────────┼─────────────┼───────────────────────┤
│ uvm_test_top.env.* │ "vif"       │ <virtual interface>   │
│ uvm_test_top.*     │ "cfg"       │ <config object>       │
│ uvm_test_top.env   │ "num_agents"│ 4                     │
└────────────────────┴─────────────┴───────────────────────┘
```

### Core Operations

There are only two operations:

- **`set`** — Store a value at a given scope + field name
- **`get`** — Retrieve a value for the calling component by scope + field name

---

## 3. config_db API in Detail

### Setting a Value

```systemverilog
uvm_config_db#(T)::set(uvm_component cntxt,
                        string        inst_name,
                        string        field_name,
                        T             value);
```

| Parameter | Description |
|---|---|
| `T` | The SystemVerilog type of the value being stored |
| `cntxt` | The component making the call (typically `this`, or `null` for top-level modules) |
| `inst_name` | A hierarchical path (relative to `cntxt`) specifying which components can see this value |
| `field_name` | An arbitrary string key to identify the value |
| `value` | The actual data to store |

**Example — Setting from a top-level module:**

```systemverilog
module top;
  import uvm_pkg::*;

  apb_if apb_vif(clk, rst_n);

  initial begin
    uvm_config_db#(virtual apb_if)::set(
      null,               // context: null = global
      "uvm_test_top.*",   // scope: all components under uvm_test_top
      "apb_vif",          // field name
      apb_vif             // value: the actual interface instance
    );
    run_test("apb_base_test");
  end
endmodule
```

### Getting a Value

```systemverilog
uvm_config_db#(T)::get(uvm_component cntxt,
                        string        inst_name,
                        string        field_name,
                        ref T         value);
```

`get()` returns `1` on success, `0` on failure. **Always check the return value.**

**Example — Retrieving in a driver:**

```systemverilog
class apb_driver extends uvm_driver#(apb_txn);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction
endclass
```

### Checking Existence Without Retrieving

```systemverilog
if (uvm_config_db#(int)::exists(this, "", "burst_length"))
  `uvm_info("CFG", "burst_length is configured", UVM_LOW)
```

### Waiting for a Value

When a value might be set later (e.g., during a later phase), use `wait_modified`:

```systemverilog
uvm_config_db#(bit)::wait_modified(this, "", "enable_coverage");
```

This blocks until the specified field is set or updated.

---

## 4. config_db Scoping and Hierarchical Paths

The power of `config_db` lies in its scoping mechanism. The effective scope of a `set` call is determined by concatenating `cntxt.get_full_name()` with `inst_name`.

### Scope Resolution

```
Effective scope = {cntxt.get_full_name(), ".", inst_name}
```

If `cntxt` is `null`, the context name is empty, so the effective scope is just `inst_name`.

### Wildcards

The `inst_name` field supports glob-style wildcards:

| Pattern | Meaning |
|---|---|
| `*` | Match any characters at one level |
| `uvm_test_top.*` | All components directly under `uvm_test_top` and their descendants |
| `uvm_test_top.env.agent*` | All agents (agent0, agent1, etc.) under env |

### Scope Examples

```systemverilog
// From top-level module (null context)
// Visible to ALL components:
uvm_config_db#(int)::set(null, "*", "timeout", 1000);

// Visible only to env and its children:
uvm_config_db#(int)::set(null, "uvm_test_top.env.*", "max_errors", 50);

// From inside a test (this = uvm_test_top)
// Visible to env.agent.driver specifically:
uvm_config_db#(bit)::set(this, "env.agent.driver", "enable_protocol_check", 1);

// From inside env (this = uvm_test_top.env)
// Visible to agent.sequencer:
uvm_config_db#(int)::set(this, "agent.sequencer", "count", 100);
```

### Matching Rules for `get`

When a component calls `get`, the config_db looks for entries where the calling component's full hierarchical path matches the scope pattern of a `set` call. The `cntxt` in `get` is almost always `this`, and `inst_name` is `""`.

```systemverilog
// In a component at path "uvm_test_top.env.agent.driver"
uvm_config_db#(int)::get(this, "", "timeout", timeout_val);

// This will match a set with scope "uvm_test_top.*" or
// "uvm_test_top.env.agent.driver" or "uvm_test_top.env.agent.*"
```

---

## 5. Passing Virtual Interfaces with config_db

Virtual interfaces cannot be passed through constructors because they are dynamic handles to static interface instances. `config_db` is the standard mechanism to bridge the static (module) and dynamic (class) worlds.

### Pattern

```
┌──────────────┐    config_db    ┌──────────────┐
│  top module   │ ────set────►   │              │
│  (static)     │                │  config_db   │
│  interface    │                │  (global)    │
│  instantiation│                │              │
└──────────────┘                └──────┬───────┘
                                       │ get
                                       ▼
                                ┌──────────────┐
                                │  UVM driver   │
                                │  (dynamic)    │
                                │  uses vif     │
                                └──────────────┘
```

### Complete Example

```systemverilog
// Interface definition
interface axi_if(input logic clk, input logic rst_n);
  logic [31:0] awaddr;
  logic        awvalid;
  logic        awready;
  logic [31:0] wdata;
  logic        wvalid;
  logic        wready;
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;

  modport master(output awaddr, awvalid, wdata, wvalid, bready,
                 input  awready, wready, bresp, bvalid);

  modport slave(input  awaddr, awvalid, wdata, wvalid, bready,
                output awready, wready, bresp, bvalid);
endinterface

// Top module
module tb_top;
  logic clk, rst_n;

  axi_if axi_vif(clk, rst_n);

  dut u_dut(.clk(clk), .rst_n(rst_n), /* connect axi_vif signals */);

  initial begin
    uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top.*", "axi_vif", axi_vif);
    run_test();
  end
endmodule

// Driver retrieval
class axi_driver extends uvm_driver#(axi_txn);
  `uvm_component_utils(axi_driver)

  virtual axi_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_vif", vif))
      `uvm_fatal("NOVIF", {"Virtual interface not set for: ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(axi_txn txn);
    @(posedge vif.clk);
    vif.awaddr  <= txn.addr;
    vif.awvalid <= 1'b1;
    @(posedge vif.clk iff vif.awready);
    vif.awvalid <= 1'b0;
  endtask
endclass
```

---

## 6. Passing Configuration Objects

Rather than setting many individual fields, bundle related settings into a **configuration object** and pass the whole object through `config_db`.

### Defining a Configuration Object

```systemverilog
class uart_agent_cfg extends uvm_object;
  `uvm_object_utils(uart_agent_cfg)

  rand int unsigned baud_rate;
  rand int unsigned data_bits;
  rand int unsigned stop_bits;
  rand bit          parity_en;
  rand bit          is_active;
  rand bit          has_coverage;

  constraint defaults_c {
    baud_rate inside {9600, 19200, 38400, 115200};
    data_bits inside {7, 8};
    stop_bits inside {1, 2};
  }

  function new(string name = "uart_agent_cfg");
    super.new(name);
  endfunction
endclass
```

### Setting and Getting Configuration Objects

```systemverilog
// In the test
class uart_test extends uvm_test;
  `uvm_component_utils(uart_test)

  uart_env_cfg env_cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env_cfg = uart_env_cfg::type_id::create("env_cfg");
    env_cfg.randomize() with { baud_rate == 115200; };
    uvm_config_db#(uart_env_cfg)::set(this, "env", "cfg", env_cfg);
  endfunction
endclass

// In the environment
class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_env_cfg cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uart_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "Environment configuration not found")

    // Use cfg to decide what to build
    if (cfg.is_active)
      agent = uart_agent::type_id::create("agent", this);
  endfunction
endclass
```

### Nested Configuration Distribution

A common pattern is to have the environment redistribute sub-configurations:

```systemverilog
class soc_env_cfg extends uvm_object;
  `uvm_object_utils(soc_env_cfg)

  uart_agent_cfg  uart_cfg;
  spi_agent_cfg   spi_cfg;
  int             num_uart_agents;

  function new(string name = "soc_env_cfg");
    super.new(name);
    uart_cfg = uart_agent_cfg::type_id::create("uart_cfg");
    spi_cfg  = spi_agent_cfg::type_id::create("spi_cfg");
  endfunction
endclass

class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)

  soc_env_cfg cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(soc_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", "SOC env config not found")

    // Propagate sub-configs down
    uvm_config_db#(uart_agent_cfg)::set(this, "uart_agent.*", "cfg", cfg.uart_cfg);
    uvm_config_db#(spi_agent_cfg)::set(this, "spi_agent.*", "cfg", cfg.spi_cfg);
  endfunction
endclass
```

---

## 7. config_db Precedence Rules

When multiple `set` calls target the same component and field, the config_db resolves conflicts using **precedence**:

### Rule 1 — Hierarchical Depth

A `set` call from a component **higher** in the hierarchy wins over one from a **lower** component.

```
uvm_test_top          → Highest precedence
  └─ env              → Medium precedence
       └─ agent       → Lowest precedence
```

This means a test can always override settings made by reusable environment code.

### Rule 2 — Last Writer Wins (Same Level)

If two `set` calls come from the same hierarchical level, the **last one executed** takes effect.

```systemverilog
// Both from the same test:
uvm_config_db#(int)::set(this, "env.agent.*", "delay", 10);  // set first
uvm_config_db#(int)::set(this, "env.agent.*", "delay", 20);  // this wins
```

### Rule 3 — Specificity Does Not Matter

Unlike CSS, a more specific path does **not** automatically win over a less specific one from a higher-level component. Only the setter's hierarchical position matters.

### Practical Implication

```
Test sets:   config_db#(int)::set(this, "env.*", "count", 5)     ← WINS
Env sets:    config_db#(int)::set(this, "agent.*", "count", 10)  ← Loses
```

The test's value wins because the test sits above the env in the hierarchy, regardless of path specificity.

---

## 8. Debugging config_db Issues

### Enabling config_db Tracing

Add this to your test or top module:

```systemverilog
initial begin
  uvm_config_db#(virtual apb_if)::set( ... );

  // Turn on tracing for all config_db accesses
  set_config_int("*", "recording_detail", UVM_FULL);

  // Or use the UVM command-line flag:
  // +UVM_CONFIG_DB_TRACE
end
```

Run with:

```bash
+UVM_CONFIG_DB_TRACE
```

This prints every `set` and `get` call with the scope, field name, and result.

### Common config_db Errors and Fixes

| Symptom | Likely Cause | Fix |
|---|---|---|
| `get()` returns 0 | Scope mismatch between `set` and `get` | Print `get_full_name()` in both places; verify path patterns match |
| `get()` returns 0 | Type parameter `T` mismatch | Ensure `set` and `get` use identical type parameter |
| `get()` returns 0 | `set` called after `get` | Move `set` to an earlier phase or a higher-level component |
| Wrong value received | Precedence conflict | Use `+UVM_CONFIG_DB_TRACE` to see which `set` call wins |
| Null virtual interface | `set` called after `build_phase` | Ensure `set` is called from `initial` block before `run_test()` |

### Printing All config_db Contents

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  uvm_config_db#(int)::dump();
endfunction
```

---

## 9. UVM Factory Fundamentals

The UVM factory is an implementation of the **Factory Method** design pattern. Instead of calling `new()` directly, components and objects are created through a central factory that can substitute a different class at runtime.

### The Problem Factory Solves

Without the factory, changing a driver type requires editing source code:

```systemverilog
// Hard-coded — NOT reusable
class my_env extends uvm_env;
  function void build_phase(uvm_phase phase);
    driver = pcie_driver::new("driver", this);   // locked to pcie_driver
  endfunction
endclass
```

With the factory, a test can substitute a different driver without modifying the environment:

```systemverilog
// Factory-based — Reusable
class my_env extends uvm_env;
  function void build_phase(uvm_phase phase);
    driver = pcie_driver::type_id::create("driver", this);  // factory decides the type
  endfunction
endclass

// In a test — override without editing the env
class error_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    pcie_driver::type_id::set_type_override(pcie_error_driver::get_type());
    super.build_phase(phase);
  endfunction
endclass
```

### Factory Architecture

```
         ┌───────────────────────────────┐
         │        uvm_factory            │
         │  (singleton registry)         │
         │                               │
         │  ┌─────────────────────────┐  │
         │  │  Type Registry          │  │
         │  │  "pcie_driver" → proxy  │  │
         │  │  "axi_txn"    → proxy  │  │
         │  └─────────────────────────┘  │
         │                               │
         │  ┌─────────────────────────┐  │
         │  │  Override Table         │  │
         │  │  pcie_driver →          │  │
         │  │    pcie_error_driver    │  │
         │  └─────────────────────────┘  │
         └───────────────────────────────┘
                      │
         type_id::create("name", parent)
                      │
                      ▼
         Returns instance of the overridden type
         (or original if no override exists)
```

---

## 10. Registering Components and Objects with the Factory

For the factory to know about a class, it must be **registered**. Registration is done with utility macros.

### For `uvm_component` Subclasses

```systemverilog
class my_driver extends uvm_driver#(my_txn);
  `uvm_component_utils(my_driver)            // registers with factory

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

### For `uvm_object` Subclasses (Transactions, Sequences, Configs)

```systemverilog
class my_txn extends uvm_sequence_item;
  `uvm_object_utils(my_txn)                  // registers with factory

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;

  function new(string name = "my_txn");
    super.new(name);
  endfunction
endclass
```

### What the Macros Do Behind the Scenes

`uvm_component_utils(T)` expands to roughly:

```systemverilog
typedef uvm_component_registry#(T, "T") type_id;
static function type_id get_type();
  return type_id::get();
endfunction
virtual function uvm_object_wrapper get_object_type();
  return type_id::get();
endfunction
virtual function string get_type_name();
  return "T";
endfunction
```

The key is the **type_id** typedef, which is a proxy registered with the global factory singleton. The proxy knows how to construct instances of `T`.

### Registration with Field Automation (Legacy)

The older `uvm_component_utils_begin` / `uvm_component_utils_end` macros also support field automation. This is **deprecated in modern UVM** and not recommended:

```systemverilog
// Legacy — avoid in new code
`uvm_object_utils_begin(my_txn)
  `uvm_field_int(addr, UVM_ALL_ON)
  `uvm_field_int(data, UVM_ALL_ON)
`uvm_object_utils_end
```

Instead, implement `do_copy`, `do_compare`, `do_print`, and `do_pack`/`do_unpack` manually for better performance and clarity.

---

## 11. Creating Objects Through the Factory

### The create() Method

Always use `type_id::create()` instead of `new()`:

```systemverilog
// For components (need parent):
my_driver drv;
drv = my_driver::type_id::create("drv", this);

// For objects (no parent):
my_txn txn;
txn = my_txn::type_id::create("txn");
```

### Why Not new()?

If you call `new()` directly, factory overrides have no effect:

```systemverilog
drv = new("drv", this);      // ALWAYS creates my_driver — overrides ignored
drv = my_driver::type_id::create("drv", this);  // factory can substitute
```

### create() in Sequences

```systemverilog
class my_sequence extends uvm_sequence#(my_txn);
  `uvm_object_utils(my_sequence)

  task body();
    my_txn txn;
    txn = my_txn::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with { addr inside {['h0:'hFF]}; })
      `uvm_error("RAND", "Randomization failed")
    finish_item(txn);
  endtask
endclass
```

---

## 12. Factory Overrides — Type Overrides

A **type override** replaces every instance of one type with another, globally.

### API

```systemverilog
// Method 1: Using type_id (preferred)
original_type::type_id::set_type_override(replacement_type::get_type(), replace);

// Method 2: Using the factory singleton directly
uvm_factory factory = uvm_factory::get();
factory.set_type_override_by_type(
  original_type::get_type(),
  replacement_type::get_type()
);
```

The `replace` argument (default `1`) controls whether an existing override is replaced.

### Requirements

The replacement class **must** extend the original class. This guarantees polymorphic compatibility.

```systemverilog
class base_txn extends uvm_sequence_item;
  `uvm_object_utils(base_txn)

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "base_txn");
    super.new(name);
  endfunction

  constraint addr_range_c {
    addr inside {[32'h0000_0000 : 32'h0000_FFFF]};
  }
endclass

class error_txn extends base_txn;
  `uvm_object_utils(error_txn)

  rand bit inject_parity_error;
  rand bit inject_crc_error;

  function new(string name = "error_txn");
    super.new(name);
  endfunction

  constraint error_injection_c {
    inject_parity_error dist {0 := 90, 1 := 10};
    inject_crc_error    dist {0 := 95, 1 := 5};
  }
endclass
```

### Using the Override in a Test

```systemverilog
class error_injection_test extends uvm_test;
  `uvm_component_utils(error_injection_test)

  my_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // Override: every create() of base_txn now returns error_txn
    base_txn::type_id::set_type_override(error_txn::get_type());
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction
endclass
```

Now every `base_txn::type_id::create(...)` in the entire testbench produces an `error_txn` instead — without modifying the environment, agent, or sequence code.

---

## 13. Factory Overrides — Instance Overrides

An **instance override** replaces a type only for a specific component instance, identified by its hierarchical path.

### API

```systemverilog
// Method 1: Using type_id
original_type::type_id::set_inst_override(
  replacement_type::get_type(),
  "hierarchical.path.to.instance"
);

// Method 2: Using factory singleton
uvm_factory factory = uvm_factory::get();
factory.set_inst_override_by_type(
  original_type::get_type(),
  replacement_type::get_type(),
  "uvm_test_top.env.agent.driver"
);
```

### Example — Override One Agent's Driver

```systemverilog
class multi_agent_test extends uvm_test;
  `uvm_component_utils(multi_agent_test)

  function void build_phase(uvm_phase phase);
    // Only agent1's driver becomes a slow_driver
    fast_driver::type_id::set_inst_override(
      slow_driver::get_type(),
      "uvm_test_top.env.agent1.driver"
    );

    // agent0's driver remains fast_driver
    super.build_phase(phase);
  endfunction
endclass
```

### Type Override vs. Instance Override

| Aspect | Type Override | Instance Override |
|---|---|---|
| Scope | Global — all instances | Specific hierarchical path |
| Use case | Change behavior everywhere | Change behavior in one place |
| Precedence | Instance override wins over type override when both apply |

---

## 14. Factory Override Chaining

Overrides can be chained: if `A` is overridden by `B`, and `B` is overridden by `C`, then creating `A` produces `C`.

```systemverilog
class base_seq extends uvm_sequence#(my_txn);
  `uvm_object_utils(base_seq)
  // ... basic sequence
endclass

class constrained_seq extends base_seq;
  `uvm_object_utils(constrained_seq)
  // ... adds constraints
endclass

class debug_seq extends constrained_seq;
  `uvm_object_utils(debug_seq)
  // ... adds debug prints
endclass

// In a test:
base_seq::type_id::set_type_override(constrained_seq::get_type());
constrained_seq::type_id::set_type_override(debug_seq::get_type());

// Now base_seq::type_id::create("s") returns a debug_seq
```

---

## 15. Parameterized Classes and the Factory

Parameterized classes need special handling because each parameterization is a distinct type.

### Registration

```systemverilog
class generic_txn #(int WIDTH = 32) extends uvm_sequence_item;
  typedef uvm_object_registry#(generic_txn#(WIDTH), 
    $sformatf("generic_txn#(%0d)", WIDTH)) type_id;

  rand bit [WIDTH-1:0] data;

  function new(string name = "generic_txn");
    super.new(name);
  endfunction

  static function type_id get_type();
    return type_id::get();
  endfunction

  virtual function string get_type_name();
    return $sformatf("generic_txn#(%0d)", WIDTH);
  endfunction
endclass
```

### Usage

```systemverilog
// Each parameterization is independent
generic_txn#(32) txn32 = generic_txn#(32)::type_id::create("txn32");
generic_txn#(64) txn64 = generic_txn#(64)::type_id::create("txn64");

// Override applies only to the matching parameterization
generic_txn#(32)::type_id::set_type_override(wide_txn#(32)::get_type());
```

---

## 16. Combining config_db and Factory

The config_db and factory are most powerful when used together. The config_db passes data; the factory swaps implementations.

### Pattern: Test Customization

```systemverilog
class stress_test extends uvm_test;
  `uvm_component_utils(stress_test)

  function void build_phase(uvm_phase phase);
    // Factory: swap in stress versions
    base_driver::type_id::set_type_override(stress_driver::get_type());
    base_txn::type_id::set_type_override(stress_txn::get_type());

    // config_db: pass test-specific parameters
    uvm_config_db#(int)::set(this, "env.*", "num_transactions", 10000);
    uvm_config_db#(bit)::set(this, "env.*", "enable_backpressure", 1);
    uvm_config_db#(int)::set(this, "env.agent.*", "max_delay", 0);

    super.build_phase(phase);
  endfunction
endclass
```

### Pattern: Conditional Creation via config_db

```systemverilog
class configurable_env extends uvm_env;
  `uvm_component_utils(configurable_env)

  my_agent       agent;
  my_scoreboard  scb;
  my_coverage    cov;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent = my_agent::type_id::create("agent", this);
    scb   = my_scoreboard::type_id::create("scb", this);

    bit has_coverage;
    if (uvm_config_db#(bit)::get(this, "", "enable_coverage", has_coverage)
        && has_coverage)
      cov = my_coverage::type_id::create("cov", this);
  endfunction
endclass
```

---

## 17. Common Pitfalls and Best Practices

### Pitfalls

| Pitfall | Description | Solution |
|---|---|---|
| Using `new()` instead of `create()` | Bypasses the factory entirely | Always use `type_id::create()` |
| Type mismatch in config_db | `set` uses `int`, `get` uses `bit` | Ensure identical type parameters |
| Scope mismatch | `set` scope doesn't cover the `get` caller | Use `+UVM_CONFIG_DB_TRACE` to debug |
| Override after `create()` | Override set after the object is already created | Set overrides before `super.build_phase()` |
| Not checking `get()` return | Silently uses uninitialized values | Always wrap `get()` in `if` with `uvm_fatal` |
| Override non-derived class | Replacement class doesn't extend original | Ensure proper inheritance chain |

### Best Practices

1. **Use configuration objects** — Group related config fields into `uvm_object` subclasses rather than setting many individual scalars.

2. **Set overrides before `super.build_phase()`** — Because `build_phase` triggers top-down, call factory overrides and config_db sets before the parent builds child components.

3. **Always check `get()` return values** — A missing configuration is usually a fatal error. Catch it early with `uvm_fatal`.

4. **Use `type_id::create()` everywhere** — Even for transactions and sequences inside sequence bodies.

5. **Pass virtual interfaces from the top module** — Set them in config_db from the `initial` block before `run_test()`.

6. **Keep `set` calls in build_phase (or earlier)** — Most `get` calls happen in `build_phase`. Setting values later may cause ordering issues.

7. **Use type overrides for global changes, instance overrides for targeted changes** — Don't scatter instance overrides when a type override suffices.

8. **Print the factory at end_of_elaboration** — Verify overrides are registered:
   ```systemverilog
   function void end_of_elaboration_phase(uvm_phase phase);
     uvm_factory factory = uvm_factory::get();
     factory.print();
   endfunction
   ```

---

## 18. Complete Worked Examples

See the [`examples/`](examples/) directory for full, annotated source files:

| File | Description | Key Concepts |
|---|---|---|
| [`12_uvm_config_db.sv`](examples/12_uvm_config_db.sv) | Complete testbench demonstrating config_db usage | Virtual interfaces, config objects, scoping, precedence |
| [`13_uvm_factory.sv`](examples/13_uvm_factory.sv) | Factory registration, type/instance overrides | Polymorphic substitution, override chaining |
| [`14_uvm_config_db_factory_combined.sv`](examples/14_uvm_config_db_factory_combined.sv) | Integrated testbench using both mechanisms | Test customization, conditional builds, full UVM flow |
