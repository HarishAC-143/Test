// Base test — random AXI-Lite transactions
class axi_lite_base_test extends uvm_test;

  `uvm_component_utils(axi_lite_base_test)

  axi_lite_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_lite_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_lite_base_sequence seq;

    phase.raise_objection(this);

    seq = axi_lite_base_sequence::type_id::create("seq");
    seq.num_txns = 50;
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


// Register test — write and read back all registers
class axi_lite_reg_test extends axi_lite_base_test;

  `uvm_component_utils(axi_lite_reg_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_lite_reg_sequence seq;

    phase.raise_objection(this);

    seq = axi_lite_reg_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
  endtask

endclass


// Stress test — high-volume random traffic
class axi_lite_stress_test extends axi_lite_base_test;

  `uvm_component_utils(axi_lite_stress_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_lite_stress_sequence seq;

    phase.raise_objection(this);

    seq = axi_lite_stress_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #500;
    phase.drop_objection(this);
  endtask

endclass
