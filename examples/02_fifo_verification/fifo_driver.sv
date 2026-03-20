// Unified FIFO driver — handles both write and read operations
class fifo_driver extends uvm_driver #(fifo_transaction);
  `uvm_component_utils(fifo_driver)

  virtual fifo_if vif;

  function new(string name = "fifo_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "FIFO virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize
    vif.wr_drv_cb.wr_en   <= 1'b0;
    vif.wr_drv_cb.wr_data <= '0;
    vif.rd_drv_cb.rd_en   <= 1'b0;

    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      fifo_transaction req;
      seq_item_port.get_next_item(req);

      if (req.delay > 0) repeat(req.delay) @(posedge vif.clk);

      if (req.op == FIFO_WRITE)
        drive_write(req);
      else
        drive_read(req);

      seq_item_port.item_done();
    end
  endtask

  task drive_write(fifo_transaction tx);
    @(vif.wr_drv_cb);
    vif.wr_drv_cb.wr_en   <= 1'b1;
    vif.wr_drv_cb.wr_data <= tx.data;
    `uvm_info("DRV", $sformatf("Writing 0x%02h", tx.data), UVM_HIGH)
    @(vif.wr_drv_cb);
    vif.wr_drv_cb.wr_en <= 1'b0;
  endtask

  task drive_read(fifo_transaction tx);
    @(vif.rd_drv_cb);
    vif.rd_drv_cb.rd_en <= 1'b1;
    `uvm_info("DRV", "Reading from FIFO", UVM_HIGH)
    @(vif.rd_drv_cb);
    vif.rd_drv_cb.rd_en <= 1'b0;
  endtask
endclass
