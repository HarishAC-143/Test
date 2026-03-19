//----------------------------------------------------------------------
// Walking Ones Test
//
// Runs the walking ones pattern across all addresses to detect
// stuck-at faults in the memory data bits.
//----------------------------------------------------------------------
class mem_walking_ones_test extends mem_base_test;
  `uvm_component_utils(mem_walking_ones_test)

  function new(string name = "mem_walking_ones_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_walking_ones_seq seq;

    phase.raise_objection(this, "walking_ones_test");

    seq = mem_walking_ones_seq::type_id::create("seq");
    seq.start(m_env.m_agent.m_sequencer);

    #200;
    phase.drop_objection(this, "walking_ones_test done");
  endtask
endclass
