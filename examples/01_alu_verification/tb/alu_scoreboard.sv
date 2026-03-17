// ALU Scoreboard — checks DUT results against expected values
class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;

  int pass_count  = 0;
  int fail_count  = 0;
  int total_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(alu_transaction txn);
    bit [8:0] expected_wide;
    bit [7:0] expected_result;
    bit       expected_carry;
    bit       expected_zero;

    total_count++;

    case (txn.operation)
      ALU_ADD: expected_wide = txn.operand_a + txn.operand_b;
      ALU_SUB: expected_wide = txn.operand_a - txn.operand_b;
      ALU_AND: expected_wide = {1'b0, txn.operand_a & txn.operand_b};
      ALU_OR:  expected_wide = {1'b0, txn.operand_a | txn.operand_b};
      ALU_XOR: expected_wide = {1'b0, txn.operand_a ^ txn.operand_b};
      default: expected_wide = 9'h000;
    endcase

    expected_result = expected_wide[7:0];
    expected_carry  = expected_wide[8];
    expected_zero   = (expected_result == 8'h00);

    if (txn.result === expected_result &&
        txn.carry_out === expected_carry &&
        txn.zero_flag === expected_zero) begin
      pass_count++;
      `uvm_info("SCB", $sformatf("PASS [%0d]: %s", total_count, txn.convert2string()), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SCB", $sformatf(
        "FAIL [%0d]: %s | Expected: result=0x%02h carry=%0b zero=%0b",
        total_count, txn.convert2string(), expected_result, expected_carry, expected_zero))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "================================================", UVM_NONE)
    `uvm_info("SCB", $sformatf("  ALU Scoreboard Results"), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Total: %0d | Passed: %0d | Failed: %0d",
                               total_count, pass_count, fail_count), UVM_NONE)
    `uvm_info("SCB", "================================================", UVM_NONE)
    if (fail_count > 0)
      `uvm_error("SCB", "*** TEST FAILED ***")
    else
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
  endfunction

endclass
