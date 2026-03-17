// ============================================================================
// ALU Tests — different test scenarios
// ============================================================================

// Base test — provides common setup for all ALU tests
class alu_base_test extends uvm_test;
  `uvm_component_utils(alu_base_test)

  alu_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    alu_base_sequence seq;

    phase.raise_objection(this);

    seq = alu_base_sequence::type_id::create("seq");
    seq.num_txns = 50;
    seq.start(env.agent.sequencer);

    #50;
    phase.drop_objection(this);
  endtask
endclass


// Corner case test — focuses on boundary values
class alu_corner_test extends alu_base_test;
  `uvm_component_utils(alu_corner_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_corner_case_sequence seq;

    phase.raise_objection(this);

    seq = alu_corner_case_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #50;
    phase.drop_objection(this);
  endtask
endclass


// Full test — runs directed + random sequences
class alu_full_test extends alu_base_test;
  `uvm_component_utils(alu_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_full_test_sequence seq;

    phase.raise_objection(this);

    seq = alu_full_test_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);

    #100;
    phase.drop_objection(this);
  endtask
endclass
