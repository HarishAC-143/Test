// Memory Environment
class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)

  mem_agent      agent;
  mem_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = mem_agent::type_id::create("agent", this);
    scoreboard = mem_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
