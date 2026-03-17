// ============================================================================
// FIFO Sequences
// ============================================================================

// Random operations sequence
class fifo_random_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_random_sequence)

  rand int unsigned num_txns;

  constraint default_c {
    num_txns inside {[50:200]};
  }

  function new(string name = "fifo_random_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction txn;

    `uvm_info("SEQ", $sformatf("Random FIFO sequence: %0d operations", num_txns), UVM_MEDIUM)

    repeat (num_txns) begin
      txn = fifo_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize());
      finish_item(txn);
    end
  endtask
endclass


// Fill-and-drain sequence — fills the FIFO completely, then drains it
class fifo_fill_drain_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_fill_drain_sequence)

  function new(string name = "fifo_fill_drain_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction txn;

    `uvm_info("SEQ", $sformatf("Fill-and-drain: filling %0d entries", FIFO_DEPTH), UVM_MEDIUM)

    // Fill the FIFO to capacity
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      txn = fifo_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with {
        operation == FIFO_WRITE;
      });
      finish_item(txn);
    end

    // Attempt one more write when full (should be blocked)
    `uvm_info("SEQ", "Attempting write when full", UVM_MEDIUM)
    txn = fifo_transaction::type_id::create("txn");
    start_item(txn);
    txn.operation = FIFO_WRITE;
    txn.wr_data   = 8'hFF;
    finish_item(txn);

    // Drain all entries
    `uvm_info("SEQ", "Draining FIFO", UVM_MEDIUM)
    for (int i = 0; i < FIFO_DEPTH; i++) begin
      txn = fifo_transaction::type_id::create("txn");
      start_item(txn);
      txn.operation = FIFO_READ;
      finish_item(txn);
    end

    // Attempt read when empty (should be blocked)
    `uvm_info("SEQ", "Attempting read when empty", UVM_MEDIUM)
    txn = fifo_transaction::type_id::create("txn");
    start_item(txn);
    txn.operation = FIFO_READ;
    finish_item(txn);
  endtask
endclass


// Simultaneous read-write sequence
class fifo_simultaneous_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_simultaneous_sequence)

  rand int unsigned num_txns;

  constraint default_c {
    num_txns inside {[20:50]};
  }

  function new(string name = "fifo_simultaneous_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction txn;

    `uvm_info("SEQ", "Simultaneous read-write test", UVM_MEDIUM)

    // First, put some data in the FIFO
    repeat (FIFO_DEPTH / 2) begin
      txn = fifo_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with { operation == FIFO_WRITE; });
      finish_item(txn);
    end

    // Now do simultaneous read+write
    repeat (num_txns) begin
      txn = fifo_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with { operation == FIFO_BOTH; });
      finish_item(txn);
    end
  endtask
endclass


// Burst sequence — alternating bursts of writes and reads
class fifo_burst_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_burst_sequence)

  rand int unsigned num_bursts;
  rand int unsigned burst_size;

  constraint default_c {
    num_bursts inside {[3:8]};
    burst_size inside {[4:FIFO_DEPTH]};
  }

  function new(string name = "fifo_burst_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_transaction txn;

    `uvm_info("SEQ", $sformatf("Burst test: %0d bursts of %0d", num_bursts, burst_size), UVM_MEDIUM)

    repeat (num_bursts) begin
      // Write burst
      repeat (burst_size) begin
        txn = fifo_transaction::type_id::create("txn");
        start_item(txn);
        assert(txn.randomize() with { operation == FIFO_WRITE; });
        finish_item(txn);
      end

      // Read burst
      repeat (burst_size) begin
        txn = fifo_transaction::type_id::create("txn");
        start_item(txn);
        txn.operation = FIFO_READ;
        finish_item(txn);
      end
    end
  endtask
endclass


// Full test sequence
class fifo_full_test_sequence extends uvm_sequence #(fifo_transaction);
  `uvm_object_utils(fifo_full_test_sequence)

  function new(string name = "fifo_full_test_sequence");
    super.new(name);
  endfunction

  task body();
    fifo_fill_drain_sequence     fill_drain;
    fifo_simultaneous_sequence   simul;
    fifo_burst_sequence          burst;
    fifo_random_sequence         random;

    `uvm_info("SEQ", "=== Phase 1: Fill and Drain ===", UVM_LOW)
    fill_drain = fifo_fill_drain_sequence::type_id::create("fill_drain");
    fill_drain.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 2: Simultaneous R/W ===", UVM_LOW)
    simul = fifo_simultaneous_sequence::type_id::create("simul");
    simul.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 3: Burst Operations ===", UVM_LOW)
    burst = fifo_burst_sequence::type_id::create("burst");
    burst.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 4: Random Operations ===", UVM_LOW)
    random = fifo_random_sequence::type_id::create("random");
    random.num_txns = 300;
    random.start(m_sequencer);
  endtask
endclass
