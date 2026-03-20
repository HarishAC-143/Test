typedef enum bit [2:0] {
  ALU_ADD = 3'b000,
  ALU_SUB = 3'b001,
  ALU_MUL = 3'b010,
  ALU_AND = 3'b011,
  ALU_OR  = 3'b100,
  ALU_XOR = 3'b101,
  ALU_SHL = 3'b110,
  ALU_SHR = 3'b111
} alu_opcode_t;

class alu_transaction extends uvm_sequence_item;
  `uvm_object_utils(alu_transaction)

  // Stimulus fields
  rand alu_opcode_t opcode;
  rand bit [31:0]   operand_a;
  rand bit [31:0]   operand_b;

  // Response fields (filled by monitor)
  bit [31:0] result;
  bit        zero_flag;
  bit        carry_flag;
  bit        overflow_flag;

  // Constraints
  constraint c_shift_amount {
    (opcode == ALU_SHL || opcode == ALU_SHR) -> operand_b inside {[0:31]};
  }

  function new(string name = "alu_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("op=%s a=0x%08h b=0x%08h | result=0x%08h Z=%0b C=%0b V=%0b",
                     opcode.name(), operand_a, operand_b,
                     result, zero_flag, carry_flag, overflow_flag);
  endfunction

  function void do_copy(uvm_object rhs);
    alu_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    opcode        = rhs_.opcode;
    operand_a     = rhs_.operand_a;
    operand_b     = rhs_.operand_b;
    result        = rhs_.result;
    zero_flag     = rhs_.zero_flag;
    carry_flag    = rhs_.carry_flag;
    overflow_flag = rhs_.overflow_flag;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    alu_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            opcode    == rhs_.opcode &&
            operand_a == rhs_.operand_a &&
            operand_b == rhs_.operand_b &&
            result    == rhs_.result);
  endfunction
endclass
