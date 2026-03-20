// FIFO Driver
class fifo_driver extends uvm_driver #(fifo_seq_item);
  `uvm_component_utils(fifo_driver)

  virtual fifo_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    vif.wr_en   <= 0;
    vif.rd_en   <= 0;
    vif.wr_data <= 0;
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      fifo_seq_item req;
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  task drive(fifo_seq_item tr);
    @(posedge vif.clk);
    vif.wr_en   <= tr.wr_en;
    vif.rd_en   <= tr.rd_en;
    vif.wr_data <= tr.wr_data;

    @(posedge vif.clk);
    tr.rd_data = vif.rd_data;
    tr.full    = vif.full;
    tr.empty   = vif.empty;

    vif.wr_en <= 0;
    vif.rd_en <= 0;

    `uvm_info("DRV", $sformatf("Drove: %s", tr.convert2string()), UVM_HIGH)
  endtask

endclass
