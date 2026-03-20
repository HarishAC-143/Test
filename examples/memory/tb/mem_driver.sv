class mem_driver extends uvm_driver #(mem_transaction);
  `uvm_component_utils(mem_driver)

  virtual mem_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Failed to get virtual interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_transaction tx;

    // Initialize signals
    vif.driver_cb.we <= 0;
    vif.driver_cb.re <= 0;

    forever begin
      seq_item_port.get_next_item(tx);
      drive_transaction(tx);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(mem_transaction tx);
    @(posedge vif.clk);
    vif.driver_cb.addr  <= tx.addr;
    vif.driver_cb.we    <= tx.we;
    vif.driver_cb.re    <= tx.re;
    vif.driver_cb.be    <= tx.be;
    vif.driver_cb.wdata <= tx.wdata;

    @(posedge vif.clk);
    vif.driver_cb.we <= 0;
    vif.driver_cb.re <= 0;

    `uvm_info("DRV", $sformatf("Drove: %s", tx.convert2string()), UVM_HIGH)
  endtask
endclass
