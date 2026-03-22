// =============================================================================
// Example 08: Complete UVM Testbench
// Covers: full verification environment with interface, DUT, driver, monitor,
//         scoreboard, coverage, agent, env, sequences, and multiple tests
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;


// ─── Simple ALU DUT ───
module alu_dut (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        valid_in,
  input  logic [7:0]  operand_a,
  input  logic [7:0]  operand_b,
  input  logic [1:0]  opcode,
  output logic        valid_out,
  output logic [15:0] result,
  output logic        overflow
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 0;
      result    <= 0;
      overflow  <= 0;
    end else if (valid_in) begin
      valid_out <= 1;
      overflow  <= 0;
      case (opcode)
        2'b00: result <= {8'h0, operand_a} + {8'h0, operand_b};
        2'b01: result <= {8'h0, operand_a} - {8'h0, operand_b};
        2'b10: result <= operand_a * operand_b;
        2'b11: begin
          if (operand_b == 0) begin
            result   <= 16'hFFFF;
            overflow <= 1;
          end else
            result <= {8'h0, operand_a} / {8'h0, operand_b};
        end
      endcase
    end else begin
      valid_out <= 0;
    end
  end
endmodule


// ─── Interface ───
interface alu_if (input logic clk, input logic rst_n);
  logic        valid_in;
  logic [7:0]  operand_a;
  logic [7:0]  operand_b;
  logic [1:0]  opcode;
  logic        valid_out;
  logic [15:0] result;
  logic        overflow;
endinterface


// ─── Transaction ───
class alu_txn extends uvm_sequence_item;
  `uvm_object_utils(alu_txn)

  rand bit [7:0]  a;
  rand bit [7:0]  b;
  rand bit [1:0]  op;
       bit [15:0] result;
       bit        overflow;

  typedef enum bit [1:0] {ADD=0, SUB=1, MUL=2, DIV=3} op_e;

  function new(string name = "alu_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string op_name;
    case (op)
      ADD: op_name = "ADD";
      SUB: op_name = "SUB";
      MUL: op_name = "MUL";
      DIV: op_name = "DIV";
    endcase
    return $sformatf("%s a=%0d b=%0d result=%0d overflow=%0b",
                     op_name, a, b, result, overflow);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    alu_txn t;
    super.do_copy(rhs);
    $cast(t, rhs);
    a        = t.a;
    b        = t.b;
    op       = t.op;
    result   = t.result;
    overflow = t.overflow;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    alu_txn t;
    bit eq = super.do_compare(rhs, comparer);
    $cast(t, rhs);
    eq &= (a == t.a) && (b == t.b) && (op == t.op);
    eq &= (result == t.result) && (overflow == t.overflow);
    return eq;
  endfunction
endclass


// ─── Sequences ───
class alu_base_seq extends uvm_sequence #(alu_txn);
  `uvm_object_utils(alu_base_seq)
  function new(string name = "alu_base_seq");
    super.new(name);
  endfunction
endclass

class alu_random_seq extends alu_base_seq;
  `uvm_object_utils(alu_random_seq)

  rand int unsigned num_txns;
  constraint c_num { num_txns inside {[10:50]}; }

  function new(string name = "alu_random_seq");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;
    repeat (num_txns) begin
      txn = alu_txn::type_id::create("txn");
      start_item(txn);
      void'(txn.randomize());
      finish_item(txn);
    end
  endtask
endclass

class alu_add_seq extends alu_base_seq;
  `uvm_object_utils(alu_add_seq)

  function new(string name = "alu_add_seq");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;
    repeat (20) begin
      txn = alu_txn::type_id::create("txn");
      start_item(txn);
      void'(txn.randomize() with { op == alu_txn::ADD; });
      finish_item(txn);
    end
  endtask
endclass

class alu_div_zero_seq extends alu_base_seq;
  `uvm_object_utils(alu_div_zero_seq)

  function new(string name = "alu_div_zero_seq");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;

    // Normal divisions
    repeat (5) begin
      txn = alu_txn::type_id::create("txn");
      start_item(txn);
      void'(txn.randomize() with { op == alu_txn::DIV; b > 0; });
      finish_item(txn);
    end

    // Divide by zero
    repeat (3) begin
      txn = alu_txn::type_id::create("txn");
      start_item(txn);
      void'(txn.randomize() with { op == alu_txn::DIV; b == 0; });
      finish_item(txn);
    end
  endtask
endclass

class alu_corner_case_seq extends alu_base_seq;
  `uvm_object_utils(alu_corner_case_seq)

  function new(string name = "alu_corner_case_seq");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;

    bit [7:0] corners[] = '{0, 1, 8'h7F, 8'h80, 8'hFE, 8'hFF};

    foreach (corners[i]) begin
      foreach (corners[j]) begin
        for (int op = 0; op < 4; op++) begin
          txn = alu_txn::type_id::create("txn");
          start_item(txn);
          txn.a  = corners[i];
          txn.b  = corners[j];
          txn.op = op[1:0];
          finish_item(txn);
        end
      end
    end
  endtask
endclass


// ─── Sequencer ───
typedef uvm_sequencer #(alu_txn) alu_sequencer;


// ─── Driver ───
class alu_driver extends uvm_driver #(alu_txn);
  `uvm_component_utils(alu_driver)

  virtual alu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_txn txn;
    vif.valid_in <= 0;

    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);

      @(posedge vif.clk);
      vif.valid_in  <= 1;
      vif.operand_a <= txn.a;
      vif.operand_b <= txn.b;
      vif.opcode    <= txn.op;

      @(posedge vif.clk);
      vif.valid_in <= 0;

      @(posedge vif.clk iff vif.valid_out);
      txn.result   = vif.result;
      txn.overflow = vif.overflow;

      seq_item_port.item_done();
    end
  endtask
endclass


// ─── Monitor ───
class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;
  uvm_analysis_port #(alu_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_txn txn;

    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk iff vif.valid_in);
      txn = alu_txn::type_id::create("mon_txn");
      txn.a  = vif.operand_a;
      txn.b  = vif.operand_b;
      txn.op = vif.opcode;

      @(posedge vif.clk iff vif.valid_out);
      txn.result   = vif.result;
      txn.overflow = vif.overflow;

      `uvm_info("MON", txn.convert2string(), UVM_HIGH)
      ap.write(txn);
    end
  endtask
endclass


// ─── Reference Model (Scoreboard) ───
class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_txn, alu_scoreboard) imp;

  int pass_count;
  int fail_count;
  int total_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    imp = new("imp", this);
  endfunction

  function void write(alu_txn txn);
    bit [15:0] expected_result;
    bit        expected_overflow = 0;

    total_count++;

    case (txn.op)
      2'b00: expected_result = {8'h0, txn.a} + {8'h0, txn.b};
      2'b01: expected_result = {8'h0, txn.a} - {8'h0, txn.b};
      2'b10: expected_result = txn.a * txn.b;
      2'b11: begin
        if (txn.b == 0) begin
          expected_result   = 16'hFFFF;
          expected_overflow = 1;
        end else
          expected_result = {8'h0, txn.a} / {8'h0, txn.b};
      end
    endcase

    if (txn.result === expected_result && txn.overflow === expected_overflow) begin
      pass_count++;
      `uvm_info("SCB", $sformatf("PASS: %s", txn.convert2string()), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SCB", $sformatf(
        "FAIL: %s | expected result=%0d overflow=%0b",
        txn.convert2string(), expected_result, expected_overflow))
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf(
      "\n╔═══════════════════════════╗\n" ,
      "║   Scoreboard Summary      ║\n" ,
      "║   Total:  %4d             ║\n" ,
      "║   Passed: %4d             ║\n" ,
      "║   Failed: %4d             ║\n" ,
      "╚═══════════════════════════╝",
      total_count, pass_count, fail_count), UVM_NONE)

    if (fail_count == 0)
      `uvm_info("SCB", "** ALL CHECKS PASSED **", UVM_NONE)
    else
      `uvm_error("SCB", "** TEST FAILED **")
  endfunction
endclass


// ─── Coverage ───
class alu_coverage extends uvm_subscriber #(alu_txn);
  `uvm_component_utils(alu_coverage)

  alu_txn txn;

  covergroup alu_cg;
    option.per_instance = 1;
    option.name = "alu_coverage";

    op_cp: coverpoint txn.op {
      bins add = {0};
      bins sub = {1};
      bins mul = {2};
      bins div = {3};
    }

    a_cp: coverpoint txn.a {
      bins zero     = {0};
      bins small    = {[1:63]};
      bins mid      = {[64:191]};
      bins large    = {[192:254]};
      bins max      = {255};
    }

    b_cp: coverpoint txn.b {
      bins zero     = {0};
      bins small    = {[1:63]};
      bins mid      = {[64:191]};
      bins large    = {[192:254]};
      bins max      = {255};
    }

    overflow_cp: coverpoint txn.overflow {
      bins no_overflow = {0};
      bins overflow    = {1};
    }

    op_x_overflow: cross op_cp, overflow_cp {
      ignore_bins impossible = binsof(op_cp.add) && binsof(overflow_cp.overflow);
      ignore_bins impossible2 = binsof(op_cp.sub) && binsof(overflow_cp.overflow);
      ignore_bins impossible3 = binsof(op_cp.mul) && binsof(overflow_cp.overflow);
    }

    op_x_a: cross op_cp, a_cp;
    op_x_b: cross op_cp, b_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  virtual function void write(alu_txn t);
    txn = t;
    alu_cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("Functional coverage: %.2f%%", alu_cg.get_coverage()), UVM_LOW)
  endfunction
