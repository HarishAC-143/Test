class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize to idle
    vif.drv_cb.psel    <= 1'b0;
    vif.drv_cb.penable <= 1'b0;
    vif.drv_cb.pwrite  <= 1'b0;
    vif.drv_cb.paddr   <= '0;
    vif.drv_cb.pwdata  <= '0;
    vif.drv_cb.pstrb   <= '0;

    @(posedge vif.preset_n);
    @(posedge vif.pclk);

    forever begin
      apb_seq_item req;
      seq_item_port.get_next_item(req);

      if (req.delay > 0) repeat(req.delay) @(vif.drv_cb);

      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_transfer(apb_seq_item tx);
    // SETUP phase
    @(vif.drv_cb);
    vif.drv_cb.psel   <= 1'b1;
    vif.drv_cb.paddr  <= tx.addr;
    vif.drv_cb.pwrite <= tx.direction;
    vif.drv_cb.pstrb  <= tx.strb;
    if (tx.direction == APB_WRITE)
      vif.drv_cb.pwdata <= tx.wdata;
    vif.drv_cb.penable <= 1'b0;

    // ACCESS phase
    @(vif.drv_cb);
    vif.drv_cb.penable <= 1'b1;

    // Wait for PREADY
    do begin
      @(vif.drv_cb);
    end while (!vif.drv_cb.pready);

    // Capture response
    if (tx.direction == APB_READ)
      tx.rdata = vif.drv_cb.prdata;
    tx.slverr = vif.drv_cb.pslverr;

    `uvm_info("DRV", tx.convert2string(), UVM_HIGH)

    // Return to IDLE
    vif.drv_cb.psel    <= 1'b0;
    vif.drv_cb.penable <= 1'b0;
  endtask
endclass
