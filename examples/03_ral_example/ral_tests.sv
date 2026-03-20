class ral_base_test extends uvm_test;
  `uvm_component_utils(ral_base_test)

  ral_env env;

  function new(string name = "ral_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ral_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    super.report_phase(phase);
    if (srv.get_severity_count(UVM_ERROR) > 0 || srv.get_severity_count(UVM_FATAL) > 0)
      `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction
endclass

// Test: Verify register reset values using built-in UVM sequence
class ral_reset_test extends ral_base_test;
  `uvm_component_utils(ral_reset_test)

  function new(string name = "ral_reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_reg_hw_reset_seq reset_seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== RAL Reset Value Test ===", UVM_LOW)
    reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
    reset_seq.model = env.reg_model;
    reset_seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass

// Test: Read-write verification
class ral_rw_test extends ral_base_test;
  `uvm_component_utils(ral_rw_test)

  function new(string name = "ral_rw_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ral_rw_sequence rw_seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== RAL Read-Write Test ===", UVM_LOW)
    rw_seq = ral_rw_sequence::type_id::create("rw_seq");
    rw_seq.reg_model = env.reg_model;
    rw_seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass

// Test: Bit-bash using built-in UVM sequence
class ral_bit_bash_test extends ral_base_test;
  `uvm_component_utils(ral_bit_bash_test)

  function new(string name = "ral_bit_bash_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_reg_bit_bash_seq bash_seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== RAL Bit-Bash Test ===", UVM_LOW)
    bash_seq = uvm_reg_bit_bash_seq::type_id::create("bash_seq");
    bash_seq.model = env.reg_model;
    bash_seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass

// Test: Functional operations
class ral_functional_test extends ral_base_test;
  `uvm_component_utils(ral_functional_test)

  function new(string name = "ral_functional_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ral_functional_sequence func_seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== RAL Functional Test ===", UVM_LOW)
    func_seq = ral_functional_sequence::type_id::create("func_seq");
    func_seq.reg_model = env.reg_model;
    func_seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass
