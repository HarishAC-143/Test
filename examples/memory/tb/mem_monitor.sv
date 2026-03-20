class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)

  virtual mem_if vif;
  uvm_analysis_port #(mem_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Failed to get virtual interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_transaction tx;

    forever begin
      @(posedge vif.clk);

      if (vif.monitor_cb.we || vif.monitor_cb.re) begin
        tx = mem_transaction::type_id::create("tx");
        tx.addr  = vif.monitor_cb.addr;
        tx.wdata = vif.monitor_cb.wdata;
        tx.we    = vif.monitor_cb.we;
        tx.re    = vif.monitor_cb.re;
        tx.be    = vif.monitor_cb.be;

        if (vif.monitor_cb.re) begin
          @(posedge vif.clk);
          tx.rdata  = vif.monitor_cb.rdata;
          tx.rvalid = vif.monitor_cb.rvalid;
        end

        `uvm_info("MON", $sformatf("Observed: %s", tx.convert2string()), UVM_HIGH)
        ap.write(tx);
      end
    end
  endtask
endclass
