// ALU Monitor — observes DUT interface and broadcasts transactions
class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;
  uvm_analysis_port #(alu_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface 'alu_vif' not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    alu_transaction txn;

    @(posedge vif.rst_n);

    forever begin
      @(posedge vif.clk);
      if (vif.monitor_cb.valid_in) begin
        txn = alu_transaction::type_id::create("txn");

        // Capture inputs
        txn.operand_a = vif.monitor_cb.operand_a;
        txn.operand_b = vif.monitor_cb.operand_b;
        txn.operation = alu_op_t'(vif.monitor_cb.operation);

        // Wait one clock for the registered output
        @(posedge vif.clk);
        txn.result    = vif.monitor_cb.result;
        txn.carry_out = vif.monitor_cb.carry_out;
        txn.zero_flag = vif.monitor_cb.zero_flag;

        `uvm_info("MON", $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)

        ap.write(txn);
      end
    end
  endtask

endclass
