// ============================================================================
// FIFO Tests
// ============================================================================

// Base test
class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)

  fifo_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    fifo_random_sequence seq;

    phase.raise_objection(this);

    seq = fifo_random_sequence::type_id::create("seq");
    seq.num_txns = 100;
    seq.start(env.agent.sequencer);

    #100;
    phase.drop_objection(this);
  endtask
endclass


// Fill-drain test — tests full and empty boundary conditions
class fifo_fill_drain_test extends fifo_base_test;
  `uvm_component_utils(fifo_fill_drain_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_fill_drain_sequence seq;

    phase.raise_objection(this);

    seq = fifo_fill_drain_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #100;
    phase.drop_objection(this);
  endtask
endclass


// Full test — comprehensive FIFO testing
class fifo_full_test extends fifo_base_test;
  `uvm_component_utils(fifo_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_full_test_sequence seq;

    phase.raise_objection(this);

    seq = fifo_full_test_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #200;
    phase.drop_objection(this);
  endtask
endclass
