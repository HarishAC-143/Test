//----------------------------------------------------------------------
// Virtual Sequence Test
//
// Demonstrates virtual sequences: runs the comprehensive virtual
// sequence that combines directed, walking-ones, and random patterns.
//----------------------------------------------------------------------
class mem_virtual_seq_test extends mem_base_test;
  `uvm_component_utils(mem_virtual_seq_test)

  function new(string name = "mem_virtual_seq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_comprehensive_vseq vseq;

    phase.raise_objection(this, "virtual_seq_test");

    vseq = mem_comprehensive_vseq::type_id::create("vseq");
    vseq.start(m_vseqr);

    #200;
    phase.drop_objection(this, "virtual_seq_test done");
  endtask
endclass

//----------------------------------------------------------------------
// Sequential Virtual Sequence Test
//----------------------------------------------------------------------
class mem_sequential_vseq_test extends mem_base_test;
  `uvm_component_utils(mem_sequential_vseq_test)

  function new(string name = "mem_sequential_vseq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_sequential_vseq vseq;

    phase.raise_objection(this, "sequential_vseq_test");

    vseq = mem_sequential_vseq::type_id::create("vseq");
    vseq.start(m_vseqr);

    #200;
    phase.drop_objection(this, "sequential_vseq_test done");
  endtask
endclass

//----------------------------------------------------------------------
// Parallel Virtual Sequence Test
//----------------------------------------------------------------------
class mem_parallel_vseq_test extends mem_base_test;
  `uvm_component_utils(mem_parallel_vseq_test)

  function new(string name = "mem_parallel_vseq_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_parallel_vseq vseq;

    phase.raise_objection(this, "parallel_vseq_test");

    vseq = mem_parallel_vseq::type_id::create("vseq");
    vseq.start(m_vseqr);

    #200;
    phase.drop_objection(this, "parallel_vseq_test done");
  endtask
endclass
