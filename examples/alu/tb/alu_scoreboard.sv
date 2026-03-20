class alu_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;

  int pass_count = 0;
  int fail_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(alu_transaction tx);
    bit [15:0] expected_result;
    bit        expected_overflow;

    compute_expected(tx.operand_a, tx.operand_b, tx.opcode,
                     expected_result, expected_overflow);

    if (tx.result === expected_result && tx.overflow === expected_overflow) begin
      pass_count++;
      `uvm_info("SB", $sformatf("PASS: %s", tx.convert2string()), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SB", $sformatf(
        "FAIL: %s | Expected: result=0x%04h ovf=%0b",
        tx.convert2string(), expected_result, expected_overflow))
    end
  endfunction

  function void compute_expected(
    input  bit [7:0]  a,
    input  bit [7:0]  b,
    input  bit [1:0]  op,
    output bit [15:0] result,
    output bit        overflow
  );
    result   = '0;
    overflow = 1'b0;

    case (op)
      2'b00: begin  // ADD
        {overflow, result[7:0]} = a + b;
        result[15:8] = '0;
      end
      2'b01: begin  // SUB
        result[7:0]  = a - b;
        result[15:8] = '0;
        overflow     = (a < b);
      end
      2'b10: begin  // MUL
        result = a * b;
      end
      2'b11: begin  // AND
        result[7:0]  = a & b;
        result[15:8] = '0;
      end
    endcase
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "\n============================================\n"  +
      "  ALU Scoreboard Summary\n"                        +
      "  Passed: %0d\n"                                   +
      "  Failed: %0d\n"                                   +
      "  Total:  %0d\n"                                   +
      "============================================",
      pass_count, fail_count, pass_count + fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SB", "TEST FAILED -- mismatches detected")
    else
      `uvm_info("SB", "TEST PASSED -- all comparisons matched", UVM_LOW)
  endfunction
endclass
