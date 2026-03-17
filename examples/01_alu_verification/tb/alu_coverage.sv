// ALU Coverage Collector — measures functional coverage
class alu_coverage extends uvm_subscriber #(alu_transaction);
  `uvm_component_utils(alu_coverage)

  alu_transaction txn_cached;

  covergroup alu_cg;
    option.per_instance = 1;

    operation_cp: coverpoint txn_cached.operation {
      bins add_op = {ALU_ADD};
      bins sub_op = {ALU_SUB};
      bins and_op = {ALU_AND};
      bins or_op  = {ALU_OR};
      bins xor_op = {ALU_XOR};
    }

    operand_a_cp: coverpoint txn_cached.operand_a {
      bins zero    = {0};
      bins max_val = {8'hFF};
      bins low     = {[1:8'h3F]};
      bins mid     = {[8'h40:8'hBF]};
      bins high    = {[8'hC0:8'hFE]};
    }

    operand_b_cp: coverpoint txn_cached.operand_b {
      bins zero    = {0};
      bins max_val = {8'hFF};
      bins low     = {[1:8'h3F]};
      bins mid     = {[8'h40:8'hBF]};
      bins high    = {[8'hC0:8'hFE]};
    }

    result_cp: coverpoint txn_cached.result {
      bins zero    = {0};
      bins max_val = {8'hFF};
      bins other   = {[1:8'hFE]};
    }

    carry_cp: coverpoint txn_cached.carry_out {
      bins no_carry = {0};
      bins carry    = {1};
    }

    zero_cp: coverpoint txn_cached.zero_flag {
      bins not_zero = {0};
      bins is_zero  = {1};
    }

    op_x_a: cross operation_cp, operand_a_cp;
    op_x_b: cross operation_cp, operand_b_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  function void write(alu_transaction t);
    txn_cached = t;
    alu_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("ALU Coverage: %.1f%%", alu_cg.get_coverage()), UVM_NONE)
  endfunction

endclass
