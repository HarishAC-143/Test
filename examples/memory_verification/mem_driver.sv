// Memory Driver — drives read/write transactions on the SRAM interface
class mem_driver extends uvm_driver #(mem_txn);

  `uvm_component_utils(mem_driver)

  virtual mem_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "mem_vif", vif))
      `uvm_fatal("DRV", "Virtual interface 'mem_vif' not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_txn txn;

    // Initialize signals
    vif.cs    <= 1'b0;
    vif.we    <= 1'b0;
    vif.addr  <= 8'd0;
    vif.wdata <= 8'd0;

    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_transaction(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(mem_txn txn);
    @(posedge vif.clk);
    vif.cs    <= 1'b1;
    vif.addr  <= txn.addr;

    if (txn.op == MEM_WRITE) begin
      vif.we    <= 1'b1;
      vif.wdata <= txn.wdata;
      `uvm_info("DRV", $sformatf("Driving WRITE: addr=0x%02h data=0x%02h",
                txn.addr, txn.wdata), UVM_HIGH)
    end else begin
      vif.we    <= 1'b0;
      vif.wdata <= 8'd0;
      `uvm_info("DRV", $sformatf("Driving READ: addr=0x%02h", txn.addr), UVM_HIGH)
    end

    @(posedge vif.clk);
    vif.cs <= 1'b0;
    vif.we <= 1'b0;
  endtask

endclass
