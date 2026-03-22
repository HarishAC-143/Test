// =============================================================================
// Example 06: UVM Factory and Configuration Database
// Covers: factory registration, type_id::create, type overrides,
//         instance overrides, uvm_config_db set/get, configuration objects
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;


// ─── Configuration Object ───
class my_config extends uvm_object;
  `uvm_object_utils(my_config)

  int unsigned    num_transactions = 10;
  bit             enable_coverage  = 1;
  bit             enable_checking  = 1;
  bit [31:0]      base_addr       = 32'h0000_0000;
  string          protocol_name   = "APB";

  function new(string name = "my_config");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("Config: txns=%0d cov=%0b chk=%0b base=0x%08h proto=%s",
                     num_transactions, enable_coverage, enable_checking,
                     base_addr, protocol_name);
  endfunction
endclass


// ─── Base Transaction ───
class base_txn extends uvm_sequence_item;
  `uvm_object_utils(base_txn)

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "base_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("base_txn: addr=0x%08h data=0x%08h", addr, data);
  endfunction
endclass


// ─── Extended Transaction (for factory override demonstration) ───
class extended_txn extends base_txn;
  `uvm_object_utils(extended_txn)

  rand bit [7:0] qos;
  rand bit [3:0] region;

  constraint c_qos { qos inside {[0:15]}; }

  function new(string name = "extended_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("extended_txn: addr=0x%08h data=0x%08h qos=%0d region=%0d",
                     addr, data, qos, region);
  endfunction
endclass


// ─── Base Driver ───
class base_driver extends uvm_driver #(base_txn);
  `uvm_component_utils(base_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    `uvm_info("DRV", $sformatf("I am %s (type: %s)", get_full_name(), get_type_name()), UVM_LOW)
  endtask
endclass


// ─── Enhanced Driver (for factory override) ───
class enhanced_driver extends base_driver;
  `uvm_component_utils(enhanced_driver)

  int max_retries = 3;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db #(int)::get(this, "", "max_retries", max_retries));
    `uvm_info("DRV", $sformatf("max_retries = %0d", max_retries), UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    `uvm_info("DRV", $sformatf("I am ENHANCED %s (type: %s, retries=%0d)",
              get_full_name(), get_type_name(), max_retries), UVM_LOW)
  endtask
endclass


// ─── Simple Agent ───
class simple_agent extends uvm_agent;
  `uvm_component_utils(simple_agent)

  base_driver drv;
  my_config   cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(my_config)::get(this, "", "cfg", cfg))
      `uvm_info("AGENT", "No config found — using defaults", UVM_MEDIUM)
    else
      `uvm_info("AGENT", {"Config: ", cfg.convert2string()}, UVM_LOW)

    drv = base_driver::type_id::create("drv", this);
  endfunction
endclass


// ─── Environment ───
class simple_env extends uvm_env;
  `uvm_component_utils(simple_env)

  simple_agent agent_a;
  simple_agent agent_b;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent_a = simple_agent::type_id::create("agent_a", this);
    agent_b = simple_agent::type_id::create("agent_b", this);
  endfunction
endclass


// ─── Test: Demonstrating Factory + Config DB ───
class factory_demo_test extends uvm_test;
  `uvm_component_utils(factory_demo_test)

  simple_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    my_config cfg_a, cfg_b;

    super.build_phase(phase);

    // -- Factory Override: all base_driver → enhanced_driver (only in agent_b) --
    base_driver::type_id::set_inst_override(
      enhanced_driver::get_type(), "env.agent_b.drv", this);

    // -- Factory Override: all base_txn → extended_txn globally --
    base_txn::type_id::set_type_override(extended_txn::get_type());

    // -- Config DB: pass config objects --
    cfg_a = my_config::type_id::create("cfg_a");
    cfg_a.num_transactions = 50;
    cfg_a.base_addr        = 32'h1000_0000;
    cfg_a.protocol_name    = "AXI";
    uvm_config_db #(my_config)::set(this, "env.agent_a", "cfg", cfg_a);

    cfg_b = my_config::type_id::create("cfg_b");
    cfg_b.num_transactions = 200;
    cfg_b.base_addr        = 32'h2000_0000;
    cfg_b.protocol_name    = "AHB";
    cfg_b.enable_coverage  = 0;
    uvm_config_db #(my_config)::set(this, "env.agent_b", "cfg", cfg_b);

    // -- Config DB: pass integer config to enhanced driver --
    uvm_config_db #(int)::set(this, "env.agent_b.drv", "max_retries", 7);

    env = simple_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);

    `uvm_info("TEST", "\n=== Component Topology ===", UVM_LOW)
    uvm_top.print_topology();

    `uvm_info("TEST", "\n=== Factory Configuration ===", UVM_LOW)
    factory.print();
  endfunction

  virtual task run_phase(uvm_phase phase);
    base_txn txn;
    phase.raise_objection(this);

    `uvm_info("TEST", "\n=== Factory Object Creation ===", UVM_LOW)
    repeat (3) begin
      txn = base_txn::type_id::create("txn");
      void'(txn.randomize());
      `uvm_info("TEST", $sformatf("  Created: %s (type=%s)",
                txn.convert2string(), txn.get_type_name()), UVM_LOW)
    end

    #100;
    phase.drop_objection(this);
  endtask
endclass


module tb_factory_config;
  initial begin
    run_test("factory_demo_test");
  end
endmodule
