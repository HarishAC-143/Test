//----------------------------------------------------------------------
// Memory Monitor
//
// Passively observes the DUT interface and broadcasts transactions
// through analysis ports.  Separate ports are provided for write
// and read transactions so downstream components (scoreboard,
// coverage) can subscribe independently.
//----------------------------------------------------------------------
class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)

  virtual mem_if vif;

  uvm_analysis_port #(mem_seq_item) write_ap;
  uvm_analysis_port #(mem_seq_item) read_ap;
  uvm_analysis_port #(mem_seq_item) ap;  // combined port

  function new(string name = "mem_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
    write_ap = new("write_ap", this);
    read_ap  = new("read_ap",  this);
    ap       = new("ap",       this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_seq_item txn;

    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);
      txn = mem_seq_item::type_id::create("txn");

      if (vif.monitor_cb.wr_en) begin
        txn.wr_en = 1;
        txn.rd_en = 0;
        txn.addr  = vif.monitor_cb.addr;
        txn.wdata = vif.monitor_cb.wdata;
        `uvm_info(get_type_name(), $sformatf("Write observed: %s", txn.convert2string()), UVM_HIGH)
        write_ap.write(txn);
        ap.write(txn);
      end

      if (vif.monitor_cb.rd_en) begin
        txn.wr_en = 0;
        txn.rd_en = 1;
        txn.addr  = vif.monitor_cb.addr;
        // Wait one cycle for read data to appear
        @(posedge vif.clk);
        txn.rdata = vif.monitor_cb.rdata;
        txn.valid = vif.monitor_cb.valid;
        `uvm_info(get_type_name(), $sformatf("Read observed: %s", txn.convert2string()), UVM_HIGH)
        read_ap.write(txn);
        ap.write(txn);
      end
    end
  endtask
endclass
