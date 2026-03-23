// =============================================================================
// UVM config_db + Factory Combined Example
// =============================================================================
//
// A realistic SPI master verification environment that demonstrates how
// config_db and the factory work together to build a fully configurable,
// reusable testbench.
//
// Key patterns demonstrated:
//   1. Configuration objects passed via config_db control WHAT is built
//   2. Factory overrides control WHICH implementations are used
//   3. Tests customize both without modifying the reusable environment
//   4. config_db + factory together enable per-test behavioral variation
//
// Hierarchy:
//   tb_top (module)
//     └─ spi_test (uvm_test)
//          └─ spi_env (uvm_env)
//               ├─ master_agent (spi_agent) [active]
//               │    ├─ driver
//               │    ├─ monitor
//               │    └─ sequencer
//               ├─ slave_agent (spi_agent) [passive — optional]
//               │    └─ monitor
//               ├─ scoreboard (optional via config)
//               └─ coverage (optional via config)
//
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// =============================================================================
// SPI Interface
// =============================================================================
interface spi_if(input logic clk, input logic rst_n);
  logic       sclk;
  logic       mosi;
  logic       miso;
  logic       cs_n;

  modport master(output sclk, mosi, cs_n, input miso);
  modport slave(input sclk, mosi, cs_n, output miso);
  modport monitor(input sclk, mosi, miso, cs_n);
endinterface

// =============================================================================
// CONFIGURATION OBJECTS
//
// The config hierarchy mirrors the component hierarchy. Each level retrieves
// its own config and redistributes sub-configs to children.
// =============================================================================

// SPI protocol-level parameters
class spi_protocol_cfg extends uvm_object;
  `uvm_object_utils(spi_protocol_cfg)

  typedef enum {MODE_0, MODE_1, MODE_2, MODE_3} spi_mode_e;

  spi_mode_e   mode       = MODE_0;
  int unsigned  clk_div    = 4;
  bit           msb_first  = 1;
  int unsigned  word_size  = 8;
  int unsigned  max_words  = 16;

  function new(string name = "spi_protocol_cfg");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("mode=%s clk_div=%0d msb_first=%0b word_size=%0d max_words=%0d",
                     mode.name(), clk_div, msb_first, word_size, max_words);
  endfunction
endclass

// Agent-level configuration
class spi_agent_cfg extends uvm_object;
  `uvm_object_utils(spi_agent_cfg)

  uvm_active_passive_enum is_active    = UVM_ACTIVE;
  bit                     has_coverage = 0;
  spi_protocol_cfg        protocol;

  function new(string name = "spi_agent_cfg");
    super.new(name);
    protocol = spi_protocol_cfg::type_id::create("protocol");
  endfunction

  function string convert2string();
    return $sformatf("active=%s has_cov=%0b protocol={%s}",
                     is_active.name(), has_coverage, protocol.convert2string());
  endfunction
endclass

// Environment-level configuration — bundles everything
class spi_env_cfg extends uvm_object;
  `uvm_object_utils(spi_env_cfg)

  spi_agent_cfg master_cfg;
  spi_agent_cfg slave_cfg;
  bit           has_scoreboard = 1;
  bit           has_coverage   = 1;
  bit           has_slave_agent = 0;
  int unsigned  num_transactions = 50;

  function new(string name = "spi_env_cfg");
    super.new(name);
    master_cfg = spi_agent_cfg::type_id::create("master_cfg");
    slave_cfg  = spi_agent_cfg::type_id::create("slave_cfg");
    slave_cfg.is_active = UVM_PASSIVE;
  endfunction
endclass

// =============================================================================
// TRANSACTIONS
// =============================================================================

class spi_txn extends uvm_sequence_item;
  `uvm_object_utils(spi_txn)

  rand bit [7:0] tx_data[];
  rand int unsigned word_count;
  bit [7:0]      rx_data[];
  rand int unsigned cs_to_sclk_delay;
  rand int unsigned inter_word_delay;

  constraint size_c {
    word_count inside {[1:16]};
    tx_data.size() == word_count;
  }

  constraint delay_c {
    cs_to_sclk_delay inside {[1:10]};
    inter_word_delay inside {[0:5]};
  }

  function new(string name = "spi_txn");
    super.new(name);
  endfunction

  function string convert2string();
    string s = $sformatf("[%s] words=%0d delays={cs=%0d, iw=%0d} tx=",
                         get_type_name(), word_count, cs_to_sclk_delay, inter_word_delay);
    foreach (tx_data[i])
      s = {s, $sformatf("%02h ", tx_data[i])};
    return s;
  endfunction
