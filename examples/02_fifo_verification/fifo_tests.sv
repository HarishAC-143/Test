class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)

  fifo_env env;

  function new(string name = "fifo_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    fifo_random_sequence seq;
    phase.raise_objection(this);

    `uvm_info("TEST", "=== FIFO Base Test: Random Read/Write ===", UVM_LOW)
    seq = fifo_random_sequence::type_id::create("seq");
    seq.num_txns = 200;
    seq.start(env.agent.sqr);

    #200;
    phase.drop_objection(this);
  endtask
endclass

class fifo_full_empty_test extends fifo_base_test;
  `uvm_component_utils(fifo_full_empty_test)

  function new(string name = "fifo_full_empty_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_fill_drain_sequence fd_seq;
    fifo_random_sequence     rand_seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== FIFO Full/Empty Test ===", UVM_LOW)

    // Fill and drain twice
    repeat(2) begin
      fd_seq = fifo_fill_drain_sequence::type_id::create("fd_seq");
      fd_seq.start(env.agent.sqr);
    end

    // Then random traffic
    rand_seq = fifo_random_sequence::type_id::create("rand_seq");
    rand_seq.num_txns = 100;
    rand_seq.start(env.agent.sqr);

    #200;
    phase.drop_objection(this);
  endtask
endclass

class fifo_overflow_test extends fifo_base_test;
  `uvm_component_utils(fifo_overflow_test)

  function new(string name = "fifo_overflow_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    fifo_overflow_sequence ovf_seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== FIFO Overflow Test ===", UVM_LOW)
    ovf_seq = fifo_overflow_sequence::type_id::create("ovf_seq");
    ovf_seq.start(env.agent.sqr);

    #200;
    phase.drop_objection(this);
  endtask
endclass
