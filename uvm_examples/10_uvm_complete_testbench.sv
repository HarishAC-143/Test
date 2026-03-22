// =============================================================================
// Example 10: Complete UVM Testbench — APB Slave Verification
// Demonstrates: full UVM testbench architecture with interface, DUT, agent
//               (driver + sequencer + monitor), scoreboard, coverage,
//               configuration, sequences, tests, and top module.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// ===================================================================
// INTERFACE
// ===================================================================
interface apb_if(input logic pclk, input logic preset_n);
  logic        psel;
  logic        penable;
  logic [7:0]  paddr;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  modport master (output psel, penable, paddr, pwrite, pwdata,
                  input  prdata, pready, pslverr, pclk, preset_n);
  modport slave  (input  psel, penable, paddr, pwrite, pwdata,
                  output prdata, pready, pslverr, pclk, preset_n);
  modport monitor(input  psel, penable, paddr, pwrite, pwdata,
                  prdata, pready, pslverr, pclk, preset_n);
endinterface

// ===================================================================
// SIMPLE DUT — APB register file with 64 registers
// ===================================================================
module apb_register_file(apb_if.slave apb);
  logic [31:0] registers [64];

  initial foreach (registers[i]) registers[i] = 32'h0;

  always_ff @(posedge apb.pclk or negedge apb.preset_n) begin
    if (!apb.preset_n) begin
      apb.prdata  <= 32'h0;
      apb.pready  <= 1'b0;
      apb.pslverr <= 1'b0;
    end else begin
      apb.pready  <= 1'b0;
      apb.pslverr <= 1'b0;

      if (apb.psel && apb.penable) begin
        apb.pready <= 1'b1;
        if (apb.paddr[7:2] < 64) begin
          if (apb.pwrite)
            registers[apb.paddr[7:2]] <= apb.pwdata;
          else
            apb.prdata <= registers[apb.paddr[7:2]];
          apb.pslverr <= 1'b0;
        end else begin
          apb.pslverr <= 1'b1;
        end
      end
    end
  end
endmodule

// ===================================================================
// TRANSACTION
// ===================================================================
class apb_txn extends uvm_sequence_item;
  `uvm_object_utils(apb_txn)

  rand bit [7:0]  addr;
  rand bit [31:0] data;
  rand bit        write;
       bit        slverr;
       bit [31:0] rdata;

  constraint c_word_aligned { addr[1:0] == 2'b00; }
  constraint c_valid_addr   { addr[7:2] < 64; }

  function new(string name = "apb_txn");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    apb_txn rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs)) `uvm_fatal("CAST", "copy cast failed")
    this.addr   = rhs_.addr;
    this.data   = rhs_.data;
    this.write  = rhs_.write;
    this.slverr = rhs_.slverr;
    this.rdata  = rhs_.rdata;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    apb_txn rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (this.addr   == rhs_.addr)   &&
           (this.data   == rhs_.data)   &&
           (this.write  == rhs_.write)  &&
           (this.slverr == rhs_.slverr) &&
           (this.rdata  == rhs_.rdata);
  endfunction

  virtual function string convert2string();
    if (write)
      return $sformatf("APB WR addr=0x%02h wdata=0x%08h err=%0b", addr, data, slverr);
    else
      return $sformatf("APB RD addr=0x%02h rdata=0x%08h err=%0b", addr, rdata, slverr);
  endfunction
endclass

// ===================================================================
// CONFIGURATION
// ===================================================================
class apb_agent_config extends uvm_object;
  `uvm_object_utils(apb_agent_config)

  virtual apb_if            vif;
  uvm_active_passive_enum   is_active;
  bit                       has_coverage;

  function new(string name = "apb_agent_config");
    super.new(name);
    is_active    = UVM_ACTIVE;
    has_coverage = 1;
  endfunction
endclass

// ===================================================================
// DRIVER
// ===================================================================
class apb_driver extends uvm_driver #(apb_txn);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_txn txn;

    // Initialize bus
    vif.psel    <= 0;
    vif.penable <= 0;
    vif.paddr   <= 0;
    vif.pwrite  <= 0;
    vif.pwdata  <= 0;

    // Wait for reset
    @(posedge vif.preset_n);
    @(posedge vif.pclk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_txn(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_txn(apb_txn txn);
    // Setup phase
    @(posedge vif.pclk);
    vif.psel   <= 1'b1;
    vif.paddr  <= txn.addr;
    vif.pwrite <= txn.write;
    if (txn.write)
      vif.pwdata <= txn.data;

    // Access phase
    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    // Wait for ready
    @(posedge vif.pclk);
    while (!vif.pready) @(posedge vif.pclk);

    // Capture response
    if (!txn.write)
      txn.rdata = vif.prdata;
    txn.slverr = vif.pslverr;

    // Deassert
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass

// ===================================================================
// MONITOR
// ===================================================================
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    @(posedge vif.preset_n);

    forever begin
      apb_txn txn;
      collect_txn(txn);
      ap.write(txn);
    end
  endtask

  virtual task collect_txn(output apb_txn txn);
    txn = apb_txn::type_id::create("mon_txn");

    // Wait for setup phase (psel=1, penable=0)
    @(posedge vif.pclk);
    while (!(vif.psel && !vif.penable)) @(posedge vif.pclk);

    txn.addr  = vif.paddr;
    txn.write = vif.pwrite;
    if (txn.write)
      txn.data = vif.pwdata;

    // Wait for access phase completion
    @(posedge vif.pclk);
    while (!vif.pready) @(posedge vif.pclk);

    if (!txn.write)
      txn.rdata = vif.prdata;
    txn.slverr = vif.pslverr;

    `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass

