// FIFO Tests

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


// Fill-then-drain test
class fifo_fill_drain_test extends fifo_base_test;
  `uvm_component_utils(fifo_fill_drain_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_fill_drain_seq seq;
    phase.raise_objection(this);

    seq = fifo_fill_drain_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass


// Random operations test
class fifo_random_test extends fifo_base_test;
  `uvm_component_utils(fifo_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_random_seq seq;
    phase.raise_objection(this);

    seq = fifo_random_seq::type_id::create("seq");
    seq.num_transactions = 200;
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass


// Overflow boundary test
class fifo_overflow_test extends fifo_base_test;
  `uvm_component_utils(fifo_overflow_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_overflow_seq seq;
    phase.raise_objection(this);

    seq = fifo_overflow_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass
