// ALU Monitor — observes DUT signals and broadcasts transactions
class alu_monitor extends uvm_monitor;

  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;
  uvm_analysis_port #(alu_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("MON", "Virtual interface 'alu_vif' not found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Wait for reset
    @(posedge vif.rst_n);

    forever begin
      alu_txn txn;
      @(posedge vif.clk);

      if (vif.valid) begin
        txn = alu_txn::type_id::create("mon_txn");
        txn.operand_a = vif.operand_a;
        txn.operand_b = vif.operand_b;
        txn.operation = vif.operation;

        // Wait one cycle for the result (single-cycle latency)
        @(posedge vif.clk);
        txn.result       = vif.result;
        txn.result_valid = vif.result_valid;

        `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
        ap.write(txn);
      end
    end
  endtask

endclass
