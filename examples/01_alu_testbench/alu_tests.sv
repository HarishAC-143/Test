class alu_base_test extends uvm_test;
  `uvm_component_utils(alu_base_test)

  alu_env env;

  function new(string name = "alu_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    alu_random_sequence seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== ALU Base Test: Random Stimulus ===", UVM_LOW)
    seq = alu_random_sequence::type_id::create("seq");
    seq.num_txns = 100;
    seq.start(env.agent.sqr);

    #100;  // drain time
    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
endclass

class alu_directed_test extends alu_base_test;
  `uvm_component_utils(alu_directed_test)

  function new(string name = "alu_directed_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_directed_sequence dir_seq;
    alu_all_ops_sequence  ops_seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== ALU Directed Test ===", UVM_LOW)

    `uvm_info("TEST", "Phase 1: Corner cases", UVM_LOW)
    dir_seq = alu_directed_sequence::type_id::create("dir_seq");
    dir_seq.start(env.agent.sqr);

    `uvm_info("TEST", "Phase 2: All operations with random data", UVM_LOW)
    ops_seq = alu_all_ops_sequence::type_id::create("ops_seq");
    ops_seq.start(env.agent.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass

class alu_stress_test extends alu_base_test;
  `uvm_component_utils(alu_stress_test)

  function new(string name = "alu_stress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_random_sequence seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== ALU Stress Test: 5000 random transactions ===", UVM_LOW)
    seq = alu_random_sequence::type_id::create("seq");
    seq.num_txns = 5000;
    seq.start(env.agent.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass
