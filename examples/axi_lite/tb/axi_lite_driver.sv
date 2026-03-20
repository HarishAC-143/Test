class axi_lite_driver extends uvm_driver #(axi_lite_transaction);
  `uvm_component_utils(axi_lite_driver)

  virtual axi_lite_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Failed to get virtual interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_lite_transaction tx;

    // Initialize all master outputs to idle
    vif.master_cb.awvalid <= 0;
    vif.master_cb.wvalid  <= 0;
    vif.master_cb.bready  <= 0;
    vif.master_cb.arvalid <= 0;
    vif.master_cb.rready  <= 0;

    forever begin
      seq_item_port.get_next_item(tx);

      if (tx.rw)
        drive_write(tx);
      else
        drive_read(tx);

      seq_item_port.item_done();
    end
  endtask

  virtual task drive_write(axi_lite_transaction tx);
    // Write address phase
    @(posedge vif.aclk);
    vif.master_cb.awaddr  <= tx.addr;
    vif.master_cb.awvalid <= 1'b1;

    // Wait for awready
    do @(posedge vif.aclk);
    while (!vif.master_cb.awready);
    vif.master_cb.awvalid <= 1'b0;

    // Write data phase
    vif.master_cb.wdata  <= tx.wdata;
    vif.master_cb.wstrb  <= tx.wstrb;
    vif.master_cb.wvalid <= 1'b1;

    // Wait for wready
    do @(posedge vif.aclk);
    while (!vif.master_cb.wready);
    vif.master_cb.wvalid <= 1'b0;

    // Write response phase
    vif.master_cb.bready <= 1'b1;
    do @(posedge vif.aclk);
    while (!vif.master_cb.bvalid);
    tx.resp = vif.master_cb.bresp;
    vif.master_cb.bready <= 1'b0;

    `uvm_info("DRV", $sformatf("Drove: %s", tx.convert2string()), UVM_HIGH)
  endtask

  virtual task drive_read(axi_lite_transaction tx);
    // Read address phase
    @(posedge vif.aclk);
    vif.master_cb.araddr  <= tx.addr;
    vif.master_cb.arvalid <= 1'b1;

    // Wait for arready
    do @(posedge vif.aclk);
    while (!vif.master_cb.arready);
    vif.master_cb.arvalid <= 1'b0;

    // Read data phase
    vif.master_cb.rready <= 1'b1;
    do @(posedge vif.aclk);
    while (!vif.master_cb.rvalid);
    tx.rdata = vif.master_cb.rdata;
    tx.resp  = vif.master_cb.rresp;
    vif.master_cb.rready <= 1'b0;

    `uvm_info("DRV", $sformatf("Drove: %s", tx.convert2string()), UVM_HIGH)
  endtask
endclass
