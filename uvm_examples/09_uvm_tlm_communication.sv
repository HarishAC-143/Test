// =============================================================================
// Example 09: UVM TLM Communication
// Demonstrates: analysis ports, analysis FIFOs, analysis implementations,
//               uvm_subscriber, multiple port connections, scoreboard patterns.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Transaction ---
class alu_txn extends uvm_sequence_item;
  `uvm_object_utils(alu_txn)

  typedef enum bit [2:0] {
    ADD = 3'b000,
    SUB = 3'b001,
    AND = 3'b010,
    OR  = 3'b011,
    XOR = 3'b100,
    SLL = 3'b101,
    SRL = 3'b110,
    MUL = 3'b111
  } alu_op_e;

  rand alu_op_e    op;
  rand bit [15:0]  operand_a;
  rand bit [15:0]  operand_b;
       bit [31:0]  result;
       bit         overflow;

  function new(string name = "alu_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("ALU %s: A=0x%04h B=0x%04h => result=0x%08h ovf=%0b",
                     op.name(), operand_a, operand_b, result, overflow);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    alu_txn rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs)) `uvm_fatal("CAST", "do_copy cast failed")
    this.op        = rhs_.op;
    this.operand_a = rhs_.operand_a;
    this.operand_b = rhs_.operand_b;
    this.result    = rhs_.result;
    this.overflow  = rhs_.overflow;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    alu_txn rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (this.op        == rhs_.op)        &&
           (this.operand_a == rhs_.operand_a) &&
           (this.operand_b == rhs_.operand_b) &&
           (this.result    == rhs_.result)     &&
           (this.overflow  == rhs_.overflow);
  endfunction
endclass

// --- Reference model (producer of expected transactions) ---
class alu_ref_model extends uvm_component;
  `uvm_component_utils(alu_ref_model)

  uvm_analysis_imp  #(alu_txn, alu_ref_model) analysis_export;
  uvm_analysis_port #(alu_txn)                ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    ap              = new("ap", this);
  endfunction

  virtual function void write(alu_txn txn);
    alu_txn expected;
    expected = alu_txn::type_id::create("expected");
    expected.copy(txn);

    case (txn.op)
      alu_txn::ADD: begin
        {expected.overflow, expected.result} = {1'b0, 16'b0, txn.operand_a} +
                                               {1'b0, 16'b0, txn.operand_b};
      end
      alu_txn::SUB: begin
        expected.result   = {16'b0, txn.operand_a} - {16'b0, txn.operand_b};
        expected.overflow = (txn.operand_b > txn.operand_a);
      end
      alu_txn::AND: begin
        expected.result   = {16'b0, txn.operand_a & txn.operand_b};
        expected.overflow = 0;
      end
      alu_txn::OR: begin
        expected.result   = {16'b0, txn.operand_a | txn.operand_b};
        expected.overflow = 0;
      end
      alu_txn::XOR: begin
        expected.result   = {16'b0, txn.operand_a ^ txn.operand_b};
        expected.overflow = 0;
      end
      alu_txn::SLL: begin
        expected.result   = txn.operand_a << txn.operand_b[3:0];
        expected.overflow = 0;
      end
      alu_txn::SRL: begin
        expected.result   = {16'b0, txn.operand_a} >> txn.operand_b[3:0];
        expected.overflow = 0;
      end
      alu_txn::MUL: begin
        expected.result   = txn.operand_a * txn.operand_b;
        expected.overflow = 0;
      end
    endcase

    `uvm_info("REF", $sformatf("Expected: %s", expected.convert2string()), UVM_HIGH)
    ap.write(expected);
  endfunction
endclass

// --- Coverage collector using uvm_subscriber ---
class alu_coverage extends uvm_subscriber #(alu_txn);
  `uvm_component_utils(alu_coverage)

  alu_txn sampled_txn;

  covergroup alu_cg;
    op_cp: coverpoint sampled_txn.op {
      bins add = {alu_txn::ADD};
      bins sub = {alu_txn::SUB};
      bins and_op = {alu_txn::AND};
      bins or_op  = {alu_txn::OR};
      bins xor_op = {alu_txn::XOR};
      bins sll = {alu_txn::SLL};
      bins srl = {alu_txn::SRL};
      bins mul = {alu_txn::MUL};
    }

    operand_a_cp: coverpoint sampled_txn.operand_a {
      bins zero      = {0};
      bins low       = {[1:255]};
      bins mid       = {[256:65534]};
      bins max_val   = {16'hFFFF};
    }

    operand_b_cp: coverpoint sampled_txn.operand_b {
      bins zero      = {0};
      bins low       = {[1:255]};
      bins mid       = {[256:65534]};
      bins max_val   = {16'hFFFF};
    }

    overflow_cp: coverpoint sampled_txn.overflow;

    op_x_overflow: cross op_cp, overflow_cp;
  endcovergroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  virtual function void write(alu_txn t);
    sampled_txn = t;
    alu_cg.sample();
    `uvm_info("COV", $sformatf("Sampled: %s", t.convert2string()), UVM_HIGH)
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("Functional coverage: %.1f%%", alu_cg.get_coverage()), UVM_LOW)
  endfunction