endclass


// ─── Agent ───
class alu_agent extends uvm_agent;
  `uvm_component_utils(alu_agent)

  alu_driver    drv;
  alu_monitor   mon;
  alu_sequencer sqr;

  uvm_analysis_port #(alu_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = alu_monitor::type_id::create("mon", this);
    ap  = new("ap", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = alu_driver::type_id::create("drv", this);
      sqr = alu_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(ap);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass


// ─── Environment ───
class alu_env extends uvm_env;
  `uvm_component_utils(alu_env)

  alu_agent      agent;
  alu_scoreboard scb;
  alu_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = alu_agent::type_id::create("agent", this);
    scb   = alu_scoreboard::type_id::create("scb", this);
    cov   = alu_coverage::type_id::create("cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.ap.connect(scb.imp);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass


// ─── Base Test ───
class alu_base_test extends uvm_test;
  `uvm_component_utils(alu_base_test)

  alu_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
endclass


// ─── Random Test ───
class alu_random_test extends alu_base_test;
  `uvm_component_utils(alu_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_random_seq seq = alu_random_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.num_txns = 100;
    seq.start(env.agent.sqr);
    #50;
    phase.drop_objection(this);
  endtask
endclass


// ─── Add-Focused Test ───
class alu_add_test extends alu_base_test;
  `uvm_component_utils(alu_add_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_add_seq seq = alu_add_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    #50;
    phase.drop_objection(this);
  endtask
endclass


// ─── Division Edge-Case Test ───
class alu_div_test extends alu_base_test;
  `uvm_component_utils(alu_div_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_div_zero_seq seq = alu_div_zero_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    #50;
    phase.drop_objection(this);
  endtask
endclass


// ─── Corner Case Exhaustive Test ───
class alu_corner_test extends alu_base_test;
  `uvm_component_utils(alu_corner_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_corner_case_seq seq = alu_corner_case_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    #50;
    phase.drop_objection(this);
  endtask
endclass


// ─── Top-Level Testbench ───
module tb_top;
  logic clk, rst_n;

  alu_if aif(.clk(clk), .rst_n(rst_n));

  alu_dut dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (aif.valid_in),
    .operand_a (aif.operand_a),
    .operand_b (aif.operand_b),
    .opcode    (aif.opcode),
    .valid_out (aif.valid_out),
    .result    (aif.result),
    .overflow  (aif.overflow)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #25;
    rst_n = 1;
  end

  initial begin
    uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top.env.agent.*", "vif", aif);
    run_test();  // Use +UVM_TESTNAME=alu_random_test (or alu_add_test, alu_div_test, etc.)
  end
endmodule
