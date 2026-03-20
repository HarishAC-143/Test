// FIFO Sequences

// Fill the FIFO completely
class fifo_fill_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_fill_seq)

  int fill_count = 16;

  function new(string name = "fifo_fill_seq");
    super.new(name);
  endfunction

  task body();
    repeat (fill_count) begin
      fifo_seq_item req = fifo_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { wr_en == 1; rd_en == 0; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass


// Drain the FIFO completely
class fifo_drain_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_drain_seq)

  int drain_count = 16;

  function new(string name = "fifo_drain_seq");
    super.new(name);
  endfunction

  task body();
    repeat (drain_count) begin
      fifo_seq_item req = fifo_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { wr_en == 0; rd_en == 1; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass


// Random mix of reads and writes
class fifo_random_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_random_seq)

  int num_transactions = 100;

  function new(string name = "fifo_random_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_transactions) begin
      fifo_seq_item req = fifo_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize())
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass


// Fill-then-drain sequence: exercises full/empty transitions
class fifo_fill_drain_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_fill_drain_seq)

  int depth = 16;

  function new(string name = "fifo_fill_drain_seq");
    super.new(name);
  endfunction

  task body();
    fifo_fill_seq  fill  = fifo_fill_seq::type_id::create("fill");
    fifo_drain_seq drain = fifo_drain_seq::type_id::create("drain");

    `uvm_info("SEQ", "Phase 1: Filling FIFO to capacity", UVM_LOW)
    fill.fill_count = depth;
    fill.start(m_sequencer);

    `uvm_info("SEQ", "Phase 2: Draining FIFO completely", UVM_LOW)
    drain.drain_count = depth;
    drain.start(m_sequencer);

    `uvm_info("SEQ", "Fill-drain cycle complete", UVM_LOW)
  endtask
endclass


// Overflow test: attempt to write beyond capacity
class fifo_overflow_seq extends uvm_sequence #(fifo_seq_item);
  `uvm_object_utils(fifo_overflow_seq)

  int depth = 16;

  function new(string name = "fifo_overflow_seq");
    super.new(name);
  endfunction

  task body();
    fifo_fill_seq fill = fifo_fill_seq::type_id::create("fill");

    // Fill to capacity
    fill.fill_count = depth;
    fill.start(m_sequencer);

    // Attempt additional writes (should be ignored by DUT)
    repeat (5) begin
      fifo_seq_item req = fifo_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { wr_en == 1; rd_en == 0; })
        `uvm_error("RAND", "Randomization failed")
      finish_item(req);
      `uvm_info("SEQ", "Attempted write to full FIFO", UVM_MEDIUM)
    end
  endtask
endclass
