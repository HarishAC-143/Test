//----------------------------------------------------------------------
// Write-Read Test
//
// Runs the write-read sequence to verify basic memory write and
// readback functionality.
//----------------------------------------------------------------------
class mem_write_read_test extends mem_base_test;
  `uvm_component_utils(mem_write_read_test)

  function new(string name = "mem_write_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_write_read_seq seq;

    phase.raise_objection(this, "write_read_test");

    seq = mem_write_read_seq::type_id::create("seq");
    seq.num_txns = 16;
    seq.start(m_env.m_agent.m_sequencer);

    #200;
    phase.drop_objection(this, "write_read_test done");
  endtask
endclass
