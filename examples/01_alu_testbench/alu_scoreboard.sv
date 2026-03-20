class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;
  int pass_count, fail_count;

  function new(string name = "alu_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(alu_transaction tx);
    bit [31:0] expected;
    bit        exp_zero, exp_carry;
    bit [32:0] wide_result;

    case (tx.opcode)
      ALU_ADD: begin
        wide_result = {1'b0, tx.operand_a} + {1'b0, tx.operand_b};
        expected    = wide_result[31:0];
        exp_carry   = wide_result[32];
      end
      ALU_SUB: begin
        wide_result = {1'b0, tx.operand_a} - {1'b0, tx.operand_b};
        expected    = wide_result[31:0];
        exp_carry   = wide_result[32];
      end
      ALU_MUL: begin
        expected  = tx.operand_a[15:0] * tx.operand_b[15:0];
        exp_carry = 1'b0;
      end
      ALU_AND: begin
        expected  = tx.operand_a & tx.operand_b;
        exp_carry = 1'b0;
      end
      ALU_OR: begin
        expected  = tx.operand_a | tx.operand_b;
        exp_carry = 1'b0;
      end
      ALU_XOR: begin
        expected  = tx.operand_a ^ tx.operand_b;
        exp_carry = 1'b0;
      end
      ALU_SHL: begin
        expected  = tx.operand_a << tx.operand_b[4:0];
        exp_carry = 1'b0;
      end
      ALU_SHR: begin
        expected  = tx.operand_a >> tx.operand_b[4:0];
        exp_carry = 1'b0;
      end
    endcase

    exp_zero = (expected == 32'h0);

    if (tx.result !== expected) begin
      fail_count++;
      `uvm_error("SB", $sformatf("RESULT MISMATCH: %s\n  Expected: 0x%08h\n  Got:      0x%08h",
                 tx.convert2string(), expected, tx.result))
    end else if (tx.zero_flag !== exp_zero) begin
      fail_count++;
      `uvm_error("SB", $sformatf("ZERO FLAG MISMATCH: expected=%0b got=%0b for %s",
                 exp_zero, tx.zero_flag, tx.convert2string()))
    end else begin
      pass_count++;
      `uvm_info("SB", $sformatf("PASS: %s", tx.convert2string()), UVM_HIGH)
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "\n============================================\n" +
      "  ALU Scoreboard Summary\n" +
      "  Total: %0d | Pass: %0d | Fail: %0d\n" +
      "============================================",
      pass_count + fail_count, pass_count, fail_count), UVM_LOW)

    if (fail_count > 0)
      `uvm_error("SB", "*** TEST FAILED ***")
    else
      `uvm_info("SB", "*** ALL CHECKS PASSED ***", UVM_LOW)
  endfunction
endclass
