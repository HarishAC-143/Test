class alu_transaction extends uvm_sequence_item;
  `uvm_object_utils(alu_transaction)

  // Stimulus fields
  rand bit [7:0] operand_a;
  rand bit [7:0] operand_b;
  rand bit [1:0] opcode;

  // Response fields
  bit [15:0] result;
  bit        overflow;

  // Human-readable opcode names
  typedef enum bit [1:0] {
    OP_ADD = 2'b00,
    OP_SUB = 2'b01,
    OP_MUL = 2'b10,
    OP_AND = 2'b11
  } op_e;

  // Constraints
  constraint c_operands {
    operand_a dist { 0 := 5, [1:254] := 85, 255 := 10 };
    operand_b dist { 0 := 5, [1:254] := 85, 255 := 10 };
  }

  function new(string name = "alu_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    string op_name;
    case (opcode)
      OP_ADD: op_name = "ADD";
      OP_SUB: op_name = "SUB";
      OP_MUL: op_name = "MUL";
      OP_AND: op_name = "AND";
    endcase
    return $sformatf("A=0x%02h %s B=0x%02h => Result=0x%04h OVF=%0b",
                     operand_a, op_name, operand_b, result, overflow);
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    alu_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (operand_a == rhs_.operand_a) &&
           (operand_b == rhs_.operand_b) &&
           (opcode    == rhs_.opcode)    &&
           (result    == rhs_.result)    &&
           (overflow  == rhs_.overflow);
  endfunction

  function void do_copy(uvm_object rhs);
    alu_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    operand_a = rhs_.operand_a;
    operand_b = rhs_.operand_b;
    opcode    = rhs_.opcode;
    result    = rhs_.result;
    overflow  = rhs_.overflow;
  endfunction
endclass
