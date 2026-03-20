// Single write then read-back sequence
class apb_write_read_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_write_read_seq)

  rand bit [7:0]  addr;
  rand bit [31:0] data;

  constraint c_word_aligned { addr[1:0] == 2'b00; }
  constraint c_addr_range   { addr < 8'hFC; }

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item wr_item, rd_item;

    // Write
    wr_item = apb_seq_item::type_id::create("wr_item");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      direction == APB_WRITE;
      addr      == local::addr;
      wdata     == local::data;
      size      == APB_WORD;
      delay     == 0;
    })
      `uvm_error("SEQ", "Write randomization failed")
    finish_item(wr_item);

    // Read back
    rd_item = apb_seq_item::type_id::create("rd_item");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      direction == APB_READ;
      addr      == local::addr;
      size      == APB_WORD;
      delay     == 0;
    })
      `uvm_error("SEQ", "Read randomization failed")
    finish_item(rd_item);
  endtask
endclass

// Random read/write sequence
class apb_random_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_random_seq)

  rand int num_txns;
  constraint c_num { num_txns inside {[50:500]}; }

  function new(string name = "apb_random_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item tx;
    `uvm_info("SEQ", $sformatf("Running %0d random APB transactions", num_txns), UVM_LOW)
    repeat(num_txns) begin
      tx = apb_seq_item::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize())
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Write-then-read-all sequence — writes to multiple addresses then reads all back
class apb_write_then_read_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_write_then_read_seq)

  int num_addresses = 16;

  function new(string name = "apb_write_then_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item tx;

    `uvm_info("SEQ", $sformatf("Writing to %0d addresses", num_addresses), UVM_LOW)
    for (int i = 0; i < num_addresses; i++) begin
      tx = apb_seq_item::type_id::create("wr_tx");
      start_item(tx);
      if (!tx.randomize() with {
        direction == APB_WRITE;
        addr      == (i * 4);
        size      == APB_WORD;
        delay     == 0;
      })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end

    `uvm_info("SEQ", "Reading back all addresses", UVM_LOW)
    for (int i = 0; i < num_addresses; i++) begin
      tx = apb_seq_item::type_id::create("rd_tx");
      start_item(tx);
      if (!tx.randomize() with {
        direction == APB_READ;
        addr      == (i * 4);
        size      == APB_WORD;
        delay     == 0;
      })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Back-to-back sequence — no idle cycles between transactions
class apb_back2back_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_back2back_seq)

  rand int num_txns;
  constraint c_num { num_txns inside {[20:100]}; }

  function new(string name = "apb_back2back_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item tx;
    `uvm_info("SEQ", $sformatf("Running %0d back-to-back transactions", num_txns), UVM_LOW)
    repeat(num_txns) begin
      tx = apb_seq_item::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { delay == 0; })
        `uvm_error("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass

// Boundary address test
class apb_boundary_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_boundary_seq)

  function new(string name = "apb_boundary_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item tx;
    bit [7:0] test_addrs[] = '{8'h00, 8'h04, 8'h08, 8'hF8, 8'hFC};

    `uvm_info("SEQ", "Testing boundary addresses", UVM_LOW)
    foreach (test_addrs[i]) begin
      // Write
      tx = apb_seq_item::type_id::create("wr_tx");
      start_item(tx);
      tx.direction = APB_WRITE;
      tx.addr      = test_addrs[i];
      tx.wdata     = 32'hA5A5_0000 + i;
      tx.strb      = 4'b1111;
      tx.size      = APB_WORD;
      tx.delay     = 0;
      finish_item(tx);

      // Read back
      tx = apb_seq_item::type_id::create("rd_tx");
      start_item(tx);
      tx.direction = APB_READ;
      tx.addr      = test_addrs[i];
      tx.strb      = 4'b1111;
      tx.size      = APB_WORD;
      tx.delay     = 0;
      finish_item(tx);
    end
  endtask
endclass
