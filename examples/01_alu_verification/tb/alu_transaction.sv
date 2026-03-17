// ALU Transaction — represents a single ALU operation
class alu_transaction extends uvm_sequence_item;
  `uvm_object_utils(alu_transaction)

  // Stimulus fields (randomized by sequences)
  rand bit [7:0]  operand_a;
  rand bit [7:0]  operand_b;
  rand alu_op_t   operation;

  // Response fields (captured by monitor)
  bit [7:0]  result;
  bit        carry_out;
  bit        zero_flag;

  constraint valid_operation_c {
    operation inside {ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR};
  }

  constraint interesting_values_c {
    operand_a dist {0 := 5, 8'hFF := 5, [1:8'hFE] := 90};
    operand_b dist {0 := 5, 8'hFF := 5, [1:8'hFE] := 90};
  }

  function new(string name = "alu_transaction");
    super.new(name);
  endfunction

  function void do_copy(uvm_object rhs);
    alu_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    this.operand_a = rhs_.operand_a;
    this.operand_b = rhs_.operand_b;
    this.operation = rhs_.operation;
    this.result    = rhs_.result;
    this.carry_out = rhs_.carry_out;
    this.zero_flag = rhs_.zero_flag;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    alu_transaction rhs_;
    bit status;
    status = super.do_compare(rhs, comparer);
    $cast(rhs_, rhs);
    status &= (this.operand_a == rhs_.operand_a);
    status &= (this.operand_b == rhs_.operand_b);
    status &= (this.operation == rhs_.operation);
    status &= (this.result    == rhs_.result);
    status &= (this.carry_out == rhs_.carry_out);
    status &= (this.zero_flag == rhs_.zero_flag);
    return status;
  endfunction

  function string convert2string();
    return $sformatf("a=0x%02h b=0x%02h op=%s | result=0x%02h carry=%0b zero=%0b",
                     operand_a, operand_b, operation.name(),
                     result, carry_out, zero_flag);
  endfunction

endclass
