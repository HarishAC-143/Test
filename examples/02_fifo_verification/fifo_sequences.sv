// Write sequence
class fifo_write_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_write_sequence)

  rand int num_txns;
  constraint c_num { num_txns inside {[5:30]}; }

  function new(string name = "fifo_write_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction tx;
    repeat(num_txns) begin
      tx = fifo_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { op == FIFO_WRITE; })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Read sequence
class fifo_read_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_read_sequence)

  rand int num_txns;
  constraint c_num { num_txns inside {[5:30]}; }

  function new(string name = "fifo_read_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction tx;
    repeat(num_txns) begin
      tx = fifo_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { op == FIFO_READ; })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Fill-then-drain sequence — pushes FIFO to full, then reads all
class fifo_fill_drain_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_fill_drain_sequence)

  int fifo_depth = 16;

  function new(string name = "fifo_fill_drain_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction tx;

    `uvm_info("SEQ", $sformatf("Filling FIFO to depth %0d", fifo_depth), UVM_LOW)
    repeat(fifo_depth) begin
      tx = fifo_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { op == FIFO_WRITE; delay == 0; })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end

    `uvm_info("SEQ", "Draining FIFO completely", UVM_LOW)
    repeat(fifo_depth) begin
      tx = fifo_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { op == FIFO_READ; delay == 0; })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Overflow sequence — writes beyond capacity
class fifo_overflow_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_overflow_sequence)

  int fifo_depth = 16;

  function new(string name = "fifo_overflow_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction tx;

    `uvm_info("SEQ", "Writing beyond FIFO capacity to test overflow", UVM_LOW)
    repeat(fifo_depth + 4) begin
      tx = fifo_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { op == FIFO_WRITE; delay == 0; })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Random mixed read/write sequence
class fifo_random_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_random_sequence)

  rand int num_txns;
  constraint c_num { num_txns inside {[50:200]}; }

  function new(string name = "fifo_random_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction tx;
    `uvm_info("SEQ", $sformatf("Running %0d random FIFO operations", num_txns), UVM_LOW)
    repeat(num_txns) begin
      tx = fifo_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize())
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass
