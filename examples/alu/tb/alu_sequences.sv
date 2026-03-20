// ──────── Base sequence ────────
class alu_base_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_base_sequence)

  function new(string name = "alu_base_sequence");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_fatal("SEQ", "alu_base_sequence::body() must be overridden")
  endtask
endclass

// ──────── Random operations ────────
class alu_random_sequence extends alu_base_sequence;
  `uvm_object_utils(alu_random_sequence)

  rand int unsigned num_txns;
  constraint c_num { num_txns inside {[20:100]}; }

  function new(string name = "alu_random_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_transaction tx;

    `uvm_info("SEQ", $sformatf("Running %0d random ALU transactions", num_txns), UVM_LOW)

    repeat(num_txns) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Directed ADD sequence ────────
class alu_add_sequence extends alu_base_sequence;
  `uvm_object_utils(alu_add_sequence)

  function new(string name = "alu_add_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_transaction tx;

    `uvm_info("SEQ", "Running directed ADD sequence", UVM_LOW)

    // Test corner cases for addition
    // 0 + 0
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 0; operand_b == 0; opcode == 2'b00; };
    finish_item(tx);

    // MAX + MAX (overflow)
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 8'hFF; operand_b == 8'hFF; opcode == 2'b00; };
    finish_item(tx);

    // 1 + MAX (overflow)
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 1; operand_b == 8'hFF; opcode == 2'b00; };
    finish_item(tx);

    // Random additions
    repeat(10) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { opcode == 2'b00; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Directed SUB sequence ────────
class alu_sub_sequence extends alu_base_sequence;
  `uvm_object_utils(alu_sub_sequence)

  function new(string name = "alu_sub_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_transaction tx;

    `uvm_info("SEQ", "Running directed SUB sequence", UVM_LOW)

    // a - a = 0
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 8'h42; operand_b == 8'h42; opcode == 2'b01; };
    finish_item(tx);

    // 0 - MAX (underflow)
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 0; operand_b == 8'hFF; opcode == 2'b01; };
    finish_item(tx);

    // Random subtractions
    repeat(10) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { opcode == 2'b01; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Directed MUL sequence ────────
class alu_mul_sequence extends alu_base_sequence;
  `uvm_object_utils(alu_mul_sequence)

  function new(string name = "alu_mul_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_transaction tx;

    `uvm_info("SEQ", "Running directed MUL sequence", UVM_LOW)

    // 0 * anything = 0
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 0; opcode == 2'b10; };
    finish_item(tx);

    // 1 * x = x
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 1; opcode == 2'b10; };
    finish_item(tx);

    // MAX * MAX
    tx = alu_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { operand_a == 8'hFF; operand_b == 8'hFF; opcode == 2'b10; };
    finish_item(tx);

    // Random multiplications
    repeat(10) begin
      tx = alu_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { opcode == 2'b10; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Full test sequence (runs all operations) ────────
class alu_full_sequence extends alu_base_sequence;
  `uvm_object_utils(alu_full_sequence)

  function new(string name = "alu_full_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_add_sequence    add_seq;
    alu_sub_sequence    sub_seq;
    alu_mul_sequence    mul_seq;
    alu_random_sequence rand_seq;

    `uvm_info("SEQ", "Running full ALU test sequence", UVM_LOW)

    add_seq = alu_add_sequence::type_id::create("add_seq");
    add_seq.start(m_sequencer);

    sub_seq = alu_sub_sequence::type_id::create("sub_seq");
    sub_seq.start(m_sequencer);

    mul_seq = alu_mul_sequence::type_id::create("mul_seq");
    mul_seq.start(m_sequencer);

    rand_seq = alu_random_sequence::type_id::create("rand_seq");
    rand_seq.num_txns = 200;
    rand_seq.start(m_sequencer);
  endtask
endclass
