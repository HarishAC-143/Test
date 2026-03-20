// AXI-Lite Monitor — observes all AXI channels and reconstructs transactions
class axi_lite_monitor extends uvm_monitor;

  `uvm_component_utils(axi_lite_monitor)

  virtual axi_lite_if vif;
  uvm_analysis_port #(axi_lite_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "axi_vif", vif))
      `uvm_fatal("MON", "Virtual interface 'axi_vif' not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    @(posedge vif.aresetn);

    fork
      monitor_writes();
      monitor_reads();
    join
  endtask

  // Monitor write transactions
  virtual task monitor_writes();
    bit [31:0] aw_addr;
    bit [31:0] w_data;
    bit [3:0]  w_strb;

    forever begin
      axi_lite_txn txn;

      // Wait for both write address and write data handshakes
      fork
        begin
          // Capture write address
          forever begin
            @(posedge vif.aclk);
            if (vif.awvalid && vif.awready) begin
              aw_addr = vif.awaddr;
              break;
            end
          end
        end
        begin
          // Capture write data
          forever begin
            @(posedge vif.aclk);
            if (vif.wvalid && vif.wready) begin
              w_data = vif.wdata;
              w_strb = vif.wstrb;
              break;
            end
          end
        end
      join

      // Wait for write response
      forever begin
        @(posedge vif.aclk);
        if (vif.bvalid && vif.bready) begin
          txn = axi_lite_txn::type_id::create("wr_mon_txn");
          txn.dir  = AXI_WRITE;
          txn.addr = aw_addr;
          txn.data = w_data;
          txn.strb = w_strb;
          txn.resp = axi_resp_e'(vif.bresp);
          `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
          ap.write(txn);
          break;
        end
      end
    end
  endtask

  // Monitor read transactions
  virtual task monitor_reads();
    forever begin
      axi_lite_txn txn;
      bit [31:0] ar_addr;

      // Wait for read address handshake
      forever begin
        @(posedge vif.aclk);
        if (vif.arvalid && vif.arready) begin
          ar_addr = vif.araddr;
          break;
        end
      end

      // Wait for read data handshake
      forever begin
        @(posedge vif.aclk);
        if (vif.rvalid && vif.rready) begin
          txn = axi_lite_txn::type_id::create("rd_mon_txn");
          txn.dir  = AXI_READ;
          txn.addr = ar_addr;
          txn.data = vif.rdata;
          txn.resp = axi_resp_e'(vif.rresp);
          `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
          ap.write(txn);
          break;
        end
      end
    end
  endtask

endclass
