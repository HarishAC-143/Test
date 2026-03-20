class apb_driver extends uvm_driver #(apb_transaction);
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
    vif.drv_cb.psel    <= 1'b0;
    vif.drv_cb.penable <= 1'b0;
    vif.drv_cb.pwrite  <= 1'b0;
    vif.drv_cb.paddr   <= '0;
    vif.drv_cb.pwdata  <= '0;

    @(posedge vif.preset_n);
    @(posedge vif.pclk);

    forever begin
      apb_transaction req;
      seq_item_port.get_next_item(req);
      drive_apb(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_apb(apb_transaction tx);
    // SETUP phase
    @(vif.drv_cb);
    vif.drv_cb.psel   <= 1'b1;
    vif.drv_cb.paddr  <= tx.addr;
    vif.drv_cb.pwrite <= tx.write;
    if (tx.write)
      vif.drv_cb.pwdata <= tx.data;
    vif.drv_cb.penable <= 1'b0;

    // ACCESS phase
    @(vif.drv_cb);
    vif.drv_cb.penable <= 1'b1;

    // Wait for PREADY
    @(vif.drv_cb);
    while (!vif.drv_cb.pready) @(vif.drv_cb);

    if (!tx.write)
      tx.data = vif.drv_cb.prdata;

    `uvm_info("DRV", tx.convert2string(), UVM_HIGH)

    // Return to IDLE
    vif.drv_cb.psel    <= 1'b0;
    vif.drv_cb.penable <= 1'b0;
  endtask
endclass
