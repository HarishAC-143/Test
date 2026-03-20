// ALU Coverage Collector — tracks functional coverage
class alu_coverage extends uvm_subscriber #(alu_txn);

  `uvm_component_utils(alu_coverage)

  alu_txn txn;

  covergroup alu_cg;
    option.per_instance = 1;
    option.name = "alu_coverage";

    // Cover all operations
    cp_operation: coverpoint txn.operation {
      bins add = {2'b00};
      bins sub = {2'b01};
      bins and_op = {2'b10};
      bins or_op  = {2'b11};
    }

    // Cover operand_a ranges
    cp_operand_a: coverpoint txn.operand_a {
      bins zero     = {0};
      bins low      = {[1:63]};
      bins mid      = {[64:191]};
      bins high     = {[192:254]};
      bins max      = {255};
    }

    // Cover operand_b ranges
    cp_operand_b: coverpoint txn.operand_b {
      bins zero     = {0};
      bins low      = {[1:63]};
      bins mid      = {[64:191]};
      bins high     = {[192:254]};
      bins max      = {255};
    }

    // Cover carry/borrow (result bit 8)
    cp_carry: coverpoint txn.result[8] {
      bins no_carry = {0};
      bins carry    = {1};
    }

    // Cross coverage: operation x operand ranges
    cx_op_a: cross cp_operation, cp_operand_a;
    cx_op_b: cross cp_operation, cp_operand_b;

    // Cross coverage: operation x carry
    cx_op_carry: cross cp_operation, cp_carry;
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
    `uvm_info("COV", $sformatf("ALU Functional Coverage: %.2f%%",
              alu_cg.get_coverage()), UVM_NONE)
  endfunction

endclass
