// ALU Driver
class alu_driver extends uvm_driver #(alu_seq_item);
  `uvm_component_utils(alu_driver)

  virtual alu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    vif.operand_a <= 0;
    vif.operand_b <= 0;
    vif.opcode    <= 0;
    vif.start     <= 0;
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      alu_seq_item req;
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  task drive(alu_seq_item tr);
    // Apply inputs
    @(posedge vif.clk);
    vif.operand_a <= tr.operand_a;
    vif.operand_b <= tr.operand_b;
    vif.opcode    <= tr.opcode;
    vif.start     <= 1;

    // Wait for result
    @(posedge vif.clk);
    vif.start <= 0;

    // Capture outputs
    @(posedge vif.clk iff vif.done);
    tr.result        = vif.result;
    tr.zero_flag     = vif.zero_flag;
    tr.carry_flag    = vif.carry_flag;
    tr.overflow_flag = vif.overflow_flag;

    `uvm_info("DRV", $sformatf("Drove: %s", tr.convert2string()), UVM_HIGH)
  endtask

endclass
