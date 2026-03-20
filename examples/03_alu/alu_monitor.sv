// ALU Monitor
class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;
  uvm_analysis_port #(alu_seq_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);

    forever begin
      alu_seq_item tr;

      @(posedge vif.clk iff vif.start);
      tr = alu_seq_item::type_id::create("tr");
      tr.operand_a = vif.operand_a;
      tr.operand_b = vif.operand_b;
      tr.opcode    = alu_seq_item::opcode_e'(vif.opcode);

      @(posedge vif.clk iff vif.done);
      tr.result        = vif.result;
      tr.zero_flag     = vif.zero_flag;
      tr.carry_flag    = vif.carry_flag;
      tr.overflow_flag = vif.overflow_flag;

      `uvm_info("MON", $sformatf("Collected: %s", tr.convert2string()), UVM_HIGH)
      analysis_port.write(tr);
    end
  endtask

endclass
