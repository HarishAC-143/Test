// Memory Monitor — observes DUT interface and broadcasts transactions
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
    if (!uvm_config_db #(virtual mem_if)::get(this, "", "mem_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface 'mem_vif' not found")
  endfunction

  task run_phase(uvm_phase phase);
    mem_transaction txn;

    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);

      if (vif.monitor_cb.wr_en) begin
        txn = mem_transaction::type_id::create("txn");
        txn.addr  = vif.monitor_cb.addr;
        txn.wdata = vif.monitor_cb.wdata;
        txn.write = 1;
        `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
        ap.write(txn);
      end

      if (vif.monitor_cb.rd_en) begin
        txn = mem_transaction::type_id::create("txn");
        txn.addr  = vif.monitor_cb.addr;
        txn.write = 0;

        // Wait for read data
        @(posedge vif.clk);
        txn.rdata  = vif.monitor_cb.rdata;
        txn.rvalid = vif.monitor_cb.rvalid;

        `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
        ap.write(txn);
      end
    end
  endtask

endclass
