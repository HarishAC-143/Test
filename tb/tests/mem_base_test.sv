//----------------------------------------------------------------------
// Memory Base Test
//
// Base UVM test that builds the environment, sets config_db entries,
// and provides common phase implementations.  All specific tests
// extend this class.
//----------------------------------------------------------------------
class mem_base_test extends uvm_test;
  `uvm_component_utils(mem_base_test)

  mem_env               m_env;
  mem_virtual_sequencer m_vseqr;

  function new(string name = "mem_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Set agent to active mode
    uvm_config_db#(uvm_active_passive_enum)::set(this, "m_env.m_agent", "is_active", UVM_ACTIVE);

    m_env  = mem_env::type_id::create("m_env", this);
    m_vseqr = mem_virtual_sequencer::type_id::create("m_vseqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_vseqr.m_mem_seqr = m_env.m_agent.m_sequencer;
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this, "Base test running");
    #100;
    phase.drop_objection(this, "Base test done");
  endtask
endclass
