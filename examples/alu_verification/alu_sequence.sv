// Base sequence — sends N random ALU transactions
class alu_base_sequence extends uvm_sequence #(alu_txn);

  `uvm_object_utils(alu_base_sequence)

  rand int unsigned num_txns;

  constraint default_count {
    num_txns inside {[50:200]};
  }

  function new(string name = "alu_base_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;
    `uvm_info("SEQ", $sformatf("Starting %0d random ALU transactions", num_txns), UVM_LOW)

    for (int i = 0; i < num_txns; i++) begin
      txn = alu_txn::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end

    `uvm_info("SEQ", "Base sequence complete", UVM_LOW)
  endtask

endclass


// ADD-focused sequence — tests addition with corner cases
class alu_add_sequence extends uvm_sequence #(alu_txn);

  `uvm_object_utils(alu_add_sequence)

  function new(string name = "alu_add_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;
    `uvm_info("SEQ", "Starting ADD corner-case sequence", UVM_LOW)

    // Test: 0 + 0
    send_txn(8'd0, 8'd0, 2'b00);

    // Test: MAX + 0
    send_txn(8'd255, 8'd0, 2'b00);

    // Test: 0 + MAX
    send_txn(8'd0, 8'd255, 2'b00);

    // Test: MAX + MAX (overflow)
    send_txn(8'd255, 8'd255, 2'b00);

    // Test: 1 + 1
    send_txn(8'd1, 8'd1, 2'b00);

    // Test: MAX + 1 (overflow)
    send_txn(8'd255, 8'd1, 2'b00);

    // Random ADD operations
    for (int i = 0; i < 50; i++) begin
      txn = alu_txn::type_id::create($sformatf("add_txn_%0d", i));
      start_item(txn);
      if (!txn.randomize() with { operation == 2'b00; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end

    `uvm_info("SEQ", "ADD sequence complete", UVM_LOW)
  endtask

  task send_txn(bit [7:0] a, bit [7:0] b, bit [1:0] op);
    alu_txn txn = alu_txn::type_id::create("directed_txn");
    start_item(txn);
    txn.operand_a = a;
    txn.operand_b = b;
    txn.operation = op;
    finish_item(txn);
  endtask

endclass


// Exhaustive sequence — tests all operations with directed + random
class alu_exhaustive_sequence extends uvm_sequence #(alu_txn);

  `uvm_object_utils(alu_exhaustive_sequence)

  function new(string name = "alu_exhaustive_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_txn txn;
    `uvm_info("SEQ", "Starting exhaustive operation sequence", UVM_LOW)

    // Directed: test each operation with known values
    for (int op = 0; op < 4; op++) begin
      // Zero inputs
      send_txn(8'd0, 8'd0, op[1:0]);
      // Max inputs
      send_txn(8'd255, 8'd255, op[1:0]);
      // Asymmetric
      send_txn(8'd170, 8'd85, op[1:0]);  // 0xAA, 0x55
      send_txn(8'd85, 8'd170, op[1:0]);
      // Powers of 2
      send_txn(8'd1, 8'd128, op[1:0]);
      send_txn(8'd128, 8'd1, op[1:0]);
    end

    // Random: 100 random transactions across all operations
    for (int i = 0; i < 100; i++) begin
      txn = alu_txn::type_id::create($sformatf("rand_txn_%0d", i));
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end

    `uvm_info("SEQ", "Exhaustive sequence complete", UVM_LOW)
  endtask

  task send_txn(bit [7:0] a, bit [7:0] b, bit [1:0] op);
    alu_txn txn = alu_txn::type_id::create("directed_txn");
    start_item(txn);
    txn.operand_a = a;
    txn.operand_b = b;
    txn.operation = op;
    finish_item(txn);
  endtask

endclass
