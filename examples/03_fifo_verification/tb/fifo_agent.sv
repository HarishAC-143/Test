// FIFO Agent
class fifo_agent extends uvm_agent;
  `uvm_component_utils(fifo_agent)

  fifo_driver                            driver;
  fifo_monitor                           monitor;
  uvm_sequencer #(fifo_transaction)      sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    monitor = fifo_monitor::type_id::create("monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      driver    = fifo_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer #(fifo_transaction)::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass
