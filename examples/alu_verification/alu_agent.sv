// ALU Agent — bundles driver, monitor, and sequencer
class alu_agent extends uvm_agent;

  `uvm_component_utils(alu_agent)

  alu_driver                       drv;
  alu_monitor                      mon;
  uvm_sequencer #(alu_txn)        sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always present (active and passive modes)
    mon = alu_monitor::type_id::create("mon", this);

    // Driver and sequencer only in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = alu_driver::type_id::create("drv", this);
      sqr = uvm_sequencer#(alu_txn)::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect driver to sequencer in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
