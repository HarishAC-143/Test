class axi_lite_monitor extends uvm_monitor;
  `uvm_component_utils(axi_lite_monitor)

  virtual axi_lite_if vif;
  uvm_analysis_port #(axi_lite_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Failed to get virtual interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  virtual task monitor_writes();
    axi_lite_transaction tx;

    forever begin
      // Detect write address handshake
      @(posedge vif.aclk);
      if (vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
        tx = axi_lite_transaction::type_id::create("tx");
        tx.rw   = 1;
        tx.addr = vif.monitor_cb.awaddr;

        // Wait for write data handshake
        do @(posedge vif.aclk);
        while (!(vif.monitor_cb.wvalid && vif.monitor_cb.wready));
        tx.wdata = vif.monitor_cb.wdata;
        tx.wstrb = vif.monitor_cb.wstrb;

        // Wait for write response handshake
        do @(posedge vif.aclk);
        while (!(vif.monitor_cb.bvalid && vif.monitor_cb.bready));
        tx.resp = vif.monitor_cb.bresp;

        `uvm_info("MON", $sformatf("Observed: %s", tx.convert2string()), UVM_HIGH)
        ap.write(tx);
      end
    end
  endtask

  virtual task monitor_reads();
    axi_lite_transaction tx;

    forever begin
      // Detect read address handshake
      @(posedge vif.aclk);
      if (vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
        tx = axi_lite_transaction::type_id::create("tx");
        tx.rw   = 0;
        tx.addr = vif.monitor_cb.araddr;

        // Wait for read data handshake
        do @(posedge vif.aclk);
        while (!(vif.monitor_cb.rvalid && vif.monitor_cb.rready));
        tx.rdata = vif.monitor_cb.rdata;
        tx.resp  = vif.monitor_cb.rresp;

        `uvm_info("MON", $sformatf("Observed: %s", tx.convert2string()), UVM_HIGH)
        ap.write(tx);
      end
    end
  endtask
endclass
