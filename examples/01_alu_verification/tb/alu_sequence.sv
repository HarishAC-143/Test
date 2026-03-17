// ============================================================================
// ALU Sequences — different stimulus generation strategies
// ============================================================================

// Base sequence — generates fully random ALU transactions
class alu_base_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_base_sequence)

  rand int unsigned num_txns;

  constraint default_count_c {
    num_txns inside {[20:100]};
  }

  function new(string name = "alu_base_sequence");
    super.new(name);
  endfunction

  task body();
    alu_transaction txn;

    `uvm_info("SEQ", $sformatf("Starting base sequence with %0d transactions", num_txns), UVM_MEDIUM)

    repeat (num_txns) begin
      txn = alu_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize());
      finish_item(txn);
    end
  endtask
endclass


// Directed sequence — tests specific corner cases
class alu_corner_case_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_corner_case_sequence)

  function new(string name = "alu_corner_case_sequence");
    super.new(name);
  endfunction

  task body();
    alu_transaction txn;

    `uvm_info("SEQ", "Running corner case sequence", UVM_MEDIUM)

    // Test 1: 0 + 0
    send_directed(8'h00, 8'h00, ALU_ADD);
    // Test 2: FF + 01 (overflow)
    send_directed(8'hFF, 8'h01, ALU_ADD);
    // Test 3: FF + FF (max overflow)
    send_directed(8'hFF, 8'hFF, ALU_ADD);
    // Test 4: 00 - 01 (underflow)
    send_directed(8'h00, 8'h01, ALU_SUB);
    // Test 5: FF - FF = 0
    send_directed(8'hFF, 8'hFF, ALU_SUB);
    // Test 6: FF AND 0F
    send_directed(8'hFF, 8'h0F, ALU_AND);
    // Test 7: AA OR 55
    send_directed(8'hAA, 8'h55, ALU_OR);
    // Test 8: FF XOR FF = 0
    send_directed(8'hFF, 8'hFF, ALU_XOR);
    // Test 9: AA XOR 55
    send_directed(8'hAA, 8'h55, ALU_XOR);
    // Test 10: 00 XOR 00
    send_directed(8'h00, 8'h00, ALU_XOR);
  endtask

  task send_directed(bit [7:0] a, bit [7:0] b, alu_op_t op);
    alu_transaction txn = alu_transaction::type_id::create("txn");
    start_item(txn);
    txn.operand_a = a;
    txn.operand_b = b;
    txn.operation = op;
    finish_item(txn);
  endtask
endclass


// Operation-focused sequence — only tests one operation type
class alu_single_op_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_single_op_sequence)

  rand alu_op_t target_op;
  rand int unsigned num_txns;

  constraint default_count_c {
    num_txns inside {[10:50]};
  }

  function new(string name = "alu_single_op_sequence");
    super.new(name);
  endfunction

  task body();
    alu_transaction txn;

    `uvm_info("SEQ", $sformatf("Running %0d transactions with op=%s", num_txns, target_op.name()), UVM_MEDIUM)

    repeat (num_txns) begin
      txn = alu_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with { operation == target_op; });
      finish_item(txn);
    end
  endtask
endclass


// Full test sequence — combines directed and random testing
class alu_full_test_sequence extends uvm_sequence #(alu_transaction);
  `uvm_object_utils(alu_full_test_sequence)

  function new(string name = "alu_full_test_sequence");
    super.new(name);
  endfunction

  task body();
    alu_corner_case_sequence corner_seq;
    alu_single_op_sequence  add_seq;
    alu_single_op_sequence  sub_seq;
    alu_base_sequence       random_seq;

    // Phase 1: Corner cases
    `uvm_info("SEQ", "=== Phase 1: Corner Cases ===", UVM_LOW)
    corner_seq = alu_corner_case_sequence::type_id::create("corner_seq");
    corner_seq.start(m_sequencer);

    // Phase 2: ADD-focused testing
    `uvm_info("SEQ", "=== Phase 2: ADD Operations ===", UVM_LOW)
    add_seq = alu_single_op_sequence::type_id::create("add_seq");
    add_seq.target_op = ALU_ADD;
    add_seq.num_txns  = 30;
    add_seq.start(m_sequencer);

    // Phase 3: SUB-focused testing
    `uvm_info("SEQ", "=== Phase 3: SUB Operations ===", UVM_LOW)
    sub_seq = alu_single_op_sequence::type_id::create("sub_seq");
    sub_seq.target_op = ALU_SUB;
    sub_seq.num_txns  = 30;
    sub_seq.start(m_sequencer);

    // Phase 4: Fully random
    `uvm_info("SEQ", "=== Phase 4: Random Operations ===", UVM_LOW)
    random_seq = alu_base_sequence::type_id::create("random_seq");
    random_seq.num_txns = 100;
    random_seq.start(m_sequencer);
  endtask
endclass
