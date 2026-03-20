class alu_coverage extends uvm_subscriber #(alu_transaction);
  `uvm_component_utils(alu_coverage)

  alu_transaction tx;

  covergroup alu_cg;
    opcode_cp: coverpoint tx.opcode {
      bins add = {2'b00};
      bins sub = {2'b01};
      bins mul = {2'b10};
      bins and_op = {2'b11};
    }

    operand_a_cp: coverpoint tx.operand_a {
      bins zero     = {0};
      bins low      = {[1:63]};
      bins mid      = {[64:191]};
      bins high     = {[192:254]};
      bins max_val  = {255};
    }

    operand_b_cp: coverpoint tx.operand_b {
      bins zero     = {0};
      bins low      = {[1:63]};
      bins mid      = {[64:191]};
      bins high     = {[192:254]};
      bins max_val  = {255};
    }

    overflow_cp: coverpoint tx.overflow {
      bins no_overflow = {0};
      bins overflow    = {1};
    }

    op_x_overflow: cross opcode_cp, overflow_cp;

    op_x_a: cross opcode_cp, operand_a_cp;

    op_x_b: cross opcode_cp, operand_b_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  function void write(alu_transaction t);
    tx = t;
    alu_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("ALU functional coverage: %.2f%%",
              alu_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
