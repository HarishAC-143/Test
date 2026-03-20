// ──────── Write-then-read-back sequence ────────
class mem_write_read_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_write_read_sequence)

  rand int unsigned num_addrs;
  constraint c_num { num_addrs inside {[10:50]}; }

  function new(string name = "mem_write_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction tx;
    bit [7:0] addrs[$];

    `uvm_info("SEQ", $sformatf("Write-then-read-back for %0d addresses", num_addrs), UVM_LOW)

    // Phase 1: Write random data to random addresses
    repeat(num_addrs) begin
      tx = mem_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { we == 1; re == 0; be == 4'hF; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
      addrs.push_back(tx.addr);
    end

    // Phase 2: Read back from every address we wrote
    foreach (addrs[i]) begin
      tx = mem_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { we == 0; re == 1; addr == addrs[i]; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Byte-enable test sequence ────────
class mem_byte_enable_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_byte_enable_sequence)

  function new(string name = "mem_byte_enable_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction tx;
    bit [7:0] test_addr = 8'h10;

    `uvm_info("SEQ", "Byte-enable test sequence", UVM_LOW)

    // Write full word: 0xDEADBEEF
    tx = mem_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with {
      addr  == test_addr;
      wdata == 32'hDEAD_BEEF;
      we    == 1;
      re    == 0;
      be    == 4'hF;
    };
    finish_item(tx);

    // Overwrite only byte 0 with 0x42
    tx = mem_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with {
      addr  == test_addr;
      wdata == 32'h0000_0042;
      we    == 1;
      re    == 0;
      be    == 4'h1;
    };
    finish_item(tx);

    // Read back -- should be 0xDEADBE42
    tx = mem_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { addr == test_addr; we == 0; re == 1; };
    finish_item(tx);

    // Overwrite bytes 2-3 with 0xCAFE
    tx = mem_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with {
      addr  == test_addr;
      wdata == 32'hCAFE_0000;
      we    == 1;
      re    == 0;
      be    == 4'hC;
    };
    finish_item(tx);

    // Read back -- should be 0xCAFEBE42
    tx = mem_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with { addr == test_addr; we == 0; re == 1; };
    finish_item(tx);
  endtask
endclass

// ──────── Random stress sequence ────────
class mem_random_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_random_sequence)

  rand int unsigned num_txns;
  constraint c_num { num_txns inside {[100:500]}; }

  function new(string name = "mem_random_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction tx;
    `uvm_info("SEQ", $sformatf("Running %0d random memory transactions", num_txns), UVM_LOW)

    repeat(num_txns) begin
      tx = mem_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Walking ones sequence ────────
class mem_walking_ones_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_walking_ones_sequence)

  function new(string name = "mem_walking_ones_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_transaction tx;

    `uvm_info("SEQ", "Walking ones pattern test", UVM_LOW)

    for (int i = 0; i < 32; i++) begin
      // Write walking-1 pattern
      tx = mem_transaction::type_id::create("tx");
      start_item(tx);
      tx.randomize() with {
        addr  == i;
        wdata == (32'h1 << i);
        we    == 1;
        re    == 0;
        be    == 4'hF;
      };
      finish_item(tx);

      // Read back immediately
      tx = mem_transaction::type_id::create("tx");
      start_item(tx);
      tx.randomize() with {
        addr == i;
        we   == 0;
        re   == 1;
      };
      finish_item(tx);
    end
  endtask
endclass

// ──────── Full regression sequence ────────
class mem_full_sequence extends uvm_sequence #(mem_transaction);
  `uvm_object_utils(mem_full_sequence)

  function new(string name = "mem_full_sequence");
    super.new(name);
  endfunction

  virtual task body();
    mem_walking_ones_sequence  walk_seq;
    mem_byte_enable_sequence   be_seq;
    mem_write_read_sequence    wr_rd_seq;
    mem_random_sequence        rand_seq;

    walk_seq = mem_walking_ones_sequence::type_id::create("walk_seq");
    walk_seq.start(m_sequencer);

    be_seq = mem_byte_enable_sequence::type_id::create("be_seq");
    be_seq.start(m_sequencer);

    wr_rd_seq = mem_write_read_sequence::type_id::create("wr_rd_seq");
    wr_rd_seq.start(m_sequencer);

    rand_seq = mem_random_sequence::type_id::create("rand_seq");
    rand_seq.num_txns = 300;
    rand_seq.start(m_sequencer);
  endtask
endclass
