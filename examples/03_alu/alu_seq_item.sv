// ALU Sequence Item
class alu_seq_item extends uvm_sequence_item;

  // Opcodes
  typedef enum bit [3:0] {
    OP_ADD  = 4'h0,
    OP_SUB  = 4'h1,
    OP_AND  = 4'h2,
    OP_OR   = 4'h3,
    OP_XOR  = 4'h4,
    OP_NOT  = 4'h5,
    OP_SLL  = 4'h6,
    OP_SRL  = 4'h7,
    OP_SRA  = 4'h8,
    OP_MUL  = 4'h9,
    OP_INC  = 4'hA,
    OP_DEC  = 4'hB,
    OP_PASS = 4'hF
  } opcode_e;

  rand bit [31:0] operand_a;
  rand bit [31:0] operand_b;
  rand opcode_e   opcode;

  // Response fields
  bit [31:0] result;
  bit        zero_flag;
  bit        carry_flag;
  bit        overflow_flag;

  `uvm_object_utils_begin(alu_seq_item)
    `uvm_field_int(operand_a,     UVM_ALL_ON)
    `uvm_field_int(operand_b,     UVM_ALL_ON)
    `uvm_field_enum(opcode_e, opcode, UVM_ALL_ON)
    `uvm_field_int(result,        UVM_ALL_ON)
    `uvm_field_int(zero_flag,     UVM_ALL_ON)
    `uvm_field_int(carry_flag,    UVM_ALL_ON)
    `uvm_field_int(overflow_flag, UVM_ALL_ON)
  `uvm_object_utils_end

  // Interesting corner-case values appear with higher probability
  constraint interesting_values_c {
    operand_a dist {
      0                := 5,
      1                := 3,
      32'h7FFF_FFFF    := 3,
      32'h8000_0000    := 3,
      32'hFFFF_FFFF    := 3,
      [2:32'h7FFF_FFFE]    := 40,
      [32'h8000_0001:32'hFFFF_FFFE] := 40
    };

    operand_b dist {
      0                := 5,
      1                := 3,
      32'h7FFF_FFFF    := 3,
      32'h8000_0000    := 3,
      32'hFFFF_FFFF    := 3,
      [2:32'h7FFF_FFFE]    := 40,
      [32'h8000_0001:32'hFFFF_FFFE] := 40
    };
  }

  // For shift operations, limit shift amount to reasonable range
  constraint shift_amount_c {
    if (opcode inside {OP_SLL, OP_SRL, OP_SRA}) {
      operand_b inside {[0:31]};
    }
  }

  function new(string name = "alu_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s: A=0x%08h B=0x%08h => result=0x%08h Z=%0b C=%0b V=%0b",
                     opcode.name(), operand_a, operand_b, result,
                     zero_flag, carry_flag, overflow_flag);
  endfunction

endclass
