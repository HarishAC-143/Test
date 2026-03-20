// AXI-Lite Driver — protocol-aware driver handling all AXI channels
class axi_lite_driver extends uvm_driver #(axi_lite_txn);

  `uvm_component_utils(axi_lite_driver)

  virtual axi_lite_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "axi_vif", vif))
      `uvm_fatal("DRV", "Virtual interface 'axi_vif' not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi_lite_txn txn;

    // Initialize all master-side signals
    vif.awaddr  <= 32'd0;
    vif.awvalid <= 1'b0;
    vif.wdata   <= 32'd0;
    vif.wstrb   <= 4'd0;
    vif.wvalid  <= 1'b0;
    vif.bready  <= 1'b0;
    vif.araddr  <= 32'd0;
    vif.arvalid <= 1'b0;
    vif.rready  <= 1'b0;

    @(posedge vif.aresetn);
    @(posedge vif.aclk);

    forever begin
      seq_item_port.get_next_item(txn);

      if (txn.dir == AXI_WRITE)
        drive_write(txn);
      else
        drive_read(txn);

      seq_item_port.item_done();
    end
  endtask

  // Drive AXI write transaction (address + data + response)
  virtual task drive_write(axi_lite_txn txn);
    `uvm_info("DRV", $sformatf("Driving WRITE: addr=0x%08h data=0x%08h",
              txn.addr, txn.data), UVM_HIGH)

    // Drive write address and write data in parallel
    fork
      begin  // Write Address Channel
        @(posedge vif.aclk);
        vif.awaddr  <= txn.addr;
        vif.awvalid <= 1'b1;
        // Wait for AWREADY
        do @(posedge vif.aclk);
        while (!vif.awready);
        vif.awvalid <= 1'b0;
      end
      begin  // Write Data Channel
        @(posedge vif.aclk);
        vif.wdata  <= txn.data;
        vif.wstrb  <= txn.strb;
        vif.wvalid <= 1'b1;
        // Wait for WREADY
        do @(posedge vif.aclk);
        while (!vif.wready);
        vif.wvalid <= 1'b0;
      end
    join

    // Write Response Channel — wait for BVALID
    vif.bready <= 1'b1;
    do @(posedge vif.aclk);
    while (!vif.bvalid);
    txn.resp = axi_resp_e'(vif.bresp);
    vif.bready <= 1'b0;
  endtask

  // Drive AXI read transaction (address + data)
  virtual task drive_read(axi_lite_txn txn);
    `uvm_info("DRV", $sformatf("Driving READ: addr=0x%08h", txn.addr), UVM_HIGH)

    // Read Address Channel
    @(posedge vif.aclk);
    vif.araddr  <= txn.addr;
    vif.arvalid <= 1'b1;

    // Wait for ARREADY
    do @(posedge vif.aclk);
    while (!vif.arready);
    vif.arvalid <= 1'b0;

    // Read Data Channel — wait for RVALID
    vif.rready <= 1'b1;
    do @(posedge vif.aclk);
    while (!vif.rvalid);
    txn.data = vif.rdata;
    txn.resp = axi_resp_e'(vif.rresp);
    vif.rready <= 1'b0;
  endtask

endclass
