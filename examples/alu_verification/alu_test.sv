// Base test — creates environment and runs a random sequence
class alu_base_test extends uvm_test;

  `uvm_component_utils(alu_base_test)

  alu_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_base_sequence seq;

    phase.raise_objection(this, "alu_base_test: starting sequence");

    seq = alu_base_sequence::type_id::create("seq");
    seq.num_txns = 100;
    seq.start(env.agt.sqr);

    #100;  // drain time

    phase.drop_objection(this, "alu_base_test: sequence complete");
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    super.report_phase(phase);
    if (srv.get_severity_count(UVM_ERROR) > 0)
      `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction

endclass


// ADD-focused test — tests addition operations with corner cases
class alu_add_test extends alu_base_test;

  `uvm_component_utils(alu_add_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_add_sequence seq;

    phase.raise_objection(this, "alu_add_test: starting ADD sequence");

    seq = alu_add_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #100;

    phase.drop_objection(this, "alu_add_test: ADD sequence complete");
  endtask

endclass


// Exhaustive test — tests all operations systematically
class alu_exhaustive_test extends alu_base_test;

  `uvm_component_utils(alu_exhaustive_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_exhaustive_sequence seq;

    phase.raise_objection(this, "alu_exhaustive_test: starting exhaustive sequence");

    seq = alu_exhaustive_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #100;

    phase.drop_objection(this, "alu_exhaustive_test: exhaustive sequence complete");
  endtask

endclass
