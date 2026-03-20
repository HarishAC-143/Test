# Chapter 3 -- UVM Advanced Topics

## 3.1 Callbacks

Callbacks allow you to inject behavior into existing components **without modifying their
source code**. This is critical for VIP reuse.

### Defining a Callback Class

```systemverilog
class driver_callback extends uvm_callback;
  `uvm_object_utils(driver_callback)

  function new(string name = "driver_callback");
    super.new(name);
  endfunction

  // Hook: called before driving a transaction
  virtual task pre_drive(my_driver drv, my_transaction tx);
  endtask

  // Hook: called after driving a transaction
  virtual task post_drive(my_driver drv, my_transaction tx);
  endtask
endclass
```

### Registering Callbacks in the Component

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)
  `uvm_register_cb(my_driver, driver_callback)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);

      // Execute all registered pre_drive callbacks
      `uvm_do_callbacks(my_driver, driver_callback, pre_drive(this, req))

      @(posedge vif.clk);
      vif.addr  <= req.addr;
      vif.data  <= req.data;
      vif.valid <= 1'b1;
      @(posedge vif.clk);
      vif.valid <= 1'b0;

      // Execute all registered post_drive callbacks
      `uvm_do_callbacks(my_driver, driver_callback, post_drive(this, req))

      seq_item_port.item_done();
    end
  endtask
endclass
```

### Using Callbacks in a Test

```systemverilog
class error_inject_callback extends driver_callback;
  `uvm_object_utils(error_inject_callback)

  function new(string name = "error_inject_callback");
    super.new(name);
  endfunction

  virtual task pre_drive(my_driver drv, my_transaction tx);
    // Corrupt data 10% of the time
    if ($urandom_range(0, 9) == 0) begin
      tx.data = $urandom();
      `uvm_info("CB", "Injected error into transaction", UVM_LOW)
    end
  endtask
endclass

class error_injection_test extends base_test;
  `uvm_component_utils(error_injection_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Register the callback
    error_inject_callback cb = error_inject_callback::type_id::create("cb");
    uvm_callbacks#(my_driver, driver_callback)::add(null, cb);
  endfunction
endclass
```

---

## 3.2 Virtual Sequences and Virtual Sequencers

When a testbench has **multiple agents**, you need to coordinate sequences across them.
Virtual sequences run on a virtual sequencer that holds handles to real sequencers.

### Virtual Sequencer

```systemverilog
class my_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(my_virtual_sequencer)

  // Handles to real sequencers
  my_sequencer  cpu_sqr;
  my_sequencer  dma_sqr;
  mem_sequencer mem_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

### Connecting in the Environment

```systemverilog
class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)

  my_agent            cpu_agt;
  my_agent            dma_agt;
  mem_agent           mem_agt;
  my_virtual_sequencer v_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_agt = my_agent::type_id::create("cpu_agt", this);
    dma_agt = my_agent::type_id::create("dma_agt", this);
    mem_agt = mem_agent::type_id::create("mem_agt", this);
    v_sqr   = my_virtual_sequencer::type_id::create("v_sqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    v_sqr.cpu_sqr = cpu_agt.sqr;
    v_sqr.dma_sqr = dma_agt.sqr;
    v_sqr.mem_sqr = mem_agt.sqr;
  endfunction
endclass
```

### Virtual Sequence

```systemverilog
class coordinated_traffic_vseq extends uvm_sequence;
  `uvm_object_utils(coordinated_traffic_vseq)
  `uvm_declare_p_sequencer(my_virtual_sequencer)

  function new(string name = "coordinated_traffic_vseq");
    super.new(name);
  endfunction

  virtual task body();
    write_sequence  cpu_wr_seq;
    read_sequence   cpu_rd_seq;
    dma_sequence    dma_seq;

    // Phase 1: CPU writes data
    cpu_wr_seq = write_sequence::type_id::create("cpu_wr_seq");
    cpu_wr_seq.start(p_sequencer.cpu_sqr);

    // Phase 2: DMA and CPU read in parallel
    fork
      begin
        cpu_rd_seq = read_sequence::type_id::create("cpu_rd_seq");
        cpu_rd_seq.start(p_sequencer.cpu_sqr);
      end
      begin
        dma_seq = dma_sequence::type_id::create("dma_seq");
        dma_seq.start(p_sequencer.dma_sqr);
      end
    join
  endtask
endclass
```

### Starting the Virtual Sequence from the Test

```systemverilog
class traffic_test extends uvm_test;
  `uvm_component_utils(traffic_test)

  soc_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = soc_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    coordinated_traffic_vseq vseq;

    phase.raise_objection(this);

    vseq = coordinated_traffic_vseq::type_id::create("vseq");
    vseq.start(env.v_sqr);

    phase.drop_objection(this);
  endtask
endclass
```

---

## 3.3 UVM Register Abstraction Layer (RAL)

The Register Abstraction Layer provides a high-level, structured way to model and access
DUT registers, supporting both front-door (bus) and back-door (hierarchical) access.

### Register Model Hierarchy

```
uvm_reg_block
├── uvm_reg (register)
│   ├── uvm_reg_field (bit field)
│   └── uvm_reg_field
├── uvm_reg
└── uvm_reg_block (sub-block)
```

### Defining Registers

```systemverilog
// ──────── Individual Register ────────
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field reserved;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable = uvm_reg_field::type_id::create("enable");
    enable.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
    //                     size, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible

    mode = uvm_reg_field::type_id::create("mode");
    mode.configure(this, 2, 1, "RW", 0, 2'b00, 1, 1, 0);

    reserved = uvm_reg_field::type_id::create("reserved");
    reserved.configure(this, 29, 3, "RO", 0, 29'h0, 1, 0, 0);
  endfunction
endclass

// ──────── Status Register (read-only) ────────
class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)

  rand uvm_reg_field busy;
  rand uvm_reg_field error;
  rand uvm_reg_field done;

  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy = uvm_reg_field::type_id::create("busy");
    busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);

    error = uvm_reg_field::type_id::create("error");
    error.configure(this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);

    done = uvm_reg_field::type_id::create("done");
    done.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
  endfunction
endclass
```

### Defining the Register Block

```systemverilog
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg    ctrl;
  rand status_reg  status;
  rand uvm_reg     data_reg;

  uvm_reg_map      default_map;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    ctrl = ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this);
    ctrl.build();

    status = status_reg::type_id::create("status");
    status.configure(this);
    status.build();

    // Create the address map
    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
    default_map.add_reg(ctrl,   'h00, "RW");
    default_map.add_reg(status, 'h04, "RO");
  endfunction
endclass
```

### Connecting RAL to the Bus

```systemverilog
class reg2bus_adapter extends uvm_reg_adapter;
  `uvm_object_utils(reg2bus_adapter)

  function new(string name = "reg2bus_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 1;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    my_transaction tx = my_transaction::type_id::create("tx");
    tx.write = (rw.kind == UVM_WRITE);
    tx.addr  = rw.addr[7:0];
    tx.data  = rw.data;
    return tx;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    my_transaction tx;
    if (!$cast(tx, bus_item))
      `uvm_fatal("ADAPT", "Cast failed")
    rw.kind   = tx.write ? UVM_WRITE : UVM_READ;
    rw.addr   = tx.addr;
    rw.data   = tx.data;
    rw.status = UVM_IS_OK;
  endfunction
endclass
```

### Using the Register Model in Tests

```systemverilog
class reg_test extends base_test;
  `uvm_component_utils(reg_test)

  my_reg_block reg_model;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reg_model = my_reg_block::type_id::create("reg_model");
    reg_model.build();
    reg_model.lock_model();
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    reg2bus_adapter adapter = reg2bus_adapter::type_id::create("adapter");
    reg_model.default_map.set_sequencer(env.agt.sqr, adapter);
    reg_model.default_map.set_auto_predict(1);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e   status;
    uvm_reg_data_t data;

    phase.raise_objection(this);

    // Write to ctrl register
    reg_model.ctrl.write(status, 32'h0000_0005);
    `uvm_info("TEST", $sformatf("Wrote ctrl: status=%s", status.name()), UVM_LOW)

    // Read status register
    reg_model.status.read(status, data);
    `uvm_info("TEST", $sformatf("Read status: 0x%08h", data), UVM_LOW)

    // Mirror check -- read from DUT and compare with model
    reg_model.ctrl.mirror(status, UVM_CHECK);

    // Access individual fields
    reg_model.ctrl.enable.set(1);
    reg_model.ctrl.mode.set(2'b10);
    reg_model.ctrl.update(status);

    phase.drop_objection(this);
  endtask
endclass
```

### Built-in Register Test Sequences

UVM provides pre-built sequences for common register testing:

```systemverilog
task run_phase(uvm_phase phase);
  uvm_reg_hw_reset_seq  reset_seq;
  uvm_reg_bit_bash_seq  bit_bash_seq;
  uvm_reg_access_seq    access_seq;

  phase.raise_objection(this);

  // Verify all registers read back their reset values
  reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
  reset_seq.model = reg_model;
  reset_seq.start(env.agt.sqr);

  // Write/read-back every bit position
  bit_bash_seq = uvm_reg_bit_bash_seq::type_id::create("bit_bash_seq");
  bit_bash_seq.model = reg_model;
  bit_bash_seq.start(env.agt.sqr);

  phase.drop_objection(this);
endtask
```

---

## 3.4 Advanced Sequence Techniques

### Sequence Library

A sequence library holds multiple sequences and runs them in configurable patterns:

```systemverilog
class my_seq_lib extends uvm_sequence_library #(my_transaction);
  `uvm_object_utils(my_seq_lib)
  `uvm_sequence_library_utils(my_seq_lib)

  function new(string name = "my_seq_lib");
    super.new(name);
    init_sequence_library();
  endfunction
endclass

// Register sequences with the library
class random_write_seq extends uvm_sequence #(my_transaction);
  `uvm_object_utils(random_write_seq)
  `uvm_add_to_seq_lib(random_write_seq, my_seq_lib)

  function new(string name = "random_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_do_with(req, { write == 1; })
  endtask
endclass

class random_read_seq extends uvm_sequence #(my_transaction);
  `uvm_object_utils(random_read_seq)
  `uvm_add_to_seq_lib(random_read_seq, my_seq_lib)

  function new(string name = "random_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_do_with(req, { write == 0; })
  endtask
endclass
```

### Layered Sequences (Protocol Layers)

Model protocol stacks by layering sequences:

```systemverilog
// Lower layer: byte-level transactions
class byte_sequence extends uvm_sequence #(byte_item);
  `uvm_object_utils(byte_sequence)

  uvm_tlm_analysis_fifo #(packet_item) upper_layer_fifo;

  function new(string name = "byte_sequence");
    super.new(name);
    upper_layer_fifo = new("upper_layer_fifo");
  endfunction

  virtual task body();
    packet_item pkt;
    byte_item   byte_tx;

    forever begin
      upper_layer_fifo.get(pkt);
      // Fragment packet into bytes
      foreach (pkt.payload[i]) begin
        byte_tx = byte_item::type_id::create("byte_tx");
        start_item(byte_tx);
        byte_tx.data = pkt.payload[i];
        byte_tx.sof  = (i == 0);
        byte_tx.eof  = (i == pkt.payload.size() - 1);
        finish_item(byte_tx);
      end
    end
  endtask
endclass
```

### Reactive Sequences (Slave/Responder)

```systemverilog
class slave_response_seq extends uvm_sequence #(my_transaction);
  `uvm_object_utils(slave_response_seq)

  function new(string name = "slave_response_seq");
    super.new(name);
  endfunction

  virtual task body();
    my_transaction req, rsp;

    forever begin
      // Wait for the driver to forward a request from the bus
      p_sequencer.item_collected_port.get(req);

      rsp = my_transaction::type_id::create("rsp");
      start_item(rsp);

      if (!req.write) begin
        // Return data for read requests
        rsp.data = lookup_memory(req.addr);
      end
      rsp.set_id_info(req);

      finish_item(rsp);
    end
  endtask
endclass
```

---

## 3.5 Advanced Factory Techniques

### Parameterized Class Overrides

```systemverilog
class generic_driver #(int WIDTH = 8) extends uvm_driver #(generic_txn #(WIDTH));
  typedef generic_driver #(WIDTH) this_type;
  `uvm_component_param_utils(this_type)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// Override for a specific parameterization
class wide_driver extends generic_driver #(32);
  `uvm_component_utils(wide_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// In the test
function void build_phase(uvm_phase phase);
  generic_driver#(32)::type_id::set_type_override(wide_driver::get_type());
  super.build_phase(phase);
endfunction
```

### Factory Debug

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  // Print the entire factory configuration
  factory.print();
  // Print the component topology
  uvm_top.print_topology();
endfunction
```

---

## 3.6 UVM Event and Barrier Synchronization

### Events

```systemverilog
class my_env extends uvm_env;
  uvm_event reset_done_event;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Get or create a named event in the global pool
    reset_done_event = uvm_event_pool::get_global("reset_done");
  endfunction
endclass

// In the reset agent
task run_phase(uvm_phase phase);
  // ... perform reset ...
  uvm_event_pool::get_global("reset_done").trigger();
endtask

// In the main agent
task run_phase(uvm_phase phase);
  uvm_event_pool::get_global("reset_done").wait_trigger();
  // ... start normal operation ...
endtask
```

### Barriers

```systemverilog
class sync_test extends uvm_test;
  uvm_barrier sync_barrier;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sync_barrier = uvm_barrier_pool::get_global("sync");
    sync_barrier.set_threshold(3);  // wait for 3 participants
  endfunction
endclass

// In each agent's run_phase
task run_phase(uvm_phase phase);
  // ... initialization ...
  uvm_barrier_pool::get_global("sync").wait_for();
  // All 3 agents proceed together
endtask
```

---

## 3.7 Heartbeat Monitoring

The heartbeat mechanism detects hung components:

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
    // Monitor these components for activity
    hb.add(agt.drv);
    hb.add(agt.mon);
  endfunction

  task run_phase(uvm_phase phase);
    hb.start(hb_event);
    // Trigger heartbeat periodically
    forever begin
      #1000ns;
      hb_event.trigger();
    end
  endtask
endclass
```

---

## 3.8 Advanced Coverage Strategies

### Register Coverage

```systemverilog
class my_reg_block extends uvm_reg_block;
  function new(string name = "my_reg_block");
    // Enable built-in register coverage
    super.new(name, build_coverage(UVM_CVR_REG_BITS |
                                    UVM_CVR_ADDR_MAP |
                                    UVM_CVR_FIELD_VALS));
  endfunction

  virtual function void build();
    // ... register creation ...
    // Enable sampling
    void'(set_coverage(UVM_CVR_ALL));
  endfunction
endclass
```

### Cross-Agent Coverage

```systemverilog
class system_coverage extends uvm_component;
  `uvm_component_utils(system_coverage)

  uvm_analysis_imp_decl(_cpu)
  uvm_analysis_imp_decl(_dma)

  uvm_analysis_imp_cpu #(my_transaction, system_coverage) cpu_export;
  uvm_analysis_imp_dma #(my_transaction, system_coverage) dma_export;

  my_transaction last_cpu_tx;
  my_transaction last_dma_tx;

  covergroup cross_agent_cg;
    cpu_type: coverpoint last_cpu_tx.write;
    dma_type: coverpoint last_dma_tx.write;
    simultaneous: cross cpu_type, dma_type;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cross_agent_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cpu_export = new("cpu_export", this);
    dma_export = new("dma_export", this);
  endfunction

  function void write_cpu(my_transaction tx);
    last_cpu_tx = tx;
    if (last_dma_tx != null) cross_agent_cg.sample();
  endfunction

  function void write_dma(my_transaction tx);
    last_dma_tx = tx;
    if (last_cpu_tx != null) cross_agent_cg.sample();
  endfunction
endclass
```

---

## 3.9 Best Practices Summary

| Area | Recommendation |
|------|---------------|
| Factory | Always create objects via `type_id::create()` |
| Config DB | Use configuration objects instead of many individual `set` calls |
| Objections | Raise/drop only in the test or top-level sequence |
| Sequences | Prefer `start_item`/`finish_item` over `uvm_do` macros |
| Reporting | Use meaningful message IDs for filtering |
| Phases | Keep `build_phase` for construction, `connect_phase` for wiring |
| Topology | Print topology in `end_of_elaboration_phase` for debug |
| Coverage | Close coverage in `report_phase` and log the percentage |
| Reuse | Use callbacks and factory overrides; avoid hard-coded types |
| Naming | Follow consistent naming: `*_agent`, `*_driver`, `*_monitor`, `*_seq` |

---

**Previous:** [Chapter 2 -- UVM Intermediate](02_uvm_intermediate.md) |
**Next:** [Practical Examples](../examples/)
