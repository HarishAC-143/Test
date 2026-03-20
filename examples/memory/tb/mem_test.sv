// ──────── Base test ────────
class mem_base_test extends uvm_test;
  `uvm_component_utils(mem_base_test)

  mem_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mem_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual task reset_phase(uvm_phase phase);
    virtual mem_if vif;
    phase.raise_objection(this);

    if (!uvm_config_db#(virtual mem_if)::get(this, "", "vif", vif))
      `uvm_fatal("TEST", "Failed to get interface")

    vif.driver_cb.rst_n <= 1'b0;
    vif.driver_cb.we    <= 1'b0;
    vif.driver_cb.re    <= 1'b0;
    repeat(5) @(posedge vif.clk);
    vif.driver_cb.rst_n <= 1'b1;
    @(posedge vif.clk);

    phase.drop_objection(this);
  endtask
endclass

// ──────── Write-read-back test ────────
class mem_write_read_test extends mem_base_test;
  `uvm_component_utils(mem_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_write_read_sequence seq;
    phase.raise_objection(this);

    seq = mem_write_read_sequence::type_id::create("seq");
    seq.num_addrs = 50;
    seq.start(env.agt.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass

// ──────── Byte-enable test ────────
class mem_byte_enable_test extends mem_base_test;
  `uvm_component_utils(mem_byte_enable_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_byte_enable_sequence seq;
    phase.raise_objection(this);

    seq = mem_byte_enable_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass

// ──────── Full regression test ────────
class mem_full_test extends mem_base_test;
  `uvm_component_utils(mem_full_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_full_sequence seq;
    phase.raise_objection(this);

    seq = mem_full_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass
