# 6. UVM Advanced Topics

[&larr; Previous: Configuration & Factory](05_uvm_config_factory.md) | [Back to Main](../README.md)

---

## 6.1 UVM Register Abstraction Layer (RAL)

The Register Abstraction Layer provides a high-level, object-oriented model of the DUT's programmable registers. It enables:

- **Front-door access** — Read/write registers through the bus protocol (driver/sequencer).
- **Back-door access** — Read/write registers directly via the simulator's hierarchical path (faster, no protocol overhead).
- **Automatic checking** — Compare register model values against DUT values.
- **Coverage** — Automatic coverage of register fields.

### 6.1.1 Defining a Register

```systemverilog
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field irq_mask;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);  // 32-bit register
  endfunction

  virtual function void build();
    enable   = uvm_reg_field::type_id::create("enable");
    mode     = uvm_reg_field::type_id::create("mode");
    irq_mask = uvm_reg_field::type_id::create("irq_mask");

    //             parent, size, lsb, access,  volatile, reset, has_reset, rand, individually_accessible
    enable.configure  (this, 1,   0,   "RW",    0,       0,     1,         1,    1);
    mode.configure    (this, 2,   1,   "RW",    0,       0,     1,         1,    1);
    irq_mask.configure(this, 8,   8,   "RW",    0,       0,     1,         1,    1);
  endfunction
endclass
```

### 6.1.2 Defining a Register Block

```systemverilog
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg   ctrl;
  rand status_reg status;
  rand data_reg   data;

  uvm_reg_map map;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    // Create registers
    ctrl   = ctrl_reg::type_id::create("ctrl");
    status = status_reg::type_id::create("status");
    data   = data_reg::type_id::create("data");

    // Build each register
    ctrl.build();
    ctrl.configure(this);

    status.build();
    status.configure(this);

    data.build();
    data.configure(this);

    // Create address map
    map = create_map("map", 'h0, 4, UVM_LITTLE_ENDIAN);  // base=0, bus_width=4 bytes

    // Add registers to address map
    map.add_reg(ctrl,   'h00, "RW");  // offset 0x00
    map.add_reg(status, 'h04, "RO");  // offset 0x04
    map.add_reg(data,   'h08, "RW");  // offset 0x08

    lock_model();  // finalize the model
  endfunction
endclass
```

### 6.1.3 Register Adapter

The adapter converts between UVM register operations and your bus protocol transactions:

```systemverilog
class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  // Convert register operation → bus transaction
  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_txn txn = apb_txn::type_id::create("txn");
    txn.addr = rw.addr;
    txn.dir  = (rw.kind == UVM_READ) ? READ : WRITE;
    txn.data = rw.data;
    return txn;
  endfunction

  // Convert bus transaction → register operation
  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_txn txn;
    if (!$cast(txn, bus_item)) begin
      `uvm_fatal("CAST", "Failed to cast bus_item to apb_txn")
      return;
    end
    rw.addr   = txn.addr;
    rw.kind   = (txn.dir == READ) ? UVM_READ : UVM_WRITE;
    rw.data   = txn.data;
    rw.status = UVM_IS_OK;
  endfunction
endclass
```

### 6.1.4 Integrating RAL into the Environment

```systemverilog
class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  apb_agent        agt;
  my_reg_block     reg_model;
  apb_reg_adapter  adapter;
  uvm_reg_predictor #(apb_txn) predictor;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agt = apb_agent::type_id::create("agt", this);

    // Build register model
    reg_model = my_reg_block::type_id::create("reg_model");
    reg_model.build();

    adapter = apb_reg_adapter::type_id::create("adapter");

    predictor = uvm_reg_predictor#(apb_txn)::type_id::create("predictor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect register model to sequencer via adapter
    reg_model.map.set_sequencer(agt.sqr, adapter);
    reg_model.map.set_auto_predict(0);

    // Connect predictor
    predictor.map     = reg_model.map;
    predictor.adapter = adapter;
    agt.mon.ap.connect(predictor.bus_in);
  endfunction
