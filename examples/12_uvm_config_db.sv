// =============================================================================
// UVM config_db Example — Complete Testbench
// =============================================================================
//
// Demonstrates uvm_config_db usage for:
//   - Passing virtual interfaces from a static module to dynamic UVM classes
//   - Distributing configuration objects through the component hierarchy
//   - Scoping, precedence rules, and runtime parameter passing
//
// Hierarchy:
//   tb_top (module)
//     └─ apb_test (uvm_test)
//          └─ apb_env (uvm_env)
//               ├─ agent (apb_agent)
//               │    ├─ driver   (apb_driver)
//               │    ├─ monitor  (apb_monitor)
//               │    └─ sequencer(uvm_sequencer)
//               └─ scoreboard (apb_scoreboard)
//
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// -----------------------------------------------------------------------------
// APB Interface
// -----------------------------------------------------------------------------
interface apb_if(input logic pclk, input logic preset_n);
  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  modport master(
    output paddr, psel, penable, pwrite, pwdata,
    input  prdata, pready, pslverr
  );

  modport slave(
    input  paddr, psel, penable, pwrite, pwdata,
    output prdata, pready, pslverr
  );

  modport monitor(
    input paddr, psel, penable, pwrite, pwdata,
         prdata, pready, pslverr
  );
endinterface

// -----------------------------------------------------------------------------
// Transaction
// -----------------------------------------------------------------------------
class apb_txn extends uvm_sequence_item;
  `uvm_object_utils(apb_txn)

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  rand int        delay;

  bit [31:0] rdata;
  bit        slverr;

  constraint addr_align_c { addr[1:0] == 2'b00; }
  constraint delay_c      { delay inside {[0:15]}; }

  function new(string name = "apb_txn");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h delay=%0d",
                     write ? "WR" : "RD", addr, data, delay);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Agent Configuration Object
//
// Bundles all agent-level settings into a single object so they can be passed
// through config_db in one call instead of many individual set/get operations.
// -----------------------------------------------------------------------------
class apb_agent_cfg extends uvm_object;
  `uvm_object_utils(apb_agent_cfg)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit                     has_coverage = 1;
  int unsigned            max_retry = 3;
  int unsigned            timeout_cycles = 1000;

  function new(string name = "apb_agent_cfg");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("is_active=%s has_cov=%0b max_retry=%0d timeout=%0d",
                     is_active.name(), has_coverage, max_retry, timeout_cycles);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Environment Configuration Object
//
// Top-level configuration that contains sub-configs for each agent.
// The environment retrieves this, then redistributes sub-configs to children.
// -----------------------------------------------------------------------------
class apb_env_cfg extends uvm_object;
  `uvm_object_utils(apb_env_cfg)

  apb_agent_cfg agent_cfg;
  bit           has_scoreboard = 1;
  int unsigned  num_transactions = 100;

  function new(string name = "apb_env_cfg");
    super.new(name);
    agent_cfg = apb_agent_cfg::type_id::create("agent_cfg");
  endfunction
endclass

// -----------------------------------------------------------------------------
// Driver
//
// Retrieves its virtual interface from config_db in build_phase.
// This is the most common config_db pattern: bridging the static/dynamic
// boundary by passing virtual interfaces.
// -----------------------------------------------------------------------------
class apb_driver extends uvm_driver#(apb_txn);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve the virtual interface — fatal if not found
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", {"Virtual interface not found for ", get_full_name()})

    `uvm_info("DRV", $sformatf("Virtual interface retrieved for %s", get_full_name()), UVM_MEDIUM)
  endfunction

  task run_phase(uvm_phase phase);
    apb_txn txn;
    forever begin
      seq_item_port.get_next_item(txn);
      drive_transfer(txn);
      seq_item_port.item_done();
    end
  endtask

  task drive_transfer(apb_txn txn);
    repeat (txn.delay) @(posedge vif.pclk);

    // Setup phase
    @(posedge vif.pclk);
    vif.paddr   <= txn.addr;
    vif.pwrite  <= txn.write;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;
    if (txn.write) vif.pwdata <= txn.data;

    // Access phase
    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    // Wait for ready
    @(posedge vif.pclk iff vif.pready);
    if (!txn.write) txn.rdata = vif.prdata;
    txn.slverr = vif.pslverr;

    // Idle
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;

    `uvm_info("DRV", $sformatf("Driven: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass

// -----------------------------------------------------------------------------
// Monitor
//
// Also retrieves the virtual interface from config_db. Multiple components
// can retrieve the same interface — config_db supports many readers.
// -----------------------------------------------------------------------------
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port#(apb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", {"Virtual interface not found for ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    apb_txn txn;
    forever begin
      @(posedge vif.pclk iff (vif.psel && vif.penable && vif.pready));
      txn = apb_txn::type_id::create("txn");
      txn.addr   = vif.paddr;
      txn.write  = vif.pwrite;
      txn.data   = vif.pwrite ? vif.pwdata : '0;
      txn.rdata  = vif.prdata;
      txn.slverr = vif.pslverr;
      ap.write(txn);
      `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
    end
  endtask
endclass