endclass

// Extended transaction for stress testing — tighter constraints
class spi_stress_txn extends spi_txn;
  `uvm_object_utils(spi_stress_txn)

  constraint stress_c {
    word_count == 16;
    cs_to_sclk_delay == 1;
    inter_word_delay == 0;
  }

  function new(string name = "spi_stress_txn");
    super.new(name);
  endfunction
endclass

// Extended transaction for corner cases
class spi_corner_txn extends spi_txn;
  `uvm_object_utils(spi_corner_txn)

  constraint corner_c {
    word_count inside {1, 16};
    tx_data[0] inside {8'h00, 8'hFF, 8'hAA, 8'h55};
  }

  function new(string name = "spi_corner_txn");
    super.new(name);
  endfunction
endclass

// =============================================================================
// DRIVER VARIANTS
// =============================================================================

class spi_driver extends uvm_driver#(spi_txn);
  `uvm_component_utils(spi_driver)

  virtual spi_if vif;
  spi_protocol_cfg protocol_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Retrieve virtual interface (set by top module via config_db)
    if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", {"Virtual interface not found for ", get_full_name()})

    // Retrieve protocol configuration (set by agent via config_db)
    if (!uvm_config_db#(spi_protocol_cfg)::get(this, "", "protocol_cfg", protocol_cfg))
      `uvm_fatal("NO_CFG", {"Protocol config not found for ", get_full_name()})

    `uvm_info("DRV", $sformatf("Protocol: %s", protocol_cfg.convert2string()), UVM_MEDIUM)
  endfunction

  task run_phase(uvm_phase phase);
    vif.cs_n <= 1'b1;
    vif.sclk <= 1'b0;
    vif.mosi <= 1'b0;

    forever begin
      spi_txn txn;
      seq_item_port.get_next_item(txn);
      drive_transfer(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transfer(spi_txn txn);
    `uvm_info("DRV", $sformatf("Driving: %s", txn.convert2string()), UVM_HIGH)

    vif.cs_n <= 1'b0;
    repeat (txn.cs_to_sclk_delay) @(posedge vif.clk);

    foreach (txn.tx_data[i]) begin
      for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
        vif.sclk <= 1'b0;
        vif.mosi <= txn.tx_data[i][bit_idx];
        repeat (protocol_cfg.clk_div / 2) @(posedge vif.clk);
        vif.sclk <= 1'b1;
        repeat (protocol_cfg.clk_div / 2) @(posedge vif.clk);
      end
      repeat (txn.inter_word_delay) @(posedge vif.clk);
    end

    vif.sclk <= 1'b0;
    vif.cs_n <= 1'b1;
    @(posedge vif.clk);
  endtask
endclass

// Pipelined driver — overlaps CS deassertion with next transaction
class spi_pipelined_driver extends spi_driver;
  `uvm_component_utils(spi_pipelined_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task drive_transfer(spi_txn txn);
    `uvm_info("PIPE_DRV", $sformatf("Pipelined-driving: %s", txn.convert2string()), UVM_HIGH)

    vif.cs_n <= 1'b0;

    foreach (txn.tx_data[i]) begin
      for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
        vif.sclk <= 1'b0;
        vif.mosi <= txn.tx_data[i][bit_idx];
        repeat (protocol_cfg.clk_div / 4 + 1) @(posedge vif.clk);
        vif.sclk <= 1'b1;
        repeat (protocol_cfg.clk_div / 4 + 1) @(posedge vif.clk);
      end
    end

    vif.sclk <= 1'b0;
    vif.cs_n <= 1'b1;
  endtask
endclass

// =============================================================================
// MONITOR
// =============================================================================

