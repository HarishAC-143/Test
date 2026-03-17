// FIFO Driver
class fifo_driver extends uvm_driver #(fifo_transaction);
  `uvm_component_utils(fifo_driver)

  virtual fifo_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual fifo_if)::get(this, "", "fifo_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface 'fifo_vif' not found")
  endfunction

  task run_phase(uvm_phase phase);
    fifo_transaction txn;

    vif.driver_cb.wr_data <= '0;
    vif.driver_cb.wr_en   <= 1'b0;
    vif.driver_cb.rd_en   <= 1'b0;

    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_transaction(txn);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(fifo_transaction txn);
    @(posedge vif.clk);

    case (txn.operation)
      FIFO_WRITE: begin
        `uvm_info("DRV", $sformatf("Write: 0x%02h (full=%0b)", txn.wr_data, vif.driver_cb.full), UVM_HIGH)
        vif.driver_cb.wr_data <= txn.wr_data;
        vif.driver_cb.wr_en   <= 1'b1;
        vif.driver_cb.rd_en   <= 1'b0;
      end
      FIFO_READ: begin
        `uvm_info("DRV", $sformatf("Read (empty=%0b)", vif.driver_cb.empty), UVM_HIGH)
        vif.driver_cb.wr_en <= 1'b0;
        vif.driver_cb.rd_en <= 1'b1;
      end
      FIFO_BOTH: begin
        `uvm_info("DRV", $sformatf("Write+Read: wr=0x%02h", txn.wr_data), UVM_HIGH)
        vif.driver_cb.wr_data <= txn.wr_data;
        vif.driver_cb.wr_en   <= 1'b1;
        vif.driver_cb.rd_en   <= 1'b1;
      end
      FIFO_IDLE: begin
        vif.driver_cb.wr_en <= 1'b0;
        vif.driver_cb.rd_en <= 1'b0;
      end
    endcase

    @(posedge vif.clk);
    vif.driver_cb.wr_en <= 1'b0;
    vif.driver_cb.rd_en <= 1'b0;
  endtask

endclass
