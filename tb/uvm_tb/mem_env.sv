//----------------------------------------------------------------------
// Memory UVM Environment
//
// Top-level environment encapsulating agent, scoreboard, and coverage
// collector.  Wires analysis port connections in the connect phase.
//----------------------------------------------------------------------
class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)

  mem_agent      m_agent;
  mem_scoreboard m_scoreboard;
  mem_coverage   m_coverage;

  function new(string name = "mem_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_agent      = mem_agent::type_id::create("m_agent", this);
    m_scoreboard = mem_scoreboard::type_id::create("m_scoreboard", this);
    m_coverage   = mem_coverage::type_id::create("m_coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect monitor analysis ports to scoreboard
    m_agent.m_monitor.write_ap.connect(m_scoreboard.write_imp);
    m_agent.m_monitor.read_ap.connect(m_scoreboard.read_imp);
    // Connect combined analysis port to coverage collector
    m_agent.m_monitor.ap.connect(m_coverage.analysis_export);
  endfunction
endclass
