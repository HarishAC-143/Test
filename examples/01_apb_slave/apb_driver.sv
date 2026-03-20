// APB Driver — drives APB transactions onto the bus interface
class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize signals
    vif.paddr   <= 0;
    vif.pwdata  <= 0;
    vif.pwrite  <= 0;
    vif.psel    <= 0;
    vif.penable <= 0;

    forever begin
      apb_seq_item req;
      seq_item_port.get_next_item(req);
      drive_transfer(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_transfer(apb_seq_item tr);
    // SETUP phase
    @(posedge vif.pclk);
    vif.paddr  <= tr.addr;
    vif.pwdata <= tr.data;
    vif.pwrite <= tr.write;
    vif.psel   <= 1'b1;

    // ACCESS phase
    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    // Wait for PREADY
    @(posedge vif.pclk);
    while (!vif.pready) @(posedge vif.pclk);

    // Capture response
    if (!tr.write)
      tr.rdata = vif.prdata;
    tr.slverr = vif.pslverr;

    // Return to IDLE
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;

    `uvm_info("DRV", $sformatf("Drove: %s", tr.convert2string()), UVM_HIGH)
  endtask

endclass