endclass
```

### 6.1.5 Using RAL in Sequences

```systemverilog
class reg_access_seq extends uvm_reg_sequence;
  `uvm_object_utils(reg_access_seq)

  my_reg_block reg_model;

  function new(string name = "reg_access_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_status_e status;
    uvm_reg_data_t rdata;

    // Write to control register
    reg_model.ctrl.write(status, 32'h0000_0005);  // enable=1, mode=2
    if (status != UVM_IS_OK)
      `uvm_error("REG", "Control register write failed")

    // Read status register
    reg_model.status.read(status, rdata);
    `uvm_info("REG", $sformatf("Status register = 0x%08h", rdata), UVM_MEDIUM)

    // Write individual fields
    reg_model.ctrl.enable.set(1);
    reg_model.ctrl.mode.set(2'b10);
    reg_model.ctrl.update(status);  // write the whole register

    // Read individual fields
    reg_model.ctrl.mirror(status, UVM_CHECK);  // read and check against model

    // Built-in test sequences
    begin
      uvm_reg_hw_reset_seq rst_seq;
      rst_seq = uvm_reg_hw_reset_seq::type_id::create("rst_seq");
      rst_seq.model = reg_model;
      rst_seq.start(null);
    end
  endtask
endclass
```

### 6.1.6 Built-in Register Test Sequences

UVM provides several pre-built register test sequences:

| Sequence | Purpose |
|----------|---------|
| `uvm_reg_hw_reset_seq` | Verify all registers read back their reset values |
| `uvm_reg_bit_bash_seq` | Write walking-1/walking-0 patterns to all RW fields |
| `uvm_reg_access_seq` | Verify register access (read/write) |
| `uvm_reg_mem_walk_seq` | Walk through memory addresses |
| `uvm_reg_mem_shared_access_seq` | Test shared memory access |

---

## 6.2 UVM Callbacks

Callbacks let you inject behavior into existing components **without modifying their source code**. This is useful for error injection, protocol variations, and test-specific modifications.

### 6.2.1 Defining a Callback Class

```systemverilog
class driver_callback extends uvm_callback;
  `uvm_object_utils(driver_callback)

  function new(string name = "driver_callback");
    super.new(name);
  endfunction

  // Callback method — called before driving a transaction
  virtual function void pre_drive(apb_driver drv, apb_txn txn);
  endfunction

  // Callback method — called after driving a transaction
  virtual function void post_drive(apb_driver drv, apb_txn txn);
  endfunction
endclass
```

### 6.2.2 Adding Callback Hooks to a Component

```systemverilog
class apb_driver extends uvm_driver #(apb_txn);
  `uvm_component_utils(apb_driver)
  `uvm_register_cb(apb_driver, driver_callback)

  virtual task run_phase(uvm_phase phase);
    apb_txn txn;
    forever begin
      seq_item_port.get_next_item(txn);

      // Execute pre-drive callbacks
      `uvm_do_callbacks(apb_driver, driver_callback, pre_drive(this, txn))

      drive_txn(txn);

      // Execute post-drive callbacks
      `uvm_do_callbacks(apb_driver, driver_callback, post_drive(this, txn))

      seq_item_port.item_done();
    end
  endtask
endclass
```

### 6.2.3 Implementing and Registering a Callback

```systemverilog
class error_inject_cb extends driver_callback;
  `uvm_object_utils(error_inject_cb)

  function new(string name = "error_inject_cb");
    super.new(name);
  endfunction

  virtual function void pre_drive(apb_driver drv, apb_txn txn);
    // Corrupt data on 5% of transactions
    if ($urandom_range(99) < 5) begin
      txn.data = $urandom();
      `uvm_info("CB", $sformatf("Injecting error: data = 0x%08h", txn.data), UVM_LOW)
    end
  endfunction
endclass

// In the test:
class error_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    error_inject_cb cb = error_inject_cb::type_id::create("cb");
    uvm_callbacks#(apb_driver, driver_callback)::add(env.agt.drv, cb);
  endfunction
endclass
```

---

## 6.3 Functional Coverage

### 6.3.1 Coverage Collector Using `uvm_subscriber`

```systemverilog
class apb_coverage extends uvm_subscriber #(apb_txn);
  `uvm_component_utils(apb_coverage)

  apb_txn txn;

  covergroup apb_cg;
    option.per_instance = 1;

    cp_dir: coverpoint txn.dir {
      bins read  = {READ};
      bins write = {WRITE};
    }

    cp_addr: coverpoint txn.addr {
      bins low    = {[32'h0000:32'h00FF]};
      bins mid    = {[32'h0100:32'h0FFF]};
      bins high   = {[32'h1000:32'hFFFF]};
    }

    cp_data: coverpoint txn.data {
      bins zero     = {0};
      bins max      = {32'hFFFF_FFFF};
      bins others   = default;
    }

    cx_dir_addr: cross cp_dir, cp_addr;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_txn t);
    txn = t;
    apb_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("APB Coverage: %.2f%%", apb_cg.get_coverage()), UVM_NONE)
  endfunction
endclass
```

