// ALU Transaction — represents one ALU operation
class alu_txn extends uvm_sequence_item;

  // Stimulus fields (randomized)
  rand bit [7:0] operand_a;
  rand bit [7:0] operand_b;
  rand bit [1:0] operation;

  // Response fields (captured by monitor)
  bit [8:0] result;
  bit       result_valid;

  `uvm_object_utils_begin(alu_txn)
    `uvm_field_int(operand_a,    UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(operand_b,    UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(operation,    UVM_ALL_ON)
    `uvm_field_int(result,       UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(result_valid, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "alu_txn");
    super.new(name);
  endfunction

  // Human-readable operation name
  function string op_name();
    case (operation)
      2'b00: return "ADD";
      2'b01: return "SUB";
      2'b10: return "AND";
      2'b11: return "OR";
    endcase
  endfunction

  function string convert2string();
    return $sformatf("%s: %0d %s %0d = %0d",
                     get_name(), operand_a, op_name(), operand_b, result);
  endfunction

endclass
