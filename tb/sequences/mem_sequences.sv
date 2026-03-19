//----------------------------------------------------------------------
// Memory Sequences
//
// Provides write, read, write-then-read, and fully random sequences
// demonstrating UVM sequence/driver synchronization.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Base sequence with common reset-wait logic
//----------------------------------------------------------------------
class mem_base_seq extends uvm_sequence #(mem_seq_item);
  `uvm_object_utils(mem_base_seq)

  function new(string name = "mem_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Base sequence body - override in subclass", UVM_MEDIUM)
  endtask
endclass

//----------------------------------------------------------------------
// Write sequence: writes random data to N random addresses
//----------------------------------------------------------------------
class mem_write_seq extends mem_base_seq;
  `uvm_object_utils(mem_write_seq)

  rand int unsigned num_txns;

  constraint default_num_c { num_txns inside {[4:16]}; }

  function new(string name = "mem_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_seq_item txn;
    `uvm_info(get_type_name(), $sformatf("Starting write sequence with %0d transactions", num_txns), UVM_MEDIUM)
    repeat (num_txns) begin
      txn = mem_seq_item::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with { wr_en == 1; rd_en == 0; })
        `uvm_error(get_type_name(), "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass

//----------------------------------------------------------------------
// Read sequence: reads from N random addresses
//----------------------------------------------------------------------
class mem_read_seq extends mem_base_seq;
  `uvm_object_utils(mem_read_seq)

  rand int unsigned num_txns;

  constraint default_num_c { num_txns inside {[4:16]}; }

  function new(string name = "mem_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_seq_item txn;
    `uvm_info(get_type_name(), $sformatf("Starting read sequence with %0d transactions", num_txns), UVM_MEDIUM)
    repeat (num_txns) begin
      txn = mem_seq_item::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with { wr_en == 0; rd_en == 1; })
        `uvm_error(get_type_name(), "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass

//----------------------------------------------------------------------
// Write-Read sequence: writes data then reads it back from each address
//----------------------------------------------------------------------
class mem_write_read_seq extends mem_base_seq;
  `uvm_object_utils(mem_write_read_seq)

  rand int unsigned num_txns;

  constraint default_num_c { num_txns inside {[4:16]}; }

  function new(string name = "mem_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_seq_item wr_txn, rd_txn;
    bit [3:0] test_addr;
    bit [7:0] test_data;

    `uvm_info(get_type_name(), $sformatf("Starting write-read sequence with %0d pairs", num_txns), UVM_MEDIUM)

    repeat (num_txns) begin
      // Randomize address and data
      test_addr = $urandom_range(0, 15);
      test_data = $urandom;

      // Write phase
      wr_txn = mem_seq_item::type_id::create("wr_txn");
      start_item(wr_txn);
      if (!wr_txn.randomize() with {
        addr  == test_addr;
        wdata == test_data;
        wr_en == 1;
        rd_en == 0;
      })
        `uvm_error(get_type_name(), "Write randomization failed")
      finish_item(wr_txn);

      // Read phase - same address
      rd_txn = mem_seq_item::type_id::create("rd_txn");
      start_item(rd_txn);
      if (!rd_txn.randomize() with {
        addr  == test_addr;
        wr_en == 0;
        rd_en == 1;
      })
        `uvm_error(get_type_name(), "Read randomization failed")
      finish_item(rd_txn);
    end
  endtask
endclass

//----------------------------------------------------------------------
// Random sequence: fully random mix of reads, writes, and idles
//----------------------------------------------------------------------
class mem_random_seq extends mem_base_seq;
  `uvm_object_utils(mem_random_seq)

  rand int unsigned num_txns;

  constraint default_num_c { num_txns inside {[10:50]}; }

  function new(string name = "mem_random_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_seq_item txn;
    `uvm_info(get_type_name(), $sformatf("Starting random sequence with %0d transactions", num_txns), UVM_MEDIUM)
    repeat (num_txns) begin
      txn = mem_seq_item::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_error(get_type_name(), "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass

//----------------------------------------------------------------------
// Walking ones sequence: writes walking-1 pattern to all addresses
//----------------------------------------------------------------------
class mem_walking_ones_seq extends mem_base_seq;
  `uvm_object_utils(mem_walking_ones_seq)

  function new(string name = "mem_walking_ones_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_seq_item wr_txn, rd_txn;

    `uvm_info(get_type_name(), "Starting walking ones sequence", UVM_MEDIUM)

    for (int i = 0; i < 8; i++) begin
      for (int a = 0; a < 16; a++) begin
        // Write walking one
        wr_txn = mem_seq_item::type_id::create("wr_txn");
        start_item(wr_txn);
        if (!wr_txn.randomize() with {
          addr  == a[3:0];
          wdata == (8'h01 << i);
          wr_en == 1;
          rd_en == 0;
        })
          `uvm_error(get_type_name(), "Randomization failed")
        finish_item(wr_txn);

        // Read back
        rd_txn = mem_seq_item::type_id::create("rd_txn");
        start_item(rd_txn);
        if (!rd_txn.randomize() with {
          addr  == a[3:0];
          wr_en == 0;
          rd_en == 1;
        })
          `uvm_error(get_type_name(), "Randomization failed")
        finish_item(rd_txn);
      end
    end
  endtask
endclass