endclass

// --- Scoreboard using analysis FIFOs ---
class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_tlm_analysis_fifo #(alu_txn) expected_fifo;
  uvm_tlm_analysis_fifo #(alu_txn) actual_fifo;

  int unsigned match_count;
  int unsigned mismatch_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    match_count    = 0;
    mismatch_count = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_txn expected_txn, actual_txn;

    forever begin
      expected_fifo.get(expected_txn);
      actual_fifo.get(actual_txn);

      if (expected_txn.compare(actual_txn)) begin
        match_count++;
        `uvm_info("SCB", $sformatf("MATCH #%0d: %s", match_count,
                  actual_txn.convert2string()), UVM_HIGH)
      end else begin
        mismatch_count++;
        `uvm_error("SCB", $sformatf(
          "MISMATCH #%0d:\n  Expected: %s\n  Actual:   %s",
          mismatch_count,
          expected_txn.convert2string(),
          actual_txn.convert2string()))
      end
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf(
      "\n========== Scoreboard Results ==========\n  Matches:    %0d\n  Mismatches: %0d\n=========================================",
      match_count, mismatch_count), UVM_LOW)

    if (mismatch_count > 0)
      `uvm_error("SCB", "TEST FAILED")
    else
      `uvm_info("SCB", "TEST PASSED", UVM_LOW)
  endfunction
endclass

// --- Simple stimulus generator (simulates a monitor broadcasting transactions) ---
class alu_stimulus_gen extends uvm_component;
  `uvm_component_utils(alu_stimulus_gen)

  uvm_analysis_port #(alu_txn) ap;
  int unsigned num_txns;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txns = 50;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_txn txn;

    phase.raise_objection(this);

    repeat (num_txns) begin
      txn = alu_txn::type_id::create("txn");
      if (!txn.randomize())
        `uvm_fatal("RAND", "Randomization failed")

      // Compute result (simulating DUT behavior)
      case (txn.op)
        alu_txn::ADD: {txn.overflow, txn.result} = {1'b0, 16'b0, txn.operand_a} +
                                                    {1'b0, 16'b0, txn.operand_b};
        alu_txn::SUB: begin
          txn.result   = {16'b0, txn.operand_a} - {16'b0, txn.operand_b};
          txn.overflow = (txn.operand_b > txn.operand_a);
        end
        alu_txn::AND: begin txn.result = {16'b0, txn.operand_a & txn.operand_b}; txn.overflow = 0; end
        alu_txn::OR:  begin txn.result = {16'b0, txn.operand_a | txn.operand_b}; txn.overflow = 0; end
        alu_txn::XOR: begin txn.result = {16'b0, txn.operand_a ^ txn.operand_b}; txn.overflow = 0; end
        alu_txn::SLL: begin txn.result = txn.operand_a << txn.operand_b[3:0]; txn.overflow = 0; end
        alu_txn::SRL: begin txn.result = {16'b0, txn.operand_a} >> txn.operand_b[3:0]; txn.overflow = 0; end
        alu_txn::MUL: begin txn.result = txn.operand_a * txn.operand_b; txn.overflow = 0; end
      endcase

      ap.write(txn);
      #10;
    end

    phase.drop_objection(this);
  endtask
endclass

// --- Environment wiring all TLM connections ---
class tlm_env extends uvm_env;
  `uvm_component_utils(tlm_env)

  alu_stimulus_gen stim;
  alu_ref_model    ref_model;
  alu_scoreboard   scb;
  alu_coverage     cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    stim      = alu_stimulus_gen::type_id::create("stim", this);
    ref_model = alu_ref_model::type_id::create("ref_model", this);
    scb       = alu_scoreboard::type_id::create("scb", this);
    cov       = alu_coverage::type_id::create("cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    //  stim.ap ──┬──> ref_model.analysis_export ──> ref_model.ap ──> scb.expected_fifo
    //            ├──> scb.actual_fifo (simulates monitor output)
    //            └──> cov (coverage subscriber)

    stim.ap.connect(ref_model.analysis_export);
    stim.ap.connect(scb.actual_fifo.analysis_export);
    stim.ap.connect(cov.analysis_export);
    ref_model.ap.connect(scb.expected_fifo.analysis_export);
  endfunction
endclass

// --- Test ---
class tlm_demo_test extends uvm_test;
  `uvm_component_utils(tlm_demo_test)

  tlm_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = tlm_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
endclass

// --- Top module ---
module tb_tlm;
  initial begin
    run_test("tlm_demo_test");
  end
endmodule
