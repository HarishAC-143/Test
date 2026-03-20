// Base sequence — random AXI-Lite read/write operations
class axi_lite_base_sequence extends uvm_sequence #(axi_lite_txn);

  `uvm_object_utils(axi_lite_base_sequence)

  rand int unsigned num_txns;

  constraint defaults {
    num_txns inside {[20:100]};
  }

  function new(string name = "axi_lite_base_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_txn txn;
    `uvm_info("SEQ", $sformatf("Running %0d random AXI-Lite transactions", num_txns), UVM_LOW)

    for (int i = 0; i < num_txns; i++) begin
      txn = axi_lite_txn::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask

endclass


// Register test sequence — write each register, then read back
class axi_lite_reg_sequence extends uvm_sequence #(axi_lite_txn);

  `uvm_object_utils(axi_lite_reg_sequence)

  function new(string name = "axi_lite_reg_sequence");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] test_values [4] = '{32'hDEAD_BEEF, 32'hCAFE_BABE, 32'h1234_5678, 32'hA5A5_5A5A};
    bit [31:0] addrs [4]       = '{32'h00, 32'h04, 32'h08, 32'h0C};

    `uvm_info("SEQ", "Register write/read-back test", UVM_LOW)

    // Write all registers
    for (int i = 0; i < 4; i++) begin
      axi_write(addrs[i], test_values[i]);
    end

    // Read all registers back
    for (int i = 0; i < 4; i++) begin
      axi_read(addrs[i]);
    end

    // Overwrite with inverted values
    for (int i = 0; i < 4; i++) begin
      axi_write(addrs[i], ~test_values[i]);
    end

    // Read back inverted values
    for (int i = 0; i < 4; i++) begin
      axi_read(addrs[i]);
    end

    // Write zeros
    for (int i = 0; i < 4; i++) begin
      axi_write(addrs[i], 32'h0);
    end

    // Verify zeros
    for (int i = 0; i < 4; i++) begin
      axi_read(addrs[i]);
    end

    `uvm_info("SEQ", "Register test complete", UVM_LOW)
  endtask

  task axi_write(bit [31:0] addr, bit [31:0] data);
    axi_lite_txn txn = axi_lite_txn::type_id::create("wr_txn");
    start_item(txn);
    txn.dir  = AXI_WRITE;
    txn.addr = addr;
    txn.data = data;
    txn.strb = 4'b1111;
    finish_item(txn);
  endtask

  task axi_read(bit [31:0] addr);
    axi_lite_txn txn = axi_lite_txn::type_id::create("rd_txn");
    start_item(txn);
    txn.dir  = AXI_READ;
    txn.addr = addr;
    finish_item(txn);
  endtask

endclass


// Stress sequence — high-volume random traffic
class axi_lite_stress_sequence extends uvm_sequence #(axi_lite_txn);

  `uvm_object_utils(axi_lite_stress_sequence)

  function new(string name = "axi_lite_stress_sequence");
    super.new(name);
  endfunction

  virtual task body();
    axi_lite_txn txn;
    `uvm_info("SEQ", "Starting stress test (500 transactions)", UVM_LOW)

    for (int i = 0; i < 500; i++) begin
      txn = axi_lite_txn::type_id::create($sformatf("stress_%0d", i));
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end

    `uvm_info("SEQ", "Stress test complete", UVM_LOW)
  endtask

endclass
