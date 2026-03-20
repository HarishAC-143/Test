class alu_coverage extends uvm_subscriber #(alu_transaction);
  `uvm_component_utils(alu_coverage)

  alu_transaction tx;

  covergroup alu_cg;
    option.per_instance = 1;

    opcode_cp: coverpoint tx.opcode {
      bins add  = {ALU_ADD};
      bins sub  = {ALU_SUB};
      bins mul  = {ALU_MUL};
      bins and_op = {ALU_AND};
      bins or_op  = {ALU_OR};
      bins xor_op = {ALU_XOR};
      bins shl  = {ALU_SHL};
      bins shr  = {ALU_SHR};
    }

    operand_a_cp: coverpoint tx.operand_a {
      bins zero     = {32'h0};
      bins one      = {32'h1};
      bins small    = {[32'h2 : 32'hFF]};
      bins medium   = {[32'h100 : 32'hFFFF]};
      bins large    = {[32'h1_0000 : 32'h7FFF_FFFE]};
      bins max_pos  = {32'h7FFF_FFFF};
      bins neg_one  = {32'hFFFF_FFFF};
      bins min_neg  = {32'h8000_0000};
    }

    operand_b_cp: coverpoint tx.operand_b {
      bins zero     = {32'h0};
      bins one      = {32'h1};
      bins small    = {[32'h2 : 32'hFF]};
      bins medium   = {[32'h100 : 32'hFFFF]};
      bins large    = {[32'h1_0000 : 32'h7FFF_FFFE]};
      bins max_pos  = {32'h7FFF_FFFF};
      bins neg_one  = {32'hFFFF_FFFF};
      bins min_neg  = {32'h8000_0000};
    }

    zero_flag_cp:     coverpoint tx.zero_flag;
    carry_flag_cp:    coverpoint tx.carry_flag;
    overflow_flag_cp: coverpoint tx.overflow_flag;

    op_x_a: cross opcode_cp, operand_a_cp;
    op_x_b: cross opcode_cp, operand_b_cp;
    op_x_flags: cross opcode_cp, zero_flag_cp, carry_flag_cp;
  endgroup

  function new(string name = "alu_coverage", uvm_component parent = null);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  function void write(alu_transaction t);
    tx = t;
    alu_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("ALU Functional Coverage: %.1f%%",
              alu_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
