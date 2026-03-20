# Advanced Chapter 4: Callbacks

## What Are Callbacks?

Callbacks allow you to **inject additional behavior** into existing UVM components without modifying their source code. This is essential for:

- Adding error injection to a reusable agent
- Inserting protocol checks from a test without editing the driver
- Extending verification IP (VIP) you don't own

## UVM Callback Mechanism

### Step 1: Define the Callback Class

```systemverilog
class driver_callback extends uvm_callback;
  `uvm_object_utils(driver_callback)

  function new(string name = "driver_callback");
    super.new(name);
  endfunction

  // Hook called before driving a transaction
  virtual task pre_drive(my_driver drv, my_transaction tx);
  endtask

  // Hook called after driving a transaction
  virtual task post_drive(my_driver drv, my_transaction tx);
  endtask
endclass
```

### Step 2: Register Callbacks in the Component

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)
  `uvm_register_cb(my_driver, driver_callback)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    my_transaction req;
    forever begin
      seq_item_port.get_next_item(req);

      // Call pre_drive callbacks
      `uvm_do_callbacks(my_driver, driver_callback, pre_drive(this, req))

      drive_on_bus(req);

      // Call post_drive callbacks
      `uvm_do_callbacks(my_driver, driver_callback, post_drive(this, req))

      seq_item_port.item_done();
    end
  endtask

  task drive_on_bus(my_transaction tx);
    @(posedge vif.clk);
    vif.addr  <= tx.addr;
    vif.data  <= tx.data;
    vif.valid <= 1'b1;
    @(posedge vif.clk);
    vif.valid <= 1'b0;
  endtask
endclass
```

### Step 3: Implement a Concrete Callback

```systemverilog
class error_injection_cb extends driver_callback;
  `uvm_object_utils(error_injection_cb)

  int error_rate = 10;  // 10% error rate

  function new(string name = "error_injection_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(my_driver drv, my_transaction tx);
    if ($urandom_range(0, 99) < error_rate) begin
      `uvm_info("CB", $sformatf("Injecting error on addr=0x%04h", tx.addr), UVM_MEDIUM)
      tx.data = ~tx.data;  // corrupt data
    end
  endtask

  virtual task post_drive(my_driver drv, my_transaction tx);
    `uvm_info("CB", $sformatf("Transaction completed: %s", tx.convert2string()), UVM_HIGH)
  endtask
endclass
```

### Step 4: Add Callback from the Test

```systemverilog
class error_injection_test extends base_test;
  `uvm_component_utils(error_injection_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    begin
      error_injection_cb cb = error_injection_cb::type_id::create("err_cb");
      cb.error_rate = 20;  // 20% error injection

      // Add callback to the driver
      uvm_callbacks #(my_driver, driver_callback)::add(env.agent.drv, cb);
    end
  endfunction
endclass
```

## Practical Examples

### Example 1: Delay Injection

```systemverilog
class delay_cb extends driver_callback;
  `uvm_object_utils(delay_cb)

  int min_delay = 1;
  int max_delay = 10;

  function new(string name = "delay_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(my_driver drv, my_transaction tx);
    int delay = $urandom_range(min_delay, max_delay);
    `uvm_info("CB", $sformatf("Inserting %0d cycle delay", delay), UVM_HIGH)
    repeat(delay) @(posedge drv.vif.clk);
  endtask
endclass
```

### Example 2: Protocol Checker Callback

```systemverilog
class protocol_checker_cb extends driver_callback;
  `uvm_object_utils(protocol_checker_cb)

  bit [15:0] last_addr;
  bit        first = 1;

  function new(string name = "protocol_checker_cb");
    super.new(name);
  endfunction

  virtual task post_drive(my_driver drv, my_transaction tx);
    if (!first && tx.addr == last_addr && tx.write)
      `uvm_warning("CB", $sformatf("Back-to-back write to same address 0x%04h", tx.addr))
    last_addr = tx.addr;
    first = 0;
  endtask
endclass
```

### Example 3: Coverage Callback

```systemverilog
class coverage_cb extends driver_callback;
  `uvm_object_utils(coverage_cb)

  covergroup txn_cg with function sample(bit [15:0] addr, bit write);
    addr_cp: coverpoint addr { bins ranges[] = {[0:16'hFFFF]}; }
    wr_cp: coverpoint write;
    cross addr_cp, wr_cp;
  endgroup

  function new(string name = "coverage_cb");
    super.new(name);
    txn_cg = new();
  endfunction

  virtual task post_drive(my_driver drv, my_transaction tx);
    txn_cg.sample(tx.addr, tx.write);
  endtask
endclass
```

## Managing Multiple Callbacks

```systemverilog
// Add multiple callbacks — they execute in order of addition
uvm_callbacks #(my_driver, driver_callback)::add(env.agent.drv, cb1);
uvm_callbacks #(my_driver, driver_callback)::add(env.agent.drv, cb2);

// Remove a specific callback
uvm_callbacks #(my_driver, driver_callback)::delete(env.agent.drv, cb1);

// Add callback to ALL instances of my_driver
uvm_callbacks #(my_driver, driver_callback)::add(null, cb1);

// Display all registered callbacks
uvm_callbacks #(my_driver, driver_callback)::display();
```

## Callbacks vs. Factory Overrides

| Feature | Callbacks | Factory Override |
|---------|-----------|-----------------|
| Modifies component? | No — adds behavior alongside | Yes — replaces the entire component |
| Multiple extensions? | Yes — can stack multiple callbacks | One override at a time |
| Scope | Can target specific instances | Per-type or per-instance |
| Use case | Cross-cutting concerns (logging, injection) | Replacing component behavior entirely |

## Best Practices

1. **Design callback hooks proactively** — add hooks at natural extension points in reusable components.
2. **Keep callbacks lightweight** — heavy logic belongs in components, not callbacks.
3. **Use meaningful names** for callback methods (`pre_drive`, `post_check`, etc.).
4. **Document available hooks** — users of your VIP need to know where they can extend.
5. **Prefer callbacks over factory overrides** when you want to *add* behavior, not *replace* it.

## Next Steps

Continue to [Chapter 5: Advanced Sequences](05_advanced_sequences.md) for layered sequences, pipelining, and more.
