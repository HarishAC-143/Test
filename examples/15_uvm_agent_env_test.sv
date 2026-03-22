// UVM Agent, Environment, and Test Example
//
// Demonstrates the complete structural hierarchy:
//   - uvm_agent: groups driver, sequencer, monitor; supports active/passive modes
//   - uvm_env: assembles agents, scoreboards, coverage collectors
//   - uvm_test: top-level configuration, sequence launching, phase objections
//   - uvm_scoreboard: reference-model-based checking with analysis imports
//   - Config object pattern for passing structured configuration

`ifndef APB_AGENT_ENV_TEST_SV
`define APB_AGENT_ENV_TEST_SV

`include "uvm_macros.svh"
import uvm_pkg::*;


// ═══════════════════════════════════════════════════════════════
//  Configuration Object
//  Passed through uvm_config_db to parameterize the environment
//  without hard-coded values.
// ═══════════════════════════════════════════════════════════════

class apb_env_config extends uvm_object;
  `uvm_object_utils(apb_env_config)

  virtual apb_if               vif;
  uvm_active_passive_enum      is_active = UVM_ACTIVE;
  bit                          enable_scoreboard = 1;
  bit                          enable_coverage = 1;
  int unsigned                 num_transactions = 100;

  function new(string name = "apb_env_config");
    super.new(name);
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  APB Sequencer
//  Thin wrapper — the built-in uvm_sequencer provides all the
//  arbitration and item routing.
// ═══════════════════════════════════════════════════════════════

class apb_sequencer extends uvm_sequencer #(apb_transaction);
  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  APB Agent
//  Contains driver + sequencer (active mode) or monitor only
//  (passive mode). Always instantiates the monitor.
// ═══════════════════════════════════════════════════════════════

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_sequencer sqr;
  apb_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon = apb_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
      `uvm_info(get_type_name(), "Built in ACTIVE mode (driver + sequencer + monitor)", UVM_LOW)
    end else begin
      `uvm_info(get_type_name(), "Built in PASSIVE mode (monitor only)", UVM_LOW)
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  APB Scoreboard
//  Implements a simple memory reference model. Writes update the
//  model; reads are checked against it.
// ═══════════════════════════════════════════════════════════════

`uvm_analysis_imp_decl(_observed)

class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp_observed #(apb_transaction, apb_scoreboard) ap_imp;

  // Reference model: simple associative-array memory
  protected bit [31:0] ref_memory [bit [31:0]];

  int unsigned write_count;
  int unsigned read_count;
  int unsigned pass_count;
  int unsigned fail_count;
  int unsigned uninitialized_read_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    write_count = 0;
    read_count  = 0;
    pass_count  = 0;
    fail_count  = 0;
    uninitialized_read_count = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction

  // Called automatically each time the monitor broadcasts a transaction
  virtual function void write_observed(apb_transaction txn);
    if (txn.slv_error) begin
      `uvm_info(get_type_name(),
        $sformatf("Slave error on %s — skipping check", txn.convert2string()),
        UVM_MEDIUM)
      return;
    end

    case (txn.operation)
      APB_WRITE: begin
        ref_memory[txn.addr] = txn.data;
        write_count++;
        `uvm_info(get_type_name(),
          $sformatf("REF MODEL WRITE: mem[0x%08h] = 0x%08h",
                    txn.addr, txn.data),
          UVM_HIGH)
      end

      APB_READ: begin
        read_count++;
        if (ref_memory.exists(txn.addr)) begin
          if (txn.read_data === ref_memory[txn.addr]) begin
            pass_count++;
            `uvm_info(get_type_name(),
              $sformatf("CHECK PASS: mem[0x%08h] = 0x%08h",
                        txn.addr, txn.read_data),
              UVM_HIGH)
          end else begin
            fail_count++;
            `uvm_error(get_type_name(),
              $sformatf("CHECK FAIL: mem[0x%08h] expected=0x%08h actual=0x%08h",
                        txn.addr, ref_memory[txn.addr], txn.read_data))
          end
        end else begin
          uninitialized_read_count++;
          `uvm_warning(get_type_name(),
            $sformatf("Read from uninitialized address 0x%08h (data=0x%08h)",
                      txn.addr, txn.read_data))
        end
      end

      default: begin
        `uvm_warning(get_type_name(),
          $sformatf("Unexpected operation: %s", txn.operation.name()))
      end
    endcase
  endfunction

  // Final status report
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "═══ Scoreboard Summary ═══", UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Writes:               %0d", write_count), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Reads:                %0d", read_count), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Read checks passed:   %0d", pass_count), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Read checks failed:   %0d", fail_count), UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("  Uninitialized reads:  %0d", uninitialized_read_count), UVM_LOW)

    if (fail_count > 0)
      `uvm_error(get_type_name(),
        $sformatf("TEST FAILED: %0d read mismatches detected", fail_count))
    else if (read_count == 0 && write_count == 0)
      `uvm_warning(get_type_name(), "No transactions observed — scoreboard idle")
    else
      `uvm_info(get_type_name(), "TEST PASSED", UVM_LOW)
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  APB Environment
//  Assembles agent + scoreboard and connects analysis paths.
// ═══════════════════════════════════════════════════════════════

