// ALU Coverage Collector
class alu_coverage extends uvm_subscriber #(alu_seq_item);
  `uvm_component_utils(alu_coverage)

  alu_seq_item tr;

  covergroup alu_cg;
    option.per_instance = 1;

    opcode_cp: coverpoint tr.opcode {
      bins arithmetic[] = {alu_seq_item::OP_ADD, alu_seq_item::OP_SUB,
                           alu_seq_item::OP_INC, alu_seq_item::OP_DEC};
      bins logical[]    = {alu_seq_item::OP_AND, alu_seq_item::OP_OR,
                           alu_seq_item::OP_XOR, alu_seq_item::OP_NOT};
      bins shift[]      = {alu_seq_item::OP_SLL, alu_seq_item::OP_SRL,
                           alu_seq_item::OP_SRA};
      bins multiply     = {alu_seq_item::OP_MUL};
      bins passthrough  = {alu_seq_item::OP_PASS};
    }

    operand_a_cp: coverpoint tr.operand_a {
      bins zero     = {0};
      bins one      = {1};
      bins max_pos  = {32'h7FFF_FFFF};
      bins min_neg  = {32'h8000_0000};
      bins all_ones = {32'hFFFF_FFFF};
      bins positive = {[2:32'h7FFF_FFFE]};
      bins negative = {[32'h8000_0001:32'hFFFF_FFFE]};
    }

    operand_b_cp: coverpoint tr.operand_b {
      bins zero     = {0};
      bins one      = {1};
      bins max_pos  = {32'h7FFF_FFFF};
      bins min_neg  = {32'h8000_0000};
      bins all_ones = {32'hFFFF_FFFF};
      bins other    = default;
    }

    zero_flag_cp: coverpoint tr.zero_flag {
      bins not_zero = {0};
      bins is_zero  = {1};
    }

    carry_flag_cp: coverpoint tr.carry_flag {
      bins no_carry = {0};
      bins carry    = {1};
    }

    overflow_flag_cp: coverpoint tr.overflow_flag {
      bins no_overflow = {0};
      bins overflow    = {1};
    }

    // Cross: each opcode with interesting operand_a values
    opcode_x_operand_a: cross opcode_cp, operand_a_cp;

    // Cross: opcode with result flags
    opcode_x_zero: cross opcode_cp, zero_flag_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  function void write(alu_seq_item t);
    tr = t;
    alu_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("ALU Functional Coverage: %.2f%%",
              alu_cg.get_coverage()), UVM_LOW)
  endfunction

endclass
