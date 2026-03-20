// Base test — random read/write operations
class mem_base_test extends uvm_test;

  `uvm_component_utils(mem_base_test)

  mem_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mem_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_base_sequence seq;

    phase.raise_objection(this);

    seq = mem_base_sequence::type_id::create("seq");
    seq.num_txns = 200;
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
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


// Write-Read test — write every address, then read back
class mem_write_read_test extends mem_base_test;

  `uvm_component_utils(mem_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_write_read_sequence seq;

    phase.raise_objection(this);

    seq = mem_write_read_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
  endtask

endclass


// Boundary test — tests edge addresses and data patterns
class mem_boundary_test extends mem_base_test;

  `uvm_component_utils(mem_boundary_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_boundary_sequence seq;

    phase.raise_objection(this);

    seq = mem_boundary_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
  endtask

endclass
