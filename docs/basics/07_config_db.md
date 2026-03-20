# Chapter 7: Configuration Database (uvm_config_db)

## What Is the Config DB?

`uvm_config_db` is a **global key-value store** that allows UVM components to share configuration without hard-coded connections. It uses the component hierarchy to scope visibility, so a setting placed at one level can be read by components below it.

## Basic API

### Setting a Value

```systemverilog
uvm_config_db #(T)::set(context, instance_path, field_name, value);
```

| Parameter | Description |
|-----------|-------------|
| `T` | Data type (int, string, virtual interface, object, etc.) |
| `context` | The component making the setting (usually `this` or `null`) |
| `instance_path` | Relative hierarchical path from `context` to the target |
| `field_name` | A string key identifying the setting |
| `value` | The value to store |

### Getting a Value

```systemverilog
if (!uvm_config_db #(T)::get(context, instance_path, field_name, variable))
  `uvm_fatal("CFG", "Failed to get <field_name> from config_db")
```

Returns 1 on success, 0 if no matching entry is found.

---

## Virtual Interface Passing

The most common use of `uvm_config_db` is passing **virtual interfaces** from the top-level module to UVM components.

### Top-Level Module

```systemverilog
module top;
  logic clk, rst_n;

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // DUT interface
  apb_if apb_intf(.pclk(clk), .preset_n(rst_n));

  // DUT
  apb_slave dut (
    .pclk    (apb_intf.pclk),
    .preset_n(apb_intf.preset_n),
    .psel    (apb_intf.psel),
    .penable (apb_intf.penable),
    .pwrite  (apb_intf.pwrite),
    .paddr   (apb_intf.paddr),
    .pwdata  (apb_intf.pwdata),
    .prdata  (apb_intf.prdata),
    .pready  (apb_intf.pready)
  );

  initial begin
    // Make the interface available to UVM components
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.env.agent*", "vif", apb_intf);
    run_test();
  end
endmodule
```

### Component Retrieval

```systemverilog
class apb_driver extends uvm_driver #(apb_transaction);
  virtual apb_if vif;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db")
  endfunction
endclass
```

---

## Configuration Objects

For complex configurations, create a dedicated configuration class:

```systemverilog
class uart_config extends uvm_object;
  `uvm_object_utils(uart_config)

  rand int unsigned baud_rate;
  rand int unsigned data_bits;
  rand int unsigned stop_bits;
  rand bit          parity_en;
  rand bit          parity_odd;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  constraint c_defaults {
    baud_rate inside {9600, 19200, 38400, 57600, 115200};
    data_bits inside {7, 8};
    stop_bits inside {1, 2};
  }

  function new(string name = "uart_config");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("baud=%0d, data_bits=%0d, stop=%0d, parity=%s%s",
      baud_rate, data_bits, stop_bits,
      parity_en ? "ON" : "OFF",
      parity_en ? (parity_odd ? "(odd)" : "(even)") : "");
  endfunction
endclass
```

### Setting Configuration Objects

```systemverilog
class uart_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure
    uart_config cfg = uart_config::type_id::create("cfg");
    cfg.baud_rate = 115200;
    cfg.data_bits = 8;
    cfg.stop_bits = 1;
    cfg.parity_en = 1;
    cfg.parity_odd = 0;

    // Store in config_db for all components under the agent
    uvm_config_db #(uart_config)::set(this, "env.agent*", "cfg", cfg);

    env = uart_env::type_id::create("env", this);
  endfunction
endclass
```

### Retrieving Configuration Objects

```systemverilog
class uart_driver extends uvm_driver #(uart_transaction);
  uart_config cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(uart_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "UART config not found in config_db")
    `uvm_info("DRV", $sformatf("Configured with: %s", cfg.convert2string()), UVM_LOW)
  endfunction
endclass
```

---

## Scoping Rules

The `set()` method's `context` and `instance_path` together define which components can see the value.

### Examples

```systemverilog
// Visible to everything (global)
uvm_config_db #(int)::set(null, "*", "timeout", 1000);

// Visible to env and everything below it
uvm_config_db #(int)::set(this, "env*", "num_txns", 50);

