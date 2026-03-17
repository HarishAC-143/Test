# Chapter 8: UVM Configuration Database

## What Is the Configuration Database?

The `uvm_config_db` is a **hierarchical key-value store** that allows UVM components to share configuration data without direct references to each other. It is the primary mechanism for passing virtual interfaces, configuration objects, and scalar parameters between testbench components.

## Why Use `uvm_config_db`?

Without `uvm_config_db`, you'd need to pass configuration through constructor arguments or direct member access:

```systemverilog
// WITHOUT config_db — tight coupling, fragile
class my_env extends uvm_env;
  virtual my_if vif;  // How does this get set?
  
  function void build_phase(uvm_phase phase);
    agent = my_agent::type_id::create("agent", this);
    agent.driver.vif = this.vif;  // Reaching into sub-components — bad!
  endfunction
endclass
```

With `uvm_config_db`, configuration flows through the hierarchy cleanly:

```systemverilog
// WITH config_db — clean, loosely coupled
class my_env extends uvm_env;
  function void build_phase(uvm_phase phase);
    agent = my_agent::type_id::create("agent", this);
    // vif is automatically available to agent and its children via config_db
  endfunction
endclass
```

## Basic API

### Setting a Value

```systemverilog
uvm_config_db #(TYPE)::set(CONTEXT, INSTANCE_PATH, FIELD_NAME, VALUE);
```

| Parameter | Description |
|-----------|-------------|
| `TYPE` | The SystemVerilog type being stored |
| `CONTEXT` | The component setting the value (usually `this` or `null`) |
| `INSTANCE_PATH` | Hierarchical path to target component(s) — supports wildcards |
| `FIELD_NAME` | A string key identifying the configuration item |
| `VALUE` | The value to store |

### Getting a Value

```systemverilog
if (!uvm_config_db #(TYPE)::get(CONTEXT, INSTANCE_PATH, FIELD_NAME, VARIABLE))
  `uvm_fatal("CFG", "Configuration item not found")
```

Returns 1 on success, 0 on failure.

## Common Use Cases

### 1. Passing Virtual Interfaces

The most common use — passing the DUT interface from the top-level module into the UVM testbench:

```systemverilog
// In the top-level testbench module:
module tb_top;
  logic clk, rst;
  
  // Instantiate the interface
  my_if dut_if(clk, rst);
  
  // Instantiate the DUT
  my_dut dut(
    .clk(clk),
    .rst(rst),
    .data_in(dut_if.data_in),
    .data_out(dut_if.data_out)
  );
  
  initial begin
    // Store the virtual interface in config_db
    uvm_config_db #(virtual my_if)::set(null, "uvm_test_top.*", "vif", dut_if);
    run_test();
  end
endmodule
```

```systemverilog
// In the driver:
class my_driver extends uvm_driver #(my_transaction);
  virtual my_if vif;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual my_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction
endclass
```

### 2. Passing Scalar Configuration

```systemverilog
// In the test:
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  // Set agent to active mode
  uvm_config_db #(uvm_active_passive_enum)::set(this, "env.agent", "is_active", UVM_ACTIVE);
  
  // Set a custom parameter
  uvm_config_db #(int)::set(this, "env.agent.driver", "inter_txn_delay", 5);
endfunction
```

```systemverilog
// In the driver:
int inter_txn_delay = 1;  // Default

function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  uvm_config_db #(int)::get(this, "", "inter_txn_delay", inter_txn_delay);
  // If not found, keeps the default value of 1
endfunction
```

### 3. Passing Configuration Objects

For complex configuration, create a dedicated configuration class:

```systemverilog
class my_agent_config extends uvm_object;
  `uvm_object_utils(my_agent_config)
  
  virtual my_if        vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned         num_lanes    = 4;
  bit                  enable_coverage = 1;
  bit                  enable_checks   = 1;
  
  function new(string name = "my_agent_config");
    super.new(name);
  endfunction
endclass
```

```systemverilog
// In the test:
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  my_agent_config cfg = my_agent_config::type_id::create("cfg");
  cfg.vif             = tb_top.dut_if;
  cfg.is_active       = UVM_ACTIVE;
  cfg.num_lanes       = 8;
  cfg.enable_coverage = 1;
  
  uvm_config_db #(my_agent_config)::set(this, "env.agent*", "cfg", cfg);
endfunction
```

