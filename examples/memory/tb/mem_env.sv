class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)

  mem_agent      agt;
  mem_scoreboard sb;
  mem_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = mem_agent::type_id::create("agt", this);
    sb  = mem_scoreboard::type_id::create("sb", this);
    cov = mem_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.ap.connect(sb.analysis_export);
    agt.mon.ap.connect(cov.analysis_export);
  endfunction
endclass
