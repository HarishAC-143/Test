// FIFO Monitor — observes all FIFO operations
class fifo_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_monitor)

  virtual fifo_if vif;
  uvm_analysis_port #(fifo_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual fifo_if)::get(this, "", "fifo_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface 'fifo_vif' not found")
  endfunction

  task run_phase(uvm_phase phase);
    fifo_transaction txn;

    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);

      if (vif.monitor_cb.wr_en || vif.monitor_cb.rd_en) begin
        txn = fifo_transaction::type_id::create("txn");

        // Determine operation type
        if (vif.monitor_cb.wr_en && vif.monitor_cb.rd_en)
          txn.operation = FIFO_BOTH;
        else if (vif.monitor_cb.wr_en)
          txn.operation = FIFO_WRITE;
        else
          txn.operation = FIFO_READ;

        // Capture current state
        txn.wr_data       = vif.monitor_cb.wr_data;
        txn.full          = vif.monitor_cb.full;
        txn.empty         = vif.monitor_cb.empty;
        txn.count         = vif.monitor_cb.count;
        txn.write_blocked = vif.monitor_cb.wr_en && vif.monitor_cb.full;
        txn.read_blocked  = vif.monitor_cb.rd_en && vif.monitor_cb.empty;

        // Wait one cycle for read data to be available
        @(posedge vif.clk);
        txn.rd_data = vif.monitor_cb.rd_data;

        `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)

        ap.write(txn);
      end
    end
  endtask

endclass
