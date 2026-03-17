// Memory Driver — converts transactions into pin-level activity
class mem_driver extends uvm_driver #(mem_transaction);
  `uvm_component_utils(mem_driver)

  virtual mem_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual mem_if)::get(this, "", "mem_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface 'mem_vif' not found")
  endfunction

  task run_phase(uvm_phase phase);
    mem_transaction txn;

    // Initialize
    vif.driver_cb.addr  <= '0;
    vif.driver_cb.wdata <= '0;
    vif.driver_cb.wr_en <= 1'b0;
    vif.driver_cb.rd_en <= 1'b0;

    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_transaction(txn);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(mem_transaction txn);
    @(posedge vif.clk);
    vif.driver_cb.addr <= txn.addr;

    if (txn.write) begin
      `uvm_info("DRV", $sformatf("Write: addr=0x%02h data=0x%08h", txn.addr, txn.wdata), UVM_HIGH)
      vif.driver_cb.wdata <= txn.wdata;
      vif.driver_cb.wr_en <= 1'b1;
      vif.driver_cb.rd_en <= 1'b0;
    end else begin
      `uvm_info("DRV", $sformatf("Read: addr=0x%02h", txn.addr), UVM_HIGH)
      vif.driver_cb.wr_en <= 1'b0;
      vif.driver_cb.rd_en <= 1'b1;
    end

    @(posedge vif.clk);
    vif.driver_cb.wr_en <= 1'b0;
    vif.driver_cb.rd_en <= 1'b0;
  endtask

endclass
