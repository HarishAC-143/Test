// APB Tests — different test scenarios for the APB slave DUT

// Base test with common setup
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
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


// Test 1: Random write-only test
class apb_random_write_test extends apb_base_test;
  `uvm_component_utils(apb_random_write_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_random_write_seq seq;
    phase.raise_objection(this, "Starting random write test");

    seq = apb_random_write_seq::type_id::create("seq");
    seq.num_writes = 20;
    seq.start(env.agent.sqr);

    phase.drop_objection(this, "Random write test complete");
  endtask
endclass


// Test 2: Write-then-read-back test (the main correctness test)
class apb_write_read_test extends apb_base_test;
  `uvm_component_utils(apb_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_read_back_seq seq;
    phase.raise_objection(this, "Starting write-read test");

    seq = apb_write_read_back_seq::type_id::create("seq");
    seq.num_pairs = 25;
    seq.start(env.agent.sqr);

    phase.drop_objection(this, "Write-read test complete");
  endtask
endclass


// Test 3: Walking-ones address test
class apb_walking_ones_test extends apb_base_test;
  `uvm_component_utils(apb_walking_ones_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_walking_ones_seq seq;
    phase.raise_objection(this, "Starting walking-ones test");

    seq = apb_walking_ones_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    phase.drop_objection(this, "Walking-ones test complete");
  endtask
endclass


// Test 4: Combined stress test
class apb_stress_test extends apb_base_test;
  `uvm_component_utils(apb_stress_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting stress test");

    // Run multiple sequences in succession
    begin
      apb_random_write_seq wr_seq = apb_random_write_seq::type_id::create("wr_seq");
      wr_seq.num_writes = 50;
      wr_seq.start(env.agent.sqr);
    end

    begin
      apb_write_read_back_seq rw_seq = apb_write_read_back_seq::type_id::create("rw_seq");
      rw_seq.num_pairs = 50;
      rw_seq.start(env.agent.sqr);
    end

    begin
      apb_walking_ones_seq walk_seq = apb_walking_ones_seq::type_id::create("walk_seq");
      walk_seq.start(env.agent.sqr);
    end

    phase.drop_objection(this, "Stress test complete");
  endtask
endclass
