//----------------------------------------------------------------------
// Random Test
//
// Runs a fully random sequence of reads, writes, and idle cycles to
// stress-test the memory model.
//----------------------------------------------------------------------
class mem_random_test extends mem_base_test;
  `uvm_component_utils(mem_random_test)

  function new(string name = "mem_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_random_seq seq;

    phase.raise_objection(this, "random_test");

    seq = mem_random_seq::type_id::create("seq");
    seq.num_txns = 100;
    seq.start(m_env.m_agent.m_sequencer);

    #200;
    phase.drop_objection(this, "random_test done");
  endtask
endclass