class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scoreboard;
  apb_env_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve environment configuration
    if (!uvm_config_db#(apb_env_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", {"Environment config not found for ", get_full_name()})

    // Push interface and active/passive setting down to agent subtree
    uvm_config_db#(virtual apb_if)::set(this, "agent.*", "vif", cfg.vif);
    uvm_config_db#(int)::set(this, "agent", "is_active", cfg.is_active);
    uvm_config_db#(bit)::set(this, "agent.mon", "enable_coverage", cfg.enable_coverage);

    // Create components
    agent = apb_agent::type_id::create("agent", this);

    if (cfg.enable_scoreboard)
      scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg.enable_scoreboard)
      agent.mon.ap.connect(scoreboard.ap_imp);
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  Base Test
//  Provides common setup for all test variants.
// ═══════════════════════════════════════════════════════════════

class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env        env;
  apb_env_config env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Build configuration
    env_cfg = apb_env_config::type_id::create("env_cfg");
    configure_env(env_cfg);

    // Retrieve the virtual interface from the top-level testbench module
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", env_cfg.vif))
      `uvm_fatal("NOVIF", "No virtual interface found at test level")

    // Push configuration down
    uvm_config_db#(apb_env_config)::set(this, "env", "cfg", env_cfg);

    // Create environment
    env = apb_env::type_id::create("env", this);
  endfunction

  // Override in derived tests to change configuration
  virtual function void configure_env(apb_env_config cfg);
    cfg.is_active          = UVM_ACTIVE;
    cfg.enable_scoreboard  = 1;
    cfg.enable_coverage    = 1;
    cfg.num_transactions   = 100;
  endfunction

  // Print the component hierarchy for debug
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info(get_type_name(), "Printing UVM topology:", UVM_LOW)
    uvm_top.print_topology();
  endfunction

  // Set a simulation timeout
  virtual function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    uvm_top.set_timeout(10ms, 0);
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  Concrete Test: Write-Read Test
// ═══════════════════════════════════════════════════════════════

class apb_write_read_test extends apb_base_test;
  `uvm_component_utils(apb_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_read_seq seq;

    phase.raise_objection(this, "Starting write-read test");

    seq = apb_write_read_seq::type_id::create("seq");
    seq.num_transactions = env_cfg.num_transactions;
    seq.start(env.agent.sqr);

    phase.drop_objection(this, "Write-read test complete");
  endtask
endclass


// ═══════════════════════════════════════════════════════════════
//  Concrete Test: Stress Test
// ═══════════════════════════════════════════════════════════════

class apb_stress_test extends apb_base_test;
  `uvm_component_utils(apb_stress_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void configure_env(apb_env_config cfg);
    super.configure_env(cfg);
    cfg.num_transactions = 500;
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_stress_seq seq;

    phase.raise_objection(this, "Starting stress test");

    seq = apb_stress_seq::type_id::create("seq");
    if (!seq.randomize() with { num_transactions == env_cfg.num_transactions; })
      `uvm_fatal("RAND", "Stress sequence randomization failed")
    seq.start(env.agent.sqr);

    #1us;
    phase.drop_objection(this, "Stress test complete");
  endtask
endclass


// ═══════════════════════════════════════════════════════════════
//  Concrete Test: Factory Override Test
//  Demonstrates using factory overrides to change transaction
//  behavior without modifying existing components.
// ═══════════════════════════════════════════════════════════════

class apb_error_transaction extends apb_transaction;
  `uvm_object_utils(apb_error_transaction)

  // Force addresses into an invalid range to trigger slave errors
  constraint error_addr_c {
    addr inside {[32'hFFFF_0000 : 32'hFFFF_FFFF]};
  }

  function new(string name = "apb_error_transaction");
    super.new(name);
  endfunction
endclass

class apb_error_test extends apb_base_test;
  `uvm_component_utils(apb_error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    // Factory override: replace all apb_transaction instances with
    // apb_error_transaction — the constraint will force error addresses
    apb_transaction::type_id::set_type_override(
      apb_error_transaction::get_type());

    super.build_phase(phase);

    `uvm_info(get_type_name(),
      "Factory override applied: apb_transaction -> apb_error_transaction",
      UVM_LOW)
  endfunction

  virtual function void configure_env(apb_env_config cfg);
    super.configure_env(cfg);
    cfg.enable_scoreboard = 0;  // Errors expected, disable checking
    cfg.num_transactions  = 20;
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_base_sequence seq;

    phase.raise_objection(this, "Starting error injection test");

    seq = apb_base_sequence::type_id::create("seq");
    seq.start(env.agent.sqr);

    #500ns;
    phase.drop_objection(this, "Error test complete");
  endtask
endclass

`endif