### 6.3.2 Coverage in Sequences

```systemverilog
class coverage_driven_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(coverage_driven_seq)

  covergroup seq_cg with function sample(bit [31:0] addr, bit dir);
    cp_addr: coverpoint addr { bins addrs[] = {[0:255]}; }
    cp_dir: coverpoint dir;
    cx: cross cp_addr, cp_dir;
  endgroup

  function new(string name = "coverage_driven_seq");
    super.new(name);
    seq_cg = new();
  endfunction

  virtual task body();
    apb_txn txn;
    int iterations = 0;

    while (seq_cg.get_coverage() < 95.0 && iterations < 10000) begin
      txn = apb_txn::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize());
      finish_item(txn);
      seq_cg.sample(txn.addr, txn.dir);
      iterations++;
    end

    `uvm_info("SEQ", $sformatf("Reached %.2f%% coverage in %0d iterations",
              seq_cg.get_coverage(), iterations), UVM_LOW)
  endtask
endclass
```

---

## 6.4 UVM Reporting & Messaging

### 6.4.1 Message Severity Levels

| Macro | Severity | Behavior |
|-------|----------|----------|
| `` `uvm_info(ID, MSG, VERB) `` | Info | Print if verbosity allows |
| `` `uvm_warning(ID, MSG) `` | Warning | Always print |
| `` `uvm_error(ID, MSG) `` | Error | Increment error count; stop if max reached |
| `` `uvm_fatal(ID, MSG) `` | Fatal | Stop simulation immediately |

### 6.4.2 Controlling Verbosity

```systemverilog
// Per component
env.agt.drv.set_report_verbosity_level(UVM_HIGH);

// Per ID
env.agt.drv.set_report_verbosity_level_hier(UVM_DEBUG);

// Per severity
env.set_report_severity_action(UVM_WARNING, UVM_DISPLAY | UVM_LOG);
```

From the command line:

```
+UVM_VERBOSITY=UVM_HIGH
+uvm_set_verbosity=env.agt.drv,*,UVM_DEBUG,run
```

### 6.4.3 Severity Overrides

Change how a specific message is treated:

```systemverilog
// Promote warnings to errors for a specific ID
env.set_report_severity_id_override(UVM_WARNING, "TIMEOUT", UVM_ERROR);

// Demote errors to warnings (use cautiously)
env.set_report_severity_id_override(UVM_ERROR, "KNOWN_BUG", UVM_WARNING);
```

### 6.4.4 Custom Report Server

```systemverilog
class my_report_server extends uvm_report_server;

  virtual function string compose_report_message(
    uvm_report_message report_message,
    string report_object_name = ""
  );
    string severity_str;
    case (report_message.get_severity())
      UVM_INFO:    severity_str = "INFO";
      UVM_WARNING: severity_str = "WARN";
      UVM_ERROR:   severity_str = "ERROR";
      UVM_FATAL:   severity_str = "FATAL";
    endcase

    return $sformatf("[%0t] %s [%s] %s",
      $time, severity_str,
      report_message.get_id(),
      report_message.get_message()
    );
  endfunction
endclass

// Install custom report server
initial begin
  my_report_server srv = new();
  uvm_report_server::set_server(srv);
  run_test();
end
```

### 6.4.5 Max Error Count

```systemverilog
// Stop simulation after 10 errors
function void start_of_simulation_phase(uvm_phase phase);
  uvm_report_server srv = uvm_report_server::get_server();
  srv.set_max_quit_count(10);
endfunction
```

---

## 6.5 UVM Event Pool

Events provide synchronization between components:

```systemverilog
// Getting a shared event
uvm_event_pool ep = uvm_event_pool::get_global_pool();
uvm_event reset_done = ep.get("reset_done");

// In the reset controller:
task run_phase(uvm_phase phase);
  // ... perform reset ...
  reset_done.trigger();
endtask

// In a component waiting for reset:
task run_phase(uvm_phase phase);
  reset_done.wait_trigger();
  // ... proceed after reset ...
endtask
```

---

## 6.6 UVM Heartbeat

Monitor liveness of components — detect hangs:

```systemverilog
class my_env extends uvm_env;
  uvm_heartbeat hb;
  uvm_event     hb_event;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    hb_event = new("hb_event");
    hb = new("hb", this, hb_event);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    uvm_component comps[$];
    comps.push_back(agt.drv);
    comps.push_back(agt.mon);
    hb.set_mode(UVM_ALL_ACTIVE);
    hb.set_heartbeat(comps, hb_event);
  endfunction

  task run_phase(uvm_phase phase);
    // Trigger heartbeat periodically
    forever begin
      #1000;
      hb_event.trigger();
    end
  endtask
