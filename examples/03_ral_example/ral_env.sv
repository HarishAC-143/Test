class ral_env extends uvm_env;
  `uvm_component_utils(ral_env)

  apb_agent        agent;
  periph_reg_block reg_model;
  apb_reg_adapter  adapter;

  function new(string name = "ral_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent = apb_agent::type_id::create("agent", this);

    reg_model = periph_reg_block::type_id::create("reg_model");
    reg_model.build();

    adapter = apb_reg_adapter::type_id::create("adapter");
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    reg_model.default_map.set_sequencer(agent.sqr, adapter);
    reg_model.default_map.set_auto_predict(1);
  endfunction
endclass
