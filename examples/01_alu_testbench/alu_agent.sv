class alu_agent extends uvm_agent;
  `uvm_component_utils(alu_agent)

  alu_driver    drv;
  alu_sequencer sqr;
  alu_monitor   mon;

  function new(string name = "alu_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = alu_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = alu_driver::type_id::create("drv", this);
      sqr = alu_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction
endclass
