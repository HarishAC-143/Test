// ============================================================================
// Memory Tests
// ============================================================================

// Base test — random reads and writes
class mem_base_test extends uvm_test;
  `uvm_component_utils(mem_base_test)

  mem_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mem_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    mem_random_sequence seq;

    phase.raise_objection(this);

    seq = mem_random_sequence::type_id::create("seq");
    seq.num_txns = 50;
    seq.start(env.agent.sequencer);

    #100;
    phase.drop_objection(this);
  endtask
endclass


// Write-read test — focused data integrity check
class mem_write_read_test extends mem_base_test;
  `uvm_component_utils(mem_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_write_read_sequence seq;

    phase.raise_objection(this);

    seq = mem_write_read_sequence::type_id::create("seq");
    seq.num_locations = 16;
    seq.base_addr     = 8'h00;
    seq.start(env.agent.sequencer);

    #100;
    phase.drop_objection(this);
  endtask
endclass


// Full test — comprehensive memory testing
class mem_full_test extends mem_base_test;
  `uvm_component_utils(mem_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_full_test_sequence seq;

    phase.raise_objection(this);

    seq = mem_full_test_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #200;
    phase.drop_objection(this);
  endtask
endclass
