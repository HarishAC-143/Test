// APB Monitor — passively observes APB bus transactions
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(apb_seq_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      apb_seq_item tr = apb_seq_item::type_id::create("tr");
      collect_transfer(tr);
      analysis_port.write(tr);
    end
  endtask

  task collect_transfer(apb_seq_item tr);
    // Wait for SETUP phase (psel asserted, penable not yet)
    @(posedge vif.pclk iff (vif.psel && !vif.penable));
    tr.addr  = vif.paddr;
    tr.data  = vif.pwdata;
    tr.write = vif.pwrite;

    // Wait for ACCESS phase with PREADY
    @(posedge vif.pclk iff (vif.penable && vif.pready));
    if (!tr.write)
      tr.rdata = vif.prdata;
    tr.slverr = vif.pslverr;

    `uvm_info("MON", $sformatf("Collected: %s", tr.convert2string()), UVM_HIGH)
  endtask

endclass
