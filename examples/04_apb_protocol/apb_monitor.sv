class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.preset_n);

    forever begin
      apb_seq_item tx;

      // Detect SETUP phase (psel && !penable)
      @(vif.mon_cb iff (vif.mon_cb.psel && !vif.mon_cb.penable));
      tx = apb_seq_item::type_id::create("tx");
      tx.addr      = vif.mon_cb.paddr;
      tx.direction = apb_dir_t'(vif.mon_cb.pwrite);
      tx.strb      = vif.mon_cb.pstrb;
      if (tx.direction == APB_WRITE)
        tx.wdata = vif.mon_cb.pwdata;

      // Wait for ACCESS phase completion (penable && pready)
      @(vif.mon_cb iff (vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready));
      if (tx.direction == APB_READ)
        tx.rdata = vif.mon_cb.prdata;
      tx.slverr = vif.mon_cb.pslverr;

      `uvm_info("MON", tx.convert2string(), UVM_HIGH)
      ap.write(tx);
    end
  endtask
endclass
