// ALU Driver — converts transactions to pin-level signals
class alu_driver extends uvm_driver #(alu_txn);

  `uvm_component_utils(alu_driver)

  virtual alu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("DRV", "Virtual interface 'alu_vif' not found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_txn txn;

    // Initialize interface signals
    vif.operand_a <= 8'd0;
    vif.operand_b <= 8'd0;
    vif.operation <= 2'b00;
    vif.valid     <= 1'b0;

    // Wait for reset to deassert
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_transaction(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(alu_txn txn);
    `uvm_info("DRV", $sformatf("Driving: %s", txn.convert2string()), UVM_HIGH)

    @(posedge vif.clk);
    vif.operand_a <= txn.operand_a;
    vif.operand_b <= txn.operand_b;
    vif.operation <= txn.operation;
    vif.valid     <= 1'b1;

    @(posedge vif.clk);
    vif.valid     <= 1'b0;
  endtask

endclass
