// FIFO Monitor — observes FIFO interface activity
class fifo_monitor extends uvm_monitor;
  `uvm_component_utils(fifo_monitor)

  virtual fifo_if vif;
  uvm_analysis_port #(fifo_seq_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);

    forever begin
      fifo_seq_item tr;
      @(posedge vif.clk);

      if (vif.wr_en || vif.rd_en) begin
        tr = fifo_seq_item::type_id::create("tr");
        tr.wr_en   = vif.wr_en;
        tr.rd_en   = vif.rd_en;
        tr.wr_data = vif.wr_data;
        tr.full    = vif.full;
        tr.empty   = vif.empty;

        @(posedge vif.clk);
        tr.rd_data = vif.rd_data;
        tr.full    = vif.full;
        tr.empty   = vif.empty;

        `uvm_info("MON", $sformatf("Collected: %s", tr.convert2string()), UVM_HIGH)
        analysis_port.write(tr);
      end
    end
  endtask

endclass
