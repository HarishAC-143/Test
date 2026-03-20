// ALU Sequences

// Random operations with random operands
class alu_random_seq extends uvm_sequence #(alu_seq_item);
  `uvm_object_utils(alu_random_seq)

  int num_operations = 100;

  function new(string name = "alu_random_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_operations) begin
      alu_seq_item req = alu_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize())
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass


// Test a single specific opcode exhaustively
class alu_directed_op_seq extends uvm_sequence #(alu_seq_item);
  `uvm_object_utils(alu_directed_op_seq)

  alu_seq_item::opcode_e target_opcode = alu_seq_item::OP_ADD;
  int num_operations = 50;

  function new(string name = "alu_directed_op_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_operations) begin
      alu_seq_item req = alu_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { opcode == target_opcode; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass


// Corner-case test with known boundary values
class alu_corner_case_seq extends uvm_sequence #(alu_seq_item);
  `uvm_object_utils(alu_corner_case_seq)

  function new(string name = "alu_corner_case_seq");
    super.new(name);
  endfunction

  task body();
    // Test each arithmetic operation with boundary values
    alu_seq_item::opcode_e arith_ops[] = '{
      alu_seq_item::OP_ADD, alu_seq_item::OP_SUB,
      alu_seq_item::OP_INC, alu_seq_item::OP_DEC
    };

    bit [31:0] corner_values[] = '{
      32'h0000_0000, 32'h0000_0001, 32'h7FFF_FFFF,
      32'h8000_0000, 32'hFFFF_FFFF
    };

    foreach (arith_ops[op]) begin
      foreach (corner_values[a]) begin
        foreach (corner_values[b]) begin
          alu_seq_item req = alu_seq_item::type_id::create("req");
          start_item(req);
          if (!req.randomize() with {
            opcode    == arith_ops[op];
            operand_a == corner_values[a];
            operand_b == corner_values[b];
          }) `uvm_error("RAND", "Randomization failed")
          finish_item(req);
        end
      end
    end
  endtask
endclass


// Shift operations test
class alu_shift_seq extends uvm_sequence #(alu_seq_item);
  `uvm_object_utils(alu_shift_seq)

  function new(string name = "alu_shift_seq");
    super.new(name);
  endfunction

  task body();
    alu_seq_item::opcode_e shift_ops[] = '{
      alu_seq_item::OP_SLL, alu_seq_item::OP_SRL, alu_seq_item::OP_SRA
    };

    foreach (shift_ops[op]) begin
      for (int shift = 0; shift < 32; shift++) begin
        alu_seq_item req = alu_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
          opcode    == shift_ops[op];
          operand_b == shift;
        }) `uvm_error("RAND", "Randomization failed")
        finish_item(req);
      end
    end
  endtask
endclass


// All-operations sweep: run each opcode a number of times
class alu_all_ops_seq extends uvm_sequence #(alu_seq_item);
  `uvm_object_utils(alu_all_ops_seq)

  int ops_per_opcode = 20;

  function new(string name = "alu_all_ops_seq");
    super.new(name);
  endfunction

  task body();
    alu_seq_item::opcode_e all_ops[] = '{
      alu_seq_item::OP_ADD,  alu_seq_item::OP_SUB,
      alu_seq_item::OP_AND,  alu_seq_item::OP_OR,
      alu_seq_item::OP_XOR,  alu_seq_item::OP_NOT,
      alu_seq_item::OP_SLL,  alu_seq_item::OP_SRL,
      alu_seq_item::OP_SRA,  alu_seq_item::OP_MUL,
      alu_seq_item::OP_INC,  alu_seq_item::OP_DEC,
      alu_seq_item::OP_PASS
    };

    foreach (all_ops[op]) begin
      `uvm_info("SEQ", $sformatf("Testing opcode: %s", all_ops[op].name()), UVM_LOW)
      repeat (ops_per_opcode) begin
        alu_seq_item req = alu_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { opcode == all_ops[op]; })
          `uvm_error("RAND", "Randomization failed")
        finish_item(req);
      end
    end
  endtask
endclass
