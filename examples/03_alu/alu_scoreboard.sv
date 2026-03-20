// ALU Scoreboard — computes expected results and compares with DUT output
class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_seq_item, alu_scoreboard) analysis_export;

  int pass_count = 0;
  int fail_count = 0;
  int total_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(alu_seq_item tr);
    bit [31:0] expected_result;
    bit        expected_zero;
    bit [32:0] ext;

    total_count++;

    case (tr.opcode)
      alu_seq_item::OP_ADD: begin
        ext = {1'b0, tr.operand_a} + {1'b0, tr.operand_b};
        expected_result = ext[31:0];
      end
      alu_seq_item::OP_SUB: begin
        ext = {1'b0, tr.operand_a} - {1'b0, tr.operand_b};
        expected_result = ext[31:0];
      end
      alu_seq_item::OP_AND:  expected_result = tr.operand_a & tr.operand_b;
      alu_seq_item::OP_OR:   expected_result = tr.operand_a | tr.operand_b;
      alu_seq_item::OP_XOR:  expected_result = tr.operand_a ^ tr.operand_b;
      alu_seq_item::OP_NOT:  expected_result = ~tr.operand_a;
      alu_seq_item::OP_SLL:  expected_result = tr.operand_a << tr.operand_b[4:0];
      alu_seq_item::OP_SRL:  expected_result = tr.operand_a >> tr.operand_b[4:0];
      alu_seq_item::OP_SRA:  expected_result = $signed(tr.operand_a) >>> tr.operand_b[4:0];
      alu_seq_item::OP_MUL:  expected_result = tr.operand_a[15:0] * tr.operand_b[15:0];
      alu_seq_item::OP_INC: begin
        ext = {1'b0, tr.operand_a} + 1;
        expected_result = ext[31:0];
      end
      alu_seq_item::OP_DEC: begin
        ext = {1'b0, tr.operand_a} - 1;
        expected_result = ext[31:0];
      end
      alu_seq_item::OP_PASS: expected_result = tr.operand_a;
      default:                expected_result = 0;
    endcase

    expected_zero = (expected_result == 0);

    if (tr.result === expected_result) begin
      pass_count++;
      `uvm_info("SCB", $sformatf("PASS: %s", tr.convert2string()), UVM_MEDIUM)
    end else begin
      fail_count++;
      `uvm_error("SCB", $sformatf("FAIL: %s | expected result=0x%08h",
                 tr.convert2string(), expected_result))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", "        ALU SCOREBOARD SUMMARY              ", UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total      : %0d", total_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Passed     : %0d", pass_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Failed     : %0d", fail_count), UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    if (fail_count == 0)
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
    else
      `uvm_error("SCB", "*** TEST FAILED ***")
  endfunction

endclass