endclass
```

---

## 6.7 UVM Barrier

Synchronize multiple components at a specific point:

```systemverilog
uvm_barrier_pool bp = uvm_barrier_pool::get_global_pool();
uvm_barrier sync_barrier = bp.get("sync_point");

// Set threshold (number of components to wait for)
sync_barrier.set_threshold(3);

// In each component:
task run_phase(uvm_phase phase);
  // ... initialization ...
  sync_barrier.wait_for();  // block until all 3 arrive
  // ... synchronized operation ...
endtask
```

---

## 6.8 UVM Command-Line Processing

### Built-in Plus Arguments

| Argument | Purpose |
|----------|---------|
| `+UVM_TESTNAME=test_class` | Select test to run |
| `+UVM_VERBOSITY=UVM_HIGH` | Set global verbosity |
| `+UVM_TIMEOUT=1000000` | Set simulation timeout (ns) |
| `+UVM_MAX_QUIT_COUNT=10` | Stop after N errors |
| `+UVM_CONFIG_DB_TRACE` | Trace config_db operations |
| `+UVM_DUMP_CMDLINE_ARGS` | Print all command-line args |
| `+UVM_PHASE_TRACE` | Trace phase execution |
| `+UVM_OBJECTION_TRACE` | Trace objection raise/drop |

### Custom Plus Arguments

```systemverilog
class my_test extends uvm_test;
  int num_iterations;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Read +NUM_ITER=500 from command line
    if (!$value$plusargs("NUM_ITER=%d", num_iterations))
      num_iterations = 100;  // default

    `uvm_info("TEST", $sformatf("Running %0d iterations", num_iterations), UVM_LOW)
  endfunction
endclass
```

Using UVM's command-line processor:

```systemverilog
uvm_cmdline_processor clp = uvm_cmdline_processor::get_inst();
string val;
if (clp.get_arg_value("+MY_PARAM=", val))
  `uvm_info("TEST", $sformatf("MY_PARAM = %s", val), UVM_LOW)
```

---

## 6.9 End-of-Test Mechanisms

### Drain Time

Allow time for in-flight transactions after objections drop:

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  phase.get_objection().set_drain_time(this, 200ns);
  // ...
  phase.drop_objection(this);
  // Simulation continues for 200ns after drop
endtask
```

### Timeout

Prevent infinite simulation:

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  uvm_top.set_timeout(10ms, 0);  // 10ms timeout, non-overridable
endfunction
```

### All-Dropped Callback

Execute code when all objections are dropped:

```systemverilog
class my_test extends uvm_test;
  virtual task all_dropped(uvm_objection objection, uvm_object source_obj,
                           string description, int count);
    // Final cleanup after all objections dropped
    #100ns;  // extra drain time
  endtask
endclass
```

---

## 6.10 Best Practices Checklist

1. **Always use the factory** — `type_id::create()` instead of `new()`.
2. **Use config objects** — Bundle related config into objects, not individual `set`/`get` calls.
3. **Only raise objections in tests/sequences** — Not in drivers or monitors.
4. **Keep monitors passive** — Never drive signals from a monitor.
5. **Use analysis ports** — For monitor-to-scoreboard/coverage communication.
6. **Separate concerns** — One component per responsibility.
7. **Make agents reusable** — Parameterize with config objects and support active/passive modes.
8. **Use factory overrides** — Instead of #ifdefs or conditional logic for test variations.
9. **Close coverage holes systematically** — Use coverage-driven sequences.
10. **Set appropriate verbosity** — `UVM_MEDIUM` for development, `UVM_LOW` for regression.
11. **Use `report_phase`** — Print pass/fail summary at the end of every test.
12. **Avoid global variables** — Use `uvm_config_db` or TLM instead.

---

## 6.11 Summary

| Topic | Key Takeaway |
|-------|-------------|
| RAL | Object-oriented register model with front-door/back-door access |
| Callbacks | Inject behavior without modifying source components |
| Coverage | Use `uvm_subscriber` and covergroups for functional coverage |
| Reporting | Severity levels, verbosity control, custom report servers |
| Events/Barriers | Synchronization primitives for component coordination |
| Command-line | Extensive plus-arg support for runtime configuration |
| End-of-test | Drain time, timeouts, objection callbacks |

---

[&larr; Previous: Configuration & Factory](05_uvm_config_factory.md) | [Back to Main](../README.md)