// ===================================================================
// SEQUENCER
// ===================================================================
class apb_sequencer extends uvm_sequencer #(apb_txn);
  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// ===================================================================
// COVERAGE
// ===================================================================
class apb_coverage extends uvm_subscriber #(apb_txn);
  `uvm_component_utils(apb_coverage)

  apb_txn txn;

  covergroup apb_cg;
    addr_cp: coverpoint txn.addr[7:2] {
      bins low_regs  = {[0:15]};
      bins mid_regs  = {[16:47]};
      bins high_regs = {[48:63]};
    }
    write_cp: coverpoint txn.write;
    error_cp: coverpoint txn.slverr;
    addr_x_write: cross addr_cp, write_cp;
  endcovergroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  virtual function void write(apb_txn t);
    txn = t;
    apb_cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("APB Coverage: %.1f%%", apb_cg.get_coverage()), UVM_LOW)
  endfunction
endclass

// ===================================================================
// AGENT
// ===================================================================
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_sequencer sqr;
  apb_monitor   mon;
  apb_coverage  cov;

  apb_agent_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(apb_agent_config)::get(this, "", "cfg", cfg))
      `uvm_info("CFG", "No agent config — using defaults", UVM_MEDIUM)

    mon = apb_monitor::type_id::create("mon", this);

    if (cfg != null && cfg.has_coverage)
      cov = apb_coverage::type_id::create("cov", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cov != null)
      mon.ap.connect(cov.analysis_export);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// ===================================================================
