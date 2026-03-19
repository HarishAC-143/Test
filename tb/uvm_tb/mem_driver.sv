//----------------------------------------------------------------------
// Memory Driver
//
// Drives transactions from the sequencer onto the DUT interface using
// the driver clocking block.  Demonstrates sequence/driver
// synchronization via get_next_item / item_done handshake.
//----------------------------------------------------------------------
class mem_driver extends uvm_driver #(mem_seq_item);
  `uvm_component_utils(mem_driver)

  virtual mem_if vif;

  function new(string name = "mem_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_seq_item txn;

    // Wait for reset de-assertion
    @(posedge vif.rst_n);
    @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(txn);
      drive_txn(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_txn(mem_seq_item txn);
    @(posedge vif.clk);
    vif.driver_cb.wr_en <= txn.wr_en;
    vif.driver_cb.rd_en <= txn.rd_en;
    vif.driver_cb.addr  <= txn.addr;
    vif.driver_cb.wdata <= txn.wdata;

    @(posedge vif.clk);
    // De-assert enables after one cycle
    vif.driver_cb.wr_en <= 1'b0;
    vif.driver_cb.rd_en <= 1'b0;

    `uvm_info(get_type_name(), $sformatf("Drove: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass
