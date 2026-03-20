// ──────── Single write ────────
class axi_write_sequence extends uvm_sequence #(axi_lite_transaction);
  `uvm_object_utils(axi_write_sequence)

  rand bit [5:0]  addr;
  rand bit [31:0] data;
  rand bit [3:0]  strb;

  constraint c_default { strb == 4'hF; addr[1:0] == 0; }

  function new(string name = "axi_write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_transaction tx;
    tx = axi_lite_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with {
      rw    == 1;
      addr  == local::addr;
      wdata == local::data;
      wstrb == local::strb;
    };
    finish_item(tx);
  endtask
endclass

// ──────── Single read ────────
class axi_read_sequence extends uvm_sequence #(axi_lite_transaction);
  `uvm_object_utils(axi_read_sequence)

  rand bit [5:0] addr;
  constraint c_align { addr[1:0] == 0; }

  function new(string name = "axi_read_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_transaction tx;
    tx = axi_lite_transaction::type_id::create("tx");
    start_item(tx);
    tx.randomize() with {
      rw   == 0;
      addr == local::addr;
    };
    finish_item(tx);
  endtask
endclass

// ──────── Write-all-then-read-all ────────
class axi_write_read_all_sequence extends uvm_sequence #(axi_lite_transaction);
  `uvm_object_utils(axi_write_read_all_sequence)

  function new(string name = "axi_write_read_all_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_transaction tx;

    `uvm_info("SEQ", "Write all 16 registers then read them back", UVM_LOW)

    // Write unique data to every register
    for (int i = 0; i < 16; i++) begin
      tx = axi_lite_transaction::type_id::create("tx");
      start_item(tx);
      tx.randomize() with {
        rw    == 1;
        addr  == (i << 2);
        wdata == (32'hA000_0000 | i);
        wstrb == 4'hF;
      };
      finish_item(tx);
    end

    // Read back every register
    for (int i = 0; i < 16; i++) begin
      tx = axi_lite_transaction::type_id::create("tx");
      start_item(tx);
      tx.randomize() with {
        rw   == 0;
        addr == (i << 2);
      };
      finish_item(tx);
    end
  endtask
endclass

// ──────── Random read-write traffic ────────
class axi_random_sequence extends uvm_sequence #(axi_lite_transaction);
  `uvm_object_utils(axi_random_sequence)

  rand int unsigned num_txns;
  constraint c_num { num_txns inside {[50:200]}; }

  function new(string name = "axi_random_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_transaction tx;

    `uvm_info("SEQ", $sformatf("Running %0d random AXI-Lite transactions", num_txns), UVM_LOW)

    repeat(num_txns) begin
      tx = axi_lite_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// ──────── Back-to-back write-read (same address) ────────
class axi_b2b_sequence extends uvm_sequence #(axi_lite_transaction);
  `uvm_object_utils(axi_b2b_sequence)

  rand int unsigned num_pairs;
  constraint c_pairs { num_pairs inside {[10:50]}; }

  function new(string name = "axi_b2b_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_transaction wr_tx, rd_tx;

    `uvm_info("SEQ", $sformatf("Running %0d back-to-back write-read pairs", num_pairs), UVM_LOW)

    repeat(num_pairs) begin
      wr_tx = axi_lite_transaction::type_id::create("wr_tx");
      start_item(wr_tx);
      if (!wr_tx.randomize() with { rw == 1; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(wr_tx);

      rd_tx = axi_lite_transaction::type_id::create("rd_tx");
      start_item(rd_tx);
      rd_tx.randomize() with {
        rw   == 0;
        addr == wr_tx.addr;
      };
      finish_item(rd_tx);
    end
  endtask
endclass

// ──────── Full regression ────────
class axi_full_sequence extends uvm_sequence #(axi_lite_transaction);
  `uvm_object_utils(axi_full_sequence)

  function new(string name = "axi_full_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_write_read_all_sequence wr_rd_all;
    axi_b2b_sequence            b2b;
    axi_random_sequence         rand_seq;

    wr_rd_all = axi_write_read_all_sequence::type_id::create("wr_rd_all");
    wr_rd_all.start(m_sequencer);

    b2b = axi_b2b_sequence::type_id::create("b2b");
    b2b.num_pairs = 30;
    b2b.start(m_sequencer);

    rand_seq = axi_random_sequence::type_id::create("rand_seq");
    rand_seq.num_txns = 300;
    rand_seq.start(m_sequencer);
  endtask
endclass