```systemverilog
// In the agent:
class my_agent extends uvm_agent;
  my_agent_config cfg;
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(my_agent_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "Agent configuration not found")
    
    monitor = my_monitor::type_id::create("monitor", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      driver    = my_driver::type_id::create("driver", this);
      sequencer = my_sequencer::type_id::create("sequencer", this);
    end
  endfunction
endclass
```

## Hierarchical Path Matching

The `INSTANCE_PATH` parameter supports wildcards for flexible targeting:

| Pattern | Matches |
|---------|---------|
| `"env.agent.driver"` | Exactly `env.agent.driver` |
| `"env.agent.*"` | All direct children of `env.agent` |
| `"env.*"` | All direct children of `env` |
| `"*"` | Everything under the context component |
| `""` | The context component itself |

### Examples

```systemverilog
// Set for a specific component
uvm_config_db #(int)::set(this, "env.agent.driver", "delay", 5);

// Set for all components under agent
uvm_config_db #(virtual my_if)::set(this, "env.agent.*", "vif", vif);

// Set globally (from top-level module, context = null)
uvm_config_db #(virtual my_if)::set(null, "uvm_test_top.env.agent.*", "vif", vif);

// Set for all agents (using wildcard)
uvm_config_db #(int)::set(this, "env.agent*", "timeout", 1000);
```

## Configuration Precedence

When multiple `set()` calls target the same component and field:

1. **Later calls override earlier calls** at the same hierarchical level
2. **Parent settings override child settings** (a setting from the test overrides one from the environment)
3. The `get()` call retrieves the **most specific, highest-priority** match

```systemverilog
// In the environment (lower priority):
uvm_config_db #(int)::set(this, "agent.driver", "delay", 10);

// In the test (higher priority — overrides the above):
uvm_config_db #(int)::set(this, "env.agent.driver", "delay", 5);

// The driver will get delay = 5
```

## Debugging `uvm_config_db`

### Print All Configuration Settings

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  uvm_config_db #()::dump();  // Print all config_db entries
endfunction
```

### Enable Config DB Tracing

Add `+UVM_CONFIG_DB_TRACE` to your simulation command line to see every `set()` and `get()` operation:

```bash
./simv +UVM_CONFIG_DB_TRACE
```

### Check if a Value Exists

```systemverilog
if (uvm_config_db #(int)::exists(this, "", "my_param"))
  `uvm_info("CFG", "Parameter exists", UVM_HIGH)
```

## Best Practices

### Do

- Use configuration objects for complex configurations
- Always check the return value of `get()` — use `uvm_fatal` for required configs
- Set configuration in `build_phase` before children are created
- Use meaningful field names
- Provide default values when `get()` failure is acceptable

### Don't

- Don't use `uvm_config_db` as a general-purpose global variable store
- Don't set configuration after `build_phase` unless you have a specific reason
- Don't store large data structures (use references/handles instead)
- Don't rely on implicit wildcards matching — be explicit about paths

## `uvm_config_db` vs. `uvm_resource_db`

| Feature | `uvm_config_db` | `uvm_resource_db` |
|---------|-----------------|-------------------|
| Scope | Hierarchical (follows component tree) | Global (flat namespace) |
| Priority | Parent overrides child | Last writer wins |
| Typical Use | Testbench configuration | Shared resources |
| Recommendation | **Preferred** for most cases | Use only for global/shared data |

## Summary

| Concept | Description |
|---------|-------------|
| `set()` | Store a value in the configuration database |
| `get()` | Retrieve a value from the configuration database |
| Virtual interface | Most common `config_db` use case |
| Configuration object | Bundle multiple parameters into one object |
| Path wildcards | `*` matches component names in the hierarchy |
| Precedence | Parent settings override child settings |
| Debugging | `+UVM_CONFIG_DB_TRACE`, `dump()`, `exists()` |

---

[← Previous: Chapter 7 — TLM Ports](07_tlm.md) | [Next: Chapter 9 — Reporting & Messaging →](09_reporting.md)
