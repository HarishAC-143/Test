// Memory Monitor — observes SRAM interface and broadcasts transactions
class mem_monitor extends uvm_monitor;

  `uvm_component_utils(mem_monitor)

  virtual mem_if vif;
  uvm_analysis_port #(mem_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "mem_vif", vif))
      `uvm_fatal("MON", "Virtual interface 'mem_vif' not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);

    forever begin
      mem_txn txn;
      @(posedge vif.clk);

      if (vif.cs) begin
        txn = mem_txn::type_id::create("mon_txn");
        txn.addr = vif.addr;

        if (vif.we) begin
          txn.op    = MEM_WRITE;
          txn.wdata = vif.wdata;
          `uvm_info("MON", $sformatf("Observed WRITE: addr=0x%02h data=0x%02h",
                    txn.addr, txn.wdata), UVM_HIGH)
          ap.write(txn);
        end else begin
          txn.op = MEM_READ;
          // Wait one cycle for read data
          @(posedge vif.clk);
          txn.rdata  = vif.rdata;
          txn.rvalid = vif.rvalid;
          `uvm_info("MON", $sformatf("Observed READ: addr=0x%02h data=0x%02h",
                    txn.addr, txn.rdata), UVM_HIGH)
          ap.write(txn);
        end
      end
    end
  endtask

endclass