// -----------------------------------------------------------------------------
// Scoreboard
// -----------------------------------------------------------------------------
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp#(apb_txn, apb_scoreboard) analysis_export;
  int unsigned txn_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_txn txn);
    txn_count++;
    `uvm_info("SCB", $sformatf("Received txn #%0d: %s", txn_count, txn.convert2string()), UVM_MEDIUM)
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("Total transactions observed: %0d", txn_count), UVM_LOW)
  endfunction
endclass

// -----------------------------------------------------------------------------
// Agent
//
// Retrieves its agent_cfg from config_db. Uses the config to decide whether
// to build a driver and sequencer (active agent) or monitor only (passive).
// Then redistributes the virtual interface to its children.
// -----------------------------------------------------------------------------
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver              driver;
  apb_monitor             monitor;
  uvm_sequencer#(apb_txn) sequencer;

  apb_agent_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve agent configuration from config_db
    if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", {"Agent config not found for ", get_full_name()})

    `uvm_info("AGENT", $sformatf("Config: %s", cfg.convert2string()), UVM_MEDIUM)

    // Always build a monitor
    monitor = apb_monitor::type_id::create("monitor", this);

    // Conditionally build driver and sequencer based on config
    if (cfg.is_active == UVM_ACTIVE) begin
      driver    = apb_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(apb_txn)::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Environment
//
// Retrieves its env_cfg from config_db, then redistributes sub-configs
// (agent_cfg and virtual interface) to child components. This cascading
// pattern is the standard way to distribute configuration in UVM.
// -----------------------------------------------------------------------------
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scoreboard;
  apb_env_cfg    cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Step 1: Retrieve environment config from config_db
    if (!uvm_config_db#(apb_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", {"Environment config not found for ", get_full_name()})

    // Step 2: Redistribute sub-configs to children
    // The agent will retrieve its cfg in its own build_phase
    uvm_config_db#(apb_agent_cfg)::set(this, "agent", "cfg", cfg.agent_cfg);

    // Step 3: Build components
    agent = apb_agent::type_id::create("agent", this);

    if (cfg.has_scoreboard)
      scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    if (cfg.has_scoreboard)
      agent.monitor.ap.connect(scoreboard.analysis_export);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Base Sequence
// -----------------------------------------------------------------------------
class apb_base_seq extends uvm_sequence#(apb_txn);
  `uvm_object_utils(apb_base_seq)

  int unsigned num_txns = 10;

  function new(string name = "apb_base_seq");
    super.new(name);
  endfunction

  task body();
    apb_txn txn;

    // Retrieve num_transactions from config_db (sequences are objects, not
    // components, so use null context and the sequencer's full name)
    uvm_config_db#(int unsigned)::get(
      null, get_sequencer().get_full_name(), "num_transactions", num_txns);

    `uvm_info("SEQ", $sformatf("Running %0d transactions", num_txns), UVM_LOW)

    repeat (num_txns) begin
      txn = apb_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_error("RAND", "Transaction randomization failed")
      finish_item(txn);
    end
  endtask
endclass

// -----------------------------------------------------------------------------
// Test — Base
//
// Sets up all config_db entries. This is the central place where test-specific
// configuration is defined.
// -----------------------------------------------------------------------------
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env     env;
  apb_env_cfg env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create and configure the environment config object
    env_cfg = apb_env_cfg::type_id::create("env_cfg");
    env_cfg.has_scoreboard = 1;
    env_cfg.num_transactions = 20;
    env_cfg.agent_cfg.is_active = UVM_ACTIVE;
    env_cfg.agent_cfg.has_coverage = 1;
    env_cfg.agent_cfg.timeout_cycles = 500;

    // Pass the config object through config_db to the environment
    uvm_config_db#(apb_env_cfg)::set(this, "env", "cfg", env_cfg);

    // Pass scalar parameter for the sequence (demonstrates individual value passing)
    uvm_config_db#(int unsigned)::set(this, "env.agent.sequencer", "num_transactions",
                                      env_cfg.num_transactions);

    env = apb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_base_seq seq;
    phase.raise_objection(this);
    seq = apb_base_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info("TEST", "--- Topology ---", UVM_LOW)
    uvm_top.print_topology();
  endfunction
endclass

// -----------------------------------------------------------------------------
// Test — High-Traffic (Inherits and overrides config values)
//
// Demonstrates config_db precedence: a higher-level component's set() wins
// over a lower-level component's set(). The test's values override anything
// the environment might set internally.
// -----------------------------------------------------------------------------
class apb_high_traffic_test extends apb_base_test;
  `uvm_component_utils(apb_high_traffic_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Override the transaction count — this wins because the test is
    // higher in the hierarchy than the environment
    env_cfg.num_transactions = 1000;
    uvm_config_db#(int unsigned)::set(this, "env.agent.sequencer",
                                      "num_transactions", 1000);
  endfunction
endclass

// -----------------------------------------------------------------------------
// Top-level Module
//
// This is where virtual interfaces are instantiated and placed into config_db.
// The set() call uses null context and a wildcard scope so any component
// under uvm_test_top can retrieve the interface.
// -----------------------------------------------------------------------------
module tb_top;
  logic pclk, preset_n;

  // Clock generation
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // Reset generation
  initial begin
    preset_n = 0;
    #100;
    preset_n = 1;
  end

  // Interface instance
  apb_if apb_vif(pclk, preset_n);

  // Simple slave model for demonstration
  assign apb_vif.pready  = 1'b1;
  assign apb_vif.prdata  = 32'hDEAD_BEEF;
  assign apb_vif.pslverr = 1'b0;

  initial begin
    // Pass virtual interface into config_db BEFORE run_test()
    // null context + wildcard scope = accessible everywhere
    uvm_config_db#(virtual apb_if)::set(
      null,              // null context (top module is not a uvm_component)
      "uvm_test_top.*",  // scope: all components under test top
      "vif",             // field name
      apb_vif            // value
    );

    run_test("apb_base_test");
  end
endmodule
