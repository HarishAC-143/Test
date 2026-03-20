class alu_driver extends uvm_driver #(alu_transaction);
  `uvm_component_utils(alu_driver)

  virtual alu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Failed to get virtual interface from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_transaction tx;
    forever begin
      seq_item_port.get_next_item(tx);
      drive_transaction(tx);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(alu_transaction tx);
    @(posedge vif.clk);
    vif.driver_cb.operand_a <= tx.operand_a;
    vif.driver_cb.operand_b <= tx.operand_b;
    vif.driver_cb.opcode    <= tx.opcode;
    vif.driver_cb.valid_in  <= 1'b1;
    @(posedge vif.clk);
    vif.driver_cb.valid_in  <= 1'b0;
    `uvm_info("DRV", $sformatf("Drove: A=0x%02h OP=%0d B=0x%02h",
              tx.operand_a, tx.opcode, tx.operand_b), UVM_HIGH)
  endtask
endclass
