// FIFO Agent
class fifo_agent extends uvm_agent;
  `uvm_component_utils(fifo_agent)

  fifo_driver                      drv;
  fifo_monitor                     mon;
  uvm_sequencer #(fifo_seq_item)   sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = fifo_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = fifo_driver::type_id::create("drv", this);
      sqr = uvm_sequencer#(fifo_seq_item)::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
