// Random stimulus sequence
class alu_random_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_random_sequence)

  rand int num_txns;
  constraint c_num { num_txns inside {[50:200]}; }

  function new(string name = "alu_random_sequence");
    super.new(name);
  endfunction

  task body();
    alu_transaction tx;
    `uvm_info("SEQ", $sformatf("Starting random sequence with %0d transactions", num_txns), UVM_LOW)
    repeat(num_txns) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize())
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
    `uvm_info("SEQ", "Random sequence complete", UVM_LOW)
  endtask
endclass

// Directed test sequence — corner cases
class alu_directed_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_directed_sequence)

  function new(string name = "alu_directed_sequence");
    super.new(name);
  endfunction

  task body();
    alu_transaction tx;

    `uvm_info("SEQ", "=== Testing zero operands ===", UVM_LOW)
    foreach ({ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR}[i]) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      tx.opcode    = alu_opcode_t'(i);
      tx.operand_a = 32'h0;
      tx.operand_b = 32'h0;
      finish_item(tx);
    end

    `uvm_info("SEQ", "=== Testing max values ===", UVM_LOW)
    foreach ({ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR}[i]) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      tx.opcode    = alu_opcode_t'(i);
      tx.operand_a = 32'hFFFF_FFFF;
      tx.operand_b = 32'hFFFF_FFFF;
      finish_item(tx);
    end

    `uvm_info("SEQ", "=== Testing addition overflow ===", UVM_LOW)
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.opcode    = ALU_ADD;
    tx.operand_a = 32'h7FFF_FFFF;
    tx.operand_b = 32'h0000_0001;
    finish_item(tx);

    `uvm_info("SEQ", "=== Testing subtraction underflow ===", UVM_LOW)
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.opcode    = ALU_SUB;
    tx.operand_a = 32'h8000_0000;
    tx.operand_b = 32'h0000_0001;
    finish_item(tx);

    `uvm_info("SEQ", "=== Testing shifts ===", UVM_LOW)
    for (int i = 0; i < 32; i += 8) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      tx.opcode    = ALU_SHL;
      tx.operand_a = 32'h0000_0001;
      tx.operand_b = i;
      finish_item(tx);

      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      tx.opcode    = ALU_SHR;
      tx.operand_a = 32'h8000_0000;
      tx.operand_b = i;
      finish_item(tx);
    end

    `uvm_info("SEQ", "Directed sequence complete", UVM_LOW)
  endtask
endclass

// All-opcodes-with-random-data sequence
class alu_all_ops_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_all_ops_sequence)

  function new(string name = "alu_all_ops_sequence");
    super.new(name);
  endfunction

  task body();
    alu_transaction tx;

    for (int op = 0; op < 8; op++) begin
      repeat(20) begin
        tx = alu_transaction::type_id::create("tx");
        start_item(tx);
        if (!tx.randomize() with { opcode == alu_opcode_t'(op); })
          `uvm_error("SEQ", "Randomization failed")
        finish_item(tx);
      end
    end
  endtask
endclass
