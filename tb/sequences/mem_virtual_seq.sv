//----------------------------------------------------------------------
// Virtual Sequences and Virtual Sequencer
//
// Demonstrates virtual sequences running sub-sequences both
// sequentially and in parallel, and drive-to-sequence feedback.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Virtual Sequencer: holds handles to real sequencers
//----------------------------------------------------------------------
class mem_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(mem_virtual_sequencer)

  mem_sequencer m_mem_seqr;

  function new(string name = "mem_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

//----------------------------------------------------------------------
// Sequential virtual sequence: runs write then read in order
//----------------------------------------------------------------------
class mem_sequential_vseq extends uvm_sequence;
  `uvm_object_utils(mem_sequential_vseq)
  `uvm_declare_p_sequencer(mem_virtual_sequencer)

  function new(string name = "mem_sequential_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mem_write_seq      wr_seq;
    mem_read_seq       rd_seq;
    mem_write_read_seq wr_rd_seq;

    `uvm_info(get_type_name(), "Running sequential virtual sequence", UVM_MEDIUM)

    // Phase 1: writes
    wr_seq = mem_write_seq::type_id::create("wr_seq");
    wr_seq.num_txns = 16;
    wr_seq.start(p_sequencer.m_mem_seqr);

    // Phase 2: reads
    rd_seq = mem_read_seq::type_id::create("rd_seq");
    rd_seq.num_txns = 16;
    rd_seq.start(p_sequencer.m_mem_seqr);

    // Phase 3: write-read pairs
    wr_rd_seq = mem_write_read_seq::type_id::create("wr_rd_seq");
    wr_rd_seq.num_txns = 8;
    wr_rd_seq.start(p_sequencer.m_mem_seqr);
  endtask
endclass

//----------------------------------------------------------------------
// Parallel virtual sequence: runs multiple sequences concurrently
//----------------------------------------------------------------------
class mem_parallel_vseq extends uvm_sequence;
  `uvm_object_utils(mem_parallel_vseq)
  `uvm_declare_p_sequencer(mem_virtual_sequencer)

  function new(string name = "mem_parallel_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mem_random_seq rand_seq1, rand_seq2;

    `uvm_info(get_type_name(), "Running parallel virtual sequence", UVM_MEDIUM)

    rand_seq1 = mem_random_seq::type_id::create("rand_seq1");
    rand_seq2 = mem_random_seq::type_id::create("rand_seq2");

    rand_seq1.num_txns = 20;
    rand_seq2.num_txns = 20;

    fork
      rand_seq1.start(p_sequencer.m_mem_seqr);
      rand_seq2.start(p_sequencer.m_mem_seqr);
    join
  endtask
endclass

//----------------------------------------------------------------------
// Comprehensive virtual sequence: combines all test patterns
//----------------------------------------------------------------------
class mem_comprehensive_vseq extends uvm_sequence;
  `uvm_object_utils(mem_comprehensive_vseq)
  `uvm_declare_p_sequencer(mem_virtual_sequencer)

  function new(string name = "mem_comprehensive_vseq");
    super.new(name);
  endfunction

  virtual task body();
    mem_write_read_seq   wr_rd_seq;
    mem_walking_ones_seq walk_seq;
    mem_random_seq       rand_seq;

    `uvm_info(get_type_name(), "Running comprehensive virtual sequence", UVM_MEDIUM)

    // Directed write-read test
    wr_rd_seq = mem_write_read_seq::type_id::create("wr_rd_seq");
    wr_rd_seq.num_txns = 16;
    wr_rd_seq.start(p_sequencer.m_mem_seqr);

    // Walking ones pattern
    walk_seq = mem_walking_ones_seq::type_id::create("walk_seq");
    walk_seq.start(p_sequencer.m_mem_seqr);

    // Random stress
    rand_seq = mem_random_seq::type_id::create("rand_seq");
    rand_seq.num_txns = 50;
    rand_seq.start(p_sequencer.m_mem_seqr);
  endtask
endclass
