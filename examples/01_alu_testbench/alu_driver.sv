class alu_driver extends uvm_driver #(alu_transaction);
  `uvm_component_utils(alu_driver)

  virtual alu_if vif;

  function new(string name = "alu_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "ALU virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize signals
    vif.drv_cb.valid_in  <= 1'b0;
    vif.drv_cb.opcode    <= 3'b0;
    vif.drv_cb.operand_a <= 32'h0;
    vif.drv_cb.operand_b <= 32'h0;

    // Wait for reset
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      alu_transaction req;
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(alu_transaction tx);
    @(vif.drv_cb);
    vif.drv_cb.valid_in  <= 1'b1;
    vif.drv_cb.opcode    <= tx.opcode;
    vif.drv_cb.operand_a <= tx.operand_a;
    vif.drv_cb.operand_b <= tx.operand_b;
    `uvm_info("DRV", $sformatf("Driving: op=%s a=0x%08h b=0x%08h",
              tx.opcode.name(), tx.operand_a, tx.operand_b), UVM_HIGH)

    @(vif.drv_cb);
    vif.drv_cb.valid_in <= 1'b0;
  endtask
endclass