class spi_monitor extends uvm_monitor;
  `uvm_component_utils(spi_monitor)

  virtual spi_if vif;
  uvm_analysis_port#(spi_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", {"Virtual interface not found for ", get_full_name()})
  endfunction

  task run_phase(uvm_phase phase);
    spi_txn txn;
    forever begin
      @(negedge vif.cs_n);
      txn = spi_txn::type_id::create("mon_txn");
      collect_transaction(txn);
      ap.write(txn);
    end
  endtask

  task collect_transaction(spi_txn txn);
    byte tx_data_q[$];
    byte current_byte;
    int bit_count;

    bit_count = 0;
    current_byte = 0;

    while (vif.cs_n == 1'b0) begin
      @(posedge vif.sclk or posedge vif.cs_n);
      if (vif.cs_n) break;

      current_byte = {current_byte[6:0], vif.mosi};
      bit_count++;

      if (bit_count == 8) begin
        tx_data_q.push_back(current_byte);
        current_byte = 0;
        bit_count = 0;
      end
    end

    txn.word_count = tx_data_q.size();
    txn.tx_data = new[txn.word_count];
    foreach (tx_data_q[i])
      txn.tx_data[i] = tx_data_q[i];

    `uvm_info("MON", $sformatf("Collected: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass

// =============================================================================
// SCOREBOARD
// =============================================================================

class spi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(spi_scoreboard)

  uvm_analysis_imp#(spi_txn, spi_scoreboard) analysis_export;
  int unsigned txn_count;
  int unsigned total_words;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(spi_txn txn);
    txn_count++;
    total_words += txn.word_count;
    `uvm_info("SCB", $sformatf("Txn #%0d: %s", txn_count, txn.convert2string()), UVM_MEDIUM)
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("Total: %0d transactions, %0d words transferred",
              txn_count, total_words), UVM_LOW)
  endfunction
endclass

// =============================================================================
// COVERAGE COLLECTOR
// =============================================================================

class spi_coverage extends uvm_subscriber#(spi_txn);
  `uvm_component_utils(spi_coverage)

  spi_txn txn;

  covergroup spi_cg;
    word_count_cp: coverpoint txn.word_count {
      bins single  = {1};
      bins small   = {[2:4]};
      bins medium  = {[5:8]};
      bins large   = {[9:16]};
    }
    first_byte_cp: coverpoint txn.tx_data[0] {
      bins zeros = {8'h00};
      bins ones  = {8'hFF};
      bins other = default;
    }
    cs_delay_cp: coverpoint txn.cs_to_sclk_delay {
      bins min_delay = {1};
      bins mid_delay = {[2:5]};
      bins max_delay = {[6:10]};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    spi_cg = new();
  endfunction

  function void write(spi_txn t);
    txn = t;
    spi_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Coverage: %.1f%%", spi_cg.get_coverage()), UVM_LOW)
  endfunction
endclass

// =============================================================================
// AGENT
//
// Retrieves its spi_agent_cfg from config_db. Uses the cfg to:
//   - Decide whether to build driver + sequencer (active vs passive)
//   - Redistribute protocol_cfg to driver and monitor
// =============================================================================

class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)

  spi_driver                  driver;
  spi_monitor                 monitor;
  uvm_sequencer#(spi_txn)    sequencer;

  spi_agent_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // config_db: retrieve agent configuration
    if (!uvm_config_db#(spi_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", {"Agent config not found for ", get_full_name()})

    `uvm_info("AGENT", $sformatf("Config: %s", cfg.convert2string()), UVM_MEDIUM)

    // config_db: redistribute protocol config to children
    uvm_config_db#(spi_protocol_cfg)::set(this, "*", "protocol_cfg", cfg.protocol);

    monitor = spi_monitor::type_id::create("monitor", this);

    if (cfg.is_active == UVM_ACTIVE) begin
      // factory: driver and sequencer created through factory
      driver    = spi_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(spi_txn)::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

// =============================================================================
// ENVIRONMENT
//
// Retrieves spi_env_cfg from config_db. Uses it to:
//   - Decide which components to build (scoreboard, coverage, slave agent)
//   - Redistribute sub-configs to agents
//
// All component creation uses factory (type_id::create), so tests can
// override any component type.
// =============================================================================

class spi_env extends uvm_env;
  `uvm_component_utils(spi_env)

  spi_agent      master_agent;
  spi_agent      slave_agent;
  spi_scoreboard scoreboard;
  spi_coverage   coverage;

  spi_env_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // config_db: retrieve environment configuration
    if (!uvm_config_db#(spi_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NO_CFG", {"Env config not found for ", get_full_name()})

    // config_db: redistribute agent configs
    uvm_config_db#(spi_agent_cfg)::set(this, "master_agent", "cfg", cfg.master_cfg);

    // factory: build master agent
    master_agent = spi_agent::type_id::create("master_agent", this);

    // Conditionally build slave agent based on config
    if (cfg.has_slave_agent) begin
      uvm_config_db#(spi_agent_cfg)::set(this, "slave_agent", "cfg", cfg.slave_cfg);
      slave_agent = spi_agent::type_id::create("slave_agent", this);
    end

    // Conditionally build scoreboard and coverage based on config
    if (cfg.has_scoreboard)
      scoreboard = spi_scoreboard::type_id::create("scoreboard", this);

    if (cfg.has_coverage)
      coverage = spi_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    if (cfg.has_scoreboard)
      master_agent.monitor.ap.connect(scoreboard.analysis_export);
    if (cfg.has_coverage)
      master_agent.monitor.ap.connect(coverage.analysis_export);
  endfunction
endclass

// =============================================================================
// SEQUENCES
// =============================================================================

class spi_base_seq extends uvm_sequence#(spi_txn);
  `uvm_object_utils(spi_base_seq)

  int unsigned num_txns = 10;

  function new(string name = "spi_base_seq");
    super.new(name);
  endfunction

  task body();
    spi_txn txn;

    // config_db: sequences can also read config values
    void'(uvm_config_db#(int unsigned)::get(
      null, get_sequencer().get_full_name(), "num_transactions", num_txns));

    `uvm_info("SEQ", $sformatf("[%s] Running %0d transactions", get_type_name(), num_txns), UVM_LOW)

    repeat (num_txns) begin
      // factory: transactions created through factory, so overrides apply
      txn = spi_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_error("RAND", "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass

class spi_stress_seq extends spi_base_seq;
  `uvm_object_utils(spi_stress_seq)

  function new(string name = "spi_stress_seq");
    super.new(name);
  endfunction

  task body();
    spi_txn txn;

    void'(uvm_config_db#(int unsigned)::get(
      null, get_sequencer().get_full_name(), "num_transactions", num_txns));

    `uvm_info("STRESS_SEQ", $sformatf("Stress: %0d back-to-back transactions", num_txns), UVM_LOW)

    repeat (num_txns) begin
      txn = spi_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with {
        word_count == 16;
        cs_to_sclk_delay == 1;
        inter_word_delay == 0;
      })
        `uvm_error("RAND", "Stress randomization failed")
      finish_item(txn);
    end
  endtask
endclass

// =============================================================================
// TESTS
//
// Each test configures the testbench differently using ONLY config_db and
// factory — the environment, agent, driver, and sequence code is untouched.
// =============================================================================

// ---------------------
// Test 1: Basic functional test — default config, default types
// ---------------------
class spi_basic_test extends uvm_test;
  `uvm_component_utils(spi_basic_test)

  spi_env     env;
  spi_env_cfg env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // config_db: create and set environment configuration
    env_cfg = spi_env_cfg::type_id::create("env_cfg");
    env_cfg.num_transactions = 10;
    env_cfg.master_cfg.is_active = UVM_ACTIVE;
    env_cfg.master_cfg.protocol.clk_div = 4;
    env_cfg.master_cfg.protocol.word_size = 8;
    env_cfg.has_scoreboard = 1;
    env_cfg.has_coverage = 1;

    uvm_config_db#(spi_env_cfg)::set(this, "env", "cfg", env_cfg);
    uvm_config_db#(int unsigned)::set(this, "env.master_agent.sequencer",
                                      "num_transactions", env_cfg.num_transactions);

    env = spi_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    spi_base_seq seq;
    phase.raise_objection(this);
    seq = spi_base_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info("TEST", "--- SPI Basic Test Topology ---", UVM_LOW)
    uvm_top.print_topology();
  endfunction
endclass

// ---------------------
// Test 2: Stress test — factory overrides transaction + driver + sequence
// ---------------------
class spi_stress_test extends uvm_test;
  `uvm_component_utils(spi_stress_test)

  spi_env     env;
  spi_env_cfg env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // factory: swap in pipelined driver for maximum throughput
    spi_driver::type_id::set_type_override(spi_pipelined_driver::get_type());

    // factory: swap in stress transaction (max words, no delays)
    spi_txn::type_id::set_type_override(spi_stress_txn::get_type());

    super.build_phase(phase);

    // config_db: high transaction count, fast clock
    env_cfg = spi_env_cfg::type_id::create("env_cfg");
    env_cfg.num_transactions = 500;
    env_cfg.master_cfg.protocol.clk_div = 2;
    env_cfg.has_scoreboard = 1;
    env_cfg.has_coverage = 0;

    uvm_config_db#(spi_env_cfg)::set(this, "env", "cfg", env_cfg);
    uvm_config_db#(int unsigned)::set(this, "env.master_agent.sequencer",
                                      "num_transactions", env_cfg.num_transactions);

    env = spi_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    spi_base_seq seq;
    phase.raise_objection(this);

    // factory: create returns spi_stress_seq if we had overridden it,
    // but here the stress txn override already makes the base sequence
    // produce stress packets
    seq = spi_base_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);

    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Stress Test Factory State ===", UVM_LOW)
    factory.print();
  endfunction
endclass

// ---------------------
// Test 3: Corner case test — uses factory for corner transactions,
// config_db to enable all checking and coverage
// ---------------------
class spi_corner_test extends uvm_test;
  `uvm_component_utils(spi_corner_test)

  spi_env     env;
  spi_env_cfg env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // factory: use corner-case transactions
    spi_txn::type_id::set_type_override(spi_corner_txn::get_type());

    super.build_phase(phase);

    // config_db: enable everything for thorough checking
    env_cfg = spi_env_cfg::type_id::create("env_cfg");
    env_cfg.num_transactions = 100;
    env_cfg.has_scoreboard = 1;
    env_cfg.has_coverage = 1;
    env_cfg.has_slave_agent = 0;
    env_cfg.master_cfg.protocol.clk_div = 8;

    uvm_config_db#(spi_env_cfg)::set(this, "env", "cfg", env_cfg);
    uvm_config_db#(int unsigned)::set(this, "env.master_agent.sequencer",
                                      "num_transactions", env_cfg.num_transactions);

    env = spi_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    spi_base_seq seq;
    phase.raise_objection(this);
    seq = spi_base_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Corner Test Factory State ===", UVM_LOW)
    factory.print();
  endfunction
endclass

// ---------------------
// Test 4: Protocol mode sweep — different SPI modes via config_db,
// same environment code
// ---------------------
class spi_mode_sweep_test extends uvm_test;
  `uvm_component_utils(spi_mode_sweep_test)

  spi_env     env;
  spi_env_cfg env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env_cfg = spi_env_cfg::type_id::create("env_cfg");
    env_cfg.num_transactions = 20;
    env_cfg.has_scoreboard = 1;
    env_cfg.has_coverage = 1;

    // config_db: configure SPI Mode 3 (CPOL=1, CPHA=1)
    env_cfg.master_cfg.protocol.mode = spi_protocol_cfg::MODE_3;
    env_cfg.master_cfg.protocol.clk_div = 6;
    env_cfg.master_cfg.protocol.msb_first = 0;

    uvm_config_db#(spi_env_cfg)::set(this, "env", "cfg", env_cfg);
    uvm_config_db#(int unsigned)::set(this, "env.master_agent.sequencer",
                                      "num_transactions", env_cfg.num_transactions);

    env = spi_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    spi_base_seq seq;
    phase.raise_objection(this);
    seq = spi_base_seq::type_id::create("seq");
    seq.start(env.master_agent.sequencer);
    phase.drop_objection(this);
  endtask
endclass

// =============================================================================
// TOP-LEVEL MODULE
//
// Instantiates the DUT interface and passes it into config_db.
// config_db bridges the static module world and the dynamic class world.
// =============================================================================
module tb_top;
  logic clk, rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #50;
    rst_n = 1;
  end

  spi_if spi_vif(clk, rst_n);

  assign spi_vif.miso = spi_vif.mosi;

  initial begin
    // config_db: pass virtual interface to all components
    uvm_config_db#(virtual spi_if)::set(null, "uvm_test_top.*", "vif", spi_vif);

    // Select test via +UVM_TESTNAME:
    //   +UVM_TESTNAME=spi_basic_test
    //   +UVM_TESTNAME=spi_stress_test
    //   +UVM_TESTNAME=spi_corner_test
    //   +UVM_TESTNAME=spi_mode_sweep_test
    run_test();
  end
endmodule
