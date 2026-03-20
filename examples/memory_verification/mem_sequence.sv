// Base sequence — random read/write operations
class mem_base_sequence extends uvm_sequence #(mem_txn);

  `uvm_object_utils(mem_base_sequence)

  rand int unsigned num_txns;

  constraint defaults {
    num_txns inside {[100:300]};
  }

  function new(string name = "mem_base_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn;
    `uvm_info("SEQ", $sformatf("Running %0d random memory operations", num_txns), UVM_LOW)

    for (int i = 0; i < num_txns; i++) begin
      txn = mem_txn::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask

endclass


// Write-then-Read sequence — writes every address, then reads back
class mem_write_read_sequence extends uvm_sequence #(mem_txn);

  `uvm_object_utils(mem_write_read_sequence)

  function new(string name = "mem_write_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn;
    bit [7:0] expected_data [256];

    `uvm_info("SEQ", "Writing all 256 addresses, then reading back", UVM_LOW)

    // Phase 1: Write to every address
    for (int i = 0; i < 256; i++) begin
      expected_data[i] = i[7:0] ^ 8'hA5;  // known pattern

      txn = mem_txn::type_id::create($sformatf("wr_%0d", i));
      start_item(txn);
      txn.op    = MEM_WRITE;
      txn.addr  = i[7:0];
      txn.wdata = expected_data[i];
      finish_item(txn);
    end

    `uvm_info("SEQ", "All writes complete. Starting read-back.", UVM_MEDIUM)

    // Phase 2: Read from every address
    for (int i = 0; i < 256; i++) begin
      txn = mem_txn::type_id::create($sformatf("rd_%0d", i));
      start_item(txn);
      txn.op   = MEM_READ;
      txn.addr = i[7:0];
      finish_item(txn);
    end

    `uvm_info("SEQ", "Write-read-back sequence complete", UVM_LOW)
  endtask

endclass


// Boundary sequence — tests address boundaries and corner cases
class mem_boundary_sequence extends uvm_sequence #(mem_txn);

  `uvm_object_utils(mem_boundary_sequence)

  function new(string name = "mem_boundary_sequence");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SEQ", "Testing boundary addresses", UVM_LOW)

    // Test address 0x00
    write_then_read(8'h00, 8'hFF);
    write_then_read(8'h00, 8'h00);

    // Test address 0xFF (last address)
    write_then_read(8'hFF, 8'hAA);
    write_then_read(8'hFF, 8'h55);

    // Test address 0x80 (MSB boundary)
    write_then_read(8'h80, 8'h12);

    // Test with all-ones data
    write_then_read(8'h01, 8'hFF);

    // Test with all-zeros data
    write_then_read(8'h01, 8'h00);

    // Test overwrite: write different values to same address
    write_then_read(8'h42, 8'hAA);
    write_then_read(8'h42, 8'h55);
    write_then_read(8'h42, 8'h00);

    `uvm_info("SEQ", "Boundary test complete", UVM_LOW)
  endtask

  task write_then_read(bit [7:0] addr, bit [7:0] data);
    mem_txn wr_txn, rd_txn;

    // Write
    wr_txn = mem_txn::type_id::create("wr_txn");
    start_item(wr_txn);
    wr_txn.op    = MEM_WRITE;
    wr_txn.addr  = addr;
    wr_txn.wdata = data;
    finish_item(wr_txn);

    // Read
    rd_txn = mem_txn::type_id::create("rd_txn");
    start_item(rd_txn);
    rd_txn.op   = MEM_READ;
    rd_txn.addr = addr;
    finish_item(rd_txn);
  endtask

endclass
