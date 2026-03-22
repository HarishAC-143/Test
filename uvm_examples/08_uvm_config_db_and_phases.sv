// =============================================================================
// Example 08: UVM Configuration Database and Phases
// Demonstrates: uvm_config_db set/get, configuration objects, phase callbacks,
//               build/connect/run/report phase flow, objection mechanism.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Configuration class ---
class dut_config extends uvm_object;
  `uvm_object_utils(dut_config)

  uvm_active_passive_enum is_active;
  bit                     has_coverage;
  bit                     has_scoreboard;
  int unsigned            max_errors;
  int unsigned            timeout_ns;
  string                  protocol;

  function new(string name = "dut_config");
    super.new(name);
    is_active      = UVM_ACTIVE;
    has_coverage   = 1;
    has_scoreboard = 1;
    max_errors     = 10;
    timeout_ns     = 100000;
    protocol       = "APB";
  endfunction

  virtual function string convert2string();
    return $sformatf("Config: active=%s cov=%0b scb=%0b max_err=%0d timeout=%0dns proto=%s",
                     is_active.name(), has_coverage, has_scoreboard,
                     max_errors, timeout_ns, protocol);
  endfunction
endclass

// --- Component that retrieves config_db values ---
class config_consumer extends uvm_component;
  `uvm_component_utils(config_consumer)

  dut_config     cfg;
  int            threshold;
  string         mode_string;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve configuration object
    if (!uvm_config_db #(dut_config)::get(this, "", "cfg", cfg))
      `uvm_warning("CFG", "No config object found — using defaults")
    else
      `uvm_info("CFG", $sformatf("Retrieved config: %s", cfg.convert2string()), UVM_LOW)

    // Retrieve scalar values
    if (!uvm_config_db #(int)::get(this, "", "threshold", threshold)) begin
      threshold = 100;
      `uvm_info("CFG", $sformatf("threshold not found, defaulting to %0d", threshold), UVM_MEDIUM)
    end else
      `uvm_info("CFG", $sformatf("threshold = %0d", threshold), UVM_MEDIUM)

    if (!uvm_config_db #(string)::get(this, "", "mode", mode_string)) begin
      mode_string = "normal";
      `uvm_info("CFG", $sformatf("mode not found, defaulting to '%s'", mode_string), UVM_MEDIUM)
    end else
      `uvm_info("CFG", $sformatf("mode = '%s'", mode_string), UVM_MEDIUM)
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] connect_phase called", get_full_name()), UVM_LOW)
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] end_of_elaboration_phase called", get_full_name()), UVM_LOW)
  endfunction

  virtual function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] start_of_simulation_phase called", get_full_name()), UVM_LOW)
  endfunction

  virtual task run_phase(uvm_phase phase);
    `uvm_info("PHASE", $sformatf("[%s] run_phase started (consumes time)", get_full_name()), UVM_LOW)
    #100;
    `uvm_info("PHASE", $sformatf("[%s] run_phase ended", get_full_name()), UVM_LOW)
  endtask

  virtual function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] extract_phase called", get_full_name()), UVM_LOW)
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] check_phase called", get_full_name()), UVM_LOW)
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] report_phase called — threshold=%0d mode=%s",
              get_full_name(), threshold, mode_string), UVM_LOW)
  endfunction

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] final_phase called", get_full_name()), UVM_LOW)
  endfunction
endclass

// --- Sub-environment ---
class sub_env extends uvm_env;
  `uvm_component_utils(sub_env)

  config_consumer consumer_a;
  config_consumer consumer_b;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] build_phase called", get_full_name()), UVM_LOW)
    consumer_a = config_consumer::type_id::create("consumer_a", this);
    consumer_b = config_consumer::type_id::create("consumer_b", this);
  endfunction
endclass

// --- Top environment ---
class top_env extends uvm_env;
  `uvm_component_utils(top_env)

  sub_env sub;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] build_phase called", get_full_name()), UVM_LOW)
    sub = sub_env::type_id::create("sub", this);
  endfunction
endclass

// --- Test ---
class config_phase_test extends uvm_test;
  `uvm_component_utils(config_phase_test)

  top_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    dut_config cfg;

    super.build_phase(phase);
    `uvm_info("PHASE", $sformatf("[%s] build_phase called", get_full_name()), UVM_LOW)

    // --- Config DB: set configuration object for all consumers ---
    cfg = dut_config::type_id::create("cfg");
    cfg.is_active      = UVM_ACTIVE;
    cfg.has_coverage   = 1;
    cfg.max_errors     = 5;
    cfg.timeout_ns     = 50000;
    cfg.protocol       = "AXI";

    // Wildcard: available to all components matching "env.sub.*"
    uvm_config_db #(dut_config)::set(this, "env.sub.*", "cfg", cfg);

    // --- Config DB: scalar values with different scoping ---

    // Set threshold=200 for consumer_a specifically
    uvm_config_db #(int)::set(this, "env.sub.consumer_a", "threshold", 200);

    // Set threshold=500 for consumer_b specifically
    uvm_config_db #(int)::set(this, "env.sub.consumer_b", "threshold", 500);

    // Set mode for all consumers
    uvm_config_db #(string)::set(this, "env.sub.*", "mode", "turbo");

    // Override mode just for consumer_b (more specific wins)
    uvm_config_db #(string)::set(this, "env.sub.consumer_b", "mode", "debug");

    env = top_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info("TOPO", "\n=== Component Topology ===", UVM_LOW)
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    `uvm_info("PHASE", $sformatf("[%s] run_phase started", get_full_name()), UVM_LOW)

    phase.raise_objection(this, "Test running");

    `uvm_info("TEST", "Test is running — waiting 200 time units", UVM_LOW)
    #200;
    `uvm_info("TEST", "Test completed", UVM_LOW)

    phase.drop_objection(this, "Test done");
  endtask

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("TEST", "\n========== TEST SUMMARY ==========", UVM_LOW)
    `uvm_info("TEST", "All phases executed in correct order", UVM_LOW)
    `uvm_info("TEST", "Config DB values successfully propagated", UVM_LOW)
    `uvm_info("TEST", "==================================", UVM_LOW)
  endfunction
endclass

// --- Top module ---
module tb_config_phases;
  initial begin
    run_test("config_phase_test");
  end
endmodule
