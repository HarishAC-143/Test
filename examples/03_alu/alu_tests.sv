// ALU Tests

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
    uvm_top.print_topology();
  endfunction

  function void report_phase(uvm_phase phase);
    uvm_report_server svr = uvm_report_server::get_server();
    if (svr.get_severity_count(UVM_ERROR) > 0)
      `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction
endclass


// Fully random test
class alu_random_test extends alu_base_test;
  `uvm_component_utils(alu_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_random_seq seq;
    phase.raise_objection(this);

    seq = alu_random_seq::type_id::create("seq");
    seq.num_operations = 500;
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass


// Corner-case test focusing on boundary values
class alu_corner_case_test extends alu_base_test;
  `uvm_component_utils(alu_corner_case_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_corner_case_seq seq;
    phase.raise_objection(this);

    seq = alu_corner_case_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass


// All operations sweep
class alu_all_ops_test extends alu_base_test;
  `uvm_component_utils(alu_all_ops_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_all_ops_seq seq;
    phase.raise_objection(this);

    seq = alu_all_ops_seq::type_id::create("seq");
    seq.ops_per_opcode = 30;
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass


// Shift operations focused test
class alu_shift_test extends alu_base_test;
  `uvm_component_utils(alu_shift_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_shift_seq seq;
    phase.raise_objection(this);

    seq = alu_shift_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass


// Comprehensive test: runs all sequences for full coverage
class alu_comprehensive_test extends alu_base_test;
  `uvm_component_utils(alu_comprehensive_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    begin
      alu_corner_case_seq cc_seq = alu_corner_case_seq::type_id::create("cc_seq");
      `uvm_info("TEST", "Running corner-case sequence", UVM_LOW)
      cc_seq.start(env.agent.sqr);
    end

    begin
      alu_shift_seq sh_seq = alu_shift_seq::type_id::create("sh_seq");
      `uvm_info("TEST", "Running shift sequence", UVM_LOW)
      sh_seq.start(env.agent.sqr);
    end

    begin
      alu_all_ops_seq all_seq = alu_all_ops_seq::type_id::create("all_seq");
      `uvm_info("TEST", "Running all-operations sequence", UVM_LOW)
      all_seq.start(env.agent.sqr);
    end

    begin
      alu_random_seq rand_seq = alu_random_seq::type_id::create("rand_seq");
      rand_seq.num_operations = 300;
      `uvm_info("TEST", "Running random sequence", UVM_LOW)
      rand_seq.start(env.agent.sqr);
    end

    phase.drop_objection(this);
  endtask
endclass
