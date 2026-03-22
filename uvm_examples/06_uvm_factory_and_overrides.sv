// =============================================================================
// Example 06: UVM Factory, Type Overrides, and Instance Overrides
// Demonstrates: factory registration, type_id::create, set_type_override,
//               set_inst_override, factory debug printing.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Base transaction ---
class base_txn extends uvm_sequence_item;
  `uvm_object_utils(base_txn)

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "base_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("[base_txn] addr=0x%08h data=0x%08h", addr, data);
  endfunction
endclass

// --- Extended transaction: adds error injection ---
class error_txn extends base_txn;
  `uvm_object_utils(error_txn)

  rand bit        inject_error;
  rand bit [3:0]  error_type;

  constraint c_error_rate {
    inject_error dist { 0 := 80, 1 := 20 };
  }

  function new(string name = "error_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string base_str = super.convert2string();
    return $sformatf("[error_txn] %s inject_error=%0b error_type=%0d",
                     base_str, inject_error, error_type);
  endfunction
endclass

// --- Extended transaction: adds coverage fields ---
class coverage_txn extends base_txn;
  `uvm_object_utils(coverage_txn)

  rand bit [1:0] access_type;  // 0=single, 1=burst, 2=wrap
  rand bit [7:0] burst_len;

  constraint c_burst {
    access_type == 0 -> burst_len == 0;
    access_type == 1 -> burst_len inside {[1:15]};
    access_type == 2 -> burst_len inside {1, 3, 7, 15};
  }

  function new(string name = "coverage_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("[coverage_txn] addr=0x%08h data=0x%08h type=%0d burst=%0d",
                     addr, data, access_type, burst_len);
  endfunction
endclass

// --- Base driver ---
class base_driver extends uvm_driver #(base_txn);
  `uvm_component_utils(base_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    base_txn txn;
    forever begin
      seq_item_port.get_next_item(txn);
      `uvm_info("DRV", $sformatf("Driving: %s", txn.convert2string()), UVM_MEDIUM)
      #10;
      seq_item_port.item_done();
    end
  endtask
endclass

// --- Debug driver (override target) ---
class debug_driver extends base_driver;
  `uvm_component_utils(debug_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    base_txn txn;
    forever begin
      seq_item_port.get_next_item(txn);
      `uvm_info("DBG_DRV", $sformatf("[DEBUG] Driving: %s", txn.convert2string()), UVM_LOW)
      #10;
      seq_item_port.item_done();
    end
  endtask
endclass

// --- Sequencer ---
class base_sequencer extends uvm_sequencer #(base_txn);
  `uvm_component_utils(base_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// --- Simple sequence ---
class simple_seq extends uvm_sequence #(base_txn);
  `uvm_object_utils(simple_seq)

  int unsigned num_txns = 5;

  function new(string name = "simple_seq");
    super.new(name);
  endfunction

  virtual task body();
    base_txn txn;
    repeat (num_txns) begin
      txn = base_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("RAND", "Randomization failed")
      `uvm_info("SEQ", $sformatf("Created: %s [type: %s]",
                txn.convert2string(), txn.get_type_name()), UVM_MEDIUM)
      finish_item(txn);
    end
  endtask
endclass

// --- Agent ---
class base_agent extends uvm_agent;
  `uvm_component_utils(base_agent)

  base_driver    drv;
  base_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = base_driver::type_id::create("drv", this);
    sqr = base_sequencer::type_id::create("sqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// --- Environment with two agents ---
class factory_env extends uvm_env;
  `uvm_component_utils(factory_env)

  base_agent agent_a;
  base_agent agent_b;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent_a = base_agent::type_id::create("agent_a", this);
    agent_b = base_agent::type_id::create("agent_b", this);
  endfunction
endclass

// --- Test 1: No overrides (baseline) ---
class test_no_override extends uvm_test;
  `uvm_component_utils(test_no_override)

  factory_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = factory_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    simple_seq seq = simple_seq::type_id::create("seq");
    seq.num_txns = 3;

    phase.raise_objection(this);
    `uvm_info("TEST", "=== Test with NO overrides ===", UVM_LOW)
    seq.start(env.agent_a.sqr);
    phase.drop_objection(this);
  endtask
endclass

// --- Test 2: Type override (all base_txn → error_txn) ---
class test_type_override extends uvm_test;
  `uvm_component_utils(test_type_override)

  factory_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Type override: everywhere base_txn is created, error_txn is used instead
    base_txn::type_id::set_type_override(error_txn::get_type());

    env = factory_env::type_id::create("env", this);

    // Print the factory to show overrides
    uvm_factory::get().print();
  endfunction

  virtual task run_phase(uvm_phase phase);
    simple_seq seq = simple_seq::type_id::create("seq");
    seq.num_txns = 3;

    phase.raise_objection(this);
    `uvm_info("TEST", "=== Test with TYPE override (base_txn -> error_txn) ===", UVM_LOW)
    seq.start(env.agent_a.sqr);
    phase.drop_objection(this);
  endtask
endclass

// --- Test 3: Instance override ---
class test_instance_override extends uvm_test;
  `uvm_component_utils(test_instance_override)

  factory_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Instance override: only agent_a's driver is replaced with debug_driver
    base_driver::type_id::set_inst_override(
      debug_driver::get_type(),
      "env.agent_a.drv",
      this
    );

    env = factory_env::type_id::create("env", this);
    uvm_factory::get().print();
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info("TEST", "\n=== Component Topology ===", UVM_LOW)
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    simple_seq seq_a = simple_seq::type_id::create("seq_a");
    simple_seq seq_b = simple_seq::type_id::create("seq_b");
    seq_a.num_txns = 2;
    seq_b.num_txns = 2;

    phase.raise_objection(this);
    `uvm_info("TEST", "=== Test with INSTANCE override (agent_a.drv -> debug_driver) ===", UVM_LOW)

    `uvm_info("TEST", "--- Running on agent_a (debug_driver) ---", UVM_LOW)
    seq_a.start(env.agent_a.sqr);

    `uvm_info("TEST", "--- Running on agent_b (base_driver) ---", UVM_LOW)
    seq_b.start(env.agent_b.sqr);

    phase.drop_objection(this);
  endtask
endclass

// --- Top module ---
// Run different tests with: +UVM_TESTNAME=test_no_override
//                           +UVM_TESTNAME=test_type_override
//                           +UVM_TESTNAME=test_instance_override
module tb_factory;
  initial begin
    run_test();
  end
endmodule
