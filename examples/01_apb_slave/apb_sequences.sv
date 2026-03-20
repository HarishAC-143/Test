// APB Sequences — stimulus generators for different test scenarios

// Write a single transaction
class apb_single_write_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_single_write_seq)

  bit [31:0] wr_addr;
  bit [31:0] wr_data;

  function new(string name = "apb_single_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item req = apb_seq_item::type_id::create("req");
    start_item(req);
    if (!req.randomize() with {
      addr  == wr_addr;
      data  == wr_data;
      write == 1;
    }) `uvm_error("RAND", "Randomization failed")
    finish_item(req);
  endtask
endclass


// Read a single address
class apb_single_read_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_single_read_seq)

  bit [31:0] rd_addr;
  bit [31:0] rd_data;

  function new(string name = "apb_single_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item req = apb_seq_item::type_id::create("req");
    start_item(req);
    if (!req.randomize() with {
      addr  == rd_addr;
      write == 0;
    }) `uvm_error("RAND", "Randomization failed")
    finish_item(req);
    rd_data = req.rdata;
  endtask
endclass


// Write N random transactions
class apb_random_write_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_random_write_seq)

  int num_writes = 10;

  function new(string name = "apb_random_write_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_writes) begin
      apb_seq_item req = apb_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { write == 1; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass


// Write-then-Read-back sequence: writes random data, then reads
// it back to verify correctness
class apb_write_read_back_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_write_read_back_seq)

  int num_pairs = 10;

  function new(string name = "apb_write_read_back_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] addresses[$];
    bit [31:0] expected_data[$];

    // Phase 1: Write random data to random addresses
    repeat (num_pairs) begin
      apb_seq_item wr = apb_seq_item::type_id::create("wr");
      start_item(wr);
      if (!wr.randomize() with { write == 1; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(wr);
      addresses.push_back(wr.addr);
      expected_data.push_back(wr.data);
    end

    // Phase 2: Read back and check (scoreboard will verify)
    foreach (addresses[i]) begin
      apb_seq_item rd = apb_seq_item::type_id::create("rd");
      start_item(rd);
      if (!rd.randomize() with {
        addr  == addresses[i];
        write == 0;
      }) `uvm_error("RAND", "Randomization failed")
      finish_item(rd);
      `uvm_info("SEQ", $sformatf("Read-back addr=0x%08h expected=0x%08h got=0x%08h %s",
                addresses[i], expected_data[i], rd.rdata,
                (rd.rdata == expected_data[i]) ? "OK" : "MISMATCH"), UVM_MEDIUM)
    end
  endtask
endclass


// Walking-ones address test: exercises each address bit individually
class apb_walking_ones_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_walking_ones_seq)

  function new(string name = "apb_walking_ones_seq");
    super.new(name);
  endfunction

  task body();
    for (int bit_pos = 2; bit_pos < 10; bit_pos++) begin
      bit [31:0] test_addr = (1 << bit_pos);
      bit [31:0] test_data = 32'hDEAD_0000 | bit_pos;

      // Write
      begin
        apb_seq_item wr = apb_seq_item::type_id::create("wr");
        start_item(wr);
        if (!wr.randomize() with {
          addr  == test_addr;
          data  == test_data;
          write == 1;
        }) `uvm_error("RAND", "Randomization failed")
        finish_item(wr);
      end

      // Read back
      begin
        apb_seq_item rd = apb_seq_item::type_id::create("rd");
        start_item(rd);
        if (!rd.randomize() with {
          addr  == test_addr;
          write == 0;
        }) `uvm_error("RAND", "Randomization failed")
        finish_item(rd);
      end
    end
  endtask
endclass
