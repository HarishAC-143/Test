// ──────── Base test ────────
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
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  // Reset the DUT before starting the test
  virtual task reset_phase(uvm_phase phase);
    virtual alu_if vif;
    phase.raise_objection(this);

    if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("TEST", "Failed to get virtual interface")

    vif.driver_cb.rst_n    <= 1'b0;
    vif.driver_cb.valid_in <= 1'b0;
    repeat(5) @(posedge vif.clk);
    vif.driver_cb.rst_n <= 1'b1;
    @(posedge vif.clk);

    phase.drop_objection(this);
  endtask
endclass

// ──────── Random test ────────
class alu_random_test extends alu_base_test;
  `uvm_component_utils(alu_random_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_random_sequence seq;
    phase.raise_objection(this);

    seq = alu_random_sequence::type_id::create("seq");
    seq.num_txns = 500;
    seq.start(env.agt.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass

// ──────── Directed test ────────
class alu_directed_test extends alu_base_test;
  `uvm_component_utils(alu_directed_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    alu_full_sequence seq;
    phase.raise_objection(this);

    seq = alu_full_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass
