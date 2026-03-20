class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name = "apb_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
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

// Smoke test — basic write/read sanity
class apb_smoke_test extends apb_base_test;
  `uvm_component_utils(apb_smoke_test)

  function new(string name = "apb_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_then_read_seq seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== APB Smoke Test ===", UVM_LOW)
    seq = apb_write_then_read_seq::type_id::create("seq");
    seq.num_addresses = 8;
    seq.start(env.agent.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass

// Random test — high-volume random traffic
class apb_random_test extends apb_base_test;
  `uvm_component_utils(apb_random_test)

  function new(string name = "apb_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_random_seq seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== APB Random Test: 500 transactions ===", UVM_LOW)
    seq = apb_random_seq::type_id::create("seq");
    seq.num_txns = 500;
    seq.start(env.agent.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass

// Boundary test — address boundary conditions
class apb_boundary_test extends apb_base_test;
  `uvm_component_utils(apb_boundary_test)

  function new(string name = "apb_boundary_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_boundary_seq    bnd_seq;
    apb_write_read_seq  wr_rd_seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== APB Boundary Test ===", UVM_LOW)

    // Test boundary addresses
    bnd_seq = apb_boundary_seq::type_id::create("bnd_seq");
    bnd_seq.start(env.agent.sqr);

    // Additional write-read pairs at specific addresses
    for (int i = 0; i < 10; i++) begin
      wr_rd_seq = apb_write_read_seq::type_id::create($sformatf("wr_rd_%0d", i));
      wr_rd_seq.randomize();
      wr_rd_seq.start(env.agent.sqr);
    end

    #100;
    phase.drop_objection(this);
  endtask
endclass

// Back-to-back test — no idle cycles
class apb_back2back_test extends apb_base_test;
  `uvm_component_utils(apb_back2back_test)

  function new(string name = "apb_back2back_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_then_read_seq wr_rd_seq;
    apb_back2back_seq       b2b_seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== APB Back-to-Back Test ===", UVM_LOW)

    // First fill memory
    wr_rd_seq = apb_write_then_read_seq::type_id::create("wr_rd_seq");
    wr_rd_seq.num_addresses = 32;
    wr_rd_seq.start(env.agent.sqr);

    // Then hammer it with back-to-back traffic
    b2b_seq = apb_back2back_seq::type_id::create("b2b_seq");
    b2b_seq.num_txns = 100;
    b2b_seq.start(env.agent.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass
