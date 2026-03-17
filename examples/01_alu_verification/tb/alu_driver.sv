// ALU Driver — converts transactions into pin-level signal activity
class alu_driver extends uvm_driver #(alu_transaction);
  `uvm_component_utils(alu_driver)

  virtual alu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface 'alu_vif' not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    alu_transaction txn;

    // Initialize outputs
    vif.driver_cb.operand_a <= 8'h00;
    vif.driver_cb.operand_b <= 8'h00;
    vif.driver_cb.operation <= 3'b000;
    vif.driver_cb.valid_in  <= 1'b0;

    // Wait for reset de-assertion
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_transaction(txn);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(alu_transaction txn);
    `uvm_info("DRV", $sformatf("Driving: a=0x%02h b=0x%02h op=%s",
              txn.operand_a, txn.operand_b, txn.operation.name()), UVM_HIGH)

    @(posedge vif.clk);
    vif.driver_cb.operand_a <= txn.operand_a;
    vif.driver_cb.operand_b <= txn.operand_b;
    vif.driver_cb.operation <= txn.operation;
    vif.driver_cb.valid_in  <= 1'b1;

    @(posedge vif.clk);
    vif.driver_cb.valid_in <= 1'b0;
  endtask

endclass