// SCOREBOARD (with reference model)
// ===================================================================
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_txn, apb_scoreboard) ap_imp;

  bit [31:0]   ref_mem [256];
  int unsigned wr_count;
  int unsigned rd_count;
  int unsigned rd_match;
  int unsigned rd_mismatch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wr_count     = 0;
    rd_count     = 0;
    rd_match     = 0;
    rd_mismatch  = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
    foreach (ref_mem[i]) ref_mem[i] = 32'h0;
  endfunction

  virtual function void write(apb_txn txn);
    if (txn.write) begin
      ref_mem[txn.addr] = txn.data;
      wr_count++;
      `uvm_info("SCB", $sformatf("Write: addr=0x%02h data=0x%08h", txn.addr, txn.data), UVM_HIGH)
    end else begin
      rd_count++;
      if (txn.rdata === ref_mem[txn.addr]) begin
        rd_match++;
        `uvm_info("SCB", $sformatf("Read MATCH: addr=0x%02h data=0x%08h",
                  txn.addr, txn.rdata), UVM_HIGH)
      end else begin
        rd_mismatch++;
        `uvm_error("SCB", $sformatf("Read MISMATCH: addr=0x%02h expected=0x%08h actual=0x%08h",
                   txn.addr, ref_mem[txn.addr], txn.rdata))
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf(
      "\n========== Scoreboard Summary ==========\n" +
      "  Writes:         %0d\n" +
      "  Reads:          %0d\n" +
      "  Read matches:   %0d\n" +
      "  Read mismatches:%0d\n" +
      "=========================================",
      wr_count, rd_count, rd_match, rd_mismatch), UVM_LOW)

    if (rd_mismatch > 0)
      `uvm_error("SCB", "TEST FAILED — read mismatches detected")
    else
      `uvm_info("SCB", "TEST PASSED — all reads matched", UVM_LOW)
  endfunction
endclass

// ===================================================================
// ENVIRONMENT
// ===================================================================
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent", this);
    scb   = apb_scoreboard::type_id::create("scb", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scb.ap_imp);
  endfunction
endclass

// ===================================================================
// SEQUENCES
// ===================================================================

// Single write
class apb_single_write_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_single_write_seq)

  bit [7:0]  target_addr;
  bit [31:0] target_data;

  function new(string name = "apb_single_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_txn txn = apb_txn::type_id::create("txn");
    start_item(txn);
    txn.addr  = target_addr;
    txn.data  = target_data;
    txn.write = 1;
    finish_item(txn);
  endtask
endclass

// Single read
class apb_single_read_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_single_read_seq)

  bit [7:0]  target_addr;
  bit [31:0] read_data;

  function new(string name = "apb_single_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_txn txn = apb_txn::type_id::create("txn");
    start_item(txn);
    txn.addr  = target_addr;
    txn.write = 0;
    finish_item(txn);
    read_data = txn.rdata;
  endtask
endclass

// Write-then-read-back verification
class apb_write_read_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_write_read_seq)

  rand bit [7:0]  addr;
  rand bit [31:0] data;

  constraint c_aligned { addr[1:0] == 2'b00; }
  constraint c_valid   { addr[7:2] < 64; }

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_single_write_seq wr_seq;
    apb_single_read_seq  rd_seq;

    wr_seq = apb_single_write_seq::type_id::create("wr_seq");
    wr_seq.target_addr = addr;
    wr_seq.target_data = data;
    wr_seq.start(m_sequencer, this);

    rd_seq = apb_single_read_seq::type_id::create("rd_seq");
    rd_seq.target_addr = addr;
    rd_seq.start(m_sequencer, this);

    if (rd_seq.read_data !== data)
      `uvm_error("SEQ", $sformatf("Readback mismatch at 0x%02h: wrote 0x%08h read 0x%08h",
                 addr, data, rd_seq.read_data))
    else
      `uvm_info("SEQ", $sformatf("Readback OK at 0x%02h: 0x%08h", addr, data), UVM_MEDIUM)
  endtask
endclass

// Walking ones test
class apb_walking_ones_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_walking_ones_seq)

  function new(string name = "apb_walking_ones_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_read_seq wr_rd;

    `uvm_info("SEQ", "=== Walking Ones Test ===", UVM_LOW)
    for (int i = 0; i < 32; i++) begin
      wr_rd = apb_write_read_seq::type_id::create($sformatf("walk_%0d", i));
      wr_rd.addr = 8'h00;
      wr_rd.data = (32'h1 << i);
      wr_rd.start(m_sequencer, this);
    end
  endtask
endclass

// Random stress test
class apb_random_stress_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_random_stress_seq)

  rand int unsigned num_txns;

  constraint c_txns { num_txns inside {[20:100]}; }

  function new(string name = "apb_random_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_txn txn;

    `uvm_info("SEQ", $sformatf("=== Random Stress: %0d transactions ===", num_txns), UVM_LOW)
    repeat (num_txns) begin
      txn = apb_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass

// ===================================================================
// TESTS
// ===================================================================

// Base test
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env          env;
  apb_agent_config agent_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent_cfg = apb_agent_config::type_id::create("agent_cfg");
    agent_cfg.is_active    = UVM_ACTIVE;
    agent_cfg.has_coverage = 1;

    uvm_config_db #(apb_agent_config)::set(this, "env.agent", "cfg", agent_cfg);

    env = apb_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info("TEST", "\n=== Testbench Topology ===", UVM_LOW)
    uvm_top.print_topology();
  endfunction
endclass

// Write-read verification test
class apb_wr_rd_test extends apb_base_test;
  `uvm_component_utils(apb_wr_rd_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_read_seq seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== Write-Read Verification Test ===", UVM_LOW)
    repeat (20) begin
      seq = apb_write_read_seq::type_id::create("seq");
      if (!seq.randomize())
        `uvm_fatal("RAND", "Sequence randomization failed")
      seq.start(env.agent.sqr);
    end

    phase.drop_objection(this);
  endtask
endclass

// Walking ones test
class apb_walking_ones_test extends apb_base_test;
  `uvm_component_utils(apb_walking_ones_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_walking_ones_seq seq;

    phase.raise_objection(this);
    seq = apb_walking_ones_seq::type_id::create("seq");
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
  endtask
endclass

// Random stress test
class apb_stress_test extends apb_base_test;
  `uvm_component_utils(apb_stress_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_read_seq    wr_rd_seq;
    apb_random_stress_seq stress_seq;

    phase.raise_objection(this);

    // Phase 1: Initialize some registers
    `uvm_info("TEST", "=== Phase 1: Initialize ===", UVM_LOW)
    repeat (10) begin
      wr_rd_seq = apb_write_read_seq::type_id::create("wr_rd_seq");
      void'(wr_rd_seq.randomize());
      wr_rd_seq.start(env.agent.sqr);
    end

    // Phase 2: Random stress
    `uvm_info("TEST", "=== Phase 2: Random Stress ===", UVM_LOW)
    stress_seq = apb_random_stress_seq::type_id::create("stress_seq");
    void'(stress_seq.randomize() with { num_txns == 50; });
    stress_seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass

// ===================================================================
// TOP MODULE
// ===================================================================
// Run with: +UVM_TESTNAME=apb_wr_rd_test
//       or: +UVM_TESTNAME=apb_walking_ones_test
//       or: +UVM_TESTNAME=apb_stress_test
module tb_top;
  logic pclk, preset_n;

  // Clock: 100 MHz
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // Reset
  initial begin
    preset_n = 0;
    #50;
    preset_n = 1;
  end

  // Interface
  apb_if apb_vif(.pclk(pclk), .preset_n(preset_n));

  // DUT
  apb_register_file dut(.apb(apb_vif));

  // UVM launch
  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "vif", apb_vif);
    run_test();
  end

  // Timeout
  initial begin
    #1_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end
endmodule