// Visible only to the specific driver
uvm_config_db #(int)::set(this, "env.agent.drv", "max_delay", 5);

// Using null context with full path
uvm_config_db #(int)::set(null, "uvm_test_top.env.agent.drv", "max_delay", 5);
```

### Wildcards

The `instance_path` supports glob-style wildcards:

| Pattern | Meaning |
|---------|---------|
| `*` | Matches any string |
| `env.agent*` | Matches `env.agent`, `env.agent.drv`, `env.agent.mon`, etc. |
| `env.*.drv` | Matches `env.agent0.drv`, `env.agent1.drv`, etc. |

---

## Priority and Conflicts

If multiple `set()` calls match the same `get()`, UVM uses these rules:

1. **More specific path** wins over wildcard.
2. Among equally specific paths, the **last `set()`** wins.
3. A setting from a **higher component** in the hierarchy takes precedence over one from a lower component.

---

## Passing Simple Types

```systemverilog
// Integer
uvm_config_db #(int)::set(this, "env", "num_agents", 2);

// String
uvm_config_db #(string)::set(this, "env", "test_name", "smoke_test");

// Bit
uvm_config_db #(bit)::set(this, "env.agent", "enable_coverage", 1);

// Enum
uvm_config_db #(uvm_active_passive_enum)::set(this, "env.agent", "is_active", UVM_PASSIVE);
```

---

## Debugging Config DB

### Enable Config DB Tracing

```bash
./simv +UVM_CONFIG_DB_TRACE
```

This prints every `set()` and `get()` call, showing the full context and result.

### Check if a Setting Exists

```systemverilog
if (uvm_config_db #(int)::exists(this, "", "timeout"))
  `uvm_info("CFG", "timeout is set", UVM_LOW)
```

### Dump All Settings

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  uvm_config_db #(int)::dump();  // prints all integer settings
endfunction
```

---

## Common Patterns

### Pattern 1: Agent Active/Passive Configuration

```systemverilog
// In the test
uvm_config_db #(uvm_active_passive_enum)::set(this, "env.rx_agent", "is_active", UVM_PASSIVE);

// In the agent
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  uvm_config_db #(uvm_active_passive_enum)::get(this, "", "is_active", is_active);
  if (is_active == UVM_ACTIVE) begin
    drv = my_driver::type_id::create("drv", this);
    sqr = my_sequencer::type_id::create("sqr", this);
  end
  mon = my_monitor::type_id::create("mon", this);
endfunction
```

### Pattern 2: Number of Transactions

```systemverilog
// In the test
uvm_config_db #(int)::set(this, "env*", "num_txns", 500);

// In the sequence
int num_txns;
task body();
  if (!uvm_config_db #(int)::get(null, get_full_name(), "num_txns", num_txns))
    num_txns = 100;  // default
  repeat(num_txns) begin
    // generate transactions
  end
endtask
```

### Pattern 3: Multiple Interface Instances

```systemverilog
// In top module
uvm_config_db #(virtual axi_if)::set(null, "uvm_test_top.env.master_agent*", "vif", axi_master_intf);
uvm_config_db #(virtual axi_if)::set(null, "uvm_test_top.env.slave_agent*",  "vif", axi_slave_intf);
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Wrong type parameter in `get` vs. `set` | Types must match exactly |
| `get()` before `set()` (build order) | Ensure parent's `build_phase` sets before child's gets |
| Missing wildcard in path | Use `agent*` not `agent` to include children |
| Not checking `get()` return value | Always check and issue `uvm_fatal` on failure |
| Using `uvm_resource_db` instead | Prefer `uvm_config_db` — it is hierarchy-aware |

---

## Summary

| Operation | Syntax |
|-----------|--------|
| Set | `uvm_config_db #(T)::set(context, path, field, value)` |
| Get | `uvm_config_db #(T)::get(context, path, field, variable)` |
| Check | `uvm_config_db #(T)::exists(context, path, field)` |
| Debug | `+UVM_CONFIG_DB_TRACE` on command line |

## Next Steps

Continue to [Chapter 8: TLM (Transaction Level Modeling)](08_tlm.md) to learn about inter-component communication.
