// ALU Scoreboard — compares DUT results against a reference model
class alu_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_txn, alu_scoreboard) analysis_export;

  int pass_count;
  int fail_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    pass_count = 0;
    fail_count = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // Reference model: compute expected result
  function bit [8:0] compute_expected(alu_txn txn);
    case (txn.operation)
      2'b00: return {1'b0, txn.operand_a} + {1'b0, txn.operand_b};  // ADD
      2'b01: return {1'b0, txn.operand_a} - {1'b0, txn.operand_b};  // SUB
      2'b10: return {1'b0, txn.operand_a & txn.operand_b};           // AND
      2'b11: return {1'b0, txn.operand_a | txn.operand_b};           // OR
    endcase
  endfunction

  // Called automatically when monitor broadcasts a transaction
  virtual function void write(alu_txn txn);
    bit [8:0] expected = compute_expected(txn);

    if (expected === txn.result) begin
      pass_count++;
      `uvm_info("SB", $sformatf("PASS: %0d %s %0d = %0d (expected %0d)",
                txn.operand_a, txn.op_name(), txn.operand_b,
                txn.result, expected), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SB", $sformatf("FAIL: %0d %s %0d = %0d (expected %0d)",
                 txn.operand_a, txn.op_name(), txn.operand_b,
                 txn.result, expected))
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", "============================================", UVM_NONE)
    `uvm_info("SB", $sformatf("  Scoreboard Results:"), UVM_NONE)
    `uvm_info("SB", $sformatf("    PASSED: %0d", pass_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    FAILED: %0d", fail_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    TOTAL:  %0d", pass_count + fail_count), UVM_NONE)
    `uvm_info("SB", "============================================", UVM_NONE)
  endfunction

endclass
