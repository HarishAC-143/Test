//----------------------------------------------------------------------
// Memory Agent
//
// Encapsulates driver, monitor, and sequencer.  Supports active and
// passive modes controlled via uvm_config_db or the is_active field.
//   UVM_ACTIVE  -> driver + sequencer + monitor instantiated
//   UVM_PASSIVE -> only monitor instantiated
//----------------------------------------------------------------------
class mem_agent extends uvm_agent;
  `uvm_component_utils(mem_agent)

  mem_driver    m_driver;
  mem_monitor   m_monitor;
  mem_sequencer m_sequencer;

  function new(string name = "mem_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Always build the monitor
    m_monitor = mem_monitor::type_id::create("m_monitor", this);

    // Only build driver and sequencer in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      m_driver    = mem_driver::type_id::create("m_driver", this);
      m_sequencer = mem_sequencer::type_id::create("m_sequencer", this);
      `uvm_info(get_type_name(), "Agent configured in ACTIVE mode", UVM_MEDIUM)
    end else begin
      `uvm_info(get_type_name(), "Agent configured in PASSIVE mode", UVM_MEDIUM)
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction
endclass
