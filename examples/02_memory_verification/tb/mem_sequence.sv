// ============================================================================
// Memory Sequences
// ============================================================================

// Random read/write sequence
class mem_random_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_random_sequence)

  rand int unsigned num_txns;

  constraint default_c {
    num_txns inside {[20:100]};
  }

  function new(string name = "mem_random_sequence");
    super.new(name);
  endfunction

  task body();
    mem_transaction txn;

    `uvm_info("SEQ", $sformatf("Random sequence: %0d transactions", num_txns), UVM_MEDIUM)

    repeat (num_txns) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize());
      finish_item(txn);
    end
  endtask
endclass


// Write-then-read-back sequence — verifies data integrity
// Writes data to a set of addresses, then reads them back
class mem_write_read_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_write_read_sequence)

  rand int unsigned num_locations;
  rand bit [MEM_ADDR_WIDTH-1:0] base_addr;

  constraint defaults_c {
    num_locations inside {[4:32]};
    base_addr inside {[0:224]};  // Leave room for num_locations
  }

  // Storage for written data (for read-back comparison)
  bit [MEM_DATA_WIDTH-1:0] written_data [256];

  function new(string name = "mem_write_read_sequence");
    super.new(name);
  endfunction

  task body();
    mem_transaction txn;

    `uvm_info("SEQ", $sformatf("Write-Read sequence: %0d locations starting at 0x%02h",
              num_locations, base_addr), UVM_MEDIUM)

    // Phase 1: Write to all locations
    for (int i = 0; i < num_locations; i++) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      assert(txn.randomize() with {
        addr  == base_addr + i;
        write == 1;
      });
      written_data[base_addr + i] = txn.wdata;
      finish_item(txn);
    end

    // Phase 2: Read back all locations
    for (int i = 0; i < num_locations; i++) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      txn.addr  = base_addr + i;
      txn.write = 0;
      finish_item(txn);
    end
  endtask
endclass


// Walking-ones sequence — writes walking-one patterns to verify data bus integrity
class mem_walking_ones_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_walking_ones_sequence)

  function new(string name = "mem_walking_ones_sequence");
    super.new(name);
  endfunction

  task body();
    mem_transaction txn;

    `uvm_info("SEQ", "Walking-ones data bus test", UVM_MEDIUM)

    for (int i = 0; i < MEM_DATA_WIDTH; i++) begin
      // Write walking-one pattern
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      txn.addr  = i;
      txn.wdata = (32'h1 << i);
      txn.write = 1;
      finish_item(txn);

      // Read it back
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      txn.addr  = i;
      txn.write = 0;
      finish_item(txn);
    end
  endtask
endclass


// Address bus test — writes unique data to power-of-2 addresses
class mem_addr_bus_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_addr_bus_sequence)

  function new(string name = "mem_addr_bus_sequence");
    super.new(name);
  endfunction

  task body();
    mem_transaction txn;

    `uvm_info("SEQ", "Address bus test", UVM_MEDIUM)

    // Write unique values to power-of-2 addresses
    for (int i = 0; i < MEM_ADDR_WIDTH; i++) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      txn.addr  = (1 << i);
      txn.wdata = 32'hA000_0000 + i;
      txn.write = 1;
      finish_item(txn);
    end

    // Read them back to verify no address aliasing
    for (int i = 0; i < MEM_ADDR_WIDTH; i++) begin
      txn = mem_transaction::type_id::create("txn");
      start_item(txn);
      txn.addr  = (1 << i);
      txn.write = 0;
      finish_item(txn);
    end
  endtask
endclass


// Full memory test — combines all sub-sequences
class mem_full_test_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_full_test_sequence)

  function new(string name = "mem_full_test_sequence");
    super.new(name);
  endfunction

  task body();
    mem_walking_ones_sequence  walk_seq;
    mem_addr_bus_sequence      addr_seq;
    mem_write_read_sequence    wr_rd_seq;
    mem_random_sequence        rand_seq;

    `uvm_info("SEQ", "=== Phase 1: Walking-Ones Test ===", UVM_LOW)
    walk_seq = mem_walking_ones_sequence::type_id::create("walk_seq");
    walk_seq.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 2: Address Bus Test ===", UVM_LOW)
    addr_seq = mem_addr_bus_sequence::type_id::create("addr_seq");
    addr_seq.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 3: Write-Read-Back Test ===", UVM_LOW)
    wr_rd_seq = mem_write_read_sequence::type_id::create("wr_rd_seq");
    wr_rd_seq.start(m_sequencer);

    `uvm_info("SEQ", "=== Phase 4: Random Test ===", UVM_LOW)
    rand_seq = mem_random_sequence::type_id::create("rand_seq");
    rand_seq.num_txns = 200;
    rand_seq.start(m_sequencer);
  endtask
endclass
