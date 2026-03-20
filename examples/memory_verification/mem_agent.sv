// Memory Agent — bundles driver, monitor, and sequencer
class mem_agent extends uvm_agent;

  `uvm_component_utils(mem_agent)

  mem_driver                  drv;
  mem_monitor                 mon;
  uvm_sequencer #(mem_txn)   sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon = mem_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = mem_driver::type_id::create("drv", this);
      sqr = uvm_sequencer#(mem_txn)::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
