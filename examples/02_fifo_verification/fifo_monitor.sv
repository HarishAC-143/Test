class fifo_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_monitor)

  virtual fifo_if vif;
  uvm_analysis_port #(fifo_transaction) ap;

  function new(string name = "fifo_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "FIFO virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);

    forever begin
      fifo_transaction tx;
      @(vif.mon_cb);

      if (vif.mon_cb.wr_en || vif.mon_cb.rd_en) begin
        tx = fifo_transaction::type_id::create("tx");

        if (vif.mon_cb.wr_en) begin
          tx.op   = FIFO_WRITE;
          tx.data = vif.mon_cb.wr_data;
        end else begin
          tx.op = FIFO_READ;
        end

        tx.full         = vif.mon_cb.full;
        tx.empty        = vif.mon_cb.empty;
        tx.almost_full  = vif.mon_cb.almost_full;
        tx.almost_empty = vif.mon_cb.almost_empty;
        tx.overflow     = vif.mon_cb.overflow;
        tx.underflow    = vif.mon_cb.underflow;

        if (vif.mon_cb.rd_en) begin
          @(vif.mon_cb);  // wait one cycle for read data
          tx.rd_data = vif.mon_cb.rd_data;
        end

        `uvm_info("MON", tx.convert2string(), UVM_HIGH)
        ap.write(tx);
      end
    end
  endtask
endclass
