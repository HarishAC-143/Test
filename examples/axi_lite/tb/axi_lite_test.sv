// ──────── Base test ────────
class axi_lite_base_test extends uvm_test;
  `uvm_component_utils(axi_lite_base_test)

  axi_lite_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi_lite_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual task reset_phase(uvm_phase phase);
    virtual axi_lite_if vif;
    phase.raise_objection(this);

    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
      `uvm_fatal("TEST", "Failed to get interface")

    vif.master_cb.aresetn <= 1'b0;
    vif.master_cb.awvalid <= 1'b0;
    vif.master_cb.wvalid  <= 1'b0;
    vif.master_cb.bready  <= 1'b0;
    vif.master_cb.arvalid <= 1'b0;
    vif.master_cb.rready  <= 1'b0;
    repeat(10) @(posedge vif.aclk);
    vif.master_cb.aresetn <= 1'b1;
    repeat(2) @(posedge vif.aclk);

    phase.drop_objection(this);
  endtask
endclass

// ──────── Write-read-all test ────────
class axi_lite_wr_rd_test extends axi_lite_base_test;
  `uvm_component_utils(axi_lite_wr_rd_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_write_read_all_sequence seq;
    phase.raise_objection(this);

    seq = axi_write_read_all_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
  endtask
endclass

// ──────── Random traffic test ────────
class axi_lite_random_test extends axi_lite_base_test;
  `uvm_component_utils(axi_lite_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_random_sequence seq;
    phase.raise_objection(this);

    seq = axi_random_sequence::type_id::create("seq");
    seq.num_txns = 500;
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
  endtask
endclass

// ──────── Full regression test ────────
class axi_lite_full_test extends axi_lite_base_test;
  `uvm_component_utils(axi_lite_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    axi_full_sequence seq;
    phase.raise_objection(this);

    seq = axi_full_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #200;
    phase.drop_objection(this);
  endtask
endclass
